package QueryParser::GUI::FrameView;

use strict;
use warnings;
use Wx 0.9922 qw[:allclasses :everything];
use Wx::Grid 0.01;
use base qw(Wx::Frame Class::Accessor Class::Publisher);
use QueryParser::DAO;
use QueryParser::Result;
use Wx::Event qw(EVT_BUTTON EVT_GRID_LABEL_RIGHT_DCLICK EVT_MENU);
use File::Basename;
use Hash::Util qw(lock_keys unlock_keys);

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_ro_accessors(
    qw(start_button user_input grid file_dialog menubar));
__PACKAGE__->mk_accessors(qw(query_result));

sub new {
    my ( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
    $parent = undef             unless defined $parent;
    $id     = -1                unless defined $id;
    $title  = ""                unless defined $title;
    $pos    = wxDefaultPosition unless defined $pos;
    $size   = wxDefaultSize     unless defined $size;
    $name   = ""                unless defined $name;

    # begin wxGlade: FrameView::new
    $style = wxDEFAULT_FRAME_STYLE
      unless defined $style;
    $self =
      $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
    $self->{panel_1} =
      Wx::ScrolledWindow->new( $self, -1, wxDefaultPosition, wxDefaultSize,
        wxTAB_TRAVERSAL );

    # Menu Bar

    # :WORKAROUND:28/3/2007:ARFJr: keep the last menu ID so it will be possible
    # to define new ones dinamically
    $self->{last_menu_item_id} = 1;
    $self->{menubar} = Wx::MenuBar->new();
    $self->SetMenuBar( $self->{menubar} );
    my $wxglade_tmp_menu;
    $wxglade_tmp_menu = Wx::Menu->new();
    Wx::Event::EVT_MENU( $self, -1, \&save_as );
    $wxglade_tmp_menu->Append( 1, 'XML', 'Formats the output as a XML file' );
    $self->{last_menu_item_id}++;
    $wxglade_tmp_menu->Append( 2, 'CSV', 'Formats the output as a CSV file' );
    $self->{last_menu_item_id}++;
    $wxglade_tmp_menu->Append( 3, 'HTML', 'Formats the output as a HTML file' );
    $self->{menubar}->Append( $wxglade_tmp_menu, "Save as" );

    # hardcoding the menu ID's to match a specific format
    EVT_MENU( $self, 1, sub { $self->__save_xml() } );
    EVT_MENU( $self, 2, sub { $self->__save_csv() } );
    EVT_MENU( $self, 3, sub { $self->__save_html() } );

    # Menu Bar end

    $self->{statusbar} = $self->CreateStatusBar( 1, 0 );
    $self->{user_input} =
      Wx::TextCtrl->new( $self->{panel_1}, -1, "Type here the query",
        wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE );
    $self->{start_button} = Wx::Button->new( $self->{panel_1}, -1, 'Get details!' );
    $self->{grid} = Wx::Grid->new( $self->{panel_1}, -1 );
    $self->__set_properties();
    $self->__do_layout();
    $self->{file_dialog} = Wx::FileDialog->new(
        $self,                               # parent
        'Open File',                         # Caption
        '',                                  # Default directory
        '',                                  # Default file
        '*.*',                               # wildcard
        wxFD_SAVE | wxFD_OVERWRITE_PROMPT    # style
    );

    #registries for the event of the model
    QueryParser::DAO->add_subscriber( 'new_query',
        sub { $self->show_result(@_) } );

    # registry the event with the external Controller
    EVT_BUTTON(
        $self,
        $self->{start_button}->GetId(),
        sub { $self->__init_parsing() }
    );

    EVT_GRID_LABEL_RIGHT_DCLICK( $self, sub { $self->__copy_all() } );

    # sane value for query result
    $self->{query_result} = QueryParser::Result->new('');
    lock_keys( %{$self} );
    return $self;
}

# loops over the options in the Connection menu
# and see which one is checked to report to the Controller
sub changed_conn {
    my $self = shift;
    my $menu_bar = $self->get_menubar();
    # 1 means only the Connection menu
    my $menu_items = $menu_bar->GetMenu(1);

    foreach my $item ( $menu_items->GetMenuItems() ) {

        if ( $item->IsChecked() ) {
            # calls the Controller
            $self->notify_subscribers( 'changed_conn', $item->GetLabel() );
            last;
        }

    }

}

sub set_conn_menu {
    my $self = shift;
    # array reference
    my $options = shift;
    my $tmp_menu = Wx::Menu->new();

    foreach my $option ( @{$options} ) {
        $self->{last_menu_item_id}++;
        $tmp_menu->AppendCheckItem( $self->{last_menu_item_id},
            $option, 'Click to connect to' );
        #registering the event
        EVT_MENU(
            $self,
            $self->{last_menu_item_id},
            sub { $self->changed_conn() }
        );
    }

    $self->get_menubar()->Append( $tmp_menu, 'Connection' );

}

sub __save_html {
    my $self = shift;
    my $dialog = $self->get_file_dialog();
    $dialog->SetFilename('QueryDocumentation.html');
    $dialog->SetWildcard('HTML files (*.html)|*.htm');

    if ( $dialog->ShowModal == wxID_OK ) {
        my $full_path = $dialog->GetPath();
        open( OUT, '>', $full_path )
          or $dialog->error_msg("Cannot create $full_path: $!");
        print OUT $self->get_query_result()->to_html();
        close(OUT);
        $self->{statusbar}->SetStatusText( 'File save successfully', 0 );
    }

}

sub __save_csv {
    my $self = shift;
    my $dialog = $self->get_file_dialog();
    $dialog->SetWildcard('CSV files (*.csv)|*.csv');
    $dialog->SetFilename('QueryDocumentation.csv');

    if ( $dialog->ShowModal == wxID_OK ) {
        my $full_path = $dialog->GetPath();
        open( OUT, '>', $full_path )
          or $dialog->error_msg("Cannot create $full_path: $!");
        print OUT $self->get_query_result()->to_csv();
        close(OUT);
        $self->{statusbar}->SetStatusText( 'File save successfully', 0 );
    }

}

sub __save_xml {
    my $self = shift;
    my $dialog = $self->get_file_dialog();
    $dialog->SetWildcard('XML files (*.xml)|*.xml');
    $dialog->SetFilename('QueryDocumentation.xml');

    if ( $dialog->ShowModal == wxID_OK ) {
        my $full_path = $dialog->GetPath();
        # File::Basename function to fetch only the filename
        my $name = fileparse($full_path);
        # removing the extension, to avoid problems with XML syntax
        $name =~ s/\.xml$//;
        open( OUT, '>', $full_path )
          or $dialog->error_msg("Cannot create $full_path: $!");
        print OUT $self->get_query_result()->to_xml($name);
        close(OUT);
        $self->{statusbar}->SetStatusText( 'File save successfully', 0 );
    }

}

sub __set_properties {
    my $self = shift;
    $self->SetTitle('Properties of export interfaces');
    $self->{statusbar}->SetStatusWidths(-1);
    my (@statusbar_fields) = ('Application started');

    if (@statusbar_fields) {
        $self->{statusbar}->SetStatusText( $statusbar_fields[$_], $_ )
          for 0 .. $#statusbar_fields;
    }

    $self->{user_input}->SetMinSize( Wx::Size->new( -1, -1 ) );
    $self->{start_button}
      ->SetToolTipString('Press the button to start the process');
    $self->{grid}->CreateGrid( 10, 3 );
    $self->{grid}->SetRowLabelSize(20);
    $self->{grid}->EnableEditing(0);
    $self->{grid}->SetSelectionMode(wxGridSelectCells);
    $self->{grid}->SetColLabelValue( 0, 'Name' );
    $self->{grid}->SetColLabelValue( 1, 'Type' );
    $self->{grid}->SetColLabelValue( 2, 'Size' );
    $self->{grid}->SetMinSize( Wx::Size->new( -1, -1 ) );
    $self->{grid}->SetToolTipString('Output from the query parser');
    $self->{grid}->Show(1);
    $self->{panel_1}->SetScrollRate( 10, 10 );

}

sub __do_layout {
    my $self = shift;
    $self->{sizer_1} = Wx::BoxSizer->new(wxVERTICAL);
    $self->{grid_sizer_1} = Wx::FlexGridSizer->new( 2, 2, 0, 0 );
    $self->{grid_sizer_1}
      ->Add( $self->{user_input}, 0, wxEXPAND | wxADJUST_MINSIZE );
    $self->{grid_sizer_1}->Add( $self->{start_button}, 0,
        wxLEFT | wxALIGN_CENTER_VERTICAL | wxADJUST_MINSIZE, 20 );
    $self->{grid_sizer_1}
      ->Add( $self->{grid}, 1, wxEXPAND | wxADJUST_MINSIZE, 0 );
    $self->{panel_1}->SetAutoLayout(1);
    $self->{panel_1}->SetSizer( $self->{grid_sizer_1} );
    $self->{grid_sizer_1}->Fit( $self->{panel_1} );
    $self->{grid_sizer_1}->SetSizeHints( $self->{panel_1} );
    $self->{grid_sizer_1}->AddGrowableCol(0);
    $self->{grid_sizer_1}->AddGrowableCol(1);
    $self->{grid_sizer_1}->AddGrowableRow(0);
    $self->{grid_sizer_1}->AddGrowableRow(1);
    $self->{sizer_1}->Add( $self->{panel_1}, 1, wxEXPAND, 0 );
    $self->SetAutoLayout(1);
    $self->SetSizer( $self->{sizer_1} );
    $self->{sizer_1}->Fit($self);
    $self->{sizer_1}->SetSizeHints($self);
    $self->Layout();
}

sub error_msg {
	my ($self, $message) = @_;
    my $self    = shift;
    my $message = shift;
    #setting the status bar
    $self->{statusbar}->SetStatusText( 'An error ocurred', 0 );
    Wx::MessageBox( $message, 'ERROR', wxICON_ERROR, $self );
}

sub change_status {
	my ($self, $message) = @_;
    my $self    = shift;
    my $message = shift;
    $self->{statusbar}->SetStatusText( $message, 0 );
}

# shows the parsed query in the proper text field
sub show_result {
    my $self = shift;
    my ( $item, $event, $result ) = @_;

    if ( $result->isa('QueryParser::Result') ) {
        # keeping a referent to the result object
        $self->set_query_result($result);
        # array_ref is a bidimensional array with the query parsed values
        my $array_ref = $result->get_fields();
        # fetching how many rows are in the QueryParser::Result object
        my $total_rows = scalar @{$array_ref};
        my $grid       = $self->get_grid();

      RESIZE: {

            # resize the grid before writting to it
            if ( $total_rows > $grid->GetNumberRows() ) {
                $grid->AppendRows( $total_rows - $grid->GetNumberRows() );
                last RESIZE;
            }

            if ( $total_rows < $grid->GetNumberRows() ) {
                $grid->DeleteRows( 0, $grid->GetNumberRows() - $total_rows );
                last RESIZE;
            }

        }

        #cleaning up the grid
        $grid->ClearGrid();

        #adding values to the grid
        #looping over the rows
        for ( my $y = 0 ; $y <= $total_rows ; $y++ ) {
            my $row_ref = $array_ref->[$y];
            #updating the columns name, type and size
            $grid->SetCellValue( $y, 0, $row_ref->[0] );
            $grid->SetCellValue( $y, 1, $row_ref->[1] );
            $grid->SetCellValue( $y, 2, $row_ref->[2] );
        }

        #setting the status bar
        $self->{statusbar}->SetStatusText( 'Parsing finished successfully', 0 );
    }
    else {
        $self->error_msg('Could not fetch any information from the database');
    }

}

# double click with the right mouse button on a grid label
sub __init_parsing {
    my $self = shift;
    # check if there is something in the write_panel
    my $user_entry = $self->get_user_input()->GetValue();

    unless ( defined($user_entry) ) {
        $self->error_msg('A query must be supplied first!');
    }

    # calls the Controller
    $self->notify_subscribers( 'init_parsing', $user_entry );
}

sub __copy_all {
    my $self = shift;
    my $grid = $self->get_grid();
    # just to give a visual effect about what is happening
    $grid->SelectAll();
    wxTheClipboard->Open;
    wxTheClipboard->Clear;
    wxTheClipboard->SetData(
        Wx::TextDataObject->new( $self->get_query_result()->to_string() ) );
    wxTheClipboard->Close;
}

1;


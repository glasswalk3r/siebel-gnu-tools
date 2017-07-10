package QueryParser::GUI::ApplicationView;

# only initializes WxPerl application for the Frame to be shown
use warnings;
use strict;
use QueryParser::GUI::FrameView;
# just to inherit the new method
use base qw(Wx::App);

sub OnInit {
    my $self  = shift;
    my $frame = QueryParser::GUI::FrameView->new(
        undef,                                    # Parent window
        -1,                                       # Window id
        'Documentation for export interfaces',    # Title
        [ 300, 300 ],                             # position X, Y
        [ 600, 480 ]                              # size X, Y
    );
    $self->SetTopWindow($frame);                  # Define the toplevel window
    $frame->Show(1);                              # Show the frame
}

1;

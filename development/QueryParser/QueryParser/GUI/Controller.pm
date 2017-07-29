package QueryParser::GUI::Controller;

use warnings;
use strict;
use Carp;
use base qw(QueryParser::ControllerBridge);
use QueryParser::GUI::ApplicationView;
# VERSION

sub new {
	my ($class, $full_path) = @_;
    croak 'the complete pathname is an obligatory parameter'
      unless ( defined($full_path) );
    my $self = $class->SUPER::new(
        # the view
        QueryParser::GUI::ApplicationView->new(),
        # the model is the complete path to the INI file
        $full_path
    );
    # subscribing to the FrameView events
    $self->get_view()->GetTopWindow()
      ->add_subscriber( 'init_parsing', sub { $self->query_ready(@_) } );
    $self->get_view()->GetTopWindow()
      ->add_subscriber( 'changed_conn', sub { $self->change_conn(@_) } );
    return $self;
}

sub change_conn {
    # self, object, event, params
    my ( $self, $conf_section ) = (@_)[ 0, 3 ];

    if ( exists( $self->get_config()->{$conf_section} ) ) {

 # :TODO:29/07/2017 14:26:15:ARFREITAS: replace eval() with Try::Tiny
        eval {
            $self->get_model()
              ->change_conn( $self->get_config()->{$conf_section} );
        };

        if ($@) {
            $self->get_view()->GetTopWindow()->error_msg("@_");
        }

        $self->get_view()->GetTopWindow()
          ->change_status('Connection changed successfully');
    }
    else {
        $self->get_view()->GetTopWindow()
          ->error_msg('Configuration file is invalid');
    }

}

sub query_ready {
    # self, object, event, params
    my ( $self, $query ) = (@_)[ 0, 3 ];

    eval {
        my $model = $self->get_model();
        $model->parse_query($query);
    };

    if ($@) {
        # get the the top frame QueryParser::GUI::FrameView
        $self->get_view()->GetTopWindow()->error_msg($@);
    }

}

1;


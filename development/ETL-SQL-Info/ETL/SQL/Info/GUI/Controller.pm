package ETL::SQL::Info::GUI::Controller;

use warnings;
use strict;
use Carp;
use base qw(ETL::SQL::Info::ControllerBridge);
use ETL::SQL::Info::GUI::ApplicationView;

# VERSION

=pod

=head1 NAME

ETL::SQL::Info::GUI::Controller - MVC controller for wxWidgets GUI toolkit

=head1 DESCRIPTION

This class is a subclass of L<ETL::SQL::Info::ControllerBridge>.

=head1 ATTRIBUTES

None besides those from superclass.

=head1 METHODS

=head2 new

Returns an instance of this class.

Expects as parameter the complete path to the configuration file.

=cut

sub new {
    my ( $class, $config_file ) = @_;
    my $self =
      $class->SUPER::new( ETL::SQL::Info::GUI::ApplicationView->new(),
        $config_file );

    # subscribing to the FrameView events
    $self->get_view()->GetTopWindow()
      ->add_subscriber( 'init_parsing', sub { $self->query_ready(@_) } );
    $self->get_view()->GetTopWindow()
      ->add_subscriber( 'changed_conn', sub { $self->change_conn(@_) } );
    return $self;
}

=head2 change_conn

Implements the abstract method from parent class.

=cut

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
          ->update_status('Connection changed successfully');
    }
    else {
        $self->get_view()->GetTopWindow()
          ->error_msg('Configuration file is invalid');
    }

}

=head2 query_ready

Implements the abstract method from parent class.

=cut

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

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 of Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.orgE<gt>

This file is part of Siebel GNU Tools project.

Siebel GNU Tools is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Siebel GNU Tools is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Siebel GNU Tools.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;


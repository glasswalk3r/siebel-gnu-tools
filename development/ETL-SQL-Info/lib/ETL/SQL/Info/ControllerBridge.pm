package ETL::SQL::Info::ControllerBridge;
use warnings;
use strict;
use Carp;
use base qw(Class::Accessor);
use Config::Tiny 2.14;
use ETL::SQL::Info::DAO;
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(qw(view model config));

# VERSION

=pod

=head1 NAME

ETL::SQL::Info::ControllerBridge - abstract class to implement a MVC controller

=head1 DESCRIPTION

This is an abstract to implement a controller of a MVC design pattern. Some of it's
methods must be overrided by subclasses of it in order to have a unified API and allow
different views (GUI, text, etc) for the C<esi> application.

=head1 ATTRIBUTES

=head2 view

An instance of a view to be notified by MVC model changes.

=head2 config

An instance of a L<Config::Tiny> configuration file.

=head2 model

An instance of L<ETL::SQL::Info::DAO>, created from the information
available on C<config> attribute.

=head1 METHODS

=head2 new

Creates an instance of this class and returns it.

Expects as parameters the C<view> and C<config> values, in that order.

=cut

sub new {
    my ( $class, $view, $config_file ) = @_;
    croak 'the complete pathname is an obligatory parameter'
      unless ( defined($config_file) );
    croak 'the view name is an obligatory parameter'
      unless ( defined($view) );
    my $self = {
        view   => $view,
        config => Config::Tiny->read($config_file)
    };

    # fetch the first section in the file to configure the DAO
    my $first_section = ( ( keys( %{ $self->{config} } ) )[0] );
    croak 'The configuration file $config_file is invalid'
      unless ( defined($first_section) );

    # DAO should be the same for any Controller
    $self->{model} = ETL::SQL::Info::DAO->new( $self->{config}->{$first_section} );
    bless $self, $class;
    return $self;
}

=head2 change_conn

Changes the DB connection of the application. Must be overrided by subclasses.

=cut

# :TODO:29/07/2017 16:15:38:ARFREITAS: change to implement the invoke the model change_conn
# method and return the
sub change_conn {
    croak 'This method must be overrided by any subclasses of ' . __PACKAGE__;
}

=head2 query_ready

Notifies the view that the query was executed, so it will update itself with the new data.

=cut

sub query_ready {
    croak 'This method must be overrided by any subclasses of ' . __PACKAGE__;
}

=head1 SEE ALSO

=over

=item *

L<Class::Acessor>

=back

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

package ETL::SQL::Info::DAO;

use warnings;
use strict;
use DBI 1.636 qw(:sql_types);
use base qw(Class::Accessor Class::Publisher);
use ETL::SQL::Info::Result;
use Hash::Util qw(lock_keys unlock_keys);
use Carp qw(confess);

# VERSION

=pod

=head1 NAME

ETL::SQL::Info::DAO - class to take care of DB interaction

=head1 DESCRIPTION

Implements a DAO model to fetch information about a query from one or more tables.

=head1 ATTRIBUTES

=head2 sql_types

An hash reference to a list of known SQL types, being the key the type name
and the value a integer constant. The constants are compared with the definitions
from a database that implements a L<DBI> driver.

=head2 query

The query that will be sent to the database and analyzed.

=head2 columns

A instance of a L<ETL::SQL::Info::Result> class. It represents each column included
in the query and associated metadata.

=head2 user

A string of the user used for authentication at the database.

=head2 password

A string of the user password for database authentication.

=head2 driver

The respective L<DBI> driver to connect to the database.

=head2 database

The database name and location, as described in L<DBI>.

=head1 METHODS

=cut

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_ro_accessors(qw(sql_types dbh));
__PACKAGE__->mk_accessors(qw(query columns user password driver database));

=head2 new

Creates an instance and returns it. Doesn't expect any parameter.

=cut

sub new {

    # receives a hash reference as a parameter
    my ( $class, $self ) = @_;
    confess('user is an obligatory parameter in the configuration file')
      unless ( exists( $self->{user} ) and defined( $self->{user} ) );
    confess('password is an obligatory parameter in the configuration file')
      unless ( exists( $self->{password} ) and defined( $self->{password} ) );
    confess('driver is an obligatory parameter in the configuration file')
      unless ( exists( $self->{driver} ) and defined( $self->{driver} ) );
    confess( 'driver string is incorrect: ' . $self->{driver} )
      unless ( $self->{driver} =~ /^dbi\:\w+$/ );
    confess('database is an obligatory parameter in the configuration file')
      unless ( exists( $self->{database} )
        and defined( $self->{database} ) );
    $self->_create_list();
    $self->{query}      = undef;
    $self->{dbh}        = undef;
    $self->{properties} = undef;
    bless $self, $class;
    lock_keys( %{$self} );
    return $self;
}

=head2 change_conn

Changes the connection to a database.

If it is already connected to a database, the previous one will be disconnected first.

Expects as parameter a hash reference containing database connection details (the keys C<database>, 
C<user> and C<password> and their respective values).

Returns true if success.

=cut

sub change_conn {
    my ( $self, $conf_ref ) = @_;
    $self->set_database( $conf_ref->{database} );
    $self->set_user( $conf_ref->{user} );
    $self->set_password( $conf_ref->{password} );
    return $self->set_dbh();
}

sub _set_dbh {
    my $self = shift;
    $self->disconnect();
    $self->{dbh} =
      DBI->connect( $self->get_driver() . ':' . $self->get_database(),
        $self->get_user(), $self->get_password() )
      or confess "Cannot connect to database: $DBI::errstr";
    return 1;
}

=head2 disconnect

Executes the database disconnection, if available.

Returns true in the case it succeeds.

=cut

sub disconnect {
    my $self = shift;
    $self->get_dbh()->disconnect() if ( defined( $self->get_dbh() ) );
    $self->{dbh} = undef;
    return 1;
}

=head2 DESTROY

Handles automatic disconnection when the object is destroyed.

=cut

sub DESTROY {
    my $self = shift;
    $self->disconnect();
}

=head2 parse_query

Expects as parameter a string of the query to be executed at the database.

The query will be executed and metadata from the included columns will be recovered.

Since the C<SELECT> recovered data is just ignored, it is a good practice 
to limit the output from the query by using the related statement for your database
of choice (for example, C<ROWNUM> in Oracle and C<LIMIT> for MySQL).

Once finished, it will notify subscribers of the C<new_query> event.

Returns true if success.

=cut

sub parse_query {
    my ( $self, $query ) = @_;
    confess 'A query is an obligatory parameter'
      unless ( defined($query) );
    $self->set_query($query);
    $self->set_dbh() unless ( defined( $self->{dbh} ) );
    my $sth = $self->get_dbh()->prepare($query)
      or confess "Cannot parse the query: $DBI::errstr";
    $sth->execute or confess $sth->errstr;
    my $total_fields = $sth->{NUM_OF_FIELDS};
    my $_names       = $sth->{NAME};
    my $_types       = $sth->{TYPE};
    my $_sizes       = $sth->{PRECISION};
    my @properties;

    for ( my $i = 0 ; $i < $total_fields ; $i++ ) {
        push(
            @properties,
            [
                (
                    $_names->[$i], $self->get_sql_types()->{ $_types->[$i] },
                    $_sizes->[$i]
                )
            ]
        );

    }

    unlock_keys( %{$self} );
    $self->set_columns( ETL::SQL::Info::Result->new( \@properties ) );
    lock_keys( %{$self} );

    # :WARNING:23/3/2007:ARFJr: should notify only interface like superclasses!
    # $self should provide an reference to get Model state
    $self->notify_subscribers( 'new_query', $self->get_columns() );
	return 1;

}

sub _create_list {
    my $self = shift;
    my %list;

    for my $constant ( @{ $DBI::EXPORT_TAGS{sql_types} } ) {
        my $index = &{"DBI::$constant"};
        my $name = substr( $constant, 4 );
        $list{$index} = $name;
    }

    $self->{sql_types} = \%list;
    return 1;
}

=head1 SEE ALSO

=over

=item *

L<Class::Publisher>

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

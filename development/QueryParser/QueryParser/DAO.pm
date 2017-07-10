package QueryParser::DAO;

use warnings;
use strict;
use DBI 1.623 qw(:sql_types);
use base qw(Class::Accessor Class::Publisher);
use QueryParser::Result;
use Hash::Util qw(lock_keys unlock_keys);
use Carp qw(confess);

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_ro_accessors(qw(sql_types dbh));
__PACKAGE__->mk_accessors(qw(query columns user password driver database));

# implements a DAO model to fetch information
# about a query from one or more tables for a given database

sub new {
    # receives a hash reference as a parameter
	my ($class, $self) = @_;
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
    $self->{sql_types}  = _create_list();
    $self->{query}      = undef;
    $self->{dbh}        = undef;
    $self->{properties} = undef;
    bless $self, $class;
    lock_keys( %{$self} );
    return $self;
}

sub change_conn {
	my ($self, $conf_ref) = @_;
    $self->set_database( $conf_ref->{database} );
    $self->set_user( $conf_ref->{user} );
    $self->set_password( $conf_ref->{password} );
    $self->set_dbh();
}

sub set_dbh {
    my $self = shift;
    $self->disconnect();
    $self->{dbh} =
      DBI->connect( $self->get_driver() . ':' . $self->get_database(),
        $self->get_user(), $self->get_password() )
      or confess "Cannot connect to database: $DBI::errstr";
}

sub disconnect {
    my $self = shift;
    $self->get_dbh()->disconnect() if ( defined( $self->get_dbh() ) );
    $self->{dbh} = undef;
    return 1;
}

sub DESTROY {
    my $self = shift;
    $self->disconnect();
}

sub parse_query {
	my ($self, $query) = @_;
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
    $self->set_columns( QueryParser::Result->new( \@properties ) );
    lock_keys( %{$self} );

    # :WARNING:23/3/2007:ARFJr: should notify only interface like superclasses!
    # $self should provide an reference to get Model state
    $self->notify_subscribers( 'new_query', $self->get_columns() );

}

# creates a has list based on the sql_types exported by
# DBI; returns a hash reference
sub _create_list {
    my @list = @{ $DBI::EXPORT_TAGS{sql_types} };
    my %list;

    foreach (@list) {
        my $index = eval($_);
        s/^SQL_//;
        my $string = $_;
        $list{$index} = $string;
    }

    return \%list;
}

1;

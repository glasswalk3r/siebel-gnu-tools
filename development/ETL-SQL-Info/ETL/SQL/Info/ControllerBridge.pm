package ETL::SQL::Info::ControllerBridge;
use warnings;
use strict;
use Carp;
use base qw(Class::Accessor);
use Config::Tiny 2.14;
use QueryParser::DAO;
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(qw(view model config));

sub new {
    my $class = shift;
    my $self = {
        view   => shift,
        config => Config::Tiny->read(shift)
    };

    # fetch the first section in the file to configure the DAO
    my $first_section = ( ( keys( %{ $self->{config} } ) )[0] );
    croak 'The configuration file is invalid'
      unless ( defined($first_section) );
    # DAO should be the same for any Controller
    $self->{model} = QueryParser::DAO->new( $self->{config}->{$first_section} );
    bless $self, $class;
    return $self;
}

sub change_conn {
    croak 'This method must be overrided by any subclasses of ' . __PACKAGE__;
}

sub query_ready {
    croak 'This method must be overrided by any subclasses of ' . __PACKAGE__;
}

1;


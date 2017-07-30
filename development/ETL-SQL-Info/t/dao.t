use warnings;
use strict;
use Test::Most;

my $class = 'ETL::SQL::Info::DAO';
require_ok($class);
can_ok( $class,
    qw(new change_conn _set_dbh disconnect DESTROY parse_query _create_list) );
my %options = (
    user     => 'foobar',
    password => 'secret',
    dsn      => 'DBI:mysql:database=foobar;host=foobar.org;port=12345'
);
my $dao = new_ok( $class => [ \%options ] );
isa_ok( $dao, 'Class::Publisher' );
isa_ok( $dao, 'Class::Accessor' );
my $types_ref = $dao->get_sql_types;
is( ref($types_ref), 'HASH', 'get expected data from get_sql_types method' );

TODO: {
    local $TODO = 'needs to create DB on the fly for that';

    # no reason for validating the numeric values
    my @expected = (qw(INTEGER DATETIME VARCHAR));

    for my $expected (@expected) {
        ok( exists( $types_ref->{$expected} ), "get_sql_types has $expected" )
          or diag( explain($types_ref) );
    }

}

done_testing;

# vim: filetype=perl

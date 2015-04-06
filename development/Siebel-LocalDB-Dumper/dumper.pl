use warnings;
use strict;
use Getopt::Std;
use Siebel::LocalDB::Dumper qw(:all);
use Term::Pulse;
use feature qw(say);

$SIG{INT} = 'CLEANUP';

sub HELP_MESSAGE {

    my $option = shift;

    if ( defined($option) ) {

        say "'-$option' parameter cannot be null";

    }

    my $VERSION = version();

    say <<BLOCK;

Siebel LocalDB Dumper - version $VERSION

This program will connect to a Siebel local database (of Siebel Tools or Siebel Client) and will dump their content to a SQLite database
with the corresponding structure and data.

Connection to the Siebel Local Database will depend on previous ODBC DSN configuration.

The SQLite database will be created from scratch.

The parameters below are obligatory:

-d: Siebel local database ODBC DSN name
-u: expects as parameter the user for authentication as parameter
-p: expects as parameter the password for authentication as parameter
-s: complete path to SQLite database to be used

More information can be found by typing:

perldoc Siebel::LocalDB::Dumper

at the shell.

BLOCK

    exit(0);

}

our %opts;

getopts( 's:u:p:d:', \%opts );

foreach my $option (qw(s u p d)) {

    HELP_MESSAGE($option) unless ( defined( $opts{$option} ) );

}

say "Connecting to Siebel local database with DSN $opts{d}";
my $siebel_dbh = conn_siebel( $opts{d}, $opts{u}, $opts{p} );

say "Creating corresponding SQLite new database in $opts{s}";
my $sqlite_dbh = conn_sqlite( $opts{s} );

pulse_start( name => 'Dumping content...', rotate => 1, time => 1 );
my $result = dump_all( $siebel_dbh, $sqlite_dbh );
pulse_stop();

if ($result) {

    say "Finished: connect to $opts{s} to check results";

}
else {

    say "Failed to create $opts{s}";

}

sub CLEANUP {

    pulse_stop();

    say 'Caught Interrupt, aborting execution';

    foreach my $dbh ( $siebel_dbh, $sqlite_dbh ) {

        close_all($dbh) if ( defined($dbh) );

    }

	exit(1);

}

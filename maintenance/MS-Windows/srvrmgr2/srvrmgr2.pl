#    COPYRIGHT AND LICENCE
#
#    This software is copyright (c) 2012 of Alceu Rodrigues de Freitas Junior, glasswalk3r@yahoo.com.br
#
#    This file is part of Siebel GNU Tools.
#
#    Siebel GNU Tools is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    Siebel GNU Tools is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Siebel GNU Tools.  If not, see <http://www.gnu.org/licenses/>.

# this script will can execute execute any srvrmgr command WITHOUT showing the user and password
# Please verify the documentation of Win32::CryptData at CPAN (http://search.cpan.org/~lmasara/Win32-CryptData-0.02/) for details of how the script
# will store the user and password information in encrypted file

use warnings;
use strict;
use Win32::CryptData qw(:flags);
use Term::ReadKey;
use Getopt::Std;

our $VERSION = 0.01;
my %opts;

my $datadescr    = undef;
my $optentropy   = '$!@EP!928-190y2_-ider3894y398246';
my $reserved     = undef;
my %promptstruct = (
    PromptFlags => undef,
    hwndApp     => undef,
    Prompt      => 'srvrmgr2'
);

getopts( 'hvarc', \%opts );

if ( $opts{h} ) {

    print <<BLOCK;
srvrmgr2 version $VERSION
----------------------------------------------
Usage: srvrmgr2 <-h> <-v> <-a> [<login>] <-c> [<configuration file>]
       -h: display this help message;
       -v: display program information;
       -a <login>: adds an user/password information to the filename described
in srvrmgr2.ini file;
       -c <configuration file>: complete pathname to an alternative 
configuration file. Without this option, the program expects an srvrmgr2.ini 
file in the same directory it is running;

Without any option, the program will execute the command in srvrmgr2.ini file.

All other necessary parameters are located in the srvrmgr2.ini file. Please
check this file for more information.
This program will log all activity information in the text file srvrmgr2.log 
but the option -a. All access to encrypt file will be logged in MS Windows 
EventLog.
BLOCK

    exit;

}

if ( $opts{v} ) {

    print <<BLOCK;
srvrmgr2 version $program_version
----------------------------------------------
This program is a wrapper for the srvrmgr.exe program so the user and password
can be saved in an encrypted file.
BLOCK

    exit;

}

if ( $opts{a} ) {

    open( LOG, ">>srvrmgr2.log" )
      or die "Cannot write to srvrmgr2.log file: $!\n";
    logging( 'log', '----- Begining session -----', \*LOG );
    my %conf;

    if ( $opts{c} ) {

        my $conf_file = shift;
        logging( 'error',
            'Must receive an valid configuration filename with -c option',
            \*LOG )
          unless ( defined($conf_file) );
        %conf = read_conf( $conf_file, \*LOG );

    }
    else {

        %conf = read_conf( 'srvrmgr2.ini', \*LOG );

    }

    my $login = shift;
    logging( 'log',
        'Creating encrypted file with user and password information.', \*LOG );
    write_data( $conf{file}, $login );
    logging( 'log', 'Process finished successfully.', \*LOG );
    logging( 'log', '----- Session ended -----',      \*LOG );
    close(LOG);
    exit;
}

# executes the command if there is no option
open( LOG, ">>srvrmgr2.log" ) or die "Cannot write to srvrmgr2.log file: $!\n";
my %conf;

logging( 'log', '----- Begining session -----', \*LOG );

if ( $opts{c} ) {

    my $conf_file = shift;
    logging( 'error',
        'Must receive an valid configuration filename with -c option', \*LOG )
      unless ( defined($conf_file) );
    %conf = read_conf( $conf_file, \*LOG );

}
else {

    %conf = read_conf( 'srvrmgr2.ini', \*LOG );

}

logging( 'log', 'Executing command with srvrmgr program...', \*LOG );
my ( $user, $password ) = fetch( $conf{file}, $conf{server}, \*LOG );
run_cmd( \%conf, \*LOG, $user, $password );
logging( 'log', 'Finished.', \*LOG );
logging( 'log', '----- Session ended -----', \*LOG );
close(LOG);

######################
# function area

sub write_data {

    my $file = shift;

    print "You will be asked to type in some data. Press CTRL+C to abort.\n";

    my $login = shift;

    print "You must give a valid login after the -a key.\n"
      unless ( defined($login) );
    chomp($login);

    print
"Please type password for <$login>. Don't use the \":\" (colon character): ";
    ReadMode('noecho');
    my $pass = <STDIN>;
    ReadMode('restore');

    print "\nPlease retype the password: ";
    ReadMode('noecho');
    my $pass2 = <STDIN>;
    ReadMode('restore');

    chomp($pass);
    chomp($pass2);

    die "\nThe both passwords are not equal\n" unless ( $pass eq $pass2 );

    die "\nYou can't use the \":\" (colon character) in the password\n"
      if ( $pass =~ /\:/ );

    # creates user/password connection string
    my $DataIn   = $login . ':' . $pass;
    my $Reserved = undef;
    my $Flags    = undef;
    my $DataDescr;
    my $DataOut;

    my $ret =
      Win32::CryptData::CryptProtectData( \$DataIn, \$DataDescr, \$optentropy,
        \$Reserved, \%promptstruct, $Flags, \$DataOut );

    if ($ret) {

        open( FILE, ">$file" ) or die "Cannot create password file $file: $!\n";
        print FILE unpack( "H*", $DataOut );
        close(FILE);
        print "\nPassword saved\n";

    }
    else {

        die "\nError: $^E\n";

    }

    print <<BLOCK;
***********************************************
Please make sure you typed the correct password 
testing the interface as soon as possible!
***********************************************
BLOCK

}

sub read_conf {

    my $conf_file = shift;
    my $log_ref   = shift;
    logging( 'log', 'Reading configuration file...', $log_ref );

    # reading the configuration file
    open( CONF, "<$conf_file" )
      or logging( 'error', "Cannot read $conf_file file: $!", $log_ref );

    my %conf;
    my ( $key, $value );

    while (<CONF>) {

        next if (/^#/);
        chomp;
        next unless (/[\w]+/);

        ( $key, $value ) = split( /->/, $_ );

        # removing spaces
        $key =~ s/^\s//g;
        $key =~ s/\s$//g;

        $value =~ s/^\s//g;
        $value =~ s/\s$//g;

        $conf{$key} = $value

    }

    close(CONF);
    logging( 'log', 'Configuration step finished successfully.', $log_ref );
    return %conf;

}

sub logging {

    # error type can abort the program execution depending on it's value
    my $error_type = shift;
    my $message    = shift;
    my $file_ref   = shift;

    die "Must receive an reference to the log filename"
      unless ( defined($file_ref) );

    my $time = localtime(time);

    if ( $error_type eq 'error' ) {

        print $file_ref "[$time]: $message\n";
        print $file_ref "[$time]: ----- Session ended -----\n";
        close($file_ref);
        die "$message\n";

    }

    print $file_ref "[$time]: $message\n";
    print "$message\n";

}

sub run_cmd {

    my $conf_ref = shift;
    my $log_ref  = shift;
    my $user     = shift;
    my $password = shift;

 # creating temporary file for srvrmgr command, to avoid very long lines problem
    my $cmd_tmp = 'srvrmgr2-' . rand(time);
    my $log_tmp = 'srvrmgr2-log-' . rand(time);

    open( OUT, ">$cmd_tmp" )
      or
      logging( 'error', "Cannot create temporary file for run_cmd function: $!",
        $log_ref );
    print OUT "$conf_ref->{command}\n";
    close(OUT)
      or
      logging( 'error', "Cannot close temporary file for run_cmd function: $!",
        $log_ref );

    system( $conf_ref->{srvrmgr}, '/g', $conf_ref->{gateway}, '/e',
        $conf_ref->{enterprise}, '/s', $conf_ref->{server}, '/u',
        $user,                   '/p', $password,           '/i',
        $cmd_tmp,                '/o', $log_tmp,            '/b'
      )
      and logging( 'error',
        "An error ocurred when trying to execute Siebel srvrmgr: $!",
        $log_ref );

    #reading log file
    open( READ, "<$log_tmp" )
      or logging( 'error', "Cannot read $log_tmp file: $!", $log_ref );
    my @content = <READ>;
    close(READ);

    print $log_ref " ---- SRVRMGR output ---- \n";

    foreach (@content) {

        s/\r\n//g;
        print $log_ref "$_\n";

    }

    print $log_ref " ------------------------ \n";

    print "\n";

    unlink($cmd_tmp)
      or logging( 'error',
        "Cannot remove temporary file $cmd_tmp for run_cmd function: $!",
        $log_ref );
    unlink($log_tmp)
      or logging( 'error',
        "Cannot remove temporary file $log_tmp for run_cmd function: $!",
        $log_ref );

}

sub check_data {

    my $data     = shift;
    my $location = shift;

    logging( 'error', "The retrieved information from $location is not valid" )
      unless ( $data =~ /[\w]+\:[\w]/ );

}

sub fetch {

    my $conf_file = shift;
    my $server    = shift;
    my $log_ref   = shift;

    logging( 'log', 'Retrieving user/password information', $log_ref );

    my $encrypted_info = read_file( $conf_file, $log_ref );
    my $flags = undef;
    my $desencrypted_info;

    my $ret =
      Win32::CryptData::CryptUnprotectData( \$encrypted_info, \$datadescr,
        \$optentropy, \$reserved, \%promptstruct, $flags, \$desencrypted_info );

    if ($ret) {

        check_data( $desencrypted_info, $server );

        logging( 'log', 'Information retrieved successfully.', $log_ref );

        my ( $user, $password ) = split( /\:/, $desencrypted_info );
        return ( $user, $password );

    }
    else {

        logging( 'error', "Error: $^E", $log_ref );

    }

}

sub read_file {

    my $file    = shift;
    my $log_ref = shift;

    open( FILE, "<$file" )
      or logging( 'error', "Cannot read passwd file $file: $!", $log_ref );
    my $content = <FILE>;
    close(FILE);
    $content = pack( 'H*', $content );
    return $content;

}


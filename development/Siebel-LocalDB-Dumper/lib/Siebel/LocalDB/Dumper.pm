package Siebel::LocalDB::Dumper;

use strict;
use warnings;
use DBI qw(:utils);
use Siebel::LocalDB::Dumper::Column;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS =
  ( 'all' => [qw(conn_siebel conn_sqlite dump_all version close_all)] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(conn_siebel conn_sqlite dump_all version close_all);

our $VERSION = '0.02';

sub version {

    return $VERSION;

}

sub conn_siebel {

    my $dsn      = shift;
    my $user     = shift;
    my $password = shift;

    my $db_name = 'dbi:ODBC:' . $dsn;

    my $dbh =
      DBI->connect( $db_name,
        $user, $password, { RaiseError => 1, AutoCommit => 0 } )
      or die "Failed to connect - $DBI::errstr";

    $dbh->{LongReadLen} = 512 * 1024;

    return $dbh;

}

sub conn_sqlite {

    my $sqlite_db_name = shift;

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$sqlite_db_name",
        '', '', { RaiseError => 1 } );
    $dbh->do('PRAGMA cache_size = 500000');
    $dbh->do('PRAGMA synchronous = OFF');

    return $dbh;

}

sub close_all {

    my $dbh = shift;

    if ( $dbh->{ActiveKids} ) {

        foreach my $sth ( @{ $dbh->{ChildHandles} } ) {

            $sth->finish() if ( defined($sth) );

        }

    }

    $dbh->disconnect() or warn $dbh->errstr();

}

sub dump_all {

    my $siebel_dbh = shift;
    my $sqlite_dbh = shift;

    my $schema = 'SIEBEL';

    my $all_tables = qq{select
name
from siebel.s_table
where stat_cd = 'Active'
and ( ( name like 'S_%' ) or ( name like 'CX_%' ) )};

    my $all_sth;
    my $create_ddl;

    eval {

        $all_sth = $siebel_dbh->prepare($all_tables);

        $all_sth->execute();

        while ( my $row = $all_sth->fetchrow_arrayref() ) {

            my $table = $row->[0];

            my $columns_ref;

            if ( $table eq 'S_PER_FCST_D' ) {

# :WORKAROUND:22/05/2013 17:41:15:: S_PER_FCST_D for some reason returns duplicated columns when using database "introspection", both
# with Perl DBI and Java JDBC
                $columns_ref = _S_PER_FCST_D( $siebel_dbh, $schema, $table );
                next;

            }
            else {

                $columns_ref = _get_col_data( $siebel_dbh, $schema, $table );

            }

            $create_ddl = 'CREATE TABLE IF NOT EXISTS ' . $table . '(';

            $create_ddl .=
              join( ', ', ( map { $_->to_string() } @{$columns_ref} ) );
            $create_ddl .= ')';

            my $create_sth = $sqlite_dbh->prepare($create_ddl);
            $create_sth->execute();
            $create_sth->finish();
            $create_ddl = undef;

            my $stat_info =
              $siebel_dbh->statistics_info( undef, $schema, $table, 0, 0 );

          # must get all indexes rows first to later create the CREATE INDEX DDL
            my %indexes;

            while ( my $stat_row = $stat_info->fetchrow_hashref() ) {

                my $asc_desc;

                next unless ( defined( $stat_row->{INDEX_NAME} ) );

                if ( exists( $indexes{ $stat_row->{INDEX_NAME} } ) ) {

                    push(
                        @{ $indexes{ $stat_row->{INDEX_NAME} }->{columns} },
                        (
                            ($asc_desc)
                            ? join( ' ', $stat_row->{COLUMN_NAME}, $asc_desc )
                            : $stat_row->{COLUMN_NAME}
                        )
                    );

                }
                else {

                    CASE: {

                        unless ( defined($stat_row->{ASC_OR_DESC}) ) { $asc_desc = ''; last CASE; }
                        if ( $stat_row->{ASC_OR_DESC} eq 'A') { $asc_desc = 'ASC'; last CASE; }
                        if ( $stat_row->{ASC_OR_DESC} eq 'D') { 
                            $asc_desc = 'DESC'; last CASE;
                        } else {
                            die( 'invalid ASC_DESC clause: ' . $stat_row->{ASC_OR_DESC} )
                        }

                    }

                    $indexes{ $stat_row->{INDEX_NAME} } = {
                        non_unique => $stat_row->{NON_UNIQUE},
                        columns =>
                          [ ( $stat_row->{COLUMN_NAME} . ' ' . $asc_desc ) ]
                    };

                }

            }

            foreach my $index ( keys(%indexes) ) {

                unless ( $indexes{$index}->{non_unique} ) {

                    $create_ddl = 'CREATE UNIQUE INDEX IF NOT EXISTS ';

                }
                else {

                    $create_ddl = 'CREATE INDEX IF NOT EXISTS ';

                }

                $create_ddl .=
                    $index . ' ON '
                  . $table . '('
                  . join( ', ', @{ $indexes{$index}->{columns} } ) . ')';

                $create_sth = $sqlite_dbh->prepare($create_ddl);
                $create_sth->execute();
                $create_sth->finish();
                $create_ddl = undef;

            }

            # inserting rows

            my $source_query =
                'SELECT '
              . join( ', ', map { $_->name() } @{$columns_ref} )
              . ' FROM siebel.'
              . $table;

            my $select_sth = $siebel_dbh->prepare($source_query);

            my @quoted_columns;

            foreach my $column ( @{$columns_ref} ) {

                push( @quoted_columns, $column->quoted_name() );

            }

            my $dest_insert =
                'INSERT INTO '
              . $table . ' ('
              . join( ', ', @quoted_columns )
              . ') VALUES('
              . join( ', ', ( map { '?' } @quoted_columns ) ) . ')';

            my $insert_sth = $sqlite_dbh->prepare($dest_insert);

            $select_sth->execute();

            my $insert_counter = 0;

            while ( my $row = $select_sth->fetchrow_arrayref() ) {

                unless ($insert_counter) {

                    $sqlite_dbh->{AutoCommit} = 0;

                }

                for ( my $i = 0 ; $i < scalar( @{$columns_ref} ) ; $i++ ) {

                    $insert_sth->bind_param( ( $i + 1 ),
                        $row->[$i], $columns_ref->[$i]->sql_type() );

                }

                $insert_sth->execute();

                $insert_counter++;

                if ( $insert_counter > 999 ) {

                    $sqlite_dbh->commit();
                    $insert_counter = 0;

                }
            }

        }

        $all_sth->finish();

    };    #end of eval block

    my $return;

    if ($@) {

        warn $@;
        $return = 0;

    }
    else {

        $return = 1;
    }

    foreach my $dbh ( ( $siebel_dbh, $sqlite_dbh ) ) {

        close_all($dbh);

    }

    return $return;

}

sub _get_col_data {

    my $dbh    = shift;
    my $schema = shift;
    my $table  = shift;

    my $tbl_info = $dbh->column_info( undef, $schema, $table, '%' );

    my @columns;

    while ( my $tbl_row = $tbl_info->fetchrow_hashref() ) {

        push(
            @columns,
            Siebel::LocalDB::Dumper::Column->new(
                {
                    name           => $tbl_row->{COLUMN_NAME},
                    orig_type      => $tbl_row->{TYPE_NAME},
                    decimal_digits => (
                        ( $tbl_row->{DECIMAL_DIGITS} )
                        ? $tbl_row->{DECIMAL_DIGITS}
                        : 0
                    ),
                    nullable => ( $tbl_row->{IS_NULLABLE} eq 'NO' ) ? 0
                    : 1
                }
            )
        );

    }

    $tbl_info->finish();

    return \@columns;

}

sub _S_PER_FCST_D {

    my $dbh    = shift;
    my $schema = shift;
    my $table  = shift;

    my $tbl_info = $dbh->column_info( undef, $schema, $table, '%' );

    my @columns;

    my %columns;

# :WORKAROUND:22/05/2013 17:47:43:: hash autovivification should remove duplicated columns
    while ( my $tbl_row = $tbl_info->fetchrow_hashref() ) {

# :WORKAROUND:22/05/2013 17:49:23:: the columns DATA are not shown in Siebel Tools
        next if ( $tbl_row->{COLUMN_NAME} =~ /^DATA\d{2}$/ );

        $columns{ $tbl_row->{COLUMN_NAME} } = {
            TYPE_NAME      => $tbl_row->{TYPE_NAME},
            DECIMAL_DIGITS => $tbl_row->{DECIMAL_DIGITS},
            IS_NULLABLE    => $tbl_row->{IS_NULLABLE}
        };

    }

    foreach my $column_name ( keys(%columns) ) {

        push(
            @columns,
            Siebel::LocalDB::Dumper::Column->new(
                {
                    name           => $column_name,
                    orig_type      => $columns{$column_name}->{TYPE_NAME},
                    decimal_digits => (
                        ( $columns{$column_name}->{DECIMAL_DIGITS} )
                        ? $columns{$column_name}->{DECIMAL_DIGITS}
                        : 0
                    ),
                    nullable => ( $columns{$column_name}->{IS_NULLABLE} eq 'NO' )
                    ? 0
                    : 1
                }
            )
        );

    }

    $tbl_info->finish();

    return \@columns;

}

1;
__END__

=head1 NAME

Siebel::LocalDB::Dumper - Perl extension for exporting Siebel Local database data to a SQLite database

=head1 SYNOPSIS

    use Siebel::LocalDB::Dumper qw(:all);
 
    say "Connecting to Siebel local database with DSN $opts{d}";
    my $siebel_dbh = conn_siebel( $opts{d}, $opts{u}, $opts{p} );

    say "Creating corresponding SQLite new database in $opts{s}";
    my $sqlite_dbh = conn_sqlite( $opts{s} );

    my $result = dump_all( $siebel_dbh, $sqlite_dbh );

    if ($result) {

        say "Finished: connect to $opts{s} to check results";

    }
    else {

        say "Failed to create $opts{s}";

    }

=head1 DESCRIPTION

Siebel::LocalDB::Dumper functions enables exporting database schema from a Siebel local database (a Sybase SQL Anywhere database) to SQLite database.

Tables schema (including indexes) are recriated in a SQLite database that will created from scratch. Data from the tables is also copied.

The objective of Siebel::LocalDB::Dumper is enabling having Siebel data available in a more portable way, since SQLite is free software and available
to much more OS plataforms.

=head1 EXPORT

=head2 conn_siebel

Connects to Siebel and returns a L<DBI> database handler if the connection was successful.

Expects the following parameters:

=over

=item 1.

ODBC DSN name configured to connect to the Siebel local database.

=item 2.

The user login to connect to the local database.

=item 3.

The user password to connect to the local database.

=back

=head2 conn_sqlite

Create and connect to a SQLite database, returning a L<DBI> database handler if sucessful.

Expects a single paramater, the complete path to the file to be used for the SQLite database.

=head2 dump_all

Executes the database creation and data copy from Siebel local database to the corresponding SQLite database, returning true if sucessful.

Expects as parameters:

=over

=item 1.

Siebel local database L<DBI> database handler.

=item 2.

SQLite database L<DBI> database handler.

=back

Depending on several conditions, the data migration can take a while to finish.

=head2 version

Returns a float indicating the version of Siebel::LocalDB::Dumper.

=head2 close_all

Closes the DBI database handle gracefully: all non-finished statements will be finished.

Expects a database handle as parameter.

=head1 SEE ALSO

=over

=item *

L<DBI>

=item *

L<DBD::ODBC>

=item *

L<DBD::SQLite>

=item *

L<Siebel::LocalDB::Dumper::Column>

=back

=head1 KNOWN ISSUES

Sometimes the dumper get some issues from the Siebel local database and DBI will print some warnings to STDERR about them.

The warnings messages below were found during some tests, but they can be ignored safely.

=over

=item Getting a string instead a float

If the dumper warns something like the message below:

    datatype mismatch: bind param (12) .0010000 as float at .\lib/Siebel/LocalDB/Dumper.pm line 251.

That means that the Siebel local database had a value o ".0010000" (or anything that looks like that) that is understood by the database backend (L<DBI>)
as a string instead the float values as declared that the parameter should be. The database backend will convert the string to 0.001000 and will continue
working without further issues.

=back

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.org<gt>

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
along with Siebel COM.  If not, see <http://www.gnu.org/licenses/>.

=cut

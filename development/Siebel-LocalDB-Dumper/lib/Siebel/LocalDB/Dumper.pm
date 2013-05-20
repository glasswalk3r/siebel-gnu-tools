package Siebel::LocalDB::Dumper;

use 5.016003;
use strict;
use warnings;
use feature qw(say switch);
use DBI qw(:utils);
use DateTime;
use Siebel::LocalDB::Dumper::Column;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Siebel::LocalDB::Dumper ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [qw(conn_siebel conn_sqlite dump_all version)] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(conn_siebel conn_sqlite dump_all version);

our $VERSION = '0.01';

sub version {

    return $VERSION;

}

sub conn_siebel {

    my $dsn      = shift;
    my $user     = shift;
    my $password = shift;

    my $dbh = DBI->connect( 'dbi:ODBC:SSD Local Db default instance',
        'SLH2170', 'JOWC6L2NFR', { RaiseError => 1, AutoCommit => 0 } )
      or die "Failed to connect - $DBI::errstr";

    $dbh->{LongReadLen} = 512 * 1024;

    return $dbh;

}

sub conn_sqlite {

    my $sqlite_db_name = shift;

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$sqlite_db_name", '', '' );
    $dbh->do('PRAGMA cache_size = 500000');
    $dbh->do('PRAGMA synchronous = OFF');

    return $dbh;

}

sub close_all {

    my $dbh = shift;

    if ( $dbh->{ActiveKids} ) {

        foreach my $sth ( @{ $dbh->{ChildHandles} } ) {

            $sth->finish();

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

            next if $table eq 'S_PER_FCST_D';

            say "working with $table";

            $create_ddl = 'CREATE TABLE IF NOT EXISTS ' . $table . '(';

            my $tbl_info =
              $siebel_dbh->column_info( undef, $schema, $table, '%' );

            my @columns;

            while ( my $tbl_row = $tbl_info->fetchrow_hashref() ) {

# :WORKAROUND:27/02/2013 18:26:06:: double quotes are necessary to escape columns names equal to SQLite keywords
                push(
                    @columns,
                    Column->new(
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

            my @columns_names;

            foreach my $column (@columns) {

                push( @columns_names, $column->name() );

            }

            $create_ddl .= join( ', ', ( map { $_->to_string() } @columns ) );
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

                    given ( $stat_row->{ASC_OR_DESC} ) {

                        when (undef) { $asc_desc = '' }
                        when ('A')   { $asc_desc = 'ASC' }
                        when ('D')   { $asc_desc = 'DESC' }
                        default {
                            die( 'invalid ASC_DESC clause: '
                                  . $stat_row->{ASC_OR_DESC} )
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
              . join( ', ', @columns_names )
              . ' FROM siebel.'
              . $table;

            my $select_sth = $siebel_dbh->prepare($source_query);

            my @quoted_columns;

            foreach my $column (@columns) {

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

                for ( my $i = 0 ; $i < scalar(@columns) ; $i++ ) {

                    $insert_sth->bind_param( ( $i + 1 ),
                        $row->[$i], $columns[$i]->sql_type() );

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

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Siebel::LocalDB::Dumper - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Siebel::LocalDB::Dumper;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Siebel::LocalDB::Dumper, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

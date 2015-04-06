package Siebel::LocalDB::Dumper::Column;

=pod

=head1 NAME

Siebel::LocalDB::Dumper::Column - Perl Moose based class to represent a database column

=cut

use Moose;
use feature qw(switch say);
use DBI qw(:sql_types);
use namespace::autoclean;

=pod

=head1 SYNOPSIS

    use Siebel::LocalDB::Dumper::Column;

    while ( my $tbl_row = $tbl_info->fetchrow_hashref() ) {

        push(
            @columns,
            Siebel::LocalDB::Dumper::Column->new(
                {
                    name           => $tbl_row->{COLUMN_NAME},
                    orig_type      => $tbl_row->{TYPE_NAME},
                    decimal_digits => ( ( $tbl_row->{DECIMAL_DIGITS} ) ? $tbl_row->{DECIMAL_DIGITS} : 0 ),
                    nullable       => ( $tbl_row->{IS_NULLABLE} eq 'NO' ) ? 0 : 1
                }
            )
        );

    }

=head1 DESCRIPTION

Siebel::LocalDB::Dumper::Column represents a corresponding SQLite table column to a Siebel local database table column.

Once recovering Siebel local database schema data, such data is internally converted to be recreated using SQLite syntax and data types.

=head1 ATTRIBUTES

=head2 name

A string representing the column name.

This is a required attribute.

=cut

has name => ( is => 'ro', isa => 'Str', required => 1 );

=head2 orig_type

The original column data type recovered from the Siebel local database. This type should be converted from ODBC data types since ODBC is used
to connect to the Siebel local database (the default connection method).

Expects a string representing the data type.

=cut

has orig_type => ( is => 'ro', isa => 'Str', required => 1 );

=head2 sqlite_type

A string representing the SQLite data type of the column.

This attribute is read-only and is created automatically by using Moose's lazy evaluation.

=cut

has sqlite_type => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    builder  => '_set_sqlite_type',
    lazy     => 1
);

=head2 sql_type

A string representing the L<DBI> SQL Type of the column. It is meant to be used during binding operations to declare explicit the database
type of the binding parameter.

This attribute is read-only and is created automatically by using Moose's lazy evaluation.

=cut

has sql_type => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    builder  => '_set_sql_type',
    lazy     => 1
);

=head2 decimal_digits

An integer describing the number of decimal digits expected for the column.

This is a required attribute.

=cut

has decimal_digits => ( is => 'ro', isa => 'Int', required => 0, default => 0 );

=head2 quoted_name

A string representing the column name quoted since a column might have a name that is a reserved word of SQLite.

This attribute value is created automatically and the attribute itself is read-only.

=cut

has quoted_name =>
  ( is => 'ro', isa => 'Str', required => 0, builder => '_set_quoted_name' );

=head2 nullable

A boolean (in Perl terms) describing if the column accept NULL values or not.

This is a required attribute.

=cut

has nullable =>
  ( is => 'ro', isa => 'Bool', reader => 'is_nullable', required => 1 );

=pod

=head1 METHODS

All attributes getters and/or setters (when appropriated) use the same attribute name.

Additional methods are described below.

=head2 to_string

Returns a string of the column representing the DDL command to create the table in a SQLite table.

The string returned is composed by:

    " $column->quoted_name() $column->sqlite_type()"

Additionally, if the column does not accepts null values, the string below is returned:

    " $column->quoted_name() $column->sqlite_type() NOT NULL"

=cut

sub to_string {

    my $self = shift;

    my $column_def = join( ' ', $self->quoted_name(), $self->sqlite_type() );

    unless ( $self->is_nullable() ) {

        $column_def .= ' NOT NULL';

    }

    return $column_def;

}

sub _set_quoted_name {

    my $self = shift;

    return '"' . $self->name() . '"';

}

sub _set_sql_type {

    my $self = shift;

    my $converted;

    CASE: {

        if ( $self->sqlite_type eq 'TEXT' ) { $converted = SQL_VARCHAR; last CASE; }
        if ( $self->sqlite_type eq 'REAL') { $converted = SQL_REAL; last CASE; }
        
        if ( $self->sqlite_type eq 'INTEGER') {
        
          $converted = SQL_INTEGER; last CASE;
          
        } else { 
        
            die 'unknow type received: "' . $self->sqlite_type() . '"'
            
        }

    }

    return $converted;

}

# converts a SQL Anywhere type to a SQLite type
sub _set_sqlite_type {

    my $self = shift;

    my $converted_type;

    CASE: {

        if ( $self->orig_type eq 'varchar') { $converted_type = 'TEXT'; last CASE; }
        if ( $self->orig_type eq 'long varchar') { $converted_type = 'TEXT'; last CASE; }
        if ( $self->orig_type eq 'char') { $converted_type = 'TEXT'; last CASE }
        if ( $self->orig_type eq 'timestamp') { $converted_type = 'TEXT'; last CASE; }
        if ( $self->orig_type eq 'numeric') {
            ( $self->decimal_digits() )
              ? ( $converted_type = 'REAL' )
              : ( $converted_type = 'INTEGER' )
        } else { 
        
            die 'unknow type received: "' . $self->orig_type() . '"';
            
        }

    }

    return $converted_type;

}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 of Alceu Rodrigues de Freitas Junior, E<lt>arfreitas@cpan.org<E<gt>

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

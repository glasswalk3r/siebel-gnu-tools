package Siebel::LocalDB::Dumper::Column;

use Moose;
use feature qw(switch say);
use DBI qw(:sql_types);
use namespace::autoclean;

has name      => ( is => 'ro', isa => 'Str', required => 1 );
has orig_type => ( is => 'ro', isa => 'Str', required => 1 );
has sqlite_type =>
  ( is => 'ro', isa => 'Str', required => 0, builder => '_set_sqlite_type', lazy => 1 );
has sql_type => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
    builder  => '_set_sql_type',
    lazy     => 1
);
has decimal_digits => ( is => 'ro', isa => 'Int', required => 0, default => 0 );
has quoted_name =>
  ( is => 'ro', isa => 'Str', required => 0, builder => '_set_quoted_name' );
has nullable =>
  ( is => 'ro', isa => 'Bool', reader => 'is_nullable', required => 1 );

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

    given ( $self->sqlite_type() ) {

        when ('TEXT')    { $converted = SQL_VARCHAR }
        when ('REAL')    { $converted = SQL_REAL }
        when ('INTEGER') { $converted = SQL_INTEGER }
        default { die 'unknow type received: "' . $self->sqlite_type() . '"' }

    }

    return $converted;

}

# converts a SQL Anywhere type to a SQLite type
sub _set_sqlite_type {

    my $self = shift;

    my $converted_type;

    given ( $self->orig_type ) {

        when ('varchar')      { $converted_type = 'TEXT' }
        when ('long varchar') { $converted_type = 'TEXT' }
        when ('char')         { $converted_type = 'TEXT' }
        when ('timestamp')    { $converted_type = 'TEXT' }
        when ('numeric') {
            ( $self->decimal_digits() )
              ? ( $converted_type = 'REAL' )
              : ( $converted_type = 'INTEGER' )
        }
        default { die 'unknow type received: "' . $self->orig_type() . '"' }

    }

    return $converted_type;

}

__PACKAGE__->meta->make_immutable;

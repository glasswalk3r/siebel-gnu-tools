package ETL::SQL::Info::Result;

use warnings;
use strict;
use File::Basename;
use base qw(Class::Accessor);
use Hash::Util qw(lock_keys);
use XML::Writer 0.623;
use Text::CSV_XS 0.97;
use Carp;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(fields));

#VERSION

=pod

=head1 NAME

ETL::SQL::Info::Result - class to provide the results of the SQL query analysis

=head1 DESCRIPTION

This class implements the results of the SQL query analysis and is aware how to export
this data by using different formats.

=head1 ATTRIBUTES

=head2 fields

An array reference of arrays.

Each array represents a column in the SQL query. Each index represents an information
about the column as described below:

=over

=item 1

column name

=item 2

column type

=item 3

column size

=back

=head1 METHODS

=head2 new

Creates and returns a new instance of this class. Expects as parameter an array reference as
described in the C<fields> attribute.

=cut

sub new {
    my $class = shift;
    my $self = { fields => shift };
    bless $self, $class;
    lock_keys( %{$self} );
    return $self;
}

=head2 to_string

Returns a string, separating each field with a tab and each registry with a new line character.

=cut

sub to_string {
    my $self = shift;
    my $string;
    map { $string .= join( "\t", @{$_} ) . "\n"; } @{ $self->get_fields() };
    return $string;
}

=head2 to_csv

Returns a string representing the C<fields> attribute in CSV format.

=cut

sub to_csv {
    my $self = shift;
    my $csv = Text::CSV_XS->new()
      or confess "Cannot use CSV: " . Text::CSV_XS->error_diag();
    return $csv->combine( @{ $self->get_fields() } );
}

=head2 to_html

Returns a string representing the C<fields> attribute in HTML format.

=cut

sub to_html {
    my $self        = shift;
    my $html_string = <<BLOCK;
<html>
<head><title>Query documentation</title></head>
<body>
<table border=1 align="center">
<th>Name</th><th>Type</th><th>Size</th>
BLOCK

    map {
        $html_string .= '<tr><td>' . join( '</td><td>', @{$_} ) . '</td></tr>';
    } @{ $self->get_fields() };
    $html_string .= '</table></body></html>';
    return $html_string;
}

=head2 to_xml

Returns a string representing the C<fields> attribute in XML format.

=cut

sub to_xml {
	my ($self, $name) = @_;
    my $xml;
    my $writer = XML::Writer->new( OUTPUT => \$xml );
    my @fields_name = qw(name type size);
    $writer->xmlDecl("UTF-8");
    $writer->startTag('dataDictionary');

    for my $column_data ( @{ $self->get_fields() } ) {
        $writer->startTag('column');

   # :WARNING:26/3/2007:ARFJr: hardcoding the total of members in the array as 3
        for ( my $i = 0 ; $i <= 2 ; $i++ ) {
            $writer->dataElement( $fields_name[$i], $column_data->[$i] );
        }

        $writer->endTag('column');
    }

    $writer->endTag('dataDictionary');
    $writer->end();
    return $xml;
}

=head1 SEE ALSO

=over

=item *

L<XML::Writer>

=item *

L<Class::Acessor>

=item *

L<Text::CSV_XS>

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

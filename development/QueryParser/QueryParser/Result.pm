package QueryParser::Result;

use warnings;
use strict;
use DBI qw(:sql_types);
use File::Basename;
use base qw(Class::Accessor);
use Hash::Util qw(lock_keys);
use XML::Writer 0.623;
use Text::CSV_XS 0.97;
use Carp;

__PACKAGE__->follow_best_practice();
__PACKAGE__->mk_accessors(qw(fields));

# fields is an array reference
# each item is another array reference
# for these references, the values maintained have the following
# meaning:
# 0 - column name
# 1 - column type
# 2 - column size

sub new {
    my $class = shift;
    my $self = { fields => shift };
    bless $self, $class;
    lock_keys( %{$self} );
    return $self;
}

# returns a string, separating each field with a tab and each registry
# with a new line character
sub to_string {
    my $self = shift;
    my $string;
    map { $string .= join( "\t", @{$_} ) . "\n"; } @{ $self->get_fields() };
    return $string;
}

sub to_csv {
    my $self = shift;
    my $csv = Text::CSV_XS->new()
      or confess "Cannot use CSV: " . Text::CSV_XS->error_diag();
    return $csv->combine( @{ $self->get_fields() } );
}

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

sub to_xml {
	my ($self, $name) = @_;
    my $xml;
    my $writer = XML::Writer->new( OUTPUT => \$xml );
    my @fields_name = qw(name type size);
    $writer->xmlDecl("UTF-8");
    $writer->startTag('dataDictionary');

    foreach my $column_data ( @{ $self->get_fields() } ) {
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

1;

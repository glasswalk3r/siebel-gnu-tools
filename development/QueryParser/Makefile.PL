use 5.010;
use warnings;
use strict;
use ExtUtils::MakeMaker;

my %config = (
    NAME             => 'QueryParser',
    VERSION          => '0.01',
    MIN_PERL_VERSION => 5.014,
    PREREQ_PM        => {
        'Class::Accessor'  => 0.34,
        'Config::Tiny'     => 2.14,
        DBI                => 1.623,
        'Class::Publisher' => 0.2,
        Wx                 => 0.9922,
        'XML::Writer'      => 0.623,
        'Text::CSV_xs'     => 0.97
    },
    EXE_FILES  => ['queryparser.plx'],
    META_MERGE => {
        resources => {
            license  => 'http://www.gnu.org/licenses/gpl.txt',
            homepage => 'http://code.google.com/p/siebel-gnu-tools/',
            bugtracker =>
              'http://code.google.com/p/siebel-gnu-tools/issues/list',
            repository =>
              'http://code.google.com/p/siebel-gnu-tools/source/browse/'
        },
    },
    dist => { SUFFIX => '.gz', COMPRESS => 'gzip --best' },
    (
        $] >= 5.010
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT =>
'Graphical application to retrieve metadata from columns of a SELECT query',
            AUTHOR => 'Alceu Rodrigues de Freitas Junior <arfreitas@cpan.org>'
          )
        : ()
    ),
    NO_MYMETA => 1,
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ( 'LICENSE' => 'gpl', ) : () )
);

WriteMakefile(%config);

use 5.010001;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Siebel::GNU::Tools',
    'dist'         => { COMPRESS => "gzip", SUFFIX => "gz" },
    'EXE_FILES'    => ['perf_txnrouter.pl'],
    'VERSION_FROM' => 'perf_txnrouter.pl',
    'AUTHOR'       => 'Alceu Rodrigues de Freitas Junior',
    'ABSTRACT' => 'Siebel Transaction Router log parser and chart generator',
    'NO_META'  => 1,
    'MIN_PERL_VERSION' => 5.010000,
    PREREQ_PM          => {
        GD::Graph::lines => 1.15,
        Pod::Usage       => 1.36,
    },
    NO_MYMETA => 1
);


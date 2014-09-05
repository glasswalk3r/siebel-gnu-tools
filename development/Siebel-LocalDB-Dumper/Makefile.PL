use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Siebel::LocalDB::Dumper',
    VERSION_FROM => 'lib/Siebel/LocalDB/Dumper.pm',    # finds $VERSION
    PREREQ_PM    => {
        'Term::Pulse' => 0.04,
        'DBI'         => 1.623,
        'DBD::ODBC'   => 1.43,
        'DBD::SQLite' => 1.37,
        'Moose'       => 2.0801
    },
    BUILD_REQUIRES => {
        'Test::Pod'           => 1.22,
        'Test::Pod::Coverage' => 1.08
    },
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM =>
              'lib/Siebel/LocalDB/Dumper.pm',    # retrieve abstract from module
            AUTHOR => 'Alceu Rodrigues de Freitas Junior <arfreitas@cpan.org>'
          )
        : ()
    ),
    EXE_FILES => ['dumper.pl'],
    dist      => { SUFFIX => '.gz', COMPRESS => 'gzip --best' }
);

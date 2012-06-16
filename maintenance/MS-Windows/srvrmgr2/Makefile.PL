use 5.010001;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Siebel::GNU::Tools',
    'dist'         => { COMPRESS => "gzip", SUFFIX => "gz" },
    'EXE_FILES'    => ['srvrmgr2.pl'],
    'VERSION_FROM' => 'srvrmgr2.pl',
    'AUTHOR'       => 'Alceu Rodrigues de Freitas Junior',
    'ABSTRACT' =>
'wrapper for srvrmgr.exe that cryptographics login and password information',
    'NO_META'          => 1,
    'MIN_PERL_VERSION' => 5.010000,
    PREREQ_PM          => {
        Win32::CryptData => 0.02,
        Term::ReadKey    => 2.30
    },
    NO_MYMETA => 1
);


use 5.014002;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME => 'Devel::AssertOS::OSFeatures::SupportsSiebel',
    VERSION_FROM =>
      'lib/Devel/AssertOS/OSFeatures/SupportsSiebel.pm',    # finds $VERSION
    TEST_REQUIRES => {
        'Test::More' => 0,
        'Test::Pod'  => 1.22
    },
    META_MERGE => {
        resources => {
            license  => 'http://www.gnu.org/licenses/gpl.txt',
            homepage => 'https://github.com/glasswalk3r/siebel-gnu-tools',
            bugtracker =>
              'https://github.com/glasswalk3r/siebel-gnu-tools/issues',
            repository => 'https://github.com/glasswalk3r/siebel-gnu-tools'
        },
    },
    PREREQ_PM => { 'Devel::CheckOS' => 1.71 },
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM => 'lib/Devel/AssertOS/OSFeatures/SupportsSiebel.pm'
            ,    # retrieve abstract from module
            AUTHOR => 'Alceu Rodrigues de Freitas Junior <arfreitas@cpan.org>'
          )
        : ()
    ),
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ( 'LICENSE' => 'gpl', ) : () )
);

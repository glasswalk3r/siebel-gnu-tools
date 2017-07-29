use warnings;
use strict;
use QueryParser::GUI::Controller;
# VERSION

my $controller =
  QueryParser::GUI::Controller->new(
    'config.ini');
my $view = $controller->get_view();
# gets the sections from the INI file to use them as descriptors of the connections
# in the Connection menu
$view->GetTopWindow()
  ->set_conn_menu( [ keys( %{ $controller->get_config() } ) ] );
$view->MainLoop;


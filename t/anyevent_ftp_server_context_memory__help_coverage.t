use Test2::V0 -no_srand => 1;
use Test::AnyEventFTPServer;

my $server = create_ftpserver_ok('Memory');
$server->help_coverage_ok;

done_testing;

#!perl
use strict;
use warnings;
use Test::More tests => 4;
use lib 'lib', "$ENV{HOME}/lab/local/dapple/lib";

use Net::DAAP::Server;
use Net::DAAP::Client;
use HTTP::Daemon;

my $port = 23689;
my $pid = fork;
die "couldn't fork a server $!" unless defined $pid;
unless ($pid) {
    my $server = Net::DAAP::Server->new(path => 't/share');
    my $d = HTTP::Daemon->new( LocalPort => $port, ReuseAddr => 1) || die;

    diag( "server now ready at: ". $d->url );
    while (my $c = $d->accept) {
        while (my $request = $c->get_request) {
            my $response = $server->run($request);
            $c->send_response( $response );
        }
        $c->close;
        undef($c);
    }
    exit;
}

sleep 1; # give it time to warm up
diag( "Now testing" );

my $client = Net::DAAP::Client->new( SERVER_HOST => 'localhost' );
$client->{SERVER_PORT} = $port;
$client->{DEBUG} = 0;

ok( $client->connect, "could connect and grab database" );
my $songs = $client->songs;
is( scalar keys %$songs, 2, "2 songs in the database" );


my @playlists = values %{ $client->playlists };
is( $playlists[0]{'dmap.itemname'}, 'Net::DAAP::Server', 'got main playlist');

my $playlist_tracks = $client->playlist( $playlists[0]{'dmap.itemid'} );
is( scalar @$playlist_tracks, 2, "2 tracks on main playlist" );


undef $client;
kill "TERM", $pid;
waitpid $pid, 0;


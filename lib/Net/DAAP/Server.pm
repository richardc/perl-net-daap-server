package Net::DAAP::Server;
use strict;
use warnings;
use Net::DAAP::Server::Store;
use Net::DAAP::DMAP::Pack qw( dmap_pack );
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw( path _db ));

our $VERSION = '1.21';

=head1 NAME

Net::DAAP::Server - Provide a DAAP Server

=head1 SYNOPSIS

 use Net::DAAP::Server;

 my $server = Net::DAAP::Server->new(path => '/my/mp3/collection');
 my $d = HTTP::Daemon->new(
   LocalAddr => 'localhost',
   LocalPort => 3689,
   ReuseAddr => 1) || die;

 print "Please contact me at: ", $d->url, "\n";
 while (my $c = $d->accept) {
   while (my $request = $c->get_request) {
     my $response = $server->run($request);
     $c->send_response ($response);
   }
   $c->close;
   undef($c);
 }


=head1 DESCRIPTION

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( { @_ } );
    $self->_db( $self->db_class->open( $self->path ) );
    return $self;
}

sub run {
    my $self = shift;
    my $r = shift;
    my (undef, $method, @args) = split m{/}, $r->uri->path;
    $method =~ s/-/_/g; # server-info => server_info
    use YAML;
    print Dump { $method => \@args };
    if ($self->can( $method )) {
        my $response = HTTP::Response->new( 200 );
        $response->content_type( 'application/x-dmap-tagged' );
        $response->content( $self->$method(@args) );
        return $response;
    }

    print "Can't $method: ". $r->uri->path;
    HTTP::Response->new( 500 );
}

sub server_info {
    dmap_pack [[ 'dmap.serverinforesponse' => [
        [ 'dmap.status'             => 200 ],
        [ 'dmap.protocolversion'    => 2 ],
        [ 'daap.protocolversion'    => 1 ],
        [ 'dmap.itemname'           => __PACKAGE__ ],
        [ 'dmap.loginrequired'      => 0 ],
        [ 'dmap.timeoutinterval'    => 1800 ],
        [ 'dmap.supportsautologout' => 0 ],
        [ 'dmap.supportsupdate'     => 0 ],
        [ 'dmap.supportspersistentids' => 0 ],
        [ 'dmap.supportsextensions' => 0 ],
        [ 'dmap.supportsbrowse'     => 0 ],
        [ 'dmap.supportsquery'      => 0 ],
        [ 'dmap.supportsindex'      => 0 ],
        [ 'dmap.supportsresolve'    => 0 ],
        [ 'dmap.databasescount'     => 1 ],
       ]]];
}

sub login {
    dmap_pack [[ 'dmap.loginresponse' => [
        [ 'dmap.status'    => 200 ],
        [ 'dmap.sessionid' => 42 ],
       ]]];
}

sub logout { return }

sub update {
    dmap_pack [[ 'dmap.updateresponse' => [
        [ 'dmap.status' =>  200 ],
        [ 'dmap.serverrevision' => 42 ],
       ]]];
}

sub databases {
    my $self = shift;
    unless (@_) { # all databases
        return dmap_pack [[ 'daap.serverdatabases' => [
            [ 'dmap.status' => 200 ],
            [ 'dmap.updatetype' =>  0 ],
            [ 'dmap.specifiedtotalcount' =>  1 ],
            [ 'dmap.returnedcount' => 1 ],
            [ 'dmap.listing' => [
                [ 'dmap.listingitem' => [
                    [ 'dmap.itemid' =>  35 ],
                    [ 'dmap.persistentid' => '13950142391337751523' ],
                    [ 'dmap.itemname' => __PACKAGE__ ],
                    [ 'dmap.itemcount' => 3 ],
                    [ 'dmap.containercount' =>  6 ],
                   ],
                 ],
               ],
             ],
           ]]];
    }
    my $database_id = shift;
    my $action = shift;
    if ($action eq 'items') {
        return dmap_pack [[ 'daap.databasesongs' => [
            [ 'dmap.status' =>                   200 ],
            [ 'dmap.updatetype' =>                 0 ],
            [ 'dmap.specifiedtotalcount' =>        3 ],
            [ 'dmap.returnedcount' =>              3 ],
            [ 'dmap.listing' => [
                [ 'dmap.listingitem' => [
                    [ 'daap.songalbum'  => '' ],
                    [ 'daap.songartist' => 'Crysler' ],
                    [ 'daap.songcompilation' => 0 ],
                    [ 'daap.songformat' => 'mp3' ],
                    [ 'dmap.itemid' => 36 ],
                    [ 'dmap.itemname' => 'Insomnia - mastered' ],
                    [ 'dmap.persistentid' =>     '13950142391337751539' ],
                    [ 'daap.songsize' =>     4453814 ],
                    [ 'daap.songtrackcount' =>     3 ],
                    [ 'daap.songtracknumber' =>     1 ]
                   ],
                 ],
                [ 'dmap.listingitem' => [
                    [ 'daap.songalbum' =>     '' ],
                    [ 'daap.songartist' =>     'Crysler' ],
                    [ 'daap.songcompilation' =>     0    ],
                    [ 'daap.songformat' =>     'mp3'     ],
                    [ 'dmap.itemid' =>     37            ],
                    [ 'dmap.itemname' =>     'Games - mastered' ],
                    [ 'dmap.persistentid' =>     '13950142391337751540' ],
                    [ 'daap.songsize' => 3436916   ],
                    [ 'daap.songtrackcount' => 3   ],
                    [ 'daap.songtracknumber' => 2  ],
                   ],
                 ],
                [ 'dmap.listingitem' => [
                    [ 'daap.songalbum' => ''   ],
                    [ 'daap.songartist' => 'Crysler'  ],
                    [ 'daap.songcompilation' => 0  ],
                    [ 'daap.songformat' => 'mp3'  ],
                    [ 'dmap.itemid' => 38  ],
                    [ 'dmap.itemname' => 'Your Voice - mastered'  ],
                    [ 'dmap.persistentid' => '13950142391337751541'  ],
                    [ 'daap.songsize' => 6554061  ],
                    [ 'daap.songtrackcount' => 3 ],
                    [ 'daap.songtracknumber' => 3  ]
                   ]
                 ]
               ]
             ],
           ]]];
    }
    if ($action eq 'containers') {
        return dmap_pack [[ 'daap.databaseplaylists' => [
            [ 'dmap.status'              => 200 ],
            [ 'dmap.updatetype'          =>   0 ],
            [ 'dmap.specifiedtotalcount' =>   1 ],
            [ 'dmap.returnedcount'       =>   1 ],
            [ 'dmap.listing'             => [
                [ 'dmap.listingitem' => [
                    [ 'dmap.itemid'       => 39 ],
                    [ 'dmap.persistentid' => '13950142391337751524' ],
                    [ 'dmap.itemname'     => 'richardc (iTunes 4.5 small sample)' ],
                    [ 'dmap.itemcount'    => 3 ],
                   ],
                 ],
               ],
             ],
           ]]];
    }
}


sub db_class { "Net::DAAP::Server::Store" }


1;
__END__


=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright 2004 Richard Clamp.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO


=cut

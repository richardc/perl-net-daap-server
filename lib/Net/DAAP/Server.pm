package Net::DAAP::Server;
use strict;
use warnings;
use POE::Component::Server::HTTP;
use Net::DAAP::Server::Track;
use Net::DAAP::DMAP qw( dmap_pack );
use File::Find::Rule;
use HTTP::Daemon;
use URI::Escape;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw( debug path tracks port httpd uri ));

our $VERSION = '1.21';

=head1 NAME

Net::DAAP::Server - Provide a DAAP Server

=head1 SYNOPSIS

 use POE;
 use Net::DAAP::Server;

 my $server = Net::DAAP::Server->new(
     path => '/my/mp3/collection',
     port => 666,
 );
 $poe_kernel->run;


=head1 DESCRIPTION

=cut

use YAML;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( { tracks => {}, @_ } );
    $self->find_tracks;
    #print Dump $self;
    $self->httpd( POE::Component::Server::HTTP->new(
        Port => $self->port,
        ContentHandler => { '/' => sub { $self->handler(@_) } },
       ) );
    return $self;
}

sub find_tracks {
    my $self = shift;
    for my $file ( find name => "*.mp3", in => $self->path ) {
        my $track = Net::DAAP::Server::Track->new_from_file( $file );
        $self->tracks->{ $track->dmap_itemid } = $track;
    }
}

sub handler {
    my $self = shift;
    my ($request, $response) = @_;

    local $self->{uri};
    $self->uri( $request->uri );
    print $request->uri, "\n" if $self->debug;

    my %params = map { split /=/, $_, 2 } split /&/, $self->uri->query;
    my (undef, $method, @args) = split m{/}, $request->uri->path;
    $method =~ s/-/_/g; # server-info => server_info

    if ($self->can( $method )) {
        my $res = $self->$method( @args );
        #print Dump $res;
        $response->code( $res->code );
        $response->content( $res->content );
        $response->content_type( $res->content_type );
        return $response->code;
    }

    print "Can't $method: ". $self->uri;
    $response->code( 500 );
    return 500;
}

sub _dmap_response {
    my $self = shift;
    my $dmap = shift;
    my $response = HTTP::Response->new( 200 );
    $response->content_type( 'application/x-dmap-tagged' );
    $response->content( dmap_pack $dmap );
    #print Dump $dmap if $self->debug && $self->uri =~/type=photo/;
    return $response;
}

sub server_info {
    my $self = shift;
    $self->_dmap_response( [[ 'dmap.serverinforesponse' => [
        [ 'dmap.status'             => 200 ],
        [ 'dmap.protocolversion'    => 2 ],
        [ 'daap.protocolversion'    => 3 ],
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
       ]]] );
}

sub content_codes {
    my $self = shift;
    $self->_dmap_response( [[ 'dmap.contentcodesresponse' => [
        [ 'dmap.status'             => 200 ],
        map { [ 'dmap.dictionary' => [
            [ 'dmap.contentcodesnumber' => $_->{ID}   ],
            [ 'dmap.contentcodesname'   => $_->{NAME} ],
            [ 'dmap.contentcodestype'   => $_->{TYPE} ],
           ] ] } values %$Net::DAAP::DMAP::Types,
       ]]] );
}

sub login {
    my $self = shift;
    $self->_dmap_response( [[ 'dmap.loginresponse' => [
        [ 'dmap.status'    => 200 ],
        [ 'dmap.sessionid' =>  42 ],
       ]]] );
}

sub logout { HTTP::Response->new( 200 ) }

sub update {
    my $self = shift;
    return HTTP::Response->new( RC_WAIT )
      if $self->uri =~ m{revision-number=42};

    $self->_dmap_response( [[ 'dmap.updateresponse' => [
        [ 'dmap.status'         => 200 ],
        [ 'dmap.serverrevision' =>  42 ],
       ]]] );
}

sub databases {
    my $self = shift;
    unless (@_) { # all databases
        return $self->_dmap_response( [[ 'daap.serverdatabases' => [
            [ 'dmap.status' => 200 ],
            [ 'dmap.updatetype' =>  0 ],
            [ 'dmap.specifiedtotalcount' =>  1 ],
            [ 'dmap.returnedcount' => 1 ],
            [ 'dmap.listing' => [
                [ 'dmap.listingitem' => [
                    [ 'dmap.itemid' =>  35 ],
                    [ 'dmap.persistentid' => '13950142391337751523' ],
                    [ 'dmap.itemname' => __PACKAGE__ ],
                    [ 'dmap.itemcount' => scalar keys %{ $self->tracks } ],
                    [ 'dmap.containercount' =>  1 ],
                   ],
                 ],
               ],
             ],
           ]]] );
    }
    my $database_id = shift;
    my $action = shift;
    if ($action eq 'items') {
        my $tracks = $self->_all_tracks;
        return $self->_dmap_response( [[ 'daap.databasesongs' => [
            [ 'dmap.status' => 200 ],
            [ 'dmap.updatetype' => 0 ],
            [ 'dmap.specifiedtotalcount' => scalar @$tracks ],
            [ 'dmap.returnedcount' => scalar @$tracks ],
            [ 'dmap.listing' => $tracks ]
           ]]] );
    }
    if ($action eq 'containers') {
        return $self->_playlists( @_ );
    }
}

sub _playlists {
    my $self = shift;
    return $self->_playlist_songs( @_ ) if @_ && $_[1] eq 'items';

    my $tracks = $self->_all_tracks;
    $self->_dmap_response( [[ 'daap.databaseplaylists' => [
        [ 'dmap.status'              => 200 ],
        [ 'dmap.updatetype'          =>   0 ],
        [ 'dmap.specifiedtotalcount' =>   1 ],
        [ 'dmap.returnedcount'       =>   1 ],
        [ 'dmap.listing'             => [
            [ 'dmap.listingitem' => [
                [ 'dmap.itemid'       => 39 ],
                [ 'dmap.persistentid' => '13950142391337751524' ],
                [ 'dmap.itemname'     => __PACKAGE__ ],
                [ 'com.apple.itunes.smart-playlist' => 0 ],
                [ 'dmap.itemcount'    => scalar @$tracks ],
               ],
             ],
           ],
         ],
       ]]] );
}

sub _playlist_songs {
    my $self = shift;
    my $tracks = $self->_all_tracks;
    $self->_dmap_response( [[ 'daap.playlistsongs' => [
        [ 'dmap.status' => 200 ],
        [ 'dmap.updatetype' => 0 ],
        [ 'dmap.specifiedtotalcount' => scalar @$tracks ],
        [ 'dmap.returnedcount'       => scalar @$tracks ],
        [ 'dmap.listing' => $tracks ]
       ]]] );
}


# some things are always present in the listings returned, whether you
# ask for them or not
sub always_answer {
    qw( dmap.itemname dmap.itemkind dmap.itemid );
}


sub _all_tracks {
    my $self = shift;
    my @tracks;

    my %chunks = map { split /=/, $_, 2 } split /&/, $self->uri->query;
    my @fields = ($self->always_answer, split /(?:,|%2C)/, $chunks{meta});

    for my $track (values %{ $self->tracks }) {
        my %values = ( com_apple_itunes_smart_playlist => 0, %$track );

        push @tracks, [ 'dmap.listingitem' => [
            map {
                (my $field = $_) =~ s{[.-]}{_}g;
                # kludge
                if ($field eq 'dpap_thumb') {
                    $_ = 'dpap.picturedata';
                    $field = 'dpap_picturedata';
                }
                [ $_ => $track->$field() ]
            } @fields ] ];
    }
    return \@tracks;
}

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

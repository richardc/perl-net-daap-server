package Net::DAAP::Server;
use strict;
use warnings;
use Net::DAAP::Server::Track;
use Net::DAAP::DMAP::Pack qw( dmap_pack );
use File::Find::Rule;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw( path tracks uri ));

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
    my $self = $class->SUPER::new( { tracks => {}, @_ } );
    for my $file ( find name => "*.mp3", in => $self->path ) {
        my $track = Net::DAAP::Server::Track->new_from_file( $file );
        $self->tracks->{ $track->dmap_itemid } = $track;
    }
    use YAML;
    #print Dump $self;
    return $self;
}

sub run {
    my $self = shift;
    my $r = shift;
    my (undef, $method, @args) = split m{/}, $r->uri->path;
    $method =~ s/-/_/g; # server-info => server_info
    use YAML;
    #print Dump { $method => \@args };
    print $r->uri, "\n";
    local $self->{uri} = $r->uri;
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
       ]]];
}

sub content_codes {
    dmap_pack [[ 'dmap.contentcodesresponse' => [
        [ 'dmap.status'             => 200 ],
        map { [ 'dmap.dictionary' => [
            [ 'dmap.contentcodesnumber' => $_->{ID}   ],
            [ 'dmap.contentcodesname'   => $_->{NAME} ],
            [ 'dmap.contentcodestype'   => $_->{TYPE} ],
           ] ] } values %Net::DAAP::DMAP::Pack::types,
       ]]];
}

sub login {
    dmap_pack [[ 'dmap.loginresponse' => [
        [ 'dmap.status'    => 200 ],
        [ 'dmap.sessionid' =>  42 ],
       ]]];
}

sub logout { return }


sub update {
    my $self = shift;
    # XXX hacky - nothing to update - don't answer
    sleep if $self->uri =~ m{revision-number=42};

    dmap_pack [[ 'dmap.updateresponse' => [
        [ 'dmap.status'         => 200 ],
        [ 'dmap.serverrevision' =>  42 ],
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
                    [ 'dmap.itemcount' => scalar keys %{ $self->tracks } ],
                    [ 'dmap.containercount' =>  1 ],
                   ],
                 ],
               ],
             ],
           ]]];
    }
    my $database_id = shift;
    my $action = shift;
    if ($action eq 'items') {
        my $tracks = $self->_all_tracks;
        return dmap_pack [[ 'daap.databasesongs' => [
            [ 'dmap.status' => 200 ],
            [ 'dmap.updatetype' => 0 ],
            [ 'dmap.specifiedtotalcount' => scalar @$tracks ],
            [ 'dmap.returnedcount' => scalar @$tracks ],
            [ 'dmap.listing' => $tracks ]
           ]]];
    }
    if ($action eq 'containers') {
        return $self->_playlists( @_ );
    }
}

sub _playlists {
    my $self = shift;
    return $self->_playlist_songs(@_) if @_ && $_[1] eq 'items';

    return dmap_pack [[ 'daap.databaseplaylists' => [
        [ 'dmap.status'              => 200 ],
        [ 'dmap.updatetype'          =>   0 ],
        [ 'dmap.specifiedtotalcount' =>   1 ],
        [ 'dmap.returnedcount'       =>   1 ],
        [ 'dmap.listing'             => [
            [ 'dmap.listingitem' => [
                [ 'dmap.itemid'       => 39 ],
                [ 'dmap.persistentid' => '13950142391337751524' ],
                [ 'dmap.itemname'     => __PACKAGE__ ],
                [ 'dmap.itemcount'    => 3 ],
               ],
             ],
           ],
         ],
       ]]];
}

sub _all_tracks {
    my $self = shift;
    my @tracks;
    for my $track (values %{ $self->tracks }) {
        push @tracks, [ 'dmap.listingitem' => [
            map {
                (my $field = $_) =~ s{[.-]}{_}g;
                [ $_ => $track->$field() ]
            } $self->wanted_fields,
           ] ];
    }
    return \@tracks;
}

sub wanted_fields {
    my $self = shift;
    $self->uri =~ m{meta=(.*?)&};
    return split /,/, $1;
}

sub _playlist_songs {
    my $self = shift;
    my $tracks = $self->_all_tracks;
    dmap_pack [[ 'daap.playlistsongs' => [
        [ 'dmap.status' => 200 ],
        [ 'dmap.updatetype' => 0 ],
        [ 'dmap.specifiedtotalcount' => scalar @$tracks ],
        [ 'dmap.returnedcount'       => scalar @$tracks ],
        [ 'dmap.listing' => $tracks ]
       ]]];
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

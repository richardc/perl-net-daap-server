package Net::DAAP::Server;
use strict;
use warnings;
use Net::DAAP::Server::Track;
use File::Find::Rule;
use Net::DMAP::Server;
use base qw( Net::DMAP::Server );
__PACKAGE__->mk_accessors(qw( debug path tracks port httpd uri publisher service ));

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

sub protocol { 'daap' }

sub find_tracks {
    my $self = shift;
    for my $file ( find name => "*.mp3", in => $self->path ) {
        my $track = Net::DAAP::Server::Track->new_from_file( $file );
        $self->tracks->{ $track->dmap_itemid } = $track;
    }
}

sub server_info {
    my $self = shift;
    $self->_dmap_response( [[ 'dmap.serverinforesponse' => [
        [ 'dmap.status'             => 200 ],
        [ 'dmap.protocolversion'    => 2 ],
        [ 'daap.protocolversion'    => 3 ],
        [ 'dmap.itemname'           => ref $self ],
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
                    [ 'dmap.itemname' => ref $self ],
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
                [ 'dmap.itemname'     => ref $self ],
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
    qw( dmap.itemkind dmap.itemid dmap.itemname );
}

sub item_field {
    my $self = shift;
    my $track = shift;
    my $field = shift;

    (my $method = $field) =~  s{[.-]}{_}g;
    # kludge
    if ($field =~ /dpap\.(thumb|hires)/) {
        $field = 'dpap.picturedata';
    }

    [ $field => eval { $track->$method() } ]
}

sub response_tracks {
    my $self = shift;
    if ($self->uri =~ /dpap.hires/ && $self->uri =~ /dmap.itemid:(\d+)/) {
        return $self->tracks->{$1};
    }
    return values %{ $self->tracks }
}

sub uniq {
    my %seen;
    return grep { !$seen{$_}++ } @_;
}

sub response_fields {
    my $self = shift;

    my %chunks = map { split /=/, $_, 2 } split /&/, $self->uri->query;
    my @fields = uniq ($self->always_answer, split /(?:,|%2C)/, $chunks{meta});
    return @fields;
}


sub _all_tracks {
    my $self = shift;
    my @tracks;

    my @fields = $self->response_fields;
    for my $track ($self->response_tracks) {
        push @tracks, [ 'dmap.listingitem' => [
            map { $self->item_field( $track => $_ ) } @fields ] ];
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

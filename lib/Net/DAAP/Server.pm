package Net::DAAP::Server;
use strict;
use warnings;
use Net::DAAP::Server::Track;
use File::Find::Rule;
use Storable ();

use base qw( Net::DMAP::Server );
our $VERSION = '0.03';

sub protocol { 'daap' }

sub default_port { 3689 }

# the filename we use to cache in
__PACKAGE__->mk_accessors('cache_file');

# load the cache from disk, if we have a filename
sub load_cache {
    my $self = shift;

    # no cache unless we're asked for one
    return {} unless $self->cache_file;

    my $cache = eval { Storable::retrieve( $self->cache_file ) } || {};
    warn "Error loading cache: $!\n" if $!;

    # we just loaded it, it's clean
    $cache->{_updated} = 0;

    return $cache;
}

# get a Net::DAAP::Server::Track object from a filename, through the cache
# if possible, off disk if not.
sub get_cached_file {
    my ($self, $cache, $filename) = @_;

    # skip annoying mac metadata that takes ages to scan
    return if $filename =~ /\.AppleDouble/;
  
    # useful.
    my @s = stat($filename);

    # it there's a cached copy and it's up to date..
    if (my $c = $cache->{$filename}) {
        return $c->{track} if ($c->{mtime} == $s[9]);
    }

    # the track is either not cached, or not up to date.
    my $track = Net::DAAP::Server::Track->new_from_file( $filename );

    # we changed the cache, mark it as dirty
    $cache->{_updated} = 1;

    # store the mtime as well as the track, so we can notice changes
    $cache->{$filename} = {
        track => $track,
        mtime => $s[9],
    };
  
    return $track;
}

# save the cache to disk, if we have a filename
sub save_cache {
    my ($self, $cache) = @_;
    return unless $self->cache_file;

    # if the cache isn't dirty, don't save it.
    return unless $cache->{_updated};
    
    Storable::store( $cache, $self->cache_file );
}

sub find_tracks {
    my $self = shift;

    #print STDERR "loading cache..\n";
    my $cache = $self->load_cache;

    #print STDERR "scanning for files..\n";
    my @files = find name => [ "*.mp3", "*.m4p", "*.m4a" ], in => $self->path;

    #print STDERR "adding files..\n";
    for my $file ( @files ) {
        my $track = $self->get_cached_file( $cache, $file ) or next;
        $self->tracks->{ $track->dmap_itemid } = $track;
    }

    #print STDERR "saving cache..\n";
    $self->save_cache($cache);

    #print STDERR "ready..\n";
    
}

sub server_info {
    my ($self, $request, $response) = @_;
    $response->content( $self->_dmap_pack(
        [[ 'dmap.serverinforesponse' => [
            [ 'dmap.status'             => 200 ],
            [ 'dmap.protocolversion'    => 2 ],
            [ 'daap.protocolversion'    =>
                $request->header('Client-DAAP-Version') ],
            [ 'dmap.itemname'           => $self->name ],
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
           ]]] ));
}


1;
__END__

=head1 NAME

Net::DAAP::Server - Provide a DAAP Server

=head1 SYNOPSIS

 use POE;
 use Net::DAAP::Server;

 my $server = Net::DAAP::Server->new(
     path => '/my/mp3/collection',
     port => 666,
     name => "Groovy hits of the 80's",
 );
 $poe_kernel->run;


=head1 DESCRIPTION

Net::DAAP::Server takes a directory of mp3 files and makes it
available to iTunes and work-alikes which can use the Digital Audio
Access Protocol

=head1 METHODS

=head2 new

Creates a new daap server, takes the following arguments

=over

=item path

A directory that will be scanned for *.mp3 files to share.

=item name

The name of your DAAP share, will default to a combination of the
module name, hostname, and process id.

=item port

The port to listen on, will default to the default port, 3689.

=back

=head1 CAVEATS

Currently only shares .mp3 files.

Doesn't support playlists.

You can't skip around the playing track - I need to figure out how
this works against iTunes servers.

=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright 2004 Richard Clamp.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

Net::DAAP::Client

=cut

package Net::DAAP::Server;
use strict;
use warnings;
use Net::DAAP::Server::Track;
use File::Find::Rule;
use Net::DMAP::Server;
use base qw( Net::DMAP::Server );

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

sub protocol { 'daap' }

sub find_tracks {
    my $self = shift;
    for my $file ( find name => "*.mp3", in => $self->path ) {
        my $track = Net::DAAP::Server::Track->new_from_file( $file );
        $self->tracks->{ $track->dmap_itemid } = $track;
    }
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


=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright 2004 Richard Clamp.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO


=cut

package Net::DAAP::Server;
use strict;
use warnings;
use Net::DAAP::Server::Store;
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

sub db_class { "Net::DAAP::Server::Store" }


1;
__END__


=head1 AUTHOR

Richard Clamp <richardc@unixbeard.net>

=head1 COPYRIGHT

Copyright 2004 Richard Clamp.  All Rights Reserved.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO


=cut

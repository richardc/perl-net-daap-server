package Net::DAAP::Server::Track;
use strict;
use warnings;
use base qw( Class::Accessor::Fast );
use MP3::Info;

__PACKAGE__->mk_accessors(qw(
      file

      dmap_itemid dmap_itemname dmap_itemkind dmap_persistentid
      daap_songalbum daap_songartist daap_songbitrate
      daap_songbeatsperminute daap_songcomment daap_songcompilation
      daap_songcomposer daap_songdateadded daap_songdatemodified
      daap_songdisccount daap_songdiscnumber daap_songdisabled
      daap_songeqpreset daap_songformat daap_songgenre
      daap_songdescription daap_songrelativevolume daap_songsamplerate
      daap_songsize daap_songstarttime daap_songstoptime daap_songtime
      daap_songtrackcount daap_songtracknumber daap_songuserrating
      daap_songyear daap_songdatakind daap_songdataurl
      com_apple_itunes_norm_volume
     ));

my $i;
sub new_from_file {
    my $class = shift;
    my $file = shift;
    my $self = $class->new({ file => $file });
    print "Adding $file\n";

    my $tag = MP3::Info->new( $file );

    $self->dmap_itemid( ++$i );
    $self->dmap_itemname( $tag->title );
    $self->dmap_itemkind( 2 ); # music
    $self->dmap_persistentid( undef ); # blah, this should be some 64 bit thing
    $self->daap_songalbum( $tag->album );
    $self->daap_songartist( $tag->artist );
    $self->daap_songbitrate( $tag->bitrate );
    $self->daap_songbeatsperminute( undef );
    $self->daap_songcomment( $tag->comment );
    # from blech:
    # if ($rtag->{TCP} || $rtag->{TCMP}) {
    #     $artist = 'various artists';
    # }
    #
    $self->daap_songcompilation( 0 );
    # $self->daap_songcomposer( );
    $self->daap_songdateadded( (stat $file)[10] );
    $self->daap_songdatemodified( (stat _)[9] );
    # $self->daap_songdisccount( );
    # $self->daap_songdiscnumber( );
    # $self->daap_songdisabled( );
    # $self->daap_songeqpreset( );
    $file =~ m{\.(.*?)$};
    $self->daap_songformat( $1 );
    # $self->daap_songgenre( );
    # $self->daap_songdescription( );
    # $self->daap_songrelativevolume( );
    # $self->daap_songsamplerate( );
    $self->daap_songsize( -s $file );
    # $self->daap_songstarttime( );
    # $self->daap_songstoptime( );
    # $self->daap_songtime( );
    my ($number, $count) = split m{/}, $tag->tracknum;
    $self->daap_songtrackcount( $number );
    $self->daap_songtracknumber( $count );
    # $self->daap_songuserrating( );
    $self->daap_songyear( $tag->year );
    # $self->daap_songdatakind( );
    # $self->daap_songdataurl( );
    # $self->com_apple_itunes_norm_volume( );

    return $self;
}

1;



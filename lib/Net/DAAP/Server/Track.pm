package Net::DAAP::Server::Track;
use strict;
use warnings;
use base qw( Class::Accessor::Fast );
use MP3::Info;
use MP4::Info;
use Perl6::Slurp;
use File::Basename qw(basename);

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

      daap_songgrouping daap_songcodectype daap_songcodecsubtype
      com_apple_itunes_itms_songid com_apple_itunes_itms_artistid
      com_apple_itunes_itms_playlistid com_apple_itunes_itms_composerid
      com_apple_itunes_itms_genreid
      dmap_containeritemid
     ));

sub new_from_file {
    my $class = shift;
    my $file = shift;
    my $self = $class->new({ file => $file });
    print "Adding $file\n";


    my @stat = stat $file;
    $self->dmap_itemid( $stat[1] ); # the inode should be good enough
    $self->dmap_containeritemid( 0+$self );

    $self->dmap_itemkind( 2 ); # music
    $self->dmap_persistentid( $stat[1] ); # blah, this should be some 64 bit thing
    $self->daap_songbeatsperminute( 0 );

    # All mp3 files have 'info'. If it doesn't, give up, we can't read it.
    my ($info, $tag, $type);
    if ($file =~ m/\.mp3$/) {
      $info = MP3::Info::get_mp3info($file) or return;
      $tag = MP3::Info::get_mp3tag( $file ) || {};
      $type = 'MP3';
    } elsif ($file =~ m/\.m4[ap]$/) {
      $info = MP4::Info::get_mp4info($file) or return;
      $tag = MP4::Info::get_mp4tag( $file ) || {};
      $type = 'AAC';
    }

    $self->daap_songbitrate( $info->{BITRATE} );
    $self->daap_songsamplerate( $info->{FREQUENCY} * 1000 );
    $self->daap_songtime( $info->{SECS} * 1000 );

    # read the tag if we can, fall back to very simple data otherwise.
    $self->dmap_itemname( $tag->{TITLE} || basename($file, ".mp3") );
    $self->daap_songalbum( $tag->{ALBUM} );
    $self->daap_songartist( $tag->{ARTIST} );
    $self->daap_songcomment( $tag->{COMMENT} );
    $self->daap_songyear( $tag->{YEAR} || undef );

    my ($trackno, $trackco, $comp, $discno, $discco);

    if ($type eq 'MP3') {
      # we need more info from the file if we're going to determine these 
      my $rtag = MP3::Info::get_mp3tag( $file, 2, 1 ) || {};

      ($trackno, $trackco) = split m{/}, ($tag->{TRACKNUM} || "");
      $comp = ($rtag->{TCP} || $rtag->{TCMP}) ? 1 : 0;
      ($discno, $discco) = split m{/}, ($rtag->{TPA} || $rtag->{TPOS} || ""); 
      # TODO this is getting set right, but when it's passed into 
      # $self->daap_songdiscnumber it doesn't work, even though AAC disc 
      # info does. Very odd.
    }

    if ($type eq 'AAC') {
      $trackco = $tag->{TRKN}->[1];
      $trackno = $tag->{TRKN}->[0];
      $comp    = $tag->{CPIL};
      $discco  = $tag->{DISK}->[1];
      $discno  = $tag->{DISK}->[0];
    }    

    $self->daap_songtrackcount( $trackco || 0 );
    $self->daap_songtracknumber( $trackno || 0);
    $self->daap_songcompilation( $comp || 0);
    $self->daap_songdisccount( $discco || 0);
    $self->daap_songdiscnumber( $discno || 0);

    # $self->daap_songcomposer( );
    $self->daap_songdateadded( $stat[10] );
    $self->daap_songdatemodified( $stat[9] );
    $self->daap_songdisabled( 0 );
    $self->daap_songeqpreset( '' );
    $file =~ m{\.(.*?)$};
    $self->daap_songformat( $1 );
    $self->daap_songgenre( '' );
    $self->daap_songgrouping( '' );
    # $self->daap_songdescription( );
    # $self->daap_songrelativevolume( );
    $self->daap_songsize( -s $file );
    $self->daap_songstarttime( 0 );
    $self->daap_songstoptime( 0 );

    $self->daap_songuserrating( 0 );
    $self->daap_songdatakind( 0 );
    # $self->daap_songdataurl( );
    $self->com_apple_itunes_norm_volume( 17502 );

    # $self->daap_songcodectype( 1836082535 ); # mp3?
    # $self->daap_songcodecsubtype( 3 ); # or is this mp3?

    return $self;
}

sub data {
    my $self = shift;
    scalar slurp $self->file;
}

1;



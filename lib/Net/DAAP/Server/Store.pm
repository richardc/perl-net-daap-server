package Net::DAAP::Server::Store;
use strict;
use warnings;
use base qw( Class::Persist );
__PACKAGE__->mk_accessors(qw( path ));
use File::Find::Rule;
use MP3::Info;
require Net::DAAP::Server::Store::Item;

my @modules;
sub simple_db_spec {
    my $class = shift;
    push @modules, $class;
    $class->SUPER::simple_db_spec( @_ );
}

sub create_database {
    my $self = shift;
    $self->setup_DB_infrastructure;
    $_->create_table for @modules;
}

sub open {
    my $self = shift;

    unlink $self->database_file;
    my $dbh = DBI->connect('dbi:SQLite:'.$self->database_file, '', '', {
        RaiseError => 1,
        PrintError => 0,
    }) or die "dbi connect ".$self->database_file ." ".DBI->errstr;
    Class::Persist->dbh( $dbh );

    $self->create_database;
    for my $file (find( name => "*.mp3", in => $self->path)) {
        print "Scanning $file\n";
        my $tag = MP3::Info->new( $file );
        use YAML;
        print Dump $tag;
    }
}

sub database_file {
    my $self = shift;
    $self->path . '/net-daap-server.db';
}

1;

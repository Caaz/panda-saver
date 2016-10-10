#!/usr/bin/perl
use warnings;
use strict;

use WebService::Pandora;
use MP3::Tag;
use LWP::Simple;

my %config = ();
my @config_keys = ('directory','email','password');

sub getInput($) { print "\e[33m$_[0]\e[39m"; my $i; chomp($i = <STDIN>); return $i; }
sub stringifyArray($) { return '['.(join ", ", @{$_[0]}).']'; }
sub touchDir($) { if(!-e $_[0]) { print "\e[90mCreating directory: $_[0]\e[39m\n"; mkdir($_[0]) or die $!; } }
sub fall {
  if($config{downloading}) { print "\e[91m\nRemoving partial file: $config{downloading}\e[39m\n"; unlink($config{downloading}); }
  exit 0;
}
sub writeTags {
  my $track = shift;
  my $mp3 = MP3::Tag->new(shift); # create object
  # $mp3->get_tags(); # read tags
  $mp3->new_tag("ID3v1");
  if (exists $mp3->{ID3v1}) {
    $mp3->{ID3v1}->title($track->{songName});
    $mp3->{ID3v1}->artist($track->{artistName});
    $mp3->{ID3v1}->album($track->{albumName});
    $mp3->{ID3v1}->write_tag();
  }
  $mp3->close(); # destroy object
}
sub save($) {
  my $track = $_[0];
  if($track->{audioUrl} && $track->{songName} && $track->{artistName} && $track->{albumName}) {
    touchDir($config{directory});
    touchDir(join "/", ($config{directory},$track->{artistName}));
    touchDir(join "/", ($config{directory},$track->{artistName},$track->{albumName}));
    my $extension = $track->{audioUrl};
    $extension =~ s/^.*(\.[^.]{3})\?.*$/$1/gs;
    $config{downloading} = (join "/", ($config{directory},$track->{artistName},$track->{albumName},$track->{songName}.$extension));
    print "\e[94mSaving $config{downloading}\e[39m\n";
    getstore($track->{audioUrl},$config{downloading});
    writeTags($track,$config{downloading});
  }
}
foreach('ABRT','QUIT','KILL','INT','ABRT','HUP') { $SIG{$_} = \&fall; }
# Set configuration
for(my $i = 0; $i < @ARGV; $i++){ $config{$config_keys[$i]} = $ARGV[$i]; }
for my $key (@config_keys) { $config{$key} = getInput("$key: ") if(!$config{$key}); }
$config{directory} =~ s/\/$//gs;
# Login
my $pandora = WebService::Pandora->new( username => $config{email}, password => $config{password} );
$pandora->login() or die( $pandora->error() );
# Get Station List
my $result = $pandora->getStationList();
die( $pandora->error() ) if ( !$result );
my @stations = @{$result->{'stations'}};
for (my $i = 0; $i < @stations; $i++) { print "$i: \e[36m$stations[$i]->{stationName}\e[39m\n"; }
# Choose a station
while(!$config{station}) {
  my $choice = getInput("Choose a station by number: ");
  if(($choice > 0) && ($choice < @stations)) { $config{station} = $choice; }
  else { print "Invalid Selection.\n"; }
}
# Get playlist from station choice
while() {
  $result = $pandora->getPlaylist( stationToken => $stations[$config{station}]->{stationToken} );
  die $pandora->error() if ( !$result );
  foreach my $track ( @{$result->{'items'}} ) { save($track); }
}
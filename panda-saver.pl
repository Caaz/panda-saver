#!/usr/bin/perl
use warnings;
use strict;

use WebService::Pandora;
use WebService::Pandora::Partner::Android;
use MP3::Tag;
use MP3::Info;
use LWP::Simple;

my %config = ();
my @config_keys = ('directory','email','password');

sub getInput($) { print "\e[33m$_[0]\e[39m"; my $i; chomp($i = <STDIN>); return $i; }
sub stringifyArray($) { return '['.(join ", ", @{$_[0]}).']'; }
sub touchDir($) { if(!-e $_[0]) { print "\e[90mCreating directory: $_[0]\e[39m\n"; mkdir($_[0]) or die $!; } }
sub sanitize { my $text = shift; $text =~ s/[\/&]/_/gs; return $text; }
sub fall {
  if($config{downloading}) { print "\e[91m\nRemoving partial file: $config{downloading}\e[39m\n"; unlink($config{downloading}); }
  exit 0;
}
sub writeTags {
  my $track = shift;
  my $mp3 = MP3::Tag->new(shift);
  $mp3->new_tag("ID3v1");
  if (exists $mp3->{ID3v1}) {
    $mp3->{ID3v1}->title($track->{songName});
    $mp3->{ID3v1}->artist($track->{artistName});
    $mp3->{ID3v1}->album($track->{albumName});
    $mp3->{ID3v1}->write_tag();
  }
  $mp3->close();
}
sub countdown($) {
  #countdown(seconds);
  my ($duration) = @_;
  my $end_time = time + $duration;
  my $time = time;
  while ($time < $end_time) {
    $time = time;
    printf("\r\e[92mSaved. Waiting %02d:%02d:%02d to simulate playing the track.\e[39m", ($end_time - $time) / (60*60), ($end_time - $time) / (60) % 60, ($end_time - $time) % 60);
    $|++;
    sleep 1;
  }
  print "\n";
}
sub save($) {
  my $track = $_[0];
  if($track->{audioUrl} && $track->{songName} && $track->{artistName} && $track->{albumName}) {
    my @folders = ($track->{artistName},$track->{albumName});
    for(@folders) { $_ = sanitize($_); }
    touchDir(join "/", ($config{directory},$folders[0]));
    touchDir(join "/", ($config{directory},$folders[0],$folders[1]));
    my $extension = $track->{audioUrl};
    $extension =~ s/^.*(\.[^.]{3})\?.*$/$1/gs;
    my $filename = $track->{songName}.$extension;
    $filename = sanitize($filename);
    $config{downloading} = (join "/", ($config{directory},$folders[0],$folders[1],$filename));
    if(!-e $config{downloading}) {
      print "\e[94mSaving $config{downloading}\e[39m\n";
      my $started = time;
      getstore($track->{audioUrl},$config{downloading});
      writeTags($track,$config{downloading});
      my $info = get_mp3info($config{downloading});
      delete $config{downloading};
      my $waitTime = $info->{SECS}-(time-$started);
      if($waitTime > 0) {
        countdown($waitTime);
      }
    }
  }
}
sub login($) {
  my %c = %{$_[0]};
  my $p = WebService::Pandora->new(
    username => $c{email},
    password => $c{password},
    # partner => WebService::Pandora::Partner::Android->new()
  );
  $p->login() or die( $p->error() );
  return $p;
}
foreach('ABRT','QUIT','KILL','INT','ABRT','HUP') { $SIG{$_} = \&fall; }
# Set configuration
for(my $i = 0; $i < @ARGV; $i++){ $config{$config_keys[$i]} = $ARGV[$i]; }
for my $key (@config_keys) { $config{$key} = getInput("$key: ") if(!$config{$key}); }
$config{directory} =~ s/\/$//gs;
touchDir($config{directory});
# Login
my $pandora = login(\%config);
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
  if ( !$result ) {
    my $error = $pandora->error();
    if($error =~ /error 13\:/) {
      # Connectivity / Bad Sync Time.
      print "Bad sync time! Attempting to re-log in.\n";
      $pandora = login(\%config);
    } else {
      die $error;
    }
  } else {
    foreach my $track ( @{$result->{'items'}} ) { save($track); }
  }
}

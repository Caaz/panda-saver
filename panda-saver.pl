#!/usr/bin/perl
use warnings;
use strict;
use WebService::Pandora;
use WebService::Pandora::Partner::Android;
use MP3::Tag;
use MP3::Info;
use LWP::Simple;
MP3::Tag->config(write_v24 => 'TRUE');
my %config = ();
my @config_keys = ('directory','email','password');

sub dlThread( $ $ ) {
  my ($pidList,$station) = (shift,shift);
  my $pid = fork;
  if(!$pid) {
    my $pandora = login();
    while() {
      my $result = $pandora->getPlaylist( stationToken => $station );
      if ( !$result ) {
        my $error = $pandora->error();
        if($error =~ /error 13\:/) { $pandora = login(); } else { die $error; }
      } else { foreach my $track ( @{$result->{'items'}} ) { save($track); } }
    }
  } else { push(@{$pidList},$pid); }
}
sub getInput($) { print "\e[33m$_[0]\e[39m"; my $i; chomp($i = <STDIN>); return $i; }
sub stringifyArray($) { return '['.(join ", ", @{$_[0]}).']'; }
sub touchDir($) { if(!-e $_[0]) { print "\e[90mCreating directory: $_[0]\e[39m\n"; mkdir($_[0]) or die $!; } }
sub sanitize($) { my $text = shift; $text =~ s/[\/&]/_/gs; return $text; }
sub writeTags( $ $ ) {
  my $track = shift;
  my $mp3 = MP3::Tag->new(shift);
  $mp3->new_tag("ID3v2");
  $mp3->update_tags({title => $track->{trackName}, artist => $track->{artistName}, album => $track->{albumName},});
  $mp3->close();
}
sub countdown( $ $ ) {
  my ($end,$text) = (time + shift,shift);
  for(my $r = $end - time; $r > 0; $r = ($end - time)) { sleep(1); }
    # printf("\r\e[90m%s %02d:%02d:%02d\e[39m", $text, $r / (60*60), $r / (60) % 60, $r % 60) and $|++;
  # }
  # print "\r" and $|++;
}
sub waitFor( $ $ $ ) {
  my $info = get_mp3info(shift);
  my $waitTime = $info->{SECS}-shift;
  countdown($waitTime, shift) if($waitTime > 0);
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
    my $file = $config{downloading};
    my $offset = 0;
    my $text = "Simulating playhead...";
    if(!-e $config{downloading}) {
      print "\e[32mSaving $config{downloading}\e[39m\n";
      my $started = time;
      getstore($track->{audioUrl},$config{downloading});
      print "\e[92mSaved: $config{downloading}\e[39m\n";
      writeTags($track,$config{downloading});
      $offset = (time-$started);
    } else { $text = "Skipping $track->{songName} by $track->{artistName}..."; }
    delete $config{downloading};
    waitFor($file,$offset,$text);
  }
}
sub login() {
  my $p = WebService::Pandora->new(username => $config{email}, password => $config{password});
  $p->login() or die( $p->error() ); return $p;
}
# Set configuration
for(my $i = 0; $i < @ARGV; $i++){ $config{$config_keys[$i]} = $ARGV[$i]; }
for my $key (@config_keys) { $config{$key} = getInput("$key: ") if(!$config{$key}); }
$config{directory} =~ s/\/$//gs; touchDir($config{directory});
# Login
my $pandora = login();
# Get Station List
my $result = $pandora->getStationList();
die( $pandora->error() ) if ( !$result );
my @stations = @{$result->{'stations'}};
for (my $i = 0; $i < @stations; $i++) { print "$i: \e[36m$stations[$i]->{stationName}\e[39m\n"; }
# Choose a station
@{$config{stations}} = ();
while() {
  my $choice = getInput("Add a station by number (-1 to stop adding stations): ");
  if(($choice >= 0) && ($choice < @stations)) { push(@{$config{stations}},$choice); }
  else { last; }
}
my @pids;
my @kills = ('ABRT','QUIT','KILL','INT','ABRT','HUP');
for(@kills) { $SIG{$_} = sub  {
  if($config{downloading}) { print "\n\e[91mRemoving partial: $config{downloading}\e[39m"; unlink($config{downloading}); }
  print "\e[39m\n" and exit 0;
}; }
for my $station (@{$config{stations}}) {
  print "Creating thread for $stations[$station]->{stationName} - $stations[$station]->{stationToken}\n";
  dlThread(\@pids,$stations[$station]->{stationToken});
}
for(@kills) { $SIG{$_} = sub { for (@pids) { kill('TERM', $_); } exit 1; }; }
while((my $death = waitpid(-1, 0)) and (@pids > 0)) {
  print "Thread $death has died. removing it from pids. Length Before:".(@pids+0);
  @pids = grep { $_ != $death } @pids;
  print " Length After: ".(@pids+0)."\n";
}

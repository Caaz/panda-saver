#!/usr/bin/perl
use warnings;
use strict;
use WebService::Pandora;
use MP3::Tag;
use MP3::Info;
use LWP::Simple;
use File::Path qw(make_path);
use Cwd 'abs_path';
use Term::ReadKey;
use constant {
  RESET => 0, BOLD => 1, DIM => 2, RED => 31, GREEN => 32, YELLOW => 33, BLUE => 34, MAGENTA => 35, CYAN => 36, GRAY => 90,
  LIGHT_GRAY => 37, LIGHT_RED => 91, LIGHT_GREEN => 92, LIGHT_YELLOW => 93, LIGHT_BLUE => 94, LIGHT_MANGENTA => 95, LIGHT_CYAN => 96
};
my $id = 1;
my %config = ();
sub say($$) { print "\e[".shift.'m'.shift."\e[".RESET."m\n"; }
sub display($$) { print "\e[0;0H".(($id)?"\e[".$id."B\e[K":"")."\e[K\e[".shift.'m'.shift."\e[".RESET."m\n"; }
sub status($$) { print "\e[0;0H\e[".shift.'m'.shift."\e[K\e[".RESET."m\n"; }
sub sanitize($) { my $text = shift; $text =~ s/[\/]/_/gs; return $text; }
sub handleError($$) { my ($r, $p) = @_; die $p->error if(!$r); return $r; }
sub getInput($$) { my $i = shift; print "\e[".YELLOW.'m'.shift.":\e[".RESET."m"; chomp($$i = <STDIN>); }
sub login($) {
  my $p = shift;
  ${$p} = WebService::Pandora->new(username => $config{email}, password => $config{password});
  ${$p}->login() or die( ${$p}->error() );
}
sub dlThread($$) {
  my ($pidList,$station) = @_;
  my $pid = fork;
  if(!$pid) {
    my $wait = $id*5;
    display(GRAY,"Waiting $wait seconds before logging in...");
    sleep($wait);
    my $pandora;
    login(\$pandora);
    while() {
      my $result = getPlaylist($pandora, $station);
      if ( !$result ) {
        my $error = $pandora->error();
        if($error =~ /error 13\:/) { login(\$pandora); } else { die $error; }
      } else {
        my $waitTime = 0;
        for my $track (@{$result->{'items'}}) {
          my ($file,$offset) = save($track);
          $waitTime += get_mp3info($file)->{SECS}-$offset if(defined $file && defined $offset);
        }
        while($waitTime-- > 0) { display(GRAY,"Waiting ".int($waitTime)." seconds to simulate playhead..."); sleep(1); }
      }
    }
  } else { push(@{$pidList},$pid); $id++; }
}
sub save($) {
  my $track = shift;
  return if !($track->{additionalAudioUrl} && $track->{songName} && $track->{artistName} && $track->{albumName});
  # Make folders
  my $path = join "/", ($config{directory}, sanitize($track->{artistName}), sanitize($track->{albumName}));
  for(make_path($path)) { display(GRAY,"Directory Created: $_"); }
  # URL to download from
  my $url = $track->{additionalAudioUrl};
  # Get Extension
  my $extension = $url;
  $extension =~ s/^.*(\.[^.]{3})\?.*$/$1/gs;
  $config{downloading} = $path.'/'.sanitize($track->{songName}.$extension);
  my $file = $config{downloading};
  my $offset = 0;
  if(!-e $config{downloading}) {
    display(GREEN,"Saving $config{downloading}");
    my $started = time;
    my $rc = getstore($url,$config{downloading});
    if (is_error($rc)) {
      warn "Download failed with $rc";
    } else {
      display(LIGHT_GREEN,"Saved $config{downloading}");
      writeTags($track,$config{downloading});
      $offset = (time-$started);
    }
  }
  delete $config{downloading};
  return ($file, $offset);
}
sub writeTags($$) {
  my $track = shift;
  my $mp3 = MP3::Tag->new(shift);
  $mp3->new_tag("ID3v2");
  $mp3->update_tags({title => $track->{trackName}, artist => $track->{artistName}, album => $track->{albumName},});
  $mp3->close();
}
sub getPlaylist($$) {
  my ($self,$stationToken) = @_;
  if ( !defined( $stationToken ) ) { $self->error( 'A stationToken must be specified.' ); return; }
  my $method = WebService::Pandora::Method->new(
    name => 'station.getPlaylist', partnerAuthToken => $self->{'partnerAuthToken'},
    userAuthToken => $self->{'userAuthToken'}, partnerId => $self->{'partnerId'},
    userId => $self->{'userId'}, syncTime => $self->{'syncTime'},
    host => $self->{'partner'}{'host'}, ssl => 0, encrypt => 1,
    cryptor => $self->{'cryptor'}, timeout => $self->{'timeout'},
    params => { 'stationToken' => $stationToken, 'additionalAudioUrl' => 'HTTP_128_MP3', } );
  my $ret = $method->execute();
  if ( !$ret ) { $self->error( $method->error() ); return; }
  return $ret;
}
print "\033]0;Panda\007"."\e[0;0H"."\033[2J"."\e[?25l";
MP3::Tag->config(write_v24 => 'TRUE');
my @config_keys = ('directory','email');
for(my $i = 0; $i < @ARGV; $i++){ $config{$config_keys[$i]} = $ARGV[$i]; }
for my $key (@config_keys) { getInput(\$config{$key},$key) if(!$config{$key}); }
print "\e[".YELLOW."mpassword:\e[".RESET."m";
ReadMode('noecho'); chomp($config{password} = <STDIN>); ReadMode(0); print "\n";
$config{directory} =~ s/^\~/$ENV{HOME}/gs;
$config{directory} =~ s/\/$//gs;

my $pandora;
login(\$pandora);
my $result = handleError($pandora->getStationList(), $pandora);
my @stations = @{$result->{'stations'}};
for (my $i = 0; $i < @stations; $i++) { print "$i: \e[36m$stations[$i]->{stationName}\e[39m\n"; }
@{$config{stations}} = ();
while() {
  my $choice;
  getInput(\$choice, "Add a station by number (-1 to stop adding stations): ");
  if(($choice >= 0) && ($choice < @stations)) { push(@{$config{stations}},$choice); }
  else { last; }
}
print "\033[2J";
my @pids;
my @kills = ('ABRT','QUIT','KILL','INT','ABRT','HUP');
for(@kills) { $SIG{$_} = sub { if($config{downloading}) { display(RED,"Removing Partial: $config{downloading}"); unlink($config{downloading}); } }; }
for my $station (@{$config{stations}}) {
  status(DIM, "Creating thread for $stations[$station]->{stationName}");
  dlThread(\@pids,$stations[$station]->{stationToken});
}
status(BLUE, "Panda");
for(@kills) { $SIG{$_} = sub { for (@pids) { kill('TERM', $_); } print "\e[0;0H"."\033[2J"."\e[?25h"; exit 1; }; }
while((my $death = waitpid(-1, 0)) and (@pids > 0)) { status(RED,"Thread $death has died. ".(@pids-1)." children left"); @pids = grep { $_ != $death } @pids; }

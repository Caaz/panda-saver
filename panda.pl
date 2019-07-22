#!/usr/bin/perl
use warnings;
use strict;
use WebService::Pandora;
use WebService::Pandora::Partner::Android;
use MP3::Tag;
use MP3::Info;
use LWP::Simple;
use File::Path qw(make_path);
use Cwd 'abs_path';
use constant {
  RESET => 0, BOLD => 1, DIM => 2, RED => 31, GREEN => 32, YELLOW => 33, BLUE => 34, MAGENTA => 35, CYAN => 36, GRAY => 90,
  LIGHT_GRAY => 37, LIGHT_RED => 91, LIGHT_GREEN => 92, LIGHT_YELLOW => 93, LIGHT_BLUE => 94, LIGHT_MANGENTA => 95, LIGHT_CYAN => 96
};
my (%self, %config, %commands, @threads);
sub clear() { print "\033[2J"; }
sub say($$) { print "\e[".shift.'m'.shift."\e[".RESET."m\n"; }
sub sanitize($) { my $text = shift; $text =~ s/[\/]/_/gs; return $text; }
sub handleError($$) { my ($r, $p) = @_; died($p->error) if(!$r); return $r; }
sub toClock($) { my $t = shift; return sprintf('%02s:%02s',int($t/60), $t%60); }
sub getInput($) {my $i; print "\e[".YELLOW.'m'.shift.": \e[".RESET."m"; chomp($i = <STDIN>); return $i; }
sub waitFor($$) { for(my ($wait,$text) = @_; $wait-- > 0; sleep 1) { display(DIM,sprintf($text,toClock($wait))); } }
sub display($$) {
  # Clear second line
  # print "\e[0;0H".(($self{line})?"\e[".($self{line}*2)."B":"")."\e[K";
  # Clear first line.
  print "\e[0;0H".(($self{line})?"\e[".($self{line})."B":"")."\e[K\e[".shift.'m'.getName().' '.shift."\e[".RESET."m\n";
}
sub mkChild($$) { my ($m,%c) = (shift,%{shift()}); $c{line} = @{$m}+1; my $pid = fork; if($pid) { push(@{$m},$pid); } else { $c{block}(\%c); } }
sub getBool($) { my ($q,$r) = (shift,''); while($r =~ /^$/) { my $i = getInput("$q [y/n]"); $r = ($i=~/^y/i)?1:($i=~/^n/i)?0:''; } return $r; }
sub died($) { display(RED,(split /\n/, shift)[0]); exit; }
sub getName() {
  if($self{name}) { my $name; ($name = $self{name}) =~ s/ Radio$//gs; return sprintf('%15.15s %5d %5d', $name, $self{downloaded},$self{skips}); }
  return sprintf('%15.15s %s', 'Panda', 'Saves Skips');
}
sub login() {
  display(DIM,"Logging in...");
  my $p = WebService::Pandora->new(username => $config{email}, password => $config{password},partner => WebService::Pandora::Partner::Android->new());
  $p->login() or died( $p->error() );
  display(LIGHT_GREEN,"Logged in!");
  return $p;
}
sub writeTags($$) {
  my $track = shift; my $mp3 = MP3::Tag->new(shift); $mp3->new_tag("ID3v2");
  $mp3->update_tags({title => $track->{songName}, artist => $track->{artistName}, album => $track->{albumName},});
  $mp3->close();
}
sub getPlaylist($$) {
  display(DIM,"Getting playlist.");
  my ($self,$stationToken) = @_;
  if(!$stationToken) { display(RED,"No stationToken provided."); return; }
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
sub getConfig() {
  MP3::Tag->config(write_v24 => 'TRUE');
  my @keys = ('directory','email');
  for(my $i = 0; $i < @ARGV; $i++){ $config{$keys[$i]} = $ARGV[$i]; }
  for my $key (@keys) { $config{$key} = getInput($key) if(!$config{$key}); }
  print "\e]0;Panda\007"."\e[?25l\e[".YELLOW."mpassword: \e[8m";
  chomp($config{password} = <STDIN>);
  $config{directory} =~ s/^\~/$ENV{HOME}/gs;
  $config{directory} =~ s/\/$//gs;
  clear();
}
sub thread($) {
  %self = %{shift()};
  $self{downloaded} = 0;
  $self{skips} = 0;
  $self{loops} = 0;
  waitFor(($self{line}-1)*5, 'Waiting to start %s');
  my $pandora = login();
  while() {
    $self{loops}++;
    my $result = getPlaylist($pandora, $self{station});
    if ( !$result ) {
      my $error = $pandora->error();
      if($error =~ /error 13\:/) { $pandora = login(); } else { died($error); }
    } else {
      my $waitTime = 0;
      for my $track (@{$result->{'items'}}) {
        my ($file,$offset) = save($track);
        $waitTime += get_mp3info($file)->{SECS}-$offset if(defined $file && defined $offset);
      }
      waitFor($waitTime, 'Simulating playhead %s');
    }
  }
}
sub save($) {
  my $track = shift;
  return if !($track->{additionalAudioUrl} && $track->{songName} && $track->{artistName} && $track->{albumName});
  my $path = join "/", ($config{directory}, sanitize($track->{artistName}), sanitize($track->{albumName}));
  for(make_path($path)) { display(DIM,"Directory Created: $_"); }
  my $url = $track->{additionalAudioUrl};
  my $extension = $url;
  $extension =~ s/^.*(\.[^.]{3})\?.*$/$1/gs;
  $config{downloading} = $path.'/'.sanitize($track->{songName}.$extension);
  my $file = $config{downloading};
  my $offset = 0;
  if(!-e $config{downloading}) {
    display(GREEN,"Saving $track->{songName} by $track->{artistName}");
    my $started = time;
    my $rc = getstore($url,$config{downloading});
    if (is_error($rc)) { display(RED,"Download failed with $rc"); return; }
    else {
      $self{downloaded}++;
      display(LIGHT_GREEN,"Saved $track->{songName} by $track->{artistName}");
      writeTags($track,$config{downloading});
      $offset = (time-$started);
    }
  } else { $self{skips}++; }
  delete $config{downloading};
  return ($file, $offset);
}

# Main functions

sub start($) {
  my $pandora = shift;
  my $result = handleError($pandora->getStationList(), $pandora);
  my @stations = @{$result->{'stations'}};
  for (my $i = 0; $i < @stations; $i++) { print "$i: \e[36m$stations[$i]->{stationName}\e[39m\n"; }
  @{$config{stations}} = ();
  if(getBool("Add all stations?")) { @{$config{stations}} = (0..(@stations-1)); }
  else {
    print "Input -1 to end adding stations.\n";
    while() {
      my $choice = getInput("Add a station by number");
      if(($choice >= 0) && ($choice < @stations)) { push(@{$config{stations}},$choice); }
      else { last; }
    }
  }
  clear();
  my @kills = ('ABRT','QUIT','KILL','INT','ABRT','HUP');
  for(@kills) { $SIG{$_} = sub { if($config{downloading}) { display(RED,"Removing Partial: $config{downloading}"); unlink($config{downloading}); } display(RED,"Thread died."); }; }
  for my $id (@{$config{stations}}) {
    my $station = $stations[$id];
    display(DIM, "Creating thread for $station->{stationName}");
    mkChild(\@threads,{ name => $station->{stationName}, station => $station->{stationToken}, block => \&thread })
  }
  display(BLUE, "[Threads: ".(@threads+0)." Directory: $config{directory}]");
  for(@kills) { $SIG{$_} = sub { for (@threads) { kill('TERM', $_); } print "\e[0;0H"."\033[2J"."\e[?25h"; exit 1; }; }
  while((@threads > 0) && (my $death = waitpid(-1, 0))) { display(BLUE, "[Threads: ".(@threads-1)." Directory: $config{directory}]"); @threads = grep { $_ != $death } @threads; }
  display(RED, "All threads have died.");
}
sub search() {
  my $pandora = shift;
  my $query = getInput("Search for new content");
  my $result = handleError($pandora->search(searchText => $query), $pandora);
  for my $type (['songs','song'],['artists','artist'],['genreStations','song']) {
    next if(!$result->{$$type[0]});
    for(my $i = 0; $i < @{$result->{$$type[0]}}; $i++) {
      if(($i != 0) && ($i % 5 == 0)) { last if(!getBool("Continue listing $$type[0]?")); }
      my $obj = $result->{$$type[0]}[$i];
      handleError($pandora->createStation(musicToken => $obj->{musicToken},musicType=>$$type[1]), $pandora)
        if(getBool("Add ".(($obj->{stationName})?$obj->{stationName}:(($obj->{songName})?$obj->{songName}.' by ':'').$obj->{artistName})." to your stations?"));
    }
  }
}
sub help() { for my $key (keys %commands) { printf("%10.10s %s\n", $key,$commands{$key}{description}); } }
sub shell() {
  getConfig(); my $pandora = login();
  help();
  while(my $command = getInput('Command')) {
    $command =~ tr[A-Z][a-z];
    if($commands{$command}) { $commands{$command}{call}($pandora); }
    else { say(RED,'Invalid Command.'); }
  }
}

%commands = (
  start => { description => "Starts the main process.", call => \&start },
  search => { description => "Searches for and adds new stations.", call => \&search },
  help => { description => "Shows all commands and their description.", call => \&help },
);
shell();

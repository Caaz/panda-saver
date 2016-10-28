#!/usr/bin/perl
use strict;
use warnings;
use WebService::Pandora;
use WebService::Pandora::Partner::WindowsGadget;
use JSON;
use constant {
  RESET => 0, BOLD => 1, DIM => 2, RED => 31, GREEN => 32, YELLOW => 33, BLUE => 34, MAGENTA => 35, CYAN => 36, GRAY => 90,
  LIGHT_GRAY => 37, LIGHT_RED => 91, LIGHT_GREEN => 92, LIGHT_YELLOW => 93, LIGHT_BLUE => 94, LIGHT_MANGENTA => 95, LIGHT_CYAN => 96
};
my %config;
sub login($) {
  my $p = shift;
  ${$p} = WebService::Pandora->new(
    username => $config{email},
    password => $config{password},
    partner => WebService::Pandora::Partner::WindowsGadget->new()
  );
  ${$p}->login() or die( ${$p}->error() );
}
sub handleError($$) { my ($r, $p) = @_; die $p->error if(!$r); return $r; }
sub getInput($) {my $i; print "\e[".YELLOW.'m'.shift.": \e[".RESET."m"; chomp($i = <STDIN>); return $i; }
sub getBool($) { my ($q,$r) = (shift,''); while($r =~ /^$/) { my $i = getInput("$q [y/n]"); $r = ($i=~/^y/i)?1:($i=~/^n/i)?0:''; } return $r; }
sub debug($) { my $json = encode_json(shift); open LOG, (">>$config{directory}/log.txt"); print LOG "$json\n"; print "$json\n"; close LOG; }
sub start() {
  %config = ( email => 'D.Caaz.y@gmail.com', password => 'Machines', directory => '.' );

  my $pandora;
  login(\$pandora);

  print "Search some shit.\n";
  while() {
    my $query = getInput("Search");
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

    # for(my $i = 0; $i < @{$result->{songs}}; $i++) {
    #   if(($i != 0) && ($i % 5 == 0)) { last if(!getBool("Continue listing songs?")); }
    #   my $song = $result->{songs}[$i];
    #   handleError($pandora->createStation(musicToken => $song->{musicToken},musicType=>'song'), $pandora)
    #     if(getBool("Add $song->{songName} by $song->{artistName} to your stations?"));
    # }
    # for(my $i = 0; $i < @{$result->{artists}}; $i++) {
    #   if(($i != 0) && ($i % 5 == 0)) { last if(!getBool("Continue listing artists?")); }
    #   my $artist = $result->{artists}[$i];
    #   handleError($pandora->createStation(musicToken => $artist->{musicToken},musicType=>'artist'), $pandora)
    #     if(getBool("Add $song->{artistName} to your stations?"));
    # }
    debug($result);
  }
}
start();

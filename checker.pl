#!/usr/bin/perl
use warnings;
use strict;
use MP3::Tag;
use MP3::Info;
my (%config);

use constant {
  RESET => 0, BOLD => 1, DIM => 2, RED => 31, GREEN => 32, YELLOW => 33, BLUE => 34, MAGENTA => 35, CYAN => 36, GRAY => 90,
  LIGHT_GRAY => 37, LIGHT_RED => 91, LIGHT_GREEN => 92, LIGHT_YELLOW => 93, LIGHT_BLUE => 94, LIGHT_MANGENTA => 95, LIGHT_CYAN => 96
};
sub say($$) { print "\e[".shift.'m'.shift."\e[".RESET."m\n"; }
sub getInput($) {my $i; print "\e[".YELLOW.'m'.shift.": \e[".RESET."m"; chomp($i = <STDIN>); return $i; }
sub clear() { print "\033[2J"; }
sub getConfig() {
  MP3::Tag->config(write_v24 => 'TRUE');
  my @keys = ('directory');
  for(my $i = 0; $i < @ARGV; $i++){ $config{$keys[$i]} = $ARGV[$i]; }
  for my $key (@keys) { $config{$key} = getInput($key) if(!$config{$key}); }
  $config{directory} =~ s/^\~/$ENV{HOME}/gs;
  $config{directory} =~ s/\/$//gs;
  clear();
}

getConfig();
my $pattern = "$config{directory}/**/**/*.mp3";
print "Searching through $pattern\n";
my @glob = glob $pattern;
for my $file (@glob) {
  print "found: $file ...";
  my $info = get_mp3info($file);
  if(defined $info) {
    # print Dumper($info);
    print "OKAY!\n"
  } else {
    print "ERROR!\n";
  }
}

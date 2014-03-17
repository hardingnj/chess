#! /usr/bin/perl
# short script to convert a PGN into FEN.

use Chess::PGN::Parse; 
use Chess::Rep;
use warnings;
use strict; 

my $file = shift @ARGV // die "PGN file must be specified on command line";
my $pgn = new Chess::PGN::Parse $file or die "can't open $file. $!";

while($pgn->read_game) {
  my $pos = Chess::Rep->new;
  $pgn->quick_parse_game;
  my @moves = @{$pgn->moves};
  my $current_fen;
  my $halfmovecounter = 0;
  # loop through coordinate_moves: 
  #   do analysis
  my $counter = 0;

  foreach my $move (@moves) { 
    # set current state as FEN
    my $status = $pos->go_move($move) and ++$counter;
    $current_fen = $pos->get_fen;
    print int(($counter+1)/2).". ".$move."\t".$current_fen.$/;
  }
  print "\n\nNew game:\n";
}

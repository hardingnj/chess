#!/usr/bin/perl -w

# This script will parse a single pgn file and put it in the database.
# Does a check to see if record exists: if yes, does not enter in db.
use warnings;
use strict;
use DBI;
use Chess::PGN::Parse;
use Text::Names qw/cleanName composeName parseName2 samePerson/;
use YAML qw/Dump/;

my $dbh = DBI->connect('dbi:mysql:pgnpilot','root','442mufc')
or die "Connection Error: $DBI::errstr\n";

my %hash = ( "1-0" => 1, "0-1" => 0, "1/2-1/2" => 2, "0.5-0.5" => 2);
my $pgnfile = $ARGV[0] // die "PGN must be provided as a command line argument!";
my $pgn = new Chess::PGN::Parse $pgnfile or die "can't open $pgnfile\n";

# Parse PGN
while($pgn->read_game) {
  $pgn->quick_parse_game;
  
  my $moves = join(',', @{$pgn->moves});
  my $result = $hash{$pgn->result} // undef;
  
  my @date = split(/\./, $pgn->date);
  my $year  = $date[0];
  my $month = $date[1];
  my $day   = $date[2];
  
  my $white = return_player_id($pgn->white);
  my $black = return_player_id($pgn->black);
  
  $year  = undef if $year  =~ m/\?\?/;
  $month = undef if $month =~ m/\?\?/;
  $day   = undef if $day   =~ m/\?\?/;
  
  # look for duplicates
  my $sql = "select id from games WHERE white = ? AND black = ? AND year = ? AND result = ? AND moves = ?";
  my $sth = $dbh->prepare($sql);
  $sth->execute($white, $black, $year, $result, $moves) or die "SQL Error: $DBI::errstr\n";
  my $h = $sth->fetchrow_hashref;
  
  unless (defined $h) {  
    $dbh->do(
      'INSERT INTO games (white, black, event, site, result, year, month, day, round, pgnmoves) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      undef,
      $white, $black, $pgn->event, $pgn->site, $result, $year, $month, $day, $pgn->round, $moves
      );
     }
  else { 
    # also should update if any of the fields are null in the original.
    print "appears to be duplicate of record $h->{id}. Skipping...".$/; 
    }
  }
### CODE TO PRINT OUT AT END! ###
#my $sql = "select id, white, black, result from games";
#my $sth = $dbh->prepare($sql);
#$sth->execute or die "SQL Error: $DBI::errstr\n";
#while (my $h = $sth->fetchrow_hashref) {
#  print Dump($h);
#  } 
exit 0;

sub return_player_id {
  # is white/black a new player?
  # select based on surname, 
  my $name = shift;
  # if computer program, concatenate.
  # has a number. Fritz, Deep blue, junior etc. For now doesn't matter as long as we can recreate initial name.

  my $clean = cleanName($name);
  my @n = parseName2($clean);
  my $query = "select given_name, surname, pid from players WHERE surname = ?";
  my $exec = $dbh->prepare($query);
  $exec->execute($n[2]) or die "SQL Error: $DBI::errstr\n";

  # loop through records, is given name identical? If yes then return id. 
  while (my @row = $exec->fetchrow_array) {
    if ($row[0] eq $n[0]) { return $row[2]; } 
    # if not see if evidence to suggest a new individual. 
    elsif (samePerson($clean, "$row[1], $row[0]")) {
      # append to alias
      return $row[2];
      }
    }
    # finally add new record, return id.
    print "adding new player record: $n[2]".$/;
    my $pid = $dbh->do(
      'INSERT INTO players (given_name, surname) VALUES (?, ?)',
      undef,
      $n[0], $n[2]
      );
    print "id: $dbh->{mysql_insertid}".$/;
    return $dbh->{mysql_insertid};
  }

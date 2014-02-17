#!/usr/bin/perl -w

# This script will parse a single pgn file and put it in the database.
# Does a check to see if record exists: if yes, does not enter in db.
use warnings;
use strict;
use DBI;
use Chess::PGN::Parse;
use Text::Names qw/cleanName composeName parseName2 samePerson/;
use YAML qw/Dump LoadFile/;
use Digest::MD5 qw(md5_hex);
use IO::File;
use File::Find::Rule;

my $cfg = LoadFile("/opt/settings.yaml");

my $userid   = $cfg->{userid};
my $password = $cfg->{passwd};
my $database = $cfg->{dbname};
my $driver   = $cfg->{driver}; 
my $host_ip  = $ENV{HOSTIP} // die "FATAL: Host IP not found.$/";
my $dsn = "DBI:$driver:database=$database;hostname=$host_ip";

my $dbh = DBI->connect($dsn, $userid, $password) or die $DBI::errstr;
my %hash = ( "1-0" => 1, "0-1" => 0, "1/2-1/2" => 2, "0.5-0.5" => 2);

# LOGIC 
# DIR IS PASSED ON CL
# loop:
#   choose 1 at random. slice off. Flock.
#   if previously looked at, get another. Unflock and repeat.
#   found one... process as normal. 
#   unflock
#   sleep
  # find all the subdirectories of a given directory

  # find all the .pm files in @INC
my $directory = $ARGV[0] // die "PGN directory must be provided as a command line argument!";

# ie infinite loop!
while(1) {
  # this function returns the pgn file, and its fid.
  my $pgnfile = choosePGN($directory);
  print Dump($pgnfile);
  unless (defined $pgnfile) { sleep($cfg->{sleeptime}) and next; }

  my $pgn = new Chess::PGN::Parse $pgnfile->{filepath} or die "can't open $pgnfile->{filepath}\n";

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
    
    unless(defined $white and defined $black) { warn "Names not successfully parsed, skipping this record"; next; }
  
    $year  = undef if $year  =~ m/\?\?/;
    $month = undef if $month =~ m/\?\?/;
    $day   = undef if $day   =~ m/\?\?/;
    
    # look for duplicates
    my $sql = "select id from games WHERE white = ? AND black = ? AND year = ? AND result = ? AND algebraic_moves = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($white, $black, $year, $result, $moves) or die "SQL Error: $DBI::errstr\n";
    my $h = $sth->fetchrow_hashref;
    
    unless (defined $h) {  
      $dbh->do(
        'INSERT INTO games (white, black, event, site, result, year, month, day, round, algebraic_moves, fileid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        undef,
        $white, $black, $pgn->event, $pgn->site, $result, $year, $month, $day, $pgn->round, $moves, $pgnfile->{id}
        );
       }
    else { 
      # also should update if any of the fields are null in the original.
      print "appears to be duplicate of record $h->{id}. Skipping...".$/; 
      }
  }
  sleep($cfg->{sleeptime});
}

exit 127;

sub return_player_id {
  # is white/black a new player?
  # select based on surname, 
  my $name = shift;

  # if computer program, concatenate.
  # has a number. Fritz, Deep blue, junior etc. For now doesn't matter as long as we can recreate initial name.
  if($name =~ m/[0-9]/ || $name =~ m/^Comp\s/i) {
    #warn "I believe $name is a computer.";
    $name =~ s/^Comp\s//;
    $name =~ s/[^a-zA-Z0-9]//g;
    $name .= ", Computer";
    }
  # if contains 'bad characters', i.e. not letters numbers, hyphen, apostrophes or periods.
  elsif($name =~ m/[^a-zA-Z0-9,\.'\-\s]+/) { 
    warn "$name failed to validate as it contains an unexpected character(s): Skipping.";
    return undef;
    }

  my $clean = cleanName($name);
  my %playername;
  @playername{qw/given_name initials surname suffix/} = parseName2($clean);
  my $query = "select given_name, surname, pid from players WHERE surname = ?";
  my $exec = $dbh->prepare($query);
  $exec->execute($playername{surname}) or die "SQL Error: $DBI::errstr\n";

  # loop through records, is given name identical? If yes then return id. 
  # row is a array of length=3 with given name/surname/pid
  my %record;
  while (@record{qw/given_name surname pid/} = $exec->fetchrow_array) {
    # is given name identical?
    return $record{pid} if ($record{given_name} eq $playername{given_name});
  }
  # else add new record, return id.
  print "adding new player record: $playername{surname}".$/;
  my $pid = $dbh->do(
    'INSERT INTO players (given_name, surname) VALUES (?, ?)',
    undef,
    $playername{given_name}, $playername{surname}
    );
  print "id: $dbh->{mysql_insertid}".$/;
  return $dbh->{mysql_insertid};
  }

sub choosePGN {
  my @PGNfiles = File::Find::Rule->file()->name('*.PGN', '*.pgn')->in(shift);
  print "in choose PGN".$/;
  print "Found $#PGNfiles.".$/;
  
  my $newfileflag = 0;
  my ($chosen_file, $file_id);
  while(@PGNfiles){ 
    print join("\t", @PGNfiles).$/;
    $chosen_file = splice @PGNfiles, int(rand($#PGNfiles + 1)), 1;
    print "selected: $chosen_file".$/;

    my $md5 = md5_hex(do { local $/; IO::File->new($chosen_file)->getline });
    my $sql = "select fid from files WHERE checksum = ?";
    my $sth = $dbh->prepare($sql);
    $sth->execute($md5) or die "SQL Error: $DBI::errstr\n";
    my $h = $sth->fetchrow_hashref;
    if(!defined $h) {
      $newfileflag = 1;
      $dbh->do(
        'INSERT INTO files (checksum, filename) VALUES (?, ?)',
        undef,
        $md5, $chosen_file
      );
    $file_id = $dbh->{mysql_insertid};  
    last;
    }
    else {
      warn "I have seen $chosen_file before w/checksum $md5.\n";
      $chosen_file = undef;
    }
  }
  return undef if not defined $chosen_file;
  my %result = (filepath => $chosen_file, id => $file_id);
  return \%result;
}

#!/usr/bin/perl -w

# This script will parse a single pgn file and put it in the database.  Does a
# check to see if record exists: if yes, does not enter in db.
use warnings;
use strict; 
use DBI; 
use Chess::PGN::Parse; 
use Text::Names qw/cleanName composeName parseName2 samePerson/; 
use YAML qw/Dump LoadFile/;
use Digest::MD5 qw/md5_hex/;
use IO::File;
use Getopt::Long;
use File::Find::Rule;

my %cfg = %{LoadFile("/opt/settings.yaml")};

GetOptions(
  \%cfg, 
  'userid:s',
  'passwd:s',
  'dbname:s',
  'driver:s',
  'sleeptime:i',
  'timeout:i',
  'pgndir:s'
  ) or die "Bad options passed";	

my $database = $cfg{dbpath};
my $driver   = $cfg{driver} // 'SQLite'; 
my $timeout  = $cfg{timeout} // 0;
print Dump(\%cfg);

my $dbh = DBI->connect(
	"dbi:$driver:dbname=$database",
	"",
	""#,
    #{ sqlite_use_immediate_transaction => 1, }
	) or die $DBI::errstr;
$dbh->sqlite_busy_timeout($timeout);
my %hash = ( "1-0" => 1, "0-1" => 0, "1/2-1/2" => 2, "0.5-0.5" => 2);

# LOGIC 
# DIR IS PASSED ON CL
# loop:
#   choose 1 at random. slice off. Flock.
#   if previously looked at, get another. Unflock and repeat.
#   found one... process as normal. 
#   unflock
#   sleep

# SETUP QUERIES
# look for duplicates
my $sql_selectgame = "select id from games WHERE white = ? AND black = ? AND year = ? AND result = ? AND algebraic_moves = ?";
my $selectgame = $dbh->prepare($sql_selectgame) or die $DBI::errstr;

my $sql_selectplayer = "select given_name, surname, pid from players WHERE surname = ?";
my $selectplayer = $dbh->prepare($sql_selectplayer) or die $DBI::errstr;

my $sql_selectfile = "select fid,completed from files WHERE checksum = ?";
my $selectfile = $dbh->prepare($sql_selectfile) or die $DBI::errstr;

# ie infinite loop. This is run as daemon
while(1) {
  sleep(2); # maybe this is what is blocking the database. 

  # this function returns the pgn file, and its fid.
  my $pgnfile = choosePGN($cfg{pgndir}, $selectfile);
  
  unless (defined $pgnfile) { sleep($cfg{sleeptime}) and next; }

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
    
    my $white = return_player_id($pgn->white, $selectplayer);
    my $black = return_player_id($pgn->black, $selectplayer);
    
    if (grep { !defined $_ } ($white, $black, $pgn->result, $year)) { 
      warn "Record not successfully parsed, skipping. Should dump a decent log message here.";
      next;
    }
  
    $year  = undef if $year  =~ m/\?\?/;
    $month = undef if $month =~ m/\?\?/;
    $day   = undef if $day   =~ m/\?\?/;
    
    $selectgame->execute($white, $black, $year, $result, $moves) or die "SQL Error: $DBI::errstr\n";
    my $h = $selectgame->fetchrow_hashref;
    
    unless (defined $h) {
      $dbh->do(
        'INSERT INTO games (white, black, event, site, result, year, month, day, round, algebraic_moves, fileid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        undef,
        $white, $black, $pgn->event, $pgn->site, $result, $year, $month, $day, $pgn->round, $moves, $pgnfile->{id}
        ) or die $DBI::errstr;
      }
    else { 
      # also should update if any of the fields are null in the original.
      print "appears to be duplicate of record $h->{id}. Skipping...".$/; 
      }
  }
  # if gets here pgn was parsed ok... 
  $dbh->do(
    'UPDATE files SET completed = ? WHERE fid = ?',
    undef,
    1, $pgnfile->{id}
    ) or die $DBI::errstr;
  sleep($cfg{sleeptime});
}

exit 127;

sub return_player_id {
  # is white/black a new player?
  # select based on surname, 
  my $name = shift;
  my $query = shift;

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
  $query->execute($playername{surname}) or die "SQL Error: $DBI::errstr\n";

  # loop through records, is given name identical? If yes then return id. 
  # row is a array of length=3 with given name/surname/pid
  my %record;
  while (@record{qw/given_name surname pid/} = $query->fetchrow_array) {
    # is given name identical?
    return $record{pid} if ($record{given_name} eq $playername{given_name});
  }
  # else add new record, return id.
  print "adding new player record: $playername{surname}".$/;
  my $pid = $dbh->do(
    'INSERT INTO players (given_name, surname) VALUES (?, ?)',
    undef,
    $playername{given_name}, $playername{surname}
    ) or die $DBI::errstr;
  my $id = $dbh->last_insert_id("", "", "players", "");
  print "id: $id".$/;
  return $id;
  }

sub choosePGN {
  my $searchdir = shift;
  my $query = shift;

  my @PGNfiles = File::Find::Rule->file()->name('*.PGN', '*.pgn')->in($searchdir);
  print "in choose PGN. Found @PGNfiles in $searchdir".$/;
  
  my ($chosen_file, $file_id);
  while(@PGNfiles){ 
    print join("\t", @PGNfiles).$/;
    $chosen_file = splice @PGNfiles, int(rand($#PGNfiles + 1)), 1;
    print "selected: $chosen_file".$/;

    my $md5 = md5_hex(do { local $/; IO::File->new($chosen_file)->getline });
    $query->execute($md5) or die "SQL Error: $DBI::errstr\n";
    my $h = $query->fetchrow_hashref;
    if(!defined $h) {
      # ie not seen before
      $dbh->do(
        'INSERT INTO files (checksum, filename) VALUES (?, ?)',
        undef,
        $md5, $chosen_file
      ) or die $DBI::errstr;
	$file_id = $dbh->last_insert_id("", "", "files", "");
    last;
    }
    elsif(!$h->{completed}){
      warn "Restarting parsing of $chosen_file, as did not complete previously.";
      $file_id = $h->{fid};
      last;
	}
    else {
      warn "I have previously successfully parsed $chosen_file before w/checksum $md5.";
      $chosen_file = undef;
    }
  }
  return undef if not defined $chosen_file;
  my %result = (filepath => $chosen_file, id => $file_id);
  return \%result;
}

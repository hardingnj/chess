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
use Log::Log4perl qw(get_logger :levels);

my $logger = get_logger("chess::parsepgn");
$logger->level($INFO);

# Appender
my $appender = Log::Log4perl::Appender->new(
    "Log::Dispatch::File",
    filename => "/data/"."parsepgn_".$ENV{HOSTNAME}.".log",
    mode     => "append",
    );
$logger->add_appender($appender);

# Layouts
my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %p > %F{1}:%L %M - %m%n");
$appender->layout($layout);

my %cfg = %{LoadFile("/opt/settings.yaml")};

GetOptions(
  \%cfg, 
  'userid:s',
  'passwd:s',
  'dbname:s',
  'driver:s',
  'sleeptime:i',
  'timeout:i',
  'pgndir:s',
  'debug!'
  ) or $logger->logdie("Bad options passed");	

my $database = $cfg{dbpath};
my $driver   = $cfg{driver} // 'SQLite'; 
my $timeout  = $cfg{timeout} // 3000;
my $last_backup_time = time;
my $debug_mode = $cfg{debug};
$cfg{sleeptime} = 10 if $debug_mode;
$logger->logwarn("In DEBUG mode. No PGNS will be parsed.") if $debug_mode;

my %hash = ("1-0" => 1, "0-1" => 0, "1/2-1/2" => 2, "0.5-0.5" => 2);

my $dbh = DBI->connect(
  "dbi:$driver:dbname=$database",
  "",
  "",
  { AutoCommit => 0 }
) or $logger->logdie($DBI::errstr);


my $sql_selectgame = "select id from games WHERE white = ? AND black = ? AND year = ? AND result = ? AND algebraic_moves = ?";
my $sql_selectplayer = "select given_name, surname, pid from players WHERE surname = ?";
my $sql_selectfile = "select fid,completed from files WHERE checksum = ?";

# ie infinite loop. This is run as daemon
while(1) {

  # Look for YAML files
  my @yaml_files = File::Find::Rule->file()->name("*.YAML")->nonempty()->in('/data/');
  while(@yaml_files){
    my $file_yaml = pop @yaml_files;
    eval {

      my $yaml = LoadFile($file_yaml);

      $dbh->do(
        "UPDATE games SET processed = ?, coordinate_moves = ?, move_scores = ?, opt_algebraic_moves = ?,
         opt_coordinate_moves = ?, opt_move_scores = ?, move_mate_in = ?, opt_move_mate_in = ?, time_s = ? WHERE id = ?",
        undef,
        1,
        $yaml->{coordinate_moves}, $yaml->{move_scores}, $yaml->{opt_algebraic_moves}, $yaml->{opt_coordinate_moves}, 
        $yaml->{opt_move_scores}, $yaml->{move_mate_in}, $yaml->{opt_move_mate_in}, $yaml->{time_s}, 
        $yaml->{id}
      ) or $logger->logdie($DBI::errstr);

      $dbh->commit();
      $logger->info("Successfully entered YAML file $file_yaml in database. Game ID: $yaml->{id}.");
    }; 
    if($@){
      $logger->logwarn($@) ;
      $dbh->rollback();
    }
    unlink $file_yaml;
  }

  # now determine if we should back up.
  if(time - $last_backup_time > $cfg{backupfreq}*3600) {
    $logger->info("Backing up sqlite db", int((time - $last_backup_time)/60), "minutes since last backup.");
    $dbh->sqlite_backup_to_file($database.'.bak') or $logger->logwarn($DBI::errstr);
    $last_backup_time = time;
    }

  # debug mode?
  if($debug_mode){ sleep($cfg{sleeptime}) and next; }

  # this function returns the pgn file, and its fid.
  my $pgnfile = choosePGN($cfg{pgndir}); # This function calls the database

  unless(defined $pgnfile){ sleep($cfg{sleeptime}) and next; }

  my $pgn = new Chess::PGN::Parse $pgnfile->{filepath} or $logger->logdie("can't open $pgnfile->{filepath}");

  # Parse PGN
  while($pgn->read_game) {
    $pgn->quick_parse_game;

    my $moves = join(',', @{$pgn->moves});
    my $result = $hash{$pgn->result} // undef;

    my @date = split(/\./, $pgn->date);
    my $year  = $date[0];
    my $month = $date[1];
    my $day   = $date[2];

    my $white = return_player_id($pgn->white) // next;
    my $black = return_player_id($pgn->black) // next;

    unless(defined $result && defined $year) { 
      $logger->warn("Record not successfully parsed, skipping. White: $white, Black: $black, Result: $result, Year: $year.");
      next;
    }

    $year  = undef if $year  =~ m/\?\?/;
    $month = undef if $month =~ m/\?\?/;
    $day   = undef if $day   =~ m/\?\?/;

    # look for duplicates
    my $selectgame = $dbh->prepare($sql_selectgame) or $logger->logdie($DBI::errstr);
    $selectgame->execute($white, $black, $year, $result, $moves) or $logger->logdie("SQL Error: $DBI::errstr");
    my $gameToParse = $selectgame->fetchrow_hashref;
    $selectgame->finish;

    unless (defined $gameToParse) {
      eval { 
        $dbh->do(
          'INSERT INTO games (white, black, event, site, result, year, month, day, round, algebraic_moves, fileid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          undef,
          $white, $black, $pgn->event, $pgn->site, $result, $year, $month, $day, $pgn->round, $moves, $pgnfile->{id}
          ) or $logger->logdie($DBI::errstr);
        $dbh->commit;
      };
      if($@) {
        $dbh->rollback();
        $logger->logwarn($@);
      }
    }
    else { 
      # also should update if any of the fields are null in the original.
      $logger->info("Appears to be duplicate of record $gameToParse->{id}. Skipping...");
      }
  }
  # if gets here pgn was parsed ok... 
  eval {
    $dbh->do(
      'UPDATE files SET completed = ? WHERE fid = ?',
      undef,
      1, $pgnfile->{id}
    ) or $logger->logdie($DBI::errstr);
    $dbh->commit;
  };
  if($@) {
    $dbh->rollback();
    $logger->logwarn($@);
  }
  sleep($cfg{sleeptime});
}
exit 127;

sub return_player_id {
  # is white/black a new player?
  # select based on surname, 
  my $name   = shift;
  my $logger = get_logger("chess::parsepgn");

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
    $logger->warn("Failed to validate ($name) as it contains an unexpected character(s): Skipping...");
    return undef;
    }

  my $clean = cleanName($name);
  my %playername;
  @playername{qw/given_name initials surname suffix/} = parseName2($clean);

  # define and initialize database
  my $selectplayer = $dbh->prepare($sql_selectplayer) or $logger->logdie($DBI::errstr);
  $selectplayer->execute($playername{surname}) or $logger->logdie("SQL Error: $DBI::errstr");

  # loop through records, is given name identical? If yes then return id. 
  # row is a array of length=3 with given name/surname/pid
  my %record;
  while (@record{qw/given_name surname pid/} = $selectplayer->fetchrow_array) {
    # is given name identical? This loop will only be 
    if ($record{given_name} eq $playername{given_name}) {
      $selectplayer->finish;
      return $record{pid};
    }
  }
  # else add new record, return id.
  $selectplayer->finish;
  my $id;
  eval {
    $dbh->do(
      'INSERT INTO players (given_name, surname) VALUES (?, ?)',
      undef,
      $playername{given_name}, $playername{surname}
      ) or $logger->logdie($DBI::errstr);
    $dbh->commit;
    $id = $dbh->last_insert_id("", "", "players", "");
    $logger->info("Adding new player record: $playername{surname}, id: $id");
  };
  if($@) {
    $dbh->rollback();
    $logger->logwarn($@);
    return undef;
  }
  return $id;
}

sub choosePGN {
  my $searchdir = shift;
  my $logger = get_logger("chess::parsepgn");

  my @PGNfiles = File::Find::Rule->file()->name('*.PGN', '*.pgn')->in($searchdir);

  $logger->info("In choose PGN. Found @PGNfiles in $searchdir.");

  while(@PGNfiles){ 
    my $chosen_file = splice @PGNfiles, int(rand($#PGNfiles + 1)), 1;
    my $md5 = md5_hex(do { local $/; IO::File->new($chosen_file)->getline });
    $logger->info("selected: $chosen_file");

    # see if this file is in database
    my $selectfile = $dbh->prepare($sql_selectfile) or $logger->logdie($DBI::errstr);
    $selectfile->execute($md5) or $logger->logdie("SQL Error: $DBI::errstr");
    my $gameFromDB = $selectfile->fetchrow_hashref;
    $selectfile->finish;

    if(!defined $gameFromDB) {
      # ie not seen before
      eval {
        $dbh->do(
          'INSERT INTO files (checksum, filename) VALUES (?, ?)',
          undef,
          $md5, $chosen_file
        ) or $logger->logdie($DBI::errstr);
        $dbh->commit;
      };
      if($@) {
        $dbh->rollback();
        $logger->logwarn($@);
      }
      return { filepath => $chosen_file, id => $dbh->last_insert_id("", "", "files", "") };
    }
    elsif(!$gameFromDB->{completed}){
      $logger->warn("Restarting parsing of $chosen_file, as did not complete previously.");
      return { filepath => $chosen_file, id => $gameFromDB->{fid} };
    }
    else {
      $logger->warn("I have previously successfully parsed $chosen_file before w/checksum $md5.");
    }
  }
  # if we have looked at all files, but nothing is new then return undef.
  $logger->warn("No unprocessed files found to parse.");
  return undef;
}

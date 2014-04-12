#! /usr/bin/perl
use v5.10;
use warnings;
use strict;
use FileHandle;
use IPC::Open2;
use Term::ANSIColor;
use YAML qw/LoadFile DumpFile/;
use Chess::Rep;
use DBI;
use Getopt::Long;
use Shell::Command;
use DBD::SQLite;

my $VERSION = "1.0.0";

my %cfg = %{LoadFile("/opt/settings.yaml")};

# Set autoflush for debugging.
$| = 1;

GetOptions(
  \%cfg, 
  'userid:s',
  'passwd:s',
  'dbname:s',
  'driver:s',
  'Engine:s',
  'Depth:i',
  'EvalAfter:i',
  'hashsize:i',
  'timeout:i',
  'sleeptime:i',
  'verbose'
  ) or die "Bad options passed";

my $database = $cfg{dbpath};
my $driver   = $cfg{driver} // 'SQLite'; 
my $timeout  = $cfg{timeout} // 3000;

my $engine  = $cfg{Engine};
my $perlversion = sprintf "%vd", $^V;
my $osstring = $^O;

# instantiate engine.
print "set interface $engine (Perl: $perlversion, OS: $osstring, VERSION: $VERSION)\n";
my ($Reader, $Engine);
my $pid = open2($Reader,$Engine,$engine);
startengine(hashsize => $cfg{hashsize});

# this is will be a reference to an object. of type game. loop is conditional on this being defined
# when no more games this is no longer defined and loop exits.
my $game;
my $outfile;

# Define and declare database connection
my $dbh = DBI->connect("dbi:SQLite:$database", undef, undef, {
  sqlite_open_flags => DBD::SQLite::OPEN_READONLY,
  }) or die $DBI::errstr;
$dbh->sqlite_busy_timeout($timeout) or die $DBI::errstr;

my $sql_selectgames = "select id, algebraic_moves from games WHERE processed = 0";
my $selectgames = $dbh->prepare($sql_selectgames) or die $DBI::errstr;

while(1) {

  eval {
    $selectgames->execute or die $DBI::errstr;
    # choose game
    do {
      $game = $selectgames->fetchrow_hashref or die $DBI::errstr;
      die "No games found to be processed...." unless defined $game;
      $outfile = "/data/$game->{id}.YAML";
    } while(-e $outfile);

    $selectgames->finish;
  }; (warn $@ and sleep $cfg{sleeptime} and next) if $@;

  my $start = time;

  say "About to process game $game->{id}";
  touch $outfile;

  say "Evaluating game $game->{id}";
  my @algebraic_moves = split(/,/, $game->{algebraic_moves});
  my @coordinate_moves;
  my @move_scores;
  my @move_mate_in;

  my @opt_algebraic_moves;
  my @opt_coordinate_moves;
  my @opt_move_scores;
  my @opt_move_mate_in;

  my $pos = Chess::Rep->new;
  my $current_fen;
  my $halfmovecounter = 0;
  # loop through coordinate_moves: 
  #   do analysis
  foreach my $move (@algebraic_moves) { 
  # set current state as FEN
  $current_fen = $pos->get_fen;
    	++$halfmovecounter;

    	# update board with current move & capture move info
    	my $status = $pos->go_move($move);
    	my $move_as_coordinates = $status->{from}.$status->{to}.($status->{promote}//''); 

        push @coordinate_moves, $move_as_coordinates;

    	# code to skip 3 lines if too early in game
    	if ($cfg{EvalAfter} >= ($halfmovecounter/2)) {
              push @opt_coordinate_moves, 'NA';
              push @opt_algebraic_moves,  'NA';
              push @opt_move_scores,      'NA';
              push @move_scores,          'NA';
              push @move_mate_in,         'NA';
              push @opt_move_mate_in,     'NA';
              next;
              }

    	my $playedmove = choosemove(fen => $current_fen, searchmoves => [$move_as_coordinates], depth => $cfg{Depth}, verbose => $cfg{verbose});
    	my $bestmove   = choosemove(fen => $current_fen, depth => $cfg{Depth}, verbose => $cfg{verbose});

		# dummy pos
		my $dummy_position = Chess::Rep->new($current_fen);
        my $hypothet_move  = $dummy_position->go_move($bestmove->{move});

    	# on occasion played nove scores higher than best move...
        push @opt_coordinate_moves, $bestmove->{move}; 
        push @opt_algebraic_moves,  $hypothet_move->{san};
        push @opt_move_scores,      $bestmove->{cp};
        push @move_scores,          $playedmove->{cp};
        push @move_mate_in,         $playedmove->{matein}; 
        push @opt_move_mate_in,     $bestmove->{matein}; 
        }

    my $end = time;

    die "something went wrong..." if !@move_scores;

    say "Evaluated game $game->{id}. About to dump YAML file.";
    DumpFile(
      $outfile,
      {
        processed            => 1,
        coordinate_moves     => join(',', @coordinate_moves),
        move_scores          => join(',', @move_scores),
        opt_algebraic_moves  => join(',', @opt_algebraic_moves),
        opt_coordinate_moves => join(',', @opt_coordinate_moves),
        opt_move_scores      => join(',', @opt_move_scores),
        move_mate_in         => join(',', @move_mate_in),
        opt_move_mate_in     => join(',', @opt_move_mate_in),
        time_s               => $end - $start,
        id                   => $game->{id}
      }
    );
    # end of loop.
}
die 'Exiting. Should not reach here until killed.';

#-----------------------------------------------	
sub startengine {
#-----------------------------------------------	
	my %args = (
		hashsize => 512,
		ownbook  => 'true',
		@_
		);
	my $count = 0;
	my $success = 0;
	while (<$Reader>) {
		
		my $line = $_;
		$line =~ s/\n|\r//g;
		print $line.$/;

		if ($count == 0) {
			print $Engine "uci\n";
			$count++;
		}

		if ($line eq "uciok") {
			print $Engine "isready\n";
			print "Engine is ready\n";
		}
		if ($line eq "readyok") {
			print $Engine "ucinewgame\n";
			print $Engine "setoption name Hash value $args{hashsize}\n";
			print $Engine "setoption name UCI_AnalyseMode value true\n";
			print $Engine "setoption name OwnBook value true\n";
			++$success;
			last;
		} 
	}
    die "Engine failed to initialize. $!" unless $success;
}

#-----------------------------------------------
sub choosemove {
#-----------------------------------------------	
# This sub choses a move. Returns move AND the -cp score.
# Optional args depth and time. 
	my %args = (
		fen => undef,
		depth => 20,
		movetime => undef,
		searchmoves => [],
		verbose => 0,
		@_
		);
	my %data; #holds the output
	my ($bestmove, $multipv, $umwandler);
		
	# some logic to determine command. Might be neater to use each here, and append $key $val if defined.
	my $command = 'go';
	$command .= " depth " . $args{depth} if defined $args{depth};
	my @searchmoves = @{$args{searchmoves}};
	if(@searchmoves) { $command .= ' searchmoves '; $command .= join(' ', @searchmoves); } 
	print "Debug: $command".$/ if $args{verbose};

	print $Engine "position fen $args{fen}\n"; 
	print $Engine $command.$/;
	while (<$Reader>) {

		my $line = $_;
		$line =~ s/\n|\r//g;

		if ($line =~ m/multipv/) {
			print color 'red' if $args{verbose};
			print "$line\n" if $args{verbose};
			print color 'reset' if $args{verbose};
			$multipv = $line;
			}
		if ($line =~ m/bestmove /) {
			print color 'red' if $args{verbose};
			print "$line\n" if $args{verbose};
			print color 'reset' if $args{verbose};
			my @bmarray = split(/ /,$line);
			$bestmove = $bmarray[1];
			if (length($bestmove) > 4) {
				$umwandler = substr($bestmove,4,1);
				$bestmove = substr($bestmove,0,4);
				# used if multiple best coordinate_moves.
				$bestmove = "$bestmove"."="."$umwandler";
				}
			$data{move} = $bestmove;
			my @pvdata = split(/ /,$multipv);
			while(@pvdata){
				my $val = shift @pvdata;
				next if $val =~ m/^info$/;

				$data{depth} = shift @pvdata if $val =~ m/^depth$/;
				$data{seldepth} = shift @pvdata if $val =~ m/^seldepth$/;
				$data{nodes} = shift @pvdata if $val =~ m/^nodes$/;
				$data{nps} = shift @pvdata if $val =~ m/^nps$/;
				$data{time} = shift @pvdata if $val =~ m/^time$/;
				
				if($val =~ m/^score$/){
					my $scoretype = shift @pvdata;
					if($scoretype =~ m/cp/){ $data{cp} = shift @pvdata; $data{matein} = 'NA'; } 
					else { $data{matein} = shift @pvdata; $data{cp} = 'NA'; }
					}
				if($val =~ m/^multipv$/){
					# ignore the next two args
					shift @pvdata for 1..2;	
					# add the line and remove array.
					$data{line} = join(',', @pvdata);
					$#pvdata = -1;
					}
				}
			return \%data;
		}
	}
	die "did not read...";
}

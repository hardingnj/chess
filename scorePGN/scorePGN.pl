#! /usr/bin/perl
use v5.10;
use warnings;
use strict;
use FileHandle;
use IPC::Open2;
use Term::ANSIColor;
use YAML qw/LoadFile Dump/;
use Chess::Rep;
use DBI;
my $VERSION = "0.03";

my $cfg = LoadFile("/opt/settings.yaml");

my $userid   = $cfg->{userid};
my $password = $cfg->{passwd};
my $database = $cfg->{dbname};
my $driver   = $cfg->{driver}; 
my $host_ip  = $ENV{HOSTIP} // die "FATAL: Host IP not found.$/";
my $dsn = "DBI:$driver:database=$database;hostname=$host_ip";

# establish connection to database. 
my $dbh = DBI->connect($dsn, $userid, $password) or die $DBI::errstr;

my $engine  = $cfg->{Engine};
my $players = $cfg->{Players};

my $perlversion = sprintf "%vd", $^V;
my $osstring = $^O;

# instantiate engine.
print "set interface $engine (Perl: $perlversion  OS: $osstring)\n";
my ($Reader, $Engine);
my $pid = open2($Reader,$Engine,$engine);
startengine(hashsize => $cfg->{hashsize});

# this is will be a reference to an object. of type game. loop is conditional on this being defined
# when no more games this is no longer defined and loop exits.
my $game;

# Main loop is here!
do {
    # select eligible games
    my $sql = "select id, algebraic_moves from games WHERE processed = 0";
    my $sth = $dbh->prepare($sql);
    $sth->execute or die "SQL Error: $DBI::errstr\n";
    
    # choose game
    $game = $sth->fetchrow_hashref;
    last if !defined $game;
    
    my $start = time;
    
    # set processed to 2. Signifies in process. 
    $dbh->do(
      'UPDATE games SET processed = ? WHERE id = ?',
      undef,
      2,
      $game->{id}
      );
    
    my @algebraic_moves = split(/,/, $game->{algebraic_moves});
    
    my @coordinate_moves;
    my @move_scores;
    my @move_mate_in;
    my @opt_coordinate_moves;
    my @opt_move_scores;
    my @opt_move_mate_in;
    
    my $pos = Chess::Rep->new;
    my $current_state;
    my $halfmovecounter = 0;
    # loop through coordinate_moves: 
    #   do analysis
    foreach my $move (@algebraic_moves) { 
    	# set current state as FEN
    	$current_state = $pos->get_fen;
    	++$halfmovecounter;
    	
    	# update board with current move & capture move info
    	my $status = $pos->go_move($move);
    	my $move_uci_format = $status->{from}.$status->{to}; 
    
        push @coordinate_moves, $move_uci_format;

    	# code to skip 3 lines if too early in game
    	if ($cfg->{EvalAfter} >= ($halfmovecounter/2)) {
              push @opt_coordinate_moves, 'NA';
              push @opt_move_scores,      'NA';
              push @move_scores,          'NA';
              push @move_mate_in,         'NA';
              push @opt_move_mate_in,     'NA';
              next;
              }
             
    	my $playedmove = choosemove(fen => $current_state, searchmoves => [$move_uci_format], depth => $cfg->{Depth});
    	my $bestmove   = choosemove(depth => $cfg->{Depth});
    
    	# on occasion played nove scores higher than best move...
        push @opt_coordinate_moves, $bestmove->{move}; 
        push @opt_move_scores,      $bestmove->{cp};
        push @move_scores,          $playedmove->{cp};
        push @move_mate_in,         $playedmove->{matein}; 
        push @opt_move_mate_in,     $bestmove->{matein}; 
    	}
    
    my $end = time;
    
    die "something went wrong..." if !@move_scores;

    $dbh->do(
      'UPDATE games SET processed = ?, coordinate_moves = ?, move_scores = ?, opt_coordinate_moves = ?, opt_move_scores = ?, move_mate_in = ?, opt_move_mate_in = ?, time_s = ? WHERE id = ?',
      undef,
      1, join(',', @coordinate_moves), join(',', @move_scores), join(',', @opt_coordinate_moves), join(',', @opt_move_scores), join(',', @move_mate_in), join(',', @opt_move_mate_in), $end - $start, $game->{id}
      );
    
    # end of loop.
    say "Evaluating game $game->{id}";
    } while(defined $game);
say 'Exit ok.';
exit 0;

#-----------------------------------------------	
sub startengine {
#-----------------------------------------------	
	my %args = (
		hashsize => 512,
		ownbook  => 'true',
		@_
		);
	my $count = 0;
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
			last;
		}
	}
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
		@_
		);
	my %data; #holds the output
	my ($bestmove, $multipv, $umwandler);
		
	# some logic to determine command. Might be neater to use each here, and append $key $val if defined.
	my $command = 'go';
	$command .= " depth " . $args{depth} if defined $args{depth};
	my @searchmoves = @{$args{searchmoves}};
	if(@searchmoves) { $command .= ' searchmoves '; $command .= join(' ', @searchmoves); } 
	print "Debug: $command".$/;

	print $Engine "position fen $args{fen}\n" if defined $args{fen};
	print $Engine $command.$/;
	while (<$Reader>) {

		my $line = $_;
		$line =~ s/\n|\r//g;

		if ($line =~ m/multipv/) {
			print color 'red';
			print "$line\n";
			print color 'reset';
			$multipv = $line;
			}
 		if ($line =~ m/bestmove /) {
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
					else { $data{mate} = shift @pvdata; $data{cp} = 'NA'; }
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

# --------------------------------------------------------------------------------------------------
sub get_host_ip {
# --------------------------------------------------------------------------------------------------
# Parse the ENV hash to get ip
	while((my $key, my $value) = each(%ENV)) {
		print $key . '> ' . $value . $/;
		if($value =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/){ return ($1); }
		}
	die "Host ip not found in ENV";
}

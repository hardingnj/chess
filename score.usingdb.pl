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

my $VERSION = "0.02";
my $cfg = LoadFile("./proto.yaml");
my $engine  = $cfg->{Engine};
my $players = $cfg->{Players};
my @dataout;

my $perlversion = sprintf "%vd", $^V;
my $osstring = $^O;

print "set interface $engine (Perl: $perlversion  OS: $osstring)\n";

# establish connection to database. 
my $dbh = DBI->connect('dbi:mysql:pgnpilot','root','442mufc') or die "Connection Error: $DBI::errstr\n";

# instantiate engine.
my ($Reader, $Engine);
my $pid = open2($Reader,$Engine,$engine);
startengine(hashsize => $cfg->{hashsize});

# this is will be a reference to an object. of type game. loop is conditional on this being defined, when no more games this is no longer defined and loop exits.
my $game;

# Main loop is here!
do {

    # select eligible games
    my $sql = "select id, pgnmoves from games WHERE processed = 0";
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
    
    my @pgn_moves = split(/,/, $game->{pgnmoves});
    
    my @moves;
    my @bestmoves;
    my @score_bestmoves;
    my @score_moves;
    my @mate_moves;
    my @mate_bestmoves;
    
    my $pos = Chess::Rep->new;
    my $current_state;
    my $halfmovecounter = 0;
    # loop through moves: 
    #   do analysis
    foreach my $move (@pgn_moves) { 
    	# set current state as FEN
    	$current_state = $pos->get_fen;
    	++$halfmovecounter;
    	
    	# update board with current move & capture move info
    	my $status = $pos->go_move($move);
    	my $move_uci_format = $status->{from}.$status->{to}; 
    
        push @moves, $move_uci_format;

    	# code to skip 3 lines if not interested in player, or not eval opening.
    	if ($cfg->{EvalAfter} >= ($halfmovecounter/2)) {
              push @bestmoves,       'NA';
              push @score_bestmoves, 'NA';
              push @score_moves,     'NA';
              push @mate_moves,      'NA';
              push @mate_bestmoves,  'NA';
              next;
              }
             
    	my $playedmove = choosemove(fen => $current_state, searchmoves => [$move_uci_format], depth => $cfg->{Depth});
    	my $bestmove   = choosemove(depth => $cfg->{Depth});
    
    	# on occasion played nove scores higher than best move...
            push @bestmoves,       $bestmove->{move}; 
            push @score_bestmoves, $bestmove->{cp};
            push @score_moves,     $playedmove->{cp};
            push @mate_moves,      $playedmove->{matein}; 
            push @mate_bestmoves,  $bestmove->{matein}; 
    	}
    
    my $end = time;
    
    die "something went wrong..." if !@score_moves;

    $dbh->do(
      'UPDATE games SET processed = ?, moves = ?, scores = ?, bestmoves = ?, bestscores = ?, playedmatein = ?, bestmatein = ?, time_s = ? WHERE id = ?',
      undef,
      1, join(',', @moves), join(',', @score_moves), join(',', @bestmoves), join(',', @score_bestmoves), join(',', @mate_moves), join(',', @mate_bestmoves), $end - $start, $game->{id}
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
				# used if multiple best moves.
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

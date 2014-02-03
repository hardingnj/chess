#!/usr/bin/perl

use DBI;
use strict;
use Time::Local;

my $start = timegm 0,0,0,1,0,60;
my $end   = timegm 0,0,0,1,0,86;

my @names = qw/Bradley Evia Corrin Erinn Louisa Genevie Marlana Shanti Laree Spencer Trish Kathaleen Raeann Reita Cathie Hien Terresa Maisie Darcey Dorine Lorita Kristofer Eddy Kera Yolando Nicole Kathlene Don Elenor Charmai/;

my @foods = qw/bacon bagel bake baked Alaska bamboo shoots banana barbecue barley basil batter beancurd beans beef beet bell pepper berry biscuit bitter black beans blackberry black-eyed peas black tea bland blood orange blueberry boil bowl boysenberry bran bread breadfruit breakfast brisket broccoli broil brownie brown rice brunch Brussels sprouts buckwheat buns burrito butter /;

my $driver = "mysql"; 
my $database = "events";
my $host_ip = get_host_ip();
my $dsn = "DBI:$driver:database=$database;hostname=$host_ip";
my $userid = "admin";
my $password = "changeme";

my $dbh = DBI->connect($dsn, $userid, $password ) or die $DBI::errstr;

for(0..29) {
	my $name = $names[$_];
	my $food = $foods[$_];
	my $confirmed = (rand() < 0.5) ? 'Y' : 'N';
	my $signup_date = scalar gmtime $start + rand $end - $start;
	my $sth = $dbh->prepare("INSERT INTO potluck
                       (name, food, confirmed, signup_date)
                        values
                       (?,?,?,?)");
	$sth->execute($name,$food,$confirmed, $signup_date) 
		or die $DBI::errstr;
	$sth->finish();
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

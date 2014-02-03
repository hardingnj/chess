#!/usr/bin/perl

use DBI;
use strict;

my $driver = "mysql"; 
my $database = "events";
my $dsn = "DBI:$driver:database=$database";
my $userid = "admin";
my $password = "changeme";

my $dbh = DBI->connect($dsn, $userid, $password ) or die $DBI::errstr;

CREATE DATABASE IF NOT EXISTS pgnpilot;
use pgnpilot;

CREATE TABLE IF NOT EXISTS players (
    pid int(10) unsigned NOT NULL auto_increment,
    given_name varchar(128) NOT NULL,
    surname varchar(128) NOT NULL,
    aliases varchar(128) NOT NULL,
    PRIMARY KEY (pid)
    );

CREATE TABLE IF NOT EXISTS games (
    id int(10) unsigned NOT NULL auto_increment,
    event varchar(128) NOT NULL default '',
    site varchar(128) NOT NULL default '',
    white int(10) unsigned NOT NULL,
    black int(10) unsigned NOT NULL,
    result int(1) NOT NULL,
    year int(4) NOT NULL,
    month int(2),
    day int(1), 
    round int(2),
    whiteELO int(4),
    blackELO int(4),
    ECO varchar(8),
    pgnmoves varchar(4000) NOT NULL default '',
    moves varchar(4000),
    scores varchar(4000),
    bestmoves varchar(4000),
    bestscores varchar(4000),
    playedmatein varchar(4000),
    bestmatein varchar(4000),
    processed integer(1) NOT NULL default 0,
    time_s integer (6),
    PRIMARY KEY (id),
    FOREIGN KEY (white) REFERENCES players(pid),
    FOREIGN KEY (black) REFERENCES players(pid)
    );

CREATE DATABASE IF NOT EXISTS pgnpilot;
use pgnpilot;

CREATE TABLE IF NOT EXISTS players (
    pid int(10) unsigned NOT NULL auto_increment,
    given_name varchar(128) NOT NULL,
    surname varchar(128) NOT NULL,
    PRIMARY KEY (pid)
    );

CREATE TABLE IF NOT EXISTS files (
    fid int(10) unsigned NOT NULL auto_increment,
    checksum varchar(128) NOT NULL,
    filename varchar(2000) NOT NULL,
    PRIMARY KEY (fid)
    );

CREATE TABLE IF NOT EXISTS games (
    id int(10) unsigned NOT NULL auto_increment,
    event varchar(128) NOT NULL default '',
    site varchar(128) NOT NULL default '',
    fileid int(10) unsigned NOT NULL,
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
    algebraic_moves varchar(4000) NOT NULL default '',
    coordinate_moves varchar(4000),
    move_scores varchar(4000),
    move_mate_in varchar(4000),
    opt_algebraic_moves varchar(4000),
    opt_coordinate_moves varchar(4000),
    opt_move_scores varchar(4000),
    opt_move_mate_in varchar(4000),
    processed integer(1) NOT NULL default 0,
    time_s integer (6),
    PRIMARY KEY (id),
    FOREIGN KEY (fileid) REFERENCES files (fid),
    FOREIGN KEY (white) REFERENCES players(pid),
    FOREIGN KEY (black) REFERENCES players(pid)
    );

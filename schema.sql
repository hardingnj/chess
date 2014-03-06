CREATE TABLE IF NOT EXISTS players (
    pid INTEGER PRIMARY KEY,
    given_name TEXT NOT NULL,
    surname TEXT NOT NULL
    );

CREATE TABLE IF NOT EXISTS files (
    fid INTEGER PRIMARY KEY,
    completed INTEGER NOT NULL default 0,
    checksum TEXT NOT NULL,
    filename TEXT NOT NULL
    );

CREATE TABLE IF NOT EXISTS games (
    id INTEGER PRIMARY KEY,
    event TEXT NOT NULL default '',
    site TEXT NOT NULL default '',
    fileid INTEGER NOT NULL,
    white INTEGER NOT NULL,
    black INTEGER NOT NULL,
    result INTEGER NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER,
    day INTEGER, 
    round INTEGER,
    whiteELO INTEGER,
    blackELO INTEGER,
    ECO TEXT,
    algebraic_moves TEXT NOT NULL default '',
    coordinate_moves TEXT,
    move_scores TEXT,
    move_mate_in TEXT,
    opt_algebraic_moves TEXT,
    opt_coordinate_moves TEXT,
    opt_move_scores TEXT,
    opt_move_mate_in TEXT,
    processed integer(1) NOT NULL default 0,
    time_s integer (6),
    FOREIGN KEY (fileid) REFERENCES files (fid),
    FOREIGN KEY (white) REFERENCES players(pid),
    FOREIGN KEY (black) REFERENCES players(pid)
    );

chess
=====

# Introduction
This is a personal project with the aim of using a strong chess engine to empirically evaluate moves in a large number of chess games (potentially over 2 million). The 3 main purposes of this are: 1. Identify objectively the strongest players in history. 2. Establish a baseline of performance expectation to identify cheating in chess. 3. Use information about the type of move to identify general weaknesses in human play, i.e. backward moves are harder to find, or knight moves harder to find. 

# About the code
The code is designed to be as platform independent as possible and makes substantive use of Docker- the open source container engine. In fact this code is as much an excuse to explore the functionality of Docker as it is to address the problem outlined above. Docker is particulalry useful in this instance as it is necessary to run the code on separate machines/VMs to enable this to be in any way feasible. The code is broken into 2 component parts- a parse script that converts PGN data into a database form. An evaluation script that evaluates games found in the database and records the results. Each of these components exists in a separate docker container.

# Aknowledgements
Much of this code has been inspired by and borrowed from several sources on the internet, most notably:
* Ben Schwartz at http://txt.fliglio.com/2013/11/creating-a-mysql-docker-container/ for the implementation of a docker sql server.
* Ralph Schuler at http://ralphschuler.ch/about for the perl/stockfish interface.
* Chris Cooper for valuable assistance with SQLite, and being an all round top dude.

# Supplementary files
- *INIT_NODE.sh*: This installs docker and downloads the hardingnj/scorepgn image from the Docker repo.
- *INIT_HEAD.sh*: This installs docker, sqlite3 and downloads the hardingnj/parsepgn image from the Docker repo.
- *KILL.sh*: This stops and removes all running or non-running docker containers.
- *pgn2fen.sh*: Utility script to parse a pgn file into fen. Might get it's own container someday.
- *run-XXX-YYY*: Short convenience scripts to run docker containers on different systems.

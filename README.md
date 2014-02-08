chess
=====

# Introduction
This is a personal project with the aim of using a strong chess engine to empirically evaluate moves in a large number of chess games (potentially over 2 million). The 3 main purposes of this are: 1. Identify objectively the strongest players in history. 2. Establish a baseline of performance expectation to identify cheating in chess. 3. Use information about the type of move to identify general weaknesses in human play, i.e. backward moves are harder to find, or knight moves harder to find. 

# About the code
The code is designed to be as platform independent as possible and makes substantive use of Docker- the open source container engine. In fact this code is as much an excuse to explore the functionality of Docker as it is to address the problem outlined above. Docker is particulalry useful in this instance as it is necessary to run the code on separate machines/VMs to enable this to be in any way feasible. The code is broken into 3 component parts- an parse script that converts PGN data into a database form. An evaluation script that evaluates games found in the database and records the results. Finally an sql server that enables each script to update a database shared across machines. Each of these components exists in a separate docker container. Both the parse and the eval code containers are linked to a parent sql server container.

# Aknowledgements
Much of this code has been inspired by and borrowed from several sources on the internet, most notably:
* Ben Schwartz at http://txt.fliglio.com/2013/11/creating-a-mysql-docker-container/ for the implementation of a docker sql server.
* Ralph Schuler at http://ralphschuler.ch/about for the perl/stockfish interface

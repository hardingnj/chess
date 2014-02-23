#! /bin/bash
# This bash script simply kicks off the 3 containers required to run the evaluation.

# first pull the necessary images/ most recent versions.

sudo docker pull hardingnj/sqlcontainer
sudo docker run -d -name sqlserver -p 3305:3305 -v mysql:/var/lib/mysql hardingnj/sqlcontainer
sleep 20;

sudo docker pull hardingnj/parsepgn
sudo docker run -d -t -link sqlserver:db -name parsePGN -v /glusterfs/users/nharding/pgn_data:/pgn:ro hardingnj/parsepgn
sleep 20;

sudo docker pull hardingnj/scorepgn
sudo docker run -d -t -link sqlserver:db -name scorePGN hardingnj/scorepgn

#! /bin/bash
# This bash script simply kicks off the 3 containers required to run the evaluation.

# first pull the necessary images/ most recent versions.
HOSTLOC=/glusterfs/users/nharding/
#HOSTLOC=/home/nharding/

sudo docker pull hardingnj/parsepgn
sudo docker run -d -t -name parsepgn -v ${HOSTLOC}/pgn_data:/pgn:ro -v ${HOSTLOC}/chessDB:/data hardingnj/parsepgn

sudo docker pull hardingnj/scorepgn
sudo docker run -d -t -name scorepgn -v ${HOSTLOC}/chessDB:/data hardingnj/scorepgn --hashsize 1600

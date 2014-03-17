#! /bin/bash
# This bash script simply kicks off the 3 containers required to run the evaluation.

# first pull the necessary images/ most recent versions.
#HOSTLOC=/glusterfs/users/nharding/
HOSTLOC=/home/nharding/

sudo docker run -d -t -name parsepgn -v ${HOSTLOC}/pgn_data:/pgn:ro -v ${HOSTLOC}/chessDB:/data parsepgn
sleep 10;
sudo docker run -d -t -name scorepgn -v ${HOSTLOC}/chessDB:/data scorepgn --hashsize 600 --verbose

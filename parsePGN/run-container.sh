#!/bin/sh
# This is a simple bash script to run the parse container.
# - rm command kills as soon as complete.

# PATH IS THE LOCATION ON THE HOST OF THE PGN FILES
#PATH='/glusterfs/users/nharding/pgn_data'
HOSTPATH='/home/nharding/PGN_test/'
# 
#docker run -t -rm -link sqlserver:db -name parseContainer -v $PATH:/pgn:ro parsePGN
docker run --rm -i -t -link sqlserver:db -name parsePGN -v $HOSTPATH:/pgn:ro parsePGN

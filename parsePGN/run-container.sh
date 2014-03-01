#!/bin/sh
# This is a simple bash script to run the parse container.
# - rm command kills as soon as complete.
# PATH IS THE LOCATION ON THE HOST OF THE PGN FILES
#PATH='/glusterfs/users/nharding/pgn_data'
HOSTPATH='/home/nharding/PGN_test/'
docker run -i -t -name parsepgn -v $HOSTPATH:/pgn:ro -v /home/nharding/sqldata/:/data parsepgn

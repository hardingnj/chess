#!/bin/sh
# This is a simple bash script to run the parse container on a local CPU
# - rm command kills as soon as complete.
# PATH IS THE LOCATION ON THE HOST OF THE PGN FILES'
docker run -d -t -v ${HOME}/pgn_data:/pgn:ro -v ${HOME}/chessDB:/data parsepgn $@

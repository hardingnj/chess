#!/bin/sh
# -t for tag? -i for interactive 
docker run -d -t -v ${HOME}/chessDB:/data scorepgn $@

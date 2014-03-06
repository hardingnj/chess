#!/bin/sh
# -t for tag? -i for interactive 
HOSTPATH='/home/nharding/'
docker run -d -t -name scorepgn -v ${HOSTPATH}/chessDB:/data scorepgn $@

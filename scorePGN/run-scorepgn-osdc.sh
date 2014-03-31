#!/bin/sh
# -t for tag? -i for interactive 
export HOSTPATH=/glusterfs/users/nharding/
docker run -d -t -v ${HOSTPATH}/chessDB:/data hardingnj/scorepgn $@

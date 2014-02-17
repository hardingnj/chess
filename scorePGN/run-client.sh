#!/bin/sh
# -t for tag? -i for interactive 
docker run -d -t -link sqlserver:db -name scorePGN scorePGN

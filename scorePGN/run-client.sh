#!/bin/sh
# -t for tag? -i for interactive 
docker run -t -i -link sqlserver:db -name scorePGN scorePGN

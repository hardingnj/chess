Create Dockerfile and image with req software.

Submit to repo

Decide on way to write to persistent storage from multiple containers.

### METHOD ###
1. Create docker images on compute note. Save compute node as a snapshot. 
2. Have a docker data-only container with a volume /usr/nharding/mysql/. This should create the database??
3. Run this volume on one(?) node.
4. docker run -volumes-from chess-data chess-process

# TASKS
# Eval player strengh
# Identify cheats
# Identify themes of bad moves, ie. given elo at time of mistake, queen move, pawn move, backwards move
# 


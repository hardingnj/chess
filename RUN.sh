#! /bin/bash

# kill existing containers
sudo docker stop $(sudo docker ps -a -q)
sudo docker rm $(sudo docker ps -a -q)

# run sql_server
sudo ./sql_container/run-server.sh

# build
cd parsePGN
sudo bash build.sh
sudo bash run-container.sh

cd ../scorePGN
sudo bash build.sh
sudo bash run-client.sh

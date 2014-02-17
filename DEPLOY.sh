#! /bin/bash
sudo bash sql_container/run-server.sh
sleep 5
sudo bash parsePGN/run-container.sh
sleep 5
sudo bash scorePGN/run-client.sh

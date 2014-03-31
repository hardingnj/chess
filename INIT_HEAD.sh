# install docker
sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install -y --force-yes lxc-docker
sudo docker pull hardingnj/parsepgn

export HOSTLOC=/glusterfs/users/nharding/

#mkdir $HOSTLOC/chessDB
#rm $HOSTLOC/chessDB/chessAnalysis.db
#sudo apt-get install sqlite3
#curl -O https://raw.githubusercontent.com/hardingnj/chess/master/schema.sql
#sqlite3 $HOSTLOC/chessDB/chessAnalysis.db < schema.sql

docker run -d -t -name parsepgn -v ${HOSTLOC}/pgn_data:/pgn:ro -v ${HOSTLOC}/chessDB:/data parsepgn $@

# install docker
sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install -y --force-yes lxc-docker
sudo apt-get install -y sqlite3
sudo apt-get install -y git

sudo docker pull hardingnj/parsepgn
export HOSTPATH=/glusterfs/users/nharding/

git clone https://github.com/hardingnj/chess $HOSTPATH

# IF SPECIFIED THEN DELETE AND REGEN DB FILE
#mkdir $HOSTPATH/chessDB
#rm $HOSTPATH/chessDB/chessAnalysis.db
#curl -O https://raw.githubusercontent.com/hardingnj/chess/master/schema.sql
#sqlite3 $HOSTPATH/chessDB/chessAnalysis.db < schema.sql

# install docker
sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install lxc-docker

sudo docker pull hardingnj/scorepgn
HOSTLOC=/glusterfs/users/nharding/
sudo docker run -d -t -name scorepgn -v ${HOSTLOC}/chessDB:/data hardingnj/scorepgn --hashsize 1600

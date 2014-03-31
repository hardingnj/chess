# install docker
sudo sh -c "echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list"
sudo apt-get update
sudo apt-get install -y --force-yes lxc-docker

sudo docker pull hardingnj/scorepgn

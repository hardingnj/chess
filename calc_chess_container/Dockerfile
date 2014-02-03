# This is a Dockerfile
# chess
#
# VERSION       1

# To install: 
# stockfish
# perl cpan?
#use DBI;
#use Chess::PGN::Parse;
#use Text::Names qw/cleanName composeName parseName2 samePerson/;
#use YAML qw/Dump/;
#use FileHandle;
#use IPC::Open2;
#use Term::ANSIColor;
#use Chess::Rep;
# mysql
# git

# use the ubuntu base image provided by dotCloud
FROM ubuntu

MAINTAINER Nicholas Harding nickharding@fastmail.net

# make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update

# install stockfish
RUN apt-get install -y curl
RUN apt-get install -y unzip
RUN apt-get install -y make
RUN apt-get install -y build-essential g++
RUN curl https://s3.amazonaws.com/stockfish/stockfish-dd-src.zip -o /home/stockfish.zip
RUN unzip /home/stockfish.zip -d /home/
RUN cd /home/stockfish-dd-src/src/ && make build ARCH=x86-32
ENV PATH $PATH:/home/stockfish-dd-src/src/

# install perl and modules
RUN apt-get install -y perl
RUN apt-get install -y cpanminus
RUN cpanm YAML::Any
RUN cpanm Chess::PGN::Parse
RUN cpanm Chess::Rep
RUN cpanm FileHandle
RUN cpanm IPC::Open2
RUN cpanm Term::ANSIColor
RUN perl -e 'use YAML; print "YAML ok"'

# install sql
#RUN apt-get install -y mysql-server

# install git
RUN apt-get install -y git
RUN git clone https://github.com/hardingnj/chess.git

# Launch memcached when launching the container
#ENTRYPOINT ["memcached"]

# run memcached as the daemon user
#USER daemon

# expose memcached port
#EXPOSE 11211

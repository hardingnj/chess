# This is a Dockerfile
# VERSION       1

# use the ubuntu base image provided by dotCloud
FROM ubuntu

MAINTAINER Nicholas Harding nickharding@fastmail.net

# make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update

# install perl and modules
RUN apt-get install -y build-essential
RUN apt-get install -y make
RUN apt-get install -y perl
RUN apt-get install -y cpanminus

#RUN emerge perl && perl-cleaner allmodules 
RUN cpanm -v PerlIO::locale
RUN cpanm IPC::Open2
RUN cpanm -v Text::Names
RUN cpanm YAML::Any
RUN cpanm Chess::PGN::Parse
RUN cpanm File::Find::Rule

# install sql
RUN apt-get install -y mysql-client

ADD ./startup.sh /opt/startup.sh
ADD ./PGN_db.sql /opt/PGN_db.sql
ADD ./parsePGN.pl /opt/parsePGN.pl
ADD ./settings.yaml /opt/settings.yaml

CMD ["/bin/bash", "/opt/startup.sh"]

FROM debian:wheezy
#FROM ubuntu:12.04

RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -sf /bin/true /sbin/initctl

RUN echo "deb http://http.debian.net/debian wheezy main" > /etc/apt/sources.list
RUN echo "deb-src http://http.debian.net/debian wheezy main" >> /etc/apt/sources.list
RUN apt-get update
RUN apt-get upgrade -y


RUN apt-get -y install mysql-client mysql-server

RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

ADD ./startup.sh /opt/startup.sh

EXPOSE 3305

CMD ["/bin/bash", "/opt/startup.sh"]

#!/bin/sh

docker run -d -p 3305:3305 -v /data/mysql:/var/lib/mysql mysql

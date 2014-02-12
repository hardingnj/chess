#!/bin/sh
# -d = daemon, -name for later linking -p for port -v for volume, we map host /data/mysql to /var/lib/mysql
docker run -d -name sqlserver -p 3305:3305 -v /data/mysql:/var/lib/mysql mysql

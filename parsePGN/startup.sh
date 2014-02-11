#! /bin/bash
# This bash script executes when the Parse container starts.

# located at /opt/startup.sh
echo Executing startup script

# first initialize the database
export HOSTIP=$(env | perl -ne 'if($_ =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) { print $1; exit 0; }')
mysql --user=admin --password=changeme -h $HOSTIP < /opt/PGN_db.sql

# now kick off the perl script
for PGN in `ls /pgn/*pgn`;
  do perl /opt/parsePGN.pl $PGN;
done;

echo exiting startup script

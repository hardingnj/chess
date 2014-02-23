#! /bin/bash
# This bash script executes when the Parse container starts.

# located at /opt/startup.sh
echo Executing startup script

# first initialize the database
export HOSTIP=$(env | perl -ne 'if($_ =~ m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/) { print $1; exit 0; }')
perl /opt/scorePGN.pl $@;

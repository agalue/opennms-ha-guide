#!/bin/sh

source /vagrant/files/base.sh

master=$1
type=$2

if [ -z "$master" ]; then
  echo "Please provide the IP or FQDN of the Master PostgreSQL server"
fi
if [ -z "$type" ]; then
  echo "Please provide the type of recover: partial or full"
fi

echo "Recovering from $master"
if ping -c 1 $master &> /dev/null; then
  if [ $type == "partial" ]; then
    sudo runuser -l postgres -c "$pg_home/bin/repmgr -f /etc/repmgr/$pg_version/repmgr.conf --verbose -D $pg_data/data -d repmgr -p 5432 -U repmgr -R postgres standby clone $master"
  else
    sudo runuser -l postgres -c "$pg_home/bin/repmgr -f /etc/repmgr/$pg_version/repmgr.conf --verbose --force --rsync-only -D $pg_data/data -d repmgr -p 5432 -U repmgr -R postgres standby clone $master"
  fi
else
  echo "ERROR: $master is unreachable."
fi

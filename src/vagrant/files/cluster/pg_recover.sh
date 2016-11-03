#!/bin/sh

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
    sudo runuser -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf --verbose -D /var/lib/pgsql/9.4/data -d repmgr -p 5432 -U repmgr -R postgres standby clone $master"
  else
    sudo runuser -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf --verbose --force --rsync-only -D /var/lib/pgsql/9.5/data -d repmgr -p 5432 -U repmgr -R postgres standby clone $master"
  fi
else
  echo "ERROR: $master is unreachable."
fi

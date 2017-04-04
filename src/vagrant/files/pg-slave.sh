#!/bin/bash

source /vagrant/files/postgres.sh

# Configure Passwords

if [ ! -f "$pg_data/.configured" ]; then
  create_pgpass
  sudo touch $pg_data/.configured
fi

# Configure repmgr

sudo cat <<EOF > /etc/repmgr/$pg_version/repmgr.conf 
cluster=opennms_cluster
node=2
node_name=pgdbsrv02
conninfo='host=pgdbsrv02 user=repmgr dbname=repmgr'
use_replication_slots=1 # Only for PostgreSQL 9.4 or newer
loglevel=INFO
pg_bindir=$pg_home/bin/
pg_basebackup_options='--xlog-method=stream'
master_response_timeout=30
reconnect_attempts=3
reconnect_interval=10
failover=manual
promote_command='$pg_home/bin/repmgr standby promote -f /etc/repmgr/$pg_version/repmgr.conf'
follow_command='$pg_home/bin/repmgr standby follow -f /etc/repmgr/$pg_version/repmgr.conf'
EOF

chown postgres:postgres /etc/repmgr/$pg_version/repmgr.conf

# Restore PostgreSQL data for Slave

if [ ! -f "$pg_data/.restored" ]; then
  sudo runuser -l postgres -c "$pg_home/bin/repmgr -f /etc/repmgr/$pg_version/repmgr.conf --verbose -D $pg_data/data -d repmgr -p 5432 -U repmgr -R postgres standby clone pgdbsrv01"
  sudo touch $pg_data/.restored
fi

# Start PostgreSQL

sudo systemctl enable postgresql-$pg_version
sudo systemctl start postgresql-$pg_version

# Register Slave with repmgr

if [ ! -f "$pg_data/.registered" ]; then
  sudo runuser -l postgres -c "$pg_home/bin/repmgr -f /etc/repmgr/$pg_version/repmgr.conf --verbose standby register"
  sudo touch $pg_data/.registered
fi


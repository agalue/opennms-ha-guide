#!/bin/bash

source /vagrant/files/postgres.sh

# Configure Passwords

if [ ! -f "/var/lib/pgsql/9.5/.configured" ]; then
  create_pgpass
  sudo touch /var/lib/pgsql/9.5/.configured
fi

# Configure repmgr

sudo cat <<EOF > /etc/repmgr/9.5/repmgr.conf 
cluster=opennms_cluster
node=2
node_name=pgdbsrv02
conninfo='host=pgdbsrv02 user=repmgr dbname=repmgr'
use_replication_slots=1 # Only for PostgreSQL 9.4 or newer
loglevel=INFO
pg_bindir=/usr/pgsql-9.5/bin/
pg_basebackup_options='--xlog-method=stream'
master_response_timeout=30
reconnect_attempts=3
reconnect_interval=10
failover=manual
promote_command='/usr/pgsql-9.5/bin/repmgr standby promote -f /etc/repmgr/9.5/repmgr.conf'
follow_command='/usr/pgsql-9.5/bin/repmgr standby follow -f /etc/repmgr/9.5/repmgr.conf'
EOF

chown postgres:postgres /etc/repmgr/9.5/repmgr.conf

# Restore PostgreSQL data for Slave

if [ ! -f "/var/lib/pgsql/9.5/.restored" ]; then
  sudo runuser -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf --verbose -D /var/lib/pgsql/9.5/data -d repmgr -p 5432 -U repmgr -R postgres standby clone pgdbsrv01"
  sudo touch /var/lib/pgsql/9.5/.restored
fi

# Start PostgreSQL

sudo systemctl enable postgresql-9.5
sudo systemctl start postgresql-9.5

# Register Slave with repmgr

if [ ! -f "/var/lib/pgsql/9.5/.registered" ]; then
  sudo runuser -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf --verbose standby register"
  sudo touch /var/lib/pgsql/9.5/.registered
fi


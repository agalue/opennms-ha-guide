#!/bin/bash

source /vagrant/files/postgres.sh

# Configure Passwords

if [ ! -f "$pg_data/.configured" ]; then
  create_pgpass
  sudo touch $pg_data/.configured
fi

# Configure repmgr

sudo cat <<EOF > $repmgr_cfg
node_id=2
node_name=pgdbsrv02
conninfo='host=pgdbsrv02 user=repmgr dbname=repmgr'
data_directory=$pg_data/data
use_replication_slots=true
log_level=INFO
pg_basebackup_options='--xlog-method=stream'
reconnect_attempts=3
reconnect_interval=10
failover=manual
pg_bindir='/usr/pgsql-$pg_version/bin'
promote_command='$repmgr_bin standby promote -f $repmgr_cfg --log-to-file'
follow_command='$repmgr_bin standby follow -f $repmgr_cfg --log-to-file --upstream-node-id=%n'
service_start_command='sudo systemctl start postgresql-$pg_version'
service_stop_command='sudo systemctl stop postgresql-$pg_version'
service_reload_command='sudo systemctl reload postgresql-$pg_version'
service_restart_command='sudo systemctl restart postgresql-$pg_version'
EOF

chown postgres:postgres $repmgr_cfg

# Restore PostgreSQL data for Slave

if [ ! -f "$pg_data/.restored" ]; then
  sudo runuser -l postgres -c "$repmgr_bin -f $repmgr_cfg -v -d repmgr -U repmgr -R postgres standby clone pgdbsrv01"
  sudo touch $pg_data/.restored
fi

# Start PostgreSQL

sudo systemctl enable postgresql-$pg_version
sudo systemctl start postgresql-$pg_version

# Register Slave with repmgr

if [ ! -f "$pg_data/.registered" ]; then
  sudo runuser -l postgres -c "$repmgr_bin -f $repmgr_cfg -v standby register"
  sudo touch $pg_data/.registered
fi


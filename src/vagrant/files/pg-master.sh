#!/bin/bash

source /vagrant/files/postgres.sh

# Initialize Database

if [ ! -f "$pg_data/data/pg_hba.conf" ]; then

  sudo $pg_home/bin/postgresql$pg_family-setup initdb

  sudo cat <<EOF > $pg_data/data/pg_hba.conf
# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IP local connections:
host    all             all             127.0.0.1/32            ident
host    all             all             ::1/128                 ident

# OpenNMS Access
host    opennms         opennms         onmssrv01.local         md5
host    template1       postgres        onmssrv01.local         md5
host    opennms         opennms         onmssrv02.local         md5
host    template1       postgres        onmssrv02.local         md5

# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     postgres                                peer
host    replication     postgres        127.0.0.1/32            md5
host    replication     postgres        ::1/128                 md5

# repmgr Access
host    repmgr          repmgr          pgdbsrv01.local         md5
host    replication     repmgr          pgdbsrv01.local         md5
host    repmgr          repmgr          pgdbsrv02.local         md5
host    replication     repmgr          pgdbsrv02.local         md5

# pgpool-II Access
host    all             pgpool          onmssrv01.local         md5
host    all             pgpool          onmssrv02.local         md5
EOF

  # The following provides the minimum required changes for pgpool-II.
  # Tuning for production is not included here.
  replication_slots=3
  postgresql_conf=$pg_data/data/postgresql.conf
  sudo sed -r -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $postgresql_conf
  sudo sed -r -i "/default_statistics_target/s/^#//" $postgresql_conf
  sudo sed -r -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'repmgr_funcs'/" $postgresql_conf
  sudo sed -r -i "s/#wal_level = minimal/wal_level = 'hot_standby'/" $postgresql_conf
  sudo sed -r -i "s/#max_replication_slots = 0/max_replication_slots = $replication_slots/" $postgresql_conf
  sudo sed -r -i "s/#max_wal_senders = 0/max_wal_senders = $replication_slots/" $postgresql_conf
  sudo sed -r -i "s/#wal_buffers = -1/wal_buffers = 16MB/" $postgresql_conf
  sudo sed -r -i "s/#checkpoint_completion_target = 0.5/checkpoint_completion_target = 0.7/" $postgresql_conf
  sudo sed -r -i "s/#wal_sender_timeout = 60s/wal_sender_timeout = 1s/" $postgresql_conf
  sudo sed -r -i "s/#log_connections = off/log_connections = on/" $postgresql_conf
  # In theory, the following line is for the standby server.
  sudo sed -r -i "s/#hot_standby = off/hot_standby = on/" $postgresql_conf
  # [OPTIONAL] Enable WAL Archiving (not required for streaming replication)
  #sudo sed -r -i "s/#wal_keep_segments = 0/wal_keep_segments = 32/" $postgresql_conf
  #sudo sed -r -i "s/#archive_mode = off/archive_mode = on/" $postgresql_conf
  #sudo sed -r -i "s/#archive_command = ''/archive_command = 'cp %p /path_to/archive/%f'/" $postgresql_conf

fi

# Configure repmgr

sudo cat <<EOF > $repmgr_cfg
node_id=1
node_name=pgdbsrv01
conninfo='host=pgdbsrv01 user=repmgr dbname=repmgr'
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

sudo chown postgres:postgres $repmgr_cfg

# Start PostgreSQL

sudo systemctl enable postgresql-$pg_version
sudo systemctl start postgresql-$pg_version

# Configure Roles and Passwords

if [ ! -f "$pg_data/.configured" ]; then
  sudo runuser -l postgres -c "psql -c \"CREATE ROLE pgpool SUPERUSER CREATEDB CREATEROLE INHERIT REPLICATION LOGIN ENCRYPTED PASSWORD '$pgpool_dbpass';\""
  sudo runuser -l postgres -c "psql -c \"CREATE USER repmgr SUPERUSER REPLICATION LOGIN ENCRYPTED PASSWORD '$repmgr_dbpass';\""
  sudo runuser -l postgres -c "psql -c \"CREATE DATABASE repmgr OWNER repmgr;\""
  sudo runuser -l postgres -c "psql -c \"CREATE USER opennms SUPERUSER CREATEDB ENCRYPTED PASSWORD '$opennms_dbpass';\""
  sudo runuser -l postgres -c "psql -c \"ALTER USER postgres WITH ENCRYPTED PASSWORD '$postgres_dbpass';\""
  create_pgpass
  sudo touch $pg_data/.configured
fi

# Register Master with repmgr

if [ ! -f "$pg_data/.registered" ]; then
  sudo runuser -l postgres -c "$pg_home/bin/repmgr -f /etc/repmgr/$pg_version/repmgr.conf --verbose master register"
  sudo touch $pg_data/.registered
fi

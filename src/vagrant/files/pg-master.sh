#!/bin/bash

source /vagrant/files/postgres.sh

# Initialize Database

if [ ! -f "/var/lib/pgsql/9.5/data/pg_hba.conf" ]; then

  sudo /usr/pgsql-9.5/bin/postgresql95-setup initdb

  sudo cat <<EOF > /var/lib/pgsql/9.5/data/pg_hba.conf
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

  postgresql_conf=/var/lib/pgsql/9.5/data/postgresql.conf
  sudo sed -r -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" $postgresql_conf
  sudo sed -r -i "/default_statistics_target/s/^#//" $postgresql_conf
  sudo sed -r -i "s/#shared_preload_libraries = ''/shared_preload_libraries = 'repmgr_funcs'/" $postgresql_conf
  sudo sed -r -i "s/#wal_level = minimal/wal_level = hot_standby/" $postgresql_conf
  sudo sed -r -i "s/#wal_buffers = -1/wal_buffers = 16MB/" $postgresql_conf
  sudo sed -r -i "s/#checkpoint_completion_target = 0.5/checkpoint_completion_target = 0.7/" $postgresql_conf
  sudo sed -r -i "s/#archive_mode = off/archive_mode = on/" $postgresql_conf
  sudo sed -r -i "s/#archive_command = ''/archive_command = 'cd .'/" $postgresql_conf
  sudo sed -r -i "s/#max_wal_senders = 0/max_wal_senders = 2/" $postgresql_conf
  sudo sed -r -i "s/#wal_sender_timeout = 60s/wal_sender_timeout = 1s/" $postgresql_conf
  sudo sed -r -i "s/#max_replication_slots = 0/max_replication_slots = 2/" $postgresql_conf
  sudo sed -r -i "s/#hot_standby = off/hot_standby = on/" $postgresql_conf

fi

# Configure repmgr

sudo cat <<EOF > /etc/repmgr/9.5/repmgr.conf 
cluster=opennms_cluster
node=1
node_name=pgdbsrv01
conninfo='host=pgdbsrv01 user=repmgr dbname=repmgr'
use_replication_slots=1 # Only for PostgreSQL 9.4 o newer
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

sudo chown postgres:postgres /etc/repmgr/9.5/repmgr.conf

# Start PostgreSQL

sudo systemctl enable postgresql-9.5
sudo systemctl start postgresql-9.5

# Configure Roles and Passwords

if [ ! -f "/var/lib/pgsql/9.5/.configured" ]; then
  sudo runuser -l postgres -c "psql -c \"CREATE ROLE pgpool SUPERUSER CREATEDB CREATEROLE INHERIT REPLICATION LOGIN ENCRYPTED PASSWORD '$pgpool_dbpass';\""
  sudo runuser -l postgres -c "psql -c \"CREATE USER repmgr SUPERUSER REPLICATION LOGIN ENCRYPTED PASSWORD '$repmgr_dbpass';\""
  sudo runuser -l postgres -c "psql -c \"CREATE DATABASE repmgr OWNER repmgr;\""
  sudo runuser -l postgres -c "psql -c \"CREATE USER opennms SUPERUSER CREATEDB ENCRYPTED PASSWORD '$opennms_dbpass';\""
  sudo runuser -l postgres -c "psql -c \"ALTER USER postgres WITH ENCRYPTED PASSWORD '$postgres_dbpass';\""
  create_pgpass
  sudo touch /var/lib/pgsql/9.5/.configured
fi

# Register Master with repmgr

if [ ! -f "/var/lib/pgsql/9.5/.registered" ]; then
  sudo runuser -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf --verbose master register"
  sudo touch /var/lib/pgsql/9.5/.registered
fi


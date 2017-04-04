#!/bin/bash

source /vagrant/files/base.sh

# PostgreSQL Packages

if ! rpm -qa | grep -q postgresql$pg_family-server; then
  sudo yum install $pg_repo_url -y
  sudo yum install postgresql$pg_family postgresql$pg_family-server postgresql$pg_family-libs postgresql$pg_family-contrib repmgr$pg_family pgpool-II-$pg_family rsync -y
fi

# Create DB Cleanup Script

sudo cat <<EOF >> /usr/local/bin/dbcleanup.sh
#!/bin/bash 
# cleanup.sh This script close all the DB connections from \$1 to the \$2 database 
# @author Alejandro Galue <agalue@opennms.org> 
 
if [[ ( -n "\$1" ) && ( -n "\$2" ) ]]; then
   /bin/psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '\$1' AND pg_stat_activity.client_hostname LIKE '\$2' AND pid <> pg_backend_pid();"
else
   echo "ERROR: Invalid arguments."
   echo "Usage: dbcleanup DB_NAME SRC_SERVER_MATCH"
fi
EOF

sudo chmod 0700 /usr/local/bin/dbcleanup.sh
sudo chown postgres:postgres /usr/local/bin/dbcleanup.sh

# Configure Firewall

sudo firewall-cmd --permanent --add-service=postgresql 
sudo firewall-cmd --add-service=postgresql
sudo firewall-cmd --reload 

# Copy SSH Keys

copy_postgres_ssh_keys

# Create PGPass

function create_pgpass {
  sudo runuser -l postgres -c "echo '*:*:*:repmgr:$repmgr_dbpass' > ~/.pgpass"
  sudo runuser -l postgres -c "echo '*:*:replication:postgres:$postgres_dbpass' >> ~/.pgpass"
  sudo runuser -l postgres -c "chmod 600 ~/.pgpass"
  sudo restorecon -R /var/lib/pgsql/
}


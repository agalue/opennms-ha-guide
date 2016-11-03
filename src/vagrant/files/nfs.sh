#!/bin/bash

source /vagrant/files/base.sh

# Enable and Start NFS

sudo systemctl enable rpcbind nfs-server
sudo systemctl start rpcbind nfs-server

# Configure Firewall

sudo firewall-cmd --permanent --add-service=nfs
sudo firewall-cmd --add-service=nfs
sudo firewall-cmd --reload 

# Configure Shared Locations

sudo mkdir -p /opt/opennms/etc
sudo mkdir -p /opt/opennms/share
sudo mkdir -p /opt/opennms/pgpool

# Configure exports

sudo cat <<EOF > /etc/exports
/opt/opennms/etc      192.168.205.0/24(rw,sync,no_root_squash)
/opt/opennms/share    192.168.205.0/24(rw,sync,no_root_squash)
/opt/opennms/pgpool   192.168.205.0/24(rw,sync,no_root_squash)
EOF

# Configure PostgreSQL user

sudo mkdir /var/lib/pgsql
sudo groupadd -r -g 26 postgres
sudo useradd -r -u 26 -M -d /var/lib/pgsql -n -g postgres postgres
sudo chown postgres:postgres /var/lib/pgsql/
sudo chown postgres:postgres /opt/opennms/pgpool

# Restart NFS

sudo systemctl restart rpcbind nfs-server


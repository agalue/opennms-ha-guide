#!/bin/bash

source /vagrant/files/opennms.sh

# Configure NFS

if [ ! -f "~/.nfs_configured" ] && [ $use_nfs -eq 1 ]; then
  echo "Configuring NFS ..."
  tar czf ~/backup-opennms-etc.tar.gz /opt/opennms/etc/*
  tar czf ~/backup-opennms-var.tar.gz /var/opennms/*
  tar czf ~/backup-pgpool-etc.tar.gz /etc/pgpool-II-95/*
  sudo rm -rf /opt/opennms/etc/*
  sudo rm -rf /var/opennms/*
  sudo rm -rf /etc/pgpool-II-95/*
  sudo touch ~/.nfs_configured
fi

# Configure DRBD

if [ ! -f "~/.drbd_configured" ] && [ $use_nfs -eq 0 ]; then
  echo "Configuring DRBD ..."
  configure_drbd_resource
  sudo drbdadm secondary opennms
  sudo mkdir -p /drbd
  sudo rm -rf /opt/opennms/etc
  sudo rm -rf /var/opennms
  sudo rm -rf /etc/pgpool-II-95
  sudo ln -s /drbd/opennms/etc /opt/opennms/etc
  sudo ln -s /drbd/opennms/var /var/opennms
  sudo ln -s /drbd/pgpool/etc /etc/pgpool-II-95
  sudo touch ~/.drbd_configured
fi

# Configure Cluster
# Alternatively, we can start it directly at onmssrv01 with something like this:  ssh onmssrv01 '/vagrant/files/cluster_setup_drbd.sh'

sudo systemctl start pcsd
/vagrant/files/cluster_init.sh
if [ $use_nfs -eq 1 ]; then
  /vagrant/files/cluster_setup_nfs.sh
else
  /vagrant/files/cluster_setup_drbd.sh
fi

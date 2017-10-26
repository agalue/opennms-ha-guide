#!/bin/bash

source /vagrant/files/base.sh

echo "Cluster Setup - Topology 2"
echo
echo "* 2 PostgreSQL Servers behind PGPool-II with repmgr"
echo "* 2 OpenNMS Servers active/passive using Pacemaker, sharing data using DRBD"
echo

echo "Creating Cluster Configuration file"

sudo pcs cluster cib ~/onms-cluster.cfg

echo "Creating VIP resource"

sudo pcs -f ~/onms-cluster.cfg resource create virtual_ip ocf:heartbeat:IPaddr2 \
  ip=192.168.205.150 \
  cidr_netmask=32 \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating shared storage with DRBD"

sudo pcs -f ~/onms-cluster.cfg resource create onms_data ocf:linbit:drbd \
  drbd_resource=opennms op monitor interval=10s

sudo pcs -f ~/onms-cluster.cfg resource master onms_data_master onms_data \
  master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true

sudo pcs -f ~/onms-cluster.cfg constraint colocation add onms_app with onms_data_master INFINITY with-rsc-role=Master
sudo pcs -f ~/onms-cluster.cfg constraint order promote onms_data_master then start onms_app

echo "Creating shared filesystem"

sudo pcs -f ~/onms-cluster.cfg resource create opennms_fs Filesystem \
  device="/dev/drbd1" directory="/drbd" fstype="xfs" \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating pgpool-II"

sudo pcs -f ~/onms-cluster.cfg resource create pgpoolII_bin systemd:pgpool-II-$pg_family \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating grafana"

sudo pcs -f ~/onms-cluster.cfg resource create grafana_bin systemd:grafana-server \
  op monitor interval=30s on-fail=standby \
  --group onms_app meta \
  target-role="Started" migration-threshold=1

echo "Creating opennms"

sudo pcs -f ~/onms-cluster.cfg resource create opennms_bin systemd:opennms \
  op start timeout=180s \
  op stop timeout=180s \
  op monitor interval=90s timeout=60s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Prefering onmssrv01"

sudo pcs -f ~/onms-cluster.cfg constraint location onms_app prefers onmssrv01=50
sudo pcs -f ~/onms-cluster.cfg constraint location onms_app avoids onmssrv02=50

echo "Pushing cluster configuration ..."

sudo pcs cluster cib-push ~/onms-cluster.cfg

echo "Checking cluster..."
sleep 30
sudo pcs status

echo "IMPORTANT: Remember to enable services on both servers..."


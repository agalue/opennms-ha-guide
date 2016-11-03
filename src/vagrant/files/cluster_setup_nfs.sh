#!/bin/bash

echo "Cluster Setup - Topology 1"
echo
echo "* 2 PostgreSQL Servers behind PGPool-II with repmgr"
echo "* 2 OpenNMS Servers active/passive using Pacemaker, sharing data using NFS"
echo "* 1 NFS Server (shared data)"
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

echo "Creating shared filesystems : /opt/opennms/etc"

sudo pcs -f ~/onms-cluster.cfg resource create opennms_etc ocf:heartbeat:Filesystem \
  device="nfssrv01:/opt/opennms/etc" \
  directory="/opt/opennms/etc" \
  fstype="nfs" \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating shared filesystems : /var/opennms"

sudo pcs -f ~/onms-cluster.cfg resource create opennms_var ocf:heartbeat:Filesystem \
  device="nfssrv01:/opt/opennms/share" \
  directory="/var/opennms" \
  fstype="nfs" \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating shared filesystems : /etc/pgpool-II-95"

sudo pcs -f ~/onms-cluster.cfg resource create pgpoolII_etc ocf:heartbeat:Filesystem \
  device="nfssrv01:/opt/opennms/pgpool" \
  directory="/etc/pgpool-II-95" \
  fstype="nfs" \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating pgpool-II"

sudo pcs -f ~/onms-cluster.cfg resource create pgpoolII_bin systemd:pgpool-II-95 \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

echo "Creating grafana"

sudo pcs -f ~/onms-cluster.cfg resource create grafana_bin systemd:grafana-server \
  op monitor interval=30s on-fail=standby \
  --group onms_app \
  meta target-role="Started" migration-threshold=1

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


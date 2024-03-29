#!/bin/bash

# Timezone

timezone=EST

# Java

java_url=http://download.oracle.com/otn-pub/java/jdk/8u172-b11/a58eab1ec242421181065cdc37240b08/jdk-8u172-linux-x64.rpm

# Cassandra

cassandra_seed=192.168.205.161
cassandra_passwd=cassandra

# PostgreSQL

pg_family=96
pg_version=9.6
pg_repo_version=9.6-3
pg_repo_url=https://download.postgresql.org/pub/repos/yum/$pg_version/redhat/rhel-7-x86_64/pgdg-centos$pg_family-$pg_repo_version.noarch.rpm

pg_home="/usr/pgsql-$pg_version"
pg_data="/var/lib/pgsql/$pg_version"
repmgr_cfg="/etc/repmgr/$pg_version/repmgr.conf"
repmgr_bin="$pg_home/bin/repmgr"

pgpool_dbpass=pgpool
repmgr_dbpass=repmgr
opennms_dbpass=opennms
postgres_dbpass=postgres

# OpenNMS
# Use NFS for Shared Content: use_nfs=1
# Use DRBD for Shared Content: use_nfs=0
# Use stable, snapshot, bleading for OpenNMS branch

use_newts=1
use_nfs=0
onms_branch=stable

# Cluster
# Topology 1: NFS for Shared Storage
# Topology 2: DRBD for Shared Storage

hacluster_passwd=opennms

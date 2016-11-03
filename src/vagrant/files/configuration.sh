#!/bin/bash

# Timezone

timezone=EST

# Java

java_version=8u101
java_build=13

# Cassandra

cassandra_seed=192.168.205.161
cassandra_passwd=cassandra

# PostgreSQL

pgpool_dbpass=pgpool
repmgr_dbpass=repmgr
opennms_dbpass=opennms
postgres_dbpass=postgres

# OpenNMS
# Use NFS for Shared Content: use_nfs=1
# Use DRBD for Shared Content: use_nfs=0

use_newts=1
use_nfs=0

# Cluster
# Topology 1: NFS for Shared Storage
# Topology 2: DRBD for Shared Storage

hacluster_passwd=opennms

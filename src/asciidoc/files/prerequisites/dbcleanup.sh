#!/bin/bash
# dbcleanup.sh This script should cleanup DB connections prior starting pgpool
# @author Alejandro Galue <agalue@opennms.org>

DB_SRVS="pgdbsrv01 pgdbsrv02"
ONMS_SRV="onmssrv0%"
ONMS_DB="opennms"

date
echo
rm -f /tmp/.s.PGSQL.9* /var/log/pgpool-II-95/*
for pgserver in $DB_SRVS; do
echo "Cleaning up DB connections on $pgserver ..."
su - postgres -c "/usr/bin/ssh -T -l postgres $pgserver '/usr/loca/bin/dbcleanup.sh $ONMS_DB $ONMS_SRV'"
done

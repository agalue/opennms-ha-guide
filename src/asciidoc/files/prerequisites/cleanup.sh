#!/bin/bash
# cleanup.sh This script close all the DB connections from $1 to the $2 database
# @author Alejandro Galue <agalue@opennms.org>

if [[ ( -n "$1" ) && ( -n "$2" ) ]]; then
   /bin/psql -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$1' AND pg_stat_activity.client_h
ostname LIKE '$2' AND pid <> pg_backend_pid();"
else
   echo "ERROR: Invalid arguments."
   echo "Usage: dbcleanup DB_NAME SRC_SERVER_MATCH"
fi

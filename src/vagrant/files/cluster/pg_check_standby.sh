#!/bin/bash

sudo runuser -l postgres -c "psql -c 'SELECT pg_is_in_recovery();'"
sudo runuser -l postgres -c "psql -x -U repmgr -h pgdbsrv01 -d repmgr -c 'SELECT * FROM repmgr_opennms_cluster.repl_nodes;'"

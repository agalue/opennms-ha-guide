#!/bin/bash

sudo runuser -l postgres -c "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf cluster show"

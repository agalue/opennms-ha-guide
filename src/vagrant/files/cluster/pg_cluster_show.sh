#!/bin/bash

source /vagrant/files/base.sh

sudo runuser -l postgres -c "$pg_home/bin/repmgr -f /etc/repmgr/$pg_version/repmgr.conf cluster show"

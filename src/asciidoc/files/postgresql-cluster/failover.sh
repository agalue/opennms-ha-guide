#!/bin/sh
failed_node=$1
new_master=$2
(
date
echo "Failed node: $failed_node, Promoting $new_master ..."
set -x
/usr/bin/ssh -T -l postgres $new_master "/usr/pgsql-9.4/bin/repmgr -f /etc/repmgr/9.4/repmgr.conf standby promote 2>/dev/null 1>/dev/null <&-"
exit 0;
) 2>&1 | tee -a /var/log/pgpool/pgpool_failover.log

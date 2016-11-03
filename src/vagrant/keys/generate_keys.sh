#!/bin/sh

servers=("onmssrv01" "onmssrv02" "pgdbsrv01" "pgdbsrv02");

rm -rf *id_rsa*

for server in "${servers[@]}"; do
  echo "Generating keys for $server"
  ssh-keygen -q -N '' -t rsa -f ${server}_id_rsa -n postgres@${server}.local -C postgres@${server}.local
done

find . -type f -name '*id_rsa.pub' -exec cat {} + >> authorized_keys

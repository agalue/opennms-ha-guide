#!/bin/bash

source /vagrant/files/configuration.sh

echo "Authenticating cluster"
sudo pcs cluster auth -u hacluster -p $hacluster_passwd onmssrv01 onmssrv02

echo "Creating cluster"
sudo pcs cluster destroy --all
sudo pcs cluster setup --name cluster_onms onmssrv01 onmssrv02

echo "Starting cluster"
sudo pcs cluster start --all
echo "Waiting ..."
sleep 30
sudo pcs status

echo "Disabling Stonith (for now)"
sudo pcs property set stonith-enabled=false

echo "Ignoring low quorum"
sudo pcs property set no-quorum-policy=ignore

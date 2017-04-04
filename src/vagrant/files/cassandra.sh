#!/bin/bash

source /vagrant/files/base.sh

# Disable Swap

sudo swapoff -a

# Install Java

setup_java

# Install Cassandra

sudo cat <<EOF > /etc/yum.repos.d/datastax.repo
[datastax]
name = DataStax Repo for Apache Cassandra
baseurl = http://rpm.datastax.com/community
enabled = 1
gpgcheck = 0
EOF

if ! rpm -qa | grep -q cassandra30; then
  echo "Installing Cassandra ..."
  sudo yum install -y pytz cassandra30 cassandra30-tools
fi

# Configure Firewall

sudo cat <<EOF > /etc/firewalld/services/cassandra.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>cassandra</short>
  <description>Apache Cassandra</description>
  <port protocol="tcp" port="7199"/>
  <port protocol="tcp" port="7000"/>
  <port protocol="tcp" port="7001"/>
  <port protocol="tcp" port="9160"/>
  <port protocol="tcp" port="9042"/>
</service>
EOF

echo "Configuring Firewall ..."
sudo firewall-cmd --reload 
sudo firewall-cmd --permanent --add-service=cassandra
sudo firewall-cmd --add-service=cassandra
sudo firewall-cmd --reload 

# Configure Cassandra

echo "Configuring Cassandra ..."
cassandra_yaml=/etc/cassandra/conf/cassandra.yaml
eth1_ip=`ifconfig eth1 | grep 'inet ' | awk '{print $2}'`
sudo sed -r -i "/cluster_name/s/Test Cluster/OpenNMS Cluster/" $cassandra_yaml
sudo sed -r -i "/listen_address:/s/localhost/$eth1_ip/" $cassandra_yaml
sudo sed -r -i "/rpc_address:/s/localhost/$eth1_ip/" $cassandra_yaml
sudo sed -r -i "/- seeds:/s/127.0.0.1/$cassandra_seed/" $cassandra_yaml

# Configure JMX Access

sudo cat <<EOF > /etc/cassandra/jmxremote.password
monitorRole QED
controlRole R&D
cassandra $cassandra_passwd
EOF

sudo chown cassandra:cassandra /etc/cassandra/jmxremote.password
sudo chmod 400 /etc/cassandra/jmxremote.password
sudo echo "cassandra readwrite" >> /usr/java/latest/jre/lib/management/jmxremote.access

cassandra_env=/etc/cassandra/conf/cassandra-env.sh
sudo sed -r -i "s/LOCAL_JMX=yes/LOCAL_JMX=no/" $cassandra_env

# Enable and Start Cassandra

echo "Starting Cassandra ..."
sudo systemctl enable cassandra
sudo systemctl start cassandra


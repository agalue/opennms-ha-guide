#!/bin/bash

# Read common variables

source /vagrant/files/configuration.sh

# FIXME Abort if the operating system is not CentOS/RHEL 7

# Fix private interface issue
# https://github.com/mitchellh/vagrant/issues/5590

sudo nmcli connection reload
sudo systemctl restart network.service

# Setup DNS

sudo cat <<EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

192.168.205.150  onmssrvvip.local      onmssrvvip
192.168.205.151  onmssrv01.local       onmssrv01
192.168.205.152  onmssrv02.local       onmssrv02
192.168.205.153  pgdbsrv01.local       pgdbsrv01
192.168.205.154  pgdbsrv02.local       pgdbsrv02
192.168.205.155  nfssrv01.local        nfssrv01
192.168.205.161  cassandrasrv01.local  cassandrasrv01
192.168.205.162  cassandrasrv02.local  cassandrasrv02
192.168.205.163  cassandrasrv03.local  cassandrasrv03
EOF

sudo sed -r -i 's/#Domain =.*/Domain = local/' /etc/idmapd.conf

# NTP

if ! rpm -qa | grep -q ntpdate; then
  echo "Configuring time ..."
  sudo rm -f /etc/localtime && \
  sudo ln -s /usr/share/zoneinfo/$timezone /etc/localtime && \
  sudo yum -y install ntp ntpdate && \
  sudo ntpdate -u pool.ntp.org && \
  sudo systemctl enable ntpd && \
  sudo systemctl start ntpd
fi

# Haveged

if ! rpm -qa | grep -q haveged; then
  echo "Installing haveged ..."
  sudo yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm -y && \
  sudo yum install haveged -y && \
  sudo systemctl enable haveged && \
  sudo systemctl start haveged
fi

# Install Common Packages

if ! rpm -qa | grep -q net-tools; then
  echo "Installing common packages ..."
  sudo yum install net-tools vim wget curl net-snmp net-snmp-utils nfs-utils nfs-utils-lib git -y
fi

# Enable Firewall

echo "Enabling Firewall ..."
sudo systemctl enable firewalld 
sudo systemctl start firewalld
sudo firewall-cmd --permanent --add-interface=eth1
sudo firewall-cmd --add-interface=eth1

sudo cat <<EOF > /etc/firewalld/services/snmp.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>snmp</short>
  <description>SNMP</description>
  <port protocol="udp" port="161"/>
</service>
EOF
sudo firewall-cmd --reload 
sudo firewall-cmd --permanent --add-service=snmp
sudo firewall-cmd --add-service=snmp

# SNMP

echo "Configuring SNMP ..."
sudo cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.original
sudo cat <<EOF > /etc/snmp/snmpd.conf
com2sec localUser 192.168.205.0/24 public
group localGroup v1 localUser
group localGroup v2c localUser
view all included .1 80
access localGroup "" any noauth 0 all none none
syslocation VirtualBox
syscontact Alejandro Galue <agalue@opennms.org>
dontLogTCPWrappersConnects yes
disk /
EOF
sudo chmod 600 /etc/snmp/snmpd.conf
systemctl enable snmpd
systemctl start snmpd

# Java

function setup_java {
  if [ ! -f "/tmp/jdk-linux-x64.rpm" ]; then
    echo "Downloading Java ..."
    sudo wget --quiet --no-verbose --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" $java_url \
      -O /tmp/jdk-linux-x64.rpm 2>&1 >/dev/null
    echo "Installing Java ..."
    sudo yum install -y /tmp/jdk-linux-x64.rpm
  fi
}

# Update

function update_packages {
  sudo yum install -y update
}

# Copy SSH Keys

function copy_postgres_ssh_keys {
  if [ ! -f "/var/lib/pgsql/.ssh/id_rsa.pub" ]; then
    echo "Copying SSH Keys for Postgres ..."
    sudo runuser -l postgres -c "mkdir .ssh && chmod 700 .ssh" && \
    sudo echo "Host *" >> /var/lib/pgsql/.ssh/config && \
    sudo echo "    StrictHostKeyChecking no" >> /var/lib/pgsql/.ssh/config && \
    sudo chmod 400 /var/lib/pgsql/.ssh/config && \
    sudo cp /vagrant/keys/`hostname -s`_id_rsa /var/lib/pgsql/.ssh/id_rsa && \
    sudo chmod 600 /var/lib/pgsql/.ssh/id_rsa && \
    sudo cp /vagrant/keys/`hostname -s`_id_rsa.pub /var/lib/pgsql/.ssh/id_rsa.pub && \
    sudo chmod 644 /var/lib/pgsql/.ssh/id_rsa.pub && \
    sudo cp /vagrant/keys/authorized_keys /var/lib/pgsql/.ssh/ && \
    sudo chmod 600 /var/lib/pgsql/.ssh/authorized_keys && \
    sudo chown -R postgres:postgres /var/lib/pgsql/.ssh/
    echo "Copying SSH Keys for Vagrant ..."
    echo "Host *" >> ~/.ssh/config && \
    echo "    StrictHostKeyChecking no" >> ~/.ssh/config && \
    chmod 400 ~/.ssh/config && \
    cp /vagrant/keys/`hostname -s`_id_rsa ~/.ssh/id_rsa && \
    chmod 600 ~/.ssh/id_rsa && \
    sed 's/postgres/vagrant/' /vagrant/keys/`hostname -s`_id_rsa.pub > ~/.ssh/id_rsa.pub && \
    chmod 644 ~/.ssh/id_rsa.pub && \
    sed 's/postgres/vagrant/g' /vagrant/keys/authorized_keys >> ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys
  fi
}


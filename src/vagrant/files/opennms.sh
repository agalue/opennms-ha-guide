#!/bin/bash

source /vagrant/files/base.sh

# PostgreSQL Packages

if ! rpm -qa | grep -q postgresql95-server; then
  echo "Installing PostgreSQL ..."
  sudo yum install https://download.postgresql.org/pub/repos/yum/9.5/redhat/rhel-7-x86_64/pgdg-redhat95-9.5-2.noarch.rpm -y
  sudo yum install postgresql95 postgresql95-server postgresql95-libs pgpool-II-95 rsync -y
fi

# Copy SSH Keys

copy_postgres_ssh_keys

# Install Java

setup_java

# Install OpenNMS

if ! rpm -qa | grep -q opennms-core; then
  echo "Installing OpenNMS ..."
  sudo yum install http://yum.opennms.org/repofiles/opennms-repo-stable-rhel7.noarch.rpm -y
  sudo yum install jicmp jicmp6 jrrd2 rrdtool opennms-core opennms-webapp-jetty 'perl(LWP)' 'perl(XML::Twig)' -y
fi

# Install Grafana

if ! rpm -qa | grep -q grafana; then
  echo "Installing Grafana ..."
  sudo yum install -y initscripts fontconfig
  sudo yum install -y https://grafanarel.s3.amazonaws.com/builds/grafana-4.1.1-1484211277.x86_64.rpm
  sudo grafana-cli plugins install opennms-datasource
fi

# Install RedHat Cluster

if ! rpm -qa | grep -q pacemaker; then
  echo "Installing High Availability packages ..."
  sudo yum groupinstall "High Availability" -y
  echo "hacluster:$hacluster_passwd" > /tmp/.hacluster.pwd
  sudo chpasswd < /tmp/.hacluster.pwd
  rm /tmp/.hacluster.pwd
  sudo systemctl start pcsd
fi

# Install DRBD

if ! rpm -qa | grep -q kmod-drbd84; then
  echo "Installing DRBD ..."
  sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
  sudo yum install -y http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
  sudo yum install -y kmod-drbd84 drbd84-utils
  sudo curl -o /usr/lib/ocf/resource.d/linbit/drbd 'http://git.linbit.com/gitweb.cgi?p=drbd-utils.git;a=blob_plain;f=scripts/drbd.ocf;h=cf6b966341377a993d1bf5f585a5b9fe72eaa5f2;hb=c11ba026bbbbc647b8112543df142f2185cb4b4b'
  sudo yum install -y policycoreutils-python
  sudo semanage permissive -a drbd_t
fi

# Create DB Cleanup Script

sudo cat <<EOF > /usr/local/bin/dbcleanup.sh
#!/bin/bash 
# dbcleanup.sh This script should cleanup DB connections prior starting pgpool 
# @author Alejandro Galue <agalue@opennms.org> 
 
DB_SRVS="pgdbsrv01 pgdbsrv02"
ONMS_SRV="onmssrv0%"
ONMS_DB="opennms"
 
date
echo
rm -f /tmp/.s.PGSQL.9* /var/log/pgpool-II-95/*
for pgserver in \$DB_SRVS; do
echo "Cleaning up DB connections on \$pgserver ..."
su - postgres -c "/usr/bin/ssh -T -l postgres \$pgserver '/usr/local/bin/dbcleanup.sh \$ONMS_DB \$ONMS_SRV'"
done
EOF

sudo chmod 0700 /usr/local/bin/dbcleanup.sh

# Update PGPool-II Script

sudo cat <<EOF > /lib/systemd/system/pgpool-II-95.service
[Unit]
Description=PGPool-II Middleware Between PostgreSQL Servers And PostgreSQL Database Clients
After=syslog.target network.target
 
[Service]
User=postgres
Group=postgres
PermissionsStartOnly=true
EnvironmentFile=-/etc/sysconfig/pgpool-II-95
ExecStartPre=/usr/local/bin/dbcleanup.sh
ExecStart=/usr/pgpool-9.5/bin/pgpool -f /etc/pgpool-II-95/pgpool.conf \$OPTS
ExecStop=/usr/pgpool-9.5/bin/pgpool -f /etc/pgpool-II-95/pgpool.conf -m fast stop
 
[Install]
WantedBy=multi-user.target
EOF

sudo chmod 0644 /lib/systemd/system/pgpool-II-95.service

# Fix PGPool-II Settings and Permissions

sudo echo 'd /var/run/pgpool-II-95 0755 postgres postgres -' > /usr/lib/tmpfiles.d/pgpool-II-95.conf
sudo echo 'OPTS=" -n --discard-status"' > /etc/sysconfig/pgpool-II-95
sudo chown postgres:postgres /var/run/pgpool-II-95

# Update OpenNMS Script

sudo cat <<EOF > /usr/lib/systemd/system/opennms.service
[Unit]
Description=OpenNMS server
Wants=pgpool-II-95.service
Requires=network.target network-online.target
After=pgpool-II-95.service network.target network-online.target
 
[Service]
User=root
TimeoutStartSec=0
Type=forking
PIDFile=/opt/opennms/logs/opennms.pid
ExecStart=/opt/opennms/bin/opennms start
ExecStop=/opt/opennms/bin/opennms stop
 
[Install]
WantedBy=multi-user.target
EOF

# Update Systemd

sudo systemctl daemon-reload

# Configure Firewall

sudo cat <<EOF > /etc/firewalld/services/opennms.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>opennms</short>
  <description>OpenNMS Services with PgPool-II</description>
  <port protocol="tcp" port="5817"/>
  <port protocol="tcp" port="8980"/>
  <port protocol="tcp" port="18980"/>
  <port protocol="tcp" port="8181"/>
  <port protocol="tcp" port="9999"/>
  <port protocol="udp" port="162"/>
  <port protocol="udp" port="10514"/> <!-- Check syslogd-configuration.xml -->
</service>
EOF

sudo cat <<EOF > /etc/firewalld/services/drbd.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>drbd</short>
  <description>DRBD</description>
  <port protocol="tcp" port="7789"/>
</service>
EOF

echo "Configuring Firewall ..."
sudo firewall-cmd --reload
sudo firewall-cmd --permanent --add-service=opennms
sudo firewall-cmd --add-service=opennms
sudo firewall-cmd --permanent --add-service=drbd
sudo firewall-cmd --add-service=drbd
sudo firewall-cmd --permanent --add-service=high-availability
sudo firewall-cmd --add-service=high-availability 
sudo firewall-cmd --reload

# DRBD

function configure_drbd_resource {
  sudo cat <<EOF > ~/sdb.layout
# partition table of /dev/sdb
unit: sectors

/dev/sdb1 : start=     2048, size=  3905536, Id=83
/dev/sdb2 : start=        0, size=        0, Id= 0
/dev/sdb3 : start=        0, size=        0, Id= 0
/dev/sdb4 : start=        0, size=        0, Id= 0
EOF
  sudo sfdisk /dev/sdb < ~/sdb.layout

  sudo cat <<EOF > /etc/drbd.d/opennms.res
resource opennms {
  protocol C;
  meta-disk internal;
  disk /dev/sdb1;
  device /dev/drbd1;
  handlers {
    split-brain "/usr/lib/drbd/notify-split-brain.sh root";
  }
  net {
    allow-two-primaries no;
    after-sb-0pri discard-zero-changes;
    after-sb-1pri discard-secondary;
    after-sb-2pri disconnect;
    rr-conflict disconnect;
  }
  disk {
    on-io-error detach;
  }
  syncer {
    verify-alg sha1;
  }
  on onmssrv01.local {
    address 192.168.205.151:7789;
  }
  on onmssrv02.local {
    address 192.168.205.152:7789;
  }
}
EOF

  sudo sed -r -i "/usage-count/s/yes/no/" /etc/drbd.d/global_common.conf
  sudo echo drbd >/etc/modules-load.d/drbd.conf
  sudo drbdadm create-md opennms
  sudo modprobe drbd
  sudo drbdadm up opennms
}

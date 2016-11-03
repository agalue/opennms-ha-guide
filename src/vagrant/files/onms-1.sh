#!/bin/bash

source /vagrant/files/opennms.sh

# Configure PGPool-II

if [ ! -f "/etc/pgpool-II-95/.configured" ]; then
   echo "Configuring PGPool-II ..."
   pgpool_conf=/etc/pgpool-II-95/pgpool.conf
   sudo cp /etc/pgpool-II-95/pgpool.conf.sample-stream $pgpool_conf
   sudo sed -r -i "/listen_addresses/s/localhost/*/" $pgpool_conf 
   sudo sed -r -i "/backend_hostname0/s/host1/pgdbsrv01/" $pgpool_conf 
   sudo sed -r -i "/backend_data_directory0/s/= '\/data'/= '\/var\/lib\/pgsql\/9.5\/data'/" $pgpool_conf
   sudo sed -r -i "s/#backend_hostname1 = 'host2'/backend_hostname1 = 'pgdbsrv02'/" $pgpool_conf
   sudo sed -r -i "s/#backend_port1 = 5433/backend_port1 = 5432/" $pgpool_conf
   sudo sed -r -i "/backend_weight1/s/#//" $pgpool_conf
   sudo sed -r -i "s/#backend_data_directory1 = '\/data1'/backend_data_directory1 = '\/var\/lib\/pgsql\/9.5\/data'/" $pgpool_conf
   sudo sed -r -i "/backend_flag1/s/#//" $pgpool_conf
   sudo sed -r -i "/enable_pool_hba/s/off/on/" $pgpool_conf
   sudo sed -r -i "/num_init_children/s/32/60/" $pgpool_conf
   sudo sed -r -i "/max_pool/s/4/1/" $pgpool_conf
   sudo sed -r -i "/pid_file_name/s/=.*/= '\/var\/run\/pgpool-II-95\/pgpool.pid'/" $pgpool_conf
   sudo sed -r -i "/logdir/s/=.*/= '\/var\/log\/pgpool-II-95'/" $pgpool_conf
   sudo sed -r -i "/sr_check_user/s/nobody/pgpool/" $pgpool_conf
   sudo sed -r -i "/sr_check_password/s/''/'pgpool'/" $pgpool_conf
   sudo sed -r -i "/health_check_period/s/0/10/" $pgpool_conf
   sudo sed -r -i "/health_check_user/s/nobody/pgpool/" $pgpool_conf
   sudo sed -r -i "/health_check_password/s/''/'pgpool'/" $pgpool_conf
   sudo sed -r -i "/failover_command/s/''/'\/etc\/pgpool-II-95\/failover.sh %h %H'/" $pgpool_conf
   sudo sed -r -i "/recovery_user/s/nobody/pgpool/" $pgpool_conf
   sudo sed -r -i "/recovery_password/s/''/'pgpool'/" $pgpool_conf
   sudo chmod 0600 /etc/pgpool-II-95/pgpool.conf
   sudo chown postgres:postgres /etc/pgpool-II-95/pgpool.conf

   sudo cat <<EOF > /etc/pgpool-II-95/failover.sh
#!/bin/sh 
failed_node=\$1
new_master=\$2
(
date
echo "Failed node: \$failed_node, Promoting \$new_master ..."
set -x
/usr/bin/ssh -T -l postgres \$new_master "/usr/pgsql-9.5/bin/repmgr -f /etc/repmgr/9.5/repmgr.conf standby promote 2>/dev/null 1>/dev/null <&-"
exit 0;
) 2>&1 | tee -a /var/log/pgpool-II-95/pgpool_failover.log
EOF

  sudo chmod 0700 /etc/pgpool-II-95/failover.sh
  sudo chown postgres:postgres /etc/pgpool-II-95/failover.sh

  sudo cat <<EOF > /etc/pgpool-II-95/pool_hba.conf
# "local" is for Unix domain socket connections only 
local   all         all                               md5
# IPv4 local connections: 
host    all         all         127.0.0.1/32          md5
host    all         all         ::1/128               md5
host    all         all         0.0.0.0/0             md5
EOF

  sudo chmod 0600 /etc/pgpool-II-95/pool_hba.conf
  sudo chown postgres:postgres /etc/pgpool-II-95/pool_hba.conf

  sudo touch /etc/pgpool-II-95/pool_passwd
  sudo chmod 600 /etc/pgpool-II-95/pool_passwd
  sudo chown postgres:postgres /etc/pgpool-II-95/pool_passwd
  sudo runuser -l postgres -c "pg_md5 -m -u pgpool $pgpool_dbpass"
  sudo runuser -l postgres -c "pg_md5 -m -u repmgr $repmgr_dbpass"
  sudo runuser -l postgres -c "pg_md5 -m -u opennms $opennms_dbpass"
  sudo runuser -l postgres -c "pg_md5 -m -u postgres $postgres_dbpass"

  sudo echo "postgres:"`pg_md5 postgres` >> /etc/pgpool-II-95/pcp.conf
  sudo chmod 0600 /etc/pgpool-II-95/pcp.conf
  sudo chown postgres:postgres /etc/pgpool-II-95/pcp.conf

  sudo mkdir -p /var/log/pgpool-II-95
  sudo chown postgres:postgres /var/log/pgpool-II-95

  touch /etc/pgpool-II-95/.configured
fi

# Configure OpenNMS

if [ ! -f "~/.onms_configured" ]; then
  ONMS_ETC=/opt/opennms/etc

  cd /opt/opennms/etc/
  sudo git config --global user.name "Alejandro Galue"
  sudo git config --global user.email "agalue@opennms.org"
  sudo git init .
  sudo git add .
  sudo git commit -m "Default Configuration for OpenNMS `rpm -q --queryformat %{version} opennms-core`"
  
  sudo cat <<EOF > $ONMS_ETC/opennms.conf
START_TIMEOUT=120
JAVA_HEAP_SIZE=1024
#MAXIMUM_FILE_DESCRIPTORS=20480
ADDITIONAL_MANAGER_OPTIONS="-d64 -XX:+PrintGCTimeStamps -XX:+PrintGCDetails -Xloggc:/opt/opennms/logs/gc.log"
ADDITIONAL_MANAGER_OPTIONS="\${ADDITIONAL_MANAGER_OPTIONS} -XX:+UseG1GC -XX:+UseStringDeduplication"
ADDITIONAL_MANAGER_OPTIONS="\${ADDITIONAL_MANAGER_OPTIONS} -XX:+UnlockCommercialFeatures -XX:+FlightRecorder"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.port=18980"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.local.only=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.ssl=false"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dopennms.poller.server.serverHost=0.0.0.0"
ADDITIONAL_MANAGER_OPTIONS="\$ADDITIONAL_MANAGER_OPTIONS -Dcom.sun.management.jmxremote.authenticate=true"
EOF

  # Basic Configuration
  sudo sed -r -i "/jdbc:postgresql/s/5432/9999/" $ONMS_ETC/opennms-datasources.xml
  sudo sed -r -i "s/C3P0ConnectionFactory/HikariCPConnectionFactory/" $ONMS_ETC/opennms-datasources.xml
  sudo sed -r -i "s/password=\"opennms\"/password=\"$opennms_dbpass\"/" $ONMS_ETC/opennms-datasources.xml
  sudo sed -r -i "s/password=\"\"/password=\"$postgres_dbpass\"/" $ONMS_ETC/opennms-datasources.xml
  sudo sed -r -i "/rrdtool.MultithreadedJniRrdStrategy/s/#//" $ONMS_ETC/rrd-configuration.properties
  sudo sed -r -i "/jrrd2/s/#//" $ONMS_ETC/rrd-configuration.properties
  sudo sed -r -i "/rrd.storeBy/s/false/true/" $ONMS_ETC/opennms.properties
  sudo sed -r -i "s/#?org.opennms.rrd.storeBy/org.opennms.rrd.storeBy/" $ONMS_ETC/opennms.properties
  sudo sed -r -i "/org.opennms.timeseries.strategy=/s/#//" $ONMS_ETC/opennms.properties
  sudo sed -r -i "/OPENNMS_JDBC_HOSTNAME/s/5432/9999/" $ONMS_ETC/collectd-configuration.xml
  sudo sed -r -i "s/Postgres/PostgreSQL/" $ONMS_ETC/poller-configuration.xml
  sudo sed -r -i "port/s/5432/9999/" $ONMS_ETC/poller-configuration.xml
  if [ $use_newts -eq 1 ]; then
    sudo sed -r -i "/org.opennms.timeseries.strategy=/s/rrd/newts/" $ONMS_ETC/opennms.properties
    sudo sed -r -i "/org.opennms.newts.config.hostname=/s/#//" $ONMS_ETC/opennms.properties
    sudo sed -r -i "/org.opennms.newts.config.hostname=/s/localhost/192.168.205.161,192.168.205.162,192.168.205.163/" $ONMS_ETC/opennms.properties
  fi

  # Lab collection and polling interval (30 seconds)
  sudo sed -r -i 's/interval="300000"/interval="30000"/g' $ONMS_ETC/collectd-configuration.xml
  sudo sed -r -i 's/interval="300000" user/interval="30000" user/g' $ONMS_ETC/poller-configuration.xml
  sudo sed -r -i 's/step="300"/step="30"/g' $ONMS_ETC/poller-configuration.xml
  files=(`ls -l $ONMS_ETC/*datacollection-config.xml | awk '{print $9}'`)
  for f in "${files[@]}"; do
    if [ -f $f ]; then
      sudo sed -r -i 's/step="300"/step="30"/g' $f
    fi
  done

  # Execute the install script
  sudo systemctl start pgpool-II-95
  until /usr/pgsql-9.5/bin/psql -h localhost -p 9999 -U "postgres" -c '\l'; do
    >&2 echo "Postgres is unavailable - sleeping"
    sleep 1
  done
    >&2 echo "Postgres is up"
  sudo /opt/opennms/bin/runjava -S /usr/java/latest/bin/java
  sudo /opt/opennms/bin/install -dis
  sudo /opt/opennms/bin/newts init -r 2
  sudo systemctl stop pgpool-II-95

  sudo touch ~/.onms_configured
fi

# Backup Data

if [ ! -f "~/.backup_data" ]; then
  tar czf ~/backup-opennms-etc.tar.gz /opt/opennms/etc/*
  tar czf ~/backup-opennms-var.tar.gz /var/opennms/*
  tar czf ~/backup-pgpool-etc.tar.gz /etc/pgpool-II-95/*
  sudo touch ~/.backup_data
fi

# Configure NFS

if [ ! -f "~/.nfs_configured" ] && [ $use_nfs -eq 1 ]; then
  echo "Copying shared data to NFS server ..."
  if ping -c 1 nfssrv01 &> /dev/null; then
    sudo mount -t nfs -o vers=4 nfssrv01:/opt/opennms/etc/ /mnt/
    sudo rsync -avr /opt/opennms/etc/ /mnt/
    sudo umount /mnt
    sudo mount -t nfs -o vers=4 nfssrv01:/opt/opennms/share/ /mnt/
    sudo rsync -avr /var/opennms/ /mnt/
    sudo umount /mnt
    sudo mount -t nfs -o vers=4 nfssrv01:/opt/opennms/pgpool/ /mnt/
    sudo rsync -avr /etc/pgpool-II-95/ /mnt/
    sudo umount /mnt
    sudo rm -rf /opt/opennms/etc/*
    sudo rm -rf /var/opennms/*
    sudo rm -rf /etc/pgpool-II-95/*
  else
    echo "NFS Server unreachable, ignoring!"
  fi
  sudo touch ~/.nfs_configured
fi

# Configure DRBD

if [ ! -f "~/.drbd_configured" ] && [ $use_nfs -eq 0 ]; then
  echo "Configuring DRBD ..."
  configure_drbd_resource
  sudo drbdadm primary --force opennms
  sudo mkfs.xfs /dev/drbd1
  sudo mkdir /drbd
  sudo mount /dev/drbd1 /drbd/
  sudo mkdir -p /drbd/pgpool/etc /drbd/opennms/etc /drbd/opennms/var
  sudo rsync -avr --delete /opt/opennms/etc/ /drbd/opennms/etc/
  sudo rsync -avr --delete /var/opennms/ /drbd/opennms/var/
  sudo rsync -avr --delete /etc/pgpool-II-95/ /drbd/pgpool/etc/
  sudo rm -rf /opt/opennms/etc
  sudo rm -rf /var/opennms
  sudo rm -rf /etc/pgpool-II-95
  sudo ln -s /drbd/opennms/etc /opt/opennms/etc
  sudo ln -s /drbd/opennms/var /var/opennms
  sudo ln -s /drbd/pgpool/etc /etc/pgpool-II-95
  sudo touch ~/.drbd_configured
fi

# Configure Cluster

sudo systemctl start pcsd

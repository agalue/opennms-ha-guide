resource opennms {
  disk /dev/sdb1;
  device /dev/drbd1;
  meta-disk internal;
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

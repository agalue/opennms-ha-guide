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

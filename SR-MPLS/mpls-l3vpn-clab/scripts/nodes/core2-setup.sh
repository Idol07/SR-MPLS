#!/bin/sh
set -e
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.mpls.platform_labels=1048575 >/dev/null
sysctl -w net.mpls.conf.lo.input=1 >/dev/null
for i in eth1 eth2 eth3 eth4 eth5; do
  ip link set dev "$i" up
  sysctl -w net.mpls.conf.$i.input=1 >/dev/null
done
/usr/lib/frr/frrinit.sh start

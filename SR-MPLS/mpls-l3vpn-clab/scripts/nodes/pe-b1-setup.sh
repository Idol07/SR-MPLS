#!/bin/sh
set -e
sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.mpls.platform_labels=1048575 >/dev/null
sysctl -w net.mpls.conf.lo.input=1 >/dev/null
ip link add vrf-a type vrf table 101 2>/dev/null || true
ip link set dev vrf-a up
ip link add vrf-b type vrf table 102 2>/dev/null || true
ip link set dev vrf-b up
for i in eth1 eth2; do
  ip link set dev "$i" up
  sysctl -w net.mpls.conf.$i.input=1 >/dev/null
done
for i in eth3 eth4; do
  ip link set dev "$i" master vrf-a
  ip link set dev "$i" up
done
for i in eth5 eth6; do
  ip link set dev "$i" master vrf-b
  ip link set dev "$i" up
done
/usr/lib/frr/frrinit.sh start

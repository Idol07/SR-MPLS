#!/bin/sh
set -e
ip link add br0 type bridge vlan_filtering 1 2>/dev/null || true
ip link set dev br0 up
for p in eth1 eth2 eth3 eth4 eth5; do
  ip link set dev "$p" master br0
  ip link set dev "$p" up
  bridge vlan del dev "$p" vid 1 2>/dev/null || true
done
for p in eth1 eth2; do
  bridge vlan add dev "$p" vid 21
  bridge vlan add dev "$p" vid 101
done
bridge vlan add dev eth3 vid 21 pvid untagged
bridge vlan add dev eth4 vid 21 pvid untagged
bridge vlan add dev eth5 vid 101 pvid untagged

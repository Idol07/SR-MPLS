#!/bin/sh
set -e
sysctl -w net.ipv4.ip_forward=1 >/dev/null
for i in eth1 eth2 eth3 eth4 eth5 eth6; do ip link set dev $i up; done
ip link add link eth5 name eth5.20 type vlan id 20 2>/dev/null || true
ip link set dev eth5.20 up
ip addr add 172.17.20.2/24 dev eth5.20 2>/dev/null || true
ip addr add 172.17.20.1/24 dev eth5.20 2>/dev/null || true
ip link add link eth5 name eth5.100 type vlan id 100 2>/dev/null || true
ip link set dev eth5.100 up
ip addr add 192.168.100.2/24 dev eth5.100 2>/dev/null || true
ip addr add 192.168.100.1/24 dev eth5.100 2>/dev/null || true
ip link add link eth6 name eth6.21 type vlan id 21 2>/dev/null || true
ip link set dev eth6.21 up
ip addr add 172.17.21.3/24 dev eth6.21 2>/dev/null || true
ip link add link eth6 name eth6.101 type vlan id 101 2>/dev/null || true
ip link set dev eth6.101 up
ip addr add 192.168.101.3/24 dev eth6.101 2>/dev/null || true
/usr/lib/frr/frrinit.sh start

#!/bin/sh
set -e
sysctl -w net.ipv4.ip_forward=1 >/dev/null
for i in eth1 eth2 eth3 eth4 eth5 eth6; do ip link set dev $i up; done
ip link add link eth5 name eth5.10 type vlan id 10 2>/dev/null || true
ip link set dev eth5.10 up
ip addr add 172.16.10.2/24 dev eth5.10 2>/dev/null || true
ip addr add 172.16.10.1/24 dev eth5.10 2>/dev/null || true
ip link add link eth5 name eth5.100 type vlan id 100 2>/dev/null || true
ip link set dev eth5.100 up
ip addr add 192.168.100.2/24 dev eth5.100 2>/dev/null || true
ip addr add 192.168.100.1/24 dev eth5.100 2>/dev/null || true
ip link add link eth6 name eth6.11 type vlan id 11 2>/dev/null || true
ip link set dev eth6.11 up
ip addr add 172.16.11.3/24 dev eth6.11 2>/dev/null || true
ip link add link eth6 name eth6.101 type vlan id 101 2>/dev/null || true
ip link set dev eth6.101 up
ip addr add 192.168.101.3/24 dev eth6.101 2>/dev/null || true
/usr/lib/frr/frrinit.sh start

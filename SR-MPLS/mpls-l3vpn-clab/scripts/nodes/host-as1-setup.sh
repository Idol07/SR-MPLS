#!/bin/sh
set -e
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null

# eth1: Primary Uplink to as1 | eth2: Redundant Uplink to as | eth3: Overlap VLAN
for i in eth1 eth2 eth3; do
  ip link set dev "$i" up
  ip addr flush dev "$i"
done

ip addr add 172.16.11.11/24 dev eth1
ip addr add 172.16.10.11/24 dev eth2
ip addr add 192.168.101.11/24 dev eth3

# Dual-homed default routes via VRRP VIPs (Primary metric 10 via as1, Backup metric 20 via as)
ip route replace default via 172.16.11.1 dev eth1 metric 10
ip route append default via 172.16.10.1 dev eth2 metric 20 2>/dev/null || true

# Intra-VRF Overlapping IP route via VRRP VIP
ip route replace 192.168.100.0/24 via 192.168.101.1 dev eth3 src 192.168.101.11

echo "[host-as1] Dual-homed host configured (eth1=172.16.11.11/24 -> as1, eth2=172.16.10.11/24 -> as, eth3=192.168.101.11/24)."

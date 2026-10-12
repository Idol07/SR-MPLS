#!/bin/sh
set -e
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null

# eth1: Primary Uplink to bs | eth2: Redundant Uplink to bs1 | eth3: Overlap VLAN
for i in eth1 eth2 eth3; do
  ip link set dev "$i" up
  ip addr flush dev "$i"
done

ip addr add 172.17.20.10/24 dev eth1
ip addr add 172.17.21.10/24 dev eth2
ip addr add 192.168.100.10/24 dev eth3

# Dual-homed default routes via VRRP VIPs (Primary metric 10 via bs, Backup metric 20 via bs1)
ip route replace default via 172.17.20.1 dev eth1 metric 10
ip route append default via 172.17.21.1 dev eth2 metric 20 2>/dev/null || true

# Intra-VRF Overlapping IP route via VRRP VIP
ip route replace 192.168.101.0/24 via 192.168.100.1 dev eth3 src 192.168.100.10

echo "[host-bs] Dual-homed host configured (eth1=172.17.20.10/24 -> bs, eth2=172.17.21.10/24 -> bs1, eth3=192.168.100.10/24)."

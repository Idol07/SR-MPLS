#!/bin/sh
# Lightweight FHRP / VIP Failover Daemon (Active-Standby with Preemption & Gratuitous ARP)
# Usage: fhrp-watchdog.sh <iface> <primary_peer_ip> <vip_cidr> [vrf_name]

IFACE="$1"
PEER_IP="$2"
VIP_CIDR="$3"
VRF_NAME="${4:-}"
VIP_ONLY="${VIP_CIDR%/*}"

STATE="BACKUP"

while true; do
  if [ -n "$VRF_NAME" ]; then
    ip vrf exec "$VRF_NAME" ping -c 1 -W 1 "$PEER_IP" >/dev/null 2>&1
    RC=$?
  else
    ping -c 1 -W 1 "$PEER_IP" >/dev/null 2>&1
    RC=$?
  fi

  if [ "$RC" -ne 0 ]; then
    # Primary peer unreachable -> promote to MASTER and claim VIP
    if [ "$STATE" != "MASTER" ]; then
      ip addr add "$VIP_CIDR" dev "$IFACE" 2>/dev/null || true
      arping -c 2 -U -I "$IFACE" "$VIP_ONLY" >/dev/null 2>&1 || true
      STATE="MASTER"
      logger -t fhrp-watchdog "Promoted to MASTER for VIP ${VIP_CIDR} on ${IFACE}"
    fi
  else
    # Primary peer reachable -> preempt back to BACKUP
    if [ "$STATE" = "MASTER" ]; then
      ip addr del "$VIP_CIDR" dev "$IFACE" 2>/dev/null || true
      STATE="BACKUP"
      logger -t fhrp-watchdog "Preempted back to BACKUP for VIP ${VIP_CIDR} on ${IFACE}"
    fi
  fi
  sleep 1
done

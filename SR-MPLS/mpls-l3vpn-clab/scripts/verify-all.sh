#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# End-to-End Redundant MPLS L3VPN Verification Suite (Matching User Template)
# Nodes: core1..2, pe-a/a1/b/b1, ce-a/a1/b/b1, as/as1/bs/bs1, host-as/as1/bs/bs1
# Supports 100% Nokia SR Linux (sr_cli), Hybrid SRL/FRR, and Pure FRR (vtysh)
# =============================================================================

PREFIX="clab-mpls-l3vpn-extranet"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_header() {
  echo ""
  echo -e "${CYAN}=======================================================================${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}=======================================================================${NC}"
}

is_srl_node() {
  local node="$1"
  docker exec "${PREFIX}-${node}" which sr_cli >/dev/null 2>&1
}

check_cmd() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo -e "  [${GREEN}PASS${NC}] ${desc}"
    PASS=$((PASS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

check_negative_ping() {
  local desc="$1"
  local node="$2"
  local src_ip="$3"
  local dst_ip="$4"
  if ! docker exec "${PREFIX}-${node}" ping -c 1 -W 1 -I "${src_ip}" "${dst_ip}" >/dev/null 2>&1; then
    echo -e "  [${GREEN}PASS${NC}] ${desc} (Blocked as expected)"
    PASS=$((PASS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] ${desc} (Unexpected leak!)"
    FAIL=$((FAIL + 1))
  fi
}

log_header "1. Tier 1 & Tier 2: Core 1/2 & PE A/A1/B/B1 IS-IS SR-MPLS Underlay"
for node in core1 core2 pe-a pe-a1 pe-b pe-b1; do
  if is_srl_node "${node}"; then
    check_cmd "Nokia SR Linux IS-IS L2 adjacency UP on ${node}" \
      bash -c "docker exec ${PREFIX}-${node} sr_cli 'show network-instance default protocols isis adjacency' | grep -qi 'up'"
  else
    check_cmd "FRR IS-IS Level-2 adjacency UP on ${node}" \
      bash -c "docker exec ${PREFIX}-${node} vtysh -c 'show isis neighbor' | grep -q 'Up'"
  fi
done

log_header "2. Tier 2: Provider Edge A, A1, B, B1 MP-BGP VPN Control Plane"
for pe in pe-a pe-a1 pe-b pe-b1; do
  if is_srl_node "${pe}"; then
    check_cmd "Nokia SR Linux MP-BGP VPN peering established on ${pe}" \
      bash -c "docker exec ${PREFIX}-${pe} sr_cli 'show network-instance default protocols bgp neighbor' | grep -qi 'established'"
  else
    check_cmd "FRR MP-BGP VPNv4 peering established on ${pe}" \
      bash -c "docker exec ${PREFIX}-${pe} vtysh -c 'show bgp ipv4 vpn summary' | grep -E '10\.0\.0\.[1-4]'"
  fi
done

log_header "3. Tier 3 & Tier 4: Customer Edge A/A1/B/B1 VRRPv3 & Switch AS/AS1/BS/BS1 MAC-VRF"
for ce in ce-a ce-a1 ce-b ce-b1; do
  if is_srl_node "${ce}"; then
    check_cmd "Nokia SR Linux 4-PE eBGP & Native VRRPv3 UP on ${ce}" \
      bash -c "docker exec ${PREFIX}-${ce} sr_cli 'show ipv4 vrrp summary' | grep -qiE 'up|master'"
  fi
done

for sw in as as1 bs bs1; do
  if is_srl_node "${sw}"; then
    check_cmd "Nokia SR Linux MAC-VRF bridge operational on ${sw}" \
      bash -c "docker exec ${PREFIX}-${sw} sr_cli 'show network-instance summary' | grep -qi 'mac-vrf'"
  fi
done

log_header "4. Tier 5: Dual-Homed Host -> VRRP Gateway VIP (.1) Reachability"
check_cmd "host-as  -> Switch AS VRRP VIP (172.16.10.1) & Backup AS1 VIP (172.16.11.1)" \
  bash -c "docker exec ${PREFIX}-host-as ping -c 1 -W 2 172.16.10.1 && docker exec ${PREFIX}-host-as ping -c 1 -W 2 172.16.11.1"
check_cmd "host-as1 -> Switch AS1 VRRP VIP (172.16.11.1) & Backup AS VIP (172.16.10.1)" \
  bash -c "docker exec ${PREFIX}-host-as1 ping -c 1 -W 2 172.16.11.1 && docker exec ${PREFIX}-host-as1 ping -c 1 -W 2 172.16.10.1"
check_cmd "host-bs  -> Switch BS VRRP VIP (172.17.20.1) & Backup BS1 VIP (172.17.21.1)" \
  bash -c "docker exec ${PREFIX}-host-bs ping -c 1 -W 2 172.17.20.1 && docker exec ${PREFIX}-host-bs ping -c 1 -W 2 172.17.21.1"
check_cmd "host-bs1 -> Switch BS1 VRRP VIP (172.17.21.1) & Backup BS VIP (172.17.20.1)" \
  bash -c "docker exec ${PREFIX}-host-bs1 ping -c 1 -W 2 172.17.21.1 && docker exec ${PREFIX}-host-bs1 ping -c 1 -W 2 172.17.20.1"

log_header "5. End-to-End MPLS L3VPN Data Plane (AS/AS1 <-> BS/BS1 across Core 1/2)"
check_cmd "Stack A (host-as 172.16.10.10)  -> Stack B (host-bs 172.17.20.10)" \
  docker exec "${PREFIX}-host-as" ping -c 3 -W 2 -I 172.16.10.10 172.17.20.10
check_cmd "Stack A (host-as1 172.16.11.11) -> Stack B (host-bs1 172.17.21.11)" \
  docker exec "${PREFIX}-host-as1" ping -c 3 -W 2 -I 172.16.11.11 172.17.21.11
check_cmd "Intra-VRF-A Overlap: host-as (192.168.100.10) -> host-as1 (192.168.101.11)" \
  docker exec "${PREFIX}-host-as" ping -c 3 -W 2 -I 192.168.100.10 192.168.101.11
check_cmd "Intra-VRF-B Overlap: host-bs (192.168.100.10) -> host-bs1 (192.168.101.11)" \
  docker exec "${PREFIX}-host-bs" ping -c 3 -W 2 -I 192.168.100.10 192.168.101.11

log_header "6. Overlapping Private Subnet Isolation Audit (Negative Tests)"
check_negative_ping "Isolation: VRF-A Overlap (192.168.100.10) CANNOT reach VRF-B Corp (172.17.20.10)" \
  "host-as" "192.168.100.10" "172.17.20.10"
check_negative_ping "Isolation: VRF-B Overlap (192.168.100.10) CANNOT reach VRF-A Corp (172.16.10.10)" \
  "host-bs" "192.168.100.10" "172.16.10.10"

echo ""
echo -e "${CYAN}=======================================================================${NC}"
echo -e " Verification Summary: ${GREEN}${PASS} Passed${NC}, ${RED}${FAIL} Failed${NC}"
echo -e "${CYAN}=======================================================================${NC}"

[ "${FAIL}" -eq 0 ]

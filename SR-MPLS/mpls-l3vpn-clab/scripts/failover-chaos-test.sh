#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Automated Multi-Tier Redundancy & Failover Chaos Test Suite
# Matches User Diagram: core1..2, pe-a/a1/b/b1, ce-a/a1/b/b1, as/as1/bs/bs1
# =============================================================================

PREFIX="clab-mpls-l3vpn-extranet"
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

log_step() {
  echo ""
  echo -e "${CYAN}-----------------------------------------------------------------------${NC}"
  echo -e "${CYAN} [FAILOVER TEST] $1${NC}"
  echo -e "${CYAN}-----------------------------------------------------------------------${NC}"
}

is_srl_node() {
  local node="$1"
  docker exec "${PREFIX}-${node}" which sr_cli >/dev/null 2>&1
}

set_node_port() {
  local node="$1"
  local srl_if="$2"
  local linux_if="$3"
  local state="$4" # enable/disable
  if is_srl_node "${node}"; then
    docker exec "${PREFIX}-${node}" sr_cli -e "enter candidate" "set / interface ${srl_if} admin-state ${state}" "commit now" >/dev/null
  else
    local ip_state="up"
    [ "${state}" = "disable" ] && ip_state="down"
    docker exec "${PREFIX}-${node}" ip link set dev "${linux_if}" "${ip_state}"
  fi
}

verify_data_plane() {
  local label="$1"
  if docker exec "${PREFIX}-host-as" ping -c 2 -W 2 172.17.20.10 >/dev/null 2>&1 && \
     docker exec "${PREFIX}-host-as1" ping -c 2 -W 2 172.17.21.11 >/dev/null 2>&1; then
    echo -e "  [${GREEN}PASS${NC}] ${label} (End-to-End AS/AS1 <-> BS/BS1 Traffic UP)"
    PASS=$((PASS + 1))
  else
    echo -e "  [${RED}FAIL${NC}] ${label} (Data-plane loss detected!)"
    FAIL=$((FAIL + 1))
  fi
}

log_step "1. Tier 1 Core Router Failure (Isolating core1 completely)"
for idx in 1 2 3 4 5; do
  set_node_port "core1" "ethernet-1/${idx}" "eth${idx}" "disable"
done
sleep 3
verify_data_plane "Traffic converges onto redundant Core Router core2 (SID 16012)"
for idx in 1 2 3 4 5; do
  set_node_port "core1" "ethernet-1/${idx}" "eth${idx}" "enable"
done
sleep 3

log_step "2. Tier 2 Single PE Failure (Isolating Primary pe-a)"
for idx in 1 2 3 4 5 6; do
  set_node_port "pe-a" "ethernet-1/${idx}" "eth${idx}" "disable"
done
sleep 3
verify_data_plane "Stack A traffic fails over to redundant PE pe-a1 (SID 16002)"

log_step "3. Tier 2 Dual PE Failure (Isolating BOTH pe-a AND pe-a1 simultaneously!)"
for idx in 1 2 3 4 5 6; do
  set_node_port "pe-a1" "ethernet-1/${idx}" "eth${idx}" "disable"
done
sleep 3
verify_data_plane "4x4 PE-CE Cross-Mesh activates: ce-a & ce-a1 route via pe-b & pe-b1!"
for pe in pe-a pe-a1; do
  for idx in 1 2 3 4 5 6; do
    set_node_port "${pe}" "ethernet-1/${idx}" "eth${idx}" "enable"
  done
done
sleep 4

log_step "4. Tier 3 Customer Edge Failure (Isolating Primary ce-a)"
for idx in 1 2 3 4 5 6; do
  set_node_port "ce-a" "ethernet-1/${idx}" "eth${idx}" "disable"
done
sleep 2
verify_data_plane "2x2 Bowtie + Native VRRPv3 fails over to ce-a1 across both AS and AS1!"
for idx in 1 2 3 4 5 6; do
  set_node_port "ce-a" "ethernet-1/${idx}" "eth${idx}" "enable"
done
sleep 3

log_step "5. Tier 4 Access Switch Failure (Shutting down Primary Switch AS Link to host-as)"
docker exec "${PREFIX}-host-as" ip link set dev eth1 down
sleep 1
verify_data_plane "host-as fails over to Secondary Uplink eth2 via Switch AS1!"
docker exec "${PREFIX}-host-as" ip link set dev eth1 up
sleep 1

echo ""
echo -e "${CYAN}=======================================================================${NC}"
echo -e " Chaos Failover Summary: ${GREEN}${PASS} Passed${NC}, ${RED}${FAIL} Failed${NC}"
echo -e "${CYAN}=======================================================================${NC}"
[ "${FAIL}" -eq 0 ]

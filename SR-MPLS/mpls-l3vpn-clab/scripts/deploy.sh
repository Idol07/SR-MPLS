#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "${SCRIPT_DIR}")"
TOPO_FILE="${1:-${LAB_DIR}/topology.clab.yml}"

echo "======================================================================="
echo " [1/4] Running Host Pre-Flight Checks (Kernel Modules & Docker)"
echo "======================================================================="
bash "${SCRIPT_DIR}/host-preflight.sh"

echo ""
echo "======================================================================="
echo " [2/4] Deploying 28-Node Redundant MPLS L3VPN Topology (${TOPO_FILE##*/})"
echo "======================================================================="
sudo containerlab deploy -t "${TOPO_FILE}" --reconfigure

echo ""
echo "======================================================================="
echo " [3/4] Waiting for Nokia SR Linux / FRR Control Plane Convergence (25s)"
echo "======================================================================="
sleep 25

echo ""
echo "======================================================================="
echo " [4/4] Running End-to-End Verification Suite"
echo "======================================================================="
bash "${SCRIPT_DIR}/verify-all.sh"

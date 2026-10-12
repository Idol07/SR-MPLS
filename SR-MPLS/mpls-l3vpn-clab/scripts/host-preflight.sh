#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}=== [1/3] Checking Host Kernel Modules for MPLS, VRF, 802.1Q & Bonding ===${RESET}"
for mod in mpls_router mpls_gso mpls_iptunnel vrf 8021q bridge bonding; do
  if sudo modprobe "$mod" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${RESET} Kernel module loaded: ${BOLD}${mod}${RESET}"
  else
    echo -e "  ${YELLOW}[WARN]${RESET} Could not modprobe ${mod} (may be built-in or require linux-modules-extra-$(uname -r))"
  fi
done

echo -e "\n${BOLD}=== [2/3] Checking Docker Engine ===${RESET}"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]${RESET} Docker is installed and running ($(docker --version))"
else
  echo -e "  ${RED}[ERROR]${RESET} Docker is not running or current user lacks permissions."
  exit 1
fi

echo -e "\n${BOLD}=== [3/3] Checking Containerlab CLI ===${RESET}"
if command -v containerlab >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]${RESET} Containerlab installed ($(containerlab version | awk '/version:/ {print $2}' || echo 'detected'))"
elif command -v clab >/dev/null 2>&1; then
  echo -e "  ${GREEN}[OK]${RESET} Containerlab (clab) installed"
else
  echo -e "  ${RED}[ERROR]${RESET} Containerlab not found. Install via: bash -c \"\$(curl -sL https://get.containerlab.dev)\""
  exit 1
fi

echo -e "\n${GREEN}${BOLD}Host preflight checks passed! Ready to deploy 28-node Fully Redundant MPLS L3VPN topology.${RESET}"

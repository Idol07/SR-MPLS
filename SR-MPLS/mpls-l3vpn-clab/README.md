# Redundant MPLS L3VPN Topology (`core1..2`, `pe-a/a1/b/b1`, `ce-a/a1/b/b1`, `as/as1/bs/bs1`)

A complete **5-tier redundant MPLS L3VPN** laboratory in Containerlab built directly from your architectural template and powered by **100% Nokia SR Linux (`ghcr.io/nokia/srlinux:24.10.1`)** across all 14 routers and switches alongside 4 dual-homed Linux test hosts (18 nodes, 45 links total).

---

## 1. Visual Architecture (Exact Match to Template)

```text
                       [core1] ------------------- [core2]                 <-- Tier 1: Core (1 and 2)
                      /  |  \  \                 /  /  |  \                    2x4 Full Mesh (IS-IS SR-MPLS + BFD)
                     /   |   \  \_______________/  /   |   \
                    /    |    \___________________/    |    \
                   /     |     /                 \     |     \
              [pe-a]  [pe-a1]               [pe-b]  [pe-b1]                <-- Tier 2: Provider Edge (A, A1, B, B1)
               |\\\    /|\\                   //|\    ///|                     4x4 Full Bipartite Mesh (16 Links)
               | \\\  / | \\                 // | \  /// |                     VRF-A (Stack A) & VRF-B (Stack B)
               |  \\\/  |  \\_______________//  |  \///  |
               |  /\\\  |  /                 \  |  ///\  |
              [ce-a]  [ce-a1]               [ce-b]  [ce-b1]                <-- Tier 3: Customer Edge (A, A1, B, B1)
               |  \    /  |                   |  \    /  |                     Dual 2x2 Bowtie Meshes (802.1Q + VRRPv3)
               |   \  /   |                   |   \  /   |
               |    \/    |                   |    \/    |
               |    /\    |                   |    /\    |
              [as]      [as1]               [bs]      [bs1]                <-- Tier 4: Access Switches (AS, AS1, BS, BS1)
               | \      / |                   | \      / |                     Nokia SR Linux MAC-VRF L2 Bridges
            [host-as] [host-as1]           [host-bs] [host-bs1]            <-- Tier 5: Dual-Homed Test Hosts
```

---

## 2. Node & Addressing Inventory (14 Nokia SR Linux + 4 Dual-Homed Hosts)

### Tier 1: Core (`core1`, `core2` — Nokia 7250 `ixr-6e`)
| Node | Loopback (`system0.0`) | SR-MPLS Node-SID | Inter-Core Link (`e1-1`) | Links to PEs (`e1-2..e1-5`) |
| :--- | :--- | :--- | :--- | :--- |
| **`core1`** | `10.0.0.11/32` | **16011** (Index 11) | `10.0.12.1/30` (`-> core2`) | `pe-a` (`10.0.1.2/30`), `pe-a1` (`10.0.2.2/30`), `pe-b` (`10.0.3.2/30`), `pe-b1` (`10.0.4.2/30`) |
| **`core2`** | `10.0.0.12/32` | **16012** (Index 12) | `10.0.12.2/30` (`-> core1`) | `pe-a` (`10.0.5.2/30`), `pe-a1` (`10.0.6.2/30`), `pe-b` (`10.0.7.2/30`), `pe-b1` (`10.0.8.2/30`) |

### Tier 2: Provider Edge (`pe-a`, `pe-a1`, `pe-b`, `pe-b1` — Nokia 7250 `ixr-6e`)
Each PE connects to **both Core routers (`e1-1, e1-2`)** AND to **all 4 CEs (`e1-3..e1-6`)** in a full 4×4 mesh:
| Node | Loopback | SR Node-SID | `vrf-a` RD (`e1-3 -> ce-a`, `e1-4 -> ce-a1`) | `vrf-b` RD (`e1-5 -> ce-b`, `e1-6 -> ce-b1`) | Role & BGP Preference |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`pe-a`** | `10.0.0.1/32` | **16001** | `10.0.0.1:101` (`10.101.1.1`, `10.101.2.1`) | `10.0.0.1:102` (`10.102.1.1`, `10.102.2.1`) | **Stack A Primary** (LP 200) / Stack B Backup (LP 100) |
| **`pe-a1`** | `10.0.0.2/32` | **16002** | `10.0.0.2:101` (`10.101.3.1`, `10.101.4.1`) | `10.0.0.2:102` (`10.102.3.1`, `10.102.4.1`) | **Stack A Primary** (LP 200) / Stack B Backup (LP 100) |
| **`pe-b`** | `10.0.0.3/32` | **16003** | `10.0.0.3:101` (`10.101.5.1`, `10.101.6.1`) | `10.0.0.3:102` (`10.102.5.1`, `10.102.6.1`) | **Stack B Primary** (LP 200) / Stack A Backup (LP 100) |
| **`pe-b1`** | `10.0.0.4/32` | **16004** | `10.0.0.4:101` (`10.101.7.1`, `10.101.8.1`) | `10.0.0.4:102` (`10.102.7.1`, `10.102.8.1`) | **Stack B Primary** (LP 200) / Stack A Backup (LP 100) |

### Tier 3: Customer Edge (`ce-a`, `ce-a1`, `ce-b`, `ce-b1` — Nokia 7220 `ixr-d2l` License-Free)
Each CE has **4 WAN links (`e1-1..e1-4`)** to `pe-a, pe-a1, pe-b, pe-b1` and **2 LAN 802.1Q Bowtie Trunks (`e1-5, e1-6`)** to its pair of Access Switches with **Native SR Linux VRRPv3**:
| Node | ASN | Loopback | Bowtie Trunk 1 (`e1-5`) | Bowtie Trunk 2 (`e1-6`) |
| :--- | :--- | :--- | :--- | :--- |
| **`ce-a`** | `65101` | `172.16.255.1/32` | `-> as:e1-1`: VLAN 10 (`172.16.10.2`, **VRRP Master VIP `.1`**), VLAN 100 (`192.168.100.2`, **Master VIP `.1`**) | `-> as1:e1-1`: VLAN 11 (`172.16.11.3`, **VRRP Backup VIP `.1`**), VLAN 101 (`192.168.101.3`, **Backup VIP `.1`**) |
| **`ce-a1`** | `65101` | `172.16.255.2/32` | `-> as:e1-2`: VLAN 10 (`172.16.10.3`, **VRRP Backup VIP `.1`**), VLAN 100 (`192.168.100.3`, **Backup VIP `.1`**) | `-> as1:e1-2`: VLAN 11 (`172.16.11.2`, **VRRP Master VIP `.1`**), VLAN 101 (`192.168.101.2`, **Master VIP `.1`**) |
| **`ce-b`** | `65102` | `172.17.255.1/32` | `-> bs:e1-1`: VLAN 20 (`172.17.20.2`, **VRRP Master VIP `.1`**), VLAN 100 (`192.168.100.2`, **Master VIP `.1`**) | `-> bs1:e1-1`: VLAN 21 (`172.17.21.3`, **VRRP Backup VIP `.1`**), VLAN 101 (`192.168.101.3`, **Backup VIP `.1`**) |
| **`ce-b1`** | `65102` | `172.17.255.2/32` | `-> bs:e1-2`: VLAN 20 (`172.17.20.3`, **VRRP Backup VIP `.1`**), VLAN 100 (`192.168.100.3`, **Backup VIP `.1`**) | `-> bs1:e1-2`: VLAN 21 (`172.17.21.2`, **VRRP Master VIP `.1`**), VLAN 101 (`192.168.101.2`, **Master VIP `.1`**) |

### Tier 4: Access Switches (`as`, `as1`, `bs`, `bs1` — Nokia 7220 `ixr-d2l` License-Free)
- **`as`**: Bridges `e1-1` (`ce-a`), `e1-2` (`ce-a1`), `e1-3` (`host-as:eth1`), `e1-4` (`host-as1:eth2`) in `mac-vrf vlan-10`, and `e1-5` (`host-as:eth3`) in `mac-vrf vlan-100`.
- **`as1`**: Bridges `e1-1` (`ce-a`), `e1-2` (`ce-a1`), `e1-3` (`host-as1:eth1`), `e1-4` (`host-as:eth2`) in `mac-vrf vlan-11`, and `e1-5` (`host-as1:eth3`) in `mac-vrf vlan-101`.
- **`bs`**: Bridges `e1-1` (`ce-b`), `e1-2` (`ce-b1`), `e1-3` (`host-bs:eth1`), `e1-4` (`host-bs1:eth2`) in `mac-vrf vlan-20`, and `e1-5` (`host-bs:eth3`) in `mac-vrf vlan-100`.
- **`bs1`**: Bridges `e1-1` (`ce-b`), `e1-2` (`ce-b1`), `e1-3` (`host-bs1:eth1`), `e1-4` (`host-bs:eth2`) in `mac-vrf vlan-21`, and `e1-5` (`host-bs1:eth3`) in `mac-vrf vlan-101`.

### Tier 5: Dual-Homed Test Hosts (`host-as`, `host-as1`, `host-bs`, `host-bs1`)
- **`host-as`**: Primary `eth1` (`172.16.10.10/24 -> VIP 172.16.10.1` via `as`), Backup `eth2` (`172.16.11.10/24 -> VIP 172.16.11.1` via `as1`), Overlap `eth3` (`192.168.100.10/24`).
- **`host-as1`**: Primary `eth1` (`172.16.11.11/24 -> VIP 172.16.11.1` via `as1`), Backup `eth2` (`172.16.10.11/24 -> VIP 172.16.10.1` via `as`), Overlap `eth3` (`192.168.101.11/24`).
- **`host-bs`**: Primary `eth1` (`172.17.20.10/24 -> VIP 172.17.20.1` via `bs`), Backup `eth2` (`172.17.21.10/24 -> VIP 172.17.21.1` via `bs1`), Overlap `eth3` (`192.168.100.10/24`).
- **`host-bs1`**: Primary `eth1` (`172.17.21.11/24 -> VIP 172.17.21.1` via `bs1`), Backup `eth2` (`172.17.20.11/24 -> VIP 172.17.20.1` via `bs`), Overlap `eth3` (`192.168.101.11/24`).

---

## 3. Quick Start & Commands

```bash
# Deploy 100% Nokia SR Linux Topology (Default)
make deploy

# Or Deploy 100% License-Free Hybrid (SR Linux CEs/Switches + FRR Core/PEs)
make deploy-hybrid

# Run Automated Verification Suite
make verify

# Run Automated 5-Tier Chaos Failover Test (including simultaneous Dual-PE failure!)
make failover

# Destroy Lab
make destroy
```

# Architecture & Design

This document explains the infrastructure design, networking, security, and how components work together.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Network Design](#network-design)
- [Security Layers](#security-layers)
- [Compute & Storage](#compute--storage)
- [Data Flow](#data-flow)
- [Scaling Considerations](#scaling-considerations)

---

## High-Level Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                   Internet (Players)                           │
│                                                                │
│  Player 1     Player 2     Player 3     Player 4               │
│     │            │            │            │                   │
└─────┼────────────┼────────────┼────────────┼────────────────────┘
      │            │            │            │
      │   Minecraft Protocol (25565/TCP+UDP)  │
      │                                       │
┌─────┴───────────────────────────────────────┴──────────────────┐
│                    OCI Public Internet                          │
└─────┬───────────────────────────────────────┬──────────────────┘
      │                                       │
      │      Internet Gateway                 │
      │      (Route: 0.0.0.0/0)               │
      │                                       │
┌─────┴─────────────────────────────────────────────────────────┐
│                   VCN (10.1.0.0/16)                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Subnet (10.1.20.0/24)                             │   │
│  │                                                    │   │
│  │  ┌──────────────────────────────────────────────┐ │   │
│  │  │  Ubuntu 24.04 LTS Instance (A1 Compute)    │ │   │
│  │  │  - 1 OCPU, 6 GB RAM                        │ │   │
│  │  │  - IP: 10.1.20.x (private)                 │ │   │
│  │  │  - 150.123.45.x (public, elastic)          │ │   │
│  │  │                                            │ │   │
│  │  │  ┌─ UFW Firewall ──────────────────────┐  │ │   │
│  │  │  │ Deny all incoming                   │  │ │   │
│  │  │  │ Allow: 22/tcp (SSH)                 │  │ │   │
│  │  │  │ Allow: 25565/tcp+udp (Minecraft)   │  │ │   │
│  │  │  │ Allow: 80/tcp, 443/tcp (future)    │  │ │   │
│  │  │  └─────────────────────────────────────┘  │ │   │
│  │  │                                            │ │   │
│  │  │  ┌─ Minecraft Server ──────────────────┐  │ │   │
│  │  │  │ Java 25 (Eclipse Temurin)          │  │ │   │
│  │  │  │ server.jar (Latest)                │  │ │   │
│  │  │  │ Systemd Service                    │  │ │   │
│  │  │  └─────────────────────────────────────┘  │ │   │
│  │  │                                            │ │   │
│  │  │  Mount Point: /mnt/persistent-data ◄──┐   │ │   │
│  │  └──────────────────────────────────────┼──┘ │   │
│  │                                         │    │   │
│  │  ┌─────────────────────────────────────┼──┐ │   │
│  │  │  Block Storage Volume (50GB)       │  │ │   │
│  │  │  - EXT4 Filesystem                 │  │ │   │
│  │  │  - World Data & server.jar        ◄──┘  │   │
│  │  └──────────────────────────────────────┘ │   │
│  │                                            │   │
│  └──────────────────────────────────────────────┘   │
│                                                    │
│  ┌──────────────────────────────────────────────┐ │
│  │  Security List (Network Firewall)           │ │
│  │  - Ingress: 22/tcp, 25565/tcp+udp from 0/0 │ │
│  │  - Egress: All allowed                      │ │
│  └──────────────────────────────────────────────┘ │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

## Network Design

### VCN (Virtual Cloud Network)

**CIDR Block**: `10.1.0.0/16` (65,536 addresses)

Divides the private network into manageable ranges:
- Supports up to 64 subnets if needed
- Isolates different tiers (web, app, database)
- Currently uses only one subnet

### Subnet

**CIDR Block**: `10.1.20.0/24` (256 addresses)

- **Network Address**: 10.1.20.0
- **Usable Range**: 10.1.20.1 - 10.1.20.254
- **Broadcast**: 10.1.20.255

Currently only uses 1 instance + 1 IP for OCI services.

### Internet Gateway (IGW)

Enables:
- ✅ Public internet access for instance
- ✅ Port 25565 accessible from players worldwide
- ❌ Inbound to instance only via Security List rules

### Route Table

Single route table for the subnet:

| Destination | Target | Purpose |
|------------|--------|---------|
| 10.1.0.0/16 | Local | Instance to instance (within VCN) |
| 0.0.0.0/0 | IGW | Internet traffic (outbound + inbound) |

---

## Security Layers

### Layer 1: OCI Security List (Network-Level)

Stateless firewall at VCN level.

**Ingress Rules** (incoming traffic):

| Protocol | Port(s) | Source | Purpose |
|----------|---------|--------|---------|
| TCP | 22 | 0.0.0.0/0 | SSH access (can restrict to your IP) |
| TCP | 25565 | 0.0.0.0/0 | Minecraft Java Edition |
| UDP | 25565 | 0.0.0.0/0 | Minecraft Query protocol |

**Egress Rules** (outgoing traffic):

| Protocol | Port(s) | Destination | Purpose |
|----------|---------|-------------|---------|
| All | All | 0.0.0.0/0 | All outbound allowed |

### Layer 2: UFW (Host-Level Firewall)

Stateful firewall on the Ubuntu instance itself.

**Rules**:

| Rule | Action | Purpose |
|------|--------|---------|
| default policy: deny incoming | DROP | Deny all unless explicitly allowed |
| default policy: allow outgoing | ACCEPT | Allow all outbound |
| 22/tcp | ALLOW | SSH |
| 25565/tcp | ALLOW | Minecraft (TCP) |
| 25565/udp | ALLOW | Minecraft (UDP) |
| 80/tcp | ALLOW | HTTP (future use) |
| 443/tcp | ALLOW | HTTPS (future use) |

### Defense in Depth

Why two firewalls?

1. **OCI Security List**: Network-level protection
   - Protects if instance is misconfigured
   - Applies to all traffic entering VCN
   - Region-wide consistency

2. **UFW**: Host-level protection
   - Protects against insider threats
   - Fine-grained per-process control
   - Quick iteration (no terraform needed)

**Best Practice**: Keep both synchronized. If OCI blocks a port, UFW doesn't need to. If OCI allows it, UFW controls final access.

---

## Compute & Storage

### Compute Instance

**Type**: A1 Compute (ARM64-based)

**Specifications**:
- **OCPUs**: 1 (1 core)
- **RAM**: 6 GB
- **Architecture**: ARM64 (aarch64)
- **OS**: Canonical Ubuntu 24.04 LTS
- **Billing**: Always-free tier ($0/month)

**Why A1 Compute?**
- ✅ Only ARM-based option in always-free tier
- ✅ Sufficient for 1-4 player servers
- ✅ Adequate for vanilla Minecraft
- ❌ Limited for large worlds or many mods (would need upgrade)

### Boot Volume

**Size**: 50 GB
**Type**: SSD (high-performance)
**Mount Point**: `/`
**Used By**: Operating system, packages, Java runtime

**Typical Space Usage**:
- Ubuntu OS + packages: ~10 GB
- Java 25 + Minecraft jar: ~2 GB
- Logs + system overhead: ~5 GB
- **Available**: ~33 GB free

### Data Volume (Persistent)

**Size**: 50 GB
**Type**: SSD (high-performance)
**Mount Point**: `/mnt/persistent-data/minecraft`
**Mount Options**: `defaults,nofail` (auto-mount on startup)
**Filesystem**: EXT4

**Lifecycle**: `prevent_destroy = true`
- Survives when instance is destroyed
- Survives when instance is recreated
- Only destroyed if explicitly removed from Terraform

**Contents**:
- `/mnt/persistent-data/minecraft/server/world` (~5-20 GB typical)
- `/mnt/persistent-data/minecraft/server/server.jar` (~0.5 GB)
- `/mnt/persistent-data/minecraft/server/server.properties`
- `/mnt/persistent-data/minecraft/server/eula.txt`
- `/mnt/persistent-data/minecraft/server/logs/` (server logs)

---

## Data Flow

### Player Connection

```
Player Input (Mouse/Keyboard)
    │
    ├─→ Minecraft Java Client
    │   ├─ Compresses: GZip
    │   ├─ Encrypts: AES-128 (after handshake)
    │   └─ Protocol: 25565/TCP+UDP
    │
    ├─→ Internet (Public)
    │   └─ Routed via ISP to OCI Phoenix region
    │
    ├─→ OCI Security List
    │   └─ Checks: 25565/TCP allowed? YES → Forward
    │
    ├─→ VCN Network
    │   ├─ Destination: 10.1.20.x (instance private IP)
    │   └─ Routes via IGW (if from public internet)
    │
    ├─→ UFW Firewall
    │   └─ Checks: 25565/TCP allowed? YES → Forward
    │
    └─→ Minecraft Server (Java Process)
        ├─ Decrypts packet
        ├─ Processes command (move, block break, etc.)
        ├─ Reads from: /mnt/persistent-data/minecraft/server/world
        ├─ Writes updates to world
        ├─ Generates response packet
        └─ Sends back: Response + World data (25565/TCP+UDP)

Response Flow (same path, reversed)
    World Data → Server → UFW → VCN → Security List → Internet → Player Client
```

### Data Persistence

```
Minecraft Server (Java Process)
    │ (every 1-2 minutes)
    ├─→ Writes to: /mnt/persistent-data/minecraft/server/world/
    │
    ├─→ Block Storage Volume
    │   ├─ EXT4 Filesystem
    │   ├─ Written to disk
    │   └─ Backed by OCI Block Storage
    │
    └─→ Persistent (survives restarts)

When Instance Destroyed & Recreated:
    Old Instance X
    └─ Detach: /dev/sdb (50GB volume)
       └─ Volume data preserved in OCI storage
          └─ New Instance Y
             ├─ Attach: /dev/sdb (same volume)
             ├─ Mount: /mnt/persistent-data
             └─ World data immediately available!
```

---

## Scaling Considerations

### Current Limits (1 OCPU A1)

| Metric | Limit | Notes |
|--------|-------|-------|
| **Players** | 1-4 | Comfortable; 5+ starts lagging |
| **World Size** | ~500 MB comfortable | Can grow to several GB |
| **Plugins** | 0-5 small plugins | Heavy modding requires upgrade |
| **TPS (Ticks/sec)** | 10-18 | Target: 20 TPS (optimal) |
| **Memory** | 4-6 GB Minecraft | Rest for OS |

### Upgrade Paths

#### Option 1: Stick with Always-Free (Recommended for beginners)

- Keep 1 OCPU A1 ($0/month)
- Limit players to 1-4
- Use vanilla Minecraft or light mods
- **Cost**: $0/month

#### Option 2: Upgrade to Standard Instance

```hcl
instance_shape = "VM.Standard.E2.2"  # 2 OCPU, 16GB RAM
instance_ocpus = 2
instance_shape_config_memory_in_gbs = 16
```

- **Cost**: ~$72/month
- Supports 10-20 players comfortably
- Handles modded servers well
- Plus storage costs

#### Option 3: Add Load Balancer + Multiple Instances

```
                    ┌─── Instance 1 (2 OCPU)
Load Balancer ──────┼─── Instance 2 (2 OCPU)
                    └─── Instance 3 (2 OCPU)
```

- Distributes players across instances
- Each world runs independently
- **Cost**: Significant ($200+/month)
- Requires architectural changes (not included in this template)

---

## Failure Scenarios & Recovery

### Scenario 1: Instance Crashes

**What Happens**:
1. Minecraft service stops
2. Data volume remains mounted
3. Instance auto-recovers (systemd)

**Recovery**: Automatic (within 1 minute)

### Scenario 2: Disk Full

**What Happens**:
1. World generation fails
2. Server logs errors
3. Players disconnect

**Recovery**:
```bash
# SSH to instance
ssh ubuntu@<ip>

# Check disk usage
df -h /mnt/persistent-data

# Delete old backups or worlds
rm -rf /mnt/persistent-data/minecraft/server/world_old/

# Or expand volume size (OCI Console)
```

### Scenario 3: Intentional Rebuild

**What Happens**:
```bash
# Run terraform
terraform taint oci_core_instance.server_instance
terraform apply

# Old instance destroyed
# Volume detached (data safe due to prevent_destroy)
# New instance created
# Volume reattached
# All Minecraft data restored!
```

**Recovery Time**: 3-5 minutes

**Data Loss**: None (volume is preserved)

### Scenario 4: Complete Teardown

**What Happens**:
```bash
terraform destroy  # Deletes everything except volume!
```

**Data Recovery**:
- Volume remains in OCI (still has your world data)
- Re-run `terraform apply` to recreate instance
- Volume reattaches automatically
- World data back online!

---

## Performance Optimization

### Minecraft Server Tuning

1. **View Distance**: Lower = better performance
   ```properties
   view-distance=10  # Default 10, can reduce to 6-8
   ```

2. **Entity Limits**:
   ```properties
   max-entity-cramming=24
   spawn-animals=true  # Set to false if lagging
   ```

3. **Tick Speed**:
   ```bash
   # On instance, in server.properties
   max-tick-time=120000  # Allow longer ticks
   ```

### Java Tuning

In systemd service:
```bash
ExecStart=/usr/bin/java \
  -Djava.net.preferIPv4Stack=true \
  -XX:+UseG1GC \              # Better garbage collection
  -XX:MaxGCPauseMillis=200 \  # Reduce lag spikes
  -Xms4G -Xmx6G \            # Heap size
  -jar server.jar nogui
```

### Network Optimization

- Use `gamemode 0` (survival) - less server-side computation than creative
- Disable `online-mode=false` if lag spikes occur (use plugins for security)
- Limit player count if seeing TPS < 18

---

## Disaster Recovery Plan

| Failure | Impact | Recovery Time | Data Loss |
|---------|--------|---------------|-----------|
| Service crash | Players kicked | <2 min | None |
| Instance dies | Full downtime | 3-5 min (rebuild) | None |
| Volume deleted | Total loss | Restore from backup | All |
| Network outage | Unreachable | ISP dependent | None |

**Backup Strategy**:
```bash
# Monthly backup (manual)
ssh ubuntu@<ip>
tar czf world-$(date +%Y%m%d).tar.gz /mnt/persistent-data/minecraft/server/world/
scp ubuntu@<ip>:world-*.tar.gz ~/minecraft-backups/
```

---

## Cost Optimization

For this 1 OCPU setup:
- **Compute**: $0 (always-free)
- **Storage**: $0 (within 200GB allowance)
- **Data Transfer**: $0 if <10GB/month
- **Total**: **$0/month** ✓

To reduce further:
- Can't (already using always-free tier)

To expand affordably:
- Upgrade to 2-4 OCPU A1 (~$40-80/month)
- Or stay at 1 OCPU and manage players/world size

---

## Conclusion

This architecture provides:
- ✅ Cost-effective ($0/month initially)
- ✅ Secure (dual firewall layers)
- ✅ Persistent (volume survives rebuilds)
- ✅ Scalable (can upgrade easily)
- ✅ Maintainable (Infrastructure as Code)

Perfect for small Minecraft communities and learning Terraform!

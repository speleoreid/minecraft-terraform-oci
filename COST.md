# Cost Analysis & Always-Free Tier

This Minecraft server deployment uses Oracle Cloud's **always-free tier**, which means **$0/month** for the core resources. However, there are scenarios where you might incur charges.

## Always-Free Tier Breakdown

### What's Included (Free)

| Resource | Allocation | Used in This Project |
|----------|-----------|---------------------|
| **Compute** | 4 OCPUs total (various shapes) | 1 OCPU (A1 Compute) ✓ |
| **RAM** | Up to 24 GB across instances | 6 GB ✓ |
| **Block Storage** | 200 GB per month | 100 GB (50GB boot + 50GB data) ✓ |
| **Data Transfer Out** | 10 GB per month | ~1-5 GB typical ✓ |
| **Load Balancer** | 1 instance | Not used |
| **IP Addresses** | 2 public IPs | 1 used ✓ |

### Cost Breakdown

```
Compute Instance:     FREE (within A1 allowance)
Boot Volume (50GB):   FREE (within 200GB allowance)
Data Volume (50GB):   FREE (within 200GB allowance)
Public IP:            FREE (2 allowed)
Network Traffic:      FREE (10 GB/month egress)
─────────────────────────────────
Total:                $0/month
```

---

## When Charges Apply

### Scenario 1: Exceeding Data Transfer (Most Likely)

**Condition**: If your server data transfer exceeds 10 GB/month

**Typical Usage**:
- Player downloads world on first join: ~2-5 MB
- Regular gameplay updates: ~0.1 MB/minute of active players
- 4 players, 1 hour/day: ~24 MB/day = ~720 MB/month ✓ (under limit)

**Estimate**:
- Small server (1-2 players): **$0/month** (under 10GB)
- Medium server (4-6 players): **$0-5/month** (depends on mods)
- Large server (10+ players with mods): **$5-20/month+**

**Overage Cost**: $0.85 per GB after 10 GB

---

### Scenario 2: Using Larger Instance Type

**Condition**: If you upgrade to a non-free-tier shape

Common upgrades:
- **VM.Standard.E2.1.Micro**: $0.05/hour = **~$36/month**
- **VM.Standard.A1.Flex (4 OCPU)**: $0.10/hour = **~$72/month**
- **VM.Standard.E2.2**: $0.10/hour = **~$72/month**

**Our Setup**: Uses 1 OCPU A1 Compute = **$0/month**

---

### Scenario 3: Exceeding Block Storage

**Condition**: If you use more than 200 GB block storage total

Default: 50GB boot + 50GB data = 100 GB ✓ (under limit)

If you increase data volume:
- 100GB data volume: 150 GB total ✓ Still free
- 150GB data volume: 200 GB total ✓ Still free
- 200GB data volume: 250 GB total ✗ 50GB over limit

**Overage Cost**: $0.25 per GB/month after 200 GB

**Estimate for Minecraft**:
- Vanilla world (~10 GB): Well within limit ✓
- World with mods (~50 GB): Still within limit ✓
- Multiple worlds (~100 GB): Still within limit ✓

---

## Detailed Monthly Cost Examples

### Example 1: Small Private Server (Best Case)

```
Setup: 1 OCPU A1, 6GB RAM, 1-2 players
Resources:
  - 1x A1 Compute (1 OCPU):     $0
  - 50GB Boot Volume:            $0
  - 50GB Data Volume:            $0
  - ~2 GB data transfer:         $0
─────────────────────────────────
Total:                           $0/month
```

---

### Example 2: Medium Server with Modest Traffic

```
Setup: 1 OCPU A1, 6GB RAM, 4-6 players
Resources:
  - 1x A1 Compute (1 OCPU):     $0
  - 50GB Boot Volume:            $0
  - 50GB Data Volume:            $0
  - ~5 GB data transfer:         $0 (within 10GB allowance)
─────────────────────────────────
Total:                           $0/month
```

---

### Example 3: Active Server with High Traffic

```
Setup: 1 OCPU A1, 6GB RAM, 10+ players with mods
Resources:
  - 1x A1 Compute (1 OCPU):     $0
  - 50GB Boot Volume:            $0
  - 50GB Data Volume:            $0
  - ~15 GB data transfer:        $4.25 (5GB over limit @ $0.85/GB)
─────────────────────────────────
Total:                           ~$4.25/month
```

---

## How to Stay Free

1. **Keep under 10 GB monthly data transfer**
   - Avoid large mod packs initially
   - Monitor with: `vnstat` or OCI Console Metrics

2. **Don't upgrade compute shape**
   - Keep `instance_shape = "VM.Standard.A1.Flex"`

3. **Keep storage under 200 GB**
   - Default setup is 100 GB total ✓
   - If expanding, check before reaching 200 GB

4. **Monitor spending**
   - OCI Console → Billing → Cost Analysis
   - Set up alerts (OCI Console → Budgets)

---

## Monitoring Your Usage

### Data Transfer (OCI Console)

```
OCI Console → Networking → Traffic Statistics
Or: Monitoring → Metrics → Core Services
```

Check for egress traffic (data leaving OCI).

### Compute Usage

```bash
# On instance, check network usage
vnstat  # If installed
# Or monitor via OCI Console → Instance → Metrics
```

### Storage Usage

```bash
# On instance
df -h /mnt/persistent-data/minecraft
du -sh /mnt/persistent-data/minecraft/server/world*

# Or OCI Console → Block Storage → Volumes
```

---

## If You Need More Power

To scale beyond free tier:

```hcl
# In terraform.tfvars, change:
instance_shape = "VM.Standard.E2.2"     # ~$72/month
instance_ocpus = 4
instance_shape_config_memory_in_gbs = 8
minecraft_data_volume_size_gb = 500     # Can grow to 500GB
```

Costs would be:
- Compute: $72/month
- Storage: ~$0.25 × (500-50) = ~$112.50/month
- Data transfer: ~$0.85 × (overage)
- **Total: ~$185-200/month**

But for most personal Minecraft servers, the free tier is sufficient!

---

## FAQ

**Q: Will I be surprised with a bill?**
A: No. Oracle requires opt-in for pay-as-you-go beyond free tier. Monitor your usage in the OCI Console.

**Q: Can I test something and delete it if it costs money?**
A: Yes. Run `terraform destroy` to remove all resources. The always-free compute instance is covered indefinitely.

**Q: What if my server gets popular?**
A: You'll hit data transfer limits first (~10GB/month). Either accept the $0.85/GB overage or upgrade to paid tier for better resources.

**Q: Is there a monthly surprise if someone uses my server a lot?**
A: Only if data transfer exceeds 10 GB/month. A 1-2 player server typically uses 1-5 GB/month. With 10+ active players and mods, you might see $5-10/month.

---

## Cost Controls

### Set Up Billing Alerts

1. OCI Console → Billing → Budgets
2. Create budget: Set threshold (e.g., $5/month)
3. Get email alerts if you approach limit

### Auto-Shutdown (Advanced)

Schedule instance shutdown to save resources:

```bash
# Add to instance cron (ssh to instance)
sudo crontab -e

# Add line to stop at 11 PM daily:
# 0 23 * * * /sbin/shutdown -h now
```

---

## Summary

✅ **Default Setup**: **$0/month** (always-free tier)
⚠️ **High traffic**: **$0-10/month** (data transfer overage)
❌ **Upgraded compute**: **$72+/month** (not needed for small servers)

This project is designed to run **indefinitely for free** on the always-free tier!

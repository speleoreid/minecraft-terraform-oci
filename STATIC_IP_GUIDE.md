# Static Public IP Setup for Minecraft Server

##  Current IP Configuration

| Component | IP Address | Type | Notes |
|-----------|-----------|------|-------|
| **Instance Public IP** | `129.146.160.184` | Ephemeral | Current - may be lost on rebuild |
| **Reserved Public IP** | `132.226.86.107` | Reserved | New - survives rebuilds (preferred) |
| **Instance Private IP** | `10.0.0.64` | VCN Internal | Within subnet 10.0.0.0/24 |

## What Terraform Is Now Managing

✅ **Created:** Reserved public IP resource (`132.226.86.107`)  
✅ **Configured:** Terraform will attach this IP to new instances on rebuild  
✅ **Persistent Data Volume:** 50GB volume (`minecraft_data`) that survives instance recreations  
✅ **Network Security:** Security lists, firewall rules, and VCN configuration  

## To Use the Reserved IP for Future Rebuilds

### Option 1: Update Now & Rebuild (Recommended)
1. Update your Minecraft server access lists to accept connections from `132.226.86.107`
2. Update external DNS/firewall rules to point to `132.226.86.107`
3. Run: `terraform destroy && terraform apply -auto-approve`
   - This will destroy the current instance and rebuild with the reserved IP
   - The persistent data volume will be reattached automatically
4. Minecraft data and configurations will persist to the new instance

### Option 2: Assign Reserved IP to Current Instance (Advanced)
If you want to keep the current instance and just swap the public IP:

```bash
# Using OCI CLI:
oci network public-ip update \
  --public-ip-id ocid1.publicip.oc1.phx.amaaaaaamzsa3tqa3vkk3rmdjeubzzqg456zxoplkjwjeci44xvtk3337upq \
  --private-ip-id <PRIVATE_IP_ID> \
  --region us-phoenix-1
```

To get the PRIVATE_IP_ID for your instance:
```bash
oci network private-ip list \
  --vnic-id ocid1.vnic.oc1.phx.abyhqljregoj2iq3ov5i62spr2l5fdrnxecvgvmycf5njgidcocac3why7eq \
  --region us-phoenix-1 \
  --query 'data[0].id'
```

### Option 3: Keep Current IP (Not Recommended)
- Current IP `129.146.160.184` is ephemeral
- Risk: IP may be deallocated if instance stops or volume is detached
- Not suitable for long-term infrastructure

## How to Verify Active IP

After making changes, verify your instance is reachable:

```bash
# Test connection
ssh -i ~/.ssh/your-key.pem ubuntu@<IP_ADDRESS>

# Check current instance public IP from OCI CLI
oci compute instance get --instance-id ocid1.instance.oc1.phx.anyhqljrmzsa3tqcz7hquje7yxbxeflyg34wu5mxsbgzjghknhxdzjbczreq \
  --region us-phoenix-1 \
  --query 'data."public-ip"'
```

## Terraform Outputs (Reference)

View current configuration:
```bash
terraform output
```

Key Resources:
- **Instance:** `oci_core_instance.instance-20241129-1228`
- **Reserved IP:** `oci_core_public_ip.minecraft_reserved_ip`
- **Data Volume:** `oci_core_volume.minecraft_data`
- **Network:** Two VCNs, subnets, security lists,  route tables, IGWs

## Data Persistence Guarantee

✅ The 50GB data volume is managed independently  
✅ Volume attachment will survive instance recreation  
✅ Minecraft user (UID 1002) is configured for consistency  
✅ Cloud-init setup script handles auto-mounting on new instances  

When you rebuild:
1. Old instance deleted
2. New instance created with same subnet/specifications  
3. Reserved IP `132.226.86.107` attached to new instance
4. Data volume automatically remounted to `/mnt/minecraft-data`
5. All Minecraft server files and worlds preserved

## Security Notes

🔒 SSH access currently restricted to your IP: `71.56.204.254`  
🔒 Minecraft ports open globally: `25565/tcp`, `25565/udp`  
🔒 HTTP/HTTPS ports open: `80/tcp`, `443/tcp`  
🔒 UFW firewall configured on instance  

To modify security rules, edit [network.tf](network.tf)  and update the security lists.

## Next Steps

1. **Choose:** Do you want to migrate to `132.226.86.107` now or the next time you rebuild?
2. **Update Configs:** Update Minecraft client connection lists, DNS, firewalls to use the new IP
3. **Test:** From a client, connect to the new IP address
4. **Rebuild:** If using Option 1, run `terraform destroy && terraform apply -auto-approve`

# Reserved Public IP Setup

## Current Status

**Existing Instance IP:** `129.146.160.184` (ephemeral - can be lost on rebuild)
**New Reserved IP:** `132.226.86.107` (reserved - survives rebuilds)

## What Was Done

1. Created a reserved public IP resource in Terraform that will be allocated to future rebuilt instances
2. This reserved IP will be automatically assigned to new compute instances when infrastructure is rebuilt

##  What You Need to Do

### Option 1: Use the New Reserved IP (Recommended)
- Update your DNS/firewall rules to use `132.226.86.107` instead of `129.146.160.184`
- When you rebuild the infrastructure with `terraform apply`, the new reserved IP will be automatically assigned
- Future rebuilds will always get the same IP

### Option 2: Migrate to the New IP on Current Instance
- The current instance still uses the ephemeral IP `129.146.160.184`
- To update it to use the reserved IP, you would need to:
  1. Stop the instance
  2. Detach the current public IP
  3. Attach the reserved IP
  4. Restart the instance

### Option 3: Reserve Your Existing IP
If you must keep `129.146.160.184`:
- Use OCI Console: Compute → Instances → (select instance) → Attached VNICs → edit VNIC details
- Or use OCI CLI: `oci network public-ip create --compartment-id <COMP_ID> --public-ip-pool-id <POOL_ID> --lifetime RESERVED`
- Note: You cannot retroactively reserve an ephemeral IP; you can only release it and request a specific one if OCI has it available

## How Terraform Manages This

The Terraform configuration now includes:
- `oci_core_public_ip.minecraft_reserved_ip`: Creates the reserved IP resource
- When you destroy and recreate the instance with `terraform apply`, the reserved IP will be attached automatically to the new instance
- This ensures all future rebuilt machines have the same public IP address

##  Next Steps

1. **Update Your Access Rules:**
   - Update firewall/security group rules to use the reserved IP
   - Update Minecraft server access lists if needed
   - Update any external DNS or routing configurations

2. **Test the Reserved IP:**
   - Once you're ready, you can move your services to use `132.226.86.107`
   - Or destroy and recreate the instance to switch IPs automatically

3. **Future Infrastructure Rebuilds:**
   - Any future `terraform apply` will ensure new instances use the reserved IP `132.226.86.107`

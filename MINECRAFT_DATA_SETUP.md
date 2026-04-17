# Minecraft Data Volume Setup

## Overview

The Minecraft data volume is automatically created and attached by Terraform, but it needs to be formatted and mounted on the instance before use. This directory contains scripts and instructions to set this up.

## Quick Start

### Option 1: Automatic Setup with SSH (Recommended for new instances)

1. **SSH into your instance:**
   ```bash
   ssh -i ~/.oci/oci_api_key.pem ubuntu@<PUBLIC_IP>
   ```
   (Replace `<PUBLIC_IP>` with your instance's public IP)

2. **Download and run the setup script:**
   ```bash
   curl -o ~/user_data.sh https://raw.githubusercontent.com/YOUR_REPO/oci-minecraft/main/user_data.sh
   chmod +x ~/user_data.sh
   sudo ~/user_data.sh
   ```

   Or from your local machine:
   ```bash
   scp -i ~/.oci/oci_api_key.pem user_data.sh ubuntu@<PUBLIC_IP>:~/
   ssh -i ~/.oci/oci_api_key.pem ubuntu@<PUBLIC_IP> 'chmod +x ~/user_data.sh && sudo ~/user_data.sh'
   ```

3. **Verify the setup:**
   ```bash
   df -h /mnt/minecraft-data
   ls -la /mnt/minecraft-data
   ```

### Option 2: Manual Commands

If you prefer to run commands interactively:

```bash
# SSH to instance
ssh -i ~/.oci/oci_api_key.pem ubuntu@<PUBLIC_IP>

# Find the attached data volume (typically /dev/sdb)
lsblk

# Format the volume (ONLY if it's new/unformatted)
sudo mkfs.ext4 /dev/sdb

# Create mount point
sudo mkdir -p /mnt/minecraft-data

# Mount the volume
sudo mount /dev/sdb /mnt/minecraft-data

# Make mount permanent
echo '/dev/sdb /mnt/minecraft-data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Set permissions
sudo chown -R ubuntu:ubuntu /mnt/minecraft-data
```

## When to Run Setup

### First Time After Instance Creation
Always run the setup script/commands when you first create the instance.

### After Updating Instance Image
When you update the instance's image (e.g., upgrading Ubuntu), the data volume:
- ✅ **Remains intact** - All data is preserved
- ✅ **Stays attached** - Volume attachment persists
- ⚠️ **May need remounting** - Run the setup again to ensure it's mounted

After an image update:
```bash
ssh -i ~/.oci/oci_api_key.pem ubuntu@<PUBLIC_IP> 'sudo ~/ user_data.sh'
```

## Script Details

The `user_data.sh` script is idempotent—it safely handles:
- ✅ Detecting the data volume device
- ✅ Skipping format if volume is already formatted
- ✅ Checking if already mounted before mounting
- ✅ Adding to `/etc/fstab` only if not present
- ✅ Setting proper permissions
- ✅ Logging all actions to `/var/log/minecraft-volume-setup.log`

## Verification

After setup, verify everything is working:

```bash
# Check mounted volumes
df -h

# Check specific data volume
df -h /mnt/minecraft-data

# Check logs
tail -f /var/log/minecraft-volume-setup.log
```

## Troubleshooting

### Volume not found
If the script can't find the volume:
- Verify the volume is attached in OCI Console
- Check `lsblk` to see available block devices
- Confirm the data volume is in your Terraform state: `terraform state show oci_core_volume.minecraft_data`

### Volume already formatted with different filesystem
If the volume was previously used with a different filesystem (e.g., XFS instead of ext4):

```bash
# Check current filesystem
sudo blkid /dev/sdb

# Backup any existing data first!
# Then re-format if needed:
sudo mkfs.ext4 -F /dev/sdb
```

### Permission issues
If you can't write to `/mnt/minecraft-data`:

```bash
# Fix permissions
sudo chown -R ubuntu:ubuntu /mnt/minecraft-data
sudo chmod 755 /mnt/minecraft-data

# Verify
ls -la /mnt/minecraft-data
```

## Data Durability

Your data is stored on the persistent volume (`minecraft_data`), which:
- ✅ Survives instance restarts
- ✅ Survives instance image updates
- ✅ Can be backed up independently
- ✅ Can be attached to different instances if needed

See `compute.tf` for volume configuration details.

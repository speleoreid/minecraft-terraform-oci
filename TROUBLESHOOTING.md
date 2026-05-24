# Troubleshooting Guide

Common issues and solutions for the OCI Free Minecraft Server.

## Table of Contents

- [Installation & Deployment](#installation--deployment)
- [Connectivity Issues](#connectivity-issues)
- [Minecraft Service Issues](#minecraft-service-issues)
- [Performance Issues](#performance-issues)
- [Volume & Storage Issues](#volume--storage-issues)
- [Updating the OS Image](#updating-the-os-image)

---

## Installation & Deployment

### Error: "Invalid fingerprint format"

**Symptom**: Terraform error about API fingerprint

**Solution**:
```bash
# Get correct fingerprint format (should be: ab:cd:ef:12:34:56:...)
# From OCI Console:
# Profile → My Profile → API Keys → Copy Fingerprint

# Check terraform.tfvars has correct format
cat terraform.tfvars | grep api_fingerprint
```

---

### Error: "Terraform init fails - cannot download OCI provider"

**Symptom**: `terraform init` hangs or fails

**Solution**:
```bash
# Ensure you have internet access and correct credentials
# Try with explicit provider version
terraform init -upgrade

# Or download manually
terraform providers lock -platform=darwin_amd64 -platform=linux_amd64
```

---

### Error: "Invalid tenancy OCID"

**Symptom**: Apply fails with "Resource not found" or "Compartment not found"

**Solution**:
1. Verify OCID format: `ocid1.tenancy.oc1...` (should start with `ocid1.tenancy`)
2. Get correct OCID:
   - OCI Console → Click profile → Tenancy
   - Copy the full OCID from Tenancy Details
3. Update `terraform.tfvars`
4. Run `terraform apply` again

---

## Connectivity Issues

### Can't SSH to Instance

**Symptom**: `ssh: connect to host X.X.X.X port 22: Connection refused` or times out

**Possible Causes & Solutions**:

#### 1. Instance Still Initializing
```bash
# Wait 2-3 minutes after terraform apply
# Check instance is running
terraform show | grep "instance_state"

# Should show: lifecycle "instance_state" = "RUNNING"
```

#### 2. Security List Blocking SSH
```bash
# Check security list allows port 22
# SSH to instance and verify UFW
ssh ubuntu@<public-ip>

sudo ufw status
# Should show:
# 22/tcp    ALLOW

# If not, add it:
sudo ufw allow 22/tcp
```

#### 3. Wrong SSH Key
```bash
# Verify SSH key path in terraform.tfvars
cat terraform.tfvars | grep ssh_public_key_path

# Verify key matches public key on instance
cat ~/.ssh/minecraft_key.pub

# If wrong, update terraform.tfvars and recreate instance
terraform taint oci_core_instance.server_instance
terraform apply
```

#### 4. Wrong Username
Canonical Ubuntu uses `ubuntu` user (not `ec2-user`, `admin`, or `root`):
```bash
ssh ubuntu@<public-ip>  # ✓ Correct
ssh admin@<public-ip>   # ✗ Wrong
```

---

### Minecraft Port (25565) Connection Refused

**Symptom**: `nc -zv <ip> 25565` shows "Connection refused"

**Possible Causes & Solutions**:

#### 1. Minecraft Service Not Running
```bash
ssh ubuntu@<public-ip>
sudo systemctl status minecraft.service

# If not running:
sudo systemctl start minecraft.service

# Check service status again
sudo systemctl status minecraft.service
```

#### 2. UFW Firewall Blocking Port
```bash
ssh ubuntu@<public-ip>

# Check UFW status
sudo ufw status

# Should show:
# 25565/tcp    ALLOW
# 25565/udp    ALLOW

# If not, enable:
sudo ufw allow 25565/tcp
sudo ufw allow 25565/udp

# Verify
sudo ufw status
```

#### 3. OCI Security List Blocking Port
```bash
# From your local computer
# Check OCI Console:
# Instances → Your Instance → VNIC → Security Lists
# Verify port 25565/TCP and 25565/UDP are in Ingress Rules

# If not, add via Terraform (edit network.tf) or OCI Console
```

#### 4. Minecraft Service Failed to Start
```bash
ssh ubuntu@<public-ip>

# Check service logs
sudo journalctl -u minecraft -n 100

# Look for Java errors or permission issues
# Common: "Address already in use" (port 25565 occupied)
# Solution: Kill process or restart service

sudo systemctl restart minecraft.service
```

---

## Minecraft Service Issues

### Minecraft Service Status Shows "Failed"

**Symptom**: `sudo systemctl status minecraft.service` shows "failed"

**Debug Steps**:

```bash
ssh ubuntu@<public-ip>

# Check service logs
sudo journalctl -u minecraft -n 50

# Look for errors like:
# - "Cannot find server.jar"
# - "No such file or directory"
# - "Permission denied"
# - "Out of memory"
```

**Solutions**:

#### Missing server.jar
```bash
# Check if file exists
ls -lh /mnt/persistent-data/minecraft/server/server.jar

# If missing, download manually
cd /mnt/persistent-data/minecraft/server
sudo -u minecraft wget https://launcher.mojang.com/v1/objects/\
  $(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | \
  jq -r '.latest.release | scan("[0-9]+\\.[0-9]+\\.[0-9]+")')...
```

#### Permission Denied
```bash
# Fix permissions
sudo chown -R minecraft:minecraft /mnt/persistent-data/minecraft/server
sudo chmod -R 755 /mnt/persistent-data/minecraft/server

# Restart service
sudo systemctl restart minecraft.service
```

#### Out of Memory
```bash
# Check available RAM
free -h

# If low, edit service file
sudo nano /etc/systemd/system/minecraft.service

# Reduce Java heap:
# ExecStart=/usr/bin/java -Xms2G -Xmx4G -jar server.jar nogui

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart minecraft.service
```

---

### Players Can Connect But Game Crashes/Lags

**Symptom**: Server loads but world doesn't generate or connection drops

**Solutions**:

#### 1. Check Server Logs
```bash
ssh ubuntu@<public-ip>
sudo journalctl -u minecraft -f  # Follow live logs
```

#### 2. Monitor Resource Usage
```bash
# Check CPU/Memory/Disk
top   # Press q to exit
df -h  # Disk usage
free -h  # Memory usage
```

#### 3. Reduce Difficulty
```bash
# Edit server.properties
sudo nano /mnt/persistent-data/minecraft/server/server.properties

# Set lower difficulty/chunk load
# difficulty=1
# max-tick-time=60000

# Restart server
sudo systemctl restart minecraft.service
```

#### 4. Increase Java Heap
```bash
# Increase RAM allocation
sudo nano /etc/systemd/system/minecraft.service

# Change: -Xms4G -Xmx6G  (to use more of your 6GB)
# Save, then:
sudo systemctl daemon-reload
sudo systemctl restart minecraft.service
```

---

## Performance Issues

### Server Running Slow / High CPU Usage

**Check System Resources**:

```bash
ssh ubuntu@<public-ip>

# Check CPU
top -b -n 1 | head -20

# Check memory
free -h

# Check disk
df -h /mnt/persistent-data

# Check Java process
ps aux | grep java
```

**Solutions**:

1. **Reduce tick time in server.properties**:
   ```bash
   sudo nano /mnt/persistent-data/minecraft/server/server.properties
   # max-tick-time=120000  (increase timeout)
   ```

2. **Lower world difficulty/complexity**:
   ```bash
   difficulty=1
   spawn-monsters=false  # For testing
   view-distance=10      # Reduce render distance
   ```

3. **Restart service**:
   ```bash
   sudo systemctl restart minecraft.service
   ```

---

## Volume & Storage Issues

### Volume Not Mounted / Data Loss

**Symptom**: `/mnt/persistent-data/minecraft` is empty or doesn't exist

**Debug**:

```bash
ssh ubuntu@<public-ip>

# Check if volume is attached
lsblk  # Should show /dev/sdb with ~50GB

# Check if mounted
df -h /mnt/persistent-data

# Check fstab
cat /etc/fstab | grep persistent-data
```

**Solutions**:

#### Volume Not Attached
```bash
# In OCI Console:
# Instances → Instance → Block Volumes → Attach Volume
# Or via Terraform (should be automatic)
```

#### Volume Not Formatted
```bash
# Format volume (WARNING: destroys data)
sudo mkfs.ext4 /dev/sdb
```

#### Not in fstab
```bash
# Add to fstab for auto-mount
echo "/dev/sdb  /mnt/persistent-data  ext4  defaults,nofail  0  2" | \
  sudo tee -a /etc/fstab

# Mount it
sudo mount /mnt/persistent-data
```

---

### Out of Disk Space

**Symptom**: World won't generate or Minecraft crashes

**Check Usage**:

```bash
ssh ubuntu@<public-ip>

df -h /mnt/persistent-data
du -sh /mnt/persistent-data/minecraft/server/world*
```

**Solutions**:

1. **Delete old backups** (if any):
   ```bash
   ls -lh /mnt/persistent-data/minecraft/server/
   rm /mnt/persistent-data/minecraft/server/server-*.jar  # Old versions
   ```

2. **Increase volume size** (if >45GB used):
   ```bash
   # Expand volume in OCI Console or via Terraform
   # Then on instance:
   sudo resize2fs /dev/sdb
   ```

3. **Delete old worlds**:
   ```bash
   sudo rm -rf /mnt/persistent-data/minecraft/server/world_old/
   ```

---

## Updating the OS Image

### How to Upgrade to a Newer Ubuntu Image

When you want to update your Minecraft server to a newer Ubuntu image (security patches, bug fixes, etc.):

#### Step 1: Find Available Images

```bash
terraform plan
```

Look for the output `available_ubuntu_images` which lists all non-Minimal aarch64 Ubuntu images.

#### Step 2: Update the Image ID

Edit `terraform.tfvars` and update `os_image_id`:

```hcl
# Example: switching to a newer Ubuntu 24.04 release
os_image_id = "ocid1.image.oc1.phx.aaaaaaaanew_image_id_here"
```

#### Step 3: Force Terraform to Recreate the Instance

**⚠️ Important**: Due to OCI provider limitations, `terraform plan` will show "2 to change" instead of "destroy + recreate". You must manually tell Terraform to destroy and recreate:

```bash
terraform taint oci_core_instance.server_instance
terraform apply
```

#### Step 4: Verify the Update

```bash
ssh ubuntu@<your-static-ip>
uname -a  # Check kernel version
lsb_release -a  # Check Ubuntu version
```

#### What Happens During Update

- ✅ **Instance is destroyed and recreated** (new kernel, all packages updated)
- ✅ **Data volume persists** (your Minecraft world stays intact)
- ✅ **Static IP is preserved** (no need to update your DNS/firewall rules)
- ⚠️ **Temporary downtime** (~2-5 minutes while instance reboots)
- ⚠️ **New SSH host key** (first SSH may ask about host key authenticity)

#### After the Update Completes

Your Minecraft service will:
1. Start automatically via systemd
2. Find and mount your data volume
3. Resume hosting your world

If you need to verify the service is running:

```bash
ssh ubuntu@<your-static-ip>
sudo systemctl status minecraft.service

# Check logs if needed
sudo journalctl -u minecraft -n 20
```

---

## Getting More Help

- 🔍 **Check Logs**: `sudo journalctl -u minecraft -n 200`
- 📋 **Check Status**: `sudo systemctl status minecraft.service`
- 🔧 **Terraform Debug**: `terraform plan` to see current state
- 💬 **GitHub Issues**: Open an issue with logs and error messages
- 📖 **Minecraft Server Wiki**: https://minecraft.fandom.com/wiki/Server

---

## Still Stuck?

When reporting issues, include:

1. Output of `terraform show`
2. Output of `sudo systemctl status minecraft.service`
3. Last 50 lines of logs: `sudo journalctl -u minecraft -n 50`
4. Error message (full text)
5. Steps to reproduce

Open a GitHub issue with this information!

# Getting Started with OCI Free Minecraft Server

This guide walks you through setting up your own free Minecraft server on Oracle Cloud Infrastructure from scratch.

## Table of Contents

1. [Create OCI Account](#create-oci-account)
2. [Set Up OCI Credentials](#set-up-oci-credentials)
3. [Install Required Tools](#install-required-tools)
4. [Configure Terraform](#configure-terraform)
5. [Deploy Infrastructure](#deploy-infrastructure)
6. [Verify Server](#verify-server)
7. [Play Minecraft](#play-minecraft)

---

## Create OCI Account

1. Visit https://www.oracle.com/cloud/free/
2. Click **"Start for free"**
3. Enter your email and select your country
4. Complete the form with your details
5. Verify your email
6. Add payment method (won't be charged for always-free resources)
7. Accept terms and create account

**Save your compartment OCID** - you'll need it for Terraform. Find it in:
- OCI Console → Compartment Details → OCID (copy the full value)

---

## Set Up OCI Credentials

### Generate API Key

1. Log in to [OCI Console](https://console.us-phoenix-1.oraclecloud.com/)
2. Click profile icon (top-right) → **My Profile**
3. Scroll to **API Keys** section
4. Click **Add API Key**
5. Click **Download Private Key** (save to `~/.oci/oci_api_key.pem`)
6. Click **Add** and **Close**
7. View the generated public key and **copy the fingerprint**

```bash
# Create .oci directory if needed
mkdir -p ~/.oci

# Set proper permissions
chmod 600 ~/.oci/oci_api_key.pem
```

### Collect Your OCIDs

From OCI Console, gather these values (you'll need them for `terraform.tfvars`):

- **Tenancy OCID**: Profile icon → Tenancy → Tenancy Details → OCID
- **User OCID**: Profile icon → User Settings → User Details → OCID
- **API Fingerprint**: From API Key creation above
- **Region Code**: In your OCI console URL or Regions (e.g., `us-phoenix-1`)

---

## Install Required Tools

### macOS

```bash
# Install Terraform using Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform --version
```

### Linux

```bash
# Download Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform --version
```

### Windows

Download from https://www.terraform.io/downloads and add to PATH.

### Generate SSH Key (All Platforms)

```bash
# Create SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/minecraft_key -N ""

# View public key
cat ~/.ssh/minecraft_key.pub
```

---

## Configure Terraform

### 1. Clone Repository

```bash
git clone https://github.com/your-username/oci-minecraft.git
cd oci-minecraft
```

### 2. Create terraform.tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 3. Edit terraform.tfvars

```bash
nano terraform.tfvars
```

Fill in your values:

```hcl
# OCI Credentials
tenancy_ocid = "ocid1.tenancy.oc1..."          # From step above
user_ocid = "ocid1.user.oc1..."                # From step above
api_fingerprint = "ab:cd:ef:12:34:56:..."     # From API key creation
private_key_path = "~/.oci/oci_api_key.pem"   # Path to your private key
region = "us-phoenix-1"                        # Your OCI region

# SSH
ssh_public_key_path = "~/.ssh/minecraft_key.pub"  # Path to your public key

# Minecraft Data Volume
minecraft_data_volume_size_gb = 50              # Persistent storage size
```

**Save the file** (Ctrl+O, Enter, Ctrl+X in nano)

---

## Deploy Infrastructure

### 1. Initialize Terraform

This downloads the OCI provider and prepares your working directory.

```bash
terraform init
```

**Expected output**: "Terraform has been successfully configured!"

### 2. Review Plan

This shows what will be created (no changes yet).

```bash
terraform plan
```

Review the resources that will be created:
- ✓ VCN with subnet
- ✓ Internet Gateway
- ✓ Security List (firewall rules)
- ✓ Compute instance
- ✓ Block storage volume
- ✓ Volume attachment

### 3. Apply Configuration

This creates your infrastructure. **This takes 3-5 minutes**.

```bash
terraform apply
```

When prompted: type `yes` and press Enter.

```
Apply complete! Resources created and applied.

Outputs:

instance0_public_ip = "150.123.456.789"
instance0_ssh_command = "ssh ubuntu@150.123.456.789"
```

**Save your public IP** - you'll need it to connect.

---

## Verify Server

### 1. Wait for Initialization

The instance runs a startup script that:
- Formats and mounts the data volume
- Installs Java 25
- Downloads Minecraft server.jar
- Configures firewall (UFW)
- Starts the Minecraft service

**This takes about 5 minutes**. During this time, SSH will work, but the service might not be running yet.

### 2. SSH to Instance

```bash
# Using terraform output
ssh ubuntu@$(terraform output -raw instance0_public_ip)

# Or manually
ssh ubuntu@150.123.456.789
```

### 3. Check Minecraft Service

```bash
sudo systemctl status minecraft.service
```

Expected output when ready:
```
● minecraft.service - Minecraft Server
   Loaded: loaded (/etc/systemd/system/minecraft.service)
   Active: active (running)
```

If it says "activating" or "failed", wait a few more minutes and check again.

### 4. Check Volume Mount

```bash
df -h /mnt/persistent-data/minecraft
```

Should show a 50GB volume mounted.

### 5. Check Initialization Logs

```bash
sudo tail -50 /var/log/minecraft-volume-setup.log
```

Look for any errors. If all looks good, move to the next section.

---

## Play Minecraft

### 1. Get Server Address

```bash
terraform output instance0_public_ip
```

Copy the IP address shown.

### 2. Add Server in Minecraft

1. Launch Minecraft Java Edition
2. Click **Multiplayer**
3. Click **Add Server**
4. **Server Name**: Enter anything (e.g., "My OCI Server")
5. **Server Address**: Paste the public IP (e.g., `150.123.456.789`)
6. Click **Done**
7. Click on your server in the list
8. Click **Join Server**

### 3. Wait for World Generation

First startup generates the world (takes 1-2 minutes). Don't disconnect.

### 4. You're In!

You now have a free, always-on Minecraft server in Oracle Cloud! 🎮

---

## Common Issues During Setup

### Problem: SSH Connection Refused

**Solution**: 
- Wait 2-3 minutes after `terraform apply`
- Check instance is running: `terraform show` | grep "instance_state"
- Check security: OCI Console → Instances → Click instance → VNIC Details → Check Security List

### Problem: Minecraft Service Not Running

**Solution**:
```bash
ssh ubuntu@<ip>
sudo systemctl status minecraft.service
sudo journalctl -u minecraft -n 50  # Show last 50 lines of logs
```

Look for Java errors or download failures. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Problem: Can't Connect to Port 25565

**Solution**:
```bash
# From your local computer
nc -zv <public-ip> 25565

# If it times out, check firewall on instance
ssh ubuntu@<ip>
sudo ufw status
```

Should show:
```
25565/tcp    ALLOW
25565/udp    ALLOW
```

---

## Next Steps

- 📖 Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand the infrastructure
- 🔧 Learn how to [manage your server](README.md#managing-your-server)
- 💾 Set up [automated backups](README.md#backup-your-world)
- ⚙️ [Configure server properties](README.md#server-properties)

---

## Getting Help

- **Terraform Issues**: Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Minecraft Help**: https://help.minecraft.net
- **OCI Documentation**: https://docs.oracle.com/iaas/
- **GitHub Issues**: Open an issue in this repository

Good luck! 🚀

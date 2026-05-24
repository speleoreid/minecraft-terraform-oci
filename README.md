# OCI Free Minecraft Server

Deploy a fully functional Minecraft Java Edition server on Oracle Cloud Infrastructure's **always-free tier** with Terraform. Perfect for small servers, testing, or always-on gameplay.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Features

- 🎮 **Always-Free Tier**: Single A1 compute instance (1 OCPU, 6GB RAM) - no credit card charges
- 💾 **Persistent Storage**: 50GB block storage volume that survives instance recreations
- 🔐 **Secure**: UFW firewall + OCI Security Lists + SSH key authentication
- 🚀 **Automated Setup**: Cloud-init user_data handles all configuration
- ☕ **Java 25 LTS**: Latest OpenJDK from Eclipse Temurin
- 📦 **Latest Minecraft**: Automatically downloads latest server.jar
- 🔄 **Infrastructure as Code**: Fully version-controlled Terraform configuration

## Quick Start

### Prerequisites

1. **Oracle Cloud Account** (free tier) - [Sign up here](https://www.oracle.com/cloud/free/)
2. **Terraform** - [Install v1.0+](https://www.terraform.io/downloads)
3. **OCI CLI** (optional, but helpful) - [Installation guide](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm)
4. **SSH Key** - Generate with: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/minecraft_key`

### Deployment (5 minutes)

1. **Clone this repository**:
   ```bash
   git clone https://github.com/your-username/oci-minecraft.git
   cd oci-minecraft
   ```

2. **Configure Terraform variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your OCI credentials
   nano terraform.tfvars
   ```

3. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

4. **Get your connection details**:
   ```bash
   terraform output instance0_ssh_command
   terraform output instance0_public_ip
   ```

5. **SSH to the server** (wait ~5 minutes for initialization):
   ```bash
   ssh ubuntu@<instance-ip>
   
   # Check Minecraft service
   sudo systemctl status minecraft.service
   ```

6. **Connect in Minecraft**:
   - Server address: `<instance-public-ip>:25565`
   - Wait 2-3 minutes for first startup

## Architecture

This deployment includes:

- **Compute**: 1x A1 compute instance (1 OCPU, 6GB RAM, always-free)
- **Storage**: 50GB block volume for persistent Minecraft data
- **Network**: Virtual Cloud Network with subnet, Internet Gateway, and security rules
- **Firewall**: Dual-layer protection (OCI Security Lists + UFW)

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and explanations.

## Configuration

### Server Properties

Customize Minecraft server settings by editing `/mnt/persistent-data/minecraft/server/server.properties` on the instance:

```bash
ssh ubuntu@<instance-ip>
sudo nano /mnt/persistent-data/minecraft/server/server.properties
sudo systemctl restart minecraft.service
```

### Java Heap Memory

Adjust in the systemd service on the instance:

```bash
sudo nano /etc/systemd/system/minecraft.service
# Edit: ExecStart=/usr/bin/java -Xms4G -Xmx6G -jar server.jar nogui
sudo systemctl daemon-reload
sudo systemctl restart minecraft.service
```

Current defaults: `-Xms4G -Xmx6G` (4GB min, 6GB max)

### HTTPS & Web Server (nginx)

The server includes nginx for HTTPS support. Your configuration is persisted on the instance and survives rebuilds.

**View/Edit web server config:**
```bash
ssh ubuntu@<instance-ip>
sudo nano /mnt/persistent-data/nginx/configs/minecraft-ssl
sudo systemctl reload nginx  # Apply changes
```

**Add custom locations** (e.g., status page, API proxy):
```nginx
location /status {
    return 200 "Minecraft Server Running\n";
    add_header Content-Type text/plain;
}
```

**Backup your nginx config:**
```bash
scp -i ~/.ssh/id_rsa ubuntu@<instance-ip>:/mnt/persistent-data/nginx/configs/minecraft-ssl ./minecraft-ssl.bak
```

The config is stored on persistent storage (`/mnt/persistent-data/nginx/configs/`) so it persists across instance rebuilds.

## Managing Your Server

### SSH Access

```bash
# Connect to instance
ssh ubuntu@$(terraform output -raw instance0_public_ip)
```

### Check Minecraft Logs

```bash
# Real-time logs
sudo journalctl -u minecraft -f

# Last 100 lines
sudo journalctl -u minecraft -n 100
```

### Restart Minecraft

```bash
sudo systemctl restart minecraft.service
```

### Backup Your World

```bash
# On your local machine
ssh ubuntu@<instance-ip> 'tar czf - /mnt/persistent-data/minecraft/server/world' > minecraft-world-$(date +%Y%m%d).tar.gz
```

### Destroy Infrastructure

**⚠️ WARNING**: This destroys the instance but **preserves** the data volume. To destroy everything:

```bash
# This will ask for confirmation
terraform destroy

# Then, if you want to remove the persistent minecraft volume too:
# (manually delete in OCI console or use OCI CLI)
oci bv volume delete --volume-id <volume-ocid>
```

## Cost

**Always-free tier**: $0/month for:
- 1x A1 Compute (1 OCPU, 6GB RAM)
- Up to 200GB total block storage (we use 50GB boot + 50GB data)
- 10GB egress/month

See [COST.md](COST.md) for pricing details and potential overage scenarios.

## Troubleshooting

Having issues? Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common problems and solutions.

## Maintenance

### Regular Updates

Keep your Minecraft server secure and up-to-date:

#### OS Security Updates

Ubuntu automatically applies security patches. To verify:

```bash
ssh ubuntu@$(terraform output -raw instance0_public_ip)
sudo apt update && apt list --upgradable
```

#### Upgrading to a Newer Ubuntu Image

When you want to upgrade to a newer Ubuntu release (for bug fixes, performance improvements, or kernel updates):

```bash
# 1. Check available images
terraform plan

# 2. Update os_image_id in terraform.tfvars
nano terraform.tfvars

# 3. Force Terraform to recreate the instance
terraform taint oci_core_instance.server_instance
terraform apply

# 4. Verify the update
ssh ubuntu@$(terraform output -raw instance0_public_ip)
uname -a
```

**What to expect**:
- ✅ Minecraft data volume **persists** (world data is safe)
- ✅ Static IP **is preserved** (no DNS changes needed)
- ⏱️ **2-5 minute downtime** during instance recreation
- ℹ️ See [TROUBLESHOOTING.md - Updating the OS Image](TROUBLESHOOTING.md#updating-the-os-image) for detailed steps

### World Backups

Back up your Minecraft world regularly:

```bash
# One-time backup
ssh ubuntu@<instance-ip> 'tar czf - /mnt/persistent-data/minecraft/server/world' > backup-$(date +%Y%m%d).tar.gz

# Automated daily backups (on the instance)
ssh ubuntu@<instance-ip>
crontab -e
# Add: 0 2 * * * tar czf /mnt/persistent-data/minecraft/backups/world-$(date +\%Y\%m\%d).tar.gz /mnt/persistent-data/minecraft/server/world
```

### Monitoring

Check instance health:

```bash
# Minecraft service status
ssh ubuntu@$(terraform output -raw instance0_public_ip)
sudo systemctl status minecraft.service

# System resources
free -h
df -h /mnt/persistent-data/minecraft

# Recent errors
sudo journalctl -u minecraft -n 50
```

## Advanced Topics

### Updating the OS Image

To use a newer Ubuntu version:

```bash
# Update terraform.tfvars with new image OCID
terraform taint oci_core_instance.server_instance
terraform apply
```

The data volume will be automatically remounted on the new instance.

### Scaling (Future)

This template currently uses a single A1 instance (always-free). To scale to more powerful hardware, change in `terraform.tfvars`:

```hcl
instance_shape = "VM.Standard.E2.2"  # More cores, more cost
instance_ocpus = 4
instance_shape_config_memory_in_gbs = 16
```

## File Structure

```
.
├── README.md                    # This file
├── ARCHITECTURE.md              # System architecture & diagrams
├── GETTING_STARTED.md           # Detailed setup guide
├── TROUBLESHOOTING.md           # Common issues & solutions
├── COST.md                      # Pricing & always-free details
├── terraform.tfvars.example     # Template for variables
├── .gitignore                   # Git ignore rules
├── main.tf                      # Outputs & data sources
├── network.tf                   # VCN, subnets, security
├── compute.tf                   # Instance & storage
├── variables.tf                 # Variable definitions
├── provider.tf                  # OCI provider config
├── user_data.sh                 # Instance initialization script
└── INFRASTRUCTURE_DIAGRAM.md    # Network diagram
```

## Security Considerations

- **SSH Key**: Store `~/.ssh/minecraft_key` securely, never commit to git
- **Server IP**: Will be public; use firewall rules to restrict access if needed
- **Firewall**: UFW is configured to deny all incoming except SSH and Minecraft ports
- **OCI Security Lists**: Restrict to specific IPs if desired (edit `network.tf`)

## Contributing

Found a bug? Want to improve this? Open an issue or submit a pull request! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License - see [LICENSE](LICENSE) for details.

## Support

- 💬 **Issues**: Open a GitHub issue
- 📖 **Minecraft Server Help**: https://www.minecraft.net/
- 🏢 **OCI Documentation**: https://docs.oracle.com/

## Acknowledgments

Built with:
- [Terraform](https://www.terraform.io/)
- [Oracle Cloud Infrastructure](https://www.oracle.com/cloud/)
- [Eclipse Temurin Java](https://adoptium.net/)

---

**Happy gaming! 🎮**

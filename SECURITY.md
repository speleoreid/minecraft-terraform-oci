# Security Considerations

This document outlines security best practices when deploying and managing this OCI Free Minecraft Server.

## Critical Security Practices

### 1. Protect Your Credentials

**Never commit to Git:**
- `terraform.tfvars` (contains OCI API credentials, SSH keys)
- `.oci/` directory (OCI configuration)
- `*.tfstate` and `*.tfstate.*` files (contain sensitive data)

**Verify .gitignore is configured:**
```bash
grep -E "terraform.tfvars|.oci|tfstate" .gitignore
```

### 2. SSH Key Management

- Generate a unique SSH key for this project:
  ```bash
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/minecraft_key -C "minecraft-server"
  chmod 600 ~/.ssh/minecraft_key
  chmod 644 ~/.ssh/minecraft_key.pub
  ```

- **Never** share your private key (`~/.ssh/minecraft_key`)
- **Never** commit private keys to Git
- Store backups securely (encrypted password manager, etc.)

### 3. Firewall Rules

This deployment uses **two layers of firewall**:

1. **OCI Security Lists** (network level):
   - Controls inbound/outbound traffic to VCN
   - Managed by Terraform in `network.tf`

2. **UFW** (instance level):
   - Final defense on the Ubuntu instance
   - Managed by `user_data.sh`

**Allowed ports by default:**
- `22/tcp` - SSH (admin only)
- `25565/tcp + 25565/udp` - Minecraft server
- `80/tcp` - HTTP (redirects to HTTPS)
- `443/tcp` - HTTPS (if domain configured)

**Restrict SSH access** (recommended):
```bash
# In terraform.tfvars, set:
minecraft_allowed_ips = ["YOUR_HOME_IP/32", "YOUR_OFFICE_IP/32"]

# Format example: "192.0.2.100/32" for a single IP
```

### 4. HTTPS/SSL Certificates

**Automatic Setup** (recommended):
```bash
# In terraform.tfvars, set:
certbot_domain_name = "www.yourdomain.com"
certbot_email       = "admin@yourdomain.com"
```
- Requires port 80 and 443 open
- Requires domain name pointing to instance IP
- Certificates auto-renew daily

**Manual Setup**:
```bash
# If not auto-configured, set up HTTPS manually:
ssh ubuntu@<instance-ip>
sudo certbot certonly --standalone -d minecraft.yourdomain.com
# Then update nginx config with domain
```

### 5. Server Properties Security

After deployment, harden your Minecraft server:

```bash
ssh ubuntu@<instance-ip>
sudo vi /mnt/persistent-data/minecraft/server/server.properties

# Recommended secure settings:
online-mode=true              # Require Microsoft account verification
prevent-proxy-connections=true
difficulty=2                  # or higher
pvp=true/false               # Based on your preference
spawn-monsters=true          # or false for peaceful
white-list=true              # Whitelist approved players
```

Enable whitelist and add approved players:
```bash
# Add players to whitelist.json:
echo '[{"name":"PlayerName","uuid":"UUID-HERE"}]' | \
  sudo tee /mnt/persistent-data/minecraft/server/whitelist.json
```

### 6. Regular Updates

Keep your server secure:

```bash
# Check for OS updates (runs automatically at boot)
ssh ubuntu@<instance-ip>
sudo apt update && sudo apt upgrade

# Restart to apply kernel updates
sudo systemctl reboot

# Check Minecraft version
# Server auto-downloads latest version on restart
sudo systemctl restart minecraft.service
```

### 7. Network Isolation

- **Don't expose management ports** to the internet (8100, 8200, etc.)
- **Restrict Minecraft port** to known players only if possible:
  ```bash
  minecraft_allowed_ips = ["YOUR_ISP_IP_RANGE/24"]
  ```
- **Use VPN** to manage the server remotely if possible

### 8. Backup Security

Backups contain full world data (including player data):

```bash
# Backups are readable by anyone who can SSH
# Ensure backup files are protected:
ssh ubuntu@<instance-ip>
sudo chmod 600 /mnt/persistent-data/minecraft/backups/*.tar.gz

# Consider encrypting backups:
tar czf - /mnt/persistent-data/minecraft/server/world | \
  gpg --symmetric -o world.tar.gz.gpg
```

### 9. Monitoring & Logging

Monitor for suspicious activity:

```bash
# Check authentication logs:
ssh ubuntu@<instance-ip>
sudo tail -50 /var/log/auth.log | grep -i failed

# Monitor Minecraft player activity:
sudo tail -100 /mnt/persistent-data/minecraft/server/logs/latest.log

# Check system resources:
free -h
df -h /mnt/persistent-data
```

### 10. Incident Response

**Compromised SSH key?**
1. Immediately revoke the key in your OCI Console
2. Stop the instance: `terraform destroy` or from OCI Console
3. Rotate all credentials
4. Create new SSH key
5. Redeploy: `terraform apply`

**Suspicious activity?**
1. Check logs: `sudo tail /var/log/auth.log`
2. Review player list: `sudo cat /mnt/persistent-data/minecraft/server/whitelist.json`
3. Check UFW rules: `sudo ufw status`
4. Consider redeploying if compromised

## Known Limitations

- **No authentication** on the Minecraft server by default (open to all players)
- **No encryption** of world data at rest (data volume is unencrypted)
- **No audit logging** enabled by default
- **Single instance** (no redundancy)
- **Always-free tier limitations** (performance may vary)

## Responsible Disclosure

If you discover a security vulnerability:

1. **Do NOT open a public issue**
2. Email: security@youremail.com with details
3. Include: vulnerability description, impact, suggested fix
4. Allow 30 days for response before public disclosure

## Additional Resources

- [OCI Security Best Practices](https://docs.oracle.com/en-us/iaas/Content/Security/Concepts/security.htm)
- [Ubuntu Server Security](https://ubuntu.com/server/docs/security)
- [Minecraft Server Security](https://wiki.vg/Protocol)
- [OWASP Security Guidelines](https://owasp.org/)

---

**Last Updated:** 2026-05-23  
**Maintained By:** OCI Minecraft Contributors

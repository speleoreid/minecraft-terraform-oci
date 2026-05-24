/* Web Server & SSL Certificate Resources */

# nginx and certbot are mandatory (always installed on every instance)
# This ensures reliable SSL certificate automation and web hosting capabilities
#
# IMPORTANT: Certificates AND nginx configs are persisted across image refreshes!
# - /etc/letsencrypt/ is symlinked to /mnt/persistent-data/letsencrypt/
# - nginx config is stored at /mnt/persistent-data/nginx/configs/minecraft-ssl
# - When you refresh/rebuild the instance, certificates and configs remain intact
# - No reconfiguration needed after image refresh

# Always installed and configured:
# - nginx: Web server for hosting content (ports 80/443)
#   - Serves status pages, static content
#   - Document root: /mnt/persistent-data/nginx/www/
#   - Config: /mnt/persistent-data/nginx/configs/minecraft-ssl (persisted)
# - certbot: SSL certificate management from Let's Encrypt
# - python3-certbot-nginx: Automatic nginx configuration for SSL
# - Systemd timer: Automatic daily renewal at 3 AM UTC

# ===== IMAGE REFRESH & PERSISTENCE =====
#
# When you refresh/rebuild your system image:
# 1. Boot volume is replaced with new OS image
# 2. Persistent volume (/mnt/persistent-data) is preserved
# 3. /etc/letsencrypt is symlinked to /mnt/persistent-data/letsencrypt/
# 4. nginx config symlinked to /mnt/persistent-data/nginx/configs/minecraft-ssl
# 5. All certificates and custom nginx settings automatically available after boot
# 6. No manual reconfiguration needed!
#
# Certificate file locations (persistent):
#   /mnt/persistent-data/letsencrypt/live/your-domain.com/
#   ├── cert.pem (public certificate)
#   ├── chain.pem (CA chain)
#   ├── fullchain.pem (cert + chain, for nginx)
#   └── privkey.pem (private key)
#
# nginx config location (persistent):
#   /mnt/persistent-data/nginx/configs/minecraft-ssl
#   - Customize with: sudo nano /mnt/persistent-data/nginx/configs/minecraft-ssl
#   - Reload nginx: sudo systemctl reload nginx
#   - Changes survive instance rebuilds!
#

# After image refresh, nginx will automatically:
#   - Detect the symlinked /etc/letsencrypt/
#   - Load the persisted nginx config
#   - Resume using HTTPS with existing certificates
#   - Continue automatic renewal schedule

# ===== QUICK START: HTTPS FOR YOUR DOMAIN =====
#
# Option A: Automatic Setup (Recommended for first deployment)
# 1. Set certbot_domain_name and certbot_email in terraform.tfvars
# 2. Make sure your domain already points to your server's IP
# 3. Run: terraform apply
# 4. HTTPS is automatically configured on first boot!
#
# Example terraform.tfvars:
#   certbot_domain_name = "minecraft.example.com"
#   certbot_email = "admin@example.com"
#
# Option B: Manual Setup (After deployment)
# 1. Leave certbot_domain_name and certbot_email empty in terraform.tfvars
# 2. SSH to instance: ssh reid@<IP>
# 3. Run manually: sudo certbot --nginx -d your-domain.com -m your-email@example.com
# 4. Certbot will configure nginx and set up auto-renewal
#
# After either option, test with:
#   https://your-domain.com/
#   sudo certbot renew --dry-run  (test renewal without actually renewing)

# ===== COMMON CERTBOT COMMANDS =====
#
# List certificates:
#   sudo certbot certificates
#
# Renew specific certificate:
#   sudo certbot renew --cert-name your-domain.com
#
# Force renewal (bypass 30-day buffer):
#   sudo certbot renew --force-renewal
#
# Manual cert renewal (not recommended, automatic is better):
#   sudo certbot renew --manual-public-ip-logging-ok

# ===== NGINX CUSTOMIZATION =====
#
# Default web root: /mnt/persistent-data/nginx/www/
# Edit nginx config: sudo nano /etc/nginx/sites-available/default
# Reload nginx: sudo systemctl reload nginx
# Restart nginx: sudo systemctl restart nginx

# Note: Ports 80 (HTTP) and 443 (HTTPS) firewall rules in network.tf
# are always open for certification validation and web access

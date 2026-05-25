#!/bin/bash
set -e

echo "Sleeping for 5 minutes for cloud-init"
sleep 300

# Stop unattended-upgrades
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Checking for unattended-upgrades..."
if systemctl is-active --quiet unattended-upgrades; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Stopping unattended-upgrades service..."
  sudo systemctl stop unattended-upgrades || true
  sleep 2
fi

echo "Sleeping for 5 minutes"
sleep 300

# SSH Key for user (injected by Terraform)
SSH_AUTHORIZED_KEYS="${ssh_authorized_keys}"

# Persistent Data Volume Auto-Mount Script
# This script is executed when the instance first boots (or when an image is updated)

MOUNT_POINT="/mnt/persistent-data"
DEVICE=""
LOG_FILE="/var/log/minecraft-volume-setup.log"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Helper function: Wait for apt to be available
wait_for_apt() {
  local max_attempts=60
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    # Check for apt/dpkg processes
    apt_processes=$(pgrep -f "apt-get|apt|unattended-upgrade|dpkg" 2>/dev/null || true)
    
    # Check if lock files are held
    lock_file_check=0
    for lock in /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock; do
      if [ -f "$lock" ] 2>/dev/null && fuser "$lock" >/dev/null 2>&1; then
        lock_file_check=1
        break
      fi
    done
    
    if [ -z "$apt_processes" ] && [ $lock_file_check -eq 0 ]; then
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ apt is available"
      return 0
    fi
    
    # Provide feedback on what's blocking
    if [ $attempt -eq 0 ]; then
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Waiting for apt to become available..."
    fi
    
    if [ -n "$apt_processes" ]; then
      # Show more details about the blocking process
      proc_info=$(ps -p "$apt_processes" -o cmd= 2>/dev/null | head -1 || echo "unknown")
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") [Attempt $((attempt+1))/$max_attempts] Blocked by: $proc_info"
      
      # If unattended-upgrades is still running after attempt 3, kill it
      if [ $attempt -ge 3 ] && echo "$proc_info" | grep -q "unattended-upgrade"; then
        echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Force-stopping unattended-upgrades..."
        sudo pkill -9 -f "unattended-upgrade" || true
        sleep 2
      fi
    fi
    
    if [ $lock_file_check -eq 1 ]; then
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") [Attempt $((attempt+1))/$max_attempts] Lock files held"
    fi
    
    sleep 5
    ((attempt++))
  done
  
  # Timeout reached - provide info and try cleanup
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") WARNING: apt lock timeout, attempting emergency cleanup"
  sudo pkill -9 -f "apt|dpkg|unattended" || true
  sudo rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock* || true
  sleep 2
  return 0
}

# Helper function: Retry apt-get operations with network diagnostics
apt_install() {
  local max_retries=3
  local retry=0
  while [ $retry -lt $max_retries ]; do
    apt-get install -y "$@" 2>&1 && return 0
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") No network, waiting..."
      sleep 10
    fi
    ((retry++))
  done
  return 1
}

echo "Starting Minecraft Data Volume Setup"

############################
# Create admin user
############################
echo ""
echo "Creating user for SSH access"

ADMIN_USER="${admin_username}"

if ! id "$ADMIN_USER" &>/dev/null; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating $ADMIN_USER user..."
  useradd -m -s /bin/bash -G sudo "$ADMIN_USER"
  
  # Create .ssh directory
  mkdir -p /home/$ADMIN_USER/.ssh
  
  # Add SSH public key
  echo "$SSH_AUTHORIZED_KEYS" > /home/$ADMIN_USER/.ssh/authorized_keys
  
  # Set permissions
  chmod 700 /home/$ADMIN_USER/.ssh
  chmod 600 /home/$ADMIN_USER/.ssh/authorized_keys
  chown -R $ADMIN_USER:$ADMIN_USER /home/$ADMIN_USER/.ssh
  
  # Allow user to sudo without password
  echo "$ADMIN_USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/$ADMIN_USER > /dev/null
  chmod 440 /etc/sudoers.d/$ADMIN_USER
  
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ $ADMIN_USER user created successfully"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") $ADMIN_USER user already exists"
fi

# Function to find the data volume device (formatted or unformatted)
find_data_volume() {
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Searching for data volume..." >&2
  
  # Wait up to 60 seconds for volume to appear
  for i in {1..30}; do
    # Look for any block devices (excluding boot volumes)
    for device in /dev/sd{b,c,d,e,f}; do
      if [ -b "$device" ] 2>/dev/null; then
        echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Found data volume: $device" >&2
        echo "$device"
        return 0
      fi
    done
    
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Waiting for volume to attach... (attempt $i/30)" >&2
    sleep 2
  done
  
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ERROR: Could not find data volume" >&2
  return 1
}

# Get the device path
if DEVICE=$(find_data_volume); then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Using device: $DEVICE"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ERROR: Data volume not found. Manual setup required."
  exit 1
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating mount point: $MOUNT_POINT"
  sudo mkdir -p "$MOUNT_POINT"
fi

# Format volume if not already formatted
# IMPORTANT: This check ensures mkfs only runs on first setup.
# If the volume is attached to a new instance, this will skip formatting
# and preserve all existing data.
if ! sudo blkid "$DEVICE" >/dev/null 2>&1; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Formatting $DEVICE with ext4..."
  sudo mkfs.ext4 -F "$DEVICE"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Volume $DEVICE is already formatted, skipping format step"
fi

# Mount the volume
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Mounting $DEVICE to $MOUNT_POINT..."
if ! mountpoint -q "$MOUNT_POINT"; then
  sudo mount "$DEVICE" "$MOUNT_POINT"
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Volume mounted successfully"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Volume already mounted at $MOUNT_POINT"
fi

# Add to fstab for persistent mounting (if not already there)
if ! grep -q "$DEVICE" /etc/fstab; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Adding $DEVICE to /etc/fstab..."
  echo "$DEVICE  $MOUNT_POINT  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Volume already present in /etc/fstab"
fi

# Create server directory structure
MINECRAFT_SERVER_DIR="$MOUNT_POINT/minecraft/server"
if [ ! -d "$MINECRAFT_SERVER_DIR" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating server directory: $MINECRAFT_SERVER_DIR"
  mkdir -p "$MINECRAFT_SERVER_DIR"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Server directory already exists"
fi

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Volume configured on $DEVICE"


# Create minecraft user and directories
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Setting up Minecraft server service..."

# Create minecraft user if it doesn't exist
# Using fixed UID 1003
if ! id "minecraft" &>/dev/null; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating minecraft user with fixed UID 1003..."
  sudo useradd -u 1003 -m -d $MOUNT_POINT/minecraft/server -s /usr/sbin/nologin minecraft
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Minecraft user already exists (UID: $(id -u minecraft))"
fi

# Ensure permissions are correct
sudo chown -R minecraft:minecraft "$MINECRAFT_SERVER_DIR"
sudo chmod 755 "$MINECRAFT_SERVER_DIR"

echo ""

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing Java 25 LTS..."

wait_for_apt

# Install Java 25 from Eclipse Temurin
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Downloading Java 25 LTS from Eclipse Temurin..."
cd /tmp

# Detect architecture (ARM64 or x86_64)
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
  JAVA_URL="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.1+8/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.1_8.tar.gz"
else
  JAVA_URL="https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.1+8/OpenJDK25U-jdk_x64_linux_hotspot_25.0.1_8.tar.gz"
fi

wget -q "$JAVA_URL" -O java25.tar.gz
sudo tar -xzf java25.tar.gz -C /opt/
sudo ln -sf /opt/jdk-25.0.1+8/bin/java /usr/bin/java
sudo ln -sf /opt/jdk-25.0.1+8/bin/javac /usr/bin/javac

# Verify installation
JAVA_VERSION=$(java -version 2>&1)
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Java 25 installed successfully:"
echo "$JAVA_VERSION"
cd -

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Setting up Minecraft server..."

# Download and setup initial Minecraft server jar
MINECRAFT_SERVER_DIR="$MOUNT_POINT/minecraft/server"

# Install jq if not present (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing jq for JSON parsing..."
  wait_for_apt
  apt_install jq
fi

# Check if server.jar already exists
if [ -f "$MINECRAFT_SERVER_DIR/server.jar" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Minecraft server.jar already exists, checking for updates..."
  CURRENT_VERSION=$(java -jar "$MINECRAFT_SERVER_DIR/server.jar" --version 2>&1 | grep -oP '(?<=version )\S+' || echo "unknown")
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Current version: $CURRENT_VERSION"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") No server.jar found, downloading latest Minecraft server..."
  CURRENT_VERSION="none"
fi

# Get latest version from Minecraft.net
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Fetching latest version from Minecraft.net..."
LATEST_VERSION_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"
LATEST_VERSION=$(curl -s "$LATEST_VERSION_URL" | jq -r '.latest.release')
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Latest available version: $LATEST_VERSION"

# Compare versions and download if needed
if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Version mismatch or first-time setup detected."
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Updating Minecraft server from $CURRENT_VERSION to $LATEST_VERSION..."
  
  # Backup old version if it exists
  if [ -f "$MINECRAFT_SERVER_DIR/server.jar" ]; then
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Backing up old server.jar..."
    sudo -u minecraft mv "$MINECRAFT_SERVER_DIR/server.jar" "$MINECRAFT_SERVER_DIR/server-$CURRENT_VERSION.jar"
  fi
  
  # Get download URL for latest version
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Resolving download URL for version $LATEST_VERSION..."
  DOWNLOAD_URL=$(curl -s "$LATEST_VERSION_URL" | jq -r --arg LATEST_VERSION "$LATEST_VERSION" '.versions[] | select(.id == $LATEST_VERSION) | .url')
  SERVER_JAR_URL=$(curl -s "$DOWNLOAD_URL" | jq -r '.downloads.server.url')
  
  if [ -z "$SERVER_JAR_URL" ] || [ "$SERVER_JAR_URL" = "null" ]; then
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ERROR: Could not resolve server.jar download URL"
    exit 1
  fi
  
  # Download latest server jar
  echo "Downloading server.jar from $SERVER_JAR_URL..."
  if sudo -u minecraft wget -q -O "$MINECRAFT_SERVER_DIR/server.jar" "$SERVER_JAR_URL"; then
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Successfully downloaded Minecraft server.jar version $LATEST_VERSION"
  else
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ERROR: Failed to download server.jar"
    exit 1
  fi
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Minecraft server is already on the latest version: $LATEST_VERSION"
fi

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Accepting the Minecraft EULA..."
if [ ! -f "$MINECRAFT_SERVER_DIR/eula.txt" ]; then
  sudo -u minecraft bash -c "echo 'eula=true' > $MINECRAFT_SERVER_DIR/eula.txt"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") eula.txt already exists, skipping"
fi

# Detect which jar to use (fabric-server or vanilla server.jar)
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Detecting server jar type..."
JAR_FILE="server.jar"  # Default to vanilla server.jar

# Look for minecraft fabric-server jar files
FABRIC_JAR=$(ls "$MINECRAFT_SERVER_DIR"/fabric-server*.jar 2>/dev/null | head -1)
if [ -n "$FABRIC_JAR" ]; then
  JAR_FILE=$(basename "$FABRIC_JAR")
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Detected Fabric server: $JAR_FILE"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") No Fabric server found, using vanilla server.jar"
fi

# Create systemd service file
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating systemd service file..."
sudo tee /etc/systemd/system/minecraft.service > /dev/null <<EOF
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=$MOUNT_POINT/minecraft/server
ExecStart=/usr/bin/java -Djava.net.preferIPv4Stack=true -Xms4G -Xmx6G -jar $JAR_FILE nogui
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon to pick up new service
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the service to start on boot
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Enabling minecraft service..."
sudo systemctl enable minecraft.service

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Minecraft systemd service created successfully"
echo ""

# Start the Minecraft service automatically
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Starting Minecraft service..."
sudo systemctl start minecraft.service

# Check service status
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Service status:"
sudo systemctl status minecraft.service

# Install and Configure nginx (webserver daemon and required for certbot automation)
echo ""
echo "Installing nginx Web Server"

wait_for_apt
apt_install nginx

# Create document root for nginx on persistent volume
NGINX_ROOT="$MOUNT_POINT/nginx/www"
if [ ! -d "$NGINX_ROOT" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating nginx document root: $NGINX_ROOT"
  sudo mkdir -p "$NGINX_ROOT"
  sudo chmod 755 "$NGINX_ROOT"
fi

# Create a default index page
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating default nginx index page..."
sudo tee "$NGINX_ROOT/index.html" > /dev/null <<'NGINX_HTML'
<!DOCTYPE html>
<html>
<head>
  <title>Minecraft Server</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background-color: #1a1a1a; color: #fff; }
    h1 { color: #00ff00; }
    .server-info { background-color: #2a2a2a; padding: 20px; border-radius: 5px; }
  </style>
</head>
<body>
  <h1>Minecraft Server</h1>
  <div class="server-info">
    <p><strong>Server Status:</strong> Running</p>
    <p><strong>Port:</strong> 25565</p>
    <p><strong>Address:</strong> Check your Minecraft server list for the IP</p>
  </div>
</body>
</html>
NGINX_HTML

# Enable and start nginx
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Enabling nginx service..."
sudo systemctl enable nginx.service
sudo systemctl start nginx.service

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ nginx web server installed and started"

# Install certbot nginx plugin
echo ""
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing certbot nginx plugin..."
apt_install python3-certbot-nginx

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ certbot nginx plugin installed"
echo ""

# Configure UFW Firewall (before HTTPS setup so port 80 is open for validation)
echo "Configuring UFW Firewall..."
wait_for_apt
apt_install ufw

apt-get remove -y iptables-persistent 2>&1||true
sudo iptables -F&&sudo iptables -X
sudo iptables -P INPUT ACCEPT&&sudo iptables -P OUTPUT ACCEPT
ufw --force enable
ufw default deny incoming&&ufw default allow outgoing
ufw allow 22/tcp&&ufw allow 25565/tcp&&ufw allow 25565/udp
ufw allow 80/tcp&&ufw allow 443/tcp&&ufw allow 8100/tcp

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Firewall configured"

# Install certbot

# Persist certbot configuration across image refreshes
# Symlink /etc/letsencrypt to persistent volume so certificates survive rebuilds
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Setting up persistent certificate storage..."

LETSENCRYPT_PERSISTENT="$MOUNT_POINT/letsencrypt"

# Create letsencrypt directory on persistent volume (if it doesn't exist)
if [ ! -d "$LETSENCRYPT_PERSISTENT" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating persistent letsencrypt directory: $LETSENCRYPT_PERSISTENT"
  sudo mkdir -p "$LETSENCRYPT_PERSISTENT"
  sudo chmod 700 "$LETSENCRYPT_PERSISTENT"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Persistent letsencrypt directory already exists"
fi

# Remove default /etc/letsencrypt if it exists (so we can symlink)
if [ -d "/etc/letsencrypt" ] && [ ! -L "/etc/letsencrypt" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Removing default /etc/letsencrypt directory"
  sudo rm -rf /etc/letsencrypt
fi

# Create symlink if it doesn't already exist
if [ ! -L "/etc/letsencrypt" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating symlink: /etc/letsencrypt → $LETSENCRYPT_PERSISTENT"
  sudo ln -s "$LETSENCRYPT_PERSISTENT" /etc/letsencrypt
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Symlink created"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Symlink /etc/letsencrypt already exists"
fi

wait_for_apt
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing certbot..."
apt_install certbot

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ certbot installed successfully"

# Configure certbot renewal hooks
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Configuring certbot renewal hooks..."
sudo mkdir -p /etc/letsencrypt/renewal-hooks/post

# Enable and verify certbot renewal timer
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Enabling certbot renewal timer..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Check timer status
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Certbot renewal timer status:"
sudo systemctl status certbot.timer --no-pager || echo "Timer may not be available yet"

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Certbot setup complete"

# Automatic HTTPS certificate configuration (if domain and email provided)
# NOW THAT NGINX, PLUGIN, AND FIREWALL ARE CONFIGURED, WE CAN RUN CERTBOT
# Multi-domain support: comma-separated domains in certbot_domain_name (e.g., "example.com,www.example.com")

if [ -n "${certbot_domain_name}" ] && [ -n "${certbot_email}" ]; then
  # Extract primary domain (first domain in list) for certificate path
  PRIMARY_DOMAIN=$(echo "${certbot_domain_name}" | cut -d',' -f1 | xargs)
  
  # Check if certificates already exist
  CERT_PATH="/etc/letsencrypt/live/$PRIMARY_DOMAIN"
  
  if [ ! -d "$CERT_PATH" ]; then
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Automatic HTTPS Setup Detected"
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Domains: ${certbot_domain_name}"
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Email: ${certbot_email}"
    echo ""
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Generating SSL certificate with certbot..."
    
    # Build certbot command with all domains
    # Replace commas and spaces with individual -d flags
    CERTBOT_CMD="sudo certbot --nginx -m \"${certbot_email}\" --agree-tos --no-eff-email --non-interactive"
    for domain in $(echo "${certbot_domain_name}" | tr ',' '\n'); do
      domain=$(echo "$domain" | xargs)
      CERTBOT_CMD="$CERTBOT_CMD -d \"$domain\""
    done
    
    # Run certbot with all domain arguments
    eval "$CERTBOT_CMD" 2>&1
    
    if [ $? -eq 0 ]; then
      echo ""
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ HTTPS Certificate Generated Successfully!"
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Your domains are now secured with SSL/TLS"
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Domains: ${certbot_domain_name}"
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Primary access: https://$PRIMARY_DOMAIN"
      echo ""
    else
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ⚠ Certificate generation failed - check domains and firewall"
    fi
  else
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Certificates already exist for $PRIMARY_DOMAIN"
  fi
fi

# Recreate nginx config symlinks for persistent configs
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Setting up persistent nginx configurations..."
sudo mkdir -p /mnt/persistent-data/nginx/configs

# Configure nginx SSL redirect (create default if not already persisted)
# Use primary domain from certbot_domain_name if provided, otherwise localhost
CERT_DOMAIN=$(echo "${certbot_domain_name}" | cut -d',' -f1 | xargs)
[ -n "$CERT_DOMAIN" ] && CERT_PATH="/etc/letsencrypt/live/$CERT_DOMAIN" || CERT_PATH="/etc/letsencrypt/live/localhost"

if [ ! -f /mnt/persistent-data/nginx/configs/minecraft-ssl ]; then
  sudo tee /mnt/persistent-data/nginx/configs/minecraft-ssl >/dev/null <<NGINX_SSL
server {
    listen 80;
    listen [::]:80;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    ssl_certificate $CERT_PATH/fullchain.pem;
    ssl_certificate_key $CERT_PATH/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    add_header Strict-Transport-Security "max-age=31536000" always;
    root /mnt/persistent-data/nginx/www;
    # Main site
    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\. {
        deny all;
    }

}

NGINX_SSL
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ Default minecraft-ssl config created"
fi
sudo ln -sf /mnt/persistent-data/nginx/configs/minecraft-ssl /etc/nginx/sites-available/minecraft-ssl
sudo ln -sf /mnt/persistent-data/nginx/configs/minecraft-ssl /etc/nginx/sites-enabled/minecraft-ssl
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t >/dev/null 2>&1&&sudo systemctl reload nginx
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ nginx configured and reloaded"

############################
# System Updates & Security Patches
############################
echo ""
echo "Installing System Updates & Security Patches"

# Update package cache
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Updating package cache..."
wait_for_apt
apt-get update 2>&1

# Upgrade all packages to latest versions (security patches included)
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing all available package updates..."
apt-get upgrade -y 2>&1

# Distribution upgrade (handles package removals/replacements if needed)
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing distribution updates..."
apt-get dist-upgrade -y 2>&1

# Auto-remove unnecessary packages and clean apt cache
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Cleaning up unnecessary packages..."
apt-get autoremove -y 2>&1
apt-get autoclean 2>&1

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ System updates and security patches installed successfully"
echo ""

############################
# Final Status
############################
echo "Minecraft Server Deployment Complete!"
echo "✓ Deployment Complete - Admin: ${admin_username}"

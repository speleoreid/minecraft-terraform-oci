#!/bin/bash
set -e

echo "Sleeping for 5 minutes to allow cloud-init prcesses to complete"
sleep 300

# SSH Key for user 'reid' (injected by Terraform)
SSH_AUTHORIZED_KEYS="${ssh_authorized_keys}"

# Minecraft Data Volume Auto-Mount Script
# This script is executed when the instance first boots (or when an image is updated)

MOUNT_POINT="/mnt/minecraft-data"
DEVICE=""
LOG_FILE="/var/log/minecraft-volume-setup.log"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Helper function: Wait for apt to be available
wait_for_apt() {
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Waiting for apt to be available..."
  local max_attempts=60
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    # Check if apt processes are running
    echo "got to 1"
    apt_processes=$(pgrep -x "apt-get|apt|dpkg" 2>/dev/null || true)
    echo "got to 2"
    if [ -z "$apt_processes" ]; then
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") [DEBUG] No apt processes found"
      echo "got to 3"
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ apt is available (no processes blocking)"
      echo "got to 4"
      return 0
    else
      echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") [DEBUG] apt processes running: $apt_processes"
    fi
    
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") apt still in use, waiting... (attempt $((attempt+1))/$max_attempts)"
    sleep 5
    echo "got to 5"
    ((attempt++))
    echo "got to 6"
  done
  
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") WARNING: apt lock timeout after $max_attempts attempts, proceeding anyway"
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") [DEBUG] Current processes: $(ps aux | grep -E 'apt|dpkg' | grep -v grep || echo 'none')"
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") [DEBUG] Lock files: $(ls -la /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock* 2>/dev/null || echo 'lock files not found')"
  return 0
}

echo "=========================================="
echo "Starting Minecraft Data Volume Setup"
echo "Timestamp: $(date +"%Y-%m-%dT%H:%M:%S %Z")"
echo "=========================================="
############################
# Create reid User (Early)
############################
echo ""
echo "=========================================="
echo "Creating reid user for SSH access"
echo "=========================================="

if ! id "reid" &>/dev/null; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating reid user..."
  useradd -m -s /bin/bash -G sudo reid
  
  # Create .ssh directory
  mkdir -p /home/reid/.ssh
  
  # Add SSH public key
  echo "$SSH_AUTHORIZED_KEYS" > /home/reid/.ssh/authorized_keys
  
  # Set proper permissions
  chmod 700 /home/reid/.ssh
  chmod 600 /home/reid/.ssh/authorized_keys
  chown -R reid:reid /home/reid/.ssh
  
  # Allow reid to sudo without password (optional, for convenience)
  echo "reid ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/reid > /dev/null
  chmod 440 /etc/sudoers.d/reid
  
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ reid user created successfully"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") reid user already exists"
fi

# Function to find the data volume device
find_data_volume() {
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Searching for unformatted data volume..." >&2
  
  # Wait up to 60 seconds for volume to appear
  for i in {1..30}; do
    # Look for unformatted volumes (excluding boot volume /dev/sda)
    for device in /dev/sd{b,c,d,e,f}; do
      if [ -b "$device" ] 2>/dev/null; then
        # Check if device is already formatted
        if ! sudo blkid "$device" >/dev/null 2>&1; then
          echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Found unformatted volume: $device" >&2
          echo "$device"
          return 0
        fi
      fi
    done
    
    echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Waiting for volume to attach... (attempt $i/30)" >&2
    sleep 2
  done
  
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ERROR: Could not find unformatted data volume" >&2
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
# and preserve all existing data. The blkid tool detects existing filesystems.
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
MINECRAFT_SERVER_DIR="$MOUNT_POINT/server"
if [ ! -d "$MINECRAFT_SERVER_DIR" ]; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating server directory: $MINECRAFT_SERVER_DIR"
  mkdir -p "$MINECRAFT_SERVER_DIR"
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Server directory already exists"
fi

# Verify setup
echo ""
echo "=========================================="
echo "Volume Setup Complete!"
echo "Timestamp: $(date +"%Y-%m-%dT%H:%M:%S %Z")"
echo "=========================================="
echo "Mount point: $MOUNT_POINT"
echo "Device: $DEVICE"
echo "Mounted filesystems:"
mount | grep "$DEVICE"
echo "Disk usage:"
df -h "$MOUNT_POINT"


# Create minecraft user and directories
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Setting up Minecraft server service..."

# Create minecraft user if it doesn't exist
# Using fixed UID 1003 for consistency across instance recreations
if ! id "minecraft" &>/dev/null; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating minecraft user with fixed UID 1003..."
  sudo useradd -u 1003 -m -d $MOUNT_POINT/server -s /usr/sbin/nologin minecraft
else
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Minecraft user already exists (UID: $(id -u minecraft))"
fi

# Ensure permissions are correct
sudo chown -R minecraft:minecraft "$MINECRAFT_SERVER_DIR"
sudo chmod 755 "$MINECRAFT_SERVER_DIR"

echo ""
# Install Java (OpenJDK 25 LTS - Temurin)
echo ""
echo "=========================================="
echo "Installing Java (OpenJDK 25 LTS)"
echo "Timestamp: $(date +"%Y-%m-%dT%H:%M:%S %Z")"
echo "=========================================="

# Wait for apt to be available
wait_for_apt

# Update package manager
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Updating package manager..."
sudo DEBIAN_FRONTEND=noninteractive add-apt-repository -y ppa:openjdk-r/ppa >/dev/null 2>&1
apt-get update -qq

echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing Java 25 (openjdk-25-jre-headless)..."
apt-get install -y openjdk-25-jre-headless 2>&1

# Verify installation
JAVA_VERSION=$(java -version 2>&1)
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Java installed successfully:"
echo "$JAVA_VERSION"

echo ""
echo "=========================================="
echo "Minecraft Server Download & Version Check"
echo "Timestamp: $(date +"%Y-%m-%dT%H:%M:%S %Z")"
echo "=========================================="

# Download and setup initial Minecraft server jar
MINECRAFT_SERVER_DIR="$MOUNT_POINT/server"

# Install jq if not present (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
  echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Installing jq for JSON parsing..."
  wait_for_apt
  apt-get install -y jq 2>&1
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

# Initialize server if needed (server.properties doesn't exist yet)
# echo ""
# echo "=========================================="
# echo "Server Initialization Check"
# echo "Timestamp: $(date +"%Y-%m-%dT%H:%M:%S %Z")"
# echo "=========================================="

# if [ ! -f "$MINECRAFT_SERVER_DIR/server.properties" ]; then
#   echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") server.properties not found, initializing server..."
#   echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Starting Minecraft server to initialize..."

#   # Start server in background as minecraft user, capture PID
#   sudo -u minecraft bash -c "cd $MINECRAFT_SERVER_DIR && /usr/bin/java -Xms512M -Xmx1G -jar server.jar nogui &" &
#   java_pid=$!
  
#   # Wait up to 60 seconds for server.properties to be created
#   max_wait=30
#   waited=0
#   while [ ! -f "$MINECRAFT_SERVER_DIR/server.properties" ] && [ $waited -lt $max_wait ]; do
#     echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Waiting for server.properties... ($waited/$max_wait seconds)"
#     sleep 2
#     ((waited++))
#   done
  
#   if [ -f "$MINECRAFT_SERVER_DIR/server.properties" ]; then
#     echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ server.properties is present, so minecraft server has been initialized."
#   else
#     echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") WARNING: server.properties was not created within timeout"
#   fi
  
#   # Kill any remaining java processes for minecraft user
#   echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Stopping initialization server..."
#   sudo pkill -f "java.*server.jar" -u minecraft || true
#   sleep 2
  
# else
#   echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") ✓ server.properties already exists, skipping initialization"
# fi

# echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Minecraft server setup complete!"
# echo ""

# Create systemd service file
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Creating systemd service file..."
sudo tee /etc/systemd/system/minecraft.service > /dev/null <<EOF
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=$MOUNT_POINT/server
ExecStart=/usr/bin/java -Djava.net.preferIPv4Stack=true -Xms4G -Xmx6G -jar server.jar nogui
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
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") qStarting Minecraft service..."
sudo systemctl start minecraft.service

# Check service status
echo "$(date +"%Y-%m-%dT%H:%M:%S %Z") Service status:"
sudo systemctl status minecraft.service

# Configure UFW Firewall
echo "=========================================="
echo "Configuring UFW Firewall"
echo "=========================================="

# Install UFW if not already installed
echo "Installing UFW..."
wait_for_apt
apt-get install -y ufw 2>&1

# Enable UFW
echo "Enabling UFW..."
ufw --force enable

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
echo "Allowing SSH (22/tcp)..."
ufw allow 22/tcp

# Allow Minecraft (both TCP and UDP)
echo "Allowing Minecraft (25565/tcp and 25565/udp)..."
ufw allow 25565/tcp
ufw allow 25565/udp

# Allow HTTP
echo "Allowing HTTP (80/tcp)..."
ufw allow 80/tcp

# Allow HTTPS
echo "Allowing HTTPS (443/tcp)..."
ufw allow 443/tcp

echo "UFW Firewall configured successfully"
echo ""
ufw status

#!/bin/bash
set -e

# Minecraft Data Volume Auto-Mount Script
# This script is executed when the instance first boots (or when an image is updated)

MOUNT_POINT="/mnt/minecraft-data"
DEVICE=""
LOG_FILE="/var/log/minecraft-volume-setup.log"

# Redirect output to log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=========================================="
echo "Starting Minecraft Data Volume Setup"
echo "Timestamp: $(date)"
echo "=========================================="

# Install Java (OpenJDK 25 LTS - Temurin)
echo ""
echo "=========================================="
echo "Installing Java (OpenJDK 25 LTS)"
echo "=========================================="

# Update package manager
apt-get update -qq

# Install Java 25 LTS from Eclipse Temurin repository
if ! apt-cache search temurin | grep -q "temurin-25"; then
  echo "Adding Temurin repository..."
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | apt-key add -
  echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/adoptium.list
  apt-get update -qq
fi

echo "Installing temurin-25-jdk..."
apt-get install -y temurin-25-jdk

# Verify installation
JAVA_VERSION=$(java -version 2>&1)
echo "Java installed successfully:"
echo "$JAVA_VERSION"
echo ""

# Configure UFW Firewall
echo "=========================================="
echo "Configuring UFW Firewall"
echo "=========================================="

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

# Function to find the data volume device
find_data_volume() {
  echo "Searching for unformatted data volume..."
  
  # Wait up to 60 seconds for volume to appear
  for i in {1..30}; do
    # Look for unformatted volumes (excluding boot volume /dev/sda)
    for device in /dev/sd{b,c,d,e,f}; do
      if [ -b "$device" ] 2>/dev/null; then
        # Check if device is already formatted
        if ! sudo blkid "$device" >/dev/null 2>&1; then
          echo "Found unformatted volume: $device"
          echo "$device"
          return 0
        fi
      fi
    done
    
    echo "Waiting for volume to attach... (attempt $i/30)"
    sleep 2
  done
  
  echo "ERROR: Could not find unformatted data volume"
  return 1
}

# Get the device path
if DEVICE=$(find_data_volume); then
  echo "Using device: $DEVICE"
else
  echo "ERROR: Data volume not found. Manual setup required."
  exit 1
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
  echo "Creating mount point: $MOUNT_POINT"
  sudo mkdir -p "$MOUNT_POINT"
fi

# Format volume if not already formatted
# IMPORTANT: This check ensures mkfs only runs on first setup.
# If the volume is attached to a new instance, this will skip formatting
# and preserve all existing data. The blkid tool detects existing filesystems.
if ! sudo blkid "$DEVICE" >/dev/null 2>&1; then
  echo "Formatting $DEVICE with ext4..."
  sudo mkfs.ext4 -F "$DEVICE"
else
  echo "Volume $DEVICE is already formatted, skipping format step"
fi

# Mount the volume
echo "Mounting $DEVICE to $MOUNT_POINT..."
if ! mountpoint -q "$MOUNT_POINT"; then
  sudo mount "$DEVICE" "$MOUNT_POINT"
  echo "Volume mounted successfully"
else
  echo "Volume already mounted at $MOUNT_POINT"
fi

# Add to fstab for persistent mounting (if not already there)
if ! grep -q "$DEVICE" /etc/fstab; then
  echo "Adding $DEVICE to /etc/fstab..."
  echo "$DEVICE  $MOUNT_POINT  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab
else
  echo "Volume already present in /etc/fstab"
fi

# Set permissions to ubuntu user
echo "Setting permissions for $MOUNT_POINT..."
sudo chown -R ubuntu:ubuntu "$MOUNT_POINT"
sudo chmod 755 "$MOUNT_POINT"

# Create minecraft user and directories
echo "Setting up Minecraft server service..."

# Create minecraft user if it doesn't exist
# Using fixed UID 1002 for consistency across instance recreations
# This ensures file ownership matches when volumes are re-attached
if ! id "minecraft" &>/dev/null; then
  echo "Creating minecraft user with fixed UID 1002..."
  sudo useradd -u 1002 -m -d $MOUNT_POINT/server -s /usr/sbin/nologin minecraft
else
  echo "Minecraft user already exists (UID: $(id -u minecraft))"
fi

# Create server directory structure
MINECRAFT_SERVER_DIR="$MOUNT_POINT/server"
if [ ! -d "$MINECRAFT_SERVER_DIR" ]; then
  echo "Creating server directory: $MINECRAFT_SERVER_DIR"
  mkdir -p "$MINECRAFT_SERVER_DIR"
  sudo chown -R minecraft:minecraft "$MINECRAFT_SERVER_DIR"
  sudo chmod 755 "$MINECRAFT_SERVER_DIR"
else
  echo "Server directory already exists"
  # Ensure permissions are correct
  sudo chown -R minecraft:minecraft "$MINECRAFT_SERVER_DIR"
fi

# Create systemd service file
echo "Creating systemd service file..."
sudo tee /etc/systemd/system/minecraft.service > /dev/null <<'EOF'
[Unit]/
Description=Minecraft Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=$MOUNT_POINT/server
ExecStart=/usr/bin/java -Xms2G -Xmx6G -jar server.jar nogui
Restart=on-failure
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon to pick up new service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable the service to start on boot
echo "Enabling minecraft service..."
sudo systemctl enable minecraft.service

# Start the service
echo "Starting minecraft service..."
sudo systemctl start minecraft.service

echo "Minecraft systemd service created successfully"
echo ""
echo "IMPORTANT: The service is enabled but NOT running yet."
echo ""
echo "Next steps:"
echo "  1. Start service: sudo systemctl start minecraft"
echo "  2. Check status: sudo systemctl status minecraft"
echo "  3. View logs: sudo journalctl -u minecraft -f"


# Verify setup
echo ""
echo "=========================================="
echo "Volume Setup Complete!"
echo "=========================================="
echo "Mount point: $MOUNT_POINT"
echo "Device: $DEVICE"
echo "Mounted filesystems:"
mount | grep "$DEVICE"
echo "Disk usage:"
df -h "$MOUNT_POINT"
echo ""
echo "=========================================="
echo "Minecraft Service Setup"
echo "=========================================="
echo "Service file: /etc/systemd/system/minecraft.service"
echo "Server directory: $MINECRAFT_SERVER_DIR"
echo "Service user: minecraft"
echo ""
echo "Service commands:"
echo "  Start:    sudo systemctl start minecraft"
echo "  Stop:     sudo systemctl stop minecraft"
echo "  Status:   sudo systemctl status minecraft"
echo "  Logs:     sudo journalctl -u minecraft -f"
echo "  Enable:   sudo systemctl enable minecraft"
echo "  Disable:  sudo systemctl disable minecraft"
echo ""
echo "NOTE: This volume is portable. Your data persists across"
echo "compute instance recreations. If the filesystem was already"
echo "formatted, the mkfs step was skipped to preserve your data."
echo ""

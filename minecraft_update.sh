#!/bin/bash

# Set variables
MINECRAFT_SERVER_DIR="/opt/minecraft/server"
CURRENT_VERSION=$(java -jar "$MINECRAFT_SERVER_DIR/server.jar" --version | grep "version" | awk '{print $NF}')
LATEST_VERSION_URL="https://launchermeta.mojang.com/mc/game/version_manifest.json"

# Get latest version from Minecraft.net
LATEST_VERSION=$(curl -s $LATEST_VERSION_URL | jq -r '.latest.release')

# Compare versions
if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
    echo "Newer version found: $LATEST_VERSION"
    # Rename old server.jar
    mv "$MINECRAFT_SERVER_DIR/server.jar" "$MINECRAFT_SERVER_DIR/server-$CURRENT_VERSION.jar"

    # Download latest server.jar
    DOWNLOAD_URL=$(curl -s $LATEST_VERSION_URL | jq -r --arg LATEST_VERSION "$LATEST_VERSION" '.versions[] | select(.id == $LATEST_VERSION) | .url')
    SERVER_JAR_URL=$(curl -s $DOWNLOAD_URL | jq -r '.downloads.server.url')

    wget -O "$MINECRAFT_SERVER_DIR/server.jar" "$SERVER_JAR_URL"

    echo "Minecraft server updated to version $LATEST_VERSION"
else
    echo "You are already running the latest version: $CURRENT_VERSION"
fi
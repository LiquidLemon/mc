#!/bin/bash
set -e

echo "=========================================="
echo "  Fabric Minecraft Server"
echo "=========================================="
echo ""

# Display configuration
echo "Configuration:"
echo "  Memory: ${MEMORY_MIN} - ${MEMORY_MAX}"
echo "  Working directory: $(pwd)"
echo "  User: $(whoami)"
echo ""

# Check if server jar exists
if [ ! -f "fabric-server-launch.jar" ]; then
    echo "ERROR: fabric-server-launch.jar not found!"
    exit 1
fi

# List installed mods
echo "Installed mods:"
if [ -d "mods" ] && [ "$(ls -A mods/*.jar 2>/dev/null)" ]; then
    ls -1 mods/*.jar | wc -l | xargs echo "  Total mods:"
    ls -1 mods/*.jar | sed 's/.*\//  - /'
else
    echo "  No mods installed"
fi
echo ""

# Check for server.properties and provide RCON info
if [ ! -f "server.properties" ]; then
    echo "No server.properties found - will be generated on first startup"
    echo ""
    echo "To enable RCON for remote management, add these to server.properties:"
    echo "  enable-rcon=true"
    echo "  rcon.port=25575"
    echo "  rcon.password=YOUR_SECURE_PASSWORD"
else
    # Check if RCON is enabled
    if grep -q "^enable-rcon=true" server.properties 2>/dev/null; then
        echo "RCON is enabled for remote management"
        echo "  Use: rcon-cli <command>"
    fi
fi
echo ""

echo "Starting Minecraft server..."
echo "=========================================="
echo ""

# Start the server with optimized JVM flags
# Using Aikar's flags for optimal performance
exec java \
    -Xms${MEMORY_MIN} \
    -Xmx${MEMORY_MAX} \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    ${JVM_OPTS} \
    -jar fabric-server-launch.jar \
    nogui

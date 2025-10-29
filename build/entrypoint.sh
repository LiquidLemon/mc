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

# Accept server resource pack prompt if using one (optional)
# This prevents server from waiting for input on first startup
if [ ! -f "server.properties" ]; then
    echo "No server.properties found - will be generated on first startup"
fi

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

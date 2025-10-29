# Fabric Minecraft Server Docker Image
# This image contains the Fabric server and mods baked in

# Build arguments for versions
ARG MINECRAFT_VERSION=1.21.10
ARG FABRIC_LOADER_VERSION=0.17.3
ARG JAVA_VERSION=21
ARG FABRIC_INSTALLER_VERSION=1.1.0

# Stage 1: Download Fabric server
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy AS fabric-downloader

ARG MINECRAFT_VERSION
ARG FABRIC_LOADER_VERSION
ARG FABRIC_INSTALLER_VERSION

WORKDIR /build

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Download Fabric server launcher
RUN curl -L -o fabric-server-launch.jar \
    "https://meta.fabricmc.net/v2/versions/loader/${MINECRAFT_VERSION}/${FABRIC_LOADER_VERSION}/${FABRIC_INSTALLER_VERSION}/server/jar"

# Stage 2: Download mods
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy AS mod-downloader

WORKDIR /mods

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy mod list and download script
COPY build/mods.txt ./
COPY build/download-mods.sh ./

# Download all mods
RUN chmod +x download-mods.sh && \
    ./download-mods.sh && \
    ls -lh /mods/*.jar || echo "No mods downloaded"

# Stage 3: Final runtime image
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy

ARG MINECRAFT_VERSION
ARG FABRIC_LOADER_VERSION

LABEL org.opencontainers.image.title="Fabric Minecraft Server"
LABEL org.opencontainers.image.description="Self-hosted Fabric Minecraft server with pre-installed mods"
LABEL org.opencontainers.image.version="${MINECRAFT_VERSION}-fabric-${FABRIC_LOADER_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/YOUR_REPO"

# Create non-root user
RUN groupadd -r -g 1000 minecraft && \
    useradd -r -u 1000 -g minecraft minecraft

WORKDIR /server

# Copy Fabric server from downloader stage
COPY --from=fabric-downloader --chown=minecraft:minecraft /build/fabric-server-launch.jar ./

# Create mods directory and copy mods
RUN mkdir -p mods
COPY --from=mod-downloader --chown=minecraft:minecraft /mods/*.jar ./mods/

# Accept EULA
RUN echo "eula=true" > eula.txt && \
    chown minecraft:minecraft eula.txt

# Copy entrypoint script
COPY --chown=minecraft:minecraft build/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create directories for runtime data
RUN mkdir -p /server/world /server/logs /server/config && \
    chown -R minecraft:minecraft /server

# Switch to non-root user
USER minecraft

# Expose Minecraft server port
EXPOSE 25565

# Environment variables for configuration
ENV MEMORY_MAX=4G \
    MEMORY_MIN=4G \
    JVM_OPTS=""

ENTRYPOINT ["/entrypoint.sh"]

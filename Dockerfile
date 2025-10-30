# Fabric Minecraft Server Docker Image
# This image contains the Fabric server and mods baked in

# Build arguments for versions
ARG MINECRAFT_VERSION=1.21.9
ARG FABRIC_LOADER_VERSION=0.17.3
ARG JAVA_VERSION=21
ARG FABRIC_INSTALLER_VERSION=1.1.0

# Stage 1: Install Fabric server using CLI installer
FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy AS fabric-builder

ARG MINECRAFT_VERSION
ARG FABRIC_LOADER_VERSION
ARG FABRIC_INSTALLER_VERSION

WORKDIR /server

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Download Fabric installer
RUN curl -L -o fabric-installer.jar \
    "https://maven.fabricmc.net/net/fabricmc/fabric-installer/${FABRIC_INSTALLER_VERSION}/fabric-installer-${FABRIC_INSTALLER_VERSION}.jar"

# Run Fabric installer to set up server (downloads server jar and libraries)
RUN java -jar fabric-installer.jar server \
    -mcversion ${MINECRAFT_VERSION} \
    -loader ${FABRIC_LOADER_VERSION} \
    -downloadMinecraft && \
    rm fabric-installer.jar && \
    ls -lh

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

# Install rcon-cli for remote server management
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    wget -O /tmp/rcon-cli.tar.gz https://github.com/itzg/rcon-cli/releases/download/1.6.7/rcon-cli_1.6.7_linux_amd64.tar.gz && \
    tar -xzf /tmp/rcon-cli.tar.gz -C /usr/local/bin && \
    chmod +x /usr/local/bin/rcon-cli && \
    rm /tmp/rcon-cli.tar.gz && \
    apt-get remove -y wget && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r -g 1000 minecraft && \
    useradd -r -u 1000 -g minecraft minecraft

WORKDIR /server

# Copy Fabric server files from builder stage (includes server.jar, libraries/, and fabric-server-launch.jar)
COPY --from=fabric-builder --chown=minecraft:minecraft /server ./

# Copy mods from mod-downloader stage
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

# Expose Minecraft server port and RCON port
EXPOSE 25565
EXPOSE 25575

# Environment variables for configuration
ENV MEMORY_MAX=4G \
    MEMORY_MIN=4G \
    JVM_OPTS=""

ENTRYPOINT ["/entrypoint.sh"]

# Fabric Minecraft Server Docker

Self-hosted Fabric Minecraft server with mods baked into the Docker image.

## Features

- Fabric server with configurable Minecraft and Fabric versions
- Mods embedded in the Docker image
- Automatic builds via GitHub Actions
- Published to GitHub Container Registry (GHCR)
- Optimized JVM flags for performance
- Non-root user for security
- Persistent world data via volumes

## Repository Structure

```
.
├── build/                    # Build files (only this directory is copied to Docker)
│   ├── mods.txt             # List of mod download URLs
│   ├── download-mods.sh     # Script to download mods during build
│   └── entrypoint.sh        # Server startup script
├── .github/
│   └── workflows/
│       └── build.yml        # GitHub Actions workflow
├── Dockerfile               # Multi-stage Docker build
├── docker-compose.yml       # Local development setup
├── .dockerignore            # Whitelist: only build/ is copied
└── README.md
```

All files needed for the Docker build are in the `build/` directory. This whitelist approach means you can add any files to the repository root without needing to update `.dockerignore`.

## Quick Start

### Using Pre-built Image

```bash
# Pull the latest image
docker pull ghcr.io/YOUR_USERNAME/YOUR_REPO:latest

# Create data directory
mkdir -p data/{world,logs,config}

# Run the server
docker run -d \
  --name minecraft \
  -p 25565:25565 \
  -v $(pwd)/data/world:/server/world \
  -v $(pwd)/data/logs:/server/logs \
  -v $(pwd)/data/config:/server/config \
  -e MEMORY_MAX=4G \
  -e MEMORY_MIN=4G \
  ghcr.io/YOUR_USERNAME/YOUR_REPO:latest
```

### Using Docker Compose

1. Clone this repository
2. Edit `docker-compose.yml` and update the image name
3. Run:

```bash
docker compose up -d
```

## Building the Image

### Prerequisites

- Docker
- Bash (for mod download script)

### Build Process

1. **Add mods to download**: Edit [build/mods.txt](build/mods.txt) and add direct download URLs for your desired mods (one per line)

   Example:
   ```
   https://cdn.modrinth.com/data/AANobbMI/versions/xyz/sodium-fabric-0.5.8+mc1.21.jar
   https://cdn.modrinth.com/data/gvQqBUqZ/versions/abc/lithium-fabric-mc1.21-0.12.7.jar
   ```

2. **Build the image**:

   ```bash
   docker build -t minecraft-server .
   ```

   With custom versions:
   ```bash
   docker build \
     --build-arg MINECRAFT_VERSION=1.21.3 \
     --build-arg FABRIC_LOADER_VERSION=0.16.9 \
     --build-arg JAVA_VERSION=21 \
     -t minecraft-server .
   ```

3. **Run locally**:

   ```bash
   docker run -d \
     --name minecraft \
     -p 25565:25565 \
     -v $(pwd)/data/world:/server/world \
     -v $(pwd)/data/logs:/server/logs \
     minecraft-server
   ```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MEMORY_MAX` | `4G` | Maximum JVM heap size |
| `MEMORY_MIN` | `4G` | Minimum JVM heap size |
| `JVM_OPTS` | _(empty)_ | Additional JVM options |

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `MINECRAFT_VERSION` | `1.21.3` | Minecraft version |
| `FABRIC_LOADER_VERSION` | `0.16.9` | Fabric loader version |
| `JAVA_VERSION` | `21` | Java version for base image |

### Volumes

Mount these directories to persist data:

- `/server/world` - Main overworld
- `/server/world_nether` - Nether dimension
- `/server/world_the_end` - End dimension
- `/server/logs` - Server logs
- `/server/config` - Mod and server configuration files

## Adding/Updating Mods

1. Edit [build/mods.txt](build/mods.txt) with new mod URLs
2. Rebuild the Docker image
3. Push to GHCR (automatic via GitHub Actions on push to main)
4. Pull the new image and restart your server

## Finding Mod Download URLs

### Modrinth
1. Go to [modrinth.com](https://modrinth.com)
2. Find your mod
3. Click on the version you want
4. Right-click the download button and copy the link

### CurseForge
1. Go to [curseforge.com](https://www.curseforge.com/minecraft/mc-mods)
2. Find your mod
3. Go to Files tab
4. Click the download icon and copy the direct link

### Important Notes
- Ensure mods are compatible with your Minecraft version
- Most Fabric mods require Fabric API
- Server-side mods are different from client-side mods
- Always verify mod sources are legitimate

## GitHub Actions Setup

The repository includes a GitHub Actions workflow that automatically builds and pushes images to GHCR.

### Setup Steps

1. **Enable GitHub Actions** in your repository settings

2. **Configure package permissions**:
   - Go to repository Settings → Actions → General
   - Under "Workflow permissions", select "Read and write permissions"

3. **Update image name** in [docker-compose.yml](docker-compose.yml):
   ```yaml
   image: ghcr.io/YOUR_USERNAME/YOUR_REPO:latest
   ```

4. **Push to main branch** - the workflow will automatically build and push the image

### Triggering Builds

- **Automatic**: Push to `main` branch
- **Manual**: Go to Actions tab → Build and Push Docker Image → Run workflow
- **Tagged releases**: Push a tag like `v1.0.0` for versioned images

## Server Management

### Viewing Logs

```bash
docker logs -f minecraft
```

### Accessing Console

```bash
docker attach minecraft
```

Press `Ctrl+P` then `Ctrl+Q` to detach without stopping the server.

### Stopping the Server

```bash
docker stop minecraft
```

### Starting the Server

```bash
docker start minecraft
```

### Updating to Latest Image

```bash
docker pull ghcr.io/YOUR_USERNAME/YOUR_REPO:latest
docker stop minecraft
docker rm minecraft
# Run docker run command again with same volumes
```

## Troubleshooting

### Server won't start

Check logs:
```bash
docker logs minecraft
```

Common issues:
- Insufficient memory allocation
- Port 25565 already in use
- Corrupted world data

### Out of memory errors

Increase memory allocation:
```bash
docker run -e MEMORY_MAX=8G -e MEMORY_MIN=8G ...
```

### Mods not loading

Verify mods are in the image:
```bash
docker run --rm minecraft-server ls -la /server/mods
```

### Performance issues

- Increase memory allocation
- Adjust JVM options via `JVM_OPTS` environment variable
- Check server resources with `docker stats minecraft`

## Advanced Configuration

### Custom server.properties

Mount a custom configuration file:

```bash
docker run -d \
  -v $(pwd)/server.properties:/server/server.properties:ro \
  ...
```

### Whitelist/Ops

Mount JSON files:

```bash
docker run -d \
  -v $(pwd)/whitelist.json:/server/whitelist.json \
  -v $(pwd)/ops.json:/server/ops.json \
  ...
```

### Custom JVM Flags

```bash
docker run -d \
  -e JVM_OPTS="-XX:+UseZGC -XX:+ZGenerational" \
  ...
```

## License

This repository structure is MIT licensed. Minecraft and Fabric are subject to their respective licenses:

- Minecraft EULA: https://account.mojang.com/documents/minecraft_eula
- Fabric: https://fabricmc.net/

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues related to:
- **This Docker setup**: Open an issue in this repository
- **Minecraft**: See [Minecraft Help](https://help.minecraft.net/)
- **Fabric**: See [Fabric Discord](https://discord.gg/v6v4pMv)
- **Specific mods**: Contact the mod authors

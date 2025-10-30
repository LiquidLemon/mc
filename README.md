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
│   ├── mods.txt             # List of mod download URLs (generated)
│   ├── download-mods.sh     # Script to download mods during build
│   └── entrypoint.sh        # Server startup script
├── .github/
│   └── workflows/
│       └── build.yml        # GitHub Actions workflow (auto-builds on push)
├── config.toml              # Configuration: versions and mod list
├── build.py                 # Build script: validates mods, generates list, builds image
├── Dockerfile               # Multi-stage Docker build
├── docker-compose.yml       # Local testing only
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
- Python 3.12+ with uv

### Build Process

1. **Configure versions and mods**: Edit [config.toml](config.toml)

   ```toml
   [versions]
   minecraft = "1.21.3"
   fabric_loader = "0.16.9"
   fabric_installer = "1.0.1"
   java = "21"

   [mods]
   list = [
       "lithium",
       "fabric-api",
       "sodium",
   ]
   ```

   Find mod slugs at [modrinth.com/mods](https://modrinth.com/mods)

2. **Build the image**:

   ```bash
   uv run build.py
   ```

   This will:
   - Validate all mods are available for the Minecraft version
   - Generate `build/mods.txt` with download URLs
   - Build the Docker image with configured versions

3. **Run locally**:

   ```bash
   docker run -d \
     --name minecraft \
     -p 25565:25565 \
     -v $(pwd)/data/world:/server/world \
     -v $(pwd)/data/logs:/server/logs \
     minecraft-server:latest
   ```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MEMORY_MAX` | `4G` | Maximum JVM heap size |
| `MEMORY_MIN` | `4G` | Minimum JVM heap size |
| `JVM_OPTS` | _(empty)_ | Additional JVM options |

### config.toml

All build configuration is in [config.toml](config.toml):

- **versions**: Minecraft, Fabric loader, Fabric installer, and Java versions
- **mods.list**: Array of mod slugs from Modrinth

### Volumes

Mount these directories to persist data:

- `/server/world` - Main overworld
- `/server/world_nether` - Nether dimension
- `/server/world_the_end` - End dimension
- `/server/logs` - Server logs
- `/server/config` - Mod and server configuration files

## Adding/Updating Mods

1. Find mod slug on [modrinth.com/mods](https://modrinth.com/mods)
   - The slug is in the URL: `modrinth.com/mod/[slug]`
   - Example: "lithium" from `modrinth.com/mod/lithium`

2. Add the slug to `config.toml`:
   ```toml
   [mods]
   list = [
       "lithium",
       "fabric-api",
       "your-new-mod",  # Add here
   ]
   ```

3. Rebuild the image:
   ```bash
   uv run build.py
   ```

The build script will automatically:
- Validate the mod is available for your Minecraft version
- Fetch the latest compatible version
- Add it to the Docker image

## Updating Versions

### Automatic Updates

Update to the latest compatible versions automatically:

```bash
uv run build.py --update
```

This will:
1. Find the **latest Minecraft version** that supports all your mods
2. Get the latest Fabric loader and installer versions
3. Update `config.toml` with these versions
4. Validate all mods are available
5. Build the Docker image

**Preview updates without modifying files:**

```bash
uv run build.py --update --dry-run
```

### Manual Updates

To manually update versions:

1. Edit [config.toml](config.toml)
2. Run `uv run build.py`
3. The script will validate all mods are compatible with the new version

If any mods are incompatible, the build will fail with a clear error message.

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

- **Automatic**: Push to `main` branch (after editing `config.toml`)
- **Manual**: Go to Actions tab → Build and Push Docker Image → Run workflow
- **Tagged releases**: Push a tag like `v1.0.0` for versioned images

The workflow automatically:
1. Installs uv
2. Runs `uv run build.py --generate-only` to create `build/mods.txt`
3. Reads versions from `config.toml`
4. Builds and pushes the Docker image with proper tags

## Server Management

### Remote Management with RCON

The server includes `rcon-cli` for remote administration. To enable RCON:

1. **Enable RCON** by adding to your `server.properties`:
   ```properties
   enable-rcon=true
   rcon.port=25575
   rcon.password=YOUR_SECURE_PASSWORD
   ```

2. **Expose the RCON port** when running:
   ```bash
   docker run -d \
     -p 25565:25565 \
     -p 25575:25575 \
     ...
   ```

3. **Use rcon-cli** to send commands:
   ```bash
   # From inside the container
   docker exec minecraft rcon-cli list
   docker exec minecraft rcon-cli stop
   docker exec minecraft rcon-cli "say Server restarting in 5 minutes"

   # Or with environment variable
   docker exec -e RCON_PASSWORD=your_password minecraft rcon-cli list
   ```

**Common RCON commands:**
- `list` - List online players
- `stop` - Stop the server gracefully
- `save-all` - Force save the world
- `whitelist add <player>` - Add player to whitelist
- `op <player>` - Give operator permissions

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

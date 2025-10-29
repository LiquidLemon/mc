#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#     "requests",
# ]
# ///

"""
Build script for Fabric Minecraft Server Docker image.

This script:
1. Reads configuration from config.toml
2. Validates mod availability on Modrinth
3. Generates build/mods.txt with download URLs
4. Builds Docker image with appropriate build arguments
"""

import subprocess
import sys
import tomllib
from pathlib import Path

import requests

# Constants
API_BASE = "https://api.modrinth.com/v2"
USER_AGENT = "yakub/minecraft-server-docker/1.0 (build.py)"
LOADER = "fabric"


def load_config() -> dict:
    """Load configuration from config.toml."""
    config_path = Path(__file__).parent / "config.toml"

    if not config_path.exists():
        print("❌ config.toml not found!", file=sys.stderr)
        print(f"Expected at: {config_path}", file=sys.stderr)
        sys.exit(1)

    with config_path.open("rb") as f:
        return tomllib.load(f)


def check_mod_availability(slug: str, minecraft_version: str, loader: str) -> tuple[bool, str | None]:
    """
    Check if a mod is available for the specified Minecraft version.

    Returns:
        Tuple of (is_available, version_info)
    """
    url = f"{API_BASE}/project/{slug}/version"
    params = {
        "loaders": f'["{loader}"]',
        "game_versions": f'["{minecraft_version}"]',
    }
    headers = {"User-Agent": USER_AGENT}

    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        versions = response.json()

        if not versions:
            return False, None

        latest = versions[0]
        version_info = latest.get("version_number", "unknown")
        return True, version_info

    except requests.RequestException as e:
        print(f"  ⚠ Error checking {slug}: {e}", file=sys.stderr)
        return False, None


def get_mod_download_url(slug: str, minecraft_version: str, loader: str) -> str | None:
    """
    Fetch the download URL for the latest version of a mod from Modrinth.

    Returns:
        Download URL string, or None if no suitable version found
    """
    url = f"{API_BASE}/project/{slug}/version"
    params = {
        "loaders": f'["{loader}"]',
        "game_versions": f'["{minecraft_version}"]',
    }
    headers = {"User-Agent": USER_AGENT}

    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        versions = response.json()

        if not versions:
            return None

        latest_version = versions[0]
        files = latest_version.get("files", [])
        primary_file = next((f for f in files if f.get("primary", False)), None)

        if not primary_file and files:
            primary_file = files[0]

        if primary_file:
            return primary_file["url"]
        else:
            return None

    except requests.RequestException:
        return None


def validate_mods(mod_list: list[str], minecraft_version: str) -> bool:
    """
    Validate that all mods are available for the target Minecraft version.

    Returns:
        True if all mods are available, False otherwise
    """
    print(f"🔍 Validating mod availability for Minecraft {minecraft_version}...\n")

    all_available = True
    results = []

    for slug in mod_list:
        available, version = check_mod_availability(slug, minecraft_version, LOADER)

        if available:
            print(f"  ✓ {slug} (v{version})")
            results.append((slug, True, version))
        else:
            print(f"  ❌ {slug} - NOT AVAILABLE")
            results.append((slug, False, None))
            all_available = False

    print()

    if not all_available:
        print("❌ Some mods are not available for this Minecraft version!", file=sys.stderr)
        print("Please check the mod names and Minecraft version in config.toml", file=sys.stderr)
        return False

    print(f"✓ All {len(mod_list)} mods are available\n")
    return True


def generate_mods_file(mod_list: list[str], minecraft_version: str) -> int:
    """
    Generate build/mods.txt with download URLs.

    Returns:
        Number of mods successfully added
    """
    print("📥 Fetching mod download URLs...\n")

    urls = []

    for slug in mod_list:
        url = get_mod_download_url(slug, minecraft_version, LOADER)
        if url:
            urls.append((slug, url))
            print(f"  ✓ {slug}")
        else:
            print(f"  ❌ {slug} - Failed to get download URL")

    print()

    # Write to build/mods.txt
    output_path = Path(__file__).parent / "build" / "mods.txt"
    output_path.parent.mkdir(exist_ok=True)

    with output_path.open("w") as f:
        f.write("# Generated mod list for Fabric Minecraft Server\n")
        f.write(f"# Minecraft version: {minecraft_version}\n")
        f.write(f"# Loader: {LOADER}\n")
        f.write("#\n")
        f.write("# Do not edit this file manually - regenerate with: uv run build.py\n")
        f.write("\n")

        for slug, url in urls:
            f.write(f"# {slug}\n")
            f.write(f"{url}\n")

    print(f"✓ Written {len(urls)} mod URLs to {output_path}\n")
    return len(urls)


def build_docker_image(config: dict) -> bool:
    """
    Build the Docker image with configured versions.

    Returns:
        True if build succeeded, False otherwise
    """
    versions = config["versions"]

    print("🐳 Building Docker image...\n")

    # Build docker command
    cmd = [
        "docker",
        "build",
        "--build-arg", f"MINECRAFT_VERSION={versions['minecraft']}",
        "--build-arg", f"FABRIC_LOADER_VERSION={versions['fabric_loader']}",
        "--build-arg", f"FABRIC_INSTALLER_VERSION={versions['fabric_installer']}",
        "--build-arg", f"JAVA_VERSION={versions['java']}",
        "-t", "minecraft-server:latest",
        ".",
    ]

    print(f"Running: {' '.join(cmd)}\n")
    print("=" * 70)

    # Run docker build with live output
    try:
        subprocess.run(
            cmd,
            check=True,
            text=True,
            bufsize=1,  # Line buffered
        )
        print("=" * 70)
        print("\n✓ Docker image built successfully!")
        return True

    except subprocess.CalledProcessError as e:
        print("=" * 70)
        print(f"\n❌ Docker build failed with exit code {e.returncode}", file=sys.stderr)
        return False
    except FileNotFoundError:
        print("\n❌ Docker not found! Please install Docker.", file=sys.stderr)
        return False


def main() -> int:
    """Main entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Build Fabric Minecraft Server Docker image")
    parser.add_argument(
        "--generate-only",
        action="store_true",
        help="Only generate mods.txt without building Docker image",
    )
    args = parser.parse_args()

    print("=" * 70)
    print("Fabric Minecraft Server - Docker Build")
    print("=" * 70)
    print()

    # Load configuration
    config = load_config()
    versions = config["versions"]
    mod_list = config["mods"]["list"]

    print("Configuration:")
    print(f"  Minecraft: {versions['minecraft']}")
    print(f"  Fabric Loader: {versions['fabric_loader']}")
    print(f"  Fabric Installer: {versions['fabric_installer']}")
    print(f"  Java: {versions['java']}")
    print(f"  Mods: {len(mod_list)} selected")
    print()

    # Validate mods
    if not validate_mods(mod_list, versions["minecraft"]):
        return 1

    # Generate mods file
    mod_count = generate_mods_file(mod_list, versions["minecraft"])
    if mod_count == 0:
        print("❌ No mods were successfully added!", file=sys.stderr)
        return 1

    # If --generate-only flag is set, stop here
    if args.generate_only:
        print("✓ Mods list generated successfully!")
        return 0

    # Build Docker image
    if not build_docker_image(config):
        return 1

    print()
    print("=" * 70)
    print("✓ Build complete!")
    print("=" * 70)
    print()
    print("To run the server:")
    print("  docker run -d -p 25565:25565 -v $(pwd)/data/world:/server/world minecraft-server:latest")
    print()

    return 0


if __name__ == "__main__":
    sys.exit(main())

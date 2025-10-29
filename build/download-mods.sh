#!/bin/bash
set -e

echo "Starting mod download process..."

# Check if mods.txt exists
if [ ! -f "mods.txt" ]; then
    echo "Warning: mods.txt not found. No mods will be downloaded."
    exit 0
fi

# Count total mods to download (excluding comments and empty lines)
TOTAL_MODS=$(grep -v "^#" mods.txt | grep -v "^$" | wc -l)

if [ "$TOTAL_MODS" -eq 0 ]; then
    echo "No mod URLs found in mods.txt"
    exit 0
fi

echo "Found $TOTAL_MODS mod(s) to download"

# Download each mod
MOD_COUNT=0
while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
        continue
    fi

    MOD_COUNT=$((MOD_COUNT + 1))

    # Extract filename from URL
    FILENAME=$(basename "$line" | sed 's/?.*$//')

    echo "[$MOD_COUNT/$TOTAL_MODS] Downloading: $FILENAME"

    # Download the mod with retry logic
    MAX_RETRIES=3
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -L -f -o "$FILENAME" "$line"; then
            echo "  ✓ Successfully downloaded $FILENAME"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "  ✗ Download failed, retrying ($RETRY_COUNT/$MAX_RETRIES)..."
                sleep 2
            else
                echo "  ✗ Failed to download $FILENAME after $MAX_RETRIES attempts"
                exit 1
            fi
        fi
    done

done < mods.txt

echo "Mod download complete! Downloaded $MOD_COUNT mod(s)"
ls -lh *.jar 2>/dev/null || echo "No .jar files found in directory"

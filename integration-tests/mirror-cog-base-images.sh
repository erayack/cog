#!/usr/bin/env bash
# Mirror cog-base images from r8.im to GHCR for integration tests.
#
# This script copies all cog-base image tags listed in cog-base-tags.txt
# from r8.im/cog-base to ghcr.io/replicate/cog/cog-base. Integration tests
# use COG_REGISTRY_HOST=ghcr.io/replicate/cog to resolve base images from
# GHCR instead of r8.im.
#
# Prerequisites:
#   - crane (https://github.com/google/go-containerregistry/tree/main/cmd/crane)
#   - Authenticated to GHCR: echo $GHCR_TOKEN | crane auth login ghcr.io -u USERNAME --password-stdin
#
# Usage:
#   ./integration-tests/mirror-cog-base-images.sh
#
# Run this script when:
#   - New cog-base images are published to r8.im
#   - New tags are added to cog-base-tags.txt (e.g. new Python/CUDA/torch versions)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAGS_FILE="$SCRIPT_DIR/cog-base-tags.txt"
SRC_REGISTRY="r8.im"
DST_REGISTRY="ghcr.io/replicate/cog"

if ! command -v crane &> /dev/null; then
    echo "error: crane is not installed. Install it from:" >&2
    echo "  https://github.com/google/go-containerregistry/tree/main/cmd/crane" >&2
    exit 1
fi

if [ ! -f "$TAGS_FILE" ]; then
    echo "error: $TAGS_FILE not found" >&2
    exit 1
fi

failed=0
while IFS= read -r line; do
    tag=$(echo "$line" | xargs)  # trim whitespace
    [[ -z "$tag" || "$tag" == \#* ]] && continue

    src="$SRC_REGISTRY/cog-base:$tag"
    dst="$DST_REGISTRY/cog-base:$tag"
    echo "Copying $src -> $dst"
    if ! crane copy "$src" "$dst"; then
        echo "warning: failed to copy $src" >&2
        failed=$((failed + 1))
    fi
done < "$TAGS_FILE"

if [ "$failed" -gt 0 ]; then
    echo "warning: $failed image(s) failed to copy" >&2
    exit 1
fi

echo "All images mirrored successfully."

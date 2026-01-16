#!/bin/bash
# Build wrapper that cleans broken symlinks before building
# Usage: ./scripts/build.sh [dune args...]
#
# This prevents "broken symbolic link" errors during build

cd "$(dirname "$0")/.."

# Remove any broken .cmi symlinks before building
find driver cfrontend -maxdepth 1 -name "*.cmi" -type l -delete 2>/dev/null || true

# Run dune build with all arguments
dune build "$@"

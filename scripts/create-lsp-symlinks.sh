#!/bin/bash
# Generate .merlin files for LSP support in driver/ and cfrontend/
# Uses dune's merlin dump-config to get absolute paths including PPX

set -e

if [ -z "$WORKSPACE_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
fi

cd "$WORKSPACE_ROOT"

# Check if build exists
if [ ! -d "_build/default/extraction/compcert" ]; then
    echo "Build not found. Run 'dune build' first."
    exit 0
fi

# Get merlin config from dune (has absolute paths)
CONFIG=$(dune ocaml merlin dump-config extraction/compcert 2>/dev/null || true)

if [ -z "$CONFIG" ]; then
    echo "Could not get merlin config"
    exit 0
fi

# Extract config for a specific file section and convert to .merlin format
extract_merlin_config() {
    local section_marker="$1"
    local output_file="$2"

    echo "$CONFIG" | awk -v marker="$section_marker" '
    BEGIN { in_section = 0 }
    index($0, marker) { in_section = 1; next }
    in_section && /^[A-Za-z]+:/ { in_section = 0 }
    in_section {
        # Remove leading whitespace
        gsub(/^[ \t]+/, "")
        # Handle (B path) -> B path
        if (/^\(B /) {
            gsub(/^\(B /, "B ")
            gsub(/\)$/, "")
            print
        }
        # Handle (S path) -> S path
        if (/^\(S /) {
            gsub(/^\(S /, "S ")
            gsub(/\)$/, "")
            print
        }
        # Handle (FLG (...)) -> FLG ...
        if (/^\(FLG /) {
            gsub(/^\(FLG \(/, "FLG ")
            gsub(/\)\)$/, "")
            print
        }
    }
    ' > "$output_file"
}

# Generate .merlin for driver/ (using Driver.ml config which has PPX)
extract_merlin_config "Driver: _build/default/extraction/compcert/Driver.ml" "driver/.merlin"

# Generate .merlin for cfrontend/ (using PrintRustLight.ml or similar)
extract_merlin_config "PrintRustLight: _build/default/extraction/compcert/PrintRustLight.ml" "cfrontend/.merlin"

# If cfrontend/.merlin is empty, use compcert library config
if [ ! -s "cfrontend/.merlin" ]; then
    extract_merlin_config "compcert: _build/default/extraction/compcert/compcert" "cfrontend/.merlin"
fi

# Verify files were created with content
if [ -s "driver/.merlin" ]; then
    echo "Generated driver/.merlin ($(wc -l < driver/.merlin) lines)"
else
    echo "Warning: driver/.merlin is empty"
fi

if [ -s "cfrontend/.merlin" ]; then
    echo "Generated cfrontend/.merlin ($(wc -l < cfrontend/.merlin) lines)"
else
    echo "Warning: cfrontend/.merlin is empty"
fi

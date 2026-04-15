#!/bin/bash
set -euo pipefail

SCRIPT_PATH="bin/git-trello"
VERSION_FILE="version.txt"

usage() {
    echo "Usage: scripts/sync-version.sh [--print|--write|--check]"
    echo "  --print  Print CURRENT_VERSION from ${SCRIPT_PATH}"
    echo "  --write  Sync ${VERSION_FILE} from CURRENT_VERSION"
    echo "  --check  Exit non-zero if ${VERSION_FILE} does not match CURRENT_VERSION"
}

extract_script_version() {
    local version
    version=$(sed -n 's/^CURRENT_VERSION="\([^"]*\)"/\1/p' "$SCRIPT_PATH")
    if [ -z "${version}" ]; then
        echo "Error: Could not extract CURRENT_VERSION from ${SCRIPT_PATH}" >&2
        exit 1
    fi
    echo "${version}"
}

read_version_file() {
    if [ ! -f "$VERSION_FILE" ]; then
        echo ""
        return
    fi
    tr -d '[:space:]' < "$VERSION_FILE"
}

MODE="${1:---check}"

case "$MODE" in
    --print)
        extract_script_version
        ;;
    --write)
        version="$(extract_script_version)"
        printf "%s\n" "$version" > "$VERSION_FILE"
        echo "Synced ${VERSION_FILE} to ${version}"
        ;;
    --check)
        script_version="$(extract_script_version)"
        file_version="$(read_version_file)"

        if [ "$script_version" != "$file_version" ]; then
            echo "Version mismatch detected:"
            echo "  ${SCRIPT_PATH}: ${script_version}"
            echo "  ${VERSION_FILE}: ${file_version:-<missing>}"
            echo "Run: scripts/sync-version.sh --write"
            exit 1
        fi
        echo "Version files are in sync (${script_version})"
        ;;
    *)
        usage
        exit 1
        ;;
esac

#!/bin/bash
#
# Convert Mercurial repo to Git using hg-fast-export
#
# Usage:
#   ./convert.sh [--max-rev <revision>]
#
# Environment:
#   HG_REPO_PATH      - Path to Mercurial repo (default: ../upstream-hg)
#   FAST_EXPORT_PATH  - Path to fast-export (default: ../fast-export)
#   FILTER_SCRIPT     - Path to filter-tags.py (default: script dir)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAX_REV=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --max-rev)
            MAX_REV="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Defaults
HG_REPO_PATH="${HG_REPO_PATH:-../upstream-hg}"
FAST_EXPORT_PATH="${FAST_EXPORT_PATH:-../fast-export}"
FILTER_SCRIPT="${FILTER_SCRIPT:-$SCRIPT_DIR/filter-tags.py}"

# Build max revision argument
MAX_REV_ARG=""
if [[ -n "$MAX_REV" ]]; then
    MAX_REV_ARG="--max $MAX_REV"
    echo "Limiting sync to revision $MAX_REV"
fi

# Run conversion
python3 "${FAST_EXPORT_PATH}/hg-fast-export.py" \
    -r "$HG_REPO_PATH" \
    -M mercurial-sync \
    --force \
    --marks .git/hg2git-marks \
    --mapping .git/hg2git-mapping \
    --heads .git/hg2git-heads \
    --status .git/hg2git-state \
    $MAX_REV_ARG \
    | python3 "$FILTER_SCRIPT" \
    | git fast-import --import-marks-if-exists=.git/hg2git-marks --export-marks=.git/hg2git-marks --force

#!/bin/bash
#
# Local test script for Mercurial to Git sync
#
# Usage:
#   ./mercurial-sync.sh [--dry-run]
#
# Options:
#   --dry-run    Only run conversion, don't push to remote
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/../../.."
DRY_RUN=false

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "Running in dry-run mode (no push)"
fi

cd "$WORK_DIR"

echo "=== Step 1: Clone upstream Mercurial repo ==="
rm -rf upstream-hg
hg clone https://foss.heptapod.net/zandronum/zandronum-stable upstream-hg

echo "=== Step 2: Clone fast-export ==="
rm -rf fast-export
git clone https://github.com/frej/fast-export.git

echo "=== Step 3: Initialize temp Git repo ==="
rm -rf hg-temp-git
git init hg-temp-git
cd hg-temp-git

# Add remote if GITHUB_REPO is set, otherwise use origin from parent
if [[ -n "$GITHUB_REPO" ]]; then
    git remote add origin "https://github.com/${GITHUB_REPO}.git"
elif git -C "$WORK_DIR" remote get-url origin > /dev/null 2>&1; then
    ORIGIN_URL=$(git -C "$WORK_DIR" remote get-url origin)
    git remote add origin "$ORIGIN_URL"
fi

# Fetch if remote exists
if git remote get-url origin > /dev/null 2>&1; then
    echo "Fetching from origin..."
    git fetch origin || true
fi

echo "=== Step 4: Check for existing state ==="
# Try to restore conversion state
if git show origin/mercurial-sync-meta:hg2git-heads > /dev/null 2>&1 && \
   git show origin/mercurial-sync-meta:hg2git-marks > /dev/null 2>&1 && \
   git show origin/mercurial-sync-meta:hg2git-state > /dev/null 2>&1 && \
   git show origin/mercurial-sync-meta:hg2git-mapping > /dev/null 2>&1; then
    echo "Restoring conversion state from mercurial-sync-meta..."
    git show origin/mercurial-sync-meta:hg2git-marks > .git/hg2git-marks
    git show origin/mercurial-sync-meta:hg2git-state > .git/hg2git-state
    git show origin/mercurial-sync-meta:hg2git-mapping > .git/hg2git-mapping
    git show origin/mercurial-sync-meta:hg2git-heads > .git/hg2git-heads
    git checkout -b mercurial-sync origin/mercurial-sync
else
    echo "No existing state found, doing fresh conversion..."
    git branch -D mercurial-sync 2>/dev/null || true
    git update-ref -d refs/remotes/origin/mercurial-sync 2>/dev/null || true
    rm -f .git/hg2git-marks .git/hg2git-state .git/hg2git-mapping .git/hg2git-heads
fi

echo "=== Step 5: Run conversion ==="
python3 ../fast-export/hg-fast-export.py \
    -r ../upstream-hg \
    -M mercurial-sync \
    --force \
    --marks .git/hg2git-marks \
    --mapping .git/hg2git-mapping \
    --heads .git/hg2git-heads \
    --status .git/hg2git-state \
    | python3 "$SCRIPT_DIR/filter-tags.py" \
    | git fast-import --import-marks-if-exists=.git/hg2git-marks --export-marks=.git/hg2git-marks --force

echo "=== Step 6: Optimize repository ==="
git gc --aggressive --prune=now

echo "=== Conversion complete ==="
git log --oneline -10
echo ""
echo "Tags created:"
git tag -l | head -20

if [[ "$DRY_RUN" == "false" ]] && git remote get-url origin > /dev/null 2>&1; then
    echo ""
    echo "=== Step 7: Push to remote ==="
    git push origin mercurial-sync --force

    echo "=== Step 8: Save conversion state ==="
    git config user.email "local-test@example.com"
    git config user.name "Local Test"
    git fetch origin mercurial-sync-meta || true
    git checkout --orphan temp-meta
    git rm -rf . 2>/dev/null || true
    cp .git/hg2git-marks . 2>/dev/null || true
    cp .git/hg2git-state . 2>/dev/null || true
    cp .git/hg2git-mapping . 2>/dev/null || true
    cp .git/hg2git-heads . 2>/dev/null || true
    git add hg2git-marks hg2git-state hg2git-mapping hg2git-heads 2>/dev/null || true
    git commit -m "Update conversion state" || true
    git push origin temp-meta:mercurial-sync-meta --force || true
else
    echo ""
    echo "Dry-run mode: skipping push"
    echo "Converted repo is in: $(pwd)"
fi

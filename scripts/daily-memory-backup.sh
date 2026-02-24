#!/bin/bash
# Daily Memory Backup Script
# Runs at 7:00 PM daily

WORKSPACE="/home/warren/.openclaw/workspace"
MEMORY_DIR="$WORKSPACE/memory"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

cd "$WORKSPACE"

# Check if there are any changes in memory directory
if git diff --quiet --exit-code HEAD -- memory/ 2>/dev/null && git diff --cached --quiet --exit-code -- memory/ 2>/dev/null; then
    echo "[$DATE $TIME] No changes to memory files. Skipping backup."
    exit 0
fi

# Configure git user for this repo
git config user.email "backup@openclaw.local" 2>/dev/null || true
git config user.name "Daily Backup" 2>/dev/null || true

# Stage memory files
git add memory/

# Commit with timestamp
git commit -m "Daily backup: $DATE $TIME

- Automatic backup of memory files
- Session log updates" || {
    echo "[$DATE $TIME] Nothing to commit or commit failed"
    exit 0
}

# Push to GitHub
git push origin HEAD:main 2>&1 && {
    echo "[$DATE $TIME] ✓ Memory backup successful"
} || {
    echo "[$DATE $TIME] ✗ Push failed"
    exit 1
}

#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="$HOME"
ONEDRIVE_PATH="$HOME/OneDrive - Jackson Healthcare"
EXCLUDES=("Library" "Applications" "OneDrive - Jackson Healthcare" "dotfiles")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Results tracking
declare -a RESULTS=()

add_result() {
    local dir="$1" type="$2" status="$3"
    RESULTS+=("$(printf "%-30s | %-8s | %s" "$dir" "$type" "$status")")
}

is_excluded() {
    local dirname="$1"
    for exc in "${EXCLUDES[@]}"; do
        if [[ "$dirname" == "$exc" ]]; then
            return 0
        fi
    done
    return 1
}

handle_git_repo() {
    local dir="$1"
    local dirname
    dirname=$(basename "$dir")

    cd "$dir"

    # Check if remote exists
    if ! git remote -v | grep -q .; then
        add_result "$dirname" "git" "NO REMOTE — needs manual setup"
        return
    fi

    local branch
    branch=$(git branch --show-current 2>/dev/null || echo "")
    if [[ -z "$branch" ]]; then
        branch="detached-HEAD"
    fi

    # Stage and commit if there are changes
    local had_changes=false
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        had_changes=true
        git add -A
        git commit -m "auto-backup: $(date +%Y-%m-%d_%H-%M-%S)" --no-gpg-sign 2>/dev/null || true
    fi

    # Check if there's anything to push
    local unpushed
    unpushed=$(git log --oneline "@{upstream}..HEAD" 2>/dev/null || echo "no-upstream")

    if [[ "$unpushed" == "no-upstream" ]]; then
        # No upstream tracking — try to push, fallback to backup branch
        if git push origin "$branch" 2>/dev/null; then
            add_result "$dirname" "git" "pushed ($branch)"
        else
            local backup_branch="backup/$(date +%Y-%m-%d_%H-%M-%S)-unmerged"
            git checkout -b "$backup_branch" 2>/dev/null
            if git push origin "$backup_branch" 2>/dev/null; then
                git checkout "$branch" 2>/dev/null || true
                add_result "$dirname" "git" "pushed ($backup_branch)"
            else
                git checkout "$branch" 2>/dev/null || true
                add_result "$dirname" "git" "FAILED to push"
            fi
        fi
    elif [[ -z "$unpushed" ]] && [[ "$had_changes" == false ]]; then
        add_result "$dirname" "git" "clean ($branch)"
    else
        # Has commits to push
        if git push 2>/dev/null; then
            add_result "$dirname" "git" "pushed ($branch)"
        else
            local backup_branch="backup/$(date +%Y-%m-%d_%H-%M-%S)-unmerged"
            git checkout -b "$backup_branch" 2>/dev/null
            if git push origin "$backup_branch" 2>/dev/null; then
                git checkout "$branch" 2>/dev/null || true
                add_result "$dirname" "git" "pushed ($backup_branch)"
            else
                git checkout "$branch" 2>/dev/null || true
                add_result "$dirname" "git" "FAILED to push"
            fi
        fi
    fi
}

handle_onedrive_sync() {
    local dir="$1"
    local dirname
    dirname=$(basename "$dir")

    # Build exclude list for any nested git repos
    local -a rsync_excludes=()
    while IFS= read -r gitdir; do
        # Get the repo directory (parent of .git) relative to $dir
        local repo_rel
        repo_rel="$(dirname "${gitdir#"$dir/"}")"
        rsync_excludes+=(--exclude="$repo_rel/")
    done < <(find "$dir" -name .git -type d 2>/dev/null)

    rsync -av --delete ${rsync_excludes[@]+"${rsync_excludes[@]}"} "$dir/" "$ONEDRIVE_PATH/$dirname/" > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        add_result "$dirname" "onedrive" "synced"
    else
        add_result "$dirname" "onedrive" "SYNC FAILED"
    fi
}

# --- Main ---

echo -e "${CYAN}Backup Check — $(date +%Y-%m-%d\ %H:%M:%S)${NC}"
echo ""

# Verify OneDrive exists
if [[ ! -d "$ONEDRIVE_PATH" ]]; then
    echo -e "${RED}ERROR: OneDrive folder not found at: $ONEDRIVE_PATH${NC}"
    exit 1
fi

for dir in "$HOME_DIR"/*/; do
    # Remove trailing slash and get basename
    dir="${dir%/}"
    dirname=$(basename "$dir")

    # Skip hidden directories
    [[ "$dirname" == .* ]] && continue

    # Skip excluded
    if is_excluded "$dirname"; then
        continue
    fi

    echo -e "${CYAN}Checking:${NC} $dirname"

    if [[ -d "$dir/.git" ]]; then
        handle_git_repo "$dir"
    else
        handle_onedrive_sync "$dir"
    fi
done

# Print summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
printf "%-30s | %-8s | %s\n" "Directory" "Type" "Status"
printf "%-30s-+-%-8s-+-%s\n" "------------------------------" "--------" "--------------------"
for result in "${RESULTS[@]}"; do
    if [[ "$result" == *"FAILED"* ]] || [[ "$result" == *"NO REMOTE"* ]]; then
        echo -e "${RED}${result}${NC}"
    elif [[ "$result" == *"backup/"* ]]; then
        echo -e "${YELLOW}${result}${NC}"
    else
        echo -e "${GREEN}${result}${NC}"
    fi
done
echo ""

# Generate machine snapshot
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo -e "${CYAN}Generating machine snapshot...${NC}"
"$SCRIPT_DIR/generate-snapshot.sh"

# Copy snapshot to OneDrive
cp "$SCRIPT_DIR/MACHINE-SNAPSHOT.md" "$ONEDRIVE_PATH/MACHINE-SNAPSHOT.md" 2>/dev/null && \
    echo -e "${GREEN}Snapshot saved to OneDrive${NC}" || \
    echo -e "${YELLOW}Snapshot saved locally only${NC}"
echo ""

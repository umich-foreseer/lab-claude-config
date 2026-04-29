#!/usr/bin/env bash
set -euo pipefail

# Lab-wide Claude Code / Codex configuration uninstaller
# Removes symlinks pointing into this repo, strips lab config from CLAUDE.md/AGENTS.md,
# restores backups if available

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
BACKUP_DIR="$CLAUDE_DIR/backups/lab-config-backup"
CODEX_BACKUP_DIR="$CODEX_DIR/backups/lab-config-backup"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }

# Remove symlink only if it points into our repo
remove_repo_symlink() {
    local target="$1"
    if [[ -L "$target" ]]; then
        local link_dest
        link_dest="$(readlink -f "$target")"
        if [[ "$link_dest" == "$SCRIPT_DIR/"* ]]; then
            rm "$target"
            ok "Removed symlink: $target"
            return 0
        else
            warn "Skipping $target (points to $link_dest, not this repo)"
            return 1
        fi
    else
        warn "Skipping $target (not a symlink)"
        return 1
    fi
}

# Restore most recent backup if available
restore_backup() {
    local target="$1"
    local backup_dir="${2:-$BACKUP_DIR}"
    local basename
    basename="$(basename "$target")"

    if [[ -d "$backup_dir" ]]; then
        # Find most recent backup for this file
        local latest
        latest="$(ls -t "$backup_dir/${basename}."* 2>/dev/null | head -1 || true)"
        if [[ -n "$latest" ]]; then
            cp -a "$latest" "$target"
            ok "Restored $target from backup: $(basename "$latest")"
            return 0
        fi
    fi
    return 1
}

strip_marked_block() {
    local target_file="$1"
    local doc_label="$2"

    if [[ -f "$target_file" ]] && grep -qF "$BEGIN_MARKER" "$target_file"; then
        awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
            $0 == begin { skip=1; next }
            $0 == end   { skip=0; next }
            !skip       { print }
        ' "$target_file" > "$target_file.tmp"

        # Remove leading blank lines left behind
        sed -i '/./,$!d' "$target_file.tmp"

        if [[ -s "$target_file.tmp" ]]; then
            mv "$target_file.tmp" "$target_file"
            ok "Stripped lab config block from $doc_label (your content preserved)"
        else
            # File was entirely lab config - remove it
            rm "$target_file.tmp" "$target_file"
            ok "Removed $doc_label (was entirely lab config)"
        fi
    else
        warn "No lab config markers found in $doc_label - left untouched"
    fi
}

info "Uninstalling lab AI coding configuration..."
echo ""

# Remove symlinks and restore backups (settings.json, statusline-command.sh)
for file in settings.json statusline-command.sh; do
    if remove_repo_symlink "$CLAUDE_DIR/$file"; then
        restore_backup "$CLAUDE_DIR/$file" || true
    fi
done

BEGIN_MARKER="<!-- BEGIN: lab-config -->"
END_MARKER="<!-- END: lab-config -->"

strip_marked_block "$CLAUDE_DIR/CLAUDE.md" "CLAUDE.md"
strip_marked_block "$CODEX_DIR/AGENTS.md" "AGENTS.md"

# Remove skill symlinks
for skill_dir in "$CLAUDE_DIR/skills"/*; do
    if [[ -L "$skill_dir" ]]; then
        remove_repo_symlink "$skill_dir" || true
    fi
done

# Remove agent symlinks
for agent_file in "$CLAUDE_DIR/agents"/*.md; do
    if [[ -L "$agent_file" ]]; then
        remove_repo_symlink "$agent_file" || true
    fi
done

# Remove Claude hook symlinks
if [[ -L "$CLAUDE_DIR/hooks" ]]; then
    remove_repo_symlink "$CLAUDE_DIR/hooks" || true
fi
for hook_file in "$CLAUDE_DIR/hooks"/*; do
    if [[ -L "$hook_file" ]]; then
        remove_repo_symlink "$hook_file" || true
    fi
done

# Remove Codex skill symlinks
for skill_dir in "$CODEX_DIR/skills"/*; do
    if [[ -L "$skill_dir" ]]; then
        remove_repo_symlink "$skill_dir" || true
    fi
done

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo ""
echo "  Note: The following files were NOT touched:"
echo "    - ~/.claude/settings.local.json (your personal permissions)"
echo "    - ~/.claude/CLAUDE.md personal content (outside markers)"
echo "    - ~/.codex/AGENTS.md personal content (outside markers)"
echo "    - Backups in ~/.claude/backups/"
echo "    - Backups in ~/.codex/backups/"
echo ""
echo "  If you want to fully clean up, remove these manually."

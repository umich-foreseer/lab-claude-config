#!/usr/bin/env bash
set -euo pipefail

# Lab-wide Claude Code configuration uninstaller
# Removes symlinks pointing into this repo, strips lab config from CLAUDE.md,
# restores backups if available

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backups/lab-config-backup"

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
        if [[ "$link_dest" == "$SCRIPT_DIR"* ]]; then
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
    local basename
    basename="$(basename "$target")"

    if [[ -d "$BACKUP_DIR" ]]; then
        # Find most recent backup for this file
        local latest
        latest="$(ls -t "$BACKUP_DIR/${basename}."* 2>/dev/null | head -1 || true)"
        if [[ -n "$latest" ]]; then
            cp -a "$latest" "$target"
            ok "Restored $target from backup: $(basename "$latest")"
            return 0
        fi
    fi
    return 1
}

info "Uninstalling lab Claude Code configuration..."
echo ""

# Remove symlinks and restore backups (settings.json, statusline-command.sh)
for file in settings.json statusline-command.sh; do
    if remove_repo_symlink "$CLAUDE_DIR/$file"; then
        restore_backup "$CLAUDE_DIR/$file" || true
    fi
done

# Strip lab config block from CLAUDE.md
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
BEGIN_MARKER="<!-- BEGIN: lab-config -->"
END_MARKER="<!-- END: lab-config -->"

if [[ -f "$CLAUDE_MD" ]] && grep -qF "$BEGIN_MARKER" "$CLAUDE_MD"; then
    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        $0 == begin { skip=1; next }
        $0 == end   { skip=0; next }
        !skip       { print }
    ' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"

    # Remove leading blank lines left behind
    sed -i '/./,$!d' "$CLAUDE_MD.tmp"

    if [[ -s "$CLAUDE_MD.tmp" ]]; then
        mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
        ok "Stripped lab config block from CLAUDE.md (your content preserved)"
    else
        # File was entirely lab config — remove it
        rm "$CLAUDE_MD.tmp" "$CLAUDE_MD"
        ok "Removed CLAUDE.md (was entirely lab config)"
    fi
else
    warn "No lab config markers found in CLAUDE.md — left untouched"
fi

# Remove skill symlinks
for skill_dir in "$CLAUDE_DIR/skills"/*/; do
    if [[ -L "${skill_dir%/}" ]]; then
        remove_repo_symlink "${skill_dir%/}" || true
    fi
done

echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo ""
echo "  Note: The following files were NOT touched:"
echo "    - ~/.claude/settings.local.json (your personal permissions)"
echo "    - ~/.claude/CLAUDE.md personal content (outside markers)"
echo "    - Backups in ~/.claude/backups/"
echo ""
echo "  If you want to fully clean up, remove these manually."

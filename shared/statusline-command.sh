#!/usr/bin/env bash
# Claude Code statusLine command
# Mirrors half-life Oh My Zsh theme with ANSI 256-color escapes.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
remaining=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Color codes (use $'...' so escapes are resolved immediately)
C_PURPLE=$'\033[38;5;135m'
C_GREEN=$'\033[38;5;118m'
C_CYAN=$'\033[38;5;81m'
C_ORANGE=$'\033[38;5;166m'
C_PINK=$'\033[38;5;161m'
C_DIM=$'\033[38;5;245m'
C_RESET=$'\033[0m'

# Shorten home directory to ~
short_cwd="${cwd/#$HOME/~}"

# Git branch + dirty markers
git_info=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        markers=""
        if ! git -C "$cwd" diff --quiet 2>/dev/null; then
            markers="${markers} ${C_ORANGE}●${C_RESET}"
        fi
        if ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
            markers="${markers} ${C_GREEN}●${C_RESET}"
        fi
        if [ -n "$(git -C "$cwd" ls-files --other --exclude-standard 2>/dev/null)" ]; then
            markers="${markers} ${C_PINK}●${C_RESET}"
        fi
        git_info=" on ${C_CYAN}${branch}${markers}${C_RESET}"
    fi
fi

# Context remaining
ctx=""
if [ -n "$remaining" ]; then
    ctx="  ${C_DIM}[ctx: ${remaining}%]${C_RESET}"
fi

# Model
model_str=""
if [ -n "$model" ]; then
    model_str="  ${C_DIM}${model}${C_RESET}"
fi

echo "${C_PURPLE}$(whoami)${C_RESET} in ${C_GREEN}${short_cwd}${C_RESET}${git_info} ${C_ORANGE}λ${C_RESET}${model_str}${ctx}"

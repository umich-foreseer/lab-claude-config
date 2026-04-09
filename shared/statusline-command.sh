#!/usr/bin/env bash
# Claude Code statusLine command
# Mirrors half-life Oh My Zsh theme with ANSI 256-color escapes.
# Adapts layout to terminal width: 1 line → 2 lines → truncated.

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""' | sed 's/ *([^)]*)$//')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Colors
C_PURPLE=$'\033[38;5;135m' C_GREEN=$'\033[38;5;118m' C_CYAN=$'\033[38;5;81m'
C_ORANGE=$'\033[38;5;166m' C_PINK=$'\033[38;5;161m'  C_DIM=$'\033[38;5;245m'
C_RESET=$'\033[0m'

# Visible length (strip ANSI)
vlen() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -m; }

# Detect terminal width by walking parent PIDs to find the TTY
# (stdin is piped JSON so $COLUMNS / tput are unavailable)
cols=80
pid=$$
for _ in $(seq 10); do
    read -r ppid tty < <(ps -o ppid=,tty= -p "$pid" 2>/dev/null)
    if [[ -n $tty && $tty != "?" && $tty != "??" ]]; then
        w=$(stty size <"/dev/$tty" 2>/dev/null | awk '{print $2}')
        [[ $w -gt 0 ]] 2>/dev/null && cols=$(( w * 70 / 100 ))  # reserve 30% for Claude UI
        break
    fi
    [[ -z $ppid || $ppid == [01] ]] && break
    pid=$ppid
done

# Path: ~/a/b/c/d → ~/.../c/d (at most 2 trailing dirs)
short_cwd=$(echo "$cwd" | sed "s|^${HOME}|~|")
IFS='/' read -ra p <<< "$short_cwd"
(( ${#p[@]} > 3 )) && short_cwd="${p[0]}/.../${p[-2]}/${p[-1]}"
# Basename-only variant for narrow terminals
base_cwd="${short_cwd##*/}"

# Git info
branch="" ; markers="" ; git_seg=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks &>/dev/null; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git -C "$cwd" diff --quiet 2>/dev/null || markers+=" ${C_ORANGE}●${C_RESET}"
        git -C "$cwd" diff --cached --quiet 2>/dev/null || markers+=" ${C_GREEN}●${C_RESET}"
        [ -z "$(git -C "$cwd" ls-files --other --exclude-standard 2>/dev/null)" ] || markers+=" ${C_PINK}●${C_RESET}"
    fi
fi

# Tail segment: λ model [ctx: N%]
tail=""
[ -n "$model" ]   && tail+="  ${C_DIM}${model}${C_RESET}"
[ -n "$ctx_pct" ] && tail+="  ${C_DIM}[ctx: ${ctx_pct}%]${C_RESET}"
line2="${C_ORANGE}λ${C_RESET}${tail}"

# Build git_seg helper for a given branch name
make_git() { [ -n "$1" ] && echo " on ${C_CYAN}${1}${markers}${C_RESET}" || echo ""; }

# Adaptive layout — try widest first, progressively shrink
# 1) Full single line: user in path on branch● λ model [ctx]
git_seg=$(make_git "$branch")
line1="${C_PURPLE}$(whoami)${C_RESET} in ${C_GREEN}${short_cwd}${C_RESET}${git_seg}"
full="${line1} ${line2}"

if (( $(vlen "$full") <= cols )); then
    echo "$full"
    exit 0
fi

# 2) Two lines — full path + full branch
if (( $(vlen "$line1") <= cols )); then
    echo "$line1"
    echo "$line2"
    exit 0
fi

# 3) Two lines — basename path + full branch
line1="${C_PURPLE}$(whoami)${C_RESET} in ${C_GREEN}${base_cwd}${C_RESET}${git_seg}"
if (( $(vlen "$line1") <= cols )); then
    echo "$line1"
    echo "$line2"
    exit 0
fi

# 4) Two lines — basename path + truncated branch (max 12 chars)
if [ -n "$branch" ]; then
    short_b="${branch:0:12}" ; (( ${#branch} > 12 )) && short_b+="…"
    git_seg=$(make_git "$short_b")
    line1="${C_PURPLE}$(whoami)${C_RESET} in ${C_GREEN}${base_cwd}${C_RESET}${git_seg}"
fi
echo "$line1"
echo "$line2"

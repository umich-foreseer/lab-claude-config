#!/usr/bin/env bash
# Claude Code statusLine command
# Rich statusline with gradient progress bar, cost, rate limits, and effort level.

input=$(cat)

# Extract fields
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model_name=$(echo "$input" | jq -r '.model.display_name' | sed 's/ ([^)]*context)//')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
rate_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
# Effort: env var first, then settings chain, then default
if [ -n "$CLAUDE_CODE_EFFORT_LEVEL" ]; then
    effort="$CLAUDE_CODE_EFFORT_LEVEL"
else
    effort=""
    for f in \
        "${current_dir}/.claude/settings.local.json" \
        "${current_dir}/.claude/settings.json" \
        "$HOME/.claude/settings.local.json" \
        "$HOME/.claude/settings.json"; do
        if [ -f "$f" ]; then
            val=$(jq -r '.effortLevel // empty' "$f" 2>/dev/null)
            if [ -n "$val" ]; then
                effort="$val"
                break
            fi
        fi
    done
    effort="${effort:-medium}"
fi
dir_basename=$(basename "$current_dir")

# Continuous color: lerp through green(136,192,145) → gold(222,196,132) → red(226,135,135)
# Input: percentage 0-100, output: "r;g;b"
pct_to_color() {
    awk "BEGIN{
        t=$1/100; if(t<0)t=0; if(t>1)t=1;
        if(t<=0.5){
            s=t*2;
            r=100+s*(220-100); g=200+s*(200-200); b=120+s*(60-120)
        } else {
            s=(t-0.5)*2;
            r=220+s*(230-220); g=200+s*(80-200); b=60+s*(60-60)
        }
        printf \"%.0f;%.0f;%.0f\",r,g,b
    }"
}

# Separator
sep=$(printf '\033[38;2;87;126;137m|\033[0m')

# Git branch
git_info=""
if [ -d "$current_dir/.git" ]; then
    git_branch=$(cd "$current_dir" && git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    [ -n "$git_branch" ] && git_info=$(printf " %s \033[38;2;111;159;156m%s\033[0m" "$sep" "$git_branch")
fi

# Context progress bar (scaled to compact limit)
compact_limit=30
bar_width=10
if [ -n "$used_pct" ]; then
    fill_ratio=$(awk "BEGIN{v=$used_pct/$compact_limit; if(v>1)v=1; printf \"%.4f\",v}")
    filled=$(awk "BEGIN{printf \"%d\",$fill_ratio*$bar_width+0.5}")
    ratio_pct=$(awk "BEGIN{printf \"%.0f\",$fill_ratio*100}")

    bar=""
    i=0
    while [ $i -lt $bar_width ]; do
        if [ $i -lt $filled ]; then
            seg_pct=$(awk "BEGIN{printf \"%.0f\",($i+0.5)/$bar_width*100}")
            c=$(pct_to_color "$seg_pct")
            bar=$(printf "%s\033[38;2;%sm█\033[0m" "$bar" "$c")
        else
            bar=$(printf "%s\033[38;2;60;65;70m░\033[0m" "$bar")
        fi
        i=$(($i + 1))
    done

    pct_color=$(pct_to_color "$ratio_pct")
    token_info=$(printf "%s \033[38;2;%sm%.0f%%\033[0m" "$bar" "$pct_color" $used_pct)
else
    bar=""
    i=0
    while [ $i -lt $bar_width ]; do
        bar=$(printf "%s\033[38;2;60;65;70m░\033[0m" "$bar")
        i=$(($i + 1))
    done
    pct_color=$(pct_to_color 0)
    token_info=$(printf "%s \033[38;2;%sm0%%\033[0m" "$bar" "$pct_color")
fi

# Cost
cost_info=""
if [ -n "$cost_usd" ]; then
    cost_fmt=$(printf '%.2f' "$cost_usd")
    cost_info=$(printf " %s \033[38;2;178;164;200m\$%s\033[0m" "$sep" "$cost_fmt")
fi

# Rate limit (5h) — same continuous color
rate_info=""
if [ -n "$rate_5h" ]; then
    rate_int=$(printf "%.0f" $rate_5h)
    rate_color=$(pct_to_color "$rate_int")
    rate_info=$(printf " %s \033[38;2;%sm%d%% 5h\033[0m" "$sep" "$rate_color" "$rate_int")
fi

# Effort level
effort_info=$(printf " %s \033[38;2;255;120;120m⚡%s\033[0m" "$sep" "$effort")

# Output
printf "\033[38;2;225;163;111m%s\033[0m %s \033[38;2;222;196;132m%s\033[0m %s %s%s%s%s%s" \
    "$dir_basename" "$sep" "$model_name" "$sep" "$token_info" "$cost_info" "$rate_info" "$effort_info" "$git_info"

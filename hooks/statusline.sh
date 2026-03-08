#!/usr/bin/env bash
# Claude Code status line — gradient progress bars
# Shows: model, dir, git branch, context window, 5h usage (from API)

input=$(cat)

# --- Extract fields ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.cwd // ""')
dir_name=$(basename "$cwd")

# Context window
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

# Git branch
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks 2>/dev/null | grep -q true; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo "")
fi

# --- 5-hour usage from API (non-blocking, async refresh) ---
# Strategy: statusline ONLY reads from cache (never blocks on network).
# If cache is stale, a background process refreshes it for next render.
USAGE_CACHE="/tmp/claude-usage-cache.json"
USAGE_LOCK="/tmp/claude-usage-fetch.lock"
CACHE_TTL=60
CACHE_MAX_AGE=600  # 10min — don't display data older than this
usage_5h=""
usage_resets=""

# Background fetch: updates cache file, never blocks the statusline
bg_fetch_usage() {
    # Prevent concurrent fetches
    if [ -f "$USAGE_LOCK" ]; then
        local lock_age lock_mtime
        lock_mtime=$(stat -f %m "$USAGE_LOCK" 2>/dev/null || stat -c %Y "$USAGE_LOCK" 2>/dev/null || echo 0)
        lock_age=$(( $(date +%s) - lock_mtime ))
        # Stale lock (>30s) — remove and continue
        [ "$lock_age" -lt 30 ] && return
    fi
    echo $$ > "$USAGE_LOCK"

    local token kc_json
    # 1) macOS Keychain
    kc_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    # 2) Linux libsecret (GNOME Keyring / KWallet)
    [ -z "$kc_json" ] && kc_json=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
    if [ -n "$kc_json" ]; then
        token=$(echo "$kc_json" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
    # 3) Fall back to credentials file
    if [ -z "$token" ]; then
        local creds="$HOME/.claude/.credentials.json"
        [ -f "$creds" ] || { rm -f "$USAGE_LOCK"; return; }
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds" 2>/dev/null)
    fi
    if [ -z "$token" ]; then
        rm -f "$USAGE_LOCK"
        return
    fi

    local api_result
    api_result=$(curl -s --connect-timeout 2 --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.1.69" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ -n "$api_result" ] && echo "$api_result" | jq -e '.five_hour' &>/dev/null; then
        echo "$api_result" > "$USAGE_CACHE" 2>/dev/null
    fi
    rm -f "$USAGE_LOCK"
}

# Read from cache (instant, no network)
now=$(date +%s)
cache_is_fresh=false
if [ -f "$USAGE_CACHE" ]; then
    cache_mtime=$(stat -f %m "$USAGE_CACHE" 2>/dev/null || stat -c %Y "$USAGE_CACHE" 2>/dev/null || echo 0)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$CACHE_TTL" ]; then
        cache_is_fresh=true
    fi
    # Display from cache only if not too old
    if [ "$cache_age" -lt "$CACHE_MAX_AGE" ]; then
        usage_5h=$(jq -r '.five_hour.utilization // empty' "$USAGE_CACHE" 2>/dev/null)
        usage_resets=$(jq -r '.five_hour.resets_at // empty' "$USAGE_CACHE" 2>/dev/null)
    fi
fi

# If cache is stale or missing, trigger async background refresh
if ! $cache_is_fresh; then
    bg_fetch_usage &>/dev/null &
    disown 2>/dev/null
fi

# --- Colors ---
C_MODEL="\033[38;5;183m"
C_DIR="\033[38;5;117m"
C_GIT="\033[38;5;116m"
C_SEP="\033[38;5;240m"
C_LABEL="\033[38;5;250m"
C_R="\033[0m"

# Gradient: soft green -> green -> yellow-green -> yellow -> orange -> red -> dark red
bar_colors=(71 72 78 114 150 186 222 221 220 214 208 202 196 160 124 88)
BAR_W=20

build_bar() {
    local pct=$1 w=$BAR_W
    local filled=$(( pct * w / 100 ))
    [ "$filled" -gt "$w" ] && filled=$w
    local empty=$(( w - filled ))
    local bar="" nc=${#bar_colors[@]}

    for ((i = 0; i < filled; i++)); do
        local ci=$(( i * nc / w ))
        [ "$ci" -ge "$nc" ] && ci=$((nc - 1))
        bar+="\033[38;5;${bar_colors[$ci]}m\xe2\x96\x88"
    done
    for ((i = 0; i < empty; i++)); do
        bar+="\033[38;5;238m\xe2\x96\x91"
    done

    # Percentage color
    local pc=72
    [ "$pct" -ge 40 ] && pc=222
    [ "$pct" -ge 65 ] && pc=208
    [ "$pct" -ge 85 ] && pc=196

    printf "%b \033[38;5;${pc}m%d%%$C_R" "$bar" "$pct"
}

# Format context size
fmt_ctx() {
    local s=$1
    if [ "$s" -ge 1000000 ]; then
        echo "$(( s / 1000 / 1000 )).$(( s / 1000 % 1000 / 100 ))M"
    elif [ "$s" -ge 1000 ]; then
        echo "$(( s / 1000 ))k"
    else
        echo "$s"
    fi
}

# Format reset time as relative
fmt_resets() {
    local resets_at="$1"
    [ -z "$resets_at" ] && return
    # Strip microseconds and timezone offset, treat as UTC
    # "2026-03-05T13:00:00.293168+00:00" -> "2026-03-05T13:00:00"
    local clean
    clean=$(echo "$resets_at" | sed 's/\.[0-9]*//; s/[+-][0-9][0-9]:[0-9][0-9]$//; s/Z$//')
    local reset_epoch
    # macOS: TZ=UTC date -j -f, Linux: date -d (handles ISO natively)
    reset_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" +%s 2>/dev/null \
        || date -d "$resets_at" +%s 2>/dev/null) || return
    local diff=$(( reset_epoch - now ))
    [ "$diff" -le 0 ] && { echo "now"; return; }
    local h=$(( diff / 3600 )) m=$(( diff % 3600 / 60 ))
    if [ "$h" -gt 0 ]; then
        echo "${h}h${m}m"
    else
        echo "${m}m"
    fi
}

# --- Separator ---
sep="${C_SEP} \xe2\x94\x82 $C_R"

# --- Assemble (single line) ---
out="\xf0\x9f\xa7\xa0 ${C_MODEL}${model}${C_R}"

if [ -n "$dir_name" ]; then
    out+="${sep}\xf0\x9f\x93\x82 ${C_DIR}${dir_name}${C_R}"
fi

if [ -n "$git_branch" ]; then
    out+="${sep}${C_GIT}\xee\x82\xa0 ${git_branch}${C_R}"
fi

# Context bar
ctx_pct_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "$ctx_pct")
ctx_bar=$(build_bar "$ctx_pct_int")
ctx_fmt=$(fmt_ctx "$ctx_size")
out+="${sep}${C_LABEL}context${C_R} ${ctx_bar} ${C_LABEL}${ctx_fmt}${C_R}"

# 5-hour usage bar (from API)
if [ -n "$usage_5h" ]; then
    usage_pct=$(printf "%.0f" "$usage_5h" 2>/dev/null || echo "$usage_5h")
    usage_bar=$(build_bar "$usage_pct")
    resets_fmt=$(fmt_resets "$usage_resets")
    out+="${sep}${C_LABEL}5h${C_R} ${usage_bar}"
    [ -n "$resets_fmt" ] && out+=" ${C_LABEL}${resets_fmt}${C_R}"
fi

printf "%b" "$out"

#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Awesome Claude Code Configuration Installer
# https://github.com/Mizoreww/awesome-claude-code-config
# ============================================================

CLAUDE_DIR="$HOME/.claude"
REPO_URL="https://github.com/Mizoreww/awesome-claude-code-config"
VERSION_STAMP_FILE="$CLAUDE_DIR/.awesome-claude-code-config-version"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Retry wrapper: retry <max_attempts> <delay_seconds> <description> <command...>
# Returns 0 on success, 1 if all attempts fail.
retry() {
    local max_attempts="$1"; shift
    local delay="$1"; shift
    local description="$1"; shift
    local attempt=1

    while (( attempt <= max_attempts )); do
        if "$@" ; then
            return 0
        fi
        if (( attempt < max_attempts )); then
            warn "$description failed (attempt $attempt/$max_attempts), retrying in ${delay}s..."
            sleep "$delay"
        else
            warn "$description failed after $max_attempts attempts, skipping."
        fi
        (( attempt++ ))
    done
    return 1
}

# --- Remote install detection -------------------------------------------

detect_script_dir() {
    local candidate
    candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ -f "$candidate/CLAUDE.md" ]]; then
        # Running from a local clone
        SCRIPT_DIR="$candidate"
        REMOTE_MODE=false
    else
        # Remote mode: download tarball to temp dir
        REMOTE_MODE=true
        local tmpdir
        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT

        local version="${VERSION:-main}"
        # Sanitize VERSION to prevent command injection
        if [[ ! "$version" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            error "Invalid VERSION value: $version (only alphanumeric, dots, hyphens, underscores allowed)"
            exit 1
        fi
        local tarball_url="$REPO_URL/archive/refs/heads/${version}.tar.gz"
        # If version looks like a tag (v1.0.0), use tags URL
        if [[ "$version" =~ ^v[0-9] ]]; then
            tarball_url="$REPO_URL/archive/refs/tags/${version}.tar.gz"
        fi

        info "Remote mode: downloading $version..."
        local download_cmd
        if command -v curl &>/dev/null; then
            download_cmd="curl -fsSL $tarball_url"
        elif command -v wget &>/dev/null; then
            download_cmd="wget -qO- $tarball_url"
        else
            error "Neither curl nor wget found. Install one and retry."
            exit 1
        fi

        if ! retry 5 3 "Download source tarball" bash -c "$download_cmd | tar xz -C '$tmpdir' --strip-components=1"; then
            error "Failed to download source after retries. Cannot continue in remote mode."
            exit 1
        fi

        SCRIPT_DIR="$tmpdir"
        ok "Source downloaded to temporary directory"
    fi
}

# --- Version management -------------------------------------------------

get_source_version() {
    if [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]'
    else
        echo "unknown"
    fi
}

get_installed_version() {
    if [[ -f "$VERSION_STAMP_FILE" ]]; then
        cat "$VERSION_STAMP_FILE" | tr -d '[:space:]'
    else
        echo "not installed"
    fi
}

get_remote_version() {
    local url="https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/VERSION"
    local result=""
    _fetch_version() {
        if command -v curl &>/dev/null; then
            result="$(curl -fsSL "$url" 2>/dev/null | tr -d '[:space:]')"
        elif command -v wget &>/dev/null; then
            result="$(wget -qO- "$url" 2>/dev/null | tr -d '[:space:]')"
        else
            return 1
        fi
        [[ -n "$result" ]]
    }
    if retry 5 2 "Fetch remote version" _fetch_version; then
        echo "$result"
    else
        echo "unavailable"
    fi
}

show_version() {
    local source_ver installed_ver remote_ver
    source_ver="$(get_source_version)"
    installed_ver="$(get_installed_version)"
    remote_ver="$(get_remote_version)"

    echo "awesome-claude-code-config version info:"
    echo "  Source:    $source_ver"
    echo "  Installed: $installed_ver"
    echo "  Remote:    $remote_ver"

    if [[ "$installed_ver" != "not installed" && "$remote_ver" != "unavailable" \
          && "$installed_ver" != "$remote_ver" ]]; then
        warn "Update available: $installed_ver -> $remote_ver"
    fi
}

stamp_version() {
    local ver
    ver="$(get_source_version)"
    if [[ "$ver" != "unknown" ]]; then
        echo "$ver" > "$VERSION_STAMP_FILE"
    fi
}

# --- Helpers ------------------------------------------------------------

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Claude Code configuration files.

Running without options launches an interactive component selector.

Options:
    --all               Install everything (non-interactive)
    --uninstall         Remove all installed files
    --version           Show version info
    --dry-run           Show what would be installed without doing it
    --force             Skip confirmation prompts
    -h, --help          Show this help

Examples:
    $(basename "$0")                                 # Interactive selector
    $(basename "$0") --all                           # Install everything
    $(basename "$0") --uninstall                     # Uninstall everything
    $(basename "$0") --dry-run --all                 # Preview full install
    bash <(curl -fsSL $REPO_URL/raw/main/install.sh) --all  # Remote install
EOF
}

# --- Flags & state ------------------------------------------------------

DRY_RUN=false
INSTALL_ALL=false
EXPLICIT_ALL=false
INSTALL_WARNINGS=0
INSTALL_RULES=false
INSTALL_SKILLS=false
INSTALL_LESSONS=false
INSTALL_HOOKS=false
INSTALL_MCP=false
INSTALL_PLUGINS=false
INSTALL_CLAUDE_MD=false
INSTALL_SETTINGS=false
UNINSTALL=false
FORCE=false
SHOW_VERSION=false
INTERACTIVE=false
RULE_LANGS=()
RULE_LANGS_EXPLICIT=false
PLUGIN_GROUPS=()

# --- Plugin groups ------------------------------------------------------

PLUGINS_ESSENTIAL=(
    "everything-claude-code@everything-claude-code"
    "superpowers@claude-plugins-official"
    "code-review@claude-plugins-official"
    "context7@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "document-skills@anthropic-agent-skills"
    "playwright@claude-plugins-official"
    "feature-dev@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "frontend-design@claude-plugins-official"
    "example-skills@anthropic-agent-skills"
    "github@claude-plugins-official"
)

PLUGINS_CLAUDE_MEM=(
    "claude-mem@thedotmack"
)

PLUGINS_AI_RESEARCH=(
    "tokenization@ai-research-skills"
    "fine-tuning@ai-research-skills"
    "post-training@ai-research-skills"
    "inference-serving@ai-research-skills"
    "distributed-training@ai-research-skills"
    "optimization@ai-research-skills"
)

# --- Argument parsing ---------------------------------------------------

parse_args() {
    if [[ $# -eq 0 ]]; then
        # No args: interactive mode if terminal, else install all
        if [[ -t 0 && -t 1 ]]; then
            INTERACTIVE=true
        else
            INSTALL_ALL=true
        fi
        return
    fi

    local has_action=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)
                INSTALL_ALL=true
                EXPLICIT_ALL=true
                has_action=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                has_action=true
                shift
                ;;
            --version)
                SHOW_VERSION=true
                has_action=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                error "Run '$(basename "$0") --help' for available options."
                exit 1
                ;;
        esac
    done

    # Only modifier flags (--dry-run, --force) with no action
    if ! $has_action; then
        if [[ -t 0 && -t 1 ]]; then
            INTERACTIVE=true
        else
            INSTALL_ALL=true
        fi
    fi
}

# --- Interactive menu ---------------------------------------------------

interactive_menu() {
    # Item format: "label|description|default_on|id"
    local items=(
        "CLAUDE.md|Global instructions template|1|claude-md"
        "settings.json|Smart-merged Claude Code settings|1|settings"
        "Common rules|Coding style, git, security, testing|1|rules-common"
        "Hooks|StatusLine display hook|1|hooks"
        "Lessons template|Cross-session learning framework|1|lessons"
        "Custom skills|adversarial-review, paper-reading|1|skills"
        "Python rules|PEP 8, pytest, type hints, bandit|0|rules-python"
        "TypeScript rules|Zod, Playwright, immutability|0|rules-ts"
        "Go rules|gofmt, table-driven tests, gosec|0|rules-go"
        "Plugins (13)|superpowers, code-review, playwright, feature-dev...|1|plugins-essential"
        "claude-mem|Cross-session memory (~3k tokens/session)|0|plugins-claude-mem"
        "AI Research plugins|fine-tuning, inference, optimization...|0|plugins-ai-research"
        "Lark MCP server|Feishu/Lark integration|0|mcp"
    )

    local n=${#items[@]}
    local selected=()
    local cursor=0

    # Initialize selections from defaults
    local i
    for (( i=0; i<n; i++ )); do
        selected[$i]="$(echo "${items[$i]}" | cut -d'|' -f3)"
    done

    # Group definitions: start|end|label
    local groups=(
        "0|5|Core"
        "6|8|Language Rules  ${DIM}(only install what your projects need)${NC}"
        "9|11|Plugins"
        "12|12|MCP Servers"
    )

    # Save terminal state
    local saved_stty
    saved_stty=$(stty -g 2>/dev/null) || saved_stty=""

    _menu_cleanup() {
        [[ -n "$saved_stty" ]] && stty "$saved_stty" 2>/dev/null || stty echo 2>/dev/null || true
        tput cnorm 2>/dev/null || printf '\033[?25h'
    }
    trap '_menu_cleanup; exit 0' INT TERM

    _read_key() {
        local key
        IFS= read -r -s -n 1 key 2>/dev/null || true

        if [[ "$key" == $'\033' ]]; then
            local rest=""
            IFS= read -r -s -n 2 -t 1 rest 2>/dev/null || true
            case "$rest" in
                '[A') echo "UP" ;;
                '[B') echo "DOWN" ;;
                *)    echo "OTHER" ;;
            esac
            return
        fi

        case "$key" in
            '')     echo "ENTER" ;;
            ' ')    echo "SPACE" ;;
            a|A)    echo "ALL" ;;
            n|N)    echo "NONE" ;;
            d|D)    echo "DEFAULT" ;;
            q|Q)    echo "QUIT" ;;
            j|J)    echo "DOWN" ;;
            k|K)    echo "UP" ;;
            *)      echo "OTHER" ;;
        esac
    }

    _draw_menu() {
        printf '\033[H\033[J'

        echo ""
        echo -e "  ${BOLD}=========================================${NC}"
        echo -e "  ${BOLD}  Awesome Claude Code Config Installer${NC}"
        echo -e "  ${BOLD}  $(get_source_version)${NC}"
        echo -e "  ${BOLD}=========================================${NC}"
        echo ""
        echo -e "  ${DIM}↑↓ move  Enter select  a=all n=none d=defaults q=quit${NC}"
        echo ""

        for group_def in "${groups[@]}"; do
            local g_start g_end g_label
            g_start="$(echo "$group_def" | cut -d'|' -f1)"
            g_end="$(echo "$group_def" | cut -d'|' -f2)"
            g_label="$(echo "$group_def" | cut -d'|' -f3-)"

            echo -e "  ${CYAN}${g_label}${NC}"

            local j
            for (( j=g_start; j<=g_end; j++ )); do
                local label desc
                label="$(echo "${items[$j]}" | cut -d'|' -f1)"
                desc="$(echo "${items[$j]}" | cut -d'|' -f2)"

                local indicator="  "
                if [[ $j -eq $cursor ]]; then
                    indicator="${GREEN}>${NC} "
                fi

                local mark=" "
                if [[ ${selected[$j]} -eq 1 ]]; then
                    mark="${GREEN}x${NC}"
                fi

                if [[ $j -eq $cursor ]]; then
                    echo -e "  ${indicator}[${mark}] ${BOLD}$(printf '%-24s' "$label")${NC} ${DIM}${desc}${NC}"
                else
                    echo -e "  ${indicator}[${mark}] $(printf '%-24s' "$label") ${DIM}${desc}${NC}"
                fi
            done
            echo ""
        done

        # Submit button
        if [[ $cursor -eq $n ]]; then
            echo -e "  ${GREEN}>${NC}  ${BOLD}${GREEN}[ Submit ]${NC}"
        else
            echo -e "     ${DIM}[ Submit ]${NC}"
        fi
        echo ""
    }

    # Hide cursor, disable echo
    tput civis 2>/dev/null || printf '\033[?25l'
    stty -echo 2>/dev/null || true

    # Main loop
    while true; do
        _draw_menu

        local key
        key="$(_read_key)"

        case "$key" in
            UP)
                (( cursor > 0 )) && (( cursor-- )) || true
                ;;
            DOWN)
                (( cursor < n )) && (( cursor++ )) || true
                ;;
            ENTER|SPACE)
                if (( cursor == n )); then
                    # Submit
                    break
                else
                    selected[$cursor]=$(( 1 - ${selected[$cursor]} ))
                fi
                ;;
            ALL)
                for (( i=0; i<n; i++ )); do selected[$i]=1; done
                ;;
            NONE)
                for (( i=0; i<n; i++ )); do selected[$i]=0; done
                ;;
            DEFAULT)
                for (( i=0; i<n; i++ )); do
                    selected[$i]="$(echo "${items[$i]}" | cut -d'|' -f3)"
                done
                ;;
            QUIT)
                _menu_cleanup
                echo ""
                info "Cancelled."
                exit 0
                ;;
        esac
    done

    # Restore terminal
    _menu_cleanup
    trap - INT TERM

    # Map selections to install flags
    INSTALL_ALL=false
    RULE_LANGS_EXPLICIT=true

    for (( i=0; i<n; i++ )); do
        [[ ${selected[$i]} -eq 0 ]] && continue

        local item_id
        item_id="$(echo "${items[$i]}" | cut -d'|' -f4)"

        case "$item_id" in
            claude-md)           INSTALL_CLAUDE_MD=true ;;
            settings)            INSTALL_SETTINGS=true ;;
            rules-common)        INSTALL_RULES=true ;;
            hooks)               INSTALL_HOOKS=true ;;
            lessons)             INSTALL_LESSONS=true ;;
            skills)              INSTALL_SKILLS=true ;;
            rules-python)        INSTALL_RULES=true; RULE_LANGS+=("python") ;;
            rules-ts)            INSTALL_RULES=true; RULE_LANGS+=("typescript") ;;
            rules-go)            INSTALL_RULES=true; RULE_LANGS+=("golang") ;;
            plugins-essential)   INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("essential") ;;
            plugins-claude-mem)  INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("claude-mem") ;;
            plugins-ai-research) INSTALL_PLUGINS=true; PLUGIN_GROUPS+=("ai-research") ;;
            mcp)                 INSTALL_MCP=true ;;
        esac
    done
}

# --- Confirm prompt (respects --force) ----------------------------------

confirm() {
    local prompt="${1:-Continue?}"
    if $FORCE; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        error "Non-interactive shell detected. Use --force to skip confirmation."
        exit 1
    fi
    echo -en "${YELLOW}${prompt} [y/N] ${NC}"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]]
}

# --- Install functions --------------------------------------------------

install_claude_md() {
    info "Installing CLAUDE.md..."
    if $DRY_RUN; then
        info "Would copy: CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"
    else
        cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
        ok "CLAUDE.md installed"
    fi
}

install_settings() {
    info "Installing settings.json..."
    if [[ ! -f "$CLAUDE_DIR/settings.json" ]]; then
        # New file: just copy
        if $DRY_RUN; then
            info "Would copy: settings.json -> $CLAUDE_DIR/settings.json"
        else
            cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
            ok "settings.json installed (new)"
        fi
        return
    fi

    # File exists: smart merge with jq if available
    if ! command -v jq &>/dev/null; then
        warn "settings.json already exists and jq is not installed"
        warn "  Cannot perform smart merge. Please merge manually:"
        warn "  Source: $SCRIPT_DIR/settings.json"
        warn "  Target: $CLAUDE_DIR/settings.json"
        (( INSTALL_WARNINGS++ )) || true
        return
    fi

    if $DRY_RUN; then
        info "Would smart-merge settings.json (jq available)"
        info "  - env: incoming as defaults, existing overrides"
        info "  - permissions.allow: union of arrays"
        info "  - enabledPlugins: merged, existing keys take priority"
        info "  - hooks.SessionStart: deduplicated by matcher"
        info "  - statusLine: incoming takes priority"
        return
    fi

    local existing="$CLAUDE_DIR/settings.json"
    local incoming="$SCRIPT_DIR/settings.json"
    local merged
    merged="$(mktemp)"

    jq -s '
    def unique_array: [.[] | tostring] | unique | [.[] | fromjson? // .];

    # $base = incoming (defaults), $over = existing (user overrides)
    .[0] as $base | .[1] as $over |

    # env: incoming as defaults, existing overrides
    ($base.env // {}) * ($over.env // {}) as $env |

    # permissions.allow: union
    (($base.permissions.allow // []) + ($over.permissions.allow // []) | unique) as $allow |

    # enabledPlugins: merge, existing wins
    (($base.enabledPlugins // {}) * ($over.enabledPlugins // {})) as $plugins |

    # hooks.SessionStart: deduplicate by matcher
    (
      (($base.hooks.SessionStart // []) + ($over.hooks.SessionStart // []))
      | group_by(.matcher)
      | map(last)
    ) as $session_hooks |

    # Build merged object: start with incoming, overlay existing, then set merged fields
    ($base * $over) * {
      env: $env,
      enabledPlugins: $plugins,
      statusLine: ($base.statusLine // null),
      permissions: (($base.permissions // {}) * ($over.permissions // {}) + {allow: $allow}),
      hooks: (($base.hooks // {}) * ($over.hooks // {}) + {SessionStart: $session_hooks})
    }
    ' "$incoming" "$existing" > "$merged"

    if jq empty "$merged" 2>/dev/null; then
        mv "$merged" "$existing"
        ok "settings.json smart-merged"
    else
        rm -f "$merged"
        error "Merge produced invalid JSON — keeping existing file"
        warn "Please merge manually: $incoming -> $existing"
        (( INSTALL_WARNINGS++ )) || true
    fi
}

install_rules() {
    info "Installing rules..."
    mkdir -p "$CLAUDE_DIR/rules"

    # Always install common rules when any rules are selected
    if $DRY_RUN; then
        info "Would copy: rules/common/ -> $CLAUDE_DIR/rules/common/"
    else
        rm -rf "$CLAUDE_DIR/rules/common"
        cp -r "$SCRIPT_DIR/rules/common" "$CLAUDE_DIR/rules/common"
        ok "Common rules installed"
    fi

    # Determine which language rules to install
    local langs=()
    if [[ ${#RULE_LANGS[@]} -gt 0 ]]; then
        langs=("${RULE_LANGS[@]}")
    elif ! $RULE_LANGS_EXPLICIT; then
        # Auto-detect: install all available languages (--all mode or legacy)
        for lang_dir in "$SCRIPT_DIR"/rules/*/; do
            local lang
            lang=$(basename "$lang_dir")
            [[ "$lang" == "common" || "$lang" == "README.md" ]] && continue
            langs+=("$lang")
        done
    fi
    # If RULE_LANGS_EXPLICIT=true and RULE_LANGS is empty, skip language rules

    for lang in "${langs[@]}"; do
        if [[ -d "$SCRIPT_DIR/rules/$lang" ]]; then
            if $DRY_RUN; then
                info "Would copy: rules/$lang/ -> $CLAUDE_DIR/rules/$lang/"
            else
                rm -rf "$CLAUDE_DIR/rules/$lang"
                cp -r "$SCRIPT_DIR/rules/$lang" "$CLAUDE_DIR/rules/$lang"
                ok "$lang rules installed"
            fi
        else
            error "Language rules not found: $lang"
        fi
    done

    # Clean up language rule dirs that were NOT selected (from previous installs)
    if $RULE_LANGS_EXPLICIT; then
        for existing_dir in "$CLAUDE_DIR"/rules/*/; do
            [[ -d "$existing_dir" ]] || continue
            local dir_name
            dir_name=$(basename "$existing_dir")
            [[ "$dir_name" == "common" ]] && continue

            local keep=false
            for lang in "${langs[@]}"; do
                if [[ "$lang" == "$dir_name" ]]; then
                    keep=true
                    break
                fi
            done

            if ! $keep; then
                if $DRY_RUN; then
                    info "Would remove unselected: $CLAUDE_DIR/rules/$dir_name/"
                else
                    rm -rf "$existing_dir"
                    ok "Removed unselected rules: $dir_name"
                fi
            fi
        done
    fi

    if $DRY_RUN; then
        info "Would copy: rules/README.md -> $CLAUDE_DIR/rules/README.md"
    else
        cp "$SCRIPT_DIR/rules/README.md" "$CLAUDE_DIR/rules/README.md"
    fi
}

install_skills() {
    info "Installing custom skills..."
    mkdir -p "$CLAUDE_DIR/skills"

    for skill_dir in "$SCRIPT_DIR"/skills/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill
        skill=$(basename "$skill_dir")

        if $DRY_RUN; then
            info "Would copy: skills/$skill/ -> $CLAUDE_DIR/skills/$skill/"
        else
            rm -rf "$CLAUDE_DIR/skills/$skill"
            cp -r "$skill_dir" "$CLAUDE_DIR/skills/$skill"
            ok "Skill installed: $skill"
        fi
    done
}

install_lessons() {
    info "Installing lessons.md template..."
    local target="$CLAUDE_DIR/lessons.md"

    if [[ -f "$target" ]]; then
        warn "lessons.md already exists -- skipping"
    else
        if $DRY_RUN; then
            info "Would copy: lessons.md -> $target"
        else
            cp "$SCRIPT_DIR/lessons.md" "$target"
            ok "lessons.md template installed to $target"
        fi
    fi
}

install_hooks() {
    info "Installing hooks..."
    mkdir -p "$CLAUDE_DIR/hooks"

    for hook_file in "$SCRIPT_DIR"/hooks/*; do
        [[ -f "$hook_file" ]] || continue
        local fname
        fname=$(basename "$hook_file")
        if $DRY_RUN; then
            info "Would copy: hooks/$fname -> $CLAUDE_DIR/hooks/$fname"
        else
            cp "$hook_file" "$CLAUDE_DIR/hooks/$fname"
            chmod +x "$CLAUDE_DIR/hooks/$fname"
            ok "Hook installed: $fname"
        fi
    done
}

install_mcp() {
    info "Installing MCP servers..."

    if ! command -v claude &>/dev/null; then
        error "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return 1
    fi

    # Lark MCP
    if $DRY_RUN; then
        info "Would add MCP server: lark-mcp (stdio)"
    else
        if retry 5 3 "Add MCP server lark-mcp" claude mcp add --scope user --transport stdio lark-mcp \
            -- npx -y @larksuiteoapi/lark-mcp mcp -a YOUR_APP_ID -s YOUR_APP_SECRET 2>/dev/null; then
            ok "MCP server added: lark-mcp"
        else
            warn "MCP server lark-mcp may already exist or could not be added, skipping"
        fi
        warn "Replace YOUR_APP_ID and YOUR_APP_SECRET with your Feishu credentials"
    fi
}

install_plugins() {
    if ! command -v claude &>/dev/null; then
        error "Claude Code CLI not found. Install it first: https://claude.com/claude-code"
        return 1
    fi

    # Collect plugins from all selected groups
    local plugins=()
    for group in "${PLUGIN_GROUPS[@]}"; do
        case "$group" in
            essential|core)
                plugins+=("${PLUGINS_ESSENTIAL[@]}")
                ;;
            claude-mem)
                plugins+=("${PLUGINS_CLAUDE_MEM[@]}")
                ;;
            ai-research)
                plugins+=("${PLUGINS_AI_RESEARCH[@]}")
                ;;
            all)
                plugins+=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}")
                ;;
        esac
    done

    # Deduplicate
    local unique_plugins=()
    local seen=""
    for entry in "${plugins[@]}"; do
        if [[ "$seen" != *"|$entry|"* ]]; then
            unique_plugins+=("$entry")
            seen="$seen|$entry|"
        fi
    done
    plugins=("${unique_plugins[@]}")

    local group_names
    group_names="$(IFS=','; echo "${PLUGIN_GROUPS[*]}")"
    info "Installing plugins (groups: $group_names)..."

    # Collect required marketplaces from selected plugins
    local marketplace_list=(
        "anthropic-agent-skills|anthropics/skills"
        "everything-claude-code|affaan-m/everything-claude-code"
        "ai-research-skills|zechenzhangAGI/AI-research-SKILLs"
        "claude-plugins-official|anthropics/claude-plugins-official"
        "thedotmack|thedotmack/claude-mem"
    )

    # Build set of needed marketplaces (bash 3.2 compatible, no associative arrays)
    local needed_marketplaces=""
    for entry in "${plugins[@]}"; do
        local marketplace="${entry##*@}"
        needed_marketplaces="$needed_marketplaces|$marketplace|"
    done

    # Step 1: Add required marketplaces
    info "Adding marketplaces..."
    for entry in "${marketplace_list[@]}"; do
        local marketplace="${entry%%|*}"
        local repo="${entry##*|}"
        [[ "$needed_marketplaces" != *"|$marketplace|"* ]] && continue
        if $DRY_RUN; then
            info "Would add marketplace: $marketplace (github.com/$repo)"
        else
            if retry 5 3 "Add marketplace $marketplace" claude plugin marketplace add "https://github.com/$repo" 2>/dev/null; then
                ok "Marketplace added: $marketplace"
            else
                warn "Marketplace $marketplace may already exist or could not be added"
            fi
        fi
    done

    # Step 2: Install plugins
    info "Installing ${#plugins[@]} plugins..."
    for entry in "${plugins[@]}"; do
        local plugin_name="${entry%%@*}"
        local marketplace="${entry##*@}"
        if $DRY_RUN; then
            info "Would install plugin: $plugin_name from $marketplace"
        else
            if retry 5 3 "Install plugin $plugin_name" claude plugin install "${plugin_name}@${marketplace}" 2>/dev/null; then
                ok "Plugin installed: $plugin_name"
            else
                warn "Plugin $plugin_name could not be installed, skipping"
                (( INSTALL_WARNINGS++ )) || true
            fi
        fi
    done
}

# --- Uninstall ----------------------------------------------------------

uninstall() {
    echo ""
    warn "The following will be removed:"
    echo "  - $CLAUDE_DIR/CLAUDE.md"
    echo "  - $CLAUDE_DIR/settings.json (backed up first)"
    echo "  - $CLAUDE_DIR/rules/"
    echo "  - $CLAUDE_DIR/skills/ (installer-managed only)"
    echo "  - $CLAUDE_DIR/lessons.md"
    echo "  - $CLAUDE_DIR/hooks/ (installer-managed only)"
    echo "  - Installed plugins (requires claude CLI)"
    echo "  - MCP server: lark-mcp (requires claude CLI)"
    [[ -f "$VERSION_STAMP_FILE" ]] && echo "  - $VERSION_STAMP_FILE"
    echo ""

    if $DRY_RUN; then
        warn "DRY RUN -- nothing will be removed"
        return
    fi

    if ! confirm "Proceed with uninstall?"; then
        info "Cancelled."
        exit 0
    fi

    rm -f "$CLAUDE_DIR/CLAUDE.md" && ok "Removed CLAUDE.md"

    if [[ -f "$CLAUDE_DIR/settings.json" ]]; then
        cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
        ok "Backed up settings.json -> settings.json.bak"
        rm -f "$CLAUDE_DIR/settings.json" && ok "Removed settings.json"
    fi

    rm -rf "$CLAUDE_DIR/rules" && ok "Removed rules/"

    # Only remove skills that ship with this repo
    if [[ -d "$SCRIPT_DIR/skills" ]]; then
        for skill_dir in "$SCRIPT_DIR"/skills/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill
            skill=$(basename "$skill_dir")
            rm -rf "$CLAUDE_DIR/skills/$skill" && ok "Removed skill: $skill"
        done
    else
        rm -rf "$CLAUDE_DIR/skills" && ok "Removed skills/"
    fi

    rm -f "$CLAUDE_DIR/lessons.md" && ok "Removed lessons.md"

    # Only remove hooks that ship with this repo
    if [[ -d "$SCRIPT_DIR/hooks" ]]; then
        for hook_file in "$SCRIPT_DIR"/hooks/*; do
            [[ -f "$hook_file" ]] || continue
            local fname
            fname=$(basename "$hook_file")
            rm -f "$CLAUDE_DIR/hooks/$fname" && ok "Removed hook: $fname"
        done
    else
        rm -rf "$CLAUDE_DIR/hooks" && ok "Removed hooks/"
    fi

    if command -v claude &>/dev/null; then
        local all_plugins=("${PLUGINS_ESSENTIAL[@]}" "${PLUGINS_CLAUDE_MEM[@]}" "${PLUGINS_AI_RESEARCH[@]}")
        for entry in "${all_plugins[@]}"; do
            local plugin_name="${entry%%@*}"
            claude plugin uninstall "$entry" 2>/dev/null && \
                ok "Uninstalled plugin: $plugin_name" || \
                warn "Could not uninstall: $plugin_name"
        done
        claude mcp remove lark-mcp 2>/dev/null && \
            ok "Removed MCP server: lark-mcp" || \
            warn "Could not remove lark-mcp"
    else
        warn "Claude CLI not found — cannot uninstall plugins or MCP servers"
    fi

    rm -f "$VERSION_STAMP_FILE"
    echo ""
    ok "Uninstall complete."
}

# --- Main ---------------------------------------------------------------

main() {
    detect_script_dir
    parse_args "$@"

    # Handle --version
    if $SHOW_VERSION; then
        show_version
        exit 0
    fi

    # Handle --uninstall
    if $UNINSTALL; then
        echo ""
        echo "========================================="
        echo "  Claude Code Config — Uninstaller"
        echo "========================================="
        uninstall
        exit 0
    fi

    # Interactive mode: show menu first
    if $INTERACTIVE; then
        interactive_menu
    fi

    # --all mode: set all flags
    if $INSTALL_ALL; then
        INSTALL_CLAUDE_MD=true
        INSTALL_SETTINGS=true
        INSTALL_RULES=true
        INSTALL_SKILLS=true
        INSTALL_LESSONS=true
        INSTALL_HOOKS=true
        INSTALL_PLUGINS=true
        if $EXPLICIT_ALL; then
            # Explicit --all: install everything including MCP and all plugin groups
            INSTALL_MCP=true
            PLUGIN_GROUPS=("all")
        else
            # Implicit (non-TTY fallback): essential plugins only, no MCP
            PLUGIN_GROUPS=("essential")
        fi
    fi

    # Check if anything was selected
    if ! $INSTALL_CLAUDE_MD && ! $INSTALL_SETTINGS && ! $INSTALL_RULES && \
       ! $INSTALL_SKILLS && ! $INSTALL_LESSONS && ! $INSTALL_HOOKS && \
       ! $INSTALL_PLUGINS && ! $INSTALL_MCP; then
        warn "Nothing selected to install."
        exit 0
    fi

    echo ""
    echo "========================================="
    echo "  Awesome Claude Code Config Installer"
    echo "  $(get_source_version)"
    echo "========================================="
    echo ""

    if $DRY_RUN; then
        warn "DRY RUN MODE -- no changes will be made"
        echo ""
    fi

    local installed_ver
    installed_ver="$(get_installed_version)"
    if [[ "$installed_ver" != "not installed" ]]; then
        info "Upgrading from $installed_ver -> $(get_source_version)"
    fi

    mkdir -p "$CLAUDE_DIR"

    $INSTALL_CLAUDE_MD && install_claude_md
    $INSTALL_SETTINGS && install_settings
    $INSTALL_RULES && install_rules
    $INSTALL_SKILLS && install_skills
    $INSTALL_LESSONS && install_lessons
    $INSTALL_HOOKS && install_hooks
    $INSTALL_MCP && install_mcp
    $INSTALL_PLUGINS && install_plugins

    # Stamp version (skip if there were critical warnings)
    if ! $DRY_RUN; then
        if [[ $INSTALL_WARNINGS -eq 0 ]]; then
            stamp_version
        else
            warn "Skipping version stamp due to $INSTALL_WARNINGS warning(s)"
        fi
    fi

    echo ""
    if [[ $INSTALL_WARNINGS -gt 0 ]]; then
        warn "Installation completed with $INSTALL_WARNINGS warning(s) — review messages above"
    else
        ok "Installation complete! ($(get_source_version))"
    fi
    echo ""
    info "Next steps:"
    echo "  1. Restart Claude Code for changes to take effect"
    echo "  2. Customize CLAUDE.md for your specific projects"
    if $INSTALL_MCP; then
        echo "  3. Replace YOUR_APP_ID/YOUR_APP_SECRET in Lark MCP config"
    fi
    echo ""
}

main "$@"

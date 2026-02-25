# Claude Code Configuration

A comprehensive, production-ready configuration for [Claude Code](https://claude.com/claude-code) — Anthropic's official CLI for Claude.

This repository contains a complete setup including global instructions, multi-language coding rules, custom skills, MCP server integrations, plugin marketplace management, and a self-improvement loop that learns from corrections across sessions.

## What's Included

```
.
├── CLAUDE.md                    # Global instructions (main config)
├── settings.json                # Claude Code settings (permissions, plugins, model)
├── rules/                       # Multi-language coding standards
│   ├── README.md                # Rules installation guide
│   ├── common/                  # Language-agnostic principles
│   │   ├── coding-style.md      #   Immutability, file organization, error handling
│   │   ├── git-workflow.md      #   Commit format, PR workflow, feature workflow
│   │   ├── testing.md           #   80% coverage, TDD workflow
│   │   ├── performance.md       #   Model selection, context management
│   │   ├── patterns.md          #   Repository pattern, API response format
│   │   ├── hooks.md             #   Pre/Post tool hooks, auto-accept
│   │   ├── agents.md            #   Agent orchestration, parallel execution
│   │   └── security.md          #   Security checks, secret management
│   ├── typescript/              # TypeScript/JavaScript specific
│   ├── python/                  # Python specific
│   └── golang/                  # Go specific
├── mcp/                         # MCP server configurations
│   ├── README.md                # MCP installation & usage guide
│   └── mcp-servers.json         # Server definitions (Context7, GitHub, Playwright)
├── plugins/                     # Plugin marketplace configurations
│   └── README.md                # Plugin installation guide (9 plugins, 5 marketplaces)
├── skills/                      # Custom skills
│   └── paper-reading/
│       └── SKILL.md             # Research paper summarization skill
├── memory/                      # Cross-session memory templates
│   ├── MEMORY.md                # Memory index template
│   └── lessons.md               # Self-correction log template
└── install.sh                   # One-command installer
```

## Quick Start

### Option 1: Install Everything

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-config.git
cd claude-code-config
./install.sh
```

### Option 2: Install Selectively

```bash
./install.sh --rules python typescript  # Rules only
./install.sh --mcp                      # MCP servers only
./install.sh --plugins                  # Plugins only
./install.sh --mcp --plugins            # MCP + Plugins
./install.sh --dry-run                  # Preview all changes
```

### Option 3: Manual Installation

```bash
# 1. Copy global instructions
cp CLAUDE.md ~/.claude/CLAUDE.md

# 2. Merge settings (review first — do NOT overwrite blindly)
cat settings.json

# 3. Install rules (common is required, languages are optional)
cp -r rules/common ~/.claude/rules/common
cp -r rules/python ~/.claude/rules/python
cp -r rules/typescript ~/.claude/rules/typescript
cp -r rules/golang ~/.claude/rules/golang

# 4. Install skills
cp -r skills/paper-reading ~/.claude/skills/paper-reading

# 5. Install MCP servers
claude mcp add --scope user --transport stdio context7 -- npx -y @upstash/context7-mcp@latest
claude mcp add --scope user --transport http github https://api.githubcopilot.com/mcp/
claude mcp add --scope user --transport stdio playwright -- npx -y @playwright/mcp@latest

# 6. Install plugins (see plugins/README.md for full list)
claude plugin marketplace add https://github.com/obra/superpowers-marketplace
claude plugin install superpowers --marketplace superpowers-marketplace
# ... see plugins/README.md for all plugins
```

## Architecture

### Layered Rules System

Inspired by [OpenAI Codex's AGENTS.md](https://developers.openai.com/codex/guides/agents-md/) hierarchical approach, rules are organized in layers:

```
common/          → Universal principles (always loaded)
  ↓ extended by
python/          → Python-specific (PEP 8, pytest, black, bandit)
typescript/      → TypeScript-specific (Zod, Playwright, Prettier)
golang/          → Go-specific (gofmt, table-driven tests, gosec)
```

Each language file explicitly extends its common counterpart. This avoids duplication while allowing language-specific overrides.

### Self-Improvement Loop

The key differentiator: Claude Code **learns from corrections** across sessions.

```
User corrects Claude → Claude writes to memory/lessons.md
                           ↓
Next session starts  → Claude reviews lessons.md
                           ↓
Pattern confirmed    → Rule promoted to CLAUDE.md
```

This creates a feedback loop where recurring mistakes are permanently eliminated.

### Memory System

```
~/.claude/projects/<project>/memory/
├── MEMORY.md      # Index file — loaded into every conversation
└── lessons.md     # Correction log — reviewed at session start
```

## MCP Servers

Three recommended MCP servers for maximum productivity:

| Server | Transport | Purpose |
|--------|-----------|---------|
| **[Context7](https://github.com/upstash/context7)** | stdio | Injects up-to-date library docs into context — no more outdated API suggestions |
| **[GitHub](https://github.com/github/github-mcp-server)** | http | PR/Issue management, code review, CI/CD — all from Claude Code |
| **[Playwright](https://github.com/anthropics/anthropic-quickstarts)** | stdio | Browser automation, E2E testing, screenshots |

See [`mcp/README.md`](mcp/README.md) for detailed installation and configuration.

## Plugins

9 plugins across 5 marketplaces, covering development workflows, document creation, and ML/AI research:

| Category | Plugins | Marketplace |
|----------|---------|-------------|
| **Dev Workflows** | superpowers, everything-claude-code | obra, affaan-m |
| **Documents** | document-skills, example-skills | anthropics/skills |
| **ML/AI Research** | fine-tuning, post-training, inference-serving, distributed-training, optimization | zechenzhangAGI |

See [`plugins/README.md`](plugins/README.md) for the full list with installation commands.

## Key Features

| Feature | Description |
|---------|-------------|
| **Self-Improvement Loop** | Automatically records corrections and learns from them |
| **Plan Mode First** | Non-trivial tasks (3+ steps) always start in plan mode |
| **Subagent Strategy** | Offload research/exploration to subagents, keep main context clean |
| **Autonomous Bug Fixing** | Given a bug report, fix it directly without hand-holding |
| **Verification Before Done** | Never mark complete without proving it works |
| **80% Test Coverage** | TDD workflow enforced: RED → GREEN → REFACTOR |
| **Multi-Language Rules** | Python, TypeScript, Go — extensible to any language |
| **MCP Integration** | Context7 + GitHub + Playwright recommended stack |
| **Plugin Ecosystem** | 9 plugins for dev workflows, docs, and ML research |
| **Bypass Permissions** | All tools auto-allowed for maximum speed (opt-in) |

## Customization

### Adding a New Language

1. Create `rules/<language>/` directory
2. Add files extending common rules: `coding-style.md`, `testing.md`, `patterns.md`, `hooks.md`, `security.md`
3. Each file should start with:
   ```
   > This file extends [common/xxx.md](../common/xxx.md) with <Language> specific content.
   ```

### Creating Custom Skills

Place skill files in `skills/<skill-name>/SKILL.md`. See `skills/paper-reading/SKILL.md` for the format.

### Adapting CLAUDE.md

The `CLAUDE.md` file is the most personal — adapt it to your:
- Shell environment (bash/zsh/fish)
- Package manager (conda/pip/uv/npm/pnpm)
- Project context (web dev, ML, robotics, etc.)
- Communication preferences

### Adding More MCP Servers

```bash
# Sentry — Error monitoring
claude mcp add --scope user --transport http sentry https://mcp.sentry.dev/mcp

# Database — PostgreSQL access
claude mcp add --scope user --transport stdio db -- npx -y @bytebase/dbhub \
  --dsn "postgresql://user:pass@host:5432/dbname"
```

## Acknowledgements

The **Workflow Orchestration** section in `CLAUDE.md` (Plan Mode Default, Subagent Strategy, Self-Improvement Loop, Verification Before Done, Demand Elegance, Autonomous Bug Fixing) is inspired by [**@OmerFarukOruc**](https://github.com/OmerFarukOruc)'s excellent [AI Agent Workflow Orchestration Guidelines](https://gist.github.com/OmerFarukOruc/a02a5883e27b5b52ce740cadae0e4d60). His work on structured agent workflows and the `tasks/lessons.md` self-improvement pattern was a key influence on this configuration.

## License

MIT

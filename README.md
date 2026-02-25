# Claude Code Configuration

A comprehensive, production-ready configuration for [Claude Code](https://claude.com/claude-code) — Anthropic's official CLI for Claude.

This repository contains a complete setup including global instructions, multi-language coding rules, custom skills, MCP integrations, plugin recommendations, and a self-improvement loop that learns from corrections across sessions.

## What's Included

```
.
├── CLAUDE.md                    # Global instructions (main config)
├── settings.json                # Claude Code settings
├── rules/                       # Multi-language coding standards
│   ├── README.md                # Installation guide
│   ├── common/                  # Language-agnostic principles
│   │   ├── coding-style.md
│   │   ├── git-workflow.md
│   │   ├── testing.md
│   │   ├── performance.md
│   │   ├── patterns.md
│   │   ├── hooks.md
│   │   ├── agents.md
│   │   └── security.md
│   ├── typescript/              # TypeScript/JavaScript specific
│   ├── python/                  # Python specific
│   └── golang/                  # Go specific
├── skills/                      # Custom skills
│   └── paper-reading/
│       └── SKILL.md
├── memory/                      # Cross-session memory templates
│   ├── MEMORY.md
│   └── lessons.md
└── install.sh                   # One-command installer
```

## Quick Start

### Option 1: Install Script

```bash
git clone https://github.com/YOUR_USERNAME/claude-code-config.git
cd claude-code-config

# Install everything
./install.sh

# Or install specific language rules only
./install.sh --rules python typescript
```

### Option 2: Manual Installation

```bash
# 1. Copy global instructions
cp CLAUDE.md ~/.claude/CLAUDE.md

# 2. Merge settings (review first!)
# WARNING: Do not overwrite — merge with your existing settings
cat settings.json  # Review, then manually merge

# 3. Install rules
cp -r rules/common ~/.claude/rules/common
cp -r rules/python ~/.claude/rules/python       # if needed
cp -r rules/typescript ~/.claude/rules/typescript # if needed
cp -r rules/golang ~/.claude/rules/golang         # if needed

# 4. Install skills
cp -r skills/paper-reading ~/.claude/skills/paper-reading

# 5. Set up memory directory
mkdir -p ~/.claude/projects/$(pwd | sed 's|/|-|g')/memory
cp memory/MEMORY.md memory/lessons.md ~/.claude/projects/$(pwd | sed 's|/|-|g')/memory/
```

### Option 3: MCP Servers (Recommended)

```bash
# Context7 — Injects up-to-date library documentation
claude mcp add --scope user --transport stdio context7 -- npx -y @upstash/context7-mcp@latest

# GitHub — Manage PRs, issues, code reviews from CLI
claude mcp add --scope user --transport http github https://api.githubcopilot.com/mcp/

# Playwright — Browser automation and E2E testing
claude mcp add --scope user --transport stdio playwright -- npx -y @playwright/mcp@latest
```

## Architecture

### Layered Rules System

Inspired by [OpenAI Codex's AGENTS.md](https://developers.openai.com/codex/guides/agents-md/) hierarchical approach, rules are organized in layers:

```
common/          → Universal principles (always loaded)
  ↓ extended by
python/          → Python-specific patterns (PEP 8, pytest, black)
typescript/      → TypeScript-specific patterns (Zod, Playwright, Prettier)
golang/          → Go-specific patterns (gofmt, table-driven tests, gosec)
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

## Recommended Plugins

These plugins are installed via Claude Code's plugin marketplace:

| Plugin | Marketplace | Purpose |
|--------|-------------|---------|
| superpowers | [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) | Brainstorming, debugging, code review workflows |
| everything-claude-code | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | TDD, security review, database patterns, and more |
| document-skills | [anthropics/skills](https://github.com/anthropics/skills) | PDF, DOCX, PPTX, XLSX document manipulation |
| ai-research-skills | [zechenzhangAGI/AI-research-SKILLs](https://github.com/zechenzhangAGI/AI-research-SKILLs) | Fine-tuning, inference serving, distributed training |

Install via:
```bash
claude plugin add <marketplace-url>
```

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

## License

MIT

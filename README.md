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

## Best Practices: Software Development Workflow

This section describes how all the tools in this configuration work together across every phase of development. Each phase shows which tools, skills, MCP servers, and rules are activated.

### Overview: The Full Pipeline

```
 Feature Request / Bug Report
          │
          ▼
 ┌─────────────────┐
 │  1. PLANNING     │  Skills: brainstorming, writing-plans, plan
 │                   │  Mode: Plan Mode (Shift+Tab ×2)
 │                   │  MCP: Context7 (lookup API docs)
 └────────┬──────────┘
          ▼
 ┌─────────────────┐
 │  2. TDD          │  Skills: test-driven-development, tdd, tdd-workflow
 │  Write tests     │  Rules: testing.md (80% coverage)
 │  first           │  Agent: tdd-guide
 └────────┬──────────┘
          ▼
 ┌─────────────────┐
 │  3. IMPLEMENT    │  Skills: coding-standards, *-patterns
 │                   │  Rules: coding-style.md, patterns.md
 │                   │  MCP: Context7 (live docs)
 └────────┬──────────┘
          ▼
 ┌─────────────────┐
 │  4. REVIEW       │  Skills: requesting-code-review, security-review
 │                   │  Skills: python-review, go-review
 │                   │  Rules: security.md
 └────────┬──────────┘
          ▼
 ┌─────────────────┐
 │  5. E2E TEST     │  Skills: e2e, webapp-testing
 │                   │  MCP: Playwright (browser automation)
 └────────┬──────────┘
          ▼
 ┌─────────────────┐
 │  6. COMMIT & PR  │  Rules: git-workflow.md
 │                   │  MCP: GitHub (create PR, manage issues)
 │                   │  Skill: verification-before-completion
 └────────┬──────────┘
          ▼
        Done ✓
```

---

### Phase 1: Planning

> "Measure twice, cut once." Never jump into code for non-trivial tasks.

**When**: Any task with 3+ steps, multi-file changes, or architectural decisions.

**How**:

```
You: "Add user authentication with JWT"

Claude auto-activates:
  1. /brainstorming          → Explore approaches (session vs JWT vs OAuth)
  2. /writing-plans          → Structured plan with phases and risks
  3. Plan Mode (Shift+Tab)   → Read-only exploration, no accidental edits
  4. Context7 MCP            → Pull latest docs for chosen libraries
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:brainstorming` | Generate and evaluate multiple approaches before committing |
| `superpowers:writing-plans` | Create step-by-step plan with checkpoints |
| `everything-claude-code:plan` | Restate requirements, assess risks, wait for confirmation |
| **Context7 MCP** | Look up current API docs for frameworks (e.g., NextAuth, Passport) |
| `rules/common/agents.md` | Dispatch parallel subagents for research if needed |

**Anti-pattern**: Jumping straight to `vim` or `code .` without a plan.

---

### Phase 2: Test-Driven Development

> Write the test first. Watch it fail. Then make it pass.

**When**: Every feature and every bug fix.

**How**:

```
Claude follows the TDD cycle:

  RED    → Write a failing test that defines the expected behavior
  GREEN  → Write minimal code to make the test pass
  REFACTOR → Clean up while keeping tests green
  VERIFY → Check coverage ≥ 80%
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:test-driven-development` | Enforces write-test-first discipline |
| `everything-claude-code:tdd` | Scaffold interfaces → generate tests → implement |
| `everything-claude-code:tdd-workflow` | Full TDD lifecycle management |
| `everything-claude-code:python-testing` | pytest fixtures, parametrize, mocking |
| `everything-claude-code:golang-testing` | Table-driven tests, race detection |
| `rules/common/testing.md` | 80% coverage minimum, test isolation |
| **Language-specific rules** | `python/testing.md`, `typescript/testing.md`, `golang/testing.md` |

**Anti-pattern**: Writing implementation first, then retroactively adding tests.

---

### Phase 3: Implementation

> Immutability, small files, small functions. Let Context7 handle the docs.

**When**: After tests are written (Phase 2) and the plan is approved (Phase 1).

**How**:

```
Claude writes code following:
  - Immutable data patterns (no mutation)
  - Small files (200-400 lines, 800 max)
  - Small functions (<50 lines)
  - Schema-based validation at boundaries
  - Context7 for latest API usage
```

**Tools activated**:

| Tool | Role |
|------|------|
| `rules/common/coding-style.md` | Immutability, file organization, error handling |
| `everything-claude-code:coding-standards` | Universal best practices |
| `everything-claude-code:python-patterns` | Pythonic idioms, type hints |
| `everything-claude-code:golang-patterns` | Idiomatic Go, interfaces, error wrapping |
| `everything-claude-code:frontend-patterns` | React, Next.js, state management |
| `everything-claude-code:backend-patterns` | API design, database optimization |
| `everything-claude-code:postgres-patterns` | Query optimization, indexing, schema design |
| **Context7 MCP** | Real-time documentation lookup — never use outdated APIs |
| `rules/common/patterns.md` | Repository pattern, API response envelope |

**Key rule**: If you're unsure about an API, ask Context7 before guessing.

---

### Phase 4: Code Review & Security

> Review immediately after writing. Don't wait for PR.

**When**: After any code is written or modified.

**How**:

```
Claude auto-triggers after implementation:
  1. Code review    → Style, correctness, edge cases
  2. Security scan  → OWASP Top 10, secrets, injection
  3. Language review → Python/Go/TS-specific checks
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:requesting-code-review` | Comprehensive review against requirements |
| `everything-claude-code:security-review` | Auth, input validation, secrets, XSS, CSRF |
| `everything-claude-code:python-review` | PEP 8, type hints, security, Pythonic idioms |
| `everything-claude-code:go-review` | Concurrency safety, error handling, idiomatic Go |
| `rules/common/security.md` | Pre-commit security checklist |
| **Language-specific security** | `python/security.md` (bandit), `golang/security.md` (gosec) |

**Severity handling**:
- **CRITICAL/HIGH** → Fix immediately, no exceptions
- **MEDIUM** → Fix when possible
- **LOW** → Note for future cleanup

**Anti-pattern**: Skipping review because "it's a small change."

---

### Phase 5: E2E Testing

> Trust, but verify. In a real browser.

**When**: Critical user flows, UI changes, API integration points.

**How**:

```
Claude uses Playwright MCP to:
  1. Navigate to the page
  2. Fill forms, click buttons
  3. Assert expected outcomes
  4. Capture screenshots as evidence
```

**Tools activated**:

| Tool | Role |
|------|------|
| `everything-claude-code:e2e` | Generate Playwright test journeys, run them, capture artifacts |
| `document-skills:webapp-testing` | Interact with and verify local web apps |
| **Playwright MCP** | Direct browser control — click, type, screenshot, assert |
| `rules/typescript/testing.md` | Playwright as E2E framework |

**Anti-pattern**: Only testing with unit tests and hoping the UI works.

---

### Phase 6: Git Workflow & PR

> Conventional commits. Comprehensive PRs. Verify before claiming done.

**When**: Code is reviewed, tests pass, ready to ship.

**How**:

```
1. Verify everything works        → /verification-before-completion
2. Stage specific files            → git add (never git add -A blindly)
3. Commit with conventional format → feat: / fix: / refactor: / test:
4. Push and create PR              → GitHub MCP handles it
5. PR includes summary + test plan
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:verification-before-completion` | Run tests, check logs, prove correctness before committing |
| `superpowers:finishing-a-development-branch` | Decide: merge, squash, or rebase |
| `superpowers:using-git-worktrees` | Isolate feature work from main workspace |
| `rules/common/git-workflow.md` | Commit format, PR checklist, branch strategy |
| **GitHub MCP** | Create PR, link issues, manage reviews — without leaving the terminal |

**Commit format**:
```
<type>: <description>

Types: feat, fix, refactor, docs, test, chore, perf, ci
```

---

### Phase 7: Debugging

> Reproduce → Isolate → Fix → Verify. No guessing.

**When**: Any bug, test failure, or unexpected behavior.

**How**:

```
Claude follows systematic debugging:
  1. Reproduce the issue with a minimal test case
  2. Form hypothesis about root cause
  3. Add diagnostic logging/assertions
  4. Fix the root cause (not symptoms)
  5. Verify fix with the reproduction test
  6. Check for similar issues elsewhere
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:systematic-debugging` | Structured debugging workflow — no guessing |
| `everything-claude-code:go-build` | Fix Go build errors, vet warnings incrementally |
| `rules/common/coding-style.md` | Error handling patterns |
| **Playwright MCP** | Debug UI issues visually with screenshots |
| **Context7 MCP** | Look up correct API usage when the bug is "wrong API call" |

**Anti-pattern**: Changing random things until tests pass.

---

### Parallel Execution

> Independent tasks should run concurrently, not sequentially.

**When**: 2+ tasks with no shared state or sequential dependency.

**How**:

```
Claude dispatches parallel subagents:
  Agent 1: Security review of auth module
  Agent 2: Unit tests for payment service
  Agent 3: E2E test for checkout flow
  ─── all run simultaneously ───
  Results merged when all complete
```

**Tools activated**:

| Tool | Role |
|------|------|
| `superpowers:dispatching-parallel-agents` | Identify and launch independent parallel tasks |
| `rules/common/agents.md` | Agent orchestration patterns |
| `settings.json` → `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | Enable multi-agent teams |

---

### Cross-Session Learning

> Every correction makes the system permanently smarter.

**How it works**:

```
Session 1: User corrects Claude → lesson saved to memory/lessons.md
Session 2: Claude reads lessons.md at start → avoids same mistake
Session N: Pattern confirmed across sessions → rule promoted to CLAUDE.md
```

**Tools activated**:

| Tool | Role |
|------|------|
| `CLAUDE.md` → Self-Improvement Loop | Core instruction to record and review lessons |
| `memory/lessons.md` | Persistent correction log |
| `memory/MEMORY.md` | Index of environment info and preferences |
| `everything-claude-code:continuous-learning` | Auto-extract reusable patterns from sessions |
| `everything-claude-code:continuous-learning-v2` | Instinct-based learning with confidence scores |

---

### Quick Reference: Which Tool for What

| I want to... | Use this |
|---|---|
| Plan a feature | `superpowers:brainstorming` → `superpowers:writing-plans` |
| Write tests first | `superpowers:test-driven-development` |
| Look up library docs | **Context7 MCP** |
| Review my code | `superpowers:requesting-code-review` |
| Check for security issues | `everything-claude-code:security-review` |
| Run E2E browser tests | `everything-claude-code:e2e` + **Playwright MCP** |
| Create a PR | **GitHub MCP** |
| Debug a failing test | `superpowers:systematic-debugging` |
| Run parallel tasks | `superpowers:dispatching-parallel-agents` |
| Fix build errors (Go) | `everything-claude-code:go-build` |
| Fix build errors (TS) | `everything-claude-code:coding-standards` |
| Create a PDF/DOCX/PPTX | `document-skills:pdf` / `docx` / `pptx` |
| Fine-tune a model | `fine-tuning:unsloth` or `fine-tuning:axolotl` |
| Deploy model inference | `inference-serving:vllm` or `inference-serving:sglang` |
| Read a research paper | `paper-reading` skill |
| Optimize model (quantize) | `optimization:awq` / `gptq` / `gguf` |

---

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

# Changelog

## [1.2.0] - 2026-03-09

### Features
- Tokenization skill added to AI Research group (huggingface-tokenizers, sentencepiece)
- Web search date instruction in AGENTS.md Workflow section
- Repo URLs updated from `claude-code-config` to `awesome-claude-code-config`

### Design Rationale
- Synced from main branch to keep shared content consistent across Claude Code and Codex configurations
- Web search date instruction uses `date '+%Y-%m-%d'` with web time API fallback (no Windows variant needed since Codex CLI is Linux/macOS only)

### Notes & Caveats
- One-line install URL also updated to canonical repo name
- Skill installer is best-effort: network failures downgrade to warnings rather than blocking install

## [1.1.0] - 2026-03-05

### Features
- Adversarial code review skill (cross-model review via opposite AI CLI)
- Version changelog policy in AGENTS.md
- Multi-agent roles (explorer, reviewer, docs_researcher)

### Design Rationale
- Adversarial review spawns reviewers on the opposite model's CLI for genuine cross-model challenge
- Changelog policy keeps design decisions traceable

### Notes & Caveats
- Adversarial review requires `claude` CLI installed for Codex users

## [1.0.0] - 2026-03-02

### Features
- Initial Codex branch with AGENTS.md, config.toml, and lessons-based self-improvement loop
- Skill-first installer with open-source ecosystem skills
- Paper-reading skill for structured research paper analysis
- MCP integration (Lark, Context7, GitHub, Playwright, OpenAI docs)

### Design Rationale
- Companion branch to Claude Code main config — shared principles, Codex-specific tooling
- `config.toml` + `model_instructions_file` for lessons injection at session start

### Notes & Caveats
- Requires Codex CLI; power-user defaults (`approval_policy = "never"`, `sandbox_mode = "danger-full-access"`)
- MCP credentials must be filled in manually

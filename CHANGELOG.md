# Changelog

## [1.6.0] - 2026-04-08

### Features
- Installer now refreshes `deepxiv-cli`, `deepxiv-baseline-table`, and `deepxiv-trending-digest` directly from `DeepXiv/deepxiv_sdk` on every install run
- Bash and PowerShell installers now remove existing DeepXiv skill directories before reinstalling them from upstream
- Installers now warn when the `deepxiv` CLI runtime is missing instead of attempting to install it automatically
- Documentation now describes DeepXiv as an install-time upstream dependency instead of a bundled local skill copy

### Design Rationale
- DeepXiv changes frequently enough that mirroring superpowers-style upstream installs is a better fit than snapshotting local copies in this repo
- Reinstalling the managed DeepXiv skills ensures repeat installs actually refresh to the latest upstream version instead of silently keeping stale copies

### Notes & Caveats
- DeepXiv skill refresh still depends on the skill installer being available and GitHub being reachable during install
- The `deepxiv` CLI itself is still a separate runtime dependency and must be installed on PATH by the user

## [1.5.0] - 2026-04-08

### Features
- Added bundled DeepXiv skills: `deepxiv-cli`, `deepxiv-baseline-table`, and `deepxiv-trending-digest`
- Installer uninstall tracking now includes the three DeepXiv skills on both bash and PowerShell paths
- README, Chinese README, and migration notes now document the new DeepXiv skill set and its CLI dependency

### Design Rationale
- DeepXiv's progressive paper-reading workflows complement the existing research-oriented Codex setup without requiring a separate plugin system
- Bundling the upstream skills directly in this repo keeps local installs reproducible and ensures the installer can copy them like other repo-local skills

### Notes & Caveats
- These skills expect the `deepxiv` CLI to already be installed and available on PATH, typically via `pip install deepxiv-sdk`

## [1.4.0] - 2026-03-20

### Features
- Added a bundled `update_config` skill for refreshing the installed Codex configuration from the `codex` branch
- Added a `docs/claude-main-to-codex-migration.md` reference mapping Claude Code main-branch concepts to Codex equivalents
- Normalized version-stamp handling so the PowerShell installer now writes the Codex-native stamp path while still reading the legacy fallback

### Design Rationale
- A dedicated migration document is clearer than restoring Claude-era top-level plugin/rules structures that no longer match the Codex branch architecture
- The update skill needs consistent version-stamp behavior across platforms to report installed vs remote versions correctly

### Notes & Caveats
- Existing Windows installs using the old `.claude-code-config-version` file continue to work because the installer and update skill now read both paths during transition

## [1.3.0] - 2026-03-11

### Features
- Installer now installs the full `obra/superpowers` repo via native skill discovery instead of copying only four skills
- Installer creates `~/.agents/skills/superpowers` symlink and removes the legacy partial superpowers copies from `~/.codex/skills`
- README and README.zh-CN now document the full superpowers installation model and native discovery paths

### Design Rationale
- Superpowers upstream now expects repo-level installation plus skill-directory symlinking; mirroring that upstream flow avoids partial installs such as missing `brainstorming`
- Keeping superpowers as its own cloned repo makes updates straightforward with `git pull` and preserves the full upstream skill set without curating individual directories

### Notes & Caveats
- Existing users with a non-git directory at `~/.codex/superpowers` will need to resolve that path manually before the installer can manage it
- If `~/.agents/skills/superpowers` already exists as a normal directory instead of a symlink, the installer warns and skips replacing it automatically

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

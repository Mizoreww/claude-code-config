# Global Instructions (Codex)

## Memory System (Highest Priority)

### Architecture

- `~/.codex/AGENTS.md`: global instructions, auto-loaded
- `~/.codex/lessons.md`: correction log, auto-loaded via `model_instructions_file`

### Self-Correction

**Identify corrections early**: user says something is wrong, says “remember / don't do this again”, expresses frustration, or same operation fails repeatedly.

**After a correction**:
1. Immediately write a lesson to `~/.codex/lessons.md` (date, context, mistake, rule)
2. Make the rule concrete and actionable
3. Continue task execution only after recording

## Core Settings

- Language: respond in user's preferred language; keep technical terms in English when appropriate
- Shell: zsh (`~/.zshrc`)

## Communication Preferences

- If user says a hypothesis is wrong, stop that direction immediately
- Prefer implementation over repetitive questioning

## Workflow

- Use explicit planning for non-trivial tasks
- Verify before marking done (tests/logs where applicable)
- Fix bugs directly and report what changed

## Rule Set

- Common + language-specific coding standards are provided via skills:
  - `claude-rules`
  - `python-patterns`, `golang-patterns`, `frontend-patterns`

## Paper Reading

- Use `paper-reading` skill for research paper tasks

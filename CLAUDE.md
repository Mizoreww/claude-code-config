# Global Instructions

## Thinking Mode

- Use ultrathink extended thinking mode by default

## Language Preferences

- All responses and explanations in the user's preferred language
- Code comments may use English
- Keep standard English for technical terms (API, Git, Docker, etc.)

## Shell Environment

- Default Shell: **Zsh**
- Config file: `~/.zshrc`

## Conda Environment Usage

**Important**: Before running any Python script, activate the conda environment:

```bash
# Conda path
CONDA_PATH="$HOME/anaconda3"

# List available environments
$HOME/anaconda3/bin/conda env list

# Activate environment (in Zsh)
source $HOME/anaconda3/etc/profile.d/conda.sh && conda activate <env_name>

# Or use the environment's Python directly
$HOME/anaconda3/envs/<env_name>/bin/python script.py
```

## Proxy & Network Configuration

- Remote server proxies are typically configured via SSH reverse port forwarding
- Do not modify `.bashrc`, `.profile`, or VSCode settings to configure proxies unless explicitly asked
- Standard approach: `ssh -R <remote_port>:127.0.0.1:<local_port>`, then set `http_proxy`/`https_proxy` to `http://127.0.0.1:<remote_port>`
- When no `sudo` access, prefer user-space installation methods

## Communication Preferences

- When the user explicitly says a cause is **not** the problem, **immediately stop** exploring that direction and pivot to other possibilities
- Prefer providing concrete code implementations over asking repeated questions. If the user has made the same request multiple times, just write the code with reasonable assumptions noted in comments

## Self-Improvement Loop

- After ANY correction from the user, **immediately** write the lesson to `memory/lessons.md`
- Record format: date, context, mistake, rule (specific rule to prevent recurrence)
- At the start of each session, review entries in `lessons.md` relevant to the current project
- Continuously iterate on these rules until the same class of mistakes no longer occurs
- If a rule proves universal (recurring across multiple sessions), promote it to `CLAUDE.md`

## Workflow Guidelines

- **Plan Mode First**: Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- **Re-plan on Deviation**: If implementation drifts from the plan, stop and re-plan — don't keep pushing
- **Subagent Strategy**: Use subagents for research, exploration, and parallel analysis to keep main context clean; one task per subagent
- **Verification Before Done**: Never mark a task complete without proving it works. Run tests, check logs, demonstrate correctness
- **Autonomous Bug Fixing**: When given a bug report, just fix it. Point at logs, errors, failing tests — then resolve them. Zero context switching required from the user

## Paper Reading Standards

When asked to read/summarize research papers:
1. Prefer HTML version from `ar5iv.labs.arxiv.org` (replace `arxiv.org/abs/` with `ar5iv.labs.arxiv.org/html/`)
2. Provide structured summary: problem definition, method, key contributions, architecture, experimental results
3. Include concrete examples and equations, not just abstract descriptions
4. If full content cannot be retrieved, say so immediately — don't repeatedly try failed approaches

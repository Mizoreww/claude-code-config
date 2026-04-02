---
name: update-config
description: Update awesome-claude-code-config to the latest version. Checks remote for new releases, then re-runs the installer with the interactive selector. Use when user types /update-config or asks to update their Claude Code configuration.
---

# Update — awesome-claude-code-config

## Overview

Check for updates and upgrade the installed configuration to the latest version.

## Workflow

Run the following steps **in order**. Stop immediately if a step fails. Do NOT ask for
confirmation between steps — just execute.

### Step 1: Check versions

```bash
# Installed version
INSTALLED="$(cat ~/.claude/.awesome-claude-code-config-version 2>/dev/null || echo 'not installed')"

# Remote version
REMOTE="$(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/VERSION 2>/dev/null | tr -d '[:space:]')"

echo "Installed: $INSTALLED"
echo "Remote:    $REMOTE"
```

If `INSTALLED` equals `REMOTE`, tell the user they are already on the latest version and stop.

If the remote fetch fails, warn the user and stop.

### Step 2: Run the installer (remote mode)

Download and execute the latest installer interactively:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Mizoreww/awesome-claude-code-config/main/install.sh)
```

This launches the interactive component selector. The installer handles:
- Smart merging of `settings.json` (preserves user customizations)
- Version stamping
- Font and dependency installation
- Plugin updates

### Step 3: Report result

After the installer finishes, confirm the new version:

```bash
cat ~/.claude/.awesome-claude-code-config-version 2>/dev/null
```

Tell the user the update is complete with the new version number.

## Notes

- The installer's smart merge preserves existing `settings.json` customizations
- `lessons.md` is never overwritten if it already exists
- Plugins are re-installed (idempotent — existing ones are skipped)
- User should restart Claude Code after updating for changes to take effect

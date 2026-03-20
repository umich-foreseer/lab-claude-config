# Lab Claude Code Configuration

Shared Claude Code setup for the lab. Provides consistent CLAUDE.md instructions, statusline, settings, and Slurm skills across Great Lakes and Lighthouse clusters.

## Quick Start

```bash
git clone https://github.com/umich-foreseer/lab-claude-config.git ~/lab-claude-config
cd ~/lab-claude-config
```

Then pick one:

- **Interactive onboarding (recommended):** Run `/onboard` in Claude Code — it detects your cluster, looks up your Slurm accounts, runs setup, and helps customize your config.
- **Manual setup:** Run `./setup.sh` — it auto-detects your cluster (or use `--modules` to specify), prompts for Slurm account details, and generates config files with symlinks in `~/.claude/`.

### Prerequisites

- `jq` (for statusline script) — available on both clusters via `module load jq` or pre-installed
- Claude Code CLI installed and `~/.claude/` directory exists

## Module Options

```bash
# Auto-detect (default)
./setup.sh

# Specify modules explicitly
./setup.sh --modules greatlakes,lighthouse    # Both clusters
./setup.sh --modules greatlakes               # Great Lakes only
./setup.sh --modules lighthouse               # Lighthouse only
./setup.sh --modules none                     # No cluster modules (shared config only)

# Non-interactive (uses saved values)
./setup.sh --non-interactive
```

## Personal Overrides

### Personal instructions (CLAUDE.md)

Your `~/.claude/CLAUDE.md` is **your file**. The lab config is injected between markers:

```markdown
<!-- BEGIN: lab-config -->
... shared + module config (managed by setup.sh) ...
<!-- END: lab-config -->

# My Personal Config       <-- your content goes here, outside the markers
...
```

Write anything you want outside the markers — setup.sh will only replace content *between* them on re-runs. Your content above or below is preserved.

### Personal permissions and settings

Edit `~/.claude/settings.local.json` (created from template on first run). This file is never touched by setup.sh.

## Updating

When shared config changes are pushed:

```bash
cd ~/lab-claude-config
git pull
./setup.sh
```

Re-running setup.sh is safe and idempotent. It won't re-prompt for values already saved.

## Uninstalling

```bash
./uninstall.sh
```

Removes symlinks, strips the lab config block from CLAUDE.md (your content outside the markers is preserved), and restores backups.

## What Gets Installed

| File | Source | Method |
|------|--------|--------|
| `~/.claude/settings.json` | `shared/settings.json` + statusline path | Generated, symlinked |
| `~/.claude/statusline-command.sh` | `shared/statusline-command.sh` | Symlinked directly |
| `~/.claude/CLAUDE.md` | shared + modules | Injected between markers (user owns file) |
| `~/.claude/skills/slurm-status/` | Cluster skill template | Generated, symlinked (last module wins) |
| `~/.claude/skills/onboard/` | `shared/skills/onboard/` | Symlinked directly |
| `~/.claude/settings.local.json` | Template (first run only) | Copied, never overwritten |

## Adding a New Module

1. Create `modules/<name>/CLAUDE.md`
2. Optionally add `modules/<name>/skills/<skill-name>/SKILL.md.template`
3. Add the module name to the `case` blocks in `setup.sh`
4. Define template variables (e.g., `{{VAR_NAME}}`) and add prompts in setup.sh

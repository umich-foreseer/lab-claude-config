# Lab Claude Code Configuration

Shared Claude Code setup for the lab. Provides consistent CLAUDE.md instructions, statusline, settings, and Slurm skills across Great Lakes and Lighthouse clusters.

## Quick Start

1. Install [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and run `claude` once to initialize `~/.claude/`
2. Clone this repo and run `/onboard` in Claude Code:

```bash
git clone https://github.com/umich-foreseer/lab-claude-config.git ~/lab-claude-config
mkdir -p ~/.claude/skills && ln -sf ~/lab-claude-config/shared/skills/onboard ~/.claude/skills/onboard
```

Then open Claude Code and type `/onboard` — it will detect your cluster, look up your Slurm accounts, run setup, and help customize your config.

## Updating

```bash
cd ~/lab-claude-config && git pull
```

Then run `/onboard` again in Claude Code. It's idempotent and won't re-prompt for values already saved.

## Uninstalling

Run `./uninstall.sh` — removes symlinks, strips the lab config block from CLAUDE.md (your personal content is preserved), and restores backups.

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

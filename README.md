# Lab Claude Code Configuration

Shared Claude Code setup for the lab. Provides consistent CLAUDE.md instructions, statusline, settings, skills, and agents across Great Lakes and Lighthouse clusters.

## Quick Start

1. Install [Claude Code](https://docs.anthropic.com/en/docs/claude-code), run `claude`, and log in (`/login`)
2. Clone this repo and bootstrap the onboard skill:

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
| `~/.claude/skills/slurm-*/` | `shared/skills/slurm-*/` | Symlinked directly |
| `~/.claude/agents/*.md` | `shared/agents/*.md` | Symlinked directly |
| `~/.claude/settings.local.json` | Template (first run only) | Copied, never overwritten |

## Skills and Agents

**Skills** (`/command`) are interactive — they run in the main conversation and can ask follow-up questions. Invoke them with `/skill-name`.

| Skill | Description |
|-------|-------------|
| `/onboard` | Interactive setup wizard for new lab members |
| `/slurm-job` | Create or modify an sbatch job script |
| `/slurm-debug` | Diagnose why a Slurm job failed or is stuck |
| `/slurm-status` | Show real-time GPU/resource usage (cluster-specific, generated) |

**Agents** (`@agent`) are autonomous — they gather data independently and return a report. Invoke them with `@agent-name` or let Claude auto-delegate.

| Agent | Description |
|-------|-------------|
| `@slurm-queue` | Overview of your active, pending, and recent jobs |
| `@slurm-resource` | Reference card of available accounts, partitions, and GPUs |
| `@slurm-storage` | Scan home directory usage and suggest cleanup |

## Adding a New Module

1. Create `modules/<name>/CLAUDE.md`
2. Optionally add `modules/<name>/skills/<skill-name>/SKILL.md.template`
3. Add the module name to the `case` blocks in `setup.sh`
4. Define template variables (e.g., `{{VAR_NAME}}`) and add prompts in setup.sh

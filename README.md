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

```
~/.claude/
├── CLAUDE.md                  # Lab config injected between markers; your content outside markers is preserved
├── settings.json              # Generated from shared/settings.json + statusline path → symlinked
├── settings.local.json        # Copied from template on first run; never overwritten (your permissions)
├── statusline-command.sh      # Symlinked → shared/statusline-command.sh
├── skills/
│   ├── onboard/               # Symlinked → shared/skills/onboard/
│   ├── slurm-debug/           # Symlinked → shared/skills/slurm-debug/
│   ├── slurm-job/             # Symlinked → shared/skills/slurm-job/
│   └── slurm-status/          # Generated from module template → symlinked (cluster-specific)
├── hooks/                     # Symlinked → shared/hooks/ (PreToolUse hooks)
│   └── node-context.sh        # Detects login vs compute node, injects advisory context
└── agents/
    ├── slurm-queue.md         # Symlinked → shared/agents/slurm-queue.md
    ├── slurm-resource.md      # Symlinked → shared/agents/slurm-resource.md
    └── slurm-storage.md       # Symlinked → shared/agents/slurm-storage.md
```

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

## Hooks

The configuration includes a `PreToolUse` hook that runs before every Bash command to detect whether Claude is running on a login node or a compute node:

- **Compute node** (Slurm job detected): injects job ID, GPU count, memory, and partition — confirms that heavy operations are safe
- **Login node** (hostname matches `gl-login`, `lh-login`): warns Claude not to run CPU/GPU/memory-intensive work and suggests `srun`/`sbatch`
- **Unknown host**: outputs no context (graceful degradation)

The hook never blocks commands — it only adds advisory context so Claude makes better decisions about where to run heavy workloads.

## Contributing

Improvements welcome — open a PR against `main`. Some ideas for what to contribute:

- **New module**: add a cluster (e.g., `modules/armis2/`) with its own `CLAUDE.md` and optional skill templates
- **New skill or agent**: add to `shared/skills/` or `shared/agents/`
- **Better defaults**: tweak permissions, settings, or best-practice guidance

### Adding a new module

1. Create `modules/<name>/CLAUDE.md` (use `{{VAR}}` placeholders for user-specific values)
2. Optionally add `modules/<name>/skills/<skill-name>/SKILL.md.template`
3. Add the module name to the `case` blocks in `setup.sh`
4. Define template variables and add prompts in `setup.sh`

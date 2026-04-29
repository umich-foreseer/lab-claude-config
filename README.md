# Lab Claude Code + Codex Configuration

Shared AI coding setup for the lab. Provides consistent Claude Code and Codex instructions, statusline/settings where supported, skills, and Slurm helpers across Great Lakes and Lighthouse clusters.

## Quick Start

1. Install the tool(s) you use:
   - Claude Code: run `claude` once and log in (`/login`)
   - Codex: run `codex` once and log in
2. Clone this repo and bootstrap the onboard skill:

```bash
git clone https://github.com/umich-foreseer/lab-claude-config.git ~/lab-claude-config
mkdir -p ~/.claude/skills && ln -sf ~/lab-claude-config/shared/skills/onboard ~/.claude/skills/onboard
mkdir -p ~/.codex/skills && ln -sf ~/lab-claude-config/shared/codex/skills/onboard ~/.codex/skills/onboard
```

Then open Claude Code and type `/onboard`, or open Codex and ask it to use the `onboard` skill. It will detect your cluster, look up your Slurm accounts, run setup, and help customize your config.

Manual install examples:

```bash
cd ~/lab-claude-config

# Claude Code only (default)
./setup.sh --modules greatlakes --targets claude

# Codex only
./setup.sh --modules greatlakes --targets codex

# Both tools
./setup.sh --modules greatlakes,lighthouse --targets claude,codex
```

## Updating

```bash
cd ~/lab-claude-config && git pull
```

Then run `/onboard` in Claude Code or ask Codex to use the `onboard` skill again. Setup is idempotent and won't re-prompt for values already saved.

## Uninstalling

Run `./uninstall.sh` — removes symlinks, strips the lab config block from `CLAUDE.md` and `AGENTS.md` (your personal content is preserved), and restores backups.

## What Gets Installed for Claude Code

```
~/.claude/
├── CLAUDE.md                  # Lab config injected between markers; your content outside markers is preserved
├── settings.json              # Generated from shared/settings.json + statusline path → symlinked
├── settings.local.json        # Personal overrides (extra permissions, hooks); merged into settings.json during setup
├── statusline-command.sh      # Symlinked → shared/statusline-command.sh
├── skills/
│   ├── harvest/               # Symlinked → shared/skills/harvest/
│   ├── onboard/               # Symlinked → shared/skills/onboard/
│   ├── slurm-debug/           # Symlinked → shared/skills/slurm-debug/
│   ├── slurm-job/             # Symlinked → shared/skills/slurm-job/
│   ├── slurm-status/          # Generated from module template → symlinked (cluster-specific)
│   ├── submit-experiment/     # Symlinked → shared/skills/submit-experiment/
│   └── connect/               # Symlinked → shared/skills/connect/ (shared across clusters)
├── hooks/                     # Symlinked → shared/hooks/ (PreToolUse hooks)
│   └── node-context.sh        # Detects login vs compute node, injects advisory context
└── agents/
    ├── slurm-queue.md         # Symlinked → shared/agents/slurm-queue.md
    ├── slurm-resource.md      # Symlinked → shared/agents/slurm-resource.md
    └── slurm-storage.md       # Symlinked → shared/agents/slurm-storage.md
```

## What Gets Installed for Codex

```
~/.codex/
├── AGENTS.md                  # Lab config injected between markers; your content outside markers is preserved
└── skills/
    ├── harvest/               # Symlinked -> shared/skills/harvest/
    ├── onboard/               # Symlinked -> shared/codex/skills/onboard/
    ├── slurm-debug/           # Symlinked -> shared/skills/slurm-debug/
    ├── slurm-job/             # Symlinked -> shared/skills/slurm-job/
    ├── slurm-status/          # Generated from module template -> symlinked (cluster-specific)
    ├── submit-experiment/     # Symlinked -> shared/skills/submit-experiment/
    ├── connect/               # Symlinked -> shared/skills/connect/
    ├── slurm-queue/           # Generated from shared/agents/slurm-queue.md
    ├── slurm-resource/        # Generated from shared/agents/slurm-resource.md
    └── slurm-storage/         # Generated from shared/agents/slurm-storage.md
```

Codex does not currently use the Claude hook/statusline files directly. The important login-node safety rules are injected into `AGENTS.md`, and the reusable Slurm workflows are installed as Codex skills.

## Skills and Agents

**Claude skills** (`/command`) are interactive — they run in the main conversation and can ask follow-up questions. Invoke them with `/skill-name`.

**Codex skills** are invoked by asking Codex to use the skill by name, such as "use the slurm-status skill."

| Skill | Description |
|-------|-------------|
| `/onboard` | Interactive setup wizard for new lab members |
| `/submit-experiment` | Submit a SLURM experiment with naming, documentation, and cross-cluster support |
| `/harvest` | Discover completed experiments, collect results, and update documentation |
| `/slurm-job` | Create or modify an sbatch job script |
| `/slurm-debug` | Diagnose why a Slurm job failed or is stuck |
| `/slurm-status` | Show real-time GPU/resource usage (cluster-specific, generated) |
| `/connect` | Set up cross-cluster SSH (Great Lakes ↔ Lighthouse) and establish the connection |

**Claude agents** (`@agent`) are autonomous — they gather data independently and return a report. Invoke them with `@agent-name` or let Claude auto-delegate. In Codex, these are installed as skills with the same names.

| Agent | Description |
|-------|-------------|
| `@slurm-queue` | Overview of your active, pending, and recent jobs |
| `@slurm-resource` | Reference card of available accounts, partitions, and GPUs |
| `@slurm-storage` | Scan home directory usage and suggest cleanup |

## Hooks

**Claude hooks** run automatically before or after tool calls — no user action needed. They never block commands; they only inject advisory context.

| Hook | Trigger | Description |
|------|---------|-------------|
| `node-context` | `PreToolUse` → `Bash` | Detects login vs compute node and injects context so Claude avoids heavy ops on login nodes |

**Node context details:**
- **Compute node** (Slurm job detected): reports job ID, GPU count, memory, and partition — confirms heavy ops are safe
- **Login node** (hostname matches `gl-login`, `lh-login`): warns against heavy operations, suggests `srun`/`sbatch`
- **Unknown host**: no context added (graceful degradation)

## Contributing

Improvements welcome — open a PR against `main`. Some ideas for what to contribute:

- **New module**: add a cluster (e.g., `modules/armis2/`) with its own `CLAUDE.md`, optional `AGENTS.md`, and optional skill templates
- **New skill or agent**: add to `shared/skills/` or `shared/agents/`
- **Better defaults**: tweak permissions, settings, or best-practice guidance

### Adding a new module

1. Create `modules/<name>/CLAUDE.md` and optionally `modules/<name>/AGENTS.md` (use `{{VAR}}` placeholders for user-specific values)
2. Optionally add `modules/<name>/skills/<skill-name>/SKILL.md.template`
3. Add the module name to the `case` blocks in `setup.sh`
4. Define template variables and add prompts in `setup.sh`

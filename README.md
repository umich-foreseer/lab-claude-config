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

## Skills and Agents

**Skills** (`/command`) are interactive — they run in the main conversation and can ask follow-up questions. Invoke them with `/skill-name`.

| Skill | Description |
|-------|-------------|
| `/onboard` | Interactive setup wizard for new lab members |
| `/submit-experiment` | Submit a SLURM experiment with naming, documentation, and cross-cluster support |
| `/harvest` | Discover completed experiments, collect results, and update documentation |
| `/slurm-job` | Create or modify an sbatch job script |
| `/slurm-debug` | Diagnose why a Slurm job failed or is stuck |
| `/slurm-status` | Show real-time GPU/resource usage (cluster-specific, generated) |
| `/connect` | Set up cross-cluster SSH (Great Lakes ↔ Lighthouse) and establish the connection |

**Agents** (`@agent`) are autonomous — they gather data independently and return a report. Invoke them with `@agent-name` or let Claude auto-delegate.

| Agent | Description |
|-------|-------------|
| `@slurm-queue` | Overview of your active, pending, and recent jobs |
| `@slurm-resource` | Reference card of available accounts, partitions, and GPUs |
| `@slurm-storage` | Scan home directory usage and suggest cleanup |

## Hooks

**Hooks** run automatically before or after tool calls — no user action needed. They never block commands; they only inject advisory context.

| Hook | Trigger | Description |
|------|---------|-------------|
| `node-context` | `PreToolUse` → `Bash` | Detects login vs compute node and injects context so Claude avoids heavy ops on login nodes |

**Node context details:**
- **Compute node** (Slurm job detected): reports job ID, GPU count, memory, and partition — confirms heavy ops are safe
- **Login node** (hostname matches `gl-login`, `lh-login`): warns against heavy operations, suggests `srun`/`sbatch`
- **Unknown host**: no context added (graceful degradation)

## Shell helpers (opt-in)

### `claude-in-slurm` — auto-route `claude` into a SLURM allocation

Running Claude Code on a login node is against compute discipline. Sourcing `shared/shell/claude-in-slurm.sh` defines a `claude` shell function that:

1. If you're already inside a SLURM allocation → runs `claude` directly.
2. Otherwise, looks for a running **interactive** allocation you own and attaches via `srun --overlap --jobid=<id> --pty`. On Great Lakes, GPU jobs are skipped so `claude` never piggybacks on a training job. On Lighthouse, GPU jobs are accepted since the lab only has GPU partitions there.
3. If none exists (Great Lakes only), runs `srun --pty` with a sensible CPU default (`qmei0` / `standard`, 4 CPU / 32G / 8h) to allocate a fresh compute node and launch `claude` on it. `srun` blocks until the allocation is granted, so the prompt "waits" automatically. (We use `srun`, not `salloc <cmd>`, because Great Lakes does not set `SallocDefaultCommand` — `salloc <cmd>` would run the command on the login node while the allocation sat idle.)
4. On Lighthouse (GPU-only for this lab), auto-launch is disabled — if you don't already have an allocation, it falls back to the login node with a warning.

The script is **polyglot** — it works when sourced by either bash or zsh, so you just pick the right hook file for your shell.

**Enable** (opt-in, no `setup.sh` changes):

| Your shell setup | Hook file | Command |
|---|---|---|
| Pure bash | `~/.bashrc` | `echo '. ~/lab-claude-config/shared/shell/claude-in-slurm.sh' >> ~/.bashrc` |
| Pure zsh | `~/.zshrc` | `echo '. ~/lab-claude-config/shared/shell/claude-in-slurm.sh' >> ~/.zshrc` |
| Dotfiles with a `.local` override pattern (recommended if available) | `~/.zshrc.local` | Add the source line to `~/.zshrc.local` so it stays out of your tracked dotfiles |
| Bash that `exec`s zsh for interactive shells | `~/.zshrc` (not `~/.bashrc`) | Appending to `~/.bashrc` won't work — the exec to zsh happens first. Hook zsh directly. |

Open a new shell and run `claude` normally. The function is a no-op on compute nodes and unknown hosts, so sourcing it unconditionally is safe.

**Override defaults** by exporting before sourcing (or directly in your rc file):

```bash
export CLAUDE_IN_SLURM_CPUS=8
export CLAUDE_IN_SLURM_MEM=64G
export CLAUDE_IN_SLURM_TIME=12:00:00
export CLAUDE_IN_SLURM_DISABLE=1   # turn off entirely
```

**Notes:**
- "Interactive" means allocations with `BatchFlag=0` (i.e., `salloc`- or `srun --pty`-style). Batch `sbatch` jobs are intentionally skipped so the wrapper never piggybacks on a running training job.
- On Great Lakes, GPU jobs are skipped when searching for existing allocations. On Lighthouse, GPU jobs are accepted since the lab only has access to GPU partitions (`qmei-a100`) there.
- The Great Lakes default uses `GL_ACCOUNT_GENERAL` from `build/.env.local` (populated by `setup.sh` during `/onboard`), falling back to `qmei0` if unset.
- Lighthouse CPU defaults aren't configured because this lab only has access to the `qmei-a100` GPU partition there. If that changes, extend `_cis_alloc_args` in the script.

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

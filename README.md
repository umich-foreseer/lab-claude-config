# Lab Claude Code + Codex Configuration

Shared AI coding setup for the lab. It teaches Claude Code and/or Codex about our Slurm clusters, storage rules, login-node safety, experiment conventions, and reusable HPC workflows.

## Recommended Setup

1. Run the tool you want to use at least once:
   - Claude Code: run `claude` and log in with `/login`
   - Codex: run `codex` and log in

2. Clone this repo:

```bash
git clone https://github.com/umich-foreseer/lab-claude-config.git ~/lab-claude-config
```

3. Open Claude Code or Codex and say:

```text
Read ~/lab-claude-config/README.md and install the lab config for me.
Configure Claude Code, Codex, or both depending on what is available.
Detect my cluster, fill in my Slurm accounts, and preserve my personal config.
```

The assistant should inspect this repo, detect Great Lakes/Lighthouse, write saved setup values, and run `setup.sh`.

## Manual Setup

Use this if you want to run the installer yourself:

```bash
cd ~/lab-claude-config

# Claude Code only (default)
./setup.sh --modules greatlakes --targets claude

# Codex only
./setup.sh --modules greatlakes --targets codex

# Both tools, both clusters
./setup.sh --modules greatlakes,lighthouse --targets claude,codex
```

If you are on a cluster login node, `setup.sh` can usually auto-detect modules. Use `--modules` when you want to be explicit.

## What Gets Installed

| Target | Installed config | Reusable workflows |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md`, generated `settings.json`, statusline, hooks | `~/.claude/skills/*`, `~/.claude/agents/*` |
| Codex | `~/.codex/AGENTS.md` | `~/.codex/skills/*` |

Shared workflows include:

- `onboard` - interactive setup helper.
- `slurm-status` - check GPU/resource availability.
- `slurm-job` - create or modify sbatch scripts.
- `slurm-debug` - diagnose failed, killed, or pending jobs.
- `submit-experiment` - submit documented Slurm experiments.
- `harvest` - collect completed experiment results.
- `connect` - set up cross-cluster SSH.
- `migrate` (experimental) - discover repo and compute assumptions, then plan migration to another lab's compute resources.
- `slurm-queue`, `slurm-resource`, `slurm-storage` - Claude agents converted into Codex skills where needed.

Claude supports hooks/statusline directly. Codex does not, so login-node safety and tool usage rules are injected into `AGENTS.md` instead.

## Updating

```bash
cd ~/lab-claude-config
git pull
./setup.sh --targets <same-targets-you-installed>
```

For example, use `--targets claude` for Claude Code only, `--targets codex` for Codex only, or `--targets claude,codex` if both tools are initialized. Or ask Claude Code/Codex to read this README and update the lab config for you.

## Uninstalling

```bash
cd ~/lab-claude-config
./uninstall.sh
```

This removes repo-owned symlinks and strips the managed lab block from `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`. Personal content outside the markers is preserved. Backups are kept under `~/.claude/backups/` and `~/.codex/backups/`.

## Source Layout

The repo uses a core-plus-adapter design:

```text
shared/instructions/core.md      # Lab facts shared by Claude Code and Codex
shared/instructions/claude.md    # Claude-specific commands, hooks, agents
shared/instructions/codex.md     # Codex-specific AGENTS.md and skill guidance

modules/<cluster>/instructions/core.md
modules/<cluster>/instructions/claude.md
modules/<cluster>/instructions/codex.md

shared/skills/                   # Shared skills
shared/codex/skills/             # Codex-only skill adapters
shared/agents/                   # Claude agents, converted to Codex skills
shared/hooks/                    # Claude-only hooks
shared/settings.json             # Claude-only settings template
```

Why this shape:

- Shared cluster/storage policy lives once, so Claude and Codex do not drift.
- Tool-specific behavior stays in small adapter files.
- The installer is slightly more compositional, but future tools can be added without duplicating all lab policy.

## Contributing

Common changes:

- New cluster: add `modules/<name>/instructions/core.md`, optional `claude.md` / `codex.md`, and optional skill templates.
- New reusable workflow: add it under `shared/skills/`.
- Claude-only automation: use `shared/hooks/`, `shared/agents/`, or `shared/settings.json`.
- Codex-only adaptation: use `shared/codex/`.

Keep durable lab facts in `core.md`; keep tool syntax in the adapter files.

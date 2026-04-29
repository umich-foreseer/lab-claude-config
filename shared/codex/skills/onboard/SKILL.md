---
name: onboard
description: Onboard a lab member onto the shared Claude Code and/or Codex configuration. Detects clusters, collects Slurm account details, runs setup, and helps customize personal config.
---

# Lab AI Coding Setup - Onboarding

Help a new lab member set up the shared lab configuration for Claude Code, Codex, or both. Be friendly, concise, and beginner-friendly.

Start with a greeting like: **"Welcome onboard, Foreseer!"** Then briefly explain that this setup teaches the coding assistant about the lab's cluster environment, GPU accounts, storage rules, and Slurm workflows.

## Pre-flight Checks

1. Check whether the user has Claude Code and/or Codex initialized:

```bash
ls -ld ~/.claude ~/.codex 2>/dev/null
```

- If neither exists, ask them to run `claude` or `codex` once first, depending on what they want to use.
- If both exist, default to configuring both.
- If only one exists, configure that one unless the user asks otherwise.

2. Check if the lab config repo is cloned at `~/lab-claude-config/`. If not, tell the user to clone it:

```bash
git clone https://github.com/umich-foreseer/lab-claude-config.git ~/lab-claude-config
```

3. Verify lightweight dependencies:

```bash
which jq 2>/dev/null
```

`jq` is needed for Claude's statusline. If the user is configuring only Codex, missing `jq` is not blocking.

## Detect Cluster and Accounts

Do this proactively. Run commands yourself and present what you found.

### 1. Detect username

```bash
whoami
```

### 2. Detect cluster

```bash
hostname -f
sinfo -o "%12P %16G" --noheader 2>/dev/null | head -20
```

- If `spgpu2` exists, include Great Lakes.
- If hostname contains `lighthouse` or `lh-login`, include Lighthouse.
- If unclear, ask the user.

### 3. Look up Slurm accounts

```bash
sacctmgr show association user=$(whoami) format=account%20,partition%20,qos%40 --noheader 2>/dev/null
```

For an owned account, also check the group memory cap:

```bash
sacctmgr show association account=<owned_account> format=account%20,grptres%40 --noheader 2>/dev/null | head -5
```

Use this reference table:

| Account | Cluster | Partition(s) | GPUs | Billing |
|---|---|---|---|---|
| `qdj_project_owned1` | Great Lakes | spgpu2 | L40S | Prepaid/shared dynamic quota |
| `qmei0` | Great Lakes | gpu, gpu-rtx6000, standard | V100, RTX Pro 6000 Blackwell | Prepaid |
| `qmei3` | Great Lakes | gpu, gpu-rtx6000, standard | V100, RTX Pro 6000 Blackwell | Pay-as-you-go |
| `qmei` | Lighthouse | qmei-a100 | A100 | Dedicated |

Only present accounts for the detected cluster.

## Confirm Findings

Show a short summary with username, cluster, accounts, partitions, and any memory cap. Ask whether it looks right before writing config values.

## Run Setup

Write `~/lab-claude-config/build/.env.local` with only the variables for the detected cluster.

For Great Lakes:

```bash
# Lab Claude Config - saved template variables
GL_USERNAME=<value>
GL_ACCOUNT_OWNED=<value>
GL_ACCOUNT_GENERAL=<value>
GL_MEMORY_CAP=<value>
```

For Lighthouse:

```bash
# Lab Claude Config - saved template variables
LH_USERNAME=<value>
LH_ACCOUNT=<value>
LH_PARTITION=<value>
LH_GPU_COUNT=<value>
LH_GPU_TYPE=<value>
```

Then run setup from the repo:

```bash
cd ~/lab-claude-config && ./setup.sh --modules <modules> --targets <targets> --non-interactive
```

Examples:

```bash
# Codex only
./setup.sh --modules greatlakes --targets codex --non-interactive

# Claude Code and Codex
./setup.sh --modules greatlakes,lighthouse --targets claude,codex --non-interactive
```

## Post-setup

Summarize what was installed:

- Claude: lab block in `~/.claude/CLAUDE.md`, settings, hooks, skills, and agents.
- Codex: lab block in `~/.codex/AGENTS.md` and skills in `~/.codex/skills`.

Ask whether they want to add personal notes outside the lab markers. Good examples:

- Their turbo storage path.
- Current project paths.
- Language/framework preferences.
- Personal coding conventions.

Remind them:

- To update: `cd ~/lab-claude-config && git pull && ./setup.sh --targets <targets>`
- Personal content outside the lab markers is preserved.
- In Codex, ask for skills by name, for example "use the slurm-status skill".

## If Setup Fails

Read the error output and help debug. Common issues are missing `jq` for Claude, wrong account names, or a missing `~/.claude` / `~/.codex` directory.

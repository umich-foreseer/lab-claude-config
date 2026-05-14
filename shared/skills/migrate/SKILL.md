---
name: migrate
description: Experimental. Plan and assist migration of a repository to another lab's compute resources by discovering the current server, user, Slurm/storage environment, and repo assumptions, then presenting findings for correction before editing.
allowed-tools: Bash(hostname *), Bash(whoami), Bash(pwd), Bash(git *), Bash(sinfo *), Bash(sacctmgr *), Bash(squeue *), Bash(df *), Bash(ls *), Bash(test *), Bash(find *), Bash(python3 *), Read, Edit, Write, Glob, Grep
---

# Migrate Repository to Another Compute Resource (Experimental)

Use this skill when the user wants to move or adapt a repository to another lab, cluster, Slurm account, storage layout, GPU partition, or scheduler environment.

This skill is **experimental**. Treat discovery as advisory, make assumptions explicit, and get user correction before changing files.

Default behavior: this skill changes **zero files**. It discovers, summarizes, and proposes a migration plan. Any file edit requires explicit user permission for an exact file list.

## Safety rules

- Do not submit jobs, launch training, run inference, build large environments, or process large datasets.
- On login nodes, run only lightweight discovery, file inspection, and edits.
- Do not ask for, print, or store passwords, tokens, API keys, SSH private keys, or Duo credentials.
- Do not modify scheduler scripts, environment files, or docs until the user has reviewed the discovered facts and explicitly approves the exact files to change.
- Preserve user-specific local files. Prefer repo docs/templates over machine-local dotfiles unless the user asks otherwise.

## File impact boundaries

Be explicit about which files are only inspected, which files are candidates for edits, and which files are out of scope.

### Discovery reads

The discovery step may read lightweight text metadata from:

- Repo docs and AI guidance: `README*`, `docs/**`, `AGENTS.md`, `CLAUDE.md`.
- Scheduler/job files: `*.sh`, `*.slurm`, `*.sbatch`, files containing `#SBATCH`, and directories such as `scripts/`, `jobs/`, `slurm/`, and `workflows/`.
- Environment/config templates: `environment*.yml`, `requirements*.txt`, `pyproject.toml`, `setup.py`, `Dockerfile*`, `Apptainer*`, `Singularity*`, `.env.example`, `configs/**`.
- Project metadata: `git remote -v`, `git status --short --branch`, and small text files needed to find compute assumptions.

### Files this skill may change after approval

There are no mandatory edits. After discovery, propose the smallest useful set from this list, and ask for approval before editing.

Allowed after explicit approval:

- Scheduler scripts and templates: `submit*.sh`, `job*.sh`, `run*.sh`, `train*.sh`, `*.slurm`, `*.sbatch`, and files containing `#SBATCH`.
- Repo documentation: `README*`, `docs/**`, `AGENTS.md`, `CLAUDE.md`, or an added doc such as `docs/compute.md` / `docs/migration.md` when the repo has no existing compute instructions.
- Non-secret environment templates: `.env.example`, `.env.template`, `environment*.yml`, `requirements*.txt`, `pyproject.toml`, `Dockerfile*`, `Apptainer*`, or `Singularity*` when they contain compute-specific setup.
- Small repo config files: files under `configs/**` or similar when they explicitly contain scheduler, account, partition, GPU, storage, scratch, cache, module, or host assumptions.

For each proposed edit, state:

```text
File:
Why it needs to change:
What kind of change:
Risk:
```

Then ask:

```text
Do you want me to edit exactly these files and no others?
```

Do not edit until the user answers yes or otherwise clearly approves that exact list.

### Do not touch by default

Do not edit these unless the user explicitly names them and approves the reason:

- Secrets or local machine state: `.env`, `.env.local`, credential files, SSH config, API keys, private keys, `wandb` auth, and tool-local files under `~/.claude`, `~/.codex`, `.claude/`, or `.codex/`.
- Generated or dependency directories: `build/`, `dist/`, `outputs/`, `logs/`, `wandb/`, `.git/`, `node_modules/`, caches, checkpoints, datasets, and virtual environments.
- Core training, model, or analysis code unless it hard-codes compute-resource paths or scheduler behavior.
- Large data files, binary artifacts, notebooks with embedded outputs, or model checkpoints.

## Workflow

### 1. Discover the current environment

From the repository root, run the bundled discovery script when available:

```bash
python3 <skill_dir>/scripts/discover_compute.py .
```

If the script is unavailable, gather the same information with lightweight commands:

```bash
hostname -f 2>/dev/null || hostname
whoami
pwd
git remote -v 2>/dev/null
git status --short --branch 2>/dev/null
sacctmgr show association user=$(whoami) format=account%24,partition%30,qos%30 --noheader 2>/dev/null
sinfo -h -o "%P|%G|%D|%m|%l|%a" 2>/dev/null
df -h "$HOME" /nfs/turbo /scratch 2>/dev/null
```

Adjust the `df` paths to the current cluster if it does not use `/nfs/turbo` or `/scratch`.

Also inspect repo files for migration-sensitive assumptions:

- `README*`, `AGENTS.md`, `CLAUDE.md`, `.codex/`, `.claude/`
- `docs/`, `scripts/`, `slurm/`, `jobs/`, `configs/`, `env*`, `requirements*`, `pyproject.toml`, `environment*.yml`
- `*.sh`, `*.slurm`, `*.sbatch`, and files containing `#SBATCH`

Search for hard-coded cluster details such as account names, partitions, storage roots, hostnames, module names, CUDA versions, conda paths, and scratch/turbo paths.

### 2. Present findings for correction

Before editing, summarize the findings in this shape:

```text
Current facts I found:
- Server/cluster:
- User/account candidates:
- Scheduler/partitions/GPU hints:
- Storage paths:
- Repo job entry points:
- Hard-coded assumptions:

Proposed file impact:
- Read-only files inspected:
- Files I would edit, if you approve:
- Files I will not touch:

Unknowns or likely wrong inferences:
- ...

Please correct these before I patch the repo:
- Target lab/cluster:
- Target scheduler and account/partition:
- Target persistent storage path:
- Target scratch/temp path:
- Preferred environment setup:
```

Ask only the questions needed to unblock the migration. If the user already supplied the target environment, ask them to correct the summary rather than repeating every field.

### 3. Plan the migration

After user confirmation, produce a concise migration plan that covers:

- Scheduler changes: accounts, partitions, QOS, GPU directives, memory/time defaults, arrays, dependencies.
- Storage changes: persistent output, scratch staging, cache paths, dataset/checkpoint paths.
- Environment changes: modules, CUDA, conda/venv/container setup, package install location.
- Documentation changes: setup instructions, run commands, safety notes, and experiment tracking.
- File impact: exact files proposed for editing, why each file needs to change, and exact files that remain read-only/out of scope.
- Validation: shell syntax checks, dry-run commands, and grep checks for stale cluster-specific strings.

End the plan with a permission prompt:

```text
I will make no file changes unless you approve this exact edit list. Do you want me to edit these files?
```

### 4. Patch the repo

When editing, keep changes scoped to migration support:

- Before edits, confirm the user approved the exact file list. If discovery found more candidates than necessary, choose the smallest useful set.
- If a new file becomes necessary after editing starts, stop and ask permission for that additional file before touching it.
- Prefer parameterized variables near the top of scripts over replacing one hard-coded lab with another hard-coded lab.
- Keep old values in comments only if they are useful examples; otherwise remove stale cluster-specific assumptions.
- Use placeholders like `<target_account>` only when the user has not provided a value and the file is clearly a template.
- Update README or experiment docs so future users know how to run on the target compute resource.
- Add a short `Migration notes` or `Compute migration` section when the repo has no existing place for this.
- Never broaden into refactors, code style changes, dependency upgrades, or unrelated cleanup while migrating compute assumptions.

### 5. Validate

Run lightweight checks only:

```bash
bash -n <edited_script>.sh
grep -R "<old_account>\|<old_partition>\|<old_storage_root>" -n .
git diff --check
```

Replace `<old_account>`, `<old_partition>`, and `<old_storage_root>` with actual values found during discovery.

Report what changed, what was validated, and any remaining target details the user still needs to fill in.

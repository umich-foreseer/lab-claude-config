# Lab Shared Configuration for Codex

## Codex Operating Rules

- Be careful on shared HPC login nodes. Before running expensive commands, check `hostname` and whether `SLURM_JOB_ID` is set.
- If `SLURM_JOB_ID` is unset and the host looks like `gl-login*` or `lh-login*`, treat the shell as a login node.
- On login nodes, only run lightweight inspection, editing, Git, package management, and Slurm control commands.
- Do not run training, inference, test suites, large data processing, compilation of large codebases, or sustained CPU/GPU/I/O work on login nodes. Use `srun`, `salloc`, or `sbatch` instead.
- Inside a Slurm allocation (`SLURM_JOB_ID` set), arbitrary workloads are allowed.

## Storage

### Home (~80 GiB quota)

- Run `home-quota` to check current usage.
- Only for small files: scripts, configs, dotfiles.
- Never write large or growing files to `~/`. When in doubt, use turbo.

### Turbo (persistent large storage)

- Path: `/nfs/turbo/si-qmei/${USER}/` - 10 TB shared quota across the lab, no purge.
- Before large file operations, check available space: `df -h /nfs/turbo/si-qmei`
- Deleting files does not immediately free disk space. Turbo keeps daily snapshots for about 7 days.
- Use for datasets, model checkpoints, experiment logs, wandb artifacts, conda envs, containers, and caches.

### Data Den (archival storage)

- Tape-backed archival storage for inactive datasets. Transfer via Globus; tar small files first.
- Details: https://its.umich.edu/advanced-research-computing/storage/data-den

### Scratch (high-performance temporary storage)

- Path: `/scratch/<slurm_account_root>/<project>/<user>/`
- 10 TB / 1M inode limit per root account. Files untouched for 60 days are auto-purged.
- Use scratch for temporary files that running jobs read/write intensively.
- Always copy results back to turbo when the job finishes. Never treat scratch as permanent storage.

## Compute Discipline

- Never run CPU/GPU/memory-intensive jobs on login nodes. Login nodes are for editing, submitting jobs, and lightweight inspection.
- Use `srun`/`salloc` for interactive compute or `sbatch` for batch jobs.
- For long-running tasks, write logs to a persistent, user-inspectable location such as `logs/` or turbo.

## Experiment Discipline

Every Slurm experiment should be tracked with structured documentation:

- `docs/experiments.md` - compact index with what, why, key result, and a link to detail.
- `docs/experiments/<date>_<name>.md` - self-contained details with goal, setup, results, observations, and reproduce command.

Use names like `{type}-{descriptor}-{slug}`: lowercase and hyphenated, for example `sft-llama7b-baseline`.

## Available Codex Skills

Ask Codex to use these skills by name:

- `slurm-status` - real-time GPU and resource availability on the cluster.
- `slurm-job` - create or modify sbatch scripts with correct accounts, partitions, and best practices.
- `slurm-debug` - diagnose why a Slurm job failed, was killed, or is stuck.
- `submit-experiment` - submit a Slurm experiment with naming, documentation, and cross-cluster support.
- `harvest` - discover completed experiments, collect results, and update documentation.
- `onboard` - set up a lab member's Claude Code and/or Codex configuration.
- `connect` - set up cross-cluster SSH between Great Lakes and Lighthouse.
- `slurm-queue` - show active, pending, and recent jobs.
- `slurm-resource` - list accounts, partitions, and GPU types you can request.
- `slurm-storage` - scan home directory usage and suggest what to move to turbo.

Some shared skill docs mention Claude slash commands such as `/slurm-status`. In Codex, treat those as references to the Codex skill with the same name.

## Coding Conventions

- Write clean, readable code. Prefer clarity over cleverness.
- Use type hints in Python where practical.
- Keep experiments reproducible: pin random seeds, log hyperparameters, and use version-controlled configs.
- Use virtual environments or conda for Python dependencies. Never install packages globally.

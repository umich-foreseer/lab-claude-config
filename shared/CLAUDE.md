# Lab Shared Configuration

## Home Directory Quota

- Your home directory has a strict quota (~80 GiB on Great Lakes). Run `home-quota` to check current usage.
- Large files (datasets, model checkpoints, experiment logs, wandb artifacts, containers, etc.) must go to turbo storage (no strict quota).
- Never write large or growing files to `~/`. When in doubt, use turbo.

## Compute Discipline

- **Never run CPU/GPU/memory-intensive jobs on login nodes.** Login nodes are shared and resource-limited. Always check the current node (`hostname`) before running heavy work.
- Use `srun`/`salloc` for interactive compute or `sbatch` for batch jobs.
- For long-running tasks (environment setup, training, large data processing), always ensure logs are written to a persistent, user-inspectable location (e.g., `logs/` directory or turbo) so progress can be monitored while the job runs. Use `tee`, explicit `--output`/`--error` in sbatch, or redirect stdout/stderr to a log file.

## Coding Conventions

- Write clean, readable code. Prefer clarity over cleverness.
- Use type hints in Python where practical.
- Keep experiments reproducible: pin random seeds, log hyperparameters, use version-controlled configs.
- Use virtual environments or conda for Python dependencies. Never install packages globally.

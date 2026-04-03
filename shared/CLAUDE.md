# Lab Shared Configuration

## Storage

### Home (~80 GiB quota)

- Run `home-quota` to check current usage.
- Only for small files: scripts, configs, dotfiles.
- Never write large or growing files to `~/`. When in doubt, use turbo.

### Turbo (persistent large storage)

- Path: `/nfs/turbo/si-qmei/${USER}/` — **10 TB shared quota** across the lab, no purge.
- Before large file operations (downloading datasets, extracting archives), check available space: `df -h /nfs/turbo/si-qmei`
- **Deleting files does not immediately free disk space.** Turbo keeps daily snapshots (~7 days) so deleted data continues to consume quota until snapshots rotate out. Plan storage carefully.
- Use for: datasets, model checkpoints, experiment logs, wandb artifacts, conda envs, containers, caches (HF, torch, pip).

### Data Den (archival storage)

- Tape-backed archival for inactive datasets (100 TB free). Transfer via Globus; tar small files first.
- Details: https://its.umich.edu/advanced-research-computing/storage/data-den

### Scratch (high-performance temporary storage)

- Path: `/scratch/<slurm_account_root>/<project>/<user>/`
- 10 TB / 1M inode limit per root account. **Files untouched for 60 days are auto-purged.**
- Scratch is a high-performance GPFS filesystem — faster I/O than turbo.
- Use for: temporary files that running jobs read/write intensively (shuffled data shards, intermediate results, temporary checkpoints).
- **Always copy results back to turbo when the job finishes.** Never treat scratch as permanent storage.
- Stage-in / stage-out pattern in job scripts:

```bash
# At job start — stage data from turbo to scratch
SCRATCH_DIR=/scratch/${SLURM_ACCOUNT}/${USER}/${SLURM_JOB_ID}
mkdir -p "$SCRATCH_DIR"
cp -r /nfs/turbo/si-qmei/${USER}/data/my_dataset "$SCRATCH_DIR/"

# Run training from scratch
python train.py --data-dir "$SCRATCH_DIR/my_dataset" --output-dir "$SCRATCH_DIR/output"

# At job end — copy results back to turbo
cp -r "$SCRATCH_DIR/output" /nfs/turbo/si-qmei/${USER}/results/
# Clean up scratch (optional — purge policy will also handle it)
rm -rf "$SCRATCH_DIR"
```

## Compute Discipline

- **Never run CPU/GPU/memory-intensive jobs on login nodes.** Login nodes are shared and resource-limited. Always check the current node (`hostname`) before running heavy work.
- Use `srun`/`salloc` for interactive compute or `sbatch` for batch jobs.
- For long-running tasks (environment setup, training, large data processing), always ensure logs are written to a persistent, user-inspectable location (e.g., `logs/` directory or turbo) so progress can be monitored while the job runs. Use `tee`, explicit `--output`/`--error` in sbatch, or redirect stdout/stderr to a log file.

## Experiment Discipline

Every SLURM experiment should be tracked with structured documentation. This ensures reproducibility, prevents duplicate work, and creates a searchable history of what was tried and what worked.

**Convention**: Each project that runs experiments should maintain:
- `docs/experiments.md` — compact index (what, why, key result, link to detail file; <100 words per entry)
- `docs/experiments/<date>_<name>.md` — self-contained detail files (goal, setup, results, observations, reproduce command)

**Naming**: `{type}-{descriptor}-{slug}` — lowercase, hyphens only. Examples: `sft-llama7b-baseline`, `eval-gpt4o-zeroshot`, `pretrain-bert-large-v2`.

**Workflow**: Use `/submit-experiment` to submit jobs (handles naming, logging, cross-cluster submission) and `/harvest` to collect results when jobs complete.

**Completion markers**: Job scripts can write a `logs/<name>_<jobid>.done.json` marker on completion so `/harvest` can auto-discover finished experiments. See the `/harvest` skill for the marker schema.

## Available Skills & Agents

**Skills** (invoke with `/command`):
- `/slurm-status` — real-time GPU and resource availability on the cluster
- `/slurm-job` — create or modify sbatch scripts with correct accounts, partitions, and best practices
- `/slurm-debug` — diagnose why a job failed, was killed, or is stuck pending
- `/submit-experiment` — submit a SLURM experiment with proper naming, documentation, and cross-cluster support
- `/harvest` — discover completed experiments, collect results, and update documentation
- `/onboard` — set up a new lab member's Claude Code configuration

**Agents** (Claude uses these automatically when relevant, or you can ask for them by name):
- `slurm-queue` — show your active, pending, and recent jobs with status and quick actions
- `slurm-resource` — list all accounts, partitions, and GPU types you can request
- `slurm-storage` — scan home directory usage and suggest what to move to turbo

## Coding Conventions

- Write clean, readable code. Prefer clarity over cleverness.
- Use type hints in Python where practical.
- Keep experiments reproducible: pin random seeds, log hyperparameters, use version-controlled configs.
- Use virtual environments or conda for Python dependencies. Never install packages globally.

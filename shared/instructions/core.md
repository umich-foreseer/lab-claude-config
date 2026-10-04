# Lab Shared Configuration

This file is tool-agnostic lab guidance. Keep durable HPC, storage, Slurm, and coding conventions here so Claude Code and Codex do not drift.

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
- Lab volume: `/si-qmei/` on the Globus collection "UMich ARC Non-Sensitive Data Den Volume Collection".
- ARC asks for files of at least 100 MB (ideally 10-100 GB) and at most about 10,000 files per TB.
- `module load archivetar` packs small files into zstd-compressed tars and uploads them with Globus. Run it inside a Slurm job.
- Stage the temporary tars on scratch (`--bundle-dir /scratch/...`), not on turbo. Tars deleted from turbo stay in its daily snapshots for about 7 days and keep using the shared quota. Node-local disks such as `/tmp_data` do not work, because Globus cannot see them.
- Details: https://its.umich.edu/advanced-research-computing/storage/data-den

### Scratch (high-performance temporary storage)

- Path: `/scratch/<slurm_account_root>/<project>/<user>/`
- 10 TB / 1M inode limit per root account. Files untouched for 60 days are auto-purged.
- Scratch is a high-performance GPFS filesystem and is faster than turbo for intensive job I/O.
- Use for temporary files that running jobs read/write intensively.
- Always copy results back to turbo when the job finishes. Never treat scratch as permanent storage.
- Stage-in / stage-out pattern in job scripts:

```bash
# At job start - stage data from turbo to scratch
SCRATCH_DIR=/scratch/${SLURM_ACCOUNT}/${USER}/${SLURM_JOB_ID}
mkdir -p "$SCRATCH_DIR"
cp -r /nfs/turbo/si-qmei/${USER}/data/my_dataset "$SCRATCH_DIR/"

# Run training from scratch
python train.py --data-dir "$SCRATCH_DIR/my_dataset" --output-dir "$SCRATCH_DIR/output"

# At job end - copy results back to turbo
cp -r "$SCRATCH_DIR/output" /nfs/turbo/si-qmei/${USER}/results/
rm -rf "$SCRATCH_DIR"
```

## Compute Discipline

- Never run CPU/GPU/memory-intensive jobs on login nodes. Login nodes are shared and resource-limited.
- Always check the current node (`hostname`) before running heavy work.
- Use `srun`/`salloc` for interactive compute or `sbatch` for batch jobs.
- For long-running tasks, write logs to a persistent, user-inspectable location such as `logs/` or turbo.

## Experiment Discipline

Every Slurm experiment should be tracked with structured documentation. This helps with reproducibility, avoids duplicate work, and creates a searchable history.

Convention:

- `docs/experiments.md` - compact index with what, why, key result, and a link to detail.
- `docs/experiments/<date>_<name>.md` - self-contained details with goal, setup, results, observations, and reproduce command.

Naming: `{type}-{descriptor}-{slug}`. Use lowercase and hyphens only, for example `sft-llama7b-baseline`.

Completion markers: job scripts can write a `logs/<name>_<jobid>.done.json` marker on completion so harvest workflows can auto-discover finished experiments.

## Coding Conventions

- Write clean, readable code. Prefer clarity over cleverness.
- Use type hints in Python where practical.
- Keep experiments reproducible: pin random seeds, log hyperparameters, and use version-controlled configs.
- Use virtual environments or conda for Python dependencies. Never install packages globally.

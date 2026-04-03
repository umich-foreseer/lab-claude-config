---
name: slurm-job
description: Create or modify an sbatch job script with correct partitions, accounts, GPU requests, and best-practice defaults for the current cluster.
allowed-tools: Bash(sinfo *), Bash(sacctmgr *), Bash(whoami), Bash(hostname *), Bash(cat *), Bash(ls *), Read, Edit, Write, Glob, Grep
---

# Create / Modify an Sbatch Job Script

Help the user create a new sbatch job script or modify an existing one. The goal is a correct, ready-to-submit script that follows lab best practices.

## When invoked with an existing script

If the user points to an existing `.sh` or `.slurm` file (or pastes script content), read it and help them modify it. Common requests:
- Change GPU type / partition / account
- Adjust resource requests (GPUs, memory, time)
- Fix sbatch directives
- Add logging, conda activation, or other boilerplate

Apply the same best practices described below when modifying.

## When creating a new script

### 1. Gather requirements

Ask the user concisely (combine into one question where possible):

- **What does the job do?** (training run, inference, preprocessing, etc.)
- **Which GPU type?** Default to L40S if they don't specify. Mention the options: L40S (fastest), A40, V100.
- **How many GPUs?**
- **Estimated wall time?** Suggest a reasonable default based on the task.
- **Job name?**
- **Where should the script be saved?**

If the user already provided some of this info (e.g., "create an sbatch script for training on 2 L40S GPUs"), don't re-ask what's already clear.

### 2. Detect accounts

Run these commands to determine the correct `--account` for the chosen partition:

```bash
whoami
sacctmgr show association user=$(whoami) format=account%20,partition%20,qos%40 --noheader 2>/dev/null
```

Mapping:
- **spgpu2** (L40S) → use the account with `arph` QOS (owned account)
- **spgpu** (A40), **gpu** (V100), **gpu_mig40** (A100 MIG) → use the account with `normal` QOS (general account, typically `qmei0` or similar)

### 3. Generate the script

Use this template as a starting point, adapting to the user's needs:

```bash
#!/bin/bash
#SBATCH --job-name=<job_name>
#SBATCH --partition=<partition>
#SBATCH --account=<account>
#SBATCH --gres=gpu:<num_gpus>
#SBATCH --cpus-per-task=<cpus>
#SBATCH --mem=<memory>
#SBATCH --time=<time>
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

# --- Setup ---
set -euo pipefail

# Create log directory if needed
mkdir -p logs

# Print job info for debugging
echo "Job ID: $SLURM_JOB_ID"
echo "Node:   $(hostname)"
echo "GPUs:   $SLURM_GPUS_ON_NODE"
echo "Start:  $(date)"
echo "---"

# Activate environment
# module load cuda  # uncomment if needed
# conda activate <env_name>

# --- Run ---
<user_command>

echo "---"
echo "End: $(date)"
```

#### Resource defaults by GPU type

| GPU | Partition | Mem/GPU | CPUs/GPU |
|-----|-----------|---------|----------|
| L40S | spgpu2 | 60G | 4 |
| A40 | spgpu | 40G | 4 |
| V100 | gpu | 20G | 4 |
| A100 MIG | gpu_mig40 | 60G | 4 |

Scale memory and CPUs proportionally for multi-GPU jobs (e.g., 2 L40S → `--mem=120G --cpus-per-task=8`).

#### Best practices to apply

1. **Logs**: Always set `--output` and `--error` to a `logs/` directory (or turbo path for very large/long jobs). Use `%x` (job name) and `%j` (job ID) in filenames so logs don't overwrite each other.

2. **`set -euo pipefail`**: Include at the top so failures are caught early.

3. **Job info header**: Print `SLURM_JOB_ID`, hostname, GPU count, and timestamp so the user can debug and correlate logs.

4. **Environment activation**: Include a commented-out `conda activate` or `module load` line as a reminder. If the user tells you which environment to use, uncomment and fill it in.

5. **Time limit**: Always set `--time`. If the user doesn't specify, suggest a reasonable default and explain they can adjust it. Max is 14 days on most partitions.

6. **No home directory output**: If the job writes large outputs (checkpoints, datasets, results), direct them to turbo storage, not `~/`.

7. **Scratch for I/O-heavy jobs**: If the job reads many small files or does heavy random I/O (e.g., training on large image datasets), stage data to scratch (`/scratch/<account>/<project>/<user>/`) at job start for better performance, and copy results back to turbo at job end. Include cleanup. Example pattern:

   ```bash
   SCRATCH_DIR=/scratch/${SLURM_ACCOUNT}/${USER}/${SLURM_JOB_ID}
   mkdir -p "$SCRATCH_DIR"
   cp -r /nfs/turbo/si-qmei/${USER}/data "$SCRATCH_DIR/"
   # ... run job from $SCRATCH_DIR ...
   mkdir -p /nfs/turbo/si-qmei/${USER}/results
   cp -r "$SCRATCH_DIR/output" /nfs/turbo/si-qmei/${USER}/results/
   rm -rf "$SCRATCH_DIR"
   ```

   Remind the user that scratch is auto-purged after 60 days of inactivity — never use it as permanent storage.

8. **Multi-node / distributed**: If the user requests multiple nodes, add `--nodes`, `--ntasks-per-node`, and include `torchrun` or `srun` launcher setup as appropriate. Ask the user which distributed framework they use if unclear.

### 4. Present the script

Show the complete script to the user and explain any non-obvious choices. Write it to the requested path (or suggest a sensible default like `./job.sh`).

Remind the user:
- `mkdir -p logs` before first submission (or the script does it automatically)
- Submit with: `sbatch <script_name>.sh`
- Monitor with: `squeue -u $(whoami)` or `sacct -j <job_id>`
- Cancel with: `scancel <job_id>`

### 5. Optional enhancements

Only add these if the user asks or if clearly relevant:

- **Email notifications**: `#SBATCH --mail-type=END,FAIL` and `#SBATCH --mail-user=<email>`
- **Array jobs**: `#SBATCH --array=0-N` with `$SLURM_ARRAY_TASK_ID` usage
- **Dependency chains**: `#SBATCH --dependency=afterok:<job_id>`
- **Checkpointing**: signal trapping for graceful shutdown and checkpoint saving
- **Wandb / logging integration**: set `WANDB_PROJECT`, `WANDB_DIR` to turbo, etc.

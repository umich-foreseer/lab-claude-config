# Great Lakes HPC Cluster

This is the University of Michigan Great Lakes cluster.

## Accounts

| Account | Partitions | QOS | Limits |
|---|---|---|---|
| `{{GL_ACCOUNT_OWNED}}` (primary GPU) | **spgpu2** (L40S) | arph | Shared group memory cap: {{GL_MEMORY_CAP}} GB; group cap of 10 GPUs and 80 CPUs |
| `{{GL_ACCOUNT_GENERAL}}` (general) | gpu, spgpu, gpu_mig40, standard, debug, largemem | interactive, normal | 2 GPUs per user; small spending limit |

## GPU Partitions Accessible

| Partition | GPU | GPUs/Node | Nodes | Memory/Node | Max Time |
|---|---|---|---|---|---|
| **spgpu2** | L40S (48 GB) | 8 | 24 (192 total GPUs) | ~495 GB | 14 days |
| spgpu | A40 (48 GB), avoid by default | 8 | 30 | ~372-495 GB | 14 days |
| gpu | V100 (16/32 GB) | 2-3 | 24 | 180 GB | 14 days |
| gpu_mig40 | A100 MIG (40 GB slices) | 8 | 2 | 1 TB | 14 days |

## GPU Choice and Cost

Default to L40S on `spgpu2` (`{{GL_ACCOUNT_OWNED}}`) or the Lighthouse A100s (`qmei-a100`). Do not use A40 (`spgpu` on `{{GL_ACCOUNT_GENERAL}}`) by default, because it costs more. Use A40 only when L40S and Lighthouse are both unavailable and the job can't wait.

Why, from Slurm billing measured 2026-10-31:

- A40 on `{{GL_ACCOUNT_GENERAL}}` costs about $0.14-0.22 per GPU-hour. The high end is with a 100 GB memory request, since billing takes the max of the CPU, memory and GPU weights.
- L40S on `spgpu2` costs about $0.11 per GPU-hour, and it is faster.
- `{{GL_ACCOUNT_GENERAL}}` has a much smaller spending limit than `{{GL_ACCOUNT_OWNED}}` (October 2026: $901.07 vs $6,852.79). CPU jobs on `standard` also draw from `{{GL_ACCOUNT_GENERAL}}`.

To check costs and limits, run these on a Great Lakes login node. They need a tty, so over ssh use `ssh -tt` and set `stty cols 200`:

```bash
my_account_billing -v <account>
my_account_usage -A <account> -S YYYY-MM -E YYYY-MM

# Over ssh
ssh -tt greatlakes 'stty cols 200; my_account_billing -v {{GL_ACCOUNT_GENERAL}}'
```

The ARC portal (https://portal.arc.umich.edu) also shows the limits. In `sacct`, billing-minutes / 1e7 = dollars.

## Common Submission Patterns

```bash
# L40S (default: cheapest per GPU-hour and fastest)
sbatch --partition=spgpu2 --account={{GL_ACCOUNT_OWNED}} --gres=gpu:1 --mem=60G --time=8:00:00 job.sh

# V100
sbatch --partition=gpu --account={{GL_ACCOUNT_GENERAL}} --gres=gpu:1 --mem=20G --time=8:00:00 job.sh

# Interactive L40S session
srun --partition=spgpu2 --account={{GL_ACCOUNT_OWNED}} --gres=gpu:1 --mem=60G --time=2:00:00 --pty bash

# A40: last resort only (costs more, see GPU Choice and Cost)
sbatch --partition=spgpu --account={{GL_ACCOUNT_GENERAL}} --gres=gpu:1 --mem=40G --time=8:00:00 job.sh
```

## Storage Paths

| Storage | Path | Quota | Purge |
|---|---|---|---|
| Home | `~/` | ~80 GiB | None |
| Turbo | `/nfs/turbo/si-qmei/${USER}/` | 10 TB shared | None |
| Scratch | `/scratch/<account>/<project>/<user>/` | 10 TB / 1M inodes per account | 60 days untouched |

Use turbo for persistent large files. Use scratch for temporary high-performance I/O during jobs.

## Key Constraints

- L40S memory budget ({{GL_MEMORY_CAP}} GB) is shared across the entire `{{GL_ACCOUNT_OWNED}}` group.
- `qdj_project_owned_root` caps the whole group at 10 GPUs and 80 CPUs, and `{{GL_ACCOUNT_GENERAL}}` caps each user at 2 GPUs. A job over a cap pends with `AssocGrpGRES`.
- Estimate ~60 GB memory per L40S GPU when planning requests.
- Use the Slurm status helper before submitting large jobs.

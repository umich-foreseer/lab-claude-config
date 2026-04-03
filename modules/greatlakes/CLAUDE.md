# Great Lakes HPC Cluster

This is the University of Michigan Great Lakes cluster.

## Accounts

| Account | Partitions | QOS | Limits |
|---|---|---|---|
| `{{GL_ACCOUNT_OWNED}}` (primary GPU) | **spgpu2** (L40S) | arph | Shared group memory cap: {{GL_MEMORY_CAP}} GB |
| `{{GL_ACCOUNT_GENERAL}}` (general) | gpu, spgpu, gpu_mig40, standard, debug, largemem | interactive, normal | No explicit GPU cap |

## GPU Partitions Accessible

| Partition | GPU | GPUs/Node | Nodes | Memory/Node | Max Time |
|---|---|---|---|---|---|
| **spgpu2** | L40S (48 GB) | 8 | 24 (192 total GPUs) | ~495 GB | 14 days |
| spgpu | A40 (48 GB) | 8 | 30 | ~372-495 GB | 14 days |
| gpu | V100 (16/32 GB) | 2-3 | 24 | 180 GB | 14 days |
| gpu_mig40 | A100 MIG (40 GB slices) | 8 | 2 | 1 TB | 14 days |

## Common Submission Patterns

```bash
# L40S (best GPU available)
sbatch --partition=spgpu2 --account={{GL_ACCOUNT_OWNED}} --gres=gpu:1 --mem=60G --time=8:00:00 job.sh

# A40
sbatch --partition=spgpu --account={{GL_ACCOUNT_GENERAL}} --gres=gpu:1 --mem=40G --time=8:00:00 job.sh

# V100
sbatch --partition=gpu --account={{GL_ACCOUNT_GENERAL}} --gres=gpu:1 --mem=20G --time=8:00:00 job.sh

# Interactive L40S session
srun --partition=spgpu2 --account={{GL_ACCOUNT_OWNED}} --gres=gpu:1 --mem=60G --time=2:00:00 --pty bash
```

## Storage Paths

| Storage | Path | Quota | Purge |
|---|---|---|---|
| Home | `~/` | ~80 GiB | None |
| Turbo | `/nfs/turbo/si-qmei/<user>/` | 10 TB shared | None |
| Scratch | `/scratch/<account>/<project>/<user>/` | 10 TB / 1M inodes per account | **60 days** untouched |

Use turbo for persistent large files. Use scratch for temporary high-performance I/O during jobs (stage in from turbo, copy results back).

## Key Constraints

- L40S memory budget ({{GL_MEMORY_CAP}} GB) is shared across the entire `{{GL_ACCOUNT_OWNED}}` group (~11 members)
- Estimate ~60 GB memory per L40S GPU when planning requests
- Use `/slurm-status` skill to check real-time availability before submitting large jobs

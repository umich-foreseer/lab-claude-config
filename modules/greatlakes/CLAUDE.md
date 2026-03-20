# Great Lakes HPC Cluster

This is the University of Michigan Great Lakes cluster.

## Accounts

| Account | Partitions | QOS | Limits |
|---|---|---|---|
| Primary GPU account | **spgpu2** (L40S) | arph | Shared group memory cap |
| General account | gpu, spgpu, gpu_mig40, standard, debug, largemem | interactive, normal | No explicit GPU cap |

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
sbatch --partition=spgpu2 --account=<your-owned-account> --gres=gpu:1 --mem=60G job.sh

# A40
sbatch --partition=spgpu --account=<your-general-account> --gres=gpu:1 --mem=40G job.sh

# V100
sbatch --partition=gpu --account=<your-general-account> --gres=gpu:1 --mem=20G job.sh

# Interactive L40S session
srun --partition=spgpu2 --account=<your-owned-account> --gres=gpu:1 --mem=60G --time=2:00:00 --pty bash
```

## Key Constraints

- L40S memory budget is shared across the entire owned account group (~11 members)
- Estimate ~60 GB memory per L40S GPU when planning requests
- Use `/slurm-status` skill to check real-time availability before submitting large jobs

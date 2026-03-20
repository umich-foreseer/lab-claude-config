# Lighthouse HPC Cluster

This is the Lighthouse cluster with dedicated {{LH_GPU_TYPE}} GPUs for the group.

## Accounts

| Account | Partitions | GPU Type | Group Allocation |
|---|---|---|---|
| `{{LH_ACCOUNT}}` | gpu | {{LH_GPU_TYPE}} | {{LH_GPU_COUNT}} GPUs total for the group |

## GPU Resources

| Partition | GPU | GPUs Available | Memory/GPU | Notes |
|---|---|---|---|---|
| gpu | {{LH_GPU_TYPE}} | {{LH_GPU_COUNT}} (group total) | 80 GB | Shared among ~3-8 lab members |

## Common Submission Patterns

```bash
# Single {{LH_GPU_TYPE}}
sbatch --partition=gpu --account={{LH_ACCOUNT}} --gres=gpu:1 --mem=80G --time=8:00:00 job.sh

# Multi-GPU (up to {{LH_GPU_COUNT}})
sbatch --partition=gpu --account={{LH_ACCOUNT}} --gres=gpu:{{LH_GPU_COUNT}} --mem=320G --time=8:00:00 job.sh

# Interactive session
srun --partition=gpu --account={{LH_ACCOUNT}} --gres=gpu:1 --mem=80G --time=4:00:00 --pty bash
```

## Key Constraints

- Only {{LH_GPU_COUNT}} {{LH_GPU_TYPE}} GPUs for the entire group — coordinate with lab mates before reserving multiple GPUs
- Use `/slurm-status` skill to check real-time availability before submitting jobs
- For multi-GPU training, consider whether the task truly benefits from parallelism

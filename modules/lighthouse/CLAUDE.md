# Lighthouse HPC Cluster

This is the Lighthouse cluster with dedicated A100 80GB GPUs for the group.

## Accounts

| Account | Partitions | GPU Type | Group Allocation |
|---|---|---|---|
| Group account | gpu | A100 80GB | 4 GPUs total for the group |

## GPU Resources

| Partition | GPU | GPUs Available | Memory/GPU | Notes |
|---|---|---|---|---|
| gpu | A100 80GB | 4 (group total) | 80 GB | Shared among ~3-8 lab members |

## Common Submission Patterns

```bash
# Single A100 80GB
sbatch --partition=gpu --account=<your-account> --gres=gpu:1 --mem=80G job.sh

# Multi-GPU (up to 4)
sbatch --partition=gpu --account=<your-account> --gres=gpu:4 --mem=320G job.sh

# Interactive session
srun --partition=gpu --account=<your-account> --gres=gpu:1 --mem=80G --time=4:00:00 --pty bash
```

## Key Constraints

- Only 4 A100 80GB GPUs for the entire group — coordinate with lab mates before reserving multiple GPUs
- Use `/slurm-status` skill to check real-time availability before submitting jobs
- For multi-GPU training, consider whether the task truly benefits from parallelism

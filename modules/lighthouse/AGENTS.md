# Lighthouse HPC Cluster

This is the University of Michigan Lighthouse cluster with dedicated {{LH_GPU_TYPE}} GPUs for the group.

## Cross-Cluster Access

If you also use Great Lakes, use the `connect` skill to set up SSH. Once connected:

```bash
ssh greatlakes "sinfo -p spgpu2"
ssh greatlakes "squeue -u $(whoami)"
```

This enables the `slurm-status` skill to check both clusters and `submit-experiment` to submit remotely.

## Accounts

| Account | Partitions | GPU Type | Group Allocation |
|---|---|---|---|
| `{{LH_ACCOUNT}}` | {{LH_PARTITION}} | {{LH_GPU_TYPE}} | {{LH_GPU_COUNT}} GPUs total for the group |

## GPU Resources

| Partition | GPU | GPUs Available | Memory/GPU | Notes |
|---|---|---|---|---|
| {{LH_PARTITION}} | {{LH_GPU_TYPE}} | {{LH_GPU_COUNT}} (group total) | 80 GB | Shared among lab members |

## Common Submission Patterns

```bash
# Single {{LH_GPU_TYPE}}
sbatch --partition={{LH_PARTITION}} --account={{LH_ACCOUNT}} --gres=gpu:1 --mem=80G --time=8:00:00 job.sh

# Multi-GPU (up to {{LH_GPU_COUNT}})
sbatch --partition={{LH_PARTITION}} --account={{LH_ACCOUNT}} --gres=gpu:{{LH_GPU_COUNT}} --mem=320G --time=8:00:00 job.sh

# Interactive session
srun --partition={{LH_PARTITION}} --account={{LH_ACCOUNT}} --gres=gpu:1 --mem=80G --time=4:00:00 --pty bash
```

## Storage

- Turbo (`/nfs/turbo/`) is shared with Great Lakes, so containers, datasets, and checkpoints are accessible from both clusters.
- Home (`~/`) is also shared.
- Lighthouse does not have scratch storage.

## Key Constraints

- Only {{LH_GPU_COUNT}} {{LH_GPU_TYPE}} GPUs for the entire group. Coordinate before reserving multiple GPUs.
- Use the `slurm-status` skill to check real-time availability before submitting jobs.
- For multi-GPU training, consider whether the task truly benefits from parallelism.

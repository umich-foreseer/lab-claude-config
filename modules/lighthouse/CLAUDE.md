# Lighthouse HPC Cluster

This is the University of Michigan Lighthouse cluster with dedicated {{LH_GPU_TYPE}} GPUs for the group.

## Cross-Cluster Access (optional, for advanced users)

If you also use Great Lakes, you can submit Lighthouse jobs from there via SSH with a persistent control socket:

```bash
# Establish connection from Great Lakes (requires Duo MFA, lasts 24h)
ssh -o ControlMaster=yes -o ControlPath=~/.ssh/ctrl-lighthouse -o ControlPersist=24h lighthouse.arc-ts.umich.edu "echo connected && exit"

# All subsequent SSH commands multiplex over the socket — no re-auth needed
ssh -o ControlPath=~/.ssh/ctrl-lighthouse lighthouse.arc-ts.umich.edu "<command>"
```

This enables `/slurm-status` to check both clusters and `/submit-experiment` to submit remotely. If you only use Lighthouse directly, you can ignore this.

## Accounts

| Account | Partitions | GPU Type | Group Allocation |
|---|---|---|---|
| `{{LH_ACCOUNT}}` | {{LH_PARTITION}} | {{LH_GPU_TYPE}} | {{LH_GPU_COUNT}} GPUs total for the group |

## GPU Resources

| Partition | GPU | GPUs Available | Memory/GPU | Notes |
|---|---|---|---|---|
| {{LH_PARTITION}} | {{LH_GPU_TYPE}} | {{LH_GPU_COUNT}} (group total) | 80 GB | Shared among ~3-8 lab members |

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

- **Turbo** (`/nfs/turbo/`) is **shared with Great Lakes** — containers, datasets, and checkpoints are accessible from both clusters without copying.
- **Home** (`~/`) is also shared — same home directory on both clusters.
- Lighthouse does **not** have scratch storage.

## Key Constraints

- Only {{LH_GPU_COUNT}} {{LH_GPU_TYPE}} GPUs for the entire group — coordinate with lab mates before reserving multiple GPUs
- Use `/slurm-status` skill to check real-time availability before submitting jobs
- For multi-GPU training, consider whether the task truly benefits from parallelism

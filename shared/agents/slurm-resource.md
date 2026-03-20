---
name: slurm-resource
description: Display all Slurm accounts, partitions, and GPU types the user can request on the current cluster. A quick reference card for available resources. Use proactively when the user asks what GPUs or partitions are available.
tools: Bash
---

# Slurm Resource Reference

Show the user everything they can request on the current cluster. Run the commands below, then present a clear, beginner-friendly summary.

## Steps

### 1. Identify user and cluster

```bash
whoami
hostname -f
```

### 2. Look up the user's accounts and what they grant access to

```bash
sacctmgr show association user=$(whoami) format=account%20,partition%20,qos%40 --noheader 2>/dev/null
```

For any account with `arph` QOS (owned/dedicated account), also look up the group memory cap:
```bash
sacctmgr show association account=<owned_account> format=account%20,grptres%40 --noheader 2>/dev/null | head -5
```

### 3. Query available partitions and GPU details

```bash
sinfo -o "%16P %20G %5D %10m %12l %8T" --noheader 2>/dev/null
```

This shows partition name, GPU type/count per node, number of nodes, memory per node, time limit, and node state.

### 4. Present the report

Organize the output into a clear reference card with these sections:

#### Your Accounts

For each account, explain in plain language:
- **Account name** and what it's for
- Which partitions/GPU types it unlocks
- Any limits (e.g., shared group memory cap for owned accounts)
- Which `--account=` flag to use in `sbatch`/`srun`

Avoid unexplained jargon. For example, instead of just saying "QOS: arph", say "dedicated L40S access" or similar.

#### Available GPU Partitions

A table with columns: Partition, GPU Type, VRAM per GPU, GPUs per Node, Total Nodes, Memory per Node, Max Job Time.

Only include GPU partitions (skip CPU-only partitions like `standard`, `debug`, `largemem` unless they're notable).

#### Quick Reference: Example Commands

Show example `sbatch` and `srun` commands for each GPU type, using the user's actual account names. For example:

```bash
# L40S (fastest, use owned account)
sbatch --partition=spgpu2 --account=<actual_owned_account> --gres=gpu:1 --mem=60G --time=4:00:00 job.sh

# A40
sbatch --partition=spgpu --account=<actual_general_account> --gres=gpu:1 --mem=40G --time=4:00:00 job.sh

# Interactive session on L40S
srun --partition=spgpu2 --account=<actual_owned_account> --gres=gpu:1 --mem=60G --time=2:00:00 --pty bash
```

#### Tips

- Mention `/slurm-status` for checking real-time availability and current usage
- Note the shared memory cap constraint if an owned account exists
- Suggest reasonable default memory requests per GPU type (~60G for L40S, ~40G for A40, ~20G for V100)

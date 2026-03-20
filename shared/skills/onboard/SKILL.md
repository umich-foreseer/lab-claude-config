---
name: onboard
description: Onboard a new lab member onto the shared Claude Code configuration. Detects clusters, collects Slurm account details, runs setup, and helps customize personal config.
allowed-tools: Bash(git *), Bash(hostname *), Bash(sinfo *), Bash(sacctmgr *), Bash(whoami), Bash(which *), Bash(cat *), Bash(ls *), Bash(mkdir *), Bash(*/setup.sh *), Read, Edit, Write
---

# Lab Claude Code Setup — Onboarding

You are helping a new lab member set up the shared Claude Code configuration. Walk them through this interactively. Be friendly, welcoming, and concise.

Start with a greeting like: **"Welcome onboard, Foreseer!"** followed by a brief explanation of what this setup does: it connects Claude Code to the lab's shared configuration so Claude understands the cluster environment, knows what GPUs are available, and can help submit jobs correctly.

## Pre-flight checks

1. Check if `~/.claude/` exists. If not, tell the user to run `claude` once first and come back.

2. Check if the lab config repo is already cloned at `~/lab-claude-config/`. If not found, tell the user to clone it first:
   ```
   git clone https://github.com/umich-foreseer/lab-claude-config.git ~/lab-claude-config
   ```
   Then come back and run `/onboard` again.

3. Verify `jq` is available (`which jq`). If missing, suggest `module load jq` or installing it.

## Detect cluster and accounts

Do this proactively — don't ask the user to look things up. Run the commands yourself and present what you found.

### 1. Detect username

```bash
whoami
```

### 2. Detect which cluster(s)

Check hostname and available partitions:
```bash
hostname -f
sinfo -o "%12P %16G" --noheader 2>/dev/null | head -20
```

- If `spgpu2` partition exists → Great Lakes
- If hostname contains `lighthouse` or `lh-login` → Lighthouse
- If unclear, ask the user

### 3. Look up Slurm accounts

First, get account names and QOS:
```bash
sacctmgr show association user=$(whoami) format=account%20,partition%20,qos%40 --noheader 2>/dev/null
```

Then, look up the group memory cap for the owned account separately:
```bash
sacctmgr show association account=<owned_account> format=account%20,grptres%40 --noheader 2>/dev/null | head -5
```

Use this reference table to match `sacctmgr` output to the correct account-partition-GPU mapping. Do NOT ask the user to identify accounts — match them yourself:

| Account | Cluster | Partition(s) | GPUs | Billing |
|---|---|---|---|---|
| `qdj_project_owned1` | Great Lakes | spgpu2 | Up to 10 L40S (48G) | Prepaid (shared dynamic quota) |
| `qmei0` | Great Lakes | gpu, gpu-rtx6000, standard | V100, RTX Pro 6000 Blackwell | Prepaid (shared dynamic quota) |
| `qmei3` | Great Lakes | gpu, gpu-rtx6000, standard | V100, RTX Pro 6000 Blackwell | Pay-as-you-go |
| `qmei` | Lighthouse | qmei-a100 | 4x A100 (80G) | Dedicated |

From the `sacctmgr` output and the table above, identify:
- **Owned account**: the account with `arph` QOS (`qdj_project_owned1`) — for L40S GPUs on spgpu2
- **General account (prepaid)**: `qmei0` — for V100/RTX Pro 6000 Blackwell on gpu/gpu-rtx6000/standard
- **General account (pay-as-you-go)**: `qmei3` — same partitions, used when prepaid budget is exhausted
- **Lighthouse account**: `qmei` — for A100 GPUs on qmei-a100 partition
- **Memory cap**: check the `grptres` column for `mem=...G`, or default to 620 GB

### 4. Present findings and confirm

Show the user what you found in a clear, beginner-friendly summary. Avoid jargon where possible and briefly explain what each item means. For example:

> Here's what I detected for your cluster setup:
>
> - **Username**: `jsmith`
> - **Cluster**: Great Lakes (University of Michigan HPC)
> - **L40S account**: `qdj_project_owned1` — use this when requesting our lab's dedicated L40S GPUs (the fastest GPUs we have access to, 48 GB VRAM each)
> - **General account**: `qmei0` — use this for other GPU types (A40, V100, etc.) and CPU-only jobs
> - **Group memory cap**: 620 GB — this is the total memory our entire lab group can use on L40S nodes at the same time, so be mindful of large requests
>
> After setup, your CLAUDE.md will contain a full table of available GPU partitions and example job submission commands. You can also run `/slurm-status` anytime to check real-time GPU availability.
>
> Does this look right?

Use the reference table above to auto-fill account, partition, and GPU values. Only ask the user if their `sacctmgr` output contains accounts not listed in the reference table.

## Run setup

Once you have all values, write them to `~/lab-claude-config/build/.env.local` in this format:
```
# Lab Claude Config - saved template variables
GL_USERNAME=<value>
GL_ACCOUNT_OWNED=<value>
GL_ACCOUNT_GENERAL=<value>
GL_MEMORY_CAP=<value>
LH_USERNAME=<value>
LH_ACCOUNT=<value>
LH_GPU_COUNT=<value>
LH_GPU_TYPE=<value>
```

Only include variables for enabled modules. Then run:
```bash
cd ~/lab-claude-config && ./setup.sh --modules <modules> --non-interactive
```

Where `<modules>` is `greatlakes`, `lighthouse`, or `greatlakes,lighthouse`.

## Post-setup

After setup completes:

1. Show the user what was installed — read and summarize `~/.claude/CLAUDE.md` briefly.

2. Ask if they want to add anything personal to their CLAUDE.md. Examples:
   - Their turbo storage path (e.g., `/nfs/turbo/si-qmei/<username>/`)
   - Projects they're currently working on
   - Language/framework preferences
   - Any personal coding conventions

   If they do, append their content **below** the `<!-- END: lab-config -->` marker in `~/.claude/CLAUDE.md`.

3. Ask if they want to customize `~/.claude/settings.local.json`:
   - `skipDangerousModePermissionPrompt: true` — skips the safety prompt (experienced users only)
   - Additional tool permissions beyond the defaults
   - Any other preferences

4. Remind them:
   - To update: `cd ~/lab-claude-config && git pull && ./setup.sh`
   - Their personal content in CLAUDE.md (outside the markers) is never touched by setup.sh
   - `/slurm-status` is now available for checking cluster status

## If setup fails

- If `setup.sh` errors, read the error output and help debug.
- Common issues: missing `jq`, wrong account names, `~/.claude/` doesn't exist.
- The user can always re-run `./setup.sh` — it's idempotent.

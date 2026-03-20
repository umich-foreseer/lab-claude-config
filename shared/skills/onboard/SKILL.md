---
name: onboard
description: Onboard a new lab member onto the shared Claude Code configuration. Detects clusters, collects Slurm account details, runs setup, and helps customize personal config.
allowed-tools: Bash(git *), Bash(hostname *), Bash(sinfo *), Bash(sacctmgr *), Bash(whoami), Bash(which *), Bash(cat *), Bash(ls *), Bash(mkdir *), Bash(*/setup.sh *), Read, Edit, Write
---

# Lab Claude Code Setup — Onboarding

You are helping a lab member set up the shared Claude Code configuration. Walk them through this interactively. Be friendly and concise.

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

```bash
sacctmgr show association user=$(whoami) format=account%20,partition%20,qos%20,maxmem%15 --noheader 2>/dev/null
```

From the output, identify:
- **Great Lakes owned account**: the account with access to `spgpu2` partition and `arph` QOS (usually `*_project_owned1`)
- **Great Lakes general account**: the account with access to `gpu`, `spgpu`, etc. with `normal`/`interactive` QOS
- **Lighthouse account**: the account with access to GPU partitions on Lighthouse
- **Memory cap**: check the `maxmem` column for the owned account, or default to 620 GB

### 4. Present findings and confirm

Show the user what you found in a clear summary, e.g.:

> Here's what I detected:
> - **Username**: `jsmith`
> - **Cluster**: Great Lakes
> - **Owned account**: `qdj_project_owned1` (spgpu2/L40S, QOS: arph)
> - **General account**: `qmei0` (gpu, spgpu, etc.)
> - **Memory cap**: 620 GB
>
> Does this look right?

Only ask the user to fill in values you genuinely couldn't determine from `sacctmgr`. For Lighthouse GPU count and type, default to 4 and A100 80GB respectively — confirm with the user if they want different values.

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

# Codex Adapter

This file contains Codex-specific instructions layered on top of the shared lab configuration.

## Codex Operating Rules

- Be careful on shared HPC login nodes. Before running expensive commands, check `hostname` and whether `SLURM_JOB_ID` is set.
- If `SLURM_JOB_ID` is unset and the host looks like `gl-login*` or `lh-login*`, treat the shell as a login node.
- On login nodes, only run lightweight inspection, editing, Git, package management, and Slurm control commands.
- Do not run training, inference, test suites, large data processing, compilation of large codebases, or sustained CPU/GPU/I/O work on login nodes. Use `srun`, `salloc`, or `sbatch` instead.
- Inside a Slurm allocation (`SLURM_JOB_ID` set), arbitrary workloads are allowed.

## Available Codex Skills

Ask Codex to use these skills by name:

- `slurm-status` - real-time GPU and resource availability on the cluster.
- `slurm-job` - create or modify sbatch scripts with correct accounts, partitions, and best practices.
- `slurm-debug` - diagnose why a Slurm job failed, was killed, or is stuck.
- `submit-experiment` - submit a Slurm experiment with naming, documentation, and cross-cluster support.
- `harvest` - discover completed experiments, collect results, and update documentation.
- `onboard` - set up a lab member's Claude Code and/or Codex configuration.
- `connect` - set up cross-cluster SSH between Great Lakes and Lighthouse.
- `migrate` (experimental) - discover repo and compute assumptions, then plan migration to another lab's compute resources.
- `slurm-queue` - show active, pending, and recent jobs.
- `slurm-resource` - list accounts, partitions, and GPU types you can request.
- `slurm-storage` - scan home directory usage and suggest what to move to turbo.

Some shared skill docs mention Claude slash commands such as `/slurm-status`. In Codex, treat those as references to the Codex skill with the same name.

## Codex-Specific Constraints

- Codex does not use Claude's `settings.json`, statusline command, or hooks directly.
- Login-node safety rules live in `AGENTS.md` for Codex instead of relying on Claude hooks.
- Claude agents are installed as Codex skills because Codex skills are the durable reusable instruction unit.

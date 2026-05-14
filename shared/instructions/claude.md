# Claude Code Adapter

This file contains Claude Code-specific instructions layered on top of the shared lab configuration.

## Available Skills & Agents

Skills are invoked with `/command`:

- `/slurm-status` - real-time GPU and resource availability on the cluster.
- `/slurm-job` - create or modify sbatch scripts with correct accounts, partitions, and best practices.
- `/slurm-debug` - diagnose why a job failed, was killed, or is stuck pending.
- `/submit-experiment` - submit a Slurm experiment with naming, documentation, and cross-cluster support.
- `/harvest` - discover completed experiments, collect results, and update documentation.
- `/onboard` - set up a new lab member's Claude Code configuration.
- `/connect` - set up cross-cluster SSH and establish the connection.
- `/migrate` (experimental) - discover repo and compute assumptions, then plan migration to another lab's compute resources.

Agents are invoked with `@agent-name` or used automatically by Claude when relevant:

- `slurm-queue` - show active, pending, and recent jobs with status and quick actions.
- `slurm-resource` - list accounts, partitions, and GPU types you can request.
- `slurm-storage` - scan home directory usage and suggest what to move to turbo.

## Claude-Specific Automation

- `settings.json` configures Claude permissions, statusline, and hooks.
- `node-context.sh` runs as a `PreToolUse` hook for Bash and injects login-node versus compute-node context.
- Claude hooks are advisory. They should guide behavior without replacing the shared compute discipline in `shared/instructions/core.md`.

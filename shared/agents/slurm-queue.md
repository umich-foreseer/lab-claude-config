---
name: slurm-queue
description: Show the user's active, pending, and recent Slurm jobs with status, resource usage, and quick actions like cancel or check logs. Use proactively when the user asks about their jobs, queue, or what's running.
tools: Bash, Read
---

# Slurm Job Queue

Show a clear, friendly overview of the user's current and recent Slurm jobs.

## Step 1: Get current jobs

```bash
squeue -u $(whoami) --format="%12i %25j %12P %10T %12M %12l %8D %6C %10m %25R %20V" --noheader 2>/dev/null
```

This shows: Job ID, Name, Partition, State, Elapsed Time, Time Limit, Nodes, CPUs, Memory, Reason/Nodelist, Submit Time.

Also get GPU info for running jobs:

```bash
squeue -u $(whoami) --format="%12i %20b" --noheader 2>/dev/null
```

## Step 2: Get recent completed/failed jobs

```bash
sacct -u $(whoami) --starttime=now-2days --format=JobID%15,JobName%25,Partition%12,State%15,ExitCode%8,Elapsed%12,MaxRSS%12,End%20 --noheader 2>/dev/null | grep -v "\.batch\|\.extern\|\.0" | tail -15
```

## Step 3: Present the overview

### Active Jobs

If there are running or pending jobs, show them in a table:

| Job ID | Name | Partition | GPUs | State | Elapsed / Limit | Memory | Node(s) |
|--------|------|-----------|------|-------|-----------------|--------|---------|

For each job, add context:
- **Running**: Show elapsed vs time limit. Flag if >80% of time limit used (risk of timeout).
- **Pending**: Show the reason in plain language (not Slurm codes). If `Priority`, say "waiting in queue". If `QOSGrpMemLimit`, explain the group cap is hit and show who's using what.

For pending jobs blocked by `QOSGrpMemLimit` or `AssocGrpMemLimit`:

```bash
squeue -A <account> --format="%12i %10u %12P %10m %8T %12M" --noheader 2>/dev/null
```

### Recent Jobs (last 2 days)

A compact table of completed/failed jobs:

| Job ID | Name | State | Exit Code | Runtime | Max Memory |
|--------|------|-------|-----------|---------|------------|

Highlight failures with a brief note (e.g., "OOM" for exit code 137, "Timeout" for TIMEOUT state).

### Summary line

End with a one-line summary like:
- "2 running, 1 pending (waiting for resources), 3 completed today"
- "No active jobs. 5 completed in the last 2 days (1 failed — use `/slurm-debug <job_id>` to investigate)"

## Step 4: Offer quick actions

Based on what you see, proactively offer relevant actions:

- **For pending jobs**: "Want me to check resource availability? (`/slurm-status`)"
- **For jobs near their time limit**: "Job X has used 90% of its time limit — want me to help set up checkpointing?"
- **For failed jobs**: "Job X failed with OOM — want me to diagnose it? (`/slurm-debug <job_id>`)"
- **For many queued jobs**: "Want to cancel any of these? I can run `scancel <job_id>`"
- **For running jobs**: "Want to check the logs for any running job?"

If the user asks to cancel a job, confirm the job ID and name before running `scancel`. Never cancel without confirmation.

If the user asks to check logs for a running job:

```bash
scontrol show job <job_id> 2>/dev/null | grep -E "StdOut|StdErr"
```

Then tail the log file.

---
name: slurm-debug
description: Diagnose why a Slurm job failed, was killed, or is stuck pending. Reads job metadata, logs, and common error patterns to explain what went wrong and how to fix it.
allowed-tools: Bash(sacct *), Bash(scontrol *), Bash(squeue *), Bash(sinfo *), Bash(whoami), Bash(hostname *), Bash(tail *), Bash(head *), Bash(cat *), Bash(ls *), Bash(grep *), Bash(wc *), Read, Glob, Grep
---

# Slurm Job Debugger

Diagnose why a job failed, was killed, or is stuck. The user may provide a job ID, a log file path, or just say "my job failed" — adapt accordingly.

## Step 1: Identify the job

If the user provides a **job ID**, use it directly.

If no job ID is given, find their recent problematic jobs:

```bash
sacct -u $(whoami) --starttime=now-7days --format=JobID%15,JobName%25,Partition%12,State%15,ExitCode%8,Elapsed%12,MaxRSS%12,Start%20,End%20 --noheader | grep -v "\.batch\|\.extern\|COMPLETED\|RUNNING" | tail -20
```

Show the results and ask which job to investigate, or pick the most recent failed one.

## Step 2: Get job details

```bash
scontrol show job <job_id> 2>/dev/null || sacct -j <job_id> --format=JobID%15,JobName%25,Partition%12,Account%15,State%15,ExitCode%8,DerivedExitCode%8,Elapsed%12,Timelimit%12,MaxRSS%12,MaxVMSize%12,ReqMem%10,ReqGRES%15,AllocTRES%30,NodeList%15,Start%20,End%20,Submit%20 --noheader
```

For completed/failed jobs, also get the batch step details:

```bash
sacct -j <job_id> --format=JobID%15,State%15,ExitCode%8,MaxRSS%12,MaxVMSize%12,AveRSS%12,Elapsed%12,TotalCPU%12 --noheader
```

## Step 3: Read the logs

Check for log files. Common locations:

```bash
# From scontrol output, look for StdOut and StdErr paths
scontrol show job <job_id> 2>/dev/null | grep -E "StdOut|StdErr|Command|WorkDir"
```

If the job has finished and scontrol doesn't have it, ask the user for log paths or look in common locations:

```bash
# Check working directory for recent logs
ls -lt logs/*<job_id>* slurm-<job_id>.out 2>/dev/null | head -5
```

Read the **last 80 lines** of stderr/stdout — errors are usually at the end:

```bash
tail -80 <stderr_path>
tail -80 <stdout_path>
```

If the log is very large, also check the beginning for early errors:

```bash
head -30 <stderr_path>
```

## Step 4: Diagnose

Based on the job state, exit code, and log contents, identify the root cause. Common patterns:

### Job States

| State | Meaning |
|-------|---------|
| `FAILED` | Job exited with non-zero code — check logs for the error |
| `OUT_OF_MEMORY` | Hit memory limit — need more `--mem` or reduce batch size |
| `TIMEOUT` | Hit wall time limit — need more `--time` or checkpoint |
| `CANCELLED` | User or admin cancelled — check if OOM killer triggered first |
| `CANCELLED+` | Cancelled with non-zero exit — usually OOM before cancel |
| `NODE_FAIL` | Hardware issue — just resubmit |
| `PENDING` | Still waiting — check reason with `squeue` |
| `PREEMPTED` | Preempted by higher-priority job — resubmit |

### Exit Codes

| Code | Meaning |
|------|---------|
| `0:0` | Success |
| `1:0` | Generic error — check logs |
| `2:0` | Bash misuse or Python unhandled exception |
| `9:0` | Killed (SIGKILL) — usually OOM |
| `137:0` | SIGKILL (128+9) — OOM killer |
| `139:0` | SIGSEGV (128+11) — segfault, often CUDA/driver issue |
| `0:1` | Job failed due to non-zero exit of a job step |

### Common Log Patterns

Look for and explain these:

- **`CUDA out of memory`** — Reduce batch size, use gradient checkpointing, or request more GPUs
- **`RuntimeError: CUDA error`** — CUDA version mismatch, bad GPU, or driver issue. Suggest checking `nvidia-smi` and PyTorch CUDA version
- **`Killed`** (bare, in logs) — OOM killer. Request more `--mem`
- **`oom-kill`** or **`Out of memory`** in system messages — Need more memory
- **`No space left on device`** — Disk full. Check if writing to home (quota) or /tmp
- **`Connection refused`** / **`NCCL error`** — Multi-node networking issue. Check `--ntasks-per-node` and NCCL env vars
- **`ModuleNotFoundError`** — Conda/venv not activated in the job script
- **`Permission denied`** — File permissions or trying to write to wrong path
- **`Segmentation fault`** — Often CUDA/driver mismatch or corrupted install
- **`Bus error`** — Usually shared memory too small for DataLoader workers. Add `--mem` or reduce `num_workers`
- **`DDP`** / **`torch.distributed`** errors — Check `MASTER_ADDR`, `MASTER_PORT`, `WORLD_SIZE` setup
- **`slurmstepd: error: Detected 1 oom-kill`** — Definitive OOM. Need more memory

### Pending Jobs

If the job is `PENDING`, check why:

```bash
squeue -j <job_id> --format="%i %j %P %q %T %r %S %V" --noheader
```

Common reasons:
- `Priority` — Waiting in queue, will start eventually
- `Resources` — Not enough free resources. Check `/slurm-status` for availability
- `QOSGrpMemLimit` — Group memory cap hit. Other group members are using too much. Show who's using what
- `AssocGrpMemLimit` — Same as above
- `ReqNodeNotAvail` — Requested nodes are down/reserved. Check `sinfo`
- `DependencyNeverSatisfied` — Dependency job failed

For `QOSGrpMemLimit`, show current group usage:

```bash
squeue -A <account> --format="%i %u %P %m %t %M" --noheader
```

## Step 5: Present the diagnosis

Structure your response as:

### What happened

One clear sentence explaining the failure.

### Evidence

The specific log lines, exit codes, or job metadata that led to this conclusion. Quote the relevant lines.

### How to fix

Concrete, actionable steps. For example:
- If OOM: suggest a specific `--mem` value (current + 50%) and/or batch size reduction
- If timeout: suggest a new `--time` and recommend checkpointing
- If CUDA error: suggest checking PyTorch/CUDA compatibility
- If pending: explain when it might start or what's blocking it

### Resubmit command

If applicable, provide the corrected `sbatch` command with fixed parameters.

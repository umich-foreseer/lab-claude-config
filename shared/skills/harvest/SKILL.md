---
name: harvest
description: Discover completed SLURM experiments, collect results, and update experiment documentation.
argument-hint: [--auto] [experiment-name]
allowed-tools: Bash(sacct *), Bash(scontrol *), Bash(squeue *), Bash(ls *), Bash(tail *), Bash(jq *), Bash(hostname *), Bash(date *), Bash(cat *), Bash(find *), Read, Edit, Write, Glob, Grep
---

# Harvest Experiment Results

Discover completed SLURM experiments, collect their results, and update experiment documentation (`docs/experiments.md` index + `docs/experiments/<detail>.md` files).

## Arguments

- No args: discover and harvest **all** pending experiments
- `$ARGUMENTS[0]` = `--auto`: skip confirmation, harvest silently (useful with `/loop`)
- `$ARGUMENTS[0]` = experiment name: harvest only that specific experiment

## Workflow

### Step 0: Discover project context

Before collecting results, understand what this project tracks:

1. **Read the project's `CLAUDE.md`** (repo root). Look for:
   - Where result files are stored and their format
   - What metrics matter (e.g. accuracy, loss, F1, BLEU, perplexity)
   - Post-processing or summary commands to run after harvesting
   - Log file locations and naming patterns
   - Job types and their result collection strategies

2. **Learn the reporting style**: Read 1-2 existing **completed** detail files in `docs/experiments/` (those with real Results content, not "Pending"). This shows:
   - What metrics are reported and in what format (tables, bullet points)
   - How observations are written
   - What level of detail is expected

3. If no completed detail files exist and CLAUDE.md doesn't specify metrics, collect whatever quantitative results are found in output files and logs.

### Step 1: Discover harvestable experiments

Use **both** methods in parallel and deduplicate:

#### Method A: Completion markers

```bash
ls logs/*.done.json 2>/dev/null
```

Read each `.done.json` file. Expected schema:
```json
{
  "experiment_name": "...",
  "job_id": "...",
  "job_type": "...",
  "status": "completed|failed",
  "finished_at": "ISO 8601",
  "checkpoint": "... (optional)",
  "wandb_run_id": "... (optional)"
}
```

#### Method B: Fallback sacct scan

Read `docs/experiments/` detail files. Find those with `**Status**: Submitted` or `**Status**: Running`. Extract the Job ID from the `**Job ID**:` line.

For each, check SLURM:
```bash
sacct -j <JOB_ID> --format=JobID%15,State%15,ExitCode%8,Elapsed%12,End%20 --noheader --parsable2 2>/dev/null
```

A job is harvestable if its state is `COMPLETED`, `FAILED`, `TIMEOUT`, `CANCELLED`, or `OUT_OF_MEMORY`.

#### Filter already-harvested

Skip any experiment whose detail file already has real results in the `## Results` section (i.e., not just "Pending" or "_To be filled_").

If a specific experiment name was provided as an argument, only harvest that one.

### Step 2: Show discovery summary

Print what was found:
```
Found N harvestable experiment(s):
  - experiment-name-1 (job 12345) — COMPLETED
  - experiment-name-2 (job 12346) — FAILED
```

If `--auto` was NOT passed, ask the user for confirmation before proceeding. If nothing found, report "No pending experiments to harvest" and exit.

### Step 3: Collect results for each experiment

The collection strategy depends on the job outcome.

#### For COMPLETED jobs

1. **Read the experiment's detail file** — the Goal and Setup sections describe what was run and what to look for.

2. **Find result files** — use the project's CLAUDE.md to know where results are stored. Common patterns:
   - Result JSONs in a results directory (check CLAUDE.md for path)
   - Output files in `results/`, `output/`, or a turbo storage path
   - Metrics printed in SLURM log output

3. **Read SLURM log tail** (last 50 lines of `logs/<name>_<jobid>.out`) for:
   - Completion messages and timing
   - Inline results or metrics printed at end of job
   - Training duration, checkpoint paths

4. **Extract metrics** — use the project's CLAUDE.md and the reporting style from Step 0 to know which metrics to extract and how to format them.

5. If the `.done.json` marker has a `checkpoint` field, note it for the results.

#### For FAILED / TIMEOUT / CANCELLED / OUT_OF_MEMORY jobs

1. Read SLURM log tail (`.out` and `.err`, last 50 lines each) for error messages.
2. Run `sacct -j <JOB_ID> --format=State,ExitCode,MaxRSS,Elapsed --noheader --parsable2` for resource usage.
3. Check for partial results (e.g. training finished but post-processing didn't run).
4. Summarize the failure reason.

### Step 4: Update documentation

For each harvested experiment:

#### 4a: Update detail file (`docs/experiments/<date>_<name>.md`)

- Change `**Status**: Submitted` or `**Status**: Running` to the actual status (`Completed`, `Failed`, `Timed out`, `Cancelled`, `Out of memory`)
- Replace the `## Results` section content:
  - For completed jobs with metrics: use a table or bullet list matching the project's reporting style (learned in Step 0)
  - For failed jobs: brief failure description
- Update `## Observations` with a brief interpretation (1-2 sentences based on the results and the Goal section)

#### 4b: Update index (`docs/experiments.md`)

Find the bullet for this experiment and update with the key result. Example:
- Before: `- **sft-llama7b-baseline** (7B full-FT): First SFT run on Llama. [detail](...)`
- After: `- **sft-llama7b-baseline** (7B full-FT): 72.3% val acc — strong baseline. [detail](...)`

Keep the `[detail](...)` link. Keep entry under 100 words.

#### 4c: Run post-processing (if configured)

If the project's CLAUDE.md specifies a results summary command (e.g. a script that aggregates results), run it.

### Step 5: Report

Print a summary:

```
Harvested N experiment(s):

  experiment-name (job 12345) — COMPLETED
    Key result: XX.X% accuracy (or whatever the primary metric is)
    Updated: docs/experiments/YYYY-MM-DD_name.md
    Updated: docs/experiments.md

Remaining pending: M experiment(s)
```

## Edge Cases

- **No result files found**: Report "No result files found for <name>." Update status but leave Results as "No results produced."
- **Partial results**: Report which parts succeeded and which are missing.
- **Job still running**: Skip with message "Still running (elapsed: HH:MM:SS)"
- **Job pending**: Skip with message "Still pending in queue"
- **Multiple jobs for same experiment**: Use the most recent (highest job ID)
- **Cross-cluster jobs**: `sacct` may not work for jobs on a remote cluster. Fall back to marker files. If neither works, note that results must be harvested from the remote cluster.

## Environment Check

Check hostname to determine access level:
- Login node: Full access to sacct, logs, result files
- Compute node: sacct works but warn user this is unusual for harvesting
- Local/unknown: No sacct — rely on marker files and result files only

## `.done.json` Marker Convention

Job scripts are encouraged to write a completion marker so `/harvest` can auto-discover finished experiments:

**Location**: `logs/<experiment_name>_<job_id>.done.json`

**Schema**:
```json
{
  "experiment_name": "string (matches EXPERIMENT_NAME env var)",
  "job_id": "string (SLURM job ID)",
  "job_type": "string (project-defined job type)",
  "status": "completed | failed",
  "finished_at": "ISO 8601 timestamp",
  "checkpoint": "string (path to final checkpoint, optional)",
  "wandb_run_id": "string (optional)"
}
```

This is a **convention, not a requirement**. If markers are not present, the skill falls back to sacct scanning of experiments found in `docs/experiments/` detail files.

#!/usr/bin/env bash
# PreToolUse hook for Bash commands — injects node-type context
# so Claude knows whether heavy operations are safe.
#
# On compute nodes: reports job ID, GPU count, memory — confirms heavy ops OK
# On login nodes:   warns against heavy operations, suggests srun/sbatch
# On unknown hosts:  outputs {} (no context, graceful degradation)
#
# Never blocks — always allows the command to proceed.

set -euo pipefail

# Only act on Bash tool invocations
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"

if [[ "$TOOL_NAME" != "Bash" ]]; then
    echo '{}'
    exit 0
fi

# Fast path: if SLURM_JOB_ID is set, we're on a compute node
if [[ -n "${SLURM_JOB_ID:-}" ]]; then
    GPU_COUNT="${SLURM_GPUS_ON_NODE:-${CUDA_VISIBLE_DEVICES:+$(echo "$CUDA_VISIBLE_DEVICES" | tr ',' '\n' | wc -l)}}"
    GPU_COUNT="${GPU_COUNT:-0}"
    MEM_MB="${SLURM_MEM_PER_NODE:-unknown}"

    jq -n \
        --arg job_id "$SLURM_JOB_ID" \
        --arg gpus "$GPU_COUNT" \
        --arg mem "$MEM_MB" \
        --arg partition "${SLURM_JOB_PARTITION:-unknown}" \
        '{
            additionalContext: "COMPUTE NODE — Slurm job \($job_id) on partition \($partition) with \($gpus) GPU(s) and \($mem) MB memory. Heavy operations (training, builds, data processing) are safe to run here."
        }'
    exit 0
fi

# Fallback: check hostname pattern for login nodes
HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

if [[ "$HOSTNAME" =~ gl-login|lh-login|greatlakes\.arc-ts|lighthouse\.arc-ts ]]; then
    jq -n '{
        additionalContext: "LOGIN NODE — This is a shared login node. Do NOT run CPU/GPU/memory-intensive jobs here. Use srun/salloc for interactive compute or sbatch for batch jobs."
    }'
    exit 0
fi

# Unknown host — no context
echo '{}'

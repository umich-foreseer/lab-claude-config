#!/usr/bin/env bash
# PreToolUse hook: block ad-hoc Python execution on HPC login nodes.
#
# Policy (lab CLAUDE.md compute discipline): no CPU/GPU/memory-intensive jobs
# on login nodes. This hook rejects Bash calls that execute Python (python,
# pytest, torchrun, uv run, ...) when the current host is a greatlakes /
# lighthouse login node AND no SLURM allocation is active. Inspection commands
# (python -V, pip install, uv sync, python -m venv, conda install, ...) stay
# allowed so trivial tooling still works.
#
# Inside an allocation (SLURM_JOB_ID set) everything passes through untouched:
# the agent can salloc once and attach later with `srun --jobid=$SLURM_JOB_ID`,
# or use `srun` per request.
#
# Exit codes:
#   0 - allow the command
#   1 - block the command (message to stderr)
#
# Used together with shared/hooks/node-context.sh which remains advisory-only.

set -uo pipefail   # no -e: grep's non-match exit 1 is expected as a signal

INPUT="$(cat)"

# ---------- 1. Scope: only Bash tool calls ----------
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi

# ---------- 2. Compute-node bypass ----------
# Same fast-path as shared/hooks/node-context.sh:22-37 — if we're inside a
# SLURM allocation, heavy commands are fine.
if [[ -n "${SLURM_JOB_ID:-}" ]]; then
    exit 0
fi

# ---------- 3. Login-node detection ----------
# Same hostname regex as shared/hooks/node-context.sh:40-47 and .zshrc:89-92.
HOST="$(hostname -f 2>/dev/null || hostname)"
if ! [[ "$HOST" =~ gl-login|lh-login|greatlakes\.arc-ts|lighthouse\.arc-ts ]]; then
    exit 0   # unknown host (local mac etc.) — don't interfere
fi

# ---------- 4. Extract the command ----------
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
if [[ -z "$CMD" ]]; then
    exit 0
fi

# ---------- 5. Allowlist strip ----------
# Remove known-cheap inspection invocations from the command so a compound
# like `pip install foo && python train.py` still trips the blocklist on the
# `python train.py` half. Each pattern uses command-position boundaries:
#
#   START = (^|[[:space:];&|`$/(])     -- start, whitespace, or a shell sep
#   END   = ([[:space:];&|)]|$)        -- end, whitespace, or a shell sep
#
# This avoids false positives like `cat python.txt` (END='.', not a sep) and
# `mypy --python-version` (START='-', not a sep) while still catching
# `/usr/bin/python foo.py`, `$(python -c ...)`, `cd x && python y.py`, etc.
#
# The tail `[^;&|]*` on consuming patterns (pip/uv/conda/pipx and python -m
# pip/venv) eats the rest of the clause so that e.g. `pip install torchrun`
# fully disappears and its `torchrun` argument can't accidentally re-trip
# the blocklist.
CLEANED="$(printf '%s' "$CMD" | sed -E '
s#(^|[[:space:];&|`$/(])(grep|egrep|fgrep|rg|ag|ack)[[:space:]]+[^;&|]*# #g
s#(^|[[:space:];&|`$/(])python[23]?[[:space:]]+(-V|--version)([[:space:];&|)]|$)#\1 \3#g
s#(^|[[:space:];&|`$/(])python[23]?[[:space:]]+-m[[:space:]]+(pip|venv)([[:space:];&|)]|$)[^;&|]*#\1 #g
s#(^|[[:space:];&|`$/(])pip[[:space:]]+(install|list|show|freeze|config|index|check|download|wheel|hash|debug)([[:space:];&|)]|$)[^;&|]*#\1 #g
s#(^|[[:space:];&|`$/(])uv[[:space:]]+(sync|lock|add|remove|pip|cache|venv|build|publish|self|init|export|tree|version)([[:space:];&|)]|$)[^;&|]*#\1 #g
s#(^|[[:space:];&|`$/(])conda[[:space:]]+(install|create|remove|list|info|env|config|search|update|upgrade|activate|deactivate|clean)([[:space:];&|)]|$)[^;&|]*#\1 #g
s#(^|[[:space:];&|`$/(])pipx[[:space:]]+(install|list|show|upgrade|uninstall|reinstall|ensurepath|inject)([[:space:];&|)]|$)[^;&|]*#\1 #g
s#(^|[[:space:];&|`$/(])(which|type)[[:space:]]+(python[23]?|ipython[23]?|jupyter[a-z-]*|pytest|torchrun|deepspeed|uv|uvx|poetry|conda|pipx|accelerate|pypy[23]?)([[:space:];&|)]|$)#\1 \4#g
s#(^|[[:space:];&|`$/(])command[[:space:]]+-v[[:space:]]+(python[23]?|ipython[23]?|jupyter[a-z-]*|pytest|torchrun|deepspeed|uv|uvx|poetry|conda|pipx|accelerate|pypy[23]?)([[:space:];&|)]|$)#\1 \3#g
')"

# ---------- 6. Blocklist scan ----------
# Any command-position Python launcher that survived the strip means the
# agent is trying to run Python on the login node.
BLOCK_RE='(^|[[:space:];&|`$/(])(python[23]?|ipython[23]?|jupyter[a-z-]*|pytest|torchrun|deepspeed|pypy[23]?|uvx|accelerate[[:space:]]+launch|(uv|poetry|conda|pipx)[[:space:]]+run|uv[[:space:]]+tool[[:space:]]+run)([[:space:];&|)]|$)'

if printf '%s' "$CLEANED" | grep -qE "$BLOCK_RE"; then
    echo "BLOCKED: Python execution on login node ($HOST). Use srun or salloc — see ~/.claude/CLAUDE.md compute discipline." >&2
    # Exit 2 is the Claude Code hook contract for "deny this tool call":
    # stderr is fed back to the model as a permission-denied reason.
    # Exit 1 would only surface as a non-blocking error and the tool would still run.
    exit 2
fi

exit 0

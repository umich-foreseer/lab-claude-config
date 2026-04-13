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

# ---------- 5. Normalize multiline shell syntax ----------
# The regex strip runs statement-by-statement, so normalize the two multiline
# forms that matter for Slurm dispatch first:
#
# 1. Backslash-newline continuation: `srun \` + newline + `python foo.py`
#    is one logical `srun python foo.py` statement and should be allowed.
#    Direct `python \` + newline + `train.py` still blocks after collapse
#    because it remains a direct Python invocation.
#
# 2. Slurm heredocs: `srun bash <<EOF ... EOF` dispatches the shell to a
#    compute node, so Python inside the heredoc body must not be scanned as
#    login-node execution. A small awk pass deletes heredoc bodies attached
#    to srun/sbatch/salloc lines before the existing strip/block regexes run.
#    Supported delimiters intentionally match the documented hook contract:
#    shell identifiers only (`[A-Za-z_][A-Za-z0-9_]*`) with `<<`, `<<-`,
#    `<<'TAG'`, and `<<"TAG"` spellings.
CMD_NORMALIZED="$(printf '%s' "$CMD" | sed -zE 's/\\\n[[:blank:]]*/ /g')"
CMD_NORMALIZED="$(
    printf '%s' "$CMD_NORMALIZED" | awk '
function enqueue(tag, strip_tabs) {
    pending_count++
    pending_tag[pending_count] = tag
    pending_strip[pending_count] = strip_tabs
}

function dequeue(    i) {
    for (i = 1; i < pending_count; i++) {
        pending_tag[i] = pending_tag[i + 1]
        pending_strip[i] = pending_strip[i + 1]
    }
    delete pending_tag[pending_count]
    delete pending_strip[pending_count]
    pending_count--
}

function dispatch_offset(line,    matched) {
    if (!match(line, /(^|[[:space:];&|`$/(])(srun|sbatch|salloc)[[:blank:]]+/)) {
        return 0
    }

    matched = substr(line, RSTART, RLENGTH)
    if (matched ~ /^[[:space:];&|`$/(]/) {
        return RSTART + 1
    }

    return RSTART
}

function collect_heredocs(segment,    sq, dq, quote, escaped, i, j, c, tag, strip_tabs) {
    sq = sprintf("%c", 39)
    dq = "\""
    quote = ""
    escaped = 0

    for (i = 1; i <= length(segment); i++) {
        c = substr(segment, i, 1)

        if (quote == dq) {
            if (escaped) {
                escaped = 0
                continue
            }
            if (c == "\\") {
                escaped = 1
                continue
            }
            if (c == dq) {
                quote = ""
            }
            continue
        }

        if (quote == sq) {
            if (c == sq) {
                quote = ""
            }
            continue
        }

        if (c == sq) {
            quote = sq
            continue
        }
        if (c == dq) {
            quote = dq
            continue
        }
        if (substr(segment, i, 2) != "<<") {
            continue
        }

        j = i + 2
        strip_tabs = 0
        if (substr(segment, j, 1) == "-") {
            strip_tabs = 1
            j++
        }

        tag = ""
        c = substr(segment, j, 1)

        if (c == sq || c == dq) {
            quote = c
            j++
            while (j <= length(segment) && substr(segment, j, 1) != quote) {
                tag = tag substr(segment, j, 1)
                j++
            }
            if (j <= length(segment) && tag ~ /^[A-Za-z_][A-Za-z0-9_]*$/) {
                enqueue(tag, strip_tabs)
                i = j
            }
            continue
        }

        if (c !~ /[A-Za-z_]/) {
            continue
        }

        tag = c
        j++
        while (j <= length(segment) && substr(segment, j, 1) ~ /[A-Za-z0-9_]/) {
            tag = tag substr(segment, j, 1)
            j++
        }

        enqueue(tag, strip_tabs)
        i = j - 1
    }
}

function closes_pending(line,    probe) {
    probe = line
    if (pending_strip[1]) {
        sub(/^\t+/, "", probe)
    }

    if (probe == pending_tag[1]) {
        close_rest = ""
        return 1
    }

    if (match(probe, ("^" pending_tag[1] "([[:blank:]]*[;&|].*)$"))) {
        close_rest = substr(probe, length(pending_tag[1]) + 1)
        return 1
    }

    return 0
}

BEGIN {
    pending_count = 0
    out_count = 0
}

{
    line = $0

    while (1) {
        if (pending_count > 0) {
            if (!closes_pending(line)) {
                line = ""
                break
            }

            dequeue()
            line = close_rest

            # A close-line trailer like `&& python bar.py` should still be
            # scanned as a fresh login-node statement. If multiple heredocs
            # are pending, body parsing resumes on the next physical line.
            if (line == "" || pending_count > 0) {
                line = ""
                break
            }
        }

        dispatch = dispatch_offset(line)
        if (dispatch > 0) {
            collect_heredocs(substr(line, dispatch))
        }

        if (line != "") {
            out[++out_count] = line
        }
        break
    }
}

END {
    for (i = 1; i <= out_count; i++) {
        printf "%s", out[i]
        if (i < out_count) {
            printf "\n"
        }
    }
}
')"

# ---------- 6. Allowlist strip ----------
# Remove known-cheap inspection invocations from the command so a compound
# like `pip install foo && python train.py` still trips the blocklist on the
# `python train.py` half. Each pattern uses command-position boundaries:
#
#   START   = (^|[[:space:];&|`$/(])    -- start, whitespace, or a shell sep
#   KEYSEP  = [[:blank:]]+               -- space/tab between keyword tokens
#   END_NC  = ([[:space:];&|)]|$)        -- end delim for non-consuming strips
#   END_CO  = ([[:blank:];&|)]|$)        -- end delim for consuming strips
#   TAIL    = [^;&|\n]*                  -- args of the current statement
#
# Two distinctions matter under `sed -zE` (whole input is one record):
#
# 1. KEYSEP between keywords (e.g. `pip` + sep + `install`) uses [[:blank:]]
#    not [[:space:]] so that `pip\ninstall` cannot be matched as one token —
#    that would let `pip\ninstall foo\npython train.py` strip across two
#    unrelated statements and silently allow the python.
#
# 2. END_CO on consuming patterns (those with a TAIL) excludes \n. If \n
#    were in END_CO, the tail would start on the *next* line and eat it:
#    `uv sync\npytest tests/` would match `uv sync` + END_CO=\n, then TAIL
#    consumes `pytest tests/` because `pytest` is not in [;&|\n]. Excluding
#    \n from END_CO makes the strip fail on the bare `uv sync`, so the
#    blocklist still gets to scan the trailing `pytest`. Non-consuming
#    strips (which/type/command -v/python -V) keep \n in END_NC because
#    they have no tail to misroute and they DO need to neutralize cases
#    like `which python\nipython` so the lone `ipython` blocks correctly.
#
# srun/sbatch/salloc bypass: any python that survives a dispatcher is not
# running on the login node — Slurm ships it to a compute node by definition.
# Stripping the dispatcher and its arguments leaves only the tokens that
# actually run locally for the blocklist to scan. The dispatcher strip uses
# the consuming form (KEYSEP + TAIL, no end-delim alternation) so that
# `srun;python foo` does NOT match — the bare `srun` is harmless and the
# trailing `python foo` runs on the login node, which the blocklist catches.
#
# Multiline Slurm dispatch has already been normalized above, so the regex
# strip only has to reason about single logical statements here.
CLEANED="$(printf '%s' "$CMD_NORMALIZED" | sed -zE '
s#(^|[[:space:];&|`$/(])(grep|egrep|fgrep|rg|ag|ack)[[:blank:]]+[^;&|\n]*# #g
s#(^|[[:space:];&|`$/(])python[23]?[[:blank:]]+(-V|--version)([[:space:];&|)]|$)#\1 \3#g
s#(^|[[:space:];&|`$/(])python[23]?[[:blank:]]+-m[[:blank:]]+(pip|venv)([[:blank:];&|)]|$)[^;&|\n]*#\1 #g
s#(^|[[:space:];&|`$/(])pip[[:blank:]]+(install|list|show|freeze|config|index|check|download|wheel|hash|debug)([[:blank:];&|)]|$)[^;&|\n]*#\1 #g
s#(^|[[:space:];&|`$/(])uv[[:blank:]]+(sync|lock|add|remove|pip|cache|venv|build|publish|self|init|export|tree|version)([[:blank:];&|)]|$)[^;&|\n]*#\1 #g
s#(^|[[:space:];&|`$/(])conda[[:blank:]]+(install|create|remove|list|info|env|config|search|update|upgrade|activate|deactivate|clean)([[:blank:];&|)]|$)[^;&|\n]*#\1 #g
s#(^|[[:space:];&|`$/(])pipx[[:blank:]]+(install|list|show|upgrade|uninstall|reinstall|ensurepath|inject)([[:blank:];&|)]|$)[^;&|\n]*#\1 #g
s#(^|[[:space:];&|`$/(])(srun|sbatch|salloc)[[:blank:]]+[^;&|\n]*#\1 #g
s#(^|[[:space:];&|`$/(])(which|type)[[:blank:]]+(python[23]?|ipython[23]?|jupyter[a-z-]*|pytest|torchrun|deepspeed|uv|uvx|poetry|conda|pipx|accelerate|pypy[23]?)([[:space:];&|)]|$)#\1 \4#g
s#(^|[[:space:];&|`$/(])command[[:blank:]]+-v[[:blank:]]+(python[23]?|ipython[23]?|jupyter[a-z-]*|pytest|torchrun|deepspeed|uv|uvx|poetry|conda|pipx|accelerate|pypy[23]?)([[:space:];&|)]|$)#\1 \3#g
')"

# ---------- 7. Blocklist scan ----------
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

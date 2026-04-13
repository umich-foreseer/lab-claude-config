#!/usr/bin/env bash
# shellcheck shell=bash
# claude-in-slurm.sh — wraps the `claude` command to run inside a SLURM
# CPU allocation instead of on the login node.
#
# Compatible with bash and zsh when sourced. Not POSIX sh — relies on
# [[ ]], process substitution, and array features common to both shells.
#
# Behavior when `claude` is invoked:
#   1. Already inside a SLURM allocation ($SLURM_JOB_ID set) → run claude directly.
#   2. On a login node with a running *interactive* allocation owned by you
#      → attach via `srun --overlap --jobid=<id> --pty`. On Great Lakes, GPU
#      jobs are skipped (don't piggyback on training). On Lighthouse, any
#      interactive job is a valid target since the lab only has GPU partitions.
#   3. On a login node with no such allocation → `srun --pty` a fresh one with
#      cluster-specific defaults. `srun` (not `salloc`) is used so Claude
#      actually runs on the compute node — `salloc <cmd>` would run on the
#      login node by default on clusters without `SallocDefaultCommand` set.
#   4. Unknown host (not a login node, not in an alloc) → run claude directly.
#
# Enable by sourcing from your interactive shell's rc file:
#     bash:               . ~/lab-claude-config/shared/shell/claude-in-slurm.sh   # in ~/.bashrc
#     zsh:                . ~/lab-claude-config/shared/shell/claude-in-slurm.sh   # in ~/.zshrc
#     dotfiles with .local override pattern:
#                         . ~/lab-claude-config/shared/shell/claude-in-slurm.sh   # in ~/.zshrc.local
#
# Note: if your ~/.bashrc exec's zsh for interactive shells, appending to
# ~/.bashrc is a dead code path — hook zsh's rc file directly.
#
# Override defaults by exporting before sourcing (or in your rc file):
#     CLAUDE_IN_SLURM_CPUS=8
#     CLAUDE_IN_SLURM_MEM=64G
#     CLAUDE_IN_SLURM_TIME=12:00:00
#     CLAUDE_IN_SLURM_DISABLE=1   # turns the wrapper into a no-op

: "${CLAUDE_IN_SLURM_CPUS:=4}"
: "${CLAUDE_IN_SLURM_MEM:=32G}"
: "${CLAUDE_IN_SLURM_TIME:=8:00:00}"
: "${CLAUDE_IN_SLURM_DISABLE:=0}"

_cis_log() {
    printf '[claude-in-slurm] %s\n' "$*" >&2
}

# Load account/partition defaults that `setup.sh` saved for the lab config.
_cis_load_env() {
    local env_file="${LAB_CLAUDE_CONFIG_DIR:-$HOME/lab-claude-config}/build/.env.local"
    if [[ -f "$env_file" ]]; then
        # shellcheck disable=SC1090
        set -a; . "$env_file"; set +a
    fi
}

_cis_detect_cluster() {
    local h
    h=$(hostname -f 2>/dev/null || hostname)
    case "$h" in
        *gl-login*|*greatlakes.arc-ts*) printf 'greatlakes\n' ;;
        *lh-login*|*lighthouse.arc-ts*) printf 'lighthouse\n' ;;
        *)                              printf 'unknown\n' ;;
    esac
}

# Print the JOBID of a running interactive allocation owned by the current
# user that is a valid target for this cluster. On Great Lakes, GPU jobs
# are skipped so Claude never piggybacks on a running training job. On
# Lighthouse, GPU jobs ARE accepted because that's the only kind of
# allocation the lab has access to there. Exit 1 if none found.
_cis_find_interactive_alloc() {
    local cluster=$1
    command -v squeue >/dev/null 2>&1 || return 1

    local jobid tres batchflag
    while IFS=$'\t' read -r jobid tres; do
        [[ -z "$jobid" ]] && continue
        # On Great Lakes only, skip GPU allocations. TRES_PER_NODE (%b)
        # shows e.g. "gres/gpu:1".
        if [[ "$cluster" == "greatlakes" ]]; then
            [[ "$tres" == *gpu:* || "$tres" == *gres/gpu* ]] && continue
        fi
        # Require interactive (BatchFlag=0 on salloc'ed jobs).
        batchflag=$(scontrol show job "$jobid" -o 2>/dev/null \
            | grep -oE 'BatchFlag=[0-9]+' | cut -d= -f2)
        if [[ "$batchflag" == "0" ]]; then
            printf '%s\n' "$jobid"
            return 0
        fi
    done < <(squeue --me --states=R --noheader --format="%i"$'\t'"%b" 2>/dev/null)
    return 1
}

# Emit the allocation argv (one per line) for the given cluster, suitable
# for passing to either `salloc` or `srun`. Returns 1 if the cluster has
# no auto-launch default configured.
_cis_alloc_args() {
    local cluster=$1
    case "$cluster" in
        greatlakes)
            local account="${GL_ACCOUNT_GENERAL:-qmei0}"
            printf '%s\n' \
                "--account=${account}" \
                "--partition=standard" \
                "--cpus-per-task=${CLAUDE_IN_SLURM_CPUS}" \
                "--mem=${CLAUDE_IN_SLURM_MEM}" \
                "--time=${CLAUDE_IN_SLURM_TIME}" \
                "--job-name=claude-cpu"
            ;;
        lighthouse)
            # Lighthouse is GPU-only for this lab (qmei-a100 is the only
            # accessible partition). We can't auto-launch a CPU box — the
            # caller should attach to an existing alloc or fall back.
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# Build a single shell-safe string from the function's args, so we can pass
# it through `bash -lc "claude <args>"` without losing quoting.
_cis_quote_args() {
    if [[ $# -eq 0 ]]; then
        return 0
    fi
    local out=""
    local a
    for a in "$@"; do
        out+=" $(printf '%q' "$a")"
    done
    printf '%s' "${out# }"
}

claude() {
    # Opt-out escape hatch.
    if [[ "${CLAUDE_IN_SLURM_DISABLE}" == "1" ]]; then
        command claude "$@"
        return
    fi

    # Fast path: already inside an allocation.
    if [[ -n "${SLURM_JOB_ID:-}" ]]; then
        command claude "$@"
        return
    fi

    local cluster
    cluster=$(_cis_detect_cluster)

    if [[ "$cluster" == "unknown" ]]; then
        command claude "$@"
        return
    fi

    _cis_load_env

    # Prefer attaching to an existing interactive allocation.
    local jobid
    if jobid=$(_cis_find_interactive_alloc "$cluster"); then
        _cis_log "attaching to existing interactive allocation $jobid"
        local qargs
        qargs=$(_cis_quote_args "$@")
        srun --overlap --jobid="$jobid" --pty bash -lc "claude ${qargs}"
        return $?
    fi

    # No existing allocation — try to launch a new one.
    local -a alloc_args=()
    local args_out
    if args_out=$(_cis_alloc_args "$cluster"); then
        while IFS= read -r line; do
            [[ -n "$line" ]] && alloc_args+=("$line")
        done <<< "$args_out"
    fi

    if [[ ${#alloc_args[@]} -eq 0 ]]; then
        if [[ "$cluster" == "lighthouse" ]]; then
            _cis_log "Lighthouse has no CPU allocation default in lab config."
            _cis_log "Either salloc a GPU box first, or run claude on the login node (not recommended)."
        else
            _cis_log "no allocation default for cluster '$cluster' — falling back to login node"
        fi
        command claude "$@"
        return
    fi

    # Use `srun --pty` (not `salloc <cmd>`) so the step actually runs on
    # the compute node. salloc-with-command would run the command on the
    # login node unless the site sets SallocDefaultCommand — Great Lakes
    # does not, per `scontrol show config`.
    _cis_log "launching new allocation: srun ${alloc_args[*]} --pty"
    local qargs
    qargs=$(_cis_quote_args "$@")
    srun "${alloc_args[@]}" --pty bash -lc "claude ${qargs}"
}

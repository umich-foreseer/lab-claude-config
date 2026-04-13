#!/usr/bin/env bash
# Test runner for shared/hooks/block-login-python.sh
#
# Mocks `hostname` so the hook believes it is running on a login node, then
# drives JSON inputs through the hook and verifies its exit code matches the
# expected verdict. Each test case maps to either:
#
#   allow  - exit 0 (hook permitted the command)
#   block  - exit 2 (hook denied the command via Claude Code hook contract)
#
# Run from anywhere:
#   bash shared/hooks/tests/test-block-login-python.sh
#
# Requires `jq` (already a hook dependency).

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$HOOK_DIR/block-login-python.sh"

if [[ ! -x "$HOOK" ]]; then
    printf 'ERROR: hook not found or not executable: %s\n' "$HOOK" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'ERROR: jq not found in PATH (required by the hook)\n' >&2
    exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ---------- helpers ----------

# mock_host writes a `hostname` shim that prints the given hostname, regardless
# of args (so `hostname -f` and bare `hostname` both return it).
mock_host() {
    cat >"$TMPDIR/hostname" <<EOF
#!/usr/bin/env bash
printf '%s\n' '$1'
EOF
    chmod +x "$TMPDIR/hostname"
}

PASS=0
FAIL=0
FAILED_CASES=()

# run_case "name" "allow|block" "command" [tool_name]
run_case() {
    local name="$1"
    local expected="$2"
    local cmd="$3"
    local tool="${4:-Bash}"

    local input
    input=$(jq -nc --arg cmd "$cmd" --arg tool "$tool" \
        '{tool_name: $tool, tool_input: {command: $cmd}}')

    local actual_exit=0
    printf '%s' "$input" | "$HOOK" >/dev/null 2>&1 || actual_exit=$?

    local actual
    case $actual_exit in
        0) actual=allow ;;
        2) actual=block ;;
        *) actual="error($actual_exit)" ;;
    esac

    if [[ "$actual" == "$expected" ]]; then
        printf '  PASS  %s\n' "$name"
        PASS=$((PASS + 1))
    else
        printf '  FAIL  %s  (expected=%s actual=%s)\n' "$name" "$expected" "$actual"
        FAIL=$((FAIL + 1))
        FAILED_CASES+=("$name")
    fi
}

# ---------- environment setup ----------

export PATH="$TMPDIR:$PATH"
unset SLURM_JOB_ID SLURM_JOBID SLURM_NODELIST SLURM_NODEID

# ---------- tests ----------

mock_host gl-login1.arc-ts.umich.edu

echo "=== allow: srun/sbatch/salloc dispatch on login node ==="
run_case "srun python3 foo.py"               allow 'srun python3 foo.py'
run_case "srun --pty bash"                   allow 'srun --pty bash'
run_case "cd && srun python3"                allow 'cd ~/proj && srun python3 foo.py'
run_case 'srun bash -c "python3 foo"'        allow 'srun bash -c "python3 foo"'
run_case "FOO=bar srun python3"              allow 'FOO=bar srun python3 foo.py'
run_case "sbatch run.sh"                     allow 'sbatch run.sh'
run_case "salloc --gres=gpu:1"               allow 'salloc --gres=gpu:1'
run_case "srun --gres ... python train.py"   allow 'srun --gres=gpu:1 --mem=60G python train.py'
run_case "srun python a.py | grep done"      allow 'srun python a.py | grep done'
run_case "srun (alone)"                      allow 'srun'

echo ""
echo "=== allow: inspection commands (regression coverage) ==="
run_case "pip install torch"                 allow 'pip install torch'
run_case "pip install torchrun"              allow 'pip install torchrun'
run_case "python -V"                         allow 'python -V'
run_case "python3 --version"                 allow 'python3 --version'
run_case "which python"                      allow 'which python'
run_case "type python3"                      allow 'type python3'
run_case "uv sync"                           allow 'uv sync'
run_case "conda info"                        allow 'conda info'
run_case "pipx install ruff"                 allow 'pipx install ruff'
run_case "python -m pip install foo"         allow 'python -m pip install foo'
run_case "python -m venv .venv"              allow 'python -m venv .venv'
run_case "command -v python"                 allow 'command -v python'

echo ""
echo "=== block: python on login node ==="
run_case "bare python3 foo.py"               block 'python3 foo.py'
run_case "bare pytest"                       block 'pytest tests/'
run_case "torchrun"                          block 'torchrun --nproc-per-node 4 train.py'
run_case "python piped to tee"               block 'python train.py | tee log.txt'
run_case "srun foo.sh && python3 bar.py"    block 'srun foo.sh && python3 bar.py'
run_case "python; srun python"               block 'python3 foo; srun python3 bar'
run_case "srun;python (no space)"            block 'srun;python foo'
run_case "pip install && python train"       block 'pip install torch && python3 train.py'
run_case "ipython3"                          block 'ipython3'
run_case "uv run python script"              block 'uv run python script.py'
run_case "jupyter notebook"                  block 'jupyter notebook'

echo ""
echo "=== regression: -zE strip must not eat across newlines ==="
# Two distinct -zE failure modes the strip patterns must defend against:
#
# (a) Tail eats a sibling statement: e.g. `pip install foo\npython train.py`
#     with `[^;&|]*` would let the pip tail span the newline and silently
#     allow the python. The `\n` in the negation set fixes this — but only
#     when the strip's END delim itself doesn't consume the newline.
#
# (b) END delim eats the newline: e.g. `uv sync\npytest tests/`. Here the
#     END delim `[[:space:];&|)]` matches `\n`, the tail then starts on the
#     next line and eats `pytest tests/`. Excluding `\n` from END_CO (using
#     `[[:blank:];&|)]|$`) makes the strip fail and the blocklist scans the
#     unmodified next line.
multi_pip=$'pip install foo\npython3 train.py'
run_case "multiline: pip install X\\npython" block "$multi_pip"
multi_pip_bare=$'pip install\npython3 train.py'
run_case "multiline: pip install\\npython"   block "$multi_pip_bare"
multi_uv=$'uv sync\npytest tests/'
run_case "multiline: uv sync\\npytest"       block "$multi_uv"
multi_conda=$'conda info\npython3 train.py'
run_case "multiline: conda info\\npython"    block "$multi_conda"
multi_pipx=$'pipx list\ntorchrun train.py'
run_case "multiline: pipx list\\ntorchrun"   block "$multi_pipx"
multi_srun=$'srun foo.sh\npython3 train.py'
run_case "multiline: srun X\\npython"        block "$multi_srun"
multi_srun_bare=$'srun\npython3 train.py'
run_case "multiline: srun\\npython"          block "$multi_srun_bare"
multi_grep=$'grep foo log.txt\npython3 train.py'
run_case "multiline: grep\\npython"          block "$multi_grep"
multi_which=$'which python\nipython3'
run_case "multiline: which python\\nipython" block "$multi_which"
# Also: KEYSEP must not span newlines (uses [[:blank:]] not [[:space:]])
multi_keysep=$'pip\ninstall foo\npython3 train.py'
run_case "multiline: pip\\ninstall\\npython" block "$multi_keysep"

echo ""
echo "=== allow: Slurm heredocs and continued dispatch ==="
heredoc_single=$'srun bash <<\'EOF\'\npython3 foo.py\nEOF'
run_case "heredoc: single-quoted tag"        allow "$heredoc_single"
heredoc_unquoted=$'srun bash <<EOF\npython3 foo.py\nEOF'
run_case "heredoc: unquoted tag"             allow "$heredoc_unquoted"
heredoc_double=$'srun bash <<\"EOF\"\npython3 foo.py\nEOF'
run_case "heredoc: double-quoted tag"        allow "$heredoc_double"
heredoc_indented=$'srun bash <<-EOF\n\tpython3 foo.py\n\tEOF'
run_case "heredoc: indented close with <<-"  allow "$heredoc_indented"
heredoc_body_python=$'srun bash <<EOF\ncmd1\ncmd2 && python bar\nEOF'
run_case "heredoc: python stays in body"     allow "$heredoc_body_python"
linecont_srun=$'srun \\\npython3 foo.py'
run_case "line continuation: srun dispatch"  allow "$linecont_srun"
stacked_heredocs=$'srun bash <<A\nline\nA\nsrun bash <<B\nline\nB'
run_case "heredoc: stacked dispatches"       allow "$stacked_heredocs"
tag_substring=$'srun bash <<EOF\nsay EOF here\nEOF'
run_case "heredoc: tag as body substring"    allow "$tag_substring"

echo ""
echo "=== block: python after closed Slurm heredoc or without dispatch ==="
post_heredoc_newline=$'srun bash <<EOF\npython foo\nEOF\npython bar.py'
run_case "heredoc: trailing newline python"  block "$post_heredoc_newline"
post_heredoc_and=$'srun bash <<EOF\necho done\nEOF && python bar.py'
run_case "heredoc: trailing && python"       block "$post_heredoc_and"
linecont_python=$'python \\\ntrain.py'
run_case "line continuation: bare python"    block "$linecont_python"

echo ""
echo "=== bypass: SLURM_JOB_ID set ==="
SLURM_JOB_ID=12345 run_case "python with SLURM_JOB_ID"   allow 'python3 train.py'
SLURM_JOB_ID=12345 run_case "torchrun with SLURM_JOB_ID" allow 'torchrun --nproc 8 train.py'

echo ""
echo "=== bypass: non-Bash tool ==="
run_case "Read tool python"                  allow 'python3 train.py' Read
run_case "Edit tool pytest"                  allow 'pytest'           Edit

echo ""
echo "=== bypass: non-login hostname ==="
mock_host gl3050.arc-ts.umich.edu
run_case "compute node python"               allow 'python3 train.py'
run_case "compute node pytest"               allow 'pytest tests/'
mock_host gl-login1.arc-ts.umich.edu

echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -gt 0 ]]; then
    printf '\nFailed cases:\n'
    for c in "${FAILED_CASES[@]}"; do
        printf '  - %s\n' "$c"
    done
    exit 1
fi

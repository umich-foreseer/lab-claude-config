# Shell helpers

Optional shell snippets for the lab Claude Code setup. Opt-in — source them from your shell rc file. Nothing here is installed automatically by `setup.sh`.

## `claude-in-slurm.sh` — auto-route `claude` into a SLURM allocation

Running Claude Code on a login node is against compute discipline. Sourcing this file defines a `claude` shell function that:

1. If you're already inside a SLURM allocation → runs `claude` directly.
2. Otherwise, looks for a running **interactive** allocation you own and attaches via `srun --overlap --jobid=<id> --pty`. On Great Lakes, GPU jobs are skipped so `claude` never piggybacks on a training job. On Lighthouse, GPU jobs are accepted since the lab only has GPU partitions there.
3. If none exists (Great Lakes only), runs `srun --pty` with a sensible CPU default (`qmei0` / `standard`, 4 CPU / 32G / 8h) to allocate a fresh compute node and launch `claude` on it. `srun` blocks until the allocation is granted, so the prompt "waits" automatically.
4. On Lighthouse (GPU-only for this lab), auto-launch is disabled — if you don't already have an allocation, it falls back to the login node with a warning.

The script is **polyglot** — it works when sourced by either bash or zsh.

### Enable

| Your shell setup | Hook file | Command |
|---|---|---|
| Pure bash | `~/.bashrc` | `echo '. ~/lab-claude-config/shared/shell/claude-in-slurm.sh' >> ~/.bashrc` |
| Pure zsh | `~/.zshrc` | `echo '. ~/lab-claude-config/shared/shell/claude-in-slurm.sh' >> ~/.zshrc` |
| Dotfiles with a `.local` override pattern (recommended if available) | `~/.zshrc.local` | Add the source line to `~/.zshrc.local` so it stays out of your tracked dotfiles |
| Bash that `exec`s zsh for interactive shells | `~/.zshrc` (not `~/.bashrc`) | Appending to `~/.bashrc` won't work — the exec to zsh happens first. Hook zsh directly. |

Open a new shell and run `claude` normally. The function is a no-op on compute nodes and unknown hosts, so sourcing it unconditionally is safe.

### Override defaults

Export before sourcing, or directly in your rc file:

```bash
export CLAUDE_IN_SLURM_CPUS=8
export CLAUDE_IN_SLURM_MEM=64G
export CLAUDE_IN_SLURM_TIME=12:00:00
export CLAUDE_IN_SLURM_DISABLE=1   # turn off entirely
```

### Notes

- "Interactive" means allocations with `BatchFlag=0` (i.e., `salloc`- or `srun --pty`-style). Batch `sbatch` jobs are intentionally skipped so the wrapper never piggybacks on a running training job.
- On Great Lakes, GPU jobs are skipped when searching for existing allocations. On Lighthouse, GPU jobs are accepted since the lab only has access to GPU partitions (`qmei-a100`) there.
- The Great Lakes default uses `GL_ACCOUNT_GENERAL` from `build/.env.local` (populated by `setup.sh` during `/onboard`), falling back to `qmei0` if unset.
- Lighthouse CPU defaults aren't configured because this lab only has access to the `qmei-a100` GPU partition there. If that changes, extend `_cis_alloc_args` in the script.

### Why `srun --pty`, not `salloc <cmd>`

Great Lakes does not set `SallocDefaultCommand` (confirmed via `scontrol show config`), so `salloc <args> bash -lc "claude"` reserves a compute node but runs `bash` on the **login node** with `SLURM_JOB_ID` exported — the wrapper's own fast path then runs `claude` on the login node while the allocation sits idle. We use `srun --pty` instead, which creates both the allocation and the compute-node job step in one call.

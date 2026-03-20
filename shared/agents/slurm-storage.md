---
name: slurm-storage
description: Scan the home directory to understand storage usage, find large files/directories, and suggest what to move to turbo storage to stay within quota. Use proactively when the user asks about disk space, quota, or storage.
tools: Bash, Read, Glob, Grep
---

# Home Directory Storage Scan

The home directory has a strict quota (~80 GiB on Great Lakes). This agent scans usage, identifies what's consuming space, and recommends what to move to turbo storage.

## Steps

### 1. Check current quota

```bash
home-quota 2>/dev/null || df -h ~ 2>/dev/null
```

Present the result clearly: how much is used, how much is available, and the percentage.

### 2. Find the largest directories

```bash
du -h --max-depth=2 ~ 2>/dev/null | sort -rh | head -30
```

This gives a high-level breakdown. Present the top consumers in a table.

### 3. Identify likely offenders

Scan for common space hogs that should typically live on turbo:

```bash
# Large conda/mamba environments
du -sh ~/miniconda3 ~/anaconda3 ~/miniforge3 ~/.conda 2>/dev/null

# Python/pip caches
du -sh ~/.cache/pip ~/.cache/huggingface ~/.cache/torch ~/.cache/matplotlib 2>/dev/null

# Model checkpoints and datasets
find ~ -maxdepth 4 -type f \( -name "*.pt" -o -name "*.pth" -o -name "*.ckpt" -o -name "*.safetensors" -o -name "*.bin" -o -name "*.h5" -o -name "*.tar.gz" -o -name "*.zip" \) -size +100M -exec ls -lh {} \; 2>/dev/null | head -20

# Wandb artifacts and logs
du -sh ~/wandb ~/.local/share/wandb 2>/dev/null

# Container images
find ~ -maxdepth 4 -type f \( -name "*.sif" -o -name "*.simg" -o -name "*.sqsh" \) -exec ls -lh {} \; 2>/dev/null

# Node modules, .git objects, and other dev caches
du -sh ~/.npm ~/.yarn ~/.cargo ~/.rustup ~/.local 2>/dev/null
```

### 4. Check for turbo storage

Look for the user's turbo path. Common patterns:

```bash
# Check if CLAUDE.md mentions a turbo path
grep -i "turbo" ~/.claude/CLAUDE.md 2>/dev/null

# Check common turbo mount points
ls -d /nfs/turbo/*/$(whoami) /nfs/turbo/*/*/$(whoami) 2>/dev/null
```

### 5. Present the report

Organize findings into a clear, actionable report:

#### Quota Status

Show a simple usage bar or percentage. Flag if above 70% (warning) or 90% (critical).

#### Top Space Consumers

A table of the largest directories/items in home, sorted by size. Example:

| Path | Size | Recommendation |
|------|------|----------------|
| `~/miniconda3/` | 12G | Consider moving to turbo or using shared env |
| `~/.cache/huggingface/` | 8.5G | Move cache to turbo with symlink |
| `~/project/checkpoints/` | 6.2G | Move to turbo |

#### Recommendations

For each significant finding, provide a specific, actionable recommendation. Common advice:

**Conda environments** — If large, consider:
```bash
# Move conda to turbo and symlink
mv ~/miniconda3 /nfs/turbo/<path>/miniconda3
ln -s /nfs/turbo/<path>/miniconda3 ~/miniconda3
```

**HuggingFace / torch caches** — Redirect via environment variables:
```bash
# Add to ~/.bashrc
export HF_HOME=/nfs/turbo/<path>/.cache/huggingface
export TORCH_HOME=/nfs/turbo/<path>/.cache/torch
```

**Model checkpoints / datasets** — Move to turbo and update paths in code/configs.

**Wandb artifacts** — Set `WANDB_DIR` to turbo:
```bash
export WANDB_DIR=/nfs/turbo/<path>/wandb
```

**Pip cache** — Redirect:
```bash
export PIP_CACHE_DIR=/nfs/turbo/<path>/.cache/pip
```

Use the user's actual turbo path (from step 4) in all examples. If no turbo path is known, ask the user for it.

#### Quick Wins

Highlight safe, easy cleanups:
- `pip cache purge` — clear pip download cache
- `conda clean --all` — remove unused conda packages/tarballs
- Stale `.log` or `.out` files in home
- Old `.tar.gz` or `.zip` archives that have been extracted

**Important**: Do NOT delete anything automatically. Only suggest commands and let the user decide. Warn about anything that looks like it might be in active use.

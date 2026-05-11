#!/usr/bin/env python3
"""Lightweight discovery for the experimental migrate skill."""

import os
import re
import shutil
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import List, Optional, Tuple


TIMEOUT = 8
STORAGE_ROOTS = [
    "/nfs/turbo",
    "/scratch",
    "/gpfs",
    "/lustre",
    "/oak",
    "/nobackup",
    "/work",
    "/project",
    "/projects",
]
TEXT_EXTENSIONS = {
    ".bash",
    ".cfg",
    ".conf",
    ".env",
    ".ini",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".slurm",
    ".sbatch",
    ".toml",
    ".txt",
    ".yaml",
    ".yml",
}
INTERESTING_NAMES = {
    "AGENTS.md",
    "CLAUDE.md",
    "README.md",
    "environment.yml",
    "environment.yaml",
    "pyproject.toml",
    "requirements.txt",
    "setup.py",
}
SEARCH_TERMS = [
    "#SBATCH",
    "srun",
    "sbatch",
    "salloc",
    "partition",
    "--account",
    "--gres",
    "CUDA",
    "module load",
    "conda activate",
]
SEARCH_TERMS.extend(STORAGE_ROOTS)

# Common HPC storage roots. Sites with custom layouts can pass extra paths as
# CLI args after the repo root; existing_ancestor() filters non-existent paths.
STORAGE_PATH_PATTERN = re.compile(
    r"(?:"
    + "|".join(re.escape(root) for root in STORAGE_ROOTS)
    + r")(?:/[A-Za-z0-9._${}-]+)*"
)


def run(command: List[str], cwd: Optional[Path] = None) -> str:
    if shutil.which(command[0]) is None:
        return "(command not found)"
    try:
        result = subprocess.run(
            command,
            cwd=str(cwd) if cwd else None,
            universal_newlines=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=TIMEOUT,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return "(timed out)"
    output = result.stdout.strip()
    if not output and result.stderr:
        output = result.stderr.strip()
    return output if output else "(no output)"


def first_lines(text: str, limit: int = 30) -> List[str]:
    lines = [line.rstrip() for line in text.splitlines() if line.strip()]
    if len(lines) > limit:
        return lines[:limit] + [f"... ({len(lines) - limit} more lines)"]
    return lines


def is_text_candidate(path: Path) -> bool:
    return path.name in INTERESTING_NAMES or path.suffix in TEXT_EXTENSIONS


def iter_repo_files(root: Path) -> List[Path]:
    ignored_dirs = {
        ".claude",
        ".codex",
        ".git",
        ".mypy_cache",
        ".pytest_cache",
        "__pycache__",
        "build",
        "node_modules",
    }
    files = []  # type: List[Path]
    for current_root, dirs, filenames in os.walk(root):
        dirs[:] = [d for d in dirs if d not in ignored_dirs and not d.startswith(".ruff_cache")]
        current = Path(current_root)
        for filename in filenames:
            path = current / filename
            try:
                if path.stat().st_size > 1_000_000:
                    continue
            except OSError:
                continue
            files.append(path)
    return files


def existing_ancestor(raw_path: str) -> Optional[str]:
    cleaned = raw_path.split("${", 1)[0].rstrip("/.,;:)'\"")
    if not cleaned:
        return None
    path = Path(cleaned)
    while str(path) not in {"", "/"}:
        if path.exists():
            return str(path)
        path = path.parent
    return None


def scan_repo(root: Path) -> Tuple[Counter, List[str], List[str], List[str]]:
    files = iter_repo_files(root)
    extensions = Counter(path.suffix or "(none)" for path in files)
    interesting_files = []  # type: List[str]
    matches = []  # type: List[str]
    storage_paths = []  # type: List[str]

    for path in files:
        rel = path.relative_to(root).as_posix()
        if (
            path.name in INTERESTING_NAMES
            or path.suffix in {".sh", ".slurm", ".sbatch", ".yml", ".yaml", ".toml"}
            or any(part in {"docs", "scripts", "jobs", "slurm", "configs"} for part in path.parts)
        ):
            interesting_files.append(rel)

        if not is_text_candidate(path):
            continue
        try:
            text = path.read_text(errors="ignore")
        except OSError:
            continue
        for raw_path in STORAGE_PATH_PATTERN.findall(text):
            storage_path = existing_ancestor(raw_path)
            if storage_path:
                storage_paths.append(storage_path)
        matches_in_file = 0
        for line_number, line in enumerate(text.splitlines(), start=1):
            lower_line = line.lower()
            if any(term.lower() in lower_line for term in SEARCH_TERMS):
                compact = " ".join(line.strip().split())
                matches.append(f"{rel}:{line_number}: {compact[:220]}")
                matches_in_file += 1
                # Keep output readable while still showing more than the first directive.
                if matches_in_file >= 3:
                    break

    return extensions, sorted(interesting_files), matches, sorted(set(storage_paths))


def discover_storage_targets(root: Path, repo_storage_paths: List[str], extra_targets: List[str]) -> List[str]:
    candidates = [str(Path.home())]
    candidates.extend(extra_targets)
    candidates.extend(repo_storage_paths)
    candidates.extend(STORAGE_ROOTS)

    targets = []  # type: List[str]
    seen = set()
    for candidate in candidates:
        if not candidate:
            continue
        existing = existing_ancestor(candidate)
        if existing and existing not in seen:
            targets.append(existing)
            seen.add(existing)
    return targets


def print_section(title: str, lines: List[str]) -> None:
    print(f"\n## {title}")
    if not lines:
        print("- (none found)")
        return
    for line in lines:
        print(f"- {line}")


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    extra_storage_targets = sys.argv[2:]
    if not root.exists():
        print(f"Repository path does not exist: {root}", file=sys.stderr)
        return 2

    print("# Compute Migration Discovery")
    print(f"\nRepository: `{root}`")

    extensions, interesting_files, matches, repo_storage_paths = scan_repo(root)

    whoami_lines = first_lines(run(["whoami"]), 1)
    detected_user = os.environ.get("USER") or (whoami_lines[0] if whoami_lines else "")
    if not detected_user or detected_user.startswith("("):
        detected_user = "unknown"

    print_section(
        "Machine",
        [
            f"hostname: {run(['hostname', '-f'])}",
            f"short hostname: {run(['hostname'])}",
            f"user: {detected_user}",
            f"SLURM_JOB_ID: {os.environ.get('SLURM_JOB_ID', '(unset)')}",
            f"CONDA_DEFAULT_ENV: {os.environ.get('CONDA_DEFAULT_ENV', '(unset)')}",
            f"VIRTUAL_ENV: {os.environ.get('VIRTUAL_ENV', '(unset)')}",
        ],
    )

    print_section("Git", first_lines(run(["git", "remote", "-v"], root), 20))
    print_section("Git status", first_lines(run(["git", "status", "--short", "--branch"], root), 40))

    print_section(
        "Slurm associations",
        first_lines(
            run(
                [
                    "sacctmgr",
                    "show",
                    "association",
                    f"user={detected_user}",
                    "format=account%24,partition%30,qos%30",
                    "--noheader",
                ]
            ),
            40,
        ),
    )
    print_section("Slurm partitions", first_lines(run(["sinfo", "-h", "-o", "%P|%G|%D|%m|%l|%a"]), 60))
    print_section("User queue", first_lines(run(["squeue", "-u", detected_user, "-o", "%.18i %.9P %.40j %.8u %.2t %.10M %.6D %R"]), 25))

    storage_targets = discover_storage_targets(root, repo_storage_paths, extra_storage_targets)
    storage_lines = first_lines(run(["df", "-h", *storage_targets]), 20) if storage_targets else ["(no known storage paths)"]
    print_section("Storage", storage_lines)

    common_ext = [f"{ext}: {count}" for ext, count in extensions.most_common(12)]
    print_section("Repo file types", common_ext)
    print_section("Migration-sensitive files", interesting_files[:80] + (["..."] if len(interesting_files) > 80 else []))
    print_section("Potential compute assumptions", matches[:80] + (["..."] if len(matches) > 80 else []))

    print(
        "\n## Next step\n"
        "Review these findings with the user and ask them to correct the target lab, scheduler, "
        "account/partition, storage, scratch, and environment assumptions before editing files."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

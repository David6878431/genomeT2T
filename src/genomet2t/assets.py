"""Locate the same workflow sources in editable installs and installed wheels."""
from pathlib import Path


def workflow_directory() -> Path:
    root = Path(__file__).resolve().parents[2]
    if (root / "pyproject.toml").is_file() and (root / "env.sh").is_file():
        return root
    bundled = Path(__file__).resolve().parent / "workflows"
    if not (bundled / "env.sh").is_file():
        raise FileNotFoundError("Bundled workflows are missing; reinstall the wheel.")
    return bundled

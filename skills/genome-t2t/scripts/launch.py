#!/usr/bin/env python3
"""Run the genomeT2T CLI bundled with this skill, without a pip installation."""
from pathlib import Path, PurePosixPath
import stat
import sys
import tempfile
from zipfile import BadZipFile, ZipFile


def extract_wheel(wheel: Path, target: Path) -> None:
    with ZipFile(wheel) as archive:
        for member in archive.infolist():
            path = PurePosixPath(member.filename)
            if (path.is_absolute() or ".." in path.parts
                    or "\\" in member.filename or ":" in member.filename
                    or stat.S_ISLNK(member.external_attr >> 16)):
                raise ValueError(f"Unsupported path in bundled wheel: {member.filename}")
            destination = target.joinpath(*path.parts)
            destination.resolve().relative_to(target.resolve())
        archive.extractall(target)


def launch(argv: list[str] | None = None) -> int:
    if sys.version_info < (3, 11):
        print("ERROR: genomeT2T requires Python 3.11 or newer.", file=sys.stderr)
        return 2
    skill = Path(__file__).resolve().parents[1]
    wheels = sorted((skill / "assets").glob("genomet2t-*.whl"))
    if len(wheels) != 1:
        print("ERROR: The skill must contain exactly one genomeT2T wheel in assets/.",
              file=sys.stderr)
        return 2
    try:
        with tempfile.TemporaryDirectory(prefix="genomet2t-skill-") as temporary:
            extract_wheel(wheels[0], Path(temporary))
            sys.path.insert(0, temporary)
            try:
                from genomet2t.cli import main
                return main(sys.argv[1:] if argv is None else argv)
            finally:
                sys.path.remove(temporary)
    except (OSError, BadZipFile, ValueError) as error:
        print(f"ERROR: Cannot load the bundled genomeT2T package: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(launch())

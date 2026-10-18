import argparse
import json
from pathlib import Path
import sys

from . import __version__
from .config import ConfigError, example_toml, load_config
from .runner import StageFailure, preview, run_stages
from .stages import STAGES, get_stage


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        prog="genomet2t", description="Run selected genome assembly and annotation stages.")
    root.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = root.add_subparsers(dest="command", required=True)
    init = sub.add_parser("init", help="Write a TOML configuration template.")
    init.add_argument("path", nargs="?", default="genomeT2T.toml")
    sub.add_parser("stages", help="List supported workflow stages.")
    validate = sub.add_parser("validate", help="Check config and selected stage parameters.")
    validate.add_argument("--config", "-c", default="genomeT2T.toml")
    validate.add_argument("--stage", action="append", default=[])
    validate.add_argument("--executor", choices=("docker", "local"), default="docker")
    validate.add_argument("--check-files", action="store_true",
                          help="Check host directories (Docker) or selected input files (local).")
    run = sub.add_parser("run", help="Run explicitly selected stages in the given order.")
    run.add_argument("stages", nargs="+", help="Names from 'genomet2t stages'.")
    run.add_argument("--config", "-c", default="genomeT2T.toml")
    run.add_argument("--executor", choices=("docker", "local"), default="docker")
    run.add_argument("--bash", default="bash", help="Bash executable for local execution.")
    run.add_argument("--log-dir", help="Parent directory for execution logs.")
    run.add_argument("--dry-run", action="store_true", help="Print argv only; no analysis or Docker calls.")
    return root


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "init":
            target = Path(args.path).expanduser().resolve()
            content = example_toml()
            target.parent.mkdir(parents=True, exist_ok=True)
            # Exclusive creation protects an existing sample configuration.
            with target.open("x", encoding="utf-8", newline="\n") as output:
                output.write(content)
            print(f"Created {target}; replace sample parameters before running.")
        elif args.command == "stages":
            for stage in STAGES:
                print(f"{stage.name:15} {stage.image:10} {stage.description}")
        elif args.command == "validate":
            config = load_config(args.config)
            config.validate([get_stage(name) for name in args.stage],
                            args.executor, args.check_files)
            print("Configuration valid for the selected checks.")
            if not args.stage:
                print("No stage selected: biological placeholders for unused stages were not checked.")
            print("This does not verify software versions, databases, or biological results.")
        else:
            config = load_config(args.config)
            stages = [get_stage(name) for name in args.stages]
            names = [stage.name for stage in stages]
            if len(set(names)) != len(names):
                raise ConfigError("Do not repeat a stage in one invocation.")
            if "hic-prepare" in names and "hic-finalize" in names:
                raise ConfigError("Separate Hi-C prepare/finalize invocations are required for manual review.")
            if args.dry_run:
                print(json.dumps(preview(config, stages, args.executor, args.bash),
                                 indent=2, ensure_ascii=False))
                print("Dry run only; <generated-config.sh> is a placeholder.", file=sys.stderr)
            else:
                logs = run_stages(config, stages, args.executor, args.bash, args.log_dir)
                print(f"Finished. Run report: {logs / 'run.json'}")
        return 0
    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        return 130
    except StageFailure as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return error.returncode if 0 < error.returncode < 126 else 1
    except (ConfigError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())

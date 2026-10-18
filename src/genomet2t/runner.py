"""Execute selected workflow stages with an argv list, logs, and exit status."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import uuid

from .assets import workflow_directory
from .config import ConfigError, PipelineConfig
from .stages import Stage


class StageFailure(RuntimeError):
    def __init__(self, stage: str, returncode: int, log: Path):
        self.returncode = returncode
        super().__init__(f"{stage} exited with status {returncode}; see {log}")


def build_command(config: PipelineConfig, stage: Stage, executor: str, shell_config: str,
                  assets: Path, bash: str = "bash", container_name: str = "") -> list[str]:
    if executor == "local":
        return [bash, (assets / stage.script).as_posix(), *stage.args]
    command = ["docker", "run", "--rm", "--init"]
    if container_name:
        command += ["--name", container_name]
    bindings = [(assets, "/opt/genomet2t", True),
                (Path(shell_config), "/opt/genomet2t-config.sh", True)]
    bindings += [(host, target, False) for host, target in config.host_mounts()]
    for host, target, readonly in bindings:
        source = host.as_posix()
        # Docker's --mount values use a comma-separated grammar.
        if any(c in source + target for c in (",", "\n", "\r", '"')):
            raise ConfigError(f"Docker bind path has unsupported punctuation: {source} -> {target}")
        spec = f"type=bind,src={source},dst={target}"
        if readonly:
            spec += ",readonly"
        command += ["--mount", spec]
    image = config.docker.get(
        f"{stage.image}_image",
        "omicsclass/genome-t2t:v1.0" if stage.image == "assembly"
        else "omicsclass/genome-annotation:v1.0",
    )
    if not image or image.startswith("-") or any(c.isspace() for c in image):
        raise ConfigError("Docker image must be a nonempty image reference.")
    command += ["--env", "GENOMET2T_CONFIG=/opt/genomet2t-config.sh",
                "--workdir", "/opt/genomet2t", image,
                "/bin/bash", f"/opt/genomet2t/{stage.script}", *stage.args]
    return command


def preview(config: PipelineConfig, stages: list[Stage], executor: str, bash: str = "bash") -> list[dict]:
    config.validate(stages, executor, check_files=False)
    # This is an explicitly labelled placeholder, not an executable temp path.
    return [{"stage": stage.name, "executor": executor,
             "argv": build_command(config, stage, executor, "<generated-config.sh>",
                                   workflow_directory(), bash)}
            for stage in stages]


def _stream(command: list[str], env: dict, cwd: Path, log: Path) -> int:
    with log.open("w", encoding="utf-8") as output:
        with subprocess.Popen(command, env=env, cwd=cwd, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                              errors="replace", start_new_session=os.name != "nt") as process:
            try:
                assert process.stdout is not None
                for line in process.stdout:
                    output.write(line)
                    output.flush()
                    sys.stdout.write(line)
                    sys.stdout.flush()
                return process.wait()
            except BaseException:
                if process.poll() is None:
                    if os.name == "nt":
                        process.terminate()
                    else:
                        os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                raise


def run_stages(config: PipelineConfig, stages: list[Stage], executor: str = "docker",
               bash: str = "bash", log_dir: str | Path | None = None) -> Path:
    if executor not in {"local", "docker"}:
        raise ConfigError(f"Unknown executor: {executor}")
    names = [s.name for s in stages]
    if len(names) != len(set(names)):
        raise ConfigError("Do not repeat a stage in one invocation.")
    if "hic-prepare" in names and "hic-finalize" in names:
        raise ConfigError("Run hic-prepare and hic-finalize separately, with manual Juicebox review between them.")
    if not stages:
        raise ConfigError("Select at least one stage.")
    config.validate(stages, executor)
    executable = bash if executor == "local" else "docker"
    if shutil.which(executable) is None:
        raise ConfigError(f"{executable!r} is not available; install it or choose another executor.")
    # Validate host mounts before any analysis process starts.
    if executor == "docker":
        config.validate([], executor, check_files=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    identifier = f"{stamp}-{uuid.uuid4().hex[:8]}"
    logs = (Path(log_dir).expanduser().resolve() if log_dir else
            config.path.parent / ".genomet2t" / "runs") / identifier
    logs.mkdir(parents=True, exist_ok=False)
    metadata = {"config": str(config.path), "executor": executor,
                "status": "running", "stages": []}
    report = logs / "run.json"

    def save_report():
        report.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    save_report()
    try:
        with tempfile.TemporaryDirectory(prefix="genomet2t-") as temporary:
            shell_config = Path(temporary) / "config.sh"
            shell_config.write_text(config.shell_text(executor), encoding="utf-8", newline="\n")
            for index, stage in enumerate(stages, 1):
                # Recheck per-stage files only just before running, as previous
                # stages may be responsible for producing their input files.
                config.validate([stage], executor, check_files=True)
                container_name = f"genomet2t-{uuid.uuid4().hex[:12]}" if executor == "docker" else ""
                command = build_command(config, stage, executor, str(shell_config),
                                        workflow_directory(), bash, container_name)
                log = logs / f"{index:02d}-{stage.name}.log"
                entry = {"stage": stage.name, "status": "running", "log": str(log)}
                metadata["stages"].append(entry)
                save_report()
                print(f"[{stage.name}] log: {log}", flush=True)
                env = os.environ.copy()
                env["GENOMET2T_CONFIG"] = shell_config.as_posix()
                try:
                    code = _stream(command, env, config.path.parent, log)
                except BaseException as error:
                    entry["status"] = "interrupted" if isinstance(error, KeyboardInterrupt) else "failed"
                    if container_name:
                        try:
                            subprocess.run(["docker", "rm", "-f", container_name],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                           timeout=30, check=False)
                        except (OSError, subprocess.TimeoutExpired):
                            pass  # Preserve the original interruption/failure.
                    raise
                entry["returncode"] = code
                entry["status"] = "complete" if code == 0 else "failed"
                save_report()
                if code:
                    raise StageFailure(stage.name, code, log)
        metadata["status"] = "complete"
    except BaseException as error:
        metadata["status"] = "interrupted" if isinstance(error, KeyboardInterrupt) else "failed"
        metadata["error"] = str(error)
        raise
    finally:
        save_report()
    return logs

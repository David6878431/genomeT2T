"""Bundle the canonical root workflow scripts in wheels, without duplicate sources."""
from pathlib import Path

from setuptools import setup
from setuptools.command.build_py import build_py


class BuildPy(build_py):
    def run(self):
        super().run()
        target = Path(self.build_lib) / "genomet2t" / "workflows"
        target.mkdir(parents=True, exist_ok=True)
        root = Path(__file__).resolve().parent
        for source in sorted(root.glob("*.sh")):
            if source.name in {"env.sh", "config.example.sh"} or source.name[:2].isdigit():
                self.copy_file(str(source), str(target / source.name))


setup(cmdclass={"build_py": BuildPy})

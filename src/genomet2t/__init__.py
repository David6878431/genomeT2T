"""Genome assembly workflow configuration and execution."""

__version__ = "0.1.0"

from .config import ConfigError, PipelineConfig, load_config
from .stages import STAGES, Stage, get_stage

__all__ = ["__version__", "ConfigError", "PipelineConfig", "load_config",
           "STAGES", "Stage", "get_stage"]

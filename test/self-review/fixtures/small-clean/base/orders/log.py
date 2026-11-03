"""Minimal logger shim so library code never prints."""
import sys


def info(msg: str) -> None:
    """Write an info line to stderr."""
    sys.stderr.write(f"INFO {msg}\n")


def warn(msg: str) -> None:
    """Write a warning line to stderr."""
    sys.stderr.write(f"WARN {msg}\n")

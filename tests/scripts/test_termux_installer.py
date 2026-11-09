import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "scripts/install-termux.sh"


def shell_interpreter() -> str:
    shell = shutil.which("sh")
    if shell is None:
        pytest.skip("sh is not available on this platform")
    return shell


def test_termux_requirements_match_uv_lock() -> None:
    uv = shutil.which("uv")
    assert uv is not None, "uv is required to verify the committed dependency lock"
    result = subprocess.run(
        [
            uv,
            "export",
            "--locked",
            "--no-dev",
            "--no-emit-project",
            "--no-header",
            "--no-annotate",
            "--format",
            "requirements.txt",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    assert result.stdout == (ROOT / "requirements-termux.lock").read_text(
        encoding="utf-8"
    )


def test_termux_installer_dry_run_is_safe_on_non_termux_hosts() -> None:
    result = subprocess.run(
        [shell_interpreter(), str(INSTALLER), "--dry-run"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    assert "pkg install -y python nodejs-lts" in result.stdout
    assert "requirements-termux.lock" in result.stdout
    assert "verify fcc-server --version and claude --version" in result.stdout

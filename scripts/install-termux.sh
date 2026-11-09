#!/data/data/com.termux/files/usr/bin/sh
set -eu

FCC_VENV_NAME="free-claude-code-termux"
FCC_COMMANDS="fcc-server fcc-doctor fcc-claude"
dry_run=0

show_usage() {
    cat <<'USAGE'
Usage: scripts/install-termux.sh [--dry-run] [--help]

Install Free Claude Code and Claude Code CLI in native Termux.
Run this script from a cloned Free Claude Code repository.

Options:
  --dry-run    Show installation commands without changing the device.
  --help       Show this help text.
USAGE
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

run() {
    printf '+'
    for argument do
        printf ' %s' "$argument"
    done
    printf '\n'
    if [ "$dry_run" -eq 0 ]; then
        "$@" || fail "Command failed: $1"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --help) show_usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
[ -f "$repo_dir/pyproject.toml" ] || fail "Run this installer from a Free Claude Code repository checkout."
[ -f "$repo_dir/requirements-termux.lock" ] || fail "Missing requirements-termux.lock."

if [ "$dry_run" -eq 0 ]; then
    case "${PREFIX:-}" in
        /data/data/com.termux/files/usr|/data/user/0/com.termux/files/usr) ;;
        *) fail "This installer must run in native Termux, not Linux or a PRoot container." ;;
    esac
fi

[ -n "${HOME:-}" ] || fail "HOME is not set."
[ -n "${PREFIX:-}" ] || [ "$dry_run" -eq 1 ] || fail "PREFIX is not set by Termux."

install_dir="$HOME/.local/share/$FCC_VENV_NAME"
venv="$install_dir/venv"
bin_dir="${PREFIX:-/data/data/com.termux/files/usr}/bin"

run pkg update -y
run pkg install -y python nodejs-lts git clang cmake make pkg-config rust openssl libffi zlib

if [ "$dry_run" -eq 0 ]; then
    required_python=$(sed -n 's/^[[:space:]]*requires-python[[:space:]]*=[[:space:]]*"==\([^"]*\)".*/\1/p' "$repo_dir/pyproject.toml")
    [ -n "$required_python" ] || fail "Could not read the exact Python version from pyproject.toml."
    actual_python=$(python -c 'import platform; print(platform.python_version())') ||
        fail "Could not run Termux Python."
    [ "$actual_python" = "$required_python" ] ||
        fail "This checkout requires Python $required_python, but Termux provides $actual_python. Upgrade Termux packages and retry."
fi

if [ "$dry_run" -eq 1 ]; then
    printf '+ verify Termux Python against pyproject.toml requires-python\n'
    printf '+ create or reuse virtual environment %s\n' "$venv"
    printf '+ install pinned dependencies from %s\n' "$repo_dir/requirements-termux.lock"
    printf '+ install Free Claude Code from %s\n' "$repo_dir"
    printf '+ install Claude Code CLI with npm if the claude command is missing\n'
    for command_name in $FCC_COMMANDS; do
        printf '+ link %s/%s to %s/bin/%s\n' "$bin_dir" "$command_name" "$venv" "$command_name"
    done
    printf '+ verify fcc-server --version and claude --version\n'
    exit 0
fi

mkdir -p "$install_dir"
if [ ! -x "$venv/bin/python" ]; then
    python -m venv "$venv" || fail "Could not create the virtual environment at $venv."
fi

export GRPC_PYTHON_BUILD_SYSTEM_OPENSSL=1
export GRPC_PYTHON_BUILD_SYSTEM_ZLIB=1
"$venv/bin/python" -m pip install --require-hashes --requirement "$repo_dir/requirements-termux.lock" ||
    fail "Installing pinned Python dependencies failed. See the compiler or pip error above."
"$venv/bin/python" -m pip install --no-deps --upgrade "$repo_dir" ||
    fail "Installing Free Claude Code from this checkout failed."

if ! command -v claude >/dev/null 2>&1; then
    run npm install --global @anthropic-ai/claude-code
fi
command -v claude >/dev/null 2>&1 ||
    fail "The Claude Code CLI is not on PATH after installation."
claude --version || fail "The installed Claude Code CLI did not start correctly."

mkdir -p "$bin_dir"
for command_name in $FCC_COMMANDS; do
    command_path="$bin_dir/$command_name"
    target="$venv/bin/$command_name"
    [ -x "$target" ] || fail "The package did not create $command_name."
    if [ -e "$command_path" ] || [ -L "$command_path" ]; then
        existing_target=$(readlink "$command_path" 2>/dev/null || true)
        [ "$existing_target" = "$target" ] ||
            fail "$command_path already exists and is not managed by this installer."
    fi
    ln -sfn "$target" "$command_path" || fail "Could not link $command_name into Termux PATH."
done

"$bin_dir/fcc-server" --version || fail "fcc-server failed its version check."
printf '\nInstallation complete.\n'
printf 'Start the server with: fcc-server\n'
printf 'Open http://127.0.0.1:8082 in your Android browser to configure a provider.\n'
printf 'In another Termux session, run: fcc-claude\n'

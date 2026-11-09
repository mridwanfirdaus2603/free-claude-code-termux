#!/data/data/com.termux/files/usr/bin/sh
set -eu

FCC_VENV_NAME="free-claude-code-termux"
FCC_COMMANDS="fcc-server fcc-doctor fcc-claude"
dry_run=0

show_usage() {
    cat <<'USAGE'
Usage: scripts/uninstall-termux.sh [--dry-run] [--help]

Remove the Free Claude Code Termux virtual environment and its command links.
This keeps ~/.fcc configuration, Claude Code, Node.js, and Termux packages.

Options:
  --dry-run    Show removal commands without changing the device.
  --help       Show this help text.
USAGE
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --help) show_usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

[ -n "${HOME:-}" ] || fail "HOME is not set."
if [ "$dry_run" -eq 0 ]; then
    case "${PREFIX:-}" in
        /data/data/com.termux/files/usr|/data/user/0/com.termux/files/usr) ;;
        *) fail "This uninstaller must run in native Termux." ;;
    esac
fi

install_dir="$HOME/.local/share/$FCC_VENV_NAME"
bin_dir="${PREFIX:-/data/data/com.termux/files/usr}/bin"
for command_name in $FCC_COMMANDS; do
    command_path="$bin_dir/$command_name"
    target="$install_dir/venv/bin/$command_name"
    if [ -L "$command_path" ] && [ "$(readlink "$command_path")" = "$target" ]; then
        printf '+ rm %s\n' "$command_path"
        [ "$dry_run" -eq 1 ] || rm "$command_path"
    elif [ -e "$command_path" ] || [ -L "$command_path" ]; then
        printf 'Keeping unmanaged command: %s\n' "$command_path"
    fi
done

printf '+ rm -r %s\n' "$install_dir"
if [ "$dry_run" -eq 0 ] && [ -d "$install_dir" ]; then
    rm -r "$install_dir" || fail "Could not remove $install_dir."
fi
printf 'FCC Termux files removed. User configuration in ~/.fcc was kept.\n'

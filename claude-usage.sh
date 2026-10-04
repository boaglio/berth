#!/usr/bin/env bash
#
# Launcher for the claude-usage-widget GUI overlay.
# Installed in an isolated venv under this directory.
#
# Usage:
#   ./claude-usage.sh            Launch the GUI in the foreground
#   ./claude-usage.sh -d         Launch in the background (logs to ~/.cache/claude-usage/widget.log)
#   ./claude-usage.sh --once     Print a one-shot JSON usage snapshot (headless)
#   ./claude-usage.sh <any args> Pass through any other flags to claude-usage
#
#

set -euo pipefail

# Resolve this script's directory so it works no matter where it's called from.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
BIN="$SCRIPT_DIR/claude-usage-widget-venv/bin/claude-usage"

if [[ ! -x "$BIN" ]]; then
    echo "error: claude-usage not found at $BIN" >&2
    echo "       (expected the venv to live next to this script)" >&2
    exit 1
fi

# The GUI needs a display server. Warn early with a clear message instead of
# a cryptic Qt crash if we're on a headless session and not running a CLI flag.
is_cli_flag=false
for arg in "$@"; do
    case "$arg" in
        --once|--json|--statusline|--field|--export|--version|-h|--help) is_cli_flag=true ;;
    esac
done

if [[ "$is_cli_flag" == false && -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "warning: no DISPLAY/WAYLAND_DISPLAY detected — the GUI needs a desktop session." >&2
    echo "         Run this from your Ubuntu desktop, or use a CLI flag like --once." >&2
fi

# On GUI launches, check PyPI for a newer release and offer to upgrade the venv.
# Skipped for headless CLI flags (keeps --statusline fast) or when
# CLAUDE_USAGE_NO_UPDATE_CHECK=1. Any network/parse failure is silently ignored.
check_for_update() {
    local py="$SCRIPT_DIR/claude-usage-widget-venv/bin/python"
    local pip="$SCRIPT_DIR/claude-usage-widget-venv/bin/pip"
    local result current latest
    result="$("$py" - <<'EOF' 2>/dev/null
import json, re
from importlib.metadata import version
from urllib.request import urlopen

def parse(v):
    return tuple(int(x) for x in re.findall(r"\d+", v)[:3])

cur = version("claude-usage-widget")
with urlopen("https://pypi.org/pypi/claude-usage-widget/json", timeout=3) as r:
    latest = json.load(r)["info"]["version"]
if parse(latest) > parse(cur):
    print(cur, latest)
EOF
)" || return 0
    [[ -n "$result" ]] || return 0
    read -r current latest <<< "$result"

    echo "claude-usage-widget $latest is available (installed: $current)." >&2
    if [[ -t 0 && -t 1 ]]; then
        local reply
        read -r -p "Upgrade now? [y/N] " reply || reply=""
        if [[ "$reply" =~ ^[Yy]$ ]]; then
            "$pip" install -U pip claude-usage-widget PySide6_Essentials shiboken6 certifi \
                || echo "warning: upgrade failed; launching the installed version." >&2
        fi
    else
        echo "Upgrade with: $pip install -U claude-usage-widget" >&2
    fi
}

if [[ "$is_cli_flag" == false && "${CLAUDE_USAGE_NO_UPDATE_CHECK:-0}" != 1 ]]; then
    check_for_update
fi

exec "$BIN" "$@"

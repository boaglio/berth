# AGENTS.md

Guidance for coding agents working in `berth` (`~/claude/github/berth`,
private repo https://github.com/boaglio/berth).

## What this is

A holder repo for locally-installed Claude helper apps. It is **not** a
source project — there is no build and no test suite. Each app is a
third-party tool installed into its own isolated environment (e.g. a Python
venv). Git tracks only the thin per-app launchers, this file and
`.gitignore`; the environments and `.claude/settings.local.json` are
gitignored. (Moved here from `~/claude/apps` on 2026-10-03.)

The general pattern for each app is:

- A launcher script at the top level (e.g. `<app>.sh`) that resolves its own
  directory, points at the app's isolated environment, guards common failure
  modes (missing binary, headless session), and `exec`s the real entrypoint.
- A sibling environment directory (e.g. `<app>-venv/`) holding the installed
  package. This is a **build artifact, not source** — see guardrails below.

Installed apps:

- **claude-usage-widget** — a desktop OSD widget + CLI showing real-time Claude
  Code usage limits and cost. Launcher: `claude-usage.sh`; env:
  `claude-usage-widget-venv/`. Third-party, MIT, by Burak;
  https://github.com/bozdemir/claude-usage-widget.

## Layout

```
<app>.sh                        Per-app launcher (resolves its env, execs the entrypoint).
<app>-env/                      Per-app isolated environment (installed package — a build artifact).
.claude/settings.local.json     Local Claude Code permission allowlist (gitignored, machine-local).
```

Current instance of that pattern:

```
claude-usage.sh                 Launcher for the usage widget (resolves the venv, guards headless).
claude-usage-widget-venv/       Python 3.14 venv with the pip-installed package.
  bin/claude-usage              The entrypoint the launcher execs.
  lib/.../site-packages/claude_usage/   Installed package source (vendored — do not edit).
```

## Running

Each app is driven through its launcher. Prefer the launcher over calling the
env's binary directly, so the environment-resolution and headless guards apply.

**claude-usage-widget** (`claude-usage.sh`):

```bash
./claude-usage.sh            # launch the GUI (needs a desktop session: DISPLAY/WAYLAND_DISPLAY)
./claude-usage.sh -d         # launch in background; logs -> ~/.cache/claude-usage/widget.log
./claude-usage.sh --once     # headless: print a one-shot JSON usage snapshot
./claude-usage.sh --statusline   # one compact line for Claude Code's statusLine setting
./claude-usage.sh --export csv --days 30 > usage.csv
```

For this app, `--once`, `--json`, `--statusline`, `--field`, `--export`, and
`--version` are headless CLI flags; any other invocation opens the Qt GUI and
needs a display.

## Conventions & guardrails

These apply to every app in this directory:

- **The app's environment is a build artifact, not source.** Everything under an
  `<app>-env/` directory (installed package included) comes from a package
  manager and is gitignored. Don't edit files there to "fix" an app — changes
  are lost on reinstall and aren't tracked. Fix upstream, or wrap behavior in
  the launcher.
- **Only the launcher scripts, this file, `.gitignore` and `.claude/` are meant
  to be edited here.** Keep
  launchers POSIX-bash, `set -euo pipefail`, and path-independent (resolve their
  own dir via `BASH_SOURCE` rather than assuming the caller's cwd).
- **Runtime state lives outside this dir**, typically under `~/.cache/<app>/` and
  `~/.config/<app>/` — check there for logs and config, not here.
- When adding a new app, follow the same shape: install into a sibling
  `<app>-env/`, add an `<app>.sh` launcher, and add an entry to the "Installed
  apps" list above.

App-specific notes:

- **claude-usage-widget** — update with
  `claude-usage-widget-venv/bin/pip install -U claude-usage-widget`; recreate
  the venv with
  `python3 -m venv claude-usage-widget-venv && claude-usage-widget-venv/bin/pip install claude-usage-widget`.
  Logs/config under `~/.cache/claude-usage/` and `~/.config/claude-usage/`;
  autostart, if configured, via `~/.config/autostart/claude-usage.desktop`.
  Before upgrading, check what's outdated with
  `claude-usage-widget-venv/bin/pip list --outdated`. Upgrade PySide6 along
  with the app:
  `claude-usage-widget-venv/bin/pip install -U pip claude-usage-widget PySide6_Essentials shiboken6 certifi`.
  - **Upgrade log, 2026-09-27:** 0.12.5 → 0.13.0, PySide6/shiboken6 6.11.1 →
    6.11.2.
    - **Cost figures dropped by about 2.7x.** 0.13.0 counts each response
      (`message.id`) once, so the new numbers are the correct ones.
    - **AI weekly report is now opt-in:** set `"ai_report_enabled": true` to
      turn it on.
    - **Unconfirmed crash fix:** the upgrade was partly for a SIGSEGV on
      PySide6 6.11.1 with Python 3.14. A worker thread crashed in
      `_Py_HandlePending` while the GUI thread took back the GIL in
      Shiboken during a paint. It's not known whether 6.11.2 fixes it. If it
      happens again, check `coredumpctl list claude-usage` and consider
      rebuilding the venv on Python 3.13.
  - **Launcher update check:** on GUI launches (not headless flags),
    `claude-usage.sh` asks PyPI (3 s timeout) if there's a newer version. In a
    terminal it offers to run the full upgrade above; otherwise it prints a
    notice. Set `CLAUDE_USAGE_NO_UPDATE_CHECK=1` to skip it.
  - **Upgrade log, 2026-10-03:** 0.13.0 → 0.13.1. Other packages were already
    current. This adds `claude-opus-5-5` pricing. Before this, Opus 5.5 was
    priced as Opus 5, which overstated its cost about 2x.
  - **Known log noise:** repeated `qt.qpa.services: Failed to register with
    host portal` lines are harmless on KDE. `UserWarning: Unknown model ...;
    falling back to ... pricing` means the cost for that model is estimated
    until upstream adds it to the pricing table.
  - **Launch the GUI from a real desktop terminal (Konsole).** Started from a
    Claude Code session (sandboxed Bash or `!`), `-d` died silently. The
    sandbox also can't read `~/.claude`, so headless output there shows zero
    usage.

## Verifying a change

There are no tests. After editing a launcher, exercise it with a headless flag
that touches environment resolution and exec without needing a display, e.g.:

```bash
./claude-usage.sh --version   # exercises venv resolution + exec, no display needed
./claude-usage.sh --once      # confirms the app produces output
```

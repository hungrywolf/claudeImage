#!/usr/bin/env bash
# claude-docker — run Claude Code inside the claude-box container.
#
# Usage:
#   claude-docker                 # drop into the container's bash shell, then run `claude`
#   claude-docker claude          # run Claude directly (interactive)
#   claude-docker -p "summarize"  # one-shot: pass args straight through to `claude`
#   claude-docker login           # one-time OAuth login (writes host ~/.claude)
#   claude-docker build           # (re)build the image
#   claude-docker update          # rebuild pulling the latest Claude Code
#   claude-docker sync            # refresh skills/agents from ~/.claude into box
#
# Default drops you into bash inside /workspace (your git dir). From there:
#   cd <repo>      # navigate to the project
#   claude         # start Claude in that folder
#
# If you're already inside a repo under your git dir on the host, the shell
# opens in that same repo inside the container.
set -euo pipefail

# Stop Git Bash/MSYS from rewriting POSIX args (like --workdir /workspace/...)
# into Windows paths (C:/Program Files/Git/workspace/...) when calling docker.exe.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

# Load proxy settings from the host environment (whatever is set in your shell /
# Windows env). Accept either case, mirror http<->https so one value covers both,
# then export so `docker compose` interpolation picks them up for build + runtime.
: "${HTTP_PROXY:=${http_proxy:-}}"
: "${HTTPS_PROXY:=${https_proxy:-}}"
: "${NO_PROXY:=${no_proxy:-}}"
[ -n "${HTTPS_PROXY}" ] || HTTPS_PROXY="${HTTP_PROXY}"
[ -n "${HTTP_PROXY}" ]  || HTTP_PROXY="${HTTPS_PROXY}"
export HTTP_PROXY HTTPS_PROXY NO_PROXY

# Git Bash's terminal isn't a real Windows console, so Docker can't allocate a
# TTY and interactive tools (the Claude TUI, bash) break. winpty bridges that —
# same trick your .bashrc already uses for `winpty claude.cmd`. Use it when we
# have a terminal and winpty is installed; skip it for piped/one-shot runs.
TTY_PREFIX=()
if [ -t 1 ] && command -v winpty >/dev/null 2>&1; then
    TTY_PREFIX=(winpty)
fi

# Remember where the user invoked us from BEFORE we cd into the script dir.
CALLER_DIR="$(pwd -P)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load GIT_DIR from .env so we can map your current folder into /workspace.
GIT_DIR_WIN="$(grep -E '^GIT_DIR=' .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r')"

# Turn "C:/Users/int3r/Documents/github" into Git-Bash form "/c/Users/int3r/Documents/github".
host_gitdir=""
if [ -n "${GIT_DIR_WIN}" ]; then
    host_gitdir="$(echo "$GIT_DIR_WIN" \
        | sed -E 's#^([A-Za-z]):#/\L\1#' )"   # C:/... -> /c/...
fi

# If the current directory is inside the git dir, cd to the matching subpath.
workdir_args=()
if [ -n "$host_gitdir" ]; then
    case "$CALLER_DIR/" in
        "$host_gitdir/"*)
            rel="${CALLER_DIR#$host_gitdir}"
            rel="${rel#/}"
            if [ -n "$rel" ]; then
                workdir_args=(--workdir "/workspace/$rel")
            fi
            ;;
    esac
fi

cmd="${1:-}"
case "$cmd" in
    build)
        exec docker compose build
        ;;
    update)
        exec docker compose build --pull --no-cache
        ;;
    sync)
        # Re-copy skills/agents/etc. from your real ~/.claude into the box config.
        exec bash "$SCRIPT_DIR/seed-config.sh"
        ;;
    login)
        # OAuth login; writes the token back to your host ~/.claude.
        exec "${TTY_PREFIX[@]}" docker compose run --rm "${workdir_args[@]}" claude claude login
        ;;
    shell|"")
        # Default: an interactive bash shell inside the box. Run `claude` from there.
        shift || true
        exec "${TTY_PREFIX[@]}" docker compose run --rm "${workdir_args[@]}" claude bash "$@"
        ;;
    *)
        # Everything else is passed to `claude` (e.g. `claude-docker -p "hi"`).
        exec "${TTY_PREFIX[@]}" docker compose run --rm "${workdir_args[@]}" claude claude "$@"
        ;;
esac

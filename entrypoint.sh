#!/usr/bin/env bash
# Entrypoint: wire up the host .bashrc (+ container overrides), then run the cmd.
#
# Your real ~/.bashrc is bind-mounted read-only at $HOST_BASHRC. We can't edit a
# read-only mount, so we make the container's own ~/.bashrc source it, followed
# by container.bashrc which fixes Windows-only paths for Linux (GitHome, winpty,
# editors). Every interactive `bash` in here then gets your full, working setup.
set -e

HOST_BASHRC="${HOST_BASHRC:-/home/node/.host-bashrc}"
CONTAINER_OVERRIDES="${CONTAINER_OVERRIDES:-/home/node/.container-bashrc}"
CONTAINER_BASHRC="${HOME}/.bashrc"

marker="# >>> claude-box bashrc wiring >>>"
if ! grep -qF "$marker" "$CONTAINER_BASHRC" 2>/dev/null; then
    {
        echo ""
        echo "$marker"
        echo "[ -f \"$HOST_BASHRC\" ]        && source \"$HOST_BASHRC\" 2>/dev/null || true"
        echo "[ -f \"$CONTAINER_OVERRIDES\" ] && source \"$CONTAINER_OVERRIDES\" 2>/dev/null || true"
        echo "# <<< claude-box bashrc wiring <<<"
    } >> "$CONTAINER_BASHRC"
fi

# Also pull both into THIS shell so env/functions are live for the exec'd command
# (host first, overrides second so the overrides win).
[ -f "$HOST_BASHRC" ]         && source "$HOST_BASHRC" 2>/dev/null || true
[ -f "$CONTAINER_OVERRIDES" ] && source "$CONTAINER_OVERRIDES" 2>/dev/null || true

# If no command was given, fall back to Claude.
if [ "$#" -eq 0 ]; then
    set -- claude
fi

# `bash`/`sh` with no args -> make it interactive so the sourced .bashrc loads.
case "$1" in
    bash|sh)
        if [ "$#" -eq 1 ]; then
            exec bash -i
        fi
        ;;
esac

exec "$@"

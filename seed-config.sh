#!/usr/bin/env bash
# seed-config.sh — create the container's OWN Claude config dir on the Windows
# PC (BOX_DIR), seeded from your real ~/.claude.
#
# Why: mounting your live ~/.claude into Linux shares config that has Windows
# paths baked in (C:\Users\...), which breaks in-container plugin installs and
# risks corrupting your real config. So the container gets an isolated copy
# instead. Plugins you install inside the box land here with proper Linux paths.
#
# What it copies:
#   once (kept if already present in the box, so a box login/settings survive):
#     .credentials.json, settings.json, settings.local.json
#   every run (refreshed from host — this is your "copy the skills" step):
#     skills/, agents/, commands/, output-styles/
#
# Usage:
#   ./seed-config.sh                 # uses BOX_DIR from .env, SRC = ~/.claude
#   ./seed-config.sh /c/Users/me/.claude   # explicit source
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Convert a "C:/..." path to Git-Bash "/c/..." form (no-op on Linux/macOS).
to_posix() { echo "$1" | sed -E 's#^([A-Za-z]):#/\L\1#'; }

SRC="${1:-$HOME/.claude}"

BOX_WIN="$(grep -E '^BOX_DIR=' .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r')"
[ -n "$BOX_WIN" ] || BOX_WIN="$HOME/.claude-box"
BOX="$(to_posix "$BOX_WIN")"
DEST="$BOX/.claude"

echo "==> seeding container config"
echo "    from : $SRC"
echo "    into : $DEST"

if [ ! -d "$SRC" ]; then
    echo "ERROR: source Claude config '$SRC' not found." >&2
    exit 1
fi

mkdir -p "$DEST"

# Copy a FILE only if the box doesn't already have it (preserve box state).
copy_once() {
    local f="$1"
    if [ -f "$SRC/$f" ] && [ ! -e "$DEST/$f" ]; then
        cp "$SRC/$f" "$DEST/$f" && echo "    + $f (seeded)"
    fi
}

# Overlay a DIR every run (refresh skills/agents from the host).
copy_refresh() {
    local d="$1"
    if [ -d "$SRC/$d" ]; then
        mkdir -p "$DEST/$d"
        cp -r "$SRC/$d/." "$DEST/$d/" && echo "    ~ $d/ (refreshed)"
    fi
}

copy_once ".credentials.json"
copy_once "settings.json"
copy_once "settings.local.json"

copy_refresh "skills"
copy_refresh "agents"
copy_refresh "commands"
copy_refresh "output-styles"

# Container's .claude.json lives next to .claude (not inside it). Start empty so
# plugins/marketplaces get registered fresh with Linux paths.
[ -f "$BOX/.claude.json" ] || { echo '{}' > "$BOX/.claude.json"; echo "    + .claude.json (empty)"; }

echo "==> done. Box config ready at: $BOX"

#!/usr/bin/env bash
# container.bashrc — overrides that make your host ~/.bashrc behave inside the
# Linux container. It is sourced AFTER your host ~/.bashrc, so anything set here
# wins. It's bind-mounted (not baked in), so edits apply on the next `cclaude` —
# no rebuild needed.

# ---------------------------------------------------------------------------
# winpty is a Windows-only shim. In Linux, just run the command directly.
# Defining it as a no-op transparently fixes EVERY `winpty <cmd>` alias from
# your host bashrc (vim, lua, arch, ...) without editing them one by one.
# ---------------------------------------------------------------------------
winpty() { "$@"; }

# ---------------------------------------------------------------------------
# Your repos are mounted at /workspace. Point GitHome there so all the repo
# navigation aliases resolve: gitdir, osrepo, leetrepo, jloxrepo, cloxrepo,
# calorepo, wyagrepo, homedir, scripts, ...
# (On the host GitHome is "$HOME/My Documents/github"; that path doesn't exist
#  in the container, which is why those aliases failed before.)
# ---------------------------------------------------------------------------
export GitHome="/workspace"

# ScriptsDir already resolves to /home/node/scripts via $HOME. Mount your host
# ~/scripts there (see docker-compose.yml, commented) if you want those aliases.

# ---------------------------------------------------------------------------
# Editors: the image ships vi / vim.tiny / nano (no nvim). Remap host aliases.
# ---------------------------------------------------------------------------
alias vim='vim.tiny'
alias nvim='vim.tiny'

# Windows-only aliases that can't work here — drop them so they don't confuse.
unalias open 2>/dev/null || true

# ---------------------------------------------------------------------------
# Add your own container-specific tweaks below.
# e.g. if you bake a JDK + Maven into the image:
#   unalias mvn 2>/dev/null || true
#   export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
# ---------------------------------------------------------------------------

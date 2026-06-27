### Claude Code in a container.
### Based on the official Node slim image (Claude Code is a Node CLI).
FROM node:22-bookworm-slim

ARG CLAUDE_VERSION=latest

# Tools you'll actually want available next to Claude inside the box.
# git + openssh for repos, ripgrep/fd/jq for Claude's own searches, plus the
# usual editor/shell niceties so your .bashrc aliases have something to call.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        bash \
        curl \
        wget \
        ca-certificates \
        less \
        jq \
        ripgrep \
        fd-find \
        openssh-client \
        gnupg \
        procps \
        unzip \
        nano \
        vim-tiny \
        python3 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf "$(command -v fdfind)" /usr/local/bin/fd

# Claude Code CLI, installed globally so it's on PATH for every user.
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION} \
    && npm cache clean --force

# Run as the unprivileged "node" user (uid 1000) that ships with the base image.
# Its home is where we mount your host ~/.claude, ~/.claude.json, ~/.bashrc, etc.
ENV HOME=/home/node \
    CLAUDE_CONFIG_DIR=/home/node/.claude \
    NODE_OPTIONS=--max-old-space-size=4096

# Entrypoint sources your host .bashrc (mounted read-only) so all of your
# aliases/functions are available, then execs whatever command you passed.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /home/node/.claude /workspace \
    && chown -R node:node /home/node /workspace

USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Default to an interactive Claude session; override by passing a command.
CMD ["claude"]

# claude-box — Claude Code in Docker Compose

Run [Claude Code](https://github.com/anthropics/claude-code) inside a container that:

- mounts your **git directory** (`$gitdir`) at `/workspace`,
- reuses your **local Claude login & config** (`~/.claude`, `~/.claude.json`) so you **never re-login**,
- sources your host **`.bashrc`** so all your aliases/functions are available inside,
- is driven by a single command you call from your `.bashrc`: **`cclaude`**.

Inspired by [beevelop/docker-claude](https://github.com/beevelop/docker-claude) (Compose + persistent
config volumes) and [ungb/claude-code-docker](https://github.com/ungb/claude-code-docker) (mount
`~/.claude` to persist auth).

## Layout

```
claudeImage/
├── Dockerfile          # node:22-slim + Claude Code CLI + git/rg/jq/ssh…
├── docker-compose.yml  # the claude service + all the mounts
├── entrypoint.sh       # sources your host .bashrc, then runs the command
├── claude-docker.sh    # the wrapper you call (auto-maps your CWD into /workspace)
├── container.bashrc    # Linux overrides for your host .bashrc (GitHome, winpty…)
├── install.sh          # one-shot setup for this/another machine
├── seed-config.sh      # copies skills/agents/creds into the isolated box config
├── bashrc-snippet.sh   # aliases to paste/source into your ~/.bashrc
├── .env                # your machine's paths (git-ignored)
└── .env.example        # template
```

## Install (this machine or a new one)

Clone/copy this `claudeImage` folder somewhere under your git dir, then:

```bash
cd claudeImage
./install.sh
```

The installer auto-detects your home and git dir (the parent folder of this repo),
converts paths for Docker, writes `.env`, **seeds an isolated Claude config** (`BOX_DIR`,
see below), builds the image, and wires `cclaude` into your `~/.bashrc`. Useful flags:

```bash
./install.sh --git-dir /c/Users/me/Documents/github   # mount a different dir
./install.sh --home /c/Users/me                        # different home/config
./install.sh --box-dir /c/Users/me/.claude-box         # isolated config location
./install.sh --no-build        # skip the docker build
./install.sh --no-bashrc       # don't touch ~/.bashrc
./install.sh --force           # overwrite an existing .env
```

Then:

```bash
source ~/.bashrc      # (or loadbashrc)
cclaudelogin          # one-time OAuth login (skipped if ~/.claude is already authed)
```

## Daily use

`cclaude` drops you into the container's **bash shell** (in `/workspace` = your git dir).
From there, navigate and run `claude` yourself — easiest way to land in the right folder:

```bash
cclaude                 # enter the box's shell
  cd leetcodeMediam     #   (now inside the container)
  claude                #   start Claude here
  exit                  # leave the box
```

Other entry points:

```bash
cclauderun              # run Claude directly (skip the shell)
cclauderun -p "hi"      # one-shot, non-interactive
cclaudelogin            # OAuth login (writes the box config)
cclaudebuild            # rebuild the image
cclaudesync             # refresh skills/agents from ~/.claude into the box
```

> **Git Bash note:** interactive runs are wrapped in `winpty` automatically (same trick your
> `.bashrc` uses for `winpty claude.cmd`) so the TTY works. Without it, Claude/bash see no
> terminal and bail with *"Input must be provided through stdin..."*.

## What gets mounted (see `docker-compose.yml`)

| Host | Container | Mode | Why |
|---|---|---|---|
| `$GIT_DIR`                | `/workspace`               | rw | your code |
| `$BOX_DIR/.claude`        | `/home/node/.claude`       | rw | **isolated** Claude config (login, plugins, history) |
| `$BOX_DIR/.claude.json`   | `/home/node/.claude.json`  | rw | Claude settings (box-local) |
| `~/.bashrc`               | `/home/node/.host-bashrc`  | ro | your aliases/functions |
| `~/.gitconfig`            | `/home/node/.gitconfig`    | ro | git identity |
| `~/.ssh`                  | `/home/node/.ssh`          | ro | git over SSH |

## Isolated config & plugins

The container does **not** mount your live `~/.claude`. That folder has Windows paths baked
in (`C:\Users\...`), which break inside Linux — e.g. installing a plugin failed with
`Source path does not exist: /workspace/C:\Users\...\playwright`. Instead, `install.sh` creates
a **separate config dir on the Windows PC** (`BOX_DIR`, default `~/.claude-box`) and seeds it
from your real `~/.claude`:

- **copied once:** `.credentials.json` (so login carries over), `settings.json`, `settings.local.json`
- **refreshed every `cclaudesync`:** `skills/`, `agents/`, `commands/`, `output-styles/`

Your real `~/.claude` is never modified. Plugins you install in the box are stored with proper
Linux paths and persist across runs. To install one (e.g. the Playwright MCP plugin):

```bash
cclaude
  claude plugin marketplace add https://github.com/anthropics/claude-plugins-official.git
  claude plugin install playwright@claude-plugins-official
  claude plugin list
```

> **Heads-up for Playwright specifically:** it drives a real browser, which the slim image
> doesn't ship. The plugin *installs* fine, but to actually run browser automation the image
> needs Chromium + libs (`npx playwright install --with-deps chromium`). Ask if you want that
> baked in — it adds a few hundred MB.

## Making your `.bashrc` work inside the container

Your host `~/.bashrc` is full of Windows-isms (`winpty`, `*.cmd`, `$HOME/My Documents/...`,
JetBrains paths) that don't exist in Linux. Rather than edit your real bashrc, the container
sources it **and then sources [`container.bashrc`](./container.bashrc)** — a Linux overrides
file that wins because it loads last. It's bind-mounted, so edits apply on the next `cclaude`
(no rebuild). Out of the box it:

- defines `winpty` as a **no-op function**, so every `winpty <cmd>` alias just runs `<cmd>`;
- sets **`GitHome=/workspace`**, fixing all your repo-nav aliases (`gitdir`, `osrepo`,
  `leetrepo`, `cloxrepo`, …) — they now `cd` into the mounted git dir;
- remaps `vim`/`nvim` → `vim.tiny` (the editor the image ships).

Add your own tweaks at the bottom of `container.bashrc`. To also get your `~/scripts`
aliases (`generatewp`, `createwp`, …), uncomment the `scripts` mount in `docker-compose.yml`.

> Anything you *don't* override stays defined but only fails if you actually call it.

## Proxy

The container inherits your **host proxy settings automatically** — no config needed.
When you run `cclaude`, the wrapper reads `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` (either
case) from your shell/Windows environment, mirrors http↔https so one value covers both, and
passes them to Docker for **both the build and the running container** (Claude API, git, npm,
apt, curl all honor them). `NO_PROXY` defaults to `localhost,127.0.0.1,::1` if unset.

```bash
export HTTPS_PROXY=http://proxy.corp:8080   # in your ~/.bashrc or Windows env
cclaude                                      # container now routes via the proxy
```

Nothing is written to `.env`. To *force* a value that overrides the environment, uncomment
the `HTTP_PROXY=`/`HTTPS_PROXY=` lines in `.env`.

> Behind a TLS-intercepting proxy you may also need its root CA inside the container — mount
> the cert and point `NODE_EXTRA_CA_CERTS`/`GIT_SSL_CAINFO` at it (ask if you need this).

## Config / paths

Edit `.env` if your machine differs:

```
CLAUDE_HOME=C:/Users/int3r                      # folder with ~/.claude and ~/.bashrc
GIT_DIR=C:/Users/int3r/Documents/github         # mounted at /workspace
```

Use **forward slashes** even on Windows — Docker Desktop accepts `C:/Users/...`.

## Update Claude Code

```bash
cclaude-build      # rebuild (cached)
# or, force the newest CLI:
"$GitHome/claudeImage/claude-docker.sh" update
```

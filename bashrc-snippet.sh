######## Claude (Docker) — claude-box
# Self-locating: resolves claude-docker.sh next to this file, so it works no
# matter where the repo lives on this machine.
__claudebox_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Enter the container's bash shell (in /workspace = your git dir), then run
# `claude` from the right folder.
alias cclaude='"$__claudebox_dir/claude-docker.sh"'
# Run Claude directly without dropping into a shell first:
alias cclauderun='"$__claudebox_dir/claude-docker.sh" claude'
alias cclaudelogin='"$__claudebox_dir/claude-docker.sh" login'
alias cclaudebuild='"$__claudebox_dir/claude-docker.sh" build'
# Refresh skills/agents from your real ~/.claude into the box config:
alias cclaudesync='"$__claudebox_dir/claude-docker.sh" sync'

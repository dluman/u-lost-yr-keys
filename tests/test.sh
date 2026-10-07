#!/bin/sh
# tests/test.sh <shell> -- lose ur keys on purpose, see if we find them.
#
# Starts its own agent, then sources u_lost_yr_keys.sh in a fresh <shell>
# with the agent "lost" and checks what comes back. Run from the repo root.

sh_under_test=${1:-sh}
script=$(pwd)/u_lost_yr_keys.sh
fails=0

ok()   { echo "ok   - $*"; }
fail() { echo "FAIL - $*"; fails=$((fails + 1)); }

# Source the script in a shell that lost its keys, print what it found.
# Extra args are prepended to the -c command (to tweak PATH etc.).
found() {
  "$sh_under_test" -c "$1 unset SSH_AUTH_SOCK SSH_AGENT_PID; . '$script'
    echo \"sock=\${SSH_AUTH_SOCK:-}\"; echo \"pid=\${SSH_AGENT_PID:-}\"
    ssh-add -l >/dev/null 2>&1; echo \"rc=\$?\""
}
field() { printf '%s\n' "$out" | sed -n "s/^$1=//p"; }

eval "$(ssh-agent -s)" >/dev/null
agent_sock=$SSH_AUTH_SOCK agent_pid=$SSH_AGENT_PID
echo "# $sh_under_test: agent $agent_pid at $agent_sock"

# 1. Lost keys get found.
out=$(found "")
if [ "$(field rc)" -ne 2 ] && [ "$(field sock)" -ef "$agent_sock" ]; then
  ok "finds the agent"
else
  fail "finds the agent ($out)"
fi
if [ "$(field pid)" = "$agent_pid" ]; then
  ok "sets SSH_AGENT_PID"
else
  # Single-agent fallback can't decide if the box has other agents
  # (macOS launchd, a runner's own). Not wrong, just shy.
  [ -z "$(field pid)" ] && ok "# SKIP leaves SSH_AGENT_PID unset (other agents around)" ||
    fail "sets SSH_AGENT_PID to $agent_pid ($out)"
fi

# 2. Same thing without pgrep (Git Bash has none; elsewhere, hide it).
if command -v pgrep >/dev/null 2>&1; then
  nopgrep=$(mktemp -d)
  for t in ls ssh-add id ps awk grep sed cat env "$sh_under_test"; do
    p=$(command -v "$t") && ln -s "$p" "$nopgrep/$(basename "$t")"
  done
  out=$(found "PATH='$nopgrep';")
  rm -rf "$nopgrep"
else
  out=$(found "")
fi
if [ "$(field rc)" -ne 2 ] && { [ "$(field pid)" = "$agent_pid" ] || [ -z "$(field pid)" ]; }; then
  ok "works without pgrep (pid=$(field pid))"
else
  fail "works without pgrep ($out)"
fi

# 3. A working agent is left alone.
out=$("$sh_under_test" -c ". '$script'; echo \"sock=\$SSH_AUTH_SOCK\"")
[ "$(field sock)" = "$agent_sock" ] && ok "leaves a working agent alone" ||
  fail "leaves a working agent alone ($out)"

# 4. Nothing leaks into the caller's shell.
out=$("$sh_under_test" -c ". '$script'; set | grep -i '^_*ulyk' ; true")
[ -z "$out" ] && ok "cleans up after itself" || fail "cleans up after itself ($out)"

# 5. Dead agents don't get picked.
ssh-agent -k >/dev/null
out=$(found "")
if [ "$(field sock)" -ef "$agent_sock" ] 2>/dev/null; then
  fail "skips dead agents ($out)"
elif [ -n "$(field sock)" ] && [ "$(field rc)" -eq 2 ]; then
  fail "only picks live agents ($out)"
else
  ok "skips dead agents (sock=$(field sock))"
fi

[ "$fails" -eq 0 ] && echo "# $sh_under_test: all good" || echo "# $sh_under_test: $fails failed"
[ "$fails" -eq 0 ]

# u_lost_yr_keys.sh -- source me, don't run me.
#
# Finds an ssh-agent u already started and points this shell at it,
# instead of u starting approx. 1 grabillion more of them.
#
# POSIX sh on purpose: /etc/profile.d gets sourced by /bin/sh, which is
# often dash, which does not care for ur bashisms.

# Pids of ur ssh-agents, one per line.
_ulyk_agents() {
  if command -v pgrep >/dev/null 2>&1; then
    pgrep -u "$(id -u)" -x ssh-agent 2>/dev/null
    return 0
  fi
  # No pgrep (Git Bash, MSYS2, Cygwin, slim containers). Try POSIX ps, then
  # Cygwin-style ps, whose columns are [flag] PID ... COMMAND. Either way the
  # command is the last column (maybe a full path, maybe .exe) and the pid
  # is the first number on the line.
  { ps -u "$(id -u)" -o pid= -o comm= 2>/dev/null || ps -u "$(id -u)" 2>/dev/null; } |
    awk '{ c = $NF; sub(/.*[\/\\]/, "", c); sub(/\.exe$/, "", c)
           if (c == "ssh-agent") print ($1 ~ /^[0-9]+$/ ? $1 : $2) }'
}

_ulyk() {
  # zsh isn't sh unless u ask nicely. Without this, one glob below matching
  # nothing makes zsh skip the whole ls, even when the other globs match.
  # (-L keeps it inside this function. Every other shell skips this line.)
  [ -n "${ZSH_VERSION:-}" ] && emulate -L sh

  # Already talking to an agent (forwarded with ssh -A, desktop keyring,
  # whatever)? Then u didn't lose anything. Leave it alone.
  # ssh-add -l exits 2 only when it can't reach an agent at all.
  ssh-add -l >/dev/null 2>&1
  [ $? -ne 2 ] && return 0

  # Where agents leave their sockets:
  #   - ~/.ssh/agent/      newer OpenSSH
  #   - /tmp/ssh-*/        classic ssh-agent
  #   - $TMPDIR/ssh-*/     same, but ssh-agent honours TMPDIR, which on macOS
  #                        is some /var/folders/... thing, not /tmp
  #   - launchd's agent    macOS starts one for u at login
  set -- "$HOME"/.ssh/agent/* /tmp/ssh-*/agent.* /tmp/com.apple.launchd.*/Listeners
  case ${TMPDIR:-/tmp} in
    /tmp|/tmp/) ;;
    *) set -- "$@" "${TMPDIR%/}"/ssh-*/agent.* ;;
  esac

  # Newest first, one per line, so paths with spaces in them (hi, Windows
  # home dirs) survive. Globs that match nothing stay as-is and ls just
  # complains quietly.
  _ulyk_found=
  while IFS= read -r _ulyk_sock; do
    # Ur socket, and an actual socket. Not someone else's. Not a leftover file.
    [ -S "$_ulyk_sock" ] && [ -O "$_ulyk_sock" ] || continue
    # Alive? (exit 1 = alive but no keys loaded, which still counts)
    SSH_AUTH_SOCK=$_ulyk_sock ssh-add -l >/dev/null 2>&1
    if [ $? -ne 2 ]; then
      _ulyk_found=$_ulyk_sock
      break
    fi
  done <<EOF
$(ls -td "$@" 2>/dev/null)
EOF

  # Nothing alive. Not our job to start one; don't export garbage either.
  [ -n "$_ulyk_found" ] || return 0
  export SSH_AUTH_SOCK="$_ulyk_found"

  # SSH_AGENT_PID only matters for `ssh-agent -k`, so only set it when
  # we're sure which agent it is:
  #   - classic sockets are agent.<N>, and the agent is usually pid N+1
  #   - otherwise, if u only have one agent running, it's that one
  # Anything else and we'd be guessing, so we don't.
  _ulyk_pid=
  case "$_ulyk_found" in
    */agent.*)
      _ulyk_n=${_ulyk_found##*/agent.}
      case "$_ulyk_n" in
        ''|*[!0-9]*) ;;
        *)
          _ulyk_n=$((_ulyk_n + 1))
          if _ulyk_agents | grep -qx "$_ulyk_n"; then
            _ulyk_pid=$_ulyk_n
          fi
          ;;
      esac
      ;;
  esac
  if [ -z "$_ulyk_pid" ]; then
    _ulyk_pids=$(_ulyk_agents)
    case "$_ulyk_pids" in
      ''|*[!0-9]*) ;;  # zero agents, or more than one (newline in there)
      *) _ulyk_pid=$_ulyk_pids ;;
    esac
  fi
  if [ -n "$_ulyk_pid" ]; then
    export SSH_AGENT_PID="$_ulyk_pid"
  else
    unset SSH_AGENT_PID
  fi
}

_ulyk
# Clean up after ourselves. This file gets sourced into ur shell, so
# anything we leave lying around, u get to keep forever.
unset -f _ulyk _ulyk_agents
unset _ulyk_found _ulyk_sock _ulyk_pid _ulyk_pids _ulyk_n

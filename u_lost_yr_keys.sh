# u_lost_yr_keys.sh -- source me, don't run me.
#
# Finds an ssh-agent u already started and points this shell at it,
# instead of u starting approx. 1 grabillion more of them.
#
# POSIX sh on purpose: /etc/profile.d gets sourced by /bin/sh, which is
# often dash, which does not care for ur bashisms.

_ulyk() {
  # Already talking to an agent (forwarded with ssh -A, desktop keyring,
  # whatever)? Then u didn't lose anything. Leave it alone.
  # ssh-add -l exits 2 only when it can't reach an agent at all.
  ssh-add -l >/dev/null 2>&1
  [ $? -ne 2 ] && return 0

  # Newest first. Covers classic /tmp/ssh-XXXX/agent.<pid> sockets and
  # newer OpenSSH's ~/.ssh/agent/ sockets. The braces keep zsh's
  # "no matches found" quiet when a glob comes up empty.
  _ulyk_found=
  for _ulyk_sock in $( { ls -t "${TMPDIR:-/tmp}"/ssh-*/agent.* "$HOME"/.ssh/agent/*; } 2>/dev/null ); do
    # Ur socket, and an actual socket. Not someone else's. Not a leftover file.
    [ -S "$_ulyk_sock" ] && [ -O "$_ulyk_sock" ] || continue
    # Alive? (exit 1 = alive but no keys loaded, which still counts)
    SSH_AUTH_SOCK=$_ulyk_sock ssh-add -l >/dev/null 2>&1
    if [ $? -ne 2 ]; then
      _ulyk_found=$_ulyk_sock
      break
    fi
  done

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
          if pgrep -u "$(id -u)" -x ssh-agent | grep -qx "$_ulyk_n"; then
            _ulyk_pid=$_ulyk_n
          fi
          ;;
      esac
      ;;
  esac
  if [ -z "$_ulyk_pid" ]; then
    _ulyk_pids=$(pgrep -u "$(id -u)" -x ssh-agent 2>/dev/null)
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
unset -f _ulyk
unset _ulyk_found _ulyk_sock _ulyk_pid _ulyk_pids _ulyk_n

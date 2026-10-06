# U did it and now u regret

And now u want them back.

No more starting approx. 1 grabillion `ssh-agent` processes -- just pick up where u left off.

## What it does

U open a new terminal. Ur keys are gone. Not *gone* gone -- the `ssh-agent` u started
three terminals ago is still sitting there holding them, u just forgot where u put it.

This script goes and finds it:

- **Already got a working agent?** (forwarded with `ssh -A`, ur desktop keyring, etc.)
  Then u didn't lose anything. It does nothing. Go away.
- **Otherwise** it looks for agent sockets in `$TMPDIR` (or `/tmp`) as `ssh-*/agent.*`, and
  in `~/.ssh/agent/` where newer OpenSSH hides them, newest first.
- **Only ur sockets.** Not ur coworker's. We are not that kind of script.
- **Only live ones.** Dead sockets from agents that died in the line of duty get skipped.
- **Found one?** `SSH_AUTH_SOCK` gets pointed at it. `SSH_AGENT_PID` gets set too if it can
  tell which agent that is (it only matters for `ssh-agent -k`, so it won't guess).
- **Found nothing?** It leaves ur environment alone instead of making stuff up. Start an
  agent like a normal person: `eval "$(ssh-agent -s)"`.

It's plain POSIX `sh`, so it works in `sh`/`dash`, `bash` and `zsh`, and it cleans up its
own variables so ur shell doesn't fill up with junk.

## Install

This file gets **sourced**, not run. Running it does nothing useful -- the exports die with the
subshell, just like ur hopes.

### Just for u (recommended)

```sh
cp u_lost_yr_keys.sh ~/.u_lost_yr_keys.sh
echo '. ~/.u_lost_yr_keys.sh' >> ~/.bashrc   # or ~/.zshrc, or ~/.profile
```

`~/.bashrc` runs in every new terminal. `/etc/profile.d` only runs in login shells, and plenty
of terminal emulators don't start those.

### For everyone on the box

```sh
sudo cp u_lost_yr_keys.sh /etc/profile.d/
```

Every user's login shells pick it up. It only ever grabs each user's *own* agent, so it's not
going to hand ur keys to anyone. (zsh doesn't read `/etc/profile.d` by default. Not our fault.)

## Try it

```sh
eval "$(ssh-agent -s)" && ssh-add          # start an agent, add a key
env -u SSH_AUTH_SOCK -u SSH_AGENT_PID sh   # new shell, keys "lost"
. ./u_lost_yr_keys.sh                      # ...found
ssh-add -l                                 # there they are
```

## Or just never lose them

If u'd rather not lose them in the first place, give the agent a fixed address
(`ssh-agent -a ~/.ssh/agent.sock`), or use `keychain`, or ur distro's systemd user
`ssh-agent` service. We won't be offended. Much.

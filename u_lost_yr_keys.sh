#! /bin/bash

for sock in `ls -tr /tmp`
do
  if [[ ${sock:0:3} == "ssh" ]]; then
    dir=$sock
  fi
done

for agent in `ls /tmp/$dir`
do
  latest_agent=$agent
done

export SSH_AUTH_SOCK="/tmp/$dir/$latest_agent"

for proc in `ps aux | pgrep "ssh-agent"`
do
  final_proc=$proc
done

export SSH_AGENT_PID=$final_proc

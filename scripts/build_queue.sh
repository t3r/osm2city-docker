#!/bin/bash

QCMD=$(dirname $0)/queue.sh

set -euo pipefail
while
  echo "Checking queue"
  n=`$QCMD len`
  [[ -n "$n" && "$n" -gt 0 ]]
do 
  JOB=`$QCMD pop`
  echo "JOB: $JOB"
  eval `echo $JOB | jq -r 'to_entries | map("\(.key|ascii_upcase)=\(.value)") | .[]'`

  # SIZE Jobs - create individual 1x1 jobs
  if [ -n "${SIZE-}" ]; then
    echo "size job"
    for LNG in $(seq $W 1 $(($W+$SIZE-1))); do
      for LAT in $(seq $S 1 $(($S+$SIZE-1))); do
        $QCMD push $(printf '{"w":"%s","s":"%s","e":"%s","n":"%s"}\n' $LNG $LAT $(($LNG+1)) $((LAT+1))) && echo -n "."
      done
    done
    SIZE=
    echo; echo "are jobs pushed"
  else
    echo "Dequeued: $W $S $E $N"
  fi
done


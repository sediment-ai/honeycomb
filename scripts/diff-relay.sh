#!/usr/bin/env bash
# Diff this repo's relay config against the cluster host.
#
# The host is the runtime; relay/ is the versioned copy. apply.sh doesn't
# converge the relay — it's a different lifecycle — so nothing else notices
# when the two drift apart. Run this after touching either side.
set -euo pipefail
HOST="${CLUSTER_HOST:?set CLUSTER_HOST to the ssh alias of your cluster host}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rc=0

check() { # <file in relay/> <path on the host; $HOME expands remotely>
  local remote status=0
  # Only the remote `cat` is silenced, so ssh's own errors still reach the
  # terminal. Suppressing those instead would turn an unreachable host into
  # an empty read, and report whole-file DRIFT for what is really an outage.
  #
  # The remote runs under bash -lc because the host shell is fish. Emptiness,
  # not exit status, is what says the read failed: this connection reports 0
  # even for `ssh <host> "exit 7"`, which is why build-image.sh guards on an
  # empty digest rather than on `&&`. Status 255 is ssh's own and does work.
  remote=$(ssh -o BatchMode=yes -o ConnectTimeout=10 \
             "$HOST" "bash -lc 'cat \"$2\" 2>/dev/null'") || status=$?
  # A dead host fails every check identically. Say so once and stop, rather
  # than spending a connect timeout per file to repeat it.
  if (( status == 255 )); then
    echo "UNREACHABLE  $1  (ssh $HOST failed)"
    exit 1
  fi
  if [[ -z $remote ]]; then
    echo "MISSING      $1  (host: $2)"
    rc=1
    return
  fi
  if diff -u --label "host:$2" --label "repo:relay/$1" \
       <(printf '%s\n' "$remote") "$ROOT/relay/$1"; then
    echo "ok           $1"
  else
    echo "DRIFT        $1"
    rc=1
  fi
}

check compose.selfhost.override.yml '$HOME/code/buzz/deploy/compose/compose.selfhost.override.yml'
check Caddyfile.selfhost            '$HOME/code/buzz/deploy/compose/Caddyfile.selfhost'
check relay-compose.sh              '$HOME/.config/buzz-agents/relay-compose.sh'
exit $rc

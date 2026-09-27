#!/usr/bin/env bash
# Drive the selfhost relay stack. Replaces run-relay.sh (source build + tmux).
# run.sh can't see our override, so pass the file list explicitly.
set -euo pipefail
cd ~/code/buzz/deploy/compose
exec docker compose --env-file .env \
  -f compose.yml -f compose.caddy.yml -f compose.selfhost.override.yml "$@"

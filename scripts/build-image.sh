#!/usr/bin/env bash
# Build + push the fleet agent image from this repo's image/ context.
# With SEDIMENT_CHECKOUT set (or a sediment checkout at ~/code/sediment),
# the capture clients are synced from sediment@main and baked in. Without
# one, the build stages placeholders and produces a plain Buzz+pi agent
# image — the entrypoint skips capture setup when the scripts are empty.
# Prints the digest to pin in pod manifests. The build runs on the
# cluster host over ssh (the registry is localhost:5555 there); set
# CLUSTER_HOST for your environment.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_HOST="${CLUSTER_HOST:?set CLUSTER_HOST to the ssh alias of your cluster host}"
SEDIMENT="${SEDIMENT_CHECKOUT:-$HOME/code/sediment-v2}"
STAGE=$(mktemp -d)
cp "$ROOT"/image/* "$STAGE/"
mkdir -p "$STAGE/shims/pi/lib"
if git -C "$SEDIMENT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "sediment checkout at $SEDIMENT: baking in the capture stack"
  git -C "$SEDIMENT" fetch -q origin main
  # ponytail: bake the implementation, not scripts/sediment_attribution.py.
  # Upstream made that path a checkout shim (sediment#405) resolving its target
  # relative to its own location, so it only works inside a checkout — copied
  # out to a flat dir it looks for $HOME/cli/... and dies. Upstream's own note:
  # fleet bundles copy the implementation file's bytes, not the shim.
  git -C "$SEDIMENT" show origin/main:cli/sediment_cli/attribution.py > "$STAGE/sediment_attribution.py"
  git -C "$SEDIMENT" show origin/main:scripts/sediment_transcript.py  > "$STAGE/sediment_transcript.py"
  for f in index.ts package.json; do
    git -C "$SEDIMENT" show "origin/main:shims/pi/$f" > "$STAGE/shims/pi/$f"; done
  for f in contract.ts register.ts provider.ts; do
    git -C "$SEDIMENT" show "origin/main:shims/pi/lib/$f" > "$STAGE/shims/pi/lib/$f"; done
else
  echo "no sediment checkout: building a plain fleet image (no capture stack)"
  touch "$STAGE/sediment_attribution.py" "$STAGE/sediment_transcript.py"
  echo '{}' > "$STAGE/config.json"
fi
rsync -a --delete "$STAGE/" "$CLUSTER_HOST":buzz-fleet-build/
rm -rf "$STAGE"
# --pull refreshes buzz-sprig:main (and the other FROMs) so every build
# carries the current Buzz; without it the cached base can go days stale.
# Build/push noise goes to stderr; stdout is just the pushed digest,
# which gets pinned into image/DIGEST for render.py.
DIGEST=$(ssh "$CLUSTER_HOST" 'bash -lc "cd ~/buzz-fleet-build \
  && docker build --pull --progress=plain -t localhost:5555/sediment-agent:latest . >&2 \
  && docker push localhost:5555/sediment-agent:latest | tee /dev/stderr | awk \"/digest:/{print \\\$3}\""')
[ -n "$DIGEST" ] || { echo "no digest from push" >&2; exit 1; }
echo "$DIGEST" > "$ROOT/image/DIGEST"
echo "pinned $DIGEST in image/DIGEST"

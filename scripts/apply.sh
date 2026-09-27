#!/usr/bin/env bash
# Converge the fleet to this repo's state. Renders every agent (or the
# roles given as arguments) and recreates only the pods that drift from
# the render: secret content hash, image digest, or restartPolicy.
# Pods are recreated one at a time, waiting for Ready between roles —
# staggered starts are the OOM-cascade mitigation from fleet-design.md.
#
# Usage: scripts/apply.sh [role ...] [--force]
# ponytail: drift check covers secret/image/restartPolicy; other
# pod.tmpl.yaml field changes need --force to roll out.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KC=(kubectl --context k3d-buzz-fleet -n buzz-agents)

FORCE=0
ROLES=()
for a in "$@"; do
  if [ "$a" = "--force" ]; then FORCE=1; else ROLES+=("$a"); fi
done
if [ ${#ROLES[@]} -eq 0 ]; then
  for f in "$ROOT"/agents/*.yaml; do ROLES+=("$(basename "$f" .yaml)"); done
fi

for role in "${ROLES[@]}"; do
  out=$("$ROOT/scripts/render.py" "$role")
  secret=$(sed -n 's/.*secret=\([^ ]*\).*/\1/p' <<<"$out")
  pod=$(sed -n 's/.*pod=\([^ ]*\).*/\1/p' <<<"$out")
  want_image=$(awk '$1=="image:"{print $2}' "$ROOT/.out/$role-pod.yaml")
  want_rp=$(awk '$1=="restartPolicy:"{print $2}' "$ROOT/.out/$role-pod.yaml")
  live=$("${KC[@]}" get pod "$pod" -o jsonpath='{.spec.containers[0].envFrom[0].secretRef.name} {.spec.containers[0].image} {.spec.restartPolicy}' 2>/dev/null || echo absent)
  if [ "$live" = "$secret $want_image $want_rp" ] && [ "$FORCE" = 0 ]; then
    echo "$role: in sync"
    continue
  fi
  echo "$role: converging (live: $live)"
  "${KC[@]}" apply -f "$ROOT/.out/$role-secret.yaml" >/dev/null
  "${KC[@]}" delete pod "$pod" --ignore-not-found --wait >/dev/null
  "${KC[@]}" apply -f "$ROOT/.out/$role-pod.yaml" >/dev/null
  "${KC[@]}" wait --for=condition=Ready "pod/$pod" --timeout=300s >/dev/null
  echo "$role: ready ($secret)"
done

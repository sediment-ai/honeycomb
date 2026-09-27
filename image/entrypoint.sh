#!/bin/bash
set -euo pipefail
# EmptyDir shadows the image HOME — materialize the capture stack at runtime.
mkdir -p "$HOME/.sediment"
cp -n /opt/sediment/sediment_attribution.py /opt/sediment/sediment_transcript.py "$HOME/.sediment/" 2>/dev/null || true
cp -n /opt/sediment/config.json "$HOME/.sediment/config.json" 2>/dev/null || true
# pi shim rides HOME too: install registers $HOME/shims/pi in pi's settings
# (that is what _pi_extension_dir resolves to from $HOME/.sediment).
cp -Rn /opt/sediment/shims "$HOME/" 2>/dev/null || true
# ORDER MATTERS: this must run BEFORE the stamper install below — the
# renderer creates ~/.pi/agent, and install's presence gate
# skips the pi extension when that directory is absent.
# pi ignores ANTHROPIC_BASE_URL — custom endpoints live in models.json.
# Rendered at start from env (SEDIMENT_PI_MODELS: comma list of gateway
# alias ids) so keys ride the Secret, never an image layer.
if [ -n "${SEDIMENT_PI_MODELS:-}" ]; then
python3 - <<'PYEOF' || true
import json, os, re
home = os.environ["HOME"]
# role from the same header the git-identity block parses (which runs later)
m = re.search(r"x-sediment-agent:\s*([a-z0-9-]+)", os.environ.get("ANTHROPIC_CUSTOM_HEADERS", ""))
role = m.group(1) if m else ""
# env-REF string, resolved by pi at request time — never a literal key.
# AUTH_TOKEN is the master key on every agent; API_KEY is the fallback.
ref = "$ANTHROPIC_AUTH_TOKEN" if os.environ.get("ANTHROPIC_AUTH_TOKEN") else "$ANTHROPIC_API_KEY"
base = os.environ.get("ANTHROPIC_BASE_URL", "http://192.168.65.254:4000")
# honest sizes per model family: overstating contextWindow breaks pi's
# compaction thresholds.
ctx = int(os.environ.get("SEDIMENT_PI_CONTEXT", "200000"))
maxtok = int(os.environ.get("SEDIMENT_PI_MAXTOKENS", "64000"))
models = [
    {
        "id": alias.strip(),
        "name": f"{alias.strip()} (sediment gateway)",
        "reasoning": True,
        "contextWindow": ctx,
        "maxTokens": maxtok,
    }
    for alias in os.environ["SEDIMENT_PI_MODELS"].split(",")
    if alias.strip()
]
provider = {
    "baseUrl": base,
    "apiKey": ref,
    "api": "anthropic-messages",
    "models": models,
}
if role:
    # static agent attribution on every gateway request;
    # the callback maps it to user_id agent:<role> when richer sources
    # are absent. The session header is dynamic and rides the shim.
    provider["headers"] = {"x-sediment-agent": role}
cfg = {"providers": {"sediment": provider}}
os.makedirs(f"{home}/.pi/agent", exist_ok=True)
path = f"{home}/.pi/agent/models.json"
if not os.path.exists(path):
    json.dump(cfg, open(path, "w"), indent=1)
PYEOF
fi

seed=$(mktemp -d) && git -C "$seed" init -q
# Capture stack is optional: plain images stage an empty script. When
# present, agent hooks (claude-code, codex, pi extension) install by
# default; --transcripts opts in the SessionEnd extractor.
if [ -s "$HOME/.sediment/sediment_attribution.py" ]; then
  python3 "$HOME/.sediment/sediment_attribution.py" install "$seed" --transcripts || true
fi
rm -rf "$seed"

# Git identity: role from the per-agent attribution header, one source of truth.
role=$(printf '%s' "${ANTHROPIC_CUSTOM_HEADERS:-}" | sed -n 's/.*x-sediment-agent:[[:space:]]*\([a-z0-9-]*\).*/\1/p')
role="${role:-agent}"
git config --global user.name "$role"
git config --global user.email "${role}@${AGENT_EMAIL_DOMAIN:-agents.sediment.local}"
# Nostr-signed commits when the pubkey derives; unsigned beats broken.
if [ -n "${BUZZ_PRIVATE_KEY:-}" ] && pub=$(python3 /opt/sediment/derive_pubkey.py <<< "$BUZZ_PRIVATE_KEY" 2>/dev/null); then
    git config --global user.signingkey "$pub"
else
    git config --global commit.gpgsign false
fi

if [[ -n "${BUZZ_RELAY_URL:-}" ]]; then
    u="${BUZZ_RELAY_URL/#ws:/http:}"; u="${u/#wss:/https:}"; u="${u%/}"
    git config --global "credential.${u}/git.helper" /usr/local/bin/git-credential-nostr
    git config --global "credential.${u}/git.useHttpPath" true
fi
# Stay PID 1: pod SIGTERM must reach the pi processes AFTER buzz-acp
# winds down, or the runtime SIGKILLs them before transcripts flush.
buzz-acp "$@" &
ACP_PID=$!
term() {
  kill -TERM "$ACP_PID" 2>/dev/null
  for _ in $(seq 1 30); do kill -0 "$ACP_PID" 2>/dev/null || break; sleep 1; done
  pkill -TERM -x pi 2>/dev/null || true
  for _ in $(seq 1 10); do pgrep -x pi >/dev/null 2>&1 || break; sleep 1; done
  # Deterministic backstop: ship every pi transcript ourselves. The server
  # dedups on (org, source, session, call_id) first-write-wins, so a
  # double-ship is harmless. The session id comes from the file's own
  # {"type":"session"} header — filenames are not ids, and the parser
  # refuses a contradicting id (ADR 0002). Unknown layout globs no-op.
  for F in "$HOME"/.pi/agent/sessions/*.jsonl "$HOME"/.pi/agent/sessions/*/*.jsonl; do
    [ -f "$F" ] || continue
    [ -s "$HOME/.sediment/sediment_transcript.py" ] || break
    SID=$(head -1 "$F" | python3 -c 'import json,sys; d=json.loads(sys.stdin.read() or "{}"); print(d.get("id","") if d.get("type")=="session" else "")' 2>/dev/null)
    [ -n "$SID" ] || continue
    printf '{"session_id":"%s","transcript_path":"%s"}' "$SID" "$F" \
      | python3 "$HOME/.sediment/sediment_transcript.py" --agent pi || true
  done
  exit 0
}
trap term TERM INT
wait "$ACP_PID"

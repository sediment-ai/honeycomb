#!/usr/bin/env python3
"""Render a fleet agent's Secret + Pod manifests from its agents/<role>.yaml.

The agent YAML is the source of truth for everything except live
credentials, which are cloned from the agent's current cluster Secret
(base_secret) and never stored in this repo. Secret names carry a content
hash so a config change mints a new immutable Secret (-<hash8>), and an
unchanged config is a no-op.

Usage: scripts/render.py <role> [--image-digest sha256:...]  (default: image/DIGEST)
Then:  kubectl --context k3d-buzz-fleet apply -f .out/<role>-secret.yaml
       kubectl --context k3d-buzz-fleet delete pod <pod>; apply -f .out/<role>-pod.yaml
"""

import argparse
import base64
import hashlib
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
KC = ["kubectl", "--context", "k3d-buzz-fleet", "-n", "buzz-agents"]

POD_TMPL = (ROOT / "manifests" / "pod.tmpl.yaml").read_text()


def load_yaml(path: pathlib.Path) -> dict:
    # ponytail: the agent files are flat key: value — no yaml dep needed
    out = {}
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("role")
    ap.add_argument("--image-digest", default=(ROOT / "image" / "DIGEST").read_text().strip())
    ap.add_argument("--out", default=str(ROOT / ".out"))
    args = ap.parse_args()

    cfg = load_yaml(ROOT / "agents" / f"{args.role}.yaml")
    prompt = (ROOT / "agents" / cfg["prompt"]).read_text()
    pod, pub12 = cfg["pod"], cfg["pubkey12"]

    live = json.loads(
        subprocess.check_output(KC + ["get", "secret", cfg["base_secret"], "-o", "json"], text=True)
    )
    data = dict(live["data"])
    b64 = lambda s: base64.b64encode(s.encode()).decode()
    data.update({
        "BUZZ_ACP_AGENT_COMMAND": b64("pi-acp"),
        "BUZZ_ACP_AGENTS": b64(cfg["pool"]),
        "BUZZ_ACP_MODEL": b64(f"sediment/{cfg['model_id']}"),
        "BUZZ_ACP_IDLE_TIMEOUT": b64(cfg["idle_timeout"]),
        "BUZZ_ACP_MAX_TURN_DURATION": b64(cfg["max_turn_duration"]),
        "BUZZ_ACP_SYSTEM_PROMPT": b64(prompt),
        "SEDIMENT_PI_MODELS": b64(cfg["model_id"]),
        **({"RUST_LOG": b64(cfg["rust_log"])} if cfg.get("rust_log") else {}),
        "SEDIMENT_PI_CONTEXT": b64(cfg["context_window"]),
        "SEDIMENT_PI_MAXTOKENS": b64(cfg["max_tokens"]),
    })
    content_hash = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()[:8]
    secret_name = f"buzz-agent-{pub12}-cfg{content_hash}"

    outdir = pathlib.Path(args.out)
    outdir.mkdir(exist_ok=True)
    secret = {
        "apiVersion": "v1", "kind": "Secret", "type": "Opaque",
        "metadata": {"name": secret_name, "namespace": "buzz-agents"},
        "data": data,
    }
    (outdir / f"{args.role}-secret.yaml").write_text(json.dumps(secret))
    pod_yaml = (
        POD_TMPL.replace("{{POD}}", pod)
        .replace("{{SECRET}}", secret_name)
        .replace("{{DIGEST}}", args.image_digest)
    )
    (outdir / f"{args.role}-pod.yaml").write_text(pod_yaml)
    print(f"{args.role}: secret={secret_name} pod={pod} model=sediment/{cfg['model_id']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

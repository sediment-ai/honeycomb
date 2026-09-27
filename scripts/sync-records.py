#!/usr/bin/env python3
"""Sync the Buzz app's managed-agent records from this repo's agent configs.

Run with the Buzz app CLOSED (it rewrites managed-agents.json on its own
schedule). This keeps app-driven deploy paths convergent with the cluster
state the apply loop creates — in-app saves never redeploy anything
(block/buzz#2798), so this sync is bookkeeping, not deployment.

Usage: scripts/sync-records.py [--image-digest sha256:...]
"""

import argparse
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANAGED = pathlib.Path.home() / "Library/Application Support/xyz.block.buzz.app/agents/managed-agents.json"


def cfg(role: str) -> dict:
    out = {}
    for line in (ROOT / f"agents/{role}.yaml").read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image-digest", default=None)
    args = ap.parse_args()

    import subprocess
    if subprocess.run(["pgrep", "-x", "buzz-desktop"], capture_output=True).returncode == 0:
        print("Buzz app is running — quit it first", file=sys.stderr)
        return 1

    roles = sorted(p.stem for p in (ROOT / "agents").glob("*.yaml"))
    data = json.loads(MANAGED.read_text())
    shutil.copy2(MANAGED, MANAGED.with_name("managed-agents.json.bak-sync"))
    n = 0
    for r in data:
        role = r.get("name")
        if role not in roles:
            continue
        c = cfg(role)
        r["runtime"] = c["harness"]
        r["agent_command"] = "pi-acp" if r.get("pubkey") else ""
        r["model"] = f"sediment/{c['model_id']}"
        r["parallelism"] = int(c["pool"])
        r["system_prompt"] = (ROOT / "agents" / c["prompt"]).read_text()
        if args.image_digest and isinstance(r.get("backend"), dict) \
                and r["backend"].get("type") == "provider":
            r["backend"]["config"]["image"] = f"k3d-fleet-reg:5555/sediment-agent@{args.image_digest}"
        n += 1
    MANAGED.write_text(json.dumps(data, indent=2) + "\n")
    print(f"synced {n} records for roles: {', '.join(roles)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

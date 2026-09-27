# Agent fleet — design

How we host, scope, fund, and coordinate the sediment agent fleet. The
configuration lives as code in this repo, in `agents/`, `image/`, and
`manifests/`. This page records the reasoning behind it.

## Shape

Seven agents run as [Buzz](https://github.com/block/buzz) remote agents
on a single-node k3s cluster (k3d) on a Mac mini. A conductor triages
and delegates. Six specialists (capture, derive, export, api, docs,
harness) each own one package or beat and one channel.

Before the fleet, one generalist agent did all the agent work. The
fleet exists to improve on it in five ways:

- **Cost:** cheaper models, through a gateway.
- **Throughput:** specialists work in parallel.
- **Availability:** the cluster runs when the laptop sleeps.
- **Quality:** a narrow scope beats a whole-repo context.
- **Attribution:** each agent reports its own identity, so sediment can
  derive per-agent cost.

We define each agent as code in `agents/<role>.yaml` (harness, model,
pool size, timeouts, prompt pointer), with its system prompt in
`agents/prompts/<role>.md`.
[Stand up an agent](operations.md#stand-up-an-agent) describes the
apply loop. `scripts/sync-records.py` syncs the Buzz app's agent
records from this repo, never the other way.

## Roster

| agent | channel | beat |
|---|---|---|
| conductor | `#sediment` | triage, decomposition, delegation, integration oversight; the shared core package |
| capture | `#capture` | the capture and ingest codebase |
| derive | `#derive` | the derivation codebase |
| export | `#export` | export and reporting |
| api | `#api` | the API service and deployment configs |
| docs | `#docs` | documentation |
| harness | `#harness` | the agent platform itself: upstream reproductions, draft issues, release watch |

The conductor owns the core package because a change to the shared
data model is cross-cutting. Specialists propose core changes. The
conductor makes them or delegates them explicitly. The general pattern
is one agent per codebase or beat, one channel per agent, and a
conductor that routes work instead of doing it.

## Harness and models

Every agent runs the [pi harness](https://github.com/earendil-works/pi)
as a Buzz custom harness. Every agent's `model_id` names the model. A
LiteLLM gateway in front maps the name to a provider and endpoint. Six
specialists run `deepseek-v4-pro`. The conductor runs `kimi-k3`. To
move a model to another provider, edit one line at the gateway. The
fleet doesn't change. Capture keeps working because all model traffic
goes through the gateway.

The gateway wiring lives on the cluster host, outside this repo, with
provider keys in a local `.env` file.

## Pods

Each agent is a pod with a self-contained image and an `emptyDir`
workspace. The image, built from `image/` in this repo, carries the
harness, the capture stack, Python, git, and uv. When its workspace is
empty, the agent clones the repo into it.

Clones are ephemeral, and that's acceptable. Every capture layer sends
its data off the pod, so losing a pod loses only uncommitted work. A
specialist's job ends in a pushed branch.

Credentials reach pods only through Kubernetes Secrets that
`scripts/render.py` renders from the agent yaml and the agent's base
Secret. Credentials never touch this repo.
[The credential Secret](operations.md#the-credential-secret) lists the
keys.

We size pod requests (250m/512Mi) against the node's allocatable CPU
and memory. The lesson behind this: overcommitted limits plus one heavy
session pushed the node into a kernel out-of-memory (OOM) cascade that
stopped three agents at once. The kernel's OOM response sends SIGKILL
to PID 1, so transcript flushes never run, and the `emptyDir`
workspaces are reclaimed. Staggered pod starts and requests sized to
real use are the mitigation.

## Capture

Agent work is the product's own training data. Each pod
re-establishes all four sediment capture layers:

| layer | mechanism |
|---|---|
| completions | a LiteLLM callback on success; all model traffic goes through the gateway |
| decisions | the pi shim sends one OTel log record per edit tool call to the sediment API, tagged `user.id=agent:<role>` |
| attribution | the pi shim marks each edit, and the stamper's git hooks, baked into the image's home directory, self-install in each clone |
| edit survival | the pi shim extracts the session transcript at task end and posts its edit-outcome pairs to the ingest endpoint |

Three layers ride the gateway or the shim and need nothing from this
repo. Edit survival is ours. It's also the one that fails silently.

Edit survival is the signal that says whether an agent's edit lasted.
Without it, a trajectory is a transcript rather than a labeled example.

Two mechanisms ship it, and the difference matters:

- **At task end.** `SEDIMENT_EXTRACT_ON_SETTLE` in
  `manifests/pod.tmpl.yaml` makes the shim extract when pi settles a
  run. This is the primary mechanism. It's safe here only because one
  session means one task in this fleet. On an interactive laptop,
  "settled" isn't "finished". The server keeps only the first write of
  each edit-outcome pair, so an early extraction would lock in a
  half-done answer.
- **At container stop.** `image/entrypoint.sh` traps SIGTERM and SIGINT
  and sweeps every `~/.pi/agent/sessions/**.jsonl` through the
  extractor. This is a **backstop**, not the primary mechanism.

The settle variable exists so that nothing relies on the backstop
alone. The backstop fails in three ways:

- It lands the data when the pod next restarts, hours or days after
  the work.
- It runs nothing when the pod receives SIGKILL, which is what the
  kernel sends when the node runs out of memory. The transcripts
  disappear with the `emptyDir`.
- It reads each edited file at sweep time. Days of unrelated change
  then score as the agent's edit failing to survive.

Shipping twice is harmless. The server deduplicates on
`(org, source, session, call_id)` and keeps the first write.

To check that a run landed, see
[Verify it worked](https://github.com/sediment-ai/sediment/blob/main/docs/capture/transcript-survival.md#verify-it-worked)
in the sediment docs. If a session has decisions but zero edit
outcomes, its edit survival didn't ship.

Each agent also sets `ANTHROPIC_CUSTOM_HEADERS=x-sediment-agent: <role>`
so that completions carry the agent identity. Sediment derives
per-agent spend from its corpus, not from the gateway.

Verify an agent with an edit task, not a read. A read-only session
yields zero decisions by design, which looks like a broken pipeline. An
agent passes when it produces one completion, one decision, one git
note, and one transcript, all tagged `agent:<role>`.

## Delegation

The conductor files an issue, adds the `ready-for-agent` and
`agent:<role>` labels, and then mentions that specialist in the
specialist's Buzz channel. Specialists answer only their own channel.
They report back in that channel rather than @-mentioning each other,
so agents can't trigger each other in a loop.

A specialist that meets another package's code, a schema question, or
a statistics judgment stops. It posts `blocked: <reason>` in its
channel and downgrades the issue to `needs-info`.

## Guardrails

- No agent merges, force-pushes, edits branch protection, or re-runs CI.
  The owner approves every merge personally.
- Each agent's yaml sets its own `idle_timeout` and
  `max_turn_duration`, which caps runaway cost.

## Known limits

- The Buzz app can't fetch a remote agent's logs. The provider protocol
  has no log fetch. Cluster log shipping fills the gap.
- Liveness comes from relay presence. It can be wrong for up to three
  minutes after a pod exits abnormally. The relay runs as its own
  compose project on the cluster host, and this repo doesn't deploy it.
  [Relay](operations.md#relay) covers its topology, health endpoints,
  and upgrade path.
- Configuration edits to a running remote agent apply on its next exit.
- Saving config in the Buzz app doesn't redeploy the agent
  ([buzz#2798](https://github.com/block/buzz/issues/2798)). That's one
  of the reasons we manage the fleet as code in this repo.
- `pi-acp` sends no liveness pings, so idle timeouts must outlast quiet
  stretches in a subprocess. A long `uv sync` looks like a hang.
- Uncommitted work disappears with its pod. Buzz's Kubernetes backend
  supports no persistent volumes. Its
  `buzz-backend-kubernetes/src/pod.rs` hardcodes one `emptyDir`
  workspace, and a test asserts that the pod has no
  PersistentVolumeClaim. So each workspace is ephemeral by
  construction. We accept that, because a specialist's job ends in a
  pushed branch.

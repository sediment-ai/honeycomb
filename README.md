# honeycomb

[![License: MIT][badge-license]](LICENSE)
[![Runs on Buzz][badge-buzz]](https://github.com/block/buzz)
[![Harness: pi][badge-pi]](https://github.com/earendil-works/pi)
[![Kubernetes: k3d][badge-k3d]](https://k3d.io)
[![Gateway: LiteLLM][badge-litellm]](https://github.com/BerriAI/litellm)
[![Captured by sediment][badge-sediment]](https://github.com/sediment-ai/sediment)

An AI agent fleet, as code. Seven [Buzz](https://github.com/block/buzz)
agents build [sediment](https://github.com/sediment-ai/sediment), and
sediment captures what they do.

## How it works

- **An agent is a file.** `agents/<role>.yaml` sets the harness, model,
  pool size, and timeouts. `agents/prompts/<role>.md` holds the system
  prompt.
- **One command converges the fleet.** `scripts/apply.sh` renders every
  agent and recreates only the pods that drift, one at a time.
- **Credentials stay in the cluster.** Each render merges the yaml with
  the agent's live Kubernetes Secret, so no key touches the repo.
- **Models swap at the gateway.** Each `model_id` names a model. A
  LiteLLM gateway routes it to a provider.
- **Sediment captures the work.** Completions, decisions, commit
  attribution, and edit survival flow from every agent into sediment.

A conductor triages incoming work and routes it to six specialists:
capture, derive, export, api, docs, and harness. Each specialist owns
one beat and one channel. Tasks travel as GitHub issues. The owner
approves every merge.

## Why fleet-as-code

Buzz can't edit a deployed agent's Kubernetes config
([buzz#2798](https://github.com/block/buzz/issues/2798)). Every change
means recreating the agent by hand. With honeycomb, a change is one
reviewed PR and one run of `scripts/apply.sh`.

## Layout

```
agents/      one yaml per agent, with system prompts in agents/prompts/
image/       the agent image: pi harness, capture stack, git, gh, uv
manifests/   the pod template
relay/       the cluster host's relay config
scripts/     render, apply, build-image, sync-records, diff-relay
docs/        design, operations, and onboarding
```

## Docs

- [Agent fleet — design](docs/fleet-design.md) — why the fleet is
  shaped this way.
- [Operate the fleet](docs/operations.md) — stand up an agent, manage
  credentials and models, ship releases, and run the relay.
- [Getting started](docs/getting-started.md) — how members of our team
  connect to the fleet.

## License

[MIT](LICENSE)

[badge-license]: https://img.shields.io/badge/license-MIT-3DA639
[badge-buzz]: https://img.shields.io/badge/runs_on-Buzz-7C3AED
[badge-pi]: https://img.shields.io/badge/harness-pi-F97316
[badge-k3d]: https://img.shields.io/badge/Kubernetes-k3d-326CE5?logo=kubernetes&logoColor=white
[badge-litellm]: https://img.shields.io/badge/gateway-LiteLLM-0D9488
[badge-sediment]: https://img.shields.io/badge/captured_by-sediment-F13D4F?labelColor=111111&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNTI5IDE1MjkiPjxwYXRoIGZpbGw9IiNGMTNENEYiIGQ9Ik0xNDEyIDEwMTJMMTI1NCA4NTRDMTIzMiA4MzIgMTIxOCA4MDMgMTIxNiA3NzNDMTIxNCA3MzcgMTIyNyA3MDMgMTI1MiA2NzhMMTI3MiA2NThDMTI4NyA2NDMgMTMxMiA2NDMgMTMyNiA2NThDMTM1NiA2ODggMTM3MyA3MjYgMTM3MiA3NjhDMTM3MiA3ODAgMTM3MCA3OTMgMTM2NiA4MDVDMTM2MyA4MTYgMTM2NiA4MjggMTM3NCA4MzZMMTQ1OSA5MjFDMTQ2OCA5MzAgMTQ4NSA5MjggMTQ5MiA5MTZDMTUxOSA4NzAgMTUzMyA4MTYgMTUzMiA3NjFDMTUzMSA2ODAgMTQ5NiA2MDIgMTQzOCA1NDRMMTE1NSAyNjBDMTEzOSAyNDQgMTEzOSAyMjAgMTE1NSAyMDVMMTE2MyAxOTdDMTIxNiAxNDQgMTMwNCAxNTEgMTM0OCAyMTVDMTM1OCAyMzAgMTM2NiAyNDcgMTM2OCAyNjVDMTM3MCAyNzggMTM2NyAyOTggMTM2NCAzMTJDMTM2MiAzMjIgMTM2NiAzMzMgMTM3MyAzNDFMMTQ2MCA0MjZDMTQ3MCA0MzYgMTQ4NyA0MzQgMTQ5NCA0MjJDMTUxOCAzODAgMTUzMSAzMzIgMTUzMSAyODNDMTUzMSAyMDggMTUwMSAxMzcgMTQ0OSA4NEMxMzM4IC0yNiAxMTYwIC0yNiAxMDUwIDg0TDg1NCAyODBDODA2IDMyOCA3MjggMzI4IDY4MCAyODBMNjYwIDI2MUM2NDUgMjQ2IDY0NSAyMjEgNjYwIDIwNkw2NjMgMjAzQzY5MiAxNzUgNzMwIDE2MCA3NjggMTYwQzc4MSAxNjAgNzk1IDE2MiA4MDggMTY2QzgxOSAxNjkgODMwIDE2NiA4MzggMTU4TDkyMyA3NEM5MzMgNjQgOTMwIDQ3IDkxOCA0MEM4MDEgLTI1IDY0OSAtOSA1NDkgOTFMNTE5IDEyMUw0MDYgMjMzTDM0MCAyOTlMMjYyIDM3N0MyNDcgMzkyIDIyMiAzOTIgMjA4IDM3N0wyMDAgMzY5QzE3MSAzNDAgMTU4IDMwMSAxNjYgMjYwQzE3MCAyNDQgMTc2IDIyOCAxODYgMjE1QzIwOSAxODEgMjQ2IDE2MiAyODUgMTYyQzI5NSAxNjIgMzA1IDE2MyAzMTQgMTY2QzMyNSAxNjggMzM3IDE2NSAzNDUgMTU4TDQyOSA3M0M0MzkgNjMgNDM3IDQ2IDQyNSAzOUMzODQgMTUgMzM2IDIgMjg2IDJDMjExIDIgMTQwIDMyIDg3IDg0QzM0IDEzNyA0IDIwOCA0IDI4MkM0IDM1NyAzMyA0MjggODYgNDgxTDI4MiA2NzdDMzMwIDcyNSAzMzAgODAzIDI4MiA4NTFMMjYyIDg3MUMyNDcgODg2IDIyMiA4ODYgMjA4IDg3MUwyMDUgODY4QzE2NiA4MjkgMTUzIDc3NCAxNjcgNzIzQzE3MCA3MTIgMTY3IDcwMCAxNTkgNjkyTDc0IDYwOUM2NCA1OTkgNDYgNjAxIDQwIDYxNEMtMjYgNzMxIC05IDg4MiA5MSA5ODJMMjM0IDExMjZMMzAwIDExOTJMMzc4IDEyNjlDMzkzIDEyODQgMzkzIDEzMDkgMzc4IDEzMjRMMzcwIDEzMzJDMzQxIDEzNjAgMzAyIDEzNzIgMjYyIDEzNjZDMjQ1IDEzNjIgMjMwIDEzNTYgMjE2IDEzNDZDMTcyIDEzMTYgMTU1IDEyNjQgMTY2IDEyMThDMTY5IDEyMDggMTY2IDExOTYgMTU4IDExODhMNzQgMTEwM0M2NCAxMDk0IDQ3IDEwOTYgNDAgMTEwOEMtMjEgMTIxNSAtNiAxMzU0IDg1IDE0NDZDMTM5IDE0OTkgMjEwIDE1MjggMjg0IDE1MjhDMzIyIDE1MjggMzU4IDE1MjEgMzkyIDE1MDZDNDI2IDE0OTIgNDU3IDE0NzIgNDgzIDE0NDVMNjc3IDEyNTFDNzAxIDEyMjcgNzMyIDEyMTMgNzY2IDEyMTNDNzk5IDEyMTMgODMwIDEyMjYgODUzIDEyNDlMODczIDEyNjhDODg4IDEyODQgODg4IDEzMDggODczIDEzMjNDODQzIDEzNTMgODA1IDEzNjkgNzYzIDEzNjlDNzUwIDEzNjkgNzM4IDEzNjcgNzI2IDEzNjNDNzE1IDEzNjAgNzAzIDEzNjMgNjk0IDEzNzFMNjEwIDE0NTZDNjAxIDE0NjUgNjAzIDE0ODIgNjE1IDE0ODlDNjYxIDE1MTYgNzE1IDE1MzAgNzcwIDE1MjlDODUxIDE1MjggOTI5IDE0OTMgOTg3IDE0MzVMMTI3MCAxMTUyQzEyODYgMTEzNyAxMzEwIDExMzcgMTMyNSAxMTUyTDEzMzEgMTE1OEMxMzc5IDEyMDYgMTM4MSAxMjg0IDEzMzMgMTMzMUMxMzEwIDEzNTQgMTI4MCAxMzY3IDEyNDggMTM2N0MxMjM4IDEzNjcgMTIyOSAxMzY2IDEyMTkgMTM2M0MxMjA5IDEzNjEgMTE5NyAxMzY0IDExODkgMTM3MUwxMTA0IDE0NTZDMTA5NCAxNDY2IDEwOTcgMTQ4MyAxMTA5IDE0OTBDMTIxNiAxNTUxIDEzNTUgMTUzNiAxNDQ2IDE0NDRDMTU1NiAxMzM1IDE1NTYgMTE1NiAxNDQ2IDEwNDdMMTQxMiAxMDEyWk0xMDYyIDExMzdDMTAzNiAxMTYzIDk5NCAxMTYzIDk2OCAxMTM3QzkxNCAxMDgzIDg0MyAxMDU0IDc2NyAxMDU0QzY5MSAxMDU0IDYyMCAxMDgzIDU2NiAxMTM3QzU0MCAxMTYzIDQ5OCAxMTYzIDQ3MiAxMTM3TDM5NSAxMDYwQzM2OSAxMDM0IDM2OSA5OTIgMzk1IDk2NkM1MDYgODU1IDUwNiA2NzUgMzk1IDU2NEMzNjkgNTM4IDM2OSA0OTYgMzk1IDQ3MEw0NzIgMzkzQzQ5OCAzNjcgNTQwIDM2NyA1NjYgMzkzQzY3NyA1MDQgODU3IDUwNCA5NjggMzkzQzk5NCAzNjcgMTAzNiAzNjcgMTA2MiAzOTNMMTEzOSA0NzBDMTE2NSA0OTYgMTE2NSA1MzggMTEzOSA1NjRDMTA4NSA2MTggMTA1NiA2ODkgMTA1NiA3NjVDMTA1NiA4NDEgMTA4NSA5MTIgMTEzOSA5NjZDMTE2NSA5OTIgMTE2NSAxMDM0IDExMzkgMTA2MEwxMDYyIDExMzdaIi8+PC9zdmc+

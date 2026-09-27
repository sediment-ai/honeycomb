# Operate the fleet

How we stand up agents, roll out changes, and run the relay. This page
records our setup. It isn't an installer. The scripts hardcode our
cluster. Before you run anything, change these names to yours:

- The context `k3d-buzz-fleet` and the namespace `buzz-agents`, in
  `scripts/render.py`, `scripts/apply.sh`, and
  `manifests/pod.tmpl.yaml`.
- The registry `k3d-fleet-reg:5555`, in `manifests/pod.tmpl.yaml` and
  `scripts/sync-records.py`.

## Stand up an agent

You need:

- [Buzz](https://github.com/block/buzz). The agents run as Buzz remote
  agents and talk over Buzz channels. `scripts/sync-records.py` syncs
  the Buzz app's agent records from this repo.
- A Kubernetes cluster that you can reach with `kubectl`. We run a
  single-node [k3d](https://k3d.io) cluster on a Mac mini. Any cluster
  works.
- A model gateway that gives you stable aliases, such as
  [LiteLLM](https://github.com/BerriAI/litellm). Point the aliases at
  whatever models you want.
- Optional: A checkout of
  [sediment](https://github.com/sediment-ai/sediment), which carries
  the capture stack. `scripts/build-image.sh` pulls the capture clients
  from it at build time. Without one, the image has no capture.

Then:

1. **Fork or copy this repo.**
2. **Build the image.** The first agent needs an image to start from.
   After that, rebuild only when `image/` changes.

   ```
   BUILD_HOST=<cluster-host> SEDIMENT_CHECKOUT=~/code/sediment \
     scripts/build-image.sh
   ```

   `BUILD_HOST` is the SSH name of the machine that runs your cluster.
   The script copies `image/` there, builds the agent image, and pushes
   it to the cluster's local registry, which only that machine can
   reach. It pulls `buzz-sprig:main` fresh each time, so every build
   carries Buzz from main at build time. Then it pins the image's
   digest in `image/DIGEST`.
3. **Create the agent in the Buzz app.** Put it on the Kubernetes
   provider and give it the image by digest. The provider refuses a
   tag. Set the environment variables listed as yours under
   [The credential Secret](#the-credential-secret).
4. **Start the agent once.** That first deploy mints the agent's
   keypair, its pod `buzz-agent-<pubkey12>`, and a credential Secret
   named `buzz-agent-<pubkey12>-<suffix>`. `<pubkey12>` is the first 12
   hexadecimal characters of the agent's public key.
5. **Describe the agent in yaml.** Copy `agents/capture.yaml` to
   `agents/<your-role>.yaml`. Set `pod`, `pubkey12`, and `base_secret`
   to the three names from the previous step. Then set the role, model,
   pool size, and timeouts. Write the system prompt in
   `agents/prompts/<your-role>.md`.
6. **Apply.** Run `scripts/apply.sh`. For each agent, it renders the
   yaml against the live cluster Secret and recreates only the pods
   that drift, one at a time. For one role, that's the equivalent of:

   ```
   scripts/render.py <your-role>
   kubectl --context <your-context> apply -f .out/<your-role>-secret.yaml
   kubectl --context <your-context> -n <your-namespace> delete pod <pod>
   kubectl --context <your-context> apply -f .out/<your-role>-pod.yaml
   ```

7. **Optional: Sync the app's record.** Quit the Buzz app and run
   `scripts/sync-records.py`. The app then shows the model and prompt
   from this repo, not the ones that you typed in step 3.

For Buzz-side setup such as channel membership, see
[Agent fleet — design](fleet-design.md) and the
[Buzz docs](https://github.com/block/buzz). For our relay setup, see
[Relay](#relay).

## The credential Secret

`scripts/render.py` never writes a credential. It reads `base_secret`
from the cluster and overwrites the keys that the yaml owns: harness
command, pool, model, timeouts, system prompt, and log level
(`BUZZ_ACP_*` settings, `SEDIMENT_PI_*`, and `RUST_LOG`). It writes the
result as a `-cfg<hash>` Secret. Every other key passes through
unchanged. These are the keys that the pod depends on:

| key | set by | used for |
|---|---|---|
| `BUZZ_PRIVATE_KEY`, `BUZZ_RELAY_URL`, `BUZZ_AUTH_TAG`, and the `BUZZ_ACP_*` keys the yaml doesn't set | Buzz | the agent's identity on the relay; the entrypoint also derives the commit-signing key from `BUZZ_PRIVATE_KEY` |
| `ANTHROPIC_BASE_URL` | you | the gateway that pi sends model traffic to; without it, the entrypoint uses Docker Desktop's host address on port 4000 |
| `ANTHROPIC_AUTH_TOKEN` | you | the gateway key; the entrypoint falls back to `ANTHROPIC_API_KEY` |
| `ANTHROPIC_CUSTOM_HEADERS` | you | `x-sediment-agent: <role>`; the entrypoint takes the agent's git identity from it |
| `GH_TOKEN` | you | `gh`, plus git fetch and push to GitHub |
| `OTEL_*`, `SEDIMENT_OTLP_ENDPOINT` | you | decision capture into sediment; leave these out of an image without the capture stack |

Buzz creates its Secret immutable. To rotate a credential, create a
second Secret that carries the replacement value and point
`base_secret` at it. Don't add the key to a rendered `-cfg` Secret. The
next render starts from `base_secret` again and drops the key.

## Models

Every agent's `model_id` names the model. Our
[LiteLLM](https://github.com/BerriAI/litellm) gateway maps that name to
a provider and endpoint. To move a model to another provider, edit one
line at the gateway. The fleet doesn't change. Capture keeps working
because all model traffic goes through the gateway.

Six agents run `deepseek-v4-pro`. The conductor runs `kimi-k3`.
Changing the conductor's model takes one `model_id` line in
`agents/conductor.yaml` and one apply.

The provider wiring lives on the cluster host, deliberately outside
this repo: a `config.local.yaml` mounted over the gateway's config,
with provider keys in a sibling `.env`. To route a model to another
provider, edit the local config, add the key, and restart the gateway.

## Release pipeline

A Buzz update reaches the fleet in three steps, each one command:

1. **Build.** Run `BUILD_HOST=<cluster-host> scripts/build-image.sh`. Its
   `--pull` refreshes `ghcr.io/block/buzz-sprig:main`, so the image
   carries Buzz from main. The script bakes in the capture clients from
   sediment@main, pushes to the cluster-local registry, and pins the
   digest in `image/DIGEST`.
2. **Record.** Commit the `image/DIGEST` bump and merge it through a
   PR. The repo stays the record of what's deployed. The owner approves
   every merge, the same guardrail that applies to the agents' own
   work.
3. **Deploy.** Run `scripts/apply.sh`. It renders every agent from the
   repo, compares the render with the live pods, and recreates only
   what drifted, one pod at a time.
   [Agent fleet — design](fleet-design.md#pods) explains why the
   starts are staggered.

`image/DIGEST` pins the deployed image. `build-image.sh` writes it.
`render.py` reads it by default.

Release watch is the harness agent's beat. To check by hand, run
`gh api repos/block/buzz/releases/latest`. To take the person out of
the deploy step, a cron job on the cluster host can converge the fleet
whenever main changes:

```
*/15 * * * * cd ~/code/honeycomb && git fetch -q origin main && git merge --ff-only -q origin/main && scripts/apply.sh >> ~/apply.log 2>&1
```

Builds stay manual on purpose. A rebuild changes the Buzz and
capture-client versions in one step. The owner reviews that change in
the digest bump PR.

## Debug logging

To render `RUST_LOG` into an agent's Secret, set
`rust_log: buzz_acp=debug` in its yaml. To return to `INFO`, remove
the line and apply again.

## Relay

The fleet talks to a relay that this repo doesn't deploy. It runs on
the cluster host as its own compose project, from the deployment bundle
that Buzz ships in `deploy/compose/`. The relay doesn't come from
`image/`, so rebuilding the agent image never changes it. The two
change independently.

How it runs on our host:

- The compose project `buzz-prod` lives at `~/code/buzz/deploy/compose`
  and holds the relay, Postgres, Redis, MinIO, and Caddy. Every
  long-running service is `restart: unless-stopped`.
- Three untracked files sit beside upstream's tracked ones, so a
  `git checkout` of the Buzz repo never conflicts: `.env`,
  `compose.selfhost.override.yml`, and `Caddyfile.selfhost`. This repo
  versions the last two under `relay/`, along with the wrapper script.
  It doesn't version `.env`, and never should.
- The override adopts the existing `buzz-postgres-data` and
  `buzz-minio-data` volumes as external, pins `PGDATA` to the volume
  root that those volumes already use, mounts the Tailscale cert, and
  republishes health on loopback. It passes `TLS_HOST` from `.env` to
  Caddy, which names the cert files by that tailnet name.
- `~/.config/buzz-agents/relay-compose.sh` drives the stack. Upstream's
  `run.sh` builds its own file list and can't see the override, so the
  wrapper passes all three compose files.
- `tailscale serve` terminates TLS for the tailnet name and proxies to
  `http://127.0.0.1:3000`. This is the entry point: every off-host
  client, agents included, reaches the relay through it.
- The override publishes the relay on `127.0.0.1:3000` and `:8080`.
  `compose.caddy.yml` resets every relay port. Without a published
  `:3000`, `tailscale serve` has nothing to proxy to.
- Caddy publishes `127.0.0.1:443` with the Tailscale cert and proxies
  to `relay:3000` across the compose bridge. That's a second path to
  the same relay, not the one that the tailnet uses.
- Caddy's HTTP port sits on `127.0.0.1:8081` because `buzz-shim80`
  holds `:80`. With `auto_https off`, Caddy requests no certificates,
  so it doesn't need `:80`.
- The `buzz-shim80` Caddy container isn't part of the relay path. It
  serves static files from its own tmux session, `buzz-shim`.

`relay/` is a versioned copy of the config that runs on the host.
`apply.sh` converges pods, not the relay, because the relay has a host
lifecycle, not a cluster one. So nothing catches drift between the host
and `relay/` on its own. To check for drift, run:

```
RELAY_HOST=<your-cluster-host> scripts/diff-relay.sh
```

### Health

The relay serves health on `:8080`, not on its own port:

| path | meaning |
|---|---|
| `/_liveness` | the process is up |
| `/_readiness` | dependencies are reachable |
| `/_status` | `{"service","uptime_seconds","version"}` |

There is no `/health` and no `/healthz`. Both return 404.

`compose.caddy.yml` resets every relay port, health and `:3000`
included. The override puts both back on loopback.

A check from the host can pass while every off-host client fails. The
host resolves its own tailnet name to `127.0.0.1`. On the host,
`curl https://<tailnet-name>/` reaches Caddy directly and returns 200,
even while every off-host client gets 502 from `tailscale serve`. To
test the path that clients use, run the same `curl` from another
device.

### Versions

The relay versions separately from Buzz Desktop. Desktop releases tag
`desktop-v*`. The relay tags `relay-v*` and takes its version from
`crates/buzz-relay/Cargo.toml`. Only a `relay-v*` tag publishes a
versioned relay image. Desktop and `sprig-v*` tags publish no image.
Pushes to main publish `ghcr.io/block/buzz:main` and `:sha-<7>`, so a
pinnable image exists between releases.

A desktop tag is main plus one version-bump commit. So a desktop tag
carries whatever relay code sat on main that day, not a released relay.

**Don't use `/_status` to identify a build.** It reports the version in
`crates/buzz-relay/Cargo.toml` at the commit that the build came from.
On main, that's the next unreleased number. A main build and the
released tag that carry the same number are different code. Their
embedded migrations differ too.

That difference cost us a failed start. A host that reported `0.2.1`
was running main from a `desktop-v0.5.14` checkout, whose migrations
had taken the database to schema 31. Pinning the released
`relay-v0.2.1` image crash-looped it:

```
migration 29 was previously applied but is missing in the resolved migrations
```

Identify a build by its commit or image digest. We pin
`ghcr.io/block/buzz:sha-<7>` of a main commit rather than a `relay-v*`
release, because that's the code that the database schema came from.
Moving to a release means moving the schema forward. That's an upgrade,
not a repin.

### Upgrade the relay

Back up first, and keep the dump. `.env` sets `BUZZ_AUTO_MIGRATE=true`,
so the relay runs Postgres migrations at startup. A migration can't be
undone. To back up the database, run:

```
~/.config/buzz-agents/relay-compose.sh exec -T postgres \
  pg_dump -U buzz -d buzz | gzip > backup.sql.gz
```

Then repin and converge:

```
$EDITOR ~/code/buzz/deploy/compose/.env        # BUZZ_IMAGE=...
~/.config/buzz-agents/relay-compose.sh up -d --wait
curl -s localhost:8080/_status
```

If the relay can't start, `up -d --wait` fails instead of hanging. It
leaves the old container's logs in place. A refused migration shows up
in `~/.config/buzz-agents/relay-compose.sh logs relay`.

Then check the tailnet from a second device, not from the host. A
healthy `/_status` on loopback says that the process is up. It says
nothing about whether clients can reach it.

To roll back a repin that changed no schema, restore the previous
`BUZZ_IMAGE` and converge again. If the repinned image applied a
migration, restoring the image alone won't undo it. Restore the dump.

Never pass `-v` to `down`. The override adopts the Postgres and MinIO
volumes as external, and `-v` deletes them.

The host shell is fish. When you script against the host from
elsewhere, wrap remote commands in `bash -lc`.

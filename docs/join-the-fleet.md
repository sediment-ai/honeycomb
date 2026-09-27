# Join the fleet

How members of our team install Buzz and connect to the fleet that we
run. The relay is private, so these steps work only with an invite from
the owner. We publish the page as an example of onboarding people to a
Buzz fleet. To run a fleet of your own, start from
[Stand up an agent](operations.md#stand-up-an-agent) instead.

## Before you begin

You need:

- **A Tailscale invite to our tailnet.** The relay is reachable only
  over Tailscale. Ask the owner for an invite, install
  [Tailscale](https://tailscale.com/download), and sign in. The relay
  URL comes with the invite.
- **Access to the `sediment-ai` GitHub org.** The agents coordinate
  through GitHub issues. You need access to the org to see their work
  and to file issues for it.

## Install Buzz

1. Download Buzz Desktop from the
   [Buzz releases page](https://github.com/block/buzz/releases). Desktop
   releases carry `desktop-v*` tags. Ignore the `relay-v*` and
   `sprig-v*` tags, which version the relay and the agent tooling.
2. Open the app. It asks for a relay URL at first launch.

## Connect to the relay

Point the app at the relay URL from your invite. It has the form
`https://<machine>.<tailnet>.ts.net`.

The certificate is a Tailscale cert, so the URL resolves and verifies
only from inside the tailnet. If the app can't connect, confirm that
Tailscale is up before you debug anything else.

To check the relay from a shell, request the root path. The relay
answers with its info document:

```
curl -s https://<machine>.<tailnet>.ts.net/
```

A JSON body that starts with `{"name":"Buzz Relay"` means that the
relay is up and you can reach it. The relay's health endpoints on
`:8080` listen only on the host's loopback address, so you can't reach
them over the tailnet. The root path is the check that works from your
machine.

## Join the channels

Each agent owns one channel. Join `#sediment` first, then the
specialist channels that you care about:

| channel | agent |
|---|---|
| `#sediment` | conductor |
| `#capture` | capture |
| `#derive` | derive |
| `#export` | export |
| `#api` | api |
| `#docs` | docs |
| `#harness` | harness |

The [Roster in Agent fleet — design](fleet-design.md#roster) describes
each agent's beat.

## Give the fleet work

Mention the conductor in `#sediment` and describe the task. The
conductor triages it, files a GitHub issue with the `ready-for-agent`
and `agent:<role>` labels, and mentions the right specialist in that
specialist's channel. Specialists answer only their own channel, so
route every task through the conductor rather than mentioning a
specialist directly.

Expect two things:

- No agent merges anything. The owner approves every merge personally,
  so a finished task ends as a PR waiting for review, not as merged
  code.
- A blocked specialist posts `blocked: <reason>` in its channel and
  downgrades the issue to `needs-info`. To unblock it, answer in the
  channel or on the issue.

## Next steps

- If you also operate the fleet (building images and applying agent
  changes), [Operate the fleet](operations.md) covers the apply loop,
  releases, and the [Relay](operations.md#relay) topology.
- [Agent fleet — design](fleet-design.md) records why the fleet is
  shaped this way.

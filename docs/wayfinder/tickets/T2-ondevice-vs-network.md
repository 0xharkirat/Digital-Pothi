# T2 · AI-follow: on-device vs network

Labels: wayfinder:grilling
Status: closed
Blocked by: —
Assignee: —

## Question

Is the AI live-follow strictly on-device, or may it reach a server?

The app is local-first, but the standing note carves out "the AI-follow
differentiator" as a possible network exception. This is a root architecture
fork: it shapes model delivery (bundle vs download), latency, cost, privacy,
and whether the follow works in a Gurdwara with no/poor internet. Decide the
rule and its rationale.

## Resolution

Resolved 2026-10-19 by Hark's interview. Detail: [../../spec/2026-10-19-v1-sunday-autopilot.md](../../spec/2026-10-19-v1-sunday-autopilot.md).

The follow is strictly on-device at runtime. Only the developer machines use the network: harvesting the YouTube audio, training on the Nitro 5 over Tailscale, and SMB storage. No money is spent on cloud services until the replay test shows success.

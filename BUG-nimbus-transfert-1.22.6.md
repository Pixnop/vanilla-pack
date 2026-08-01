# Nimbus 0.2.0: server transfers are broken on Vintage Story 1.22.6

Every `/server <target>` transfer ends with the destination backend kicking the
player:

```
Account verification failed
Reason: Bad game session, try relogging
```

The player's account and session are fine. The proxy walks them through two
backends and the second one loses the auth race. Full chain below, with logs from
the proxy and both backends.

## Setup

Proxy `Nimbus-v0.2.0.zip`, backends running `Nimbus.ServerMod` 0.2.0 on Vintage
Story 1.22.6 under Stratum, three docker containers on one bridge network. Only
the proxy publishes a port. `ReservationRequired: true` on both backends,
registry embedded in the proxy. Two backends named `survival` and `creative`,
`try = [ "survival" ]`.

## Root cause: the first client frame is not Identification

The proxy assumes the first frame from the client is `Identification` and tries
to pull the PlayerUID out of it. On 1.22.6 the first frame is
`LoginTokenQuery` (Id=33, 16 bytes). `Identification` is frame #2, 128 bytes.

```
warn: [s1] captured Identification frame from first frame (20 bytes) but could not parse PlayerUID, registry-backed transfers disabled for this session
[s1 c->s] frame #1 Id=33(LoginTokenQuery) len=16 comp=0 bytes=08 21 00 00 ...
[s1] ? (172.18.0.1) → survival
[s1 s->c] frame #1 Id=77(TokenAnswer) len=44 comp=0 bytes=D0 05 4D EA 04 26 ...
[s1 c->s] frame #2 Identification len=128 comp=0 bytes=12 6B 0A 06 31 2E 32 32 2E 36 ...
```

The warning fires on every session, including the very first connect. The 20
bytes it "captured" are the LoginTokenQuery frame, not an Identification frame.
Note the proxy itself labels frame #2 as `Identification` a moment later, so the
frame decoder knows the type. Only the capture-the-first-frame shortcut is wrong.

Consequence: `registry-backed transfers disabled for this session`, the session
stays anonymous (`?` in the routing line), and routing falls back to the `try`
list instead of the reservation.

## What that costs: the auth token is single use

The mp token the client presents is consumed by the first backend that validates
it with Anego's auth server. Because the reconnect lands on `survival` first and
only then moves to `creative`, two backends validate the same token one second
apart.

Survival, first to ask:

```
[Server Notification] Client 2 uid cKPrQhZLZmvjjA5dJ9tygNCW attempting identification. Name: Pixnop
[Server Debug] Client uid cKPrQhZLZmvjjA5dJ9tygNCW, mp token iTVPs9s7x4VLqzm8i8gstbtwO58aJkrRkJrJLhyEThA=: Verifying with auth server
[Server Debug] Response from auth server: {"playername":"Pixnop","entitlements":null,"valid":1}
```

Creative, same token, same second:

```
[Server Notification] Client 1 uid cKPrQhZLZmvjjA5dJ9tygNCW attempting identification. Name: Pixnop
[Server Debug] Client uid cKPrQhZLZmvjjA5dJ9tygNCW, mp token iTVPs9s7x4VLqzm8i8gstbtwO58aJkrRkJrJLhyEThA=: Verifying with auth server
[Server Debug] Response from auth server: {"valid":0,"reason":"missingaccount"}
[Server Notification] Client 1 disconnected: Account verification failed / Bad game session, try relogging
```

The proxy's own view of the same moment, showing the useless hop through
survival:

```
[s2] ? (172.18.0.1) → survival
[s2 c->s] frame #2 Identification len=128
[s2] Pixnop: survival → creative (seamless, 1ms)
[s2 s->c] frame #3 Id=9(DisconnectPlayer) len=374
```

## The awkward part

Fixing the parse alone is not obviously enough. The proxy has to pick an upstream
before `Identification` arrives, because the client's very first frame is a
`LoginTokenQuery` that needs a `TokenAnswer` back, and today that answer comes
from a real backend. So identity-based routing needs either the proxy to answer
`LoginTokenQuery` itself, or to hold the client until frame #2 and dial upstream
only then.

Whichever way that goes, a second invariant is worth enforcing on its own: **at
most one backend may validate a given mp token**. Any flow that walks a session
through two backends will hit `missingaccount` on the second, transfers or not.

## Reproducing

Two backends, `try` pointing at the one you are *not* transferring to, connect,
then `/server <other>`. The kick is immediate. Watch
`[Server Debug] Response from auth server` on both backends: the first says
`valid:1`, the second `valid:0, missingaccount`.

Turning on debug logging on the backends is what makes this visible. Without it
you only see the player-facing "Bad game session" and it looks like a client
problem.

## Workaround currently in place

`VerifyPlayerAuth: false` in `serverconfig.json` on the destination backend only.
It survives because every reconnect passes through `survival` first, which does
authenticate, and because `ReservationRequired` still gates the destination with
a proxy-minted HMAC reservation.

This leans on the buggy behaviour to stay safe, so it should be reverted the day
routing goes straight to the destination. It is a test-bench workaround, not a
configuration to recommend.

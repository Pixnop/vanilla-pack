# BlockBreakGuards silently rejects breaking VS Roofing blocks in survival

On `1.22.6-stratum.2`, roof blocks from the
[VS Roofing Mod](https://mods.vintagestory.at/show/mod/30143) cannot be broken in
survival. The client plays the break, then the block reappears. No error reaches
the player, nothing is written to the server log, and no violation is recorded
even with `LogViolations` turned on.

Setting `BlockBreakGuards.Enabled = false` fixes it completely.

## Isolating it

Same 42-mod pack, same Vintage Story 1.22.6, same world config, one variable
changed at a time.

| Server | Result |
| --- | --- |
| Stock 1.22.6 dedicated server | roof breaks normally |
| Stratum 1.22.6-stratum.2 | break reverts, block reappears |
| Stratum, `BlockBreakGuards.Enabled = false` | roof breaks normally |
| Single player, same modpack | roof breaks normally |

Creative mode always works, on every configuration. That is expected: the
instant-break path does not go through the same validation.

## What the block is

`vsroofing.RoofBlock` extends `Block` but its block entity, `AutoRoofEntity`,
derives from `BlockEntityMicroBlock`. A roof is a chiselled block: voxel cuboids
rather than a full cube. Relevant `blocktypes/roof.json` values:

```
resistance    1
BlockMaterial Plant
Tool          hammer
```

`resistance: 1` with a matching tool means the break completes almost
instantly. My guess is that the guard treats a sub-threshold break on a
microblock as suspicious, but I have not read the guard's source, so treat that
as a hypothesis rather than a diagnosis. `MinimumTrackedBreakSeconds` is at its
default `0.15`.

The mod does not override `OnBlockBroken` or `OnBlockRemoved`, so nothing on its
side intercepts the break. Its chisel behaviour, `CollectibleBehaviorRoofChisel`,
only activates when holding an iron, steel or meteoric-iron chisel, which was not
the case here.

## The part that cost the most time

The rejection is invisible. With this in `stratum.json`:

```json
"BlockBreakGuards": { "Enabled": true, "DropViolations": true, "LogViolations": true }
```

breaking a roof block logs **nothing at all**. `LogViolations: true` should
surface a dropped break, and it does not. Whatever the guard decides here, it
does not go through the violation-logging path.

That silence sent us chasing the mod for a long while: land claims, the hammer
check, the `HardLocked` flag, the chisel requirement. All dead ends. A single log
line naming the guard and the block code would have pointed at the answer in
seconds.

So there are arguably two issues: the guard rejecting a legitimate break, and the
rejection being unobservable.

## Environment

Stratum `1.22.6-stratum.2`, Vintage Story 1.22.6, Linux, .NET 10, running in a
container off `mcr.microsoft.com/dotnet/runtime:10.0`. Behind a Nimbus 0.3.0
proxy, though the proxy is not involved: the same failure occurs on a direct
connection, and the vanilla control server was also reached directly.

Anti-cheat was otherwise off in this deployment; `BlockBreakGuards` sits under
`Hardening` and is enabled independently.

## Reproducing

Install VS Roofing 1.7.1, build a frame and add roofing material, switch to
survival, break it. The block comes back. Flip `BlockBreakGuards.Enabled` to
`false` in `stratum.json`, restart, break it again: it works.

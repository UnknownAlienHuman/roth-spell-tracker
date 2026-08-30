# Roth Spell Tracker agent guide

## Start here

Read, in order:

1. [`RothSpellTracker.toc`](RothSpellTracker.toc)
2. [`Core/Config.lua`](Core/Config.lua)
3. [`Core/Util.lua`](Core/Util.lua)
4. [`Core/Core.lua`](Core/Core.lua)
5. [`Modules/Display.lua`](Modules/Display.lua)
6. [`Modules/ManagedAuras.lua`](Modules/ManagedAuras.lua)
7. [`Modules/Tracker.lua`](Modules/Tracker.lua)
8. [`Core/ConfigUI.lua`](Core/ConfigUI.lua)

Target contract:

- Retail / Midnight `12.1.0`;
- Interface `120100`;
- addon version `0.3.0`;
- verified Blizzard source baseline `12.1.0.69497`;
- required Blizzard dependency `Blizzard_AuraContainer`;
- one SavedVariables root, `RothSpellTrackerDB`.

## Non-negotiable 12.1 boundary

AURA tracks are display-only managed AuraContainer consumers. Never restore the former raw scanner.

Forbidden runtime paths include:

```text
UNIT_AURA
C_UnitAuras
UnitAura
AuraUtil.ForEachAura
GetAuraDataByIndex
GetAuraDataByAuraInstanceID
raw AuraData caches
managed AuraButton visibility/alpha/count/frame-count queries
GetChildren / GetNumChildren for aura discovery
```

Each aura track must remain one `CustomAuraContainer` plus one `AddAuraSlot` with an `includeSpellIDs` candidate-filter map. The initialization callback may configure icon/count/cooldown/static child art; after initialization, do not retain or inspect the managed AuraButton.

Blizzard owns aura assignment, visibility, applications, duration, private/restricted state, sorting, refresh events, and candidate evaluation.

## Track schema

Schema v3 uses a stable numeric `uid` for runtime container ownership.

SPELL:

```text
uid, id, kind=SPELL, enabled,
showWhen=ALWAYS|READY|NOTREADY,
ignoreGCD
```

AURA:

```text
uid, id, kind=AURA, enabled,
showWhen=ALWAYS|ACTIVE,
unit=player|target|focus,
auraType=HELPFUL|HARMFUL
```

Do not reintroduce `minStacks` or `INACTIVE`. Missing-only and stack-threshold behavior require observing managed aura state and are not a safe general-purpose 12.1 feature. Migration maps old `INACTIVE` to `ALWAYS` and removes stack thresholds.

## Access-first spell handling

All game-returned spell values go through `Core/Util.lua`:

- `U.CanAccess` before treating a value as ordinary;
- `U.SafeBool`, `SafeNumber`, `SafeString`, `SafeTable` for control-flow data;
- `U.GetSpellName`, `GetSpellIcon`, `IsSpellKnown`, `IsUsableSpell`, `GetSpellCooldown`, `GetSpellCharges` for API boundaries;
- `U.SafeToString` for diagnostics.

Do not call `type`, compare, branch, perform arithmetic, index, format, concatenate, log, cache, or persist a raw game value before the access decision.

`pcall` contains API errors; it does not authorize inspecting returned data.

## GCD rule

A SPELL track may ignore a cooldown only when:

```lua
track.ignoreGCD ~= false and cooldown.isOnGCD == true
```

`isOnGCD` must be an accessible ordinary boolean returned by the wrapper. Duration, start time, specialization, or historical thresholds are not legal substitutes. Unknown classification fails closed as a real cooldown.

## Stable layout and combat

`Modules/Display.lua` reserves one slot for every enabled track in DB order. Dynamic spell readiness and managed aura assignment never compact or reorder slots.

Frame/container creation, managed-slot reconfiguration, anchor changes, sizing, and layout rebuilds must not occur in combat. `Display.pendingRebuild` defers the latest configuration to `PLAYER_REGEN_ENABLED`.

Spell visual regions and glow are precreated during rebuild. Do not create a glow or template on first activation during combat.

AURA `ALWAYS` is implemented with a static dim placeholder behind the managed button. The placeholder never reads managed state. `ACTIVE` simply hides the placeholder; the stable slot remains.

## Module routing

- `Core/Config.lua`: schema/version/defaults only.
- `Core/Util.lua`: access gates and sanitized spell API wrappers.
- `Core/Logging.lua`: bounded 250-line ordinary-text ring.
- `Core/Core.lua`: DB migration/sanitization, lifecycle, slash ownership, reset/rebuild boundary.
- `Core/Minimap.lua`: LDB/DBIcon object only.
- `Core/ConfigUI.lua`: supported track editor and global controls.
- `Modules/Display.lua`: anchor, stable slots, spell visuals, layout/lock/position, combat deferral.
- `Modules/ManagedAuras.lua`: managed container/slot lifecycle and target/focus refresh.
- `Modules/Tracker.lua`: SPELL-only event/evaluation path.

## Slash ownership

Do not restore `/rst`. Roth Secret Tester owns that alias. Valid tracker aliases are:

```text
/rothspelltracker
/rspellt
/spelltracker
```

## Performance invariants

- no permanent `OnUpdate` in tracker code;
- no addon aura event or aura scan;
- no frame-tree scan;
- spell event bursts coalesce to one zero-delay refresh;
- target/focus changes call `UpdateAllAuras` only on matching managed containers;
- no runtime layout compaction based on state;
- DB track count remains capped at 500;
- logger remains a bounded ring.

## Verification

Local checks:

```text
texlua --luaconly Core/*.lua
texlua --luaconly Modules/*.lua
texlua --luaconly tests/*.lua
texlua tests/test_managed_aura_12_1.lua
texlua tests/test_spell_state_12_1.lua
```

Expected results:

```text
PASS: AURA tracks use managed AddAuraSlot sinks without raw aura reads or combat-time frame creation
PASS: SPELL tracks ignore only explicit GCD evidence and fail closed on inaccessible cooldown/charge/usability values
```

Static review must find no raw aura API/event paths in addon runtime and no literal `/rst` registration.

Live-client gates:

- fresh v1/v2/v3 SavedVariables and reload;
- add/edit/remove/reorder SPELL and AURA tracks;
- player/target/focus helpful/harmful relationship combinations;
- target/focus identity changes;
- active/missing aura transitions and count/duration sinks;
- known/unknown/overridden spells, charges, explicit GCD and real cooldowns;
- configuration changes during combat and one post-combat rebuild;
- no taint, forbidden-object, secret-value, repeating error, or performance regression.

Mocked/static success does not prove live managed-template, relationship-filter, or restricted-object behavior. Record the exact build and context for all client evidence.

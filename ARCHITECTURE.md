# Roth Spell Tracker architecture

## Load and ownership

```text
RothSpellTracker.toc
  -> bundled LibStub / CallbackHandler / LibDataBroker / LibDBIcon
  -> Core/Config.lua
  -> Core/Util.lua
  -> Core/Logging.lua
  -> Core/Minimap.lua
  -> Core/ConfigUI.lua
  -> Core/Core.lua
  -> Modules/Display.lua
  -> Modules/ManagedAuras.lua
  -> Modules/Tracker.lua
```

`Blizzard_AuraContainer` is a required Blizzard dependency so `CustomAuraContainerTemplate`, `CustomAuraButtonTemplate`, `AddAuraSlot`, and the public managed display sinks exist before Roth Spell Tracker initializes.

All addon files extend one `NS.Addon` table.

## Persistent state

`Core/Config.lua` defines schema version 3. `Core/Core.lua` is the sole SavedVariables migration and sanitization owner.

Each track has a durable numeric `uid` separate from spell ID. This allows one managed container to be reconfigured without creating a new container for every edit.

SPELL fields:

```text
uid, id, kind=SPELL, enabled,
showWhen=ALWAYS|READY|NOTREADY,
ignoreGCD
```

AURA fields:

```text
uid, id, kind=AURA, enabled,
showWhen=ALWAYS|ACTIVE,
unit=player|target|focus,
auraType=HELPFUL|HARMFUL
```

Schema migration assigns stable UIDs, removes `minStacks`, and maps unsafe/unsupported AURA `INACTIVE` state to `ALWAYS`. Track count is capped at 500. Unknown schemas reset while preserving bounded minimap and frame settings.

## Access boundary

`Core/Util.lua` owns game-value access decisions.

- `CanAccess` is called before treating game-returned values as ordinary Lua data.
- `SafeBool`, `SafeNumber`, `SafeString`, and `SafeTable` reject inaccessible or secret values.
- spell name, icon, known, usable, cooldown, and charge wrappers return bounded ordinary primitives/tables only;
- logger input is converted through `SafeToString` and never stringifies raw inaccessible values.

`pcall` contains API errors but is not treated as permission or declassification.

## Stable layout

`Modules/Display.lua` owns `RothSpellTrackerAnchor`, persistent position, lock state, stable track slots, spell visual children, and layout.

Every enabled track reserves a slot according to SavedVariables order. Runtime readiness or aura assignment can hide only the child presentation inside that slot; it never changes slot count, position, or ordering. This prevents managed aura visibility from becoming a layout side channel.

Spell icon, cooldown, count, border, and glow regions are created during an out-of-combat rebuild. They are not created on first activation.

Configuration changes that require frame/container creation or geometry mutation set `pendingRebuild` during combat. `PLAYER_REGEN_ENABLED` performs one rebuild using current DB state.

## Managed AURA tracks

`Modules/ManagedAuras.lua` owns one `CustomAuraContainer` per durable aura-track UID. Each container owns exactly one slot key, `track`.

Creation sequence:

```text
addon-owned stable slot
  -> CustomAuraContainerTemplate
  -> SetUnit(player|target|focus)
  -> AddAuraSlot("track", HELPFUL|HARMFUL, options)
       candidateFilters.includeSpellIDs[spellID] = true
       initializeFrame(button)
         -> icon Texture + SetIcon
         -> count FontString + SetApplicationCount
         -> Cooldown + SetDurationCooldown
         -> static addon glow child
  -> SetEnabled(true)
```

The initialization callback configures display sinks before Blizzard applies managed access restrictions. The addon does not retain or query the returned AuraButton.

Container reconfiguration uses only public inbound methods:

- `SetUnit`;
- `SetAuraSlotFilterString`;
- `SetAuraSlotCandidateFilters`;
- `SetEnabled`;
- `UpdateAllAuras` for explicit target/focus identity changes.

The module does not register `UNIT_AURA` and does not call raw aura APIs. Blizzard's managed container owns aura events, data, assignment, visibility, count, duration, and secrecy.

AURA `ALWAYS` uses an addon-owned static placeholder behind the managed button. The placeholder never reacts to or queries managed state. `ACTIVE` hides that placeholder. The slot itself remains reserved in both modes.

## SPELL tracks

`Modules/Tracker.lua` listens only to spell/talent/world readiness events. It has no aura event or aura cache.

SPELL evaluation:

1. accessible known predicate;
2. accessible usability predicate;
3. accessible charge data when complete;
4. accessible cooldown data;
5. ignore cooldown only when accessible `isOnGCD == true` and `ignoreGCD` is enabled;
6. unknown GCD classification fails closed as a real cooldown.

A duration threshold is never used as proof that a cooldown is the GCD.

`Tracker:RequestRefresh` coalesces spell bursts with one zero-delay callback. It updates only already-created spell visuals. Frame/container creation remains the Display rebuild owner's responsibility.

## Configuration UI

`Core/ConfigUI.lua` is the only track editor. It exposes supported schema fields only. There is no AURA stack threshold or missing-only mode. Global size and spacing controls use `UISliderTemplate`.

Saving, deleting, enabling, or reordering a track calls the single `Addon:RequestRebuild` boundary.

## Slash ownership

Roth Secret Tester owns `/rst`. Roth Spell Tracker registers only:

```text
/rothspelltracker
/rspellt
/spelltracker
```

## Evidence boundary

The two local Lua regressions prove managed slot construction/reconfiguration and explicit-GCD/accessibility behavior against mocks. They do not prove live template availability, spell-filter relationship rules, secure restrictions, taint behavior, or visual output. Those require exact-build client evidence.

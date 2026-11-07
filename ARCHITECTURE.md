# Roth Spell Tracker architecture

## Runtime owners

| Owner | Responsibility |
|---|---|
| `Core/Config.lua` | version, defaults and hard input/identity bounds |
| `Core/Util.lua` | access gates, spellbook contract, override resolution and sanitized spell structures |
| `Core/Core.lua` | migration, canonicalization, forward-version guard, UID allocation, lifecycle and slash commands |
| `Core/Logging.lua` | bounded diagnostics and visible notifications |
| `Core/ConfigUI.lua` | track mutation UI, virtualized ScrollBox and destructive-reset entry point |
| `Modules/Display.lua` | first-slot origin, bounds/layout, cooldown lanes, layering and combat deferral |
| `Modules/ManagedAuras.lua` | managed container/slot configuration only |
| `Modules/Tracker.lua` | SPELL identity cache, event arbitration, GCD evidence and readiness state |

There is one SavedVariables root: `RothSpellTrackerDB`.

## Access boundary

`canaccessvalue` gates scalar identity and `canaccesstable` gates table inspection. `issecretvalue` and `issecrettable` classify only. Every consumed field is converted to an ordinary primitive before comparison, arithmetic, formatting, caching or persistence.

An active normal cooldown with inaccessible timing blocks readiness without leaking a radial tuple. An explicitly inactive readable cooldown remains usable even when unused timing is inaccessible. An on-hold cooldown (`isEnabled == false`, therefore `isActive == false`) blocks readiness but remains presentation-inactive. LoC metadata controls presentation only and does not override `C_Spell.IsSpellUsable`.

## Spell identity and knowledge

```text
configured spell ID
  -> C_Spell.GetBaseSpell
  -> C_Spell.GetOverrideSpell
  -> resolved ordinary spell ID
  -> C_SpellBook.IsSpellKnown
```

The resolved ID is cached by track UID plus configured ID. Spellbook, icon, override, shapeshift, talent/spec and world invalidations clear the cache. Deprecated global knowledge functions are fallback-only.

## Persistent identity and migrations

Schema v3 stores an ordered track array. Each active track owns a unique UID in `1..500`; allocation reuses holes after deletion.

```text
SavedVariables root
  -> root/schema access check
  -> bounded migration or forward-version guard
  -> bounded structural sanitization
  -> allowlisted canonical database
```

Migration and sanitization inspect at most 2,000 candidate rows. Legacy spell-ID text is bounded before numeric conversion; enum-like strings are bounded before comparison. V1 aliases use a total deterministic source order before deduplication and the 500-track cap.

Supported schemas are rebuilt into a fresh root containing only known fields and normalized tracks. Unknown nested graphs are not retained accidentally.

### Forward-version transaction

When `savedVersion > DB_VERSION`, the addon does not migrate, sanitize in place or assign a replacement global. It creates a temporary supported session view containing only validated ordinary frame/minimap preferences and leaves `RothSpellTrackerDB` untouched.

```text
newer persistent root
  -> preserved opaque source
  -> session-only supported view
  -> visible warning
  -> explicit confirmed Replace DB action only
```

This prevents an older addon version from destroying newer-schema data on logout. Confirmation is also required for ordinary Reset DB.

## Managed AURA path

```text
stable addon slot
  -> addon-owned CustomAuraContainerTemplate
    -> AddAuraSlot("track", HELPFUL|HARMFUL, options)
      -> Blizzard-managed AuraButton
        -> adopted icon / application-count / duration-cooldown regions
```

All adopted descendants are complete during `initializeFrame`. The managed Cooldown and addon overlay receive explicit frame levels. The addon never retains the AuraButton. Reconfiguration uses only public container setters; setter-owned refresh is not duplicated.

The parent graph is final before `AddAuraSlot` adopts descendants. If internal slot identity is ever violated, the existing graph is disabled and a new graph is created under the new final parent; adopted containers and descendants are never reparented.

## SPELL event and display path

`SPELL_UPDATE_COOLDOWN` captures accessible `isOnGCD` evidence synchronously, keyed by track UID, resolved spell and exact cycle. Full rendering is coalesced. Identity events clear the resolved-ID cache and evidence.

Readiness requires readable known/usability/charge/normal-cooldown state. A multi-charge spell exposes `showCount=true` when `maxCharges > 1`; Display then renders the ordinary current charge value, including zero or one. Charge count and recharge timing remain separate values.

LoC supplies a separate visual lane; `shouldReplaceNormalCooldown` selects whether normal and charge lanes are suppressed.

```text
charge recharge   frame level +1
normal cooldown   frame level +2
loss of control   frame level +3
top overlay       frame level +4
```

Cooldown mutation is protected in 12.1.5. The addon mutates only addon-owned ordinary cooldown widgets and only outside combat. Managed AURA duration remains Blizzard-owned through `SetDurationCooldown`.

## Configuration virtualization

The persistent list may contain 500 tracks, but the dialog uses the current Blizzard ScrollBox stack:

```text
CreateIndexRangeDataProvider(trackCount)
  -> WowScrollBoxList
  -> CreateScrollBoxListLinearView
  -> pooled visible Frame elements
  -> initializer resolves tracks[dataIndex]
```

Frames and scripts are created once per pooled visible element. The provider contains ordinary indexes only. Every click retrieves the frame's current element index and re-resolves the track; row frames and provider elements are not durable identity. Reorder, removal and editing replace the index-range provider while retaining a valid scroll position.

## Layout and combat

The saved position represents the first configured slot. An ordinary origin frame preserves that location while the movable bounding frame grows around the actual slot extent.

- geometry changes call `RequestLayout`;
- track/type/order changes call `RequestRebuild`;
- scale/display changes reapply layout only;
- rebuild never forces a SPELL child visible;
- structural and geometry changes defer in combat and converge after `PLAYER_REGEN_ENABLED`.

## Evidence ceiling

Static, CI and mocked tests prove local control flow and repository invariants. They do not prove named-client template rendering, relationship filtering, target/focus lifecycle, protected-call/taint behavior, LoC timing, ScrollBox interaction, visual correctness or performance.

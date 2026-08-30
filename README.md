# Roth Spell Tracker

Configurable compact tracker for spell readiness and specific player/target/focus auras on World of Warcraft Retail 12.1.

## Compatibility

- Game: World of Warcraft Retail / Midnight 12.1.0
- Interface: `120100`
- Version: `0.3.0`
- Verified Blizzard source baseline: `12.1.0.69497`
- SavedVariables: `RothSpellTrackerDB`
- Required Blizzard addon: `Blizzard_AuraContainer`
- Bundled libraries: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0

## Commands

- `/rothspelltracker`
- `/rspellt`
- `/spelltracker`

The previous `/rst` alias was removed because Roth Secret Tester owns the same alias.

Subcommands: `config`, `debug on|off`, `lock`, `unlock`, `log [N]`, and `reset`.

## Track types

### SPELL

A SPELL track uses accessible `C_Spell` readiness, charge, cooldown, and explicit `isOnGCD` evidence.

- `ALWAYS` — always reserve and render the icon; dim it when unavailable;
- `READY` — show only when ready;
- `NOTREADY` — show only when unavailable;
- `ignoreGCD` ignores a cooldown only when Blizzard returns accessible `isOnGCD == true`.

A short duration is not treated as GCD evidence. Missing or inaccessible classification fails closed as a real cooldown.

### AURA

AURA tracks do not call `UNIT_AURA`, `C_UnitAuras`, `UnitAura`, or maintain raw AuraData caches. Each track owns one Blizzard `CustomAuraContainer` and one `AddAuraSlot` filtered by spell ID.

The managed AuraButton receives only Blizzard-supported display sinks:

- icon;
- application count;
- duration cooldown;
- addon-owned static glow art.

Blizzard owns aura assignment, visibility, duration, stacks, filtering, restricted data, and refresh events.

Supported display modes:

- `ALWAYS` — reserve a stable slot and show a dim static placeholder while the managed aura button is absent;
- `ACTIVE` — reserve a stable blank slot and let the managed aura button appear only when Blizzard assigns the aura.

`INACTIVE` and `minStacks` were removed. Missing-only or stack-threshold decisions require observing managed aura state and are not legal general-purpose 12.1 inputs. Existing `INACTIVE` entries migrate to `ALWAYS`; existing stack thresholds are discarded.

Spell-ID filtering follows Blizzard's own candidate-filter restrictions: helpful spell matching is supported on assistable units, and harmful spell matching on non-assistable units. Unsupported relationship/filter combinations fail through the managed container rather than falling back to raw scans.

## Layout and combat behavior

Every enabled track has a stable reserved slot. Dynamic spell or aura state never compacts or reorders the tracker.

Frame/container creation, reconfiguration, anchor changes, icon sizing, and layout rebuilds are deferred during combat and applied after `PLAYER_REGEN_ENABLED`. Spell visual children and glow textures are created during the out-of-combat rebuild rather than on the first proc.

## Configuration

The configuration window supports add, edit, enable/disable, remove, and reorder operations. AURA entries expose only unit, HELPFUL/HARMFUL, and `ALWAYS`/`ACTIVE`. The obsolete stack field and missing-only mode are absent. Sliders use `UISliderTemplate`, not the retired Options slider template.

## Validation status

Local Lua checks passed for the exact source files prepared for this branch:

```text
texlua --luaconly Core/*.lua Modules/*.lua tests/*.lua
texlua tests/test_managed_aura_12_1.lua
texlua tests/test_spell_state_12_1.lua
```

The managed-aura regression proves one `AddAuraSlot` per track, spell-ID candidate filters, target/focus refresh, stable placeholders, reconfiguration without raw aura APIs, and no frame creation during combat. The spell regression proves explicit-GCD-only suppression and fail-closed behavior for inaccessible usability, cooldown, charges, and GCD classification.

Live Retail testing is still required for actual managed AuraContainer templates, relationship/filter restrictions, target/focus changes, Edit Mode/UI scale, combat transitions, SavedVariables migration, spell replacement/override states, taint, errors, and performance.

## Developer documentation

- [Architecture](ARCHITECTURE.md)
- [Agent guide](AGENT_GUIDE.md)
- [Code index](CODE_INDEX.md)
- [Code graph](CODE_GRAPH.md)
- [WoW addon engineering knowledge base](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb)

## License

Licensed under the [MIT License](LICENSE). Bundled third-party components remain under their own notices.

# Roth Spell Tracker

Compact spell-readiness and managed-aura tracker for World of Warcraft Retail / Midnight 12.1.5.

## Target

- Interface: `120105`
- Addon version: `0.4.4`
- Database schema: `3`
- Reviewed source evidence: `12.1.5.70783` / `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`
- Runtime status: **NOT-RUN** on a named client
- SavedVariables: `RothSpellTrackerDB`
- Required Blizzard addon: `Blizzard_AuraContainer`

## SPELL tracks

SPELL tracks resolve the configured ID through the explicit base/override relationship and use the current `C_SpellBook.IsSpellKnown` contract. Deprecated knowledge globals are compatibility fallbacks only.

Readiness is derived from accessible spell knowledge, `C_Spell.IsSpellUsable`, charge availability and the normal cooldown lane:

- `ALWAYS`: reserve the slot and dim an unavailable spell;
- `READY`: show only when ready;
- `NOTREADY`: show only when unavailable;
- `ignoreGCD`: ignore a cooldown only when `isOnGCD == true` was captured inside `SPELL_UPDATE_COOLDOWN` for the same resolved spell and exact cooldown cycle.

Multi-charge spells display their authoritative current charge count whenever `maxCharges > 1`, including `1` and `0`; the charge-recharge radial remains independent from the ordinary cooldown radial.

Loss-of-control data is presentation metadata, not a second castability oracle. `shouldReplaceNormalCooldown` selects whether the LoC radial replaces normal and charge radials; readiness still comes from the spell APIs above.

Normal cooldown, charge recharge and loss-of-control timing use three independent addon-owned Cooldown frames. Their frame levels are explicit, with count, border and readiness glow in a top overlay. `modRate` and `chargeModRate` are preserved.

Retail 12.1.5 marks Cooldown mutations protected. The addon changes timing only outside combat. A changed stale radial is hidden during combat and reconciled after combat, including the case where desired timing returns to the last successfully applied tuple. A cooldown on hold (`isEnabled == false`, therefore `isActive == false`) still blocks readiness but does not render a false active radial.

## AURA tracks

Each AURA track uses one addon-owned `CustomAuraContainer` and one `AddAuraSlot`. Blizzard owns acquisition, dynamic target/focus lifecycle, assignment, visibility, applications, duration and restricted data.

The addon does **not** register `UNIT_AURA`, call raw aura APIs, inspect managed children, append `UpdateAllAuras()` after public setters or own target/focus aura refresh.

- `ALWAYS`: reserve the slot and show a dim static placeholder while no managed button is assigned;
- `ACTIVE`: reserve a blank slot and show only Blizzard's managed button.

Spell-ID candidate matching is constrained by unit relationship, harmfulness and aura secrecy. Missing-only and stack-threshold decisions remain unavailable because they require managed aura-state readback.

The parent and adopted descendant graph is final when `AddAuraSlot` runs. If an internal slot-identity invariant is ever broken, the old graph is disabled and a fresh graph is created with its final parent; adopted containers or descendants are never reparented.

## Persistence and downgrade safety

The runtime domain is bounded to 500 tracks and UIDs. Migration/sanitization scans at most 2,000 candidate rows, bounds legacy key and enum text lengths, rejects malformed IDs/non-finite values and deterministically selects one canonical legacy record before deduplication.

Supported databases are rebuilt from an allowlist of schema fields, so unknown root, frame, minimap and per-track fields do not remain attached to the persistent graph. A database with a schema newer than this addon is never rewritten automatically. The addon runs from a temporary sanitized session view, shows a warning and preserves the newer SavedVariables root at logout. `Reset DB` / `Replace DB` requires explicit confirmation before replacing persistent data.

Unknown older or malformed schemas fall back to a clean supported database while preserving validated frame and minimap preferences. Removed UIDs are reused.

## Layout, configuration and support

- The first configured slot remains at the saved position while the bounding frame grows RIGHT, LEFT, UP or DOWN.
- Geometry-only changes use `RequestLayout`; structural changes use `RequestRebuild`.
- Scale/display changes reapply current layout without rebuilding containers.
- Structural and geometry mutations defer in combat and converge after `PLAYER_REGEN_ENABLED`.
- The configuration list uses the current virtualized `WowScrollBoxList`/`MinimalScrollBar` stack with an index-range data provider; only visible row frames exist.
- Row scripts are installed once and re-resolve the current ordinary track index on every action.
- The logger is a bounded 250-line ring and `LibDBIcon:Refresh` rebinds minimap settings after database replacement.
- The configuration dialog closes with Escape and surfaces future-schema session-only mode.

## Commands

- `/rothspelltracker`
- `/rspellt`
- `/spelltracker`

Subcommands: `config`, `debug on|off`, `lock`, `unlock`, `log [N]`, `reset`.

`reset` opens a destructive-action confirmation. `/rst` is intentionally not registered because Roth Secret Tester owns it.

## Validation

GitHub Actions executes Lua 5.1 syntax checks for addon, libraries and tests, then runs every deterministic regression:

```text
luac5.1 -p Core/*.lua Modules/*.lua libs/**/*.lua tests/*.lua
lua5.1 tests/test_config_ui_12_1_5.lua
lua5.1 tests/test_database_12_1_5.lua
lua5.1 tests/test_edge_contract_12_1_5.lua
lua5.1 tests/test_managed_aura_12_1.lua
lua5.1 tests/test_repository_contract.lua
lua5.1 tests/test_spell_state_12_1.lua
lua5.1 tests/test_support_12_1_5.lua
```

The harness covers persistence bounds/canonicalization, deterministic migrations, forward-schema preservation, explicit reset confirmation, exact-case TOC paths, current spellbook APIs, authoritative charge counts, override caching, exact-cycle GCD evidence, cooldown/charge/LoC lanes, on-hold cooldown presentation, protected-cooldown recovery, adopted AuraContainer parent invariants, managed-aura ownership, modern virtualized configuration ownership, layout combat deferral, logging and minimap ownership.

Live-client validation remains required for exact build/interface, managed relationship filters, target/focus transitions, LoC timing, protected-call/taint behavior, ScrollBox interaction, visuals, UI scale and profiling.

## Documentation

- [Architecture](ARCHITECTURE.md)
- [Agent guide](AGENT_GUIDE.md)
- [Remaining live gates](todo.md)
- [WoW addon engineering knowledge base](https://github.com/UnknownAlienHuman/wow-addon-engineering-kb)

## License

MIT. Bundled third-party libraries retain their own notices.

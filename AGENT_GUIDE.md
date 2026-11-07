# Roth Spell Tracker agent guide

## Target

- Retail / Midnight `12.1.5`
- Interface `120105`
- addon `0.4.4`
- DB schema `3`
- reviewed source evidence `12.1.5.70783` / `297d7aaaa736f346b3e036f38ee088eaf7f8c07f`
- runtime validation `NOT-RUN`

Read the TOC, then `Core/Config.lua`, `Core/Util.lua`, `Core/Core.lua`, `Modules/Display.lua`, `Modules/ManagedAuras.lua`, `Modules/Tracker.lua`, and `Core/ConfigUI.lua`.

## Hard AURA boundaries

Never add raw aura reads/events, managed AuraButton readback, frame-tree scans, duplicate `UpdateAllAuras()` calls or addon-owned target/focus refresh logic. Keep one `CustomAuraContainer` plus one `AddAuraSlot` per active AURA UID. Construct adopted descendants and final layering during `initializeFrame`. Never reparent an adopted container or descendant; retire an invariant-breaking graph and create a fresh graph with its final parent.

## Access and SPELL rules

- Gate every game value with `canaccessvalue` / `canaccesstable` before use; `pcall` is containment only.
- `C_SpellBook.IsSpellKnown` is primary; deprecated globals are fallback-only.
- Resolve and cache base/override identity; invalidate it on spellbook/override/form/spec/talent/world changes.
- Capture `isOnGCD` only inside `SPELL_UPDATE_COOLDOWN` and match the same resolved spell and exact cycle.
- For `maxCharges > 1`, show the authoritative current count including `0` and `1`; do not conflate count visibility with recharge timing.
- Readiness comes from knowledge, usability, charges and the normal cooldown lane. LoC metadata selects presentation only.
- An on-hold cooldown (`isEnabled == false`, `isActive == false`) blocks readiness but must not produce an active radial tuple.
- Keep `charge < normal < LoC < overlay`; protected cooldown mutation stays outside combat.

## Persistence rule

- Runtime tracks and UIDs are bounded to `1..500`; candidate input is bounded to 2,000 rows.
- Bound legacy key and enum text before conversion/comparison.
- Legacy aliases require a total deterministic order before deduplication and track capping.
- Supported schemas are canonical allowlisted copies; do not retain unknown nested keys by mutating the source in place.
- Never rewrite a SavedVariables root whose schema is newer than `DB_VERSION`.
- A future schema uses a session-only fallback until explicit confirmed replacement.
- Reset/repair is destructive and must pass through `ConfirmResetDB`.

## Configuration UI rule

- Use `WowScrollBoxList`, `MinimalScrollBar`, `CreateScrollBoxListLinearView` and `CreateIndexRangeDataProvider`.
- Do not restore `UIPanelScrollFrameTemplate`, FauxScrollFrame, HybridScrollFrame or one row tree per track.
- Element data is an ordinary track index. Every action calls `GetElementData()` and re-resolves the current track.
- Create row regions/scripts once; the initializer only binds current icon/text/check/button state.
- Row frames, provider elements and scroll positions are runtime presentation state, never persistence identity.

## Lifecycle rule

- Dynamic state never compacts or reorders tracker slots.
- `Display:Init` creates only; Core owns one login rebuild.
- Geometry uses `RequestLayout`; structural changes use `RequestRebuild`.
- No permanent `OnUpdate`, polling ticker, raw payload rebroadcast or duplicate owner.
- Logger, state maps, resolution cache and ScrollBox frame pool remain bounded.

## Verification

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

Do not report runtime PASS without exact client build, addon commit and captured observations. Remaining gates are in `todo.md`.

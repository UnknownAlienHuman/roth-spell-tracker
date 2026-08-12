# RothSpellTracker agent guide

## Start here

Read [`RothSpellTracker.toc`](RothSpellTracker.toc), then [`Core/Config.lua`](Core/Config.lua), [`Core/Core.lua`](Core/Core.lua), [`Modules/Tracker.lua`](Modules/Tracker.lua), and [`Modules/Display.lua`](Modules/Display.lua). The TOC is the dependency contract: vendored libraries first, support/core next, display before tracker last. `libs/LibDBIcon-1.0/lib.xml` exists as a packaging descriptor but is inactive because the root TOC loads `LibDBIcon-1.0.lua` directly.

TOC release metadata is `0.2.1` (`RothSpellTracker.toc`, `## Version`).

## Load order and execution path

The TOC loads `LibStub`, `CallbackHandler-1.0`, `LibDataBroker-1.1`, and `LibDBIcon-1.0`; then `Config.lua`, `Logging.lua`, `Util.lua`, `Minimap.lua`, `ConfigUI.lua`, `Core.lua`; then `Display.lua` and `Tracker.lua`. All files share `NS.Addon`.

Complete `loadedFiles` inventory (root `docs/addon-architecture.json`, in execution order):

```text
libs/LibStub/LibStub.lua
libs/CallbackHandler-1.0/CallbackHandler-1.0.lua
libs/LibDataBroker-1.1/LibDataBroker-1.1.lua
libs/LibDBIcon-1.0/LibDBIcon-1.0.lua
Core/Config.lua
Core/Logging.lua
Core/Util.lua
Core/Minimap.lua
Core/ConfigUI.lua
Core/Core.lua
Modules/Display.lua
Modules/Tracker.lua
```

`Core.lua` listens for `ADDON_LOADED` and `PLAYER_LOGIN`. For the addon load it runs `InitLogger` -> `InitDB` (default copy, v1-to-v2 migration, sanitization) -> `InitMinimapIcon`/`UpdateMinimapIcon` -> registers `/rst`. On login it initializes the display anchor and tracker, then queues a refresh. `Tracker:Refresh` builds only requested aura caches, evaluates SPELL/AURA entries, compacts shown rows, and calls `Display` methods.

## State and surfaces

- SavedVariables: `RothSpellTrackerDB`; schema `DB_VERSION = 2`. v1 `db.spells[spellID]` maps to v2 `db.tracks[]`.
- Persistent fields: `version`, `debug`, `minimap.hide/minimapPos`, `frame.point/relPoint/x/y/size/spacing/locked/grow`, and track entries (`id`, `kind`, `enabled`, `showWhen`, plus spell `ignoreGCD` or aura `unit/auraType/minStacks`).
- Slash commands: `/rst`, `/rst debug on|off`, `/rst lock|unlock`, `/rst log [N]`, `/rst reset`.
- Workspace collision: `RothSecretTester` also registers `/rst` (see the root duplicate-slash index and [tracker issue #2](https://github.com/UnknownAlienHuman/roth-spell-tracker/issues/2)). If both addons are enabled, verify which handler is installed after both `ADDON_LOADED` paths run; do not assume `/rst` is uniquely owned by this addon.
- Minimap: LDB data object `RothSpellTracker`, registered via LibDBIcon; left-click toggles config and right-click locks/unlocks.
- Runtime entry points: `Addon:InitDB`, `Addon:ResetDB`, `Tracker:Init`, `Tracker:RequestRefresh`, `Tracker:Refresh`, `Display:Init`, `Display:SetCount`.

## Dependencies and relationships

All libraries are bundled in `libs/`; there are no TOC external dependencies. The addon consumes Blizzard aura/spell/cooldown APIs and creates its own `RothSpellTrackerAnchor` and pooled icon frames. `Modules/Display.lua` borrows Blizzard spell activation alert templates opportunistically but does not call another checked-in addon. No checked-in addon references RothSpellTracker globals.

Falsification notes: tracker code has no `COMBAT_LOG_EVENT_UNFILTERED` path, no Masque/CDM integration, and no permanent `OnUpdate`; the bundled LibDBIcon drag helper may use a short-lived frame update outside the tracker hot path.

## Change routing

- DB schema/defaults/migration/sanitization: [`Core/Config.lua`](Core/Config.lua), [`Core/Core.lua`](Core/Core.lua); update `DB_VERSION` and migration together.
- Secret-safe API wrappers: [`Core/Util.lua`](Core/Util.lua); keep all control-flow gates behind `SafeBool`, `SafeNumber`, and `CanAccess`.
- Event-driven calculation, aura indexing, GCD/charges rules: [`Modules/Tracker.lua`](Modules/Tracker.lua).
- Frame pool, layout, cooldown, glow, drag/lock: [`Modules/Display.lua`](Modules/Display.lua).
- Track editor and global controls: [`Core/ConfigUI.lua`](Core/ConfigUI.lua); mutate DB then request tracker refresh.
- Logs/minimap: [`Core/Logging.lua`](Core/Logging.lua), [`Core/Minimap.lua`](Core/Minimap.lua).

## Invariants and risks

- The tracker has no permanent `OnUpdate`; every refresh is coalesced with `C_Timer.After(0)`. The bundled `LibDBIcon-1.0` may install its own short-lived drag-helper `OnUpdate`, which is outside the tracker hot path. Do not add per-frame scans to tracker code.
- `UNIT_AURA` is limited to `player`, `target`, and `focus`; aura caches are built only for configured unit/filter combinations.
- Secret booleans/numbers must never be used directly in `if`, arithmetic, or comparisons. Preserve `U.SafeBool`, `U.SafeNumber`, `U.CanAccess`, and `U.SafeSetShown` boundaries.
- Tracker config only accepts `SPELL`/`AURA`, known units, and `HELPFUL`/`HARMFUL`; duplicate `(kind,id)` entries are collapsed by sanitization/UI.
- Moving the anchor is blocked in combat; cooldown/glow frames are addon-owned, but `CreateFrame` with Blizzard alert templates can vary by build.
- Unknown SavedVariables schema is intentionally reset while preserving minimap data; do not silently reinterpret new schema fields.

## Verification

1. Verify TOC load order and every referenced file.
2. Parse Lua and run the repository Markdown/link checks.
3. In-game `/reload`; verify `/rst`, LDB left/right-click, and Settings editor add/edit/remove/reorder.
4. Test AURA entries on player/target/focus with both filters and stack thresholds; test SPELL entries with known/unknown, charges, GCD and real cooldown.
5. Drag/lock/reset anchor out of combat; confirm debug log and minimap hide persist after reload.
6. Exercise `UNIT_AURA`, `SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELLS_CHANGED`, target/focus changes, and combat transitions without Lua/taint errors.

## Uncertain or version-sensitive claims

`C_UnitAuras`, `C_Spell`, legacy spell APIs, and the available spell-activation alert template names vary by client build. The wrappers intentionally fall back, but actual 12.0.x behavior and visual templates require live-client smoke testing.

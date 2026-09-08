# Comprehensive Audit & PR Report: `RothSpellTracker`

- **Addon Name**: `RothSpellTracker`
- **Addon Path**: `C:\Development\WoWDevAddons\_Addons\RothSpellTracker`
- **Remote Repository**: `github-roth-spell-tracker` (`https://github.com/UnknownAlienHuman/roth-spell-tracker.git`)
- **Target WoW Version**: Retail 12.1.0 (`## Interface: 120100`, Target Build `12.1.0.69497`)
- **Required Blizzard Dependency**: `Blizzard_AuraContainer`
- **Local Version**: `0.2.1` (Schema v2, Interface `120001, 120005`)
- **Remote Version**: `0.3.0` (Schema v3, Interface `120100`, 17 commits ahead)
- **Audit Date**: 2026-09-08

---

## 1. Executive Summary

`RothSpellTracker` is a compact, high-performance visual tracker designed to monitor spell readiness, cooldowns, charges, and targeted aura states (similar to a focused TellMeWhen display) within the Roth gothic UI ecosystem.

### Current State Comparison

| Architectural Aspect | Local Monorepo Baseline (`_Addons/RothSpellTracker`) | Remote GitHub Main (`github-roth-spell-tracker/main`) | Status / Impact |
| :--- | :--- | :--- | :--- |
| **Interface & Build Target** | `120001, 120005` (Retail 11.x / Early TWW) | `120100` (Retail 12.1 Midnight, Build `12.1.0.69497`) | **CRITICAL**: Local marked out of date |
| **Addon Version & Schema** | Version `0.2.1`, DB Schema v2 | Version `0.3.0`, DB Schema v3 (durable `uid`) | **HIGH**: Required for stable slot management |
| **Blizzard Dependencies** | None declared | `## Dependencies: Blizzard_AuraContainer` | **CRITICAL**: Required for native managed containers |
| **Aura Architecture** | Raw `UNIT_AURA` event, `C_UnitAuras` scan, internal `_auraCache` | Pure managed Blizzard `CustomAuraContainer` (`Modules/ManagedAuras.lua`) | **FATAL**: Local triggers `SecretValue` violations in combat |
| **Aura Feature Scope** | Unsupported stack threshold (`minStacks`) & `INACTIVE` state | Retail 12.1 compliant: `ALWAYS` (placeholder) / `ACTIVE` | **PASS**: Eliminates forbidden aura introspection |
| **Global Cooldown (GCD)** | Guesses GCD via heuristic `duration <= 1.5` or `startTime > 0` | Explicit evidence required: `isOnGCD == true`; fails closed | **HIGH**: Resolves haste & sub-second GCD misclassifications |
| **Combat Lockdown Safety** | Lazy `CreateFrame` in `Display:GetIcon` during combat refresh | Precreated slots outside combat; all mutations deferred via `pendingRebuild` | **CRITICAL**: Local risks combat execution errors |
| **Layout Stability** | Dynamic compaction: icons re-anchor when auras appear/disappear | Stable slots: each enabled track retains fixed screen position | **UX/STABILITY**: No jarring layout jumps during combat |
| **Slash Command Collision** | Registers `SLASH_ROTHSPELLTRACKER1 = "/rst"` | Registers `/rothspelltracker`, `/rspellt`, `/spelltracker` | **RESOLVED**: Overcame collision with `RothSecretTester` |
| **Configuration UI** | Missing slider controls, exposes obsolete `minStacks` & `INACTIVE` | Modern `UISliderTemplate`, `UICheckButtonTemplate`, schema v3 form | **MODERNIZED**: Clean, safe options UI |
| **Automated Regressions** | No test files present | `test_managed_aura_12_1.lua` and `test_spell_state_12_1.lua` | **VERIFIED**: Deterministic 12.1 test suites pass |

**Audit Conclusion**: The local monorepo version carries critical architectural flaws that will fail or crash under Retail 12.1 (Interface `120100`): raw `UNIT_AURA` queries on restricted units throw `SecretValue` exceptions, duration-based GCD inference misclassifies cooldowns, lazy frame creation during combat causes taint and execution blocks, and the `/rst` slash command directly conflicts with `RothSecretTester`.

Upstream (`github-roth-spell-tracker/main`) has completed a comprehensive, high-quality architectural modernization across 17 commits. The monorepo tree should be synchronized with this upstream state immediately.

---

## 2. Upstream Git Analysis (`HEAD:_Addons/RothSpellTracker` vs `github-roth-spell-tracker/main`)

A full comparison between the local monorepo directory `HEAD:_Addons/RothSpellTracker` and `remotes/github-roth-spell-tracker/main` reveals extensive updates across the entire codebase:

```text
 AGENT_GUIDE.md                   | 194 +++++---
 ARCHITECTURE.md                  | 139 +++++-
 CODE_GRAPH.md                    |  39 +-
 CODE_INDEX.md                    |  25 +-
 Core/Config.lua                  |  33 +-
 Core/ConfigUI.lua                | 932 +++++++++++++++------------------------
 Core/Core.lua                    | 444 +++++++++----------
 Core/Logging.lua                 |  39 +-
 Core/Util.lua                    | 330 ++++++++++----
 Modules/Display.lua              | 481 ++++++++++----------
 Modules/ManagedAuras.lua         | 164 +++++++
 Modules/Tracker.lua              | 411 ++++-------------
 README.md                        |  92 +++-
 RothSpellTracker.toc             |  23 +-
 tests/test_managed_aura_12_1.lua | 188 ++++++++
 tests/test_spell_state_12_1.lua  |  92 ++++
 todo.md                          |  81 ++--
 17 files changed, 2046 insertions(+), 1661 deletions(-)
```

### Upstream Commit Log

The upstream repository contains 17 commits ahead of the local monorepo baseline:

1. `dfcc875` **refactor: define the Retail 12.1 track schema** — Introduced DB Schema v3 with durable numeric UIDs and distinct SPELL vs AURA field contracts.
2. `08d89a2` **fix: gate spell and logging inputs before Lua inspection** — Wrapped all API queries in `Core/Util.lua` with `CanAccess`, `SafeBool`, `SafeNumber`, `SafeString`, and `SafeTable`.
3. `7d9cb1d` **fix: sanitize diagnostic log values** — Hardened `Core/Logging.lua` against SecretValue stringification leaks.
4. `4004249` **refactor: migrate tracks and remove the /rst alias collision** — Implemented `MigrateV2toV3`, durable UID assignment, and migrated slash commands to `/rothspelltracker`, `/rspellt`, `/spelltracker`.
5. `e020933` **refactor: reserve stable slots and precreate spell visuals** — Redesigned `Modules/Display.lua` around stable slot UIDs, precreated spell visual widgets, and deferred combat updates via `pendingRebuild`.
6. `4a31695` **feat: render aura tracks through managed AddAuraSlot containers** — Created `Modules/ManagedAuras.lua` utilizing Blizzard's native `CustomAuraContainerTemplate` and `AddAuraSlot`.
7. `c573f33` **fix: remove raw aura scans and require explicit GCD evidence** — Completely stripped `UNIT_AURA` and raw aura caching from `Modules/Tracker.lua`; required `isOnGCD == true` for GCD suppression.
8. `83a906d` **refactor: expose only managed-aura-safe configuration** — Modernized `Core/ConfigUI.lua` with `UISliderTemplate`, `UICheckButtonTemplate`, and removed obsolete aura inputs.
9. `1fc3a2e` **test: cover the managed aura slot contract** — Added `tests/test_managed_aura_12_1.lua`.
10. `adf5535` **test: cover explicit GCD evidence and inaccessible spell state** — Added `tests/test_spell_state_12_1.lua`.
11. `8efba34` **chore: target Retail 12.1 and load the managed aura owner** — Updated `RothSpellTracker.toc` to Interface `120100`, added `Blizzard_AuraContainer` dependency, and loaded `ManagedAuras.lua`.
12. `959115b` **docs: document managed aura and explicit GCD behavior** — Updated `README.md`.
13. `9b58025` **docs: define managed aura and stable-slot ownership** — Updated `ARCHITECTURE.md`.
14. `af7b68f` **docs: rewrite agent instructions for Retail 12.1** — Updated `AGENT_GUIDE.md`.
15. `f255840` **docs: update the Retail 12.1 code index** — Updated `CODE_INDEX.md`.
16. `40a1649` **docs: update the managed aura code graph** — Updated `CODE_GRAPH.md`.
17. `8203b4b` **docs: replace the obsolete raw-aura plan with the 12.1 checklist** — Updated `todo.md`.

---

## 3. Detailed Audit Findings against Retail 12.1 & Engineering Knowledge Base

### 3.1 Interface & TOC Metadata Compliance
- **Local TOC**: Declared `## Interface: 120001, 120005` with version `0.2.1`. Under Retail 12.1 (`120100`), the client marks the addon as out of date and ignores it unless overrides are enabled.
- **Remote TOC**: Corrected to `## Interface: 120100` and version `0.3.0`.
- **Dependencies**: Remote explicitly declares `## Dependencies: Blizzard_AuraContainer`, ensuring Blizzard's native C-side container system is loaded before any addon frame initialization occurs.
- **Build Verification**: Declares `## X-Verified-Build: 12.1.0.69497`.

---

### 3.2 Aura Architecture: Managed `AuraContainer` vs Raw `UnitAura` (Fatal 12.1 Vulnerability)

#### The Problem
In Retail 12.1 (`120100`), Blizzard enforces strict security boundaries on unit auras. When a unit is marked as restricted (such as during combat encounters or protected unit tokens), aura data contains `SecretValue` fields or is shielded from Lua iteration. Direct calls to `C_UnitAuras.GetAuraDataByIndex`, `C_UnitAuras.GetAuraDataBySlot`, or `AuraUtil.ForEachAura` inside combat trigger runtime exceptions (`SecretValue attempted to be evaluated in Lua boolean/arithmetic expression`).

#### Local Monorepo Flaws (`Modules/Tracker.lua`)
The local implementation:
1. Registered `UNIT_AURA` for player, target, and focus.
2. Built an internal table cache (`self._auraCache`) by scanning all auras on each event:
   ```lua
   -- LOCAL DEFECT: Raw aura scanning in Lua
   local function BuildAuraIndex(unit, filter, out)
     WipeMap(out)
     local idx = 1
     while true do
       local a = C_UnitAuras.GetAuraDataByIndex(unit, idx, filter)
       if not break end
       if type(a.spellId) == "number" then
         out[a.spellId] = a
       end
       idx = idx + 1
     end
   end
   ```
3. Evaluated stack counts (`e.minStacks`) and missing-only states (`INACTIVE`) in Lua.

#### Upstream 12.1 Solution (`Modules/ManagedAuras.lua`)
1. **Zero Raw Aura APIs**: `UNIT_AURA`, `C_UnitAuras`, `UnitAura`, `AuraUtil`, and all raw data caches are completely eliminated.
2. **Native Container Hosting**: Each enabled AURA track is assigned a Blizzard `CustomAuraContainerTemplate` frame parented to the track slot:
   ```lua
   local container = CreateFrame("AuraContainer", nil, slot, "CustomAuraContainerTemplate")
   container:SetAllPoints(slot)
   container:SetUnit(track.unit)

   local options = {
     initializeFrame = function(button)
       InitializeManagedButton(button, container)
     end,
     candidateFilters = {
       includeSpellIDs = { [track.id] = true },
     },
     sortMethod = AuraContainerSortMethod.Default,
     sortDirection = AuraContainerSortDirection.Normal,
   }
   container:AddAuraSlot("track", track.auraType, options)
   ```
3. **Blizzard-Owned Display Sinks**: During frame initialization (`initializeFrame`), native C-layer sinks are hooked:
   - `button:SetIcon(icon)`
   - `button:SetApplicationCount(count, {})`
   - `button:SetDurationCooldown(cooldown)`
4. **Placeholder Art**: When `showWhen == "ALWAYS"`, a background texture at 35% alpha displays the spell icon. When active, Blizzard's managed button renders over it. When `showWhen == "ACTIVE"`, the placeholder is hidden.
5. **No Introspection**: Lua never touches or queries the managed `AuraButton` state, visibility, or child count. Blizzard handles all filtering, updating, and rendering directly in C-code.

---

### 3.3 Spell Usability, Cooldowns, Charges & Explicit GCD Evidence

#### The Problem
In earlier WoW versions, addons inferred whether a cooldown was merely the global cooldown (GCD) by testing `duration <= 1.5`. Under Retail 12.1:
- Variable haste, hero talents, and specs with naturally low base GCDs (e.g., Rogues and Windwalker Monks with 1.0s GCDs) invalidate static duration assumptions.
- Short defensive and active mitigation abilities (e.g., 1.5s shield blocks, quick procs) were falsely suppressed as "just GCD".
- Cooldown and charge APIs can return restricted/secret values under certain encounter contexts.

#### Local Monorepo Flaws (`Modules/Tracker.lua`)
```lua
-- LOCAL DEFECT: Inaccurate GCD guessing and unsafe boolean evaluation
local onRealCD = false
if startTime and duration and duration > 0.05 then
  if track.ignoreGCD ~= false then
    onRealCD = duration > 1.5   -- Fails on low-haste or short CD spells!
  else
    onRealCD = startTime > 0
  end
end
```

#### Upstream 12.1 Solution (`Modules/Tracker.lua` & `Core/Util.lua`)
1. **Explicit GCD Flag**: Utilizes `C_Spell.GetSpellCooldown(spellID).isOnGCD`, introduced by Blizzard to authoritatively signal whether a cooldown is the global cooldown.
2. **Fail-Closed Principle**:
   ```lua
   local onRealCooldown = false
   if startTime and duration and duration > 0.05 and startTime > 0 then
     if track.ignoreGCD ~= false and isOnGCD == true then
       onRealCooldown = false
     else
       -- Unknown GCD classification fails closed: short duration alone is not
       -- sufficient evidence that this is only the global cooldown.
       onRealCooldown = true
     end
   end
   ```
   If `isOnGCD` is `nil` or `false`, it fails closed and treats the ability as on real cooldown rather than assuming GCD.
3. **Safe Access Wrappers**: All queries in `Core/Util.lua` (`GetSpellName`, `GetSpellIcon`, `IsSpellKnown`, `IsUsableSpell`, `GetSpellCooldown`, `GetSpellCharges`) are protected via `pcall` and sanitized through `CanAccess`, `SafeBool`, `SafeNumber`, and `SafeTable`. Secret or inaccessible values return safe fallback states without erroring.

---

### 3.4 Pattern RT-AUDIT-001: SavedVariables Default Mutation & Deep Copying

#### Audit Requirement
Addons must ensure default configuration tables are never inserted by reference into `SavedVariables` (`RothSpellTrackerDB`), preventing profile mutation or default corruption in memory.

#### Findings & Upstream Hardening
1. **Hardened `U.DeepCopy`**:
   `Core/Util.lua` implements `U.DeepCopy(value, depth, seen)` with a strict recursion limit (`depth > 12`), cycle tracking via `seen[value]`, key validation (permits only string and number keys), and child count throttling (maximum 1,000 entries).
2. **Clean Default Merging (`U.CopyDefaults`)**:
   Deep-copies nested tables rather than assigning sub-table references.
3. **Schema Version 3 Migration (`MigrateV2toV3`)**:
   - Assigns durable numeric UIDs (`uid`) to all tracks.
   - Cleanses obsolete AURA options: converts missing-only `INACTIVE` tracks to `ALWAYS` and purges `minStacks`.
   - Deduplicates entries (`SPELL:<id>` and `AURA:<id>:<unit>:<auraType>`).
   - Increments schema to `db.version = 3`.
4. **Database Reset**:
   `Addon:ResetDB()` clones the existing minimap configuration via `U.DeepCopy`, generates a fresh DB from `Addon.Defaults`, sanitizes it, and triggers a full UI rebuild.

---

### 3.5 Pattern RT-AUDIT-002: Single Runtime Owner & Dead Code Elimination

#### Audit Requirement
Avoid overlapping event handlers, conflicting runtime controllers, or duplicate update loops.

#### Findings & Upstream Architecture
1. **Strict Ownership Boundaries**:
   - **AURA Owner**: `Modules/ManagedAuras.lua` exclusively owns all aura containers, slot lifecycle, and target/focus events (`PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`).
   - **SPELL Owner**: `Modules/Tracker.lua` exclusively owns spell readiness evaluation and spell events (`SPELL_UPDATE_COOLDOWN`, `SPELL_UPDATE_CHARGES`, `SPELLS_CHANGED`, `ACTIONBAR_UPDATE_USABLE`, talent updates).
   - **Layout/Display Owner**: `Modules/Display.lua` exclusively owns frame geometry, slot creation, positioning, and lock states.
2. **Dead Code Elimination**:
   - 411 lines in `Tracker.lua` were reduced to ~180 lines by completely removing raw aura scanning loops, cache wipe helpers, and dynamic row-compaction routines.
3. **Stable Slots vs Dynamic Compaction**:
   - The local codebase continually resized and repositioned icons depending on which items were currently "shown", causing frame churn and jarring visual movement during combat.
   - The upstream 12.1 codebase maintains **stable slots** (`self.order`): each enabled track has a permanent slot index and fixed coordinate offset. Slot position never shifts when a spell or aura changes state.

---

### 3.6 Slash Command Conflict Resolution (`/rst`)

#### The Conflict
In the local monorepo:
- `RothSpellTracker` registered: `SLASH_ROTHSPELLTRACKER1 = "/rst"`
- `RothSecretTester` (an essential diagnostic tool in the same development suite) also registered: `SLASH_ROTHSECRETTESTER1 = "/rst"`
- Depending on load order, whichever addon loaded last stole the `/rst` command, breaking configuration or diagnostic workflows.

#### The Resolution
In `Core/Core.lua`:
```lua
SLASH_ROTHSPELLTRACKER1 = "/rothspelltracker"
SLASH_ROTHSPELLTRACKER2 = "/rspellt"
SLASH_ROTHSPELLTRACKER3 = "/spelltracker"
SlashCmdList.ROTHSPELLTRACKER = Slash
```
The `/rst` alias was retired in favor of unique, descriptive identifiers, eliminating all slash command collisions.

---

### 3.7 Combat Lockdown, Taint Safety & Precreation

#### The Problem
Calling `CreateFrame`, `SetParent`, `ClearAllPoints`, or `SetPoint` during `InCombatLockdown()` triggers secure execution restrictions or combat taint errors (`ADDON_ACTION_BLOCKED`).

#### Local Flaws
The local `Display:GetIcon(i)` function created icon frames on the fly whenever `Refresh()` requested an index that did not yet exist in the pool. Since `Refresh()` was event-driven, gaining a buff or proc in combat could trigger `CreateFrame` inside combat lockdown.

#### Upstream 12.1 Implementation
1. **Precreation**: All track slots and spell visual frames are precreated outside combat when configuration changes or on login (`EnsureSlot`).
2. **Combat Deferral (`pendingRebuild`)**:
   In `Modules/Display.lua` and `Modules/ManagedAuras.lua`, every structural mutation is guarded:
   ```lua
   if InCombatLockdown() then
     self.pendingRebuild = true
     return false
   end
   ```
3. **Post-Combat Reconciliation**:
   `Modules/Display.lua` registers `PLAYER_REGEN_ENABLED`:
   ```lua
   events:RegisterEvent("PLAYER_REGEN_ENABLED")
   events:SetScript("OnEvent", function()
     if D.pendingRebuild then D:Rebuild() end
   end)
   ```
   If configuration or track lists are altered while in combat, the rebuild is deferred and executes in a single clean pass the moment combat ends.
4. **Anchor Dragging Guard**:
   `OnDragStart` verifies `not InCombatLockdown()` before allowing anchor movement.

---

### 3.8 Configuration UI & Options Modernization

#### The Problem
The legacy `OptionsSliderTemplate` and raw `CheckButton` templates are deprecated or broken in Retail 12.1. Furthermore, exposing obsolete aura options (`minStacks`, `INACTIVE`) confused users since those features cannot function under 12.1 security rules.

#### Upstream 12.1 Implementation (`Core/ConfigUI.lua`)
1. Replaced obsolete slider widgets with a clean custom helper built on `UISliderTemplate` (`CreateSlider(parent, labelText, minimum, maximum, step, getter, setter)`).
2. Standardized check buttons on `UICheckButtonTemplate`.
3. Fully integrated schema v3 track editing:
   - SPELL: options for `ALWAYS`, `READY`, `NOTREADY`, and `ignoreGCD`.
   - AURA: options for `ALWAYS`, `ACTIVE`, `unit` (`player`, `target`, `focus`), and `auraType` (`HELPFUL`, `HARMFUL`).
   - Removed obsolete `minStacks` and `INACTIVE` inputs.
   - Clean UID-based track list management with persistent selection and smooth scrolling.

---

## 4. Key Proposed Code Diffs

### Diff 1: `RothSpellTracker.toc` (Metadata & Dependencies)
```diff
--- a/_Addons/RothSpellTracker/RothSpellTracker.toc
+++ b/_Addons/RothSpellTracker/RothSpellTracker.toc
@@ -1,25 +1,24 @@
-## Interface: 120001, 120005
+## Interface: 120100
 ## Title: Roth Spell Tracker
-## Notes: Mini tracker for spells/auras/cooldowns (TellMeWhen-style). Secret-safe patterns for WoW 12.0+.
+## Notes: Managed aura slots and accessibility-first spell readiness tracking for Retail 12.1.
 ## Author: Neomorph
-## Version: 0.2.1
+## Version: 0.3.0
 ## SavedVariables: RothSpellTrackerDB
+## Dependencies: Blizzard_AuraContainer
+## X-Verified-Build: 12.1.0.69497
 
-# libs
-libs\LibStub\LibStub.lua
-libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
-libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
-libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
+Libs\LibStub\LibStub.lua
+Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
+Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
+Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
 
-# core
 Core\Config.lua
+Core\Util.lua
 Core\Logging.lua
-Core\Util.lua
 Core\Minimap.lua
 Core\ConfigUI.lua
 Core\Core.lua
-
-# modules
 Modules\Display.lua
+Modules\ManagedAuras.lua
 Modules\Tracker.lua
```

### Diff 2: `Core/Core.lua` (Schema v3 & Slash Commands)
```diff
--- a/_Addons/RothSpellTracker/Core/Core.lua
+++ b/_Addons/RothSpellTracker/Core/Core.lua
@@ -176,9 +176,9 @@ local function SanitizeTracks(db)
-    -- slash
-    SLASH_ROTHSPELLTRACKER1 = "/rst"
-    SlashCmdList["ROTHSPELLTRACKER"] = Slash
+    SLASH_ROTHSPELLTRACKER1 = "/rothspelltracker"
+    SLASH_ROTHSPELLTRACKER2 = "/rspellt"
+    SLASH_ROTHSPELLTRACKER3 = "/spelltracker"
+    SlashCmdList.ROTHSPELLTRACKER = Slash
```

### Diff 3: `Modules/Tracker.lua` (Explicit GCD & Removal of Raw Auras)
```diff
--- a/_Addons/RothSpellTracker/Modules/Tracker.lua
+++ b/_Addons/RothSpellTracker/Modules/Tracker.lua
@@ -62,11 +57,17 @@ local function EvalSpell(track)
+  local cooldown = U.GetSpellCooldown(spellID)
+  local startTime = cooldown and cooldown.startTime or nil
+  local duration = cooldown and cooldown.duration or nil
+  local isOnGCD = cooldown and cooldown.isOnGCD or nil
+
+  local onRealCooldown = false
+  if startTime and duration and duration > 0.05 and startTime > 0 then
+    if track.ignoreGCD ~= false and isOnGCD == true then
+      onRealCooldown = false
     else
-      onRealCD = startTime > 0
+      -- Unknown GCD classification fails closed: short duration alone is not
+      -- sufficient evidence that this is only the global cooldown.
+      onRealCooldown = true
     end
   end
```

---

## 5. Automated Regression Test Verification

The upstream codebase includes two deterministic test suites verifying Retail 12.1 compatibility:

### 1. `tests/test_managed_aura_12_1.lua` (188 lines)
- Verifies that `AURA` tracks are instantiated strictly via Blizzard `CustomAuraContainer`.
- Verifies that `includeSpellIDs` candidate filters are correctly passed.
- Verifies that `SetIcon`, `SetApplicationCount`, and `SetDurationCooldown` sinks are connected during initialization.
- Verifies that `C_UnitAuras` and `UnitAura` remain untouched (`nil`).
- Verifies that target/focus change events trigger container updates.
- Verifies that frame creation during combat is deferred and executed cleanly on `PLAYER_REGEN_ENABLED`.

### 2. `tests/test_spell_state_12_1.lua` (92 lines)
- Simulates Retail 12.1 `SecretValue` tables with forbidden operators (`__tostring`, `__lt`, `__index`).
- Verifies that explicit GCD (`isOnGCD == true`) is successfully ignored when `ignoreGCD == true`.
- Verifies that short cooldowns with unknown/inaccessible GCD evidence fail closed safely.
- Verifies that real cooldowns and charges calculate readiness accurately.
- Verifies that completely inaccessible/secret spell states fail closed without throwing Lua errors or leaking secrets.

---

## 6. Action Items & Live-Client Verification Checklist

### Pre-Deployment Verification
- [x] Full source code inspection against Retail 12.1 standards.
- [x] Verification of `check_lua.js` syntax validation across all files.
- [x] Review of all 17 upstream commits.
- [x] Verification of deterministic regressions (`test_managed_aura_12_1.lua`, `test_spell_state_12_1.lua`).

### Live-Client Smoke Test Checklist (Build `12.1.0.69497`)
1. **Fresh Install & Migration**:
   - Verify clean load with no SavedVariables.
   - Verify v1 and v2 SavedVariables seamlessly migrate to Schema v3 with assigned UIDs.
2. **Slash Command Integrity**:
   - Confirm `/rothspelltracker`, `/rspellt`, and `/spelltracker` open the configuration panel.
   - Confirm `/rst` does not trigger `RothSpellTracker` (reserved for `RothSecretTester`).
3. **Managed Aura Containers**:
   - Add a player buff (e.g., Blood Presence / Mark of the Wild) and harmful debuff on target (e.g., Frost Fever).
   - Verify icons, stack counts, and duration cooldown swirls render smoothly through Blizzard's container.
   - Switch targets and verify container immediately updates without delay or errors.
4. **Spell Tracking & Explicit GCD**:
   - Track spells with short cooldowns, spells with charges, and global cooldown spells.
   - Verify GCD does not trigger full cooldown overlays when `ignoreGCD` is enabled.
5. **Combat Lockdown Hardening**:
   - Enter combat with BugGrabber/Swatter active.
   - Open options or alter tracks while in combat: verify no frames are created and no errors occur.
   - Leave combat: verify deferred updates apply cleanly.
   - Verify anchor dragging is disabled while in combat.

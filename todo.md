# Roth Spell Tracker — TODO

Goal: configurable tracker that glows when an aura appears (AURA) or when a spell becomes usable (SPELL).
Patterns for robustness/secret-safety are aligned with InterruptGlow (same author): SafeBool, defensive API use, no permanent OnUpdate.

## Stage 1 (baseline MVP)
- [x] Addon skeleton (Core/, Modules/, libs/), SavedVariables + versioning.
- [x] Logging module: ring-buffer + optional chat output.
- [x] Minimap icon (LDB + DBIcon).
- [x] Config window (basic add/remove) and anchor display.
- [x] Event-driven refresh (UNIT_AURA, SPELL_UPDATE_*, target/focus changes).

## Stage 2 (this build) — AURA/SPELL list + glow + scalable UI
- [x] DB schema v2: db.tracks[] array with stable ordering (supports unlimited entries) + auto-migration from v1.
- [x] Config UI:
  - [x] Add/Edit by ID + Type (AURA/SPELL)
  - [x] Unlimited scroll list; enable/disable per row
  - [x] Preview icon+name; edit/remove row actions
  - [x] Per-entry options:
    - AURA: unit (player/target/focus), aura type (HELPFUL/HARMFUL), minStacks
    - SPELL: ignoreGCD
    - Show mode: Always / only active / only inactive
- [x] Display:
  - [x] Blizzard-style SpellActivation glow overlay on tracker icons
  - [x] Dim inactive icons when Show=Always
- [x] Tracker logic:
  - [x] AURA active detection via per-refresh aura index (unit+filter scan once, O(auras) not O(entries*auras))
  - [x] SPELL usable detection: known + usable + real cooldown/charges (ignore GCD threshold)

## Stage 3 — QoL + polish
- [x] Reorder rows (up/down).
- [x] UI polish: section insets, hide/show of kind-specific labels, grow-direction dropdown, reset buttons.
- [x] Defensive SavedVariables sanitize pass (types, caps, dedupe).
- [ ] Import/export (plain text list).
- [ ] Per-entry "glow only" vs "hide when inactive" presets.

## Stage 4 — Advanced filters
- [ ] Filters: inCombat/outOfCombat, instance type, targetExists, spec-based sets.


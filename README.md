# Roth Spell Tracker

Configurable miniature tracker for spells, auras, and cooldowns. The checked-in design uses defensive/secret-safe patterns and event-driven refresh rather than a permanent `OnUpdate` loop.

**Version:** 0.2.1
**Interface:** 120001, 120005
**SavedVariables:** `RothSpellTrackerDB`
**Dependencies:** embedded LibStub, CallbackHandler-1.0, LibDataBroker-1.1, and LibDBIcon-1.0.

## Install

Copy `RothSpellTracker` to `World of Warcraft/_retail_/Interface/AddOns/`, enable it, and reload the UI.

## Use

`/rst` opens the tracker configuration. The configuration UI supports AURA and SPELL entries, including per-entry enablement and ordering; display options include show modes and a glow overlay. A minimap icon is initialized through the embedded broker libraries.

## Current development status

The baseline MVP, scalable AURA/SPELL list, glow display, and several UI-quality items are recorded as complete. Open work is plain-text import/export, visibility/glow presets, and advanced combat/instance/target/spec filters. See [todo.md](todo.md).

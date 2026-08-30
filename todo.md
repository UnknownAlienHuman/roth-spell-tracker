# Roth Spell Tracker — TODO

Goal: configurable compact tracker for SPELL readiness and specific AURA displays without treating restricted Retail 12.1 state as ordinary Lua data.

## Retail 12.1 migration

- [x] Target Interface `120100` and source baseline `12.1.0.69497`.
- [x] Remove addon-owned `UNIT_AURA`, raw `C_UnitAuras`/`UnitAura` scans, aura indexing, and raw AuraData caches.
- [x] Render every AURA track through one Blizzard `CustomAuraContainer` and one `AddAuraSlot`.
- [x] Configure managed icon, application-count, duration-cooldown, and static glow sinks during frame initialization.
- [x] Reserve one stable slot per enabled track; never compact layout from readiness or managed aura visibility.
- [x] Add stable track UIDs and schema v3 migration.
- [x] Remove unsupported AURA `minStacks` and `INACTIVE`; migrate old missing-only entries to `ALWAYS`.
- [x] Gate spell names, icons, known/usability, cooldowns, charges, and log values before Lua inspection.
- [x] Ignore cooldown only when accessible `isOnGCD == true`; remove duration-threshold GCD inference.
- [x] Precreate spell visuals/glow outside combat and defer frame/container/layout rebuilds during combat.
- [x] Remove the `/rst` alias collision with Roth Secret Tester.
- [x] Replace the obsolete Options slider template in the configuration window.
- [x] Add local deterministic managed-aura and spell-state regressions.

## Required live-client validation

- [ ] Fresh install and representative v1/v2 SavedVariables migration to schema v3.
- [ ] Add, edit, enable/disable, remove, and reorder SPELL and AURA entries.
- [ ] Player, target, and focus HELPFUL/HARMFUL aura slots.
- [ ] Relationship restrictions: helpful on assistable units and harmful on non-assistable units.
- [ ] Target/focus identity changes while an aura is present or absent.
- [ ] Aura applications/count, duration cooldown, active glow, `ALWAYS` placeholder, and `ACTIVE` blank slot.
- [ ] Known/unknown/replaced spells, charges, explicit GCD, inaccessible GCD classification, and real cooldowns.
- [ ] Combat-time configuration changes result in one post-combat rebuild and no frame creation/layout mutation in combat.
- [ ] Frame lock/unlock/drag/reset, growth directions, size/spacing, minimap icon, configuration window, and reload persistence.
- [ ] No Lua, taint, forbidden-object, blocked-action, or secret-value error on the named Retail build.
- [ ] CPU/allocation capture during spell-event bursts and target/focus churn.

## Remaining product work

- [ ] Plain-text import/export for schema-v3 tracks, with finite length/row limits and strict validation.
- [ ] Per-entry visual presets that do not require observing managed aura state.
- [ ] Optional combat/instance/spec sets using accessible ordinary context only.
- [ ] Explicit user-facing warning when a managed spell-ID relationship/filter combination cannot match under Blizzard rules.

## Deliberate exclusions

- Missing-only AURA alerts.
- AURA stack-threshold decisions.
- Raw aura data export or diagnostics.
- Managed AuraButton visibility, alpha, child count, frame count, assigned instance, or layout inspection.
- Duration-based guessing that a cooldown is the GCD.

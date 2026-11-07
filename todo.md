# Roth Spell Tracker — remaining gates

## Completed in 0.4.4

- [x] Preserve a newer SavedVariables schema instead of overwriting it during downgrade.
- [x] Run future-schema data through a temporary session-only compatibility view.
- [x] Canonicalize supported databases through an allowlist and remove unknown nested keys.
- [x] Require explicit confirmation before Reset DB or Replace DB.
- [x] Deterministically arbitrate conflicting legacy aliases before deduplication.
- [x] Bound legacy spell-ID text and enum-like strings before conversion/comparison.
- [x] Surface future-schema mode in chat and configuration UI.
- [x] Share UI and persistence bounds and expose the DB schema in TOC metadata.
- [x] Display current multi-charge counts including zero and one.
- [x] Keep on-hold cooldowns unavailable without drawing a false active radial.
- [x] Retire and recreate a managed graph instead of reparenting after AuraContainer adoption.
- [x] Replace per-track/deprecated scroll rows with virtualized `WowScrollBoxList` ownership.

## Retained hardening

- [x] Use current `C_SpellBook` knowledge APIs with deprecated fallbacks only.
- [x] Capture `isOnGCD` in its documented event context and match the exact resolved-spell cycle.
- [x] Treat LoC replacement as cooldown presentation only.
- [x] Keep charge, normal and LoC cooldowns independent and explicitly layered.
- [x] Use native AuraContainer acquisition/assignment/refresh ownership with no raw readback.
- [x] Bound UID reuse, candidate rows, diagnostic logging and UI realization.
- [x] Reapply layout on scale/display changes and reconcile protected cooldown/layout state after combat.
- [x] Enforce Lua 5.1 syntax and deterministic regressions through read-only pinned CI.

## Required live-client validation

All observations must record exact client build, Interface, addon commit and SavedVariables fixture.

- [ ] Confirm `GetBuildInfo()` and Interface on Retail 12.1.5.
- [ ] Fresh install plus representative v1/v2/v3 migration and `/reload`.
- [ ] Load a future-schema fixture, change session settings, logout/reload with the newer addon, and prove the source root was preserved.
- [ ] Accept and cancel Reset DB / Replace DB; verify persistence and minimap reference ownership.
- [ ] Add/edit/remove/reorder/enable SPELL and AURA tracks; churn UIDs through repeated deletion/re-addition.
- [ ] Scroll configurations containing 0, 1, viewport+1 and 500 tracks; verify recycled click targets, reorder/delete, scrollbar, mouse wheel and retained position.
- [ ] Player/target/focus HELPFUL/HARMFUL relationship combinations, including unfilterable identity cases.
- [ ] Native target/focus replacement, loss/death, rapid transition, range/phase/instance loss and recovery.
- [ ] Managed icon, application count, duration and overlay ordering; `ALWAYS` placeholder and `ACTIVE` blank slot.
- [ ] Known/unknown/learned/replaced/shapeshift spells, partial/empty charges, charge text `0/1/N`, GCD, real/on-hold cooldowns and LoC.
- [ ] Verify charge < normal < LoC < overlay rendering at multiple icon sizes and UI scales.
- [ ] Verify protected radial behavior before/during/after combat with no blocked action or stale reappearance.
- [ ] Configure layout during combat and confirm one current-state post-combat reconciliation.
- [ ] Open world, encounter, Mythic+, arena and battleground: no Lua, taint, forbidden-object or secret-value loops.
- [ ] CPU/allocation capture during cooldown bursts, resource churn, config scrolling and rapid target/focus replacement.

## Deliberate exclusions

- Missing-only AURA alerts.
- AURA stack-threshold decisions.
- Raw aura export or diagnostics.
- Managed AuraButton visibility, geometry, count or assignment inspection.
- Duration-based GCD guessing.
- Protected-operation retries or polling.

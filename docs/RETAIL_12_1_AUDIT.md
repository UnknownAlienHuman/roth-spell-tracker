# Retail 12.1 audit packet

**Status:** preparatory static audit; no runtime compatibility claim.  
**Target:** World of Warcraft Retail 12.1.0 / Interface `120100`.

## Purpose

Roth Spell Tracker must be audited as a diagnostic/runtime addon, not updated by changing only the TOC. The audit must establish:

- which spell, aura, cooldown, cast, action-bar, combat-log, and unit APIs are used;
- whether every secret-capable or inaccessible return is gated before Lua inspection;
- whether raw aura reads are valid only in explicitly non-secret contexts or must be replaced;
- whether timers, `OnUpdate`, frame scans, event registrations, caches, logs, and SavedVariables are bounded and lifecycle-owned;
- whether `/rst` collides with Roth Secret Tester and which addon retains that alias;
- which Russian text is intentional localization and which text is service documentation requiring English translation.

## Automated inventory

Run:

```text
python tools/audit_retail_12_1.py
```

The scanner writes `artifacts/retail-12-1-audit.json` and reports:

- TOC Interface metadata;
- literal slash aliases and `/rst` ownership;
- removed/deprecated API tokens;
- raw aura APIs and `UNIT_AURA` paths;
- access/secrecy predicates;
- `OnUpdate`, timer, frame-tree and global-frame scans;
- persistence/formatting boundaries;
- Cyrillic service documents separately from localization files.

Strict mode returns non-zero only for confirmed hard blockers such as a missing `120100` target, obsolete API tokens, or the explicit `/rst` collision:

```text
python tools/audit_retail_12_1.py --strict
```

Context-sensitive raw aura, timer, scan, persistence, and access-gate results remain review inputs rather than automatic defects.

## Required source review

- [ ] Identify the authoritative runtime files from the current TOC and remove dead/duplicate loaders only after proving they are inactive.
- [ ] Trace every observation from event/API source to display, cache, log, export, and SavedVariables.
- [ ] Classify each observed field as ordinary, secret-capable, inaccessible-capable, or unknown for the named Retail build/context.
- [ ] Verify access before `type`, comparison, boolean branching, arithmetic, formatting, table indexing, sorting, deduplication, logging, caching, or persistence.
- [ ] Verify `pcall` is error containment only and never treated as declassification.
- [ ] Bound all periodic/event-burst work and prove idle shutdown.
- [ ] Bound all retained observations by source, entity, path, context, age, and total rows.
- [ ] Resolve slash-command ownership with Roth Secret Tester deliberately.
- [ ] Preserve `ruRU` and other player-facing localization.
- [ ] Translate Russian TODO/history/architecture/audit material only after classifying it as service documentation.

## Retail 12.1 live matrix

- [ ] Fresh login and `/reload` with the addon alone.
- [ ] Enable/disable and settings migration from representative SavedVariables.
- [ ] Clear, secret, inaccessible, and accessibility-changing values.
- [ ] Combat, encounter, Mythic+, arena, and battleground restrictions.
- [ ] Specialization/talent changes, spell replacement/override, action-bar paging, vehicle and override states.
- [ ] No repeating Lua error, taint, blocked action, forbidden operation, secret comparison, or raw-value persistence.
- [ ] CPU/allocation/event-rate capture on the exact build with the addon alone and the normal stack.

## Evidence ceiling

The audit workflow proves only repository inventory and static token classification. A Runtime 12.1 update PR requires code changes, deterministic tests, exact-head CI, and named-build client evidence. Do not mark the addon updated from this packet alone.

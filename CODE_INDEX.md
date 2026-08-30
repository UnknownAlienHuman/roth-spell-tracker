# Roth Spell Tracker code index

| Area | Files | Current owners |
|---|---|---|
| Metadata/load order | `RothSpellTracker.toc` | Interface `120100`, Blizzard_AuraContainer dependency, exact runtime order |
| Schema and migration | `Core/Config.lua`, `Core/Core.lua` | DB v3, stable `uid`, v1/v2 migration, bounded sanitize/reset |
| Access boundary | `Core/Util.lua` | `CanAccess`, safe scalar/table gates, sanitized spell name/icon/known/usable/cooldown/charge wrappers |
| Diagnostics/minimap | `Core/Logging.lua`, `Core/Minimap.lua` | bounded ordinary-text ring and LDB/DBIcon object |
| Configuration | `Core/ConfigUI.lua` | add/edit/remove/reorder, supported SPELL/AURA fields, size/spacing/grow/lock/minimap controls |
| Stable presentation | `Modules/Display.lua` | anchor, one reserved slot per enabled track, spell visual children, position/layout/lock, combat-deferred rebuild |
| Managed AURA tracks | `Modules/ManagedAuras.lua` | one CustomAuraContainer/AddAuraSlot per aura UID, display sinks, candidate filters, target/focus refresh |
| SPELL evaluation | `Modules/Tracker.lua` | coalesced spell events, explicit-GCD-only cooldown suppression, charge/readiness evaluation |
| Regression | `tests/test_managed_aura_12_1.lua`, `tests/test_spell_state_12_1.lua` | managed-slot/no-raw-aura contract and inaccessible spell/GCD contract |
| Vendored libraries | `Libs/` | LibStub, CallbackHandler, LibDataBroker, LibDBIcon |

Roth Spell Tracker does not own `/rst`; use `/rothspelltracker`, `/rspellt`, or `/spelltracker`.

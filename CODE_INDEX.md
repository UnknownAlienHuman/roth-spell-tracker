# Code index

| Area | Files | Exact anchors |
| --- | --- | --- |
| Startup/DB | [`Core/Core.lua`](Core/Core.lua), [`Core/Config.lua`](Core/Config.lua) | `Addon:InitDB`, `MigrateV1toV2`, `SanitizeDB`, `Slash`, `Addon:ResetDB` |
| Secret-safe helpers | [`Core/Util.lua`](Core/Util.lua) | `U.IsSecret`, `U.CanAccess`, `U.SafeBool`, `U.SafeNumber`, spell wrappers |
| Support | [`Core/Logging.lua`](Core/Logging.lua), [`Core/Minimap.lua`](Core/Minimap.lua) | `Addon:Log`, `Addon:DumpLog`, `Addon:InitMinimapIcon` |
| Configuration UI | [`Core/ConfigUI.lua`](Core/ConfigUI.lua) | `UI:Create`, `UI:SaveEntryFromForm`, `UI:Refresh`, `UI:MoveEntry`, `Addon:ToggleConfig` |
| Tracking | [`Modules/Tracker.lua`](Modules/Tracker.lua) | `T:Init`, `T:RequestRefresh`, `T:Refresh`, `EvalSpell`, `EvalAura` |
| Rendering | [`Modules/Display.lua`](Modules/Display.lua) | `D:Init`, `D:GetIcon`, `D:SetCount`, `D:SetIconGlow`, cooldown updates |
| Vendored libraries | [`libs/`](libs/) | LibStub, CallbackHandler, LDB, DBIcon |

Entry is TOC/lifecycle-driven; `/rst` is registered only after `ADDON_LOADED` for this addon.

# Code index

| Area | Files | Responsibility |
| --- | --- | --- |
| Startup and DB | `Core/Core.lua`, `Core/Config.lua` | migrations, defaults, component startup, slash command |
| Support | `Core/Util.lua`, `Core/Logging.lua`, `Core/Minimap.lua` | helpers, ring-buffer logging, broker/minimap icon |
| Configuration | `Core/ConfigUI.lua` | tracker editor and list UI |
| Tracking | `Modules/Tracker.lua` | event-driven aura/spell state refresh |
| Rendering | `Modules/Display.lua` | anchor, icons, cooldown and glow presentation |
| Libraries | `libs/` | LibStub, CallbackHandler, LDB, DBIcon |

Primary anchors: `Slash`, `NewDB`, `T:Init`, and the display-anchor creation path.

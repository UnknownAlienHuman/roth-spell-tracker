# Architecture

`Core/Core.lua` initializes `RothSpellTrackerDB`, migrations, command dispatch, and component startup. `Core/Config.lua` and `Core/Util.lua` define configuration and shared helpers; `Core/Logging.lua`, `Core/Minimap.lua`, and `Core/ConfigUI.lua` provide support surfaces. `Modules/Tracker.lua` subscribes to refresh events and derives tracked state, which `Modules/Display.lua` renders on the anchor frame.

Vendored broker/minimap libraries load first. Core files load before the tracker and display modules as listed in the TOC.

# Architecture

The TOC loads bundled LibStub/CallbackHandler/LibDataBroker/LibDBIcon, then `Core/Config.lua`, `Logging.lua`, `Util.lua`, `Minimap.lua`, `ConfigUI.lua`, `Core.lua`, and finally `Modules/Display.lua`/`Modules/Tracker.lua`. All files extend the shared `NS.Addon` table.

`Core/Core.lua` is the lifecycle owner: `ADDON_LOADED` initializes the logger, migrates/sanitizes `RothSpellTrackerDB`, registers the LDB minimap object and `/rst`; `PLAYER_LOGIN` initializes display and tracker. `Tracker:Refresh` derives state from configured SPELL/AURA tracks using coalesced event refreshes, then `Display` renders pooled icons, cooldowns and proc-style glow on `RothSpellTrackerAnchor`.

`/rst` is not globally unique in this workspace: `RothSecretTester` declares the same slash alias. Treat the final `SlashCmdList` registration after both addons load as an integration surface.

The v2 SavedVariables schema is an ordered `tracks` array. `Core/Config.lua` supplies defaults, `Core/Util.lua` is the secret-safe API boundary, and `ConfigUI.lua` is the only editor. There are no external TOC dependencies.

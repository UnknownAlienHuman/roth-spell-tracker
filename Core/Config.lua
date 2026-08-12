local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

Addon.VERSION = "0.2.1"
-- SavedVariables schema version.
-- v1: db.spells map keyed by spellID
-- v2: db.tracks array of entries (supports unlimited rows + stable ordering)
Addon.DB_VERSION = 2

Addon.Defaults = {
  version = Addon.DB_VERSION,
  debug = false,

  minimap = {
    hide = false,
    minimapPos = 220,
  },

  frame = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -120,
    size = 44,
    spacing = 6,
    locked = true,
    grow = "RIGHT", -- RIGHT/LEFT/UP/DOWN
  },

  tracks = {
    -- array of entries (stable order)
    -- {
    --   id = 47528,
    --   kind = "SPELL" | "AURA",
    --   enabled = true,
    --   showWhen = "ALWAYS" | "READY" | "NOTREADY" | "ACTIVE" | "INACTIVE",
    --   ignoreGCD = true,          -- SPELL only
    --   unit = "player",          -- AURA only
    --   auraType = "HELPFUL",     -- AURA only
    --   minStacks = 0,             -- AURA only
    -- }
  },
}

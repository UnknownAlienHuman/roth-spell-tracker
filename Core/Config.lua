local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

Addon.VERSION = "0.3.0"
Addon.DB_VERSION = 3

Addon.Defaults = {
  version = Addon.DB_VERSION,
  nextUID = 1,
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
    grow = "RIGHT",
  },

  tracks = {
    -- Stable ordered array. Each entry owns a durable numeric uid.
    -- SPELL:
    -- { uid, id, kind="SPELL", enabled=true,
    --   showWhen="ALWAYS"|"READY"|"NOTREADY", ignoreGCD=true }
    -- AURA:
    -- { uid, id, kind="AURA", enabled=true,
    --   showWhen="ALWAYS"|"ACTIVE", unit="player"|"target"|"focus",
    --   auraType="HELPFUL"|"HARMFUL" }
    --
    -- AURA state is rendered only through Blizzard CustomAuraContainer slots.
    -- Missing-only and stack-threshold inference are intentionally unsupported
    -- because they require observing managed aura assignment/state.
  },
}

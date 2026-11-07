local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

Addon.VERSION = "0.4.4"
Addon.DB_VERSION = 3
Addon.MAX_TRACKS = 500
Addon.MAX_TRACK_INPUTS = 2000
Addon.MAX_SPELL_ID = 2147483647
Addon.MAX_LEGACY_ID_TEXT = 64
Addon.MAX_ENUM_TEXT = 32
Addon.MIN_ICON_SIZE = 24
Addon.MAX_ICON_SIZE = 96
Addon.MAX_ICON_SPACING = 30

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
    -- Stable ordered array. Each entry owns a numeric uid in 1..MAX_TRACKS.
    -- SPELL:
    -- { uid, id, kind="SPELL", enabled=true,
    --   showWhen="ALWAYS"|"READY"|"NOTREADY", ignoreGCD=true }
    -- AURA:
    -- { uid, id, kind="AURA", enabled=true,
    --   showWhen="ALWAYS"|"ACTIVE", unit="player"|"target"|"focus",
    --   auraType="HELPFUL"|"HARMFUL" }
    --
    -- AURA state is rendered only through Blizzard CustomAuraContainer slots.
    -- Missing-only and stack-threshold inference are intentionally unsupported.
  },
}

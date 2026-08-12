local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

-- SavedVariables
RothSpellTrackerDB = RothSpellTrackerDB or nil

local function NewDB()
  local db = U.DeepCopy(Addon.Defaults)
  return db
end

local function SortTracksByID(tracks)
  table.sort(tracks, function(a, b)
    local ai = (type(a) == "table" and type(a.id) == "number") and a.id or 0
    local bi = (type(b) == "table" and type(b.id) == "number") and b.id or 0
    if ai == bi then
      local ak = (type(a) == "table" and a.kind) or ""
      local bk = (type(b) == "table" and b.kind) or ""
      return ak < bk
    end
    return ai < bi
  end)
end

local function MigrateV1toV2(db)
  -- v1 schema stored entries in db.spells[spellID] = { enabled, mode=AURA/COOLDOWN, ... }
  -- v2 uses db.tracks = array with stable order + explicit kind (AURA/SPELL)
  local spells = db.spells
  if type(spells) ~= "table" then
    db.tracks = db.tracks or {}
    db.spells = nil
    return
  end

  local tracks = {}
  for sid, e in pairs(spells) do
    local id = tonumber(sid)
    if id and id >= 1 and type(e) == "table" then
      local mode = e.mode or "AURA"
      local kind = (mode == "COOLDOWN") and "SPELL" or "AURA"
      local showWhen
      if kind == "SPELL" then
        showWhen = e.showWhen or "READY"
      else
        showWhen = e.showWhen or "ACTIVE"
      end

      tracks[#tracks + 1] = {
        id = id,
        kind = kind,
        enabled = (e.enabled ~= false),
        showWhen = showWhen,
        ignoreGCD = (e.ignoreGCD ~= false),
        unit = e.unit or "player",
        auraType = e.auraType or "HELPFUL",
        minStacks = tonumber(e.minStacks) or 0,
      }
    end
  end

  SortTracksByID(tracks)
  db.tracks = tracks
  db.spells = nil
end

-- Defensive sanitize for SavedVariables (aligned in spirit with InterruptGlow).
-- Goal: prevent corrupted SV (or secret values) from breaking logic.
local function SanitizeDB(db)
  if type(db) ~= "table" then return end

  -- debug
  local dbg = U.SafeBool(db.debug)
  if dbg == nil then dbg = false end
  db.debug = dbg

  -- minimap
  if type(db.minimap) ~= "table" then db.minimap = {} end
  local mh = U.SafeBool(db.minimap.hide)
  db.minimap.hide = (mh == true)
  local pos = U.SafeNumber(db.minimap.minimapPos)
  if not pos then pos = 220 end
  if pos < 0 then pos = 0 end
  if pos > 360 then pos = 360 end
  db.minimap.minimapPos = pos

  -- frame
  if type(db.frame) ~= "table" then db.frame = {} end
  local size = U.SafeNumber(db.frame.size) or 44
  if size < 16 then size = 16 end
  if size > 128 then size = 128 end
  db.frame.size = math.floor(size + 0.5)

  local spacing = U.SafeNumber(db.frame.spacing) or 6
  if spacing < 0 then spacing = 0 end
  if spacing > 60 then spacing = 60 end
  db.frame.spacing = math.floor(spacing + 0.5)

  local locked = U.SafeBool(db.frame.locked)
  db.frame.locked = (locked ~= false)

  local grow = (U.CanAccess(db.frame.grow) and db.frame.grow) or "RIGHT"
  if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" then
    grow = "RIGHT"
  end
  db.frame.grow = grow

  -- position fields: keep if strings/numbers, otherwise default
  if not (U.CanAccess(db.frame.point) and type(db.frame.point) == "string") then db.frame.point = "CENTER" end
  if not (U.CanAccess(db.frame.relPoint) and type(db.frame.relPoint) == "string") then db.frame.relPoint = "CENTER" end
  db.frame.x = U.SafeNumber(db.frame.x) or 0
  db.frame.y = U.SafeNumber(db.frame.y) or -120

  -- tracks
  local src = db.tracks
  if type(src) ~= "table" then
    db.tracks = {}
    return
  end

  -- preserve stable order: numeric keys ascending
  local keys = {}
  for k in pairs(src) do
    if type(k) == "number" then
      keys[#keys + 1] = k
    end
  end
  table.sort(keys)

  local out = {}
  local seen = {}
  local cap = 500

  for i = 1, #keys do
    if #out >= cap then break end
    local e = src[keys[i]]
    if type(e) == "table" then
      local id = U.SafeNumber(e.id)
      id = id and math.floor(id + 0.5) or nil
      if id and id >= 1 then
        local kind = (U.CanAccess(e.kind) and e.kind) or "AURA"
        if kind ~= "AURA" and kind ~= "SPELL" then kind = "AURA" end

        local key = kind .. ":" .. id
        if not seen[key] then
          seen[key] = true

          local enabled = U.SafeBool(e.enabled)
          if enabled == nil then enabled = true end

          local showWhen = (U.CanAccess(e.showWhen) and e.showWhen) or "ALWAYS"
          if kind == "SPELL" then
            if showWhen ~= "ALWAYS" and showWhen ~= "READY" and showWhen ~= "NOTREADY" then
              showWhen = "ALWAYS"
            end
          else
            if showWhen ~= "ALWAYS" and showWhen ~= "ACTIVE" and showWhen ~= "INACTIVE" then
              showWhen = "ALWAYS"
            end
          end

          local clean = {
            id = id,
            kind = kind,
            enabled = enabled,
            showWhen = showWhen,
          }

          if kind == "SPELL" then
            local ig = U.SafeBool(e.ignoreGCD)
            if ig == nil then ig = true end
            clean.ignoreGCD = (ig == true)
          else
            local unit = (U.CanAccess(e.unit) and e.unit) or "player"
            if unit ~= "player" and unit ~= "target" and unit ~= "focus" then unit = "player" end
            clean.unit = unit

            local at = (U.CanAccess(e.auraType) and e.auraType) or "HELPFUL"
            if at ~= "HELPFUL" and at ~= "HARMFUL" then at = "HELPFUL" end
            clean.auraType = at

            local ms = U.SafeNumber(e.minStacks)
            ms = ms and math.floor(ms + 0.5) or 0
            if ms < 0 then ms = 0 end
            if ms > 100 then ms = 100 end
            clean.minStacks = ms
          end

          out[#out + 1] = clean
        end
      end
    end
  end

  db.tracks = out
end

function Addon:InitDB()
  local db = RothSpellTrackerDB
  if type(db) ~= "table" or type(db.version) ~= "number" then
    db = NewDB()
  end

  -- migrations / defaults
  U.CopyDefaults(db, Addon.Defaults)

  -- Schema migrations
  if db.version == 1 and Addon.DB_VERSION == 2 then
    MigrateV1toV2(db)
    db.version = 2
  elseif db.version ~= Addon.DB_VERSION then
    -- Safe policy for unknown schema: wipe, preserve minimap.
    local keepMinimap = (type(db.minimap) == "table") and U.DeepCopy(db.minimap) or nil
    db = NewDB()
    if keepMinimap then db.minimap = keepMinimap end
    db.version = Addon.DB_VERSION
  end

  RothSpellTrackerDB = db
  self.db = db

  -- Final sanitize pass (post-migration + post-defaults).
  SanitizeDB(self.db)
end

function Addon:ResetDB()
  local keepMinimap = (self.db and self.db.minimap) and U.DeepCopy(self.db.minimap) or nil
  RothSpellTrackerDB = NewDB()
  if keepMinimap then RothSpellTrackerDB.minimap = keepMinimap end
  self.db = RothSpellTrackerDB
  self:UpdateMinimapIcon()
  self.Display:ApplyLayout()
  self.Tracker:RequestRefresh()
  self:Log("INFO", "DB reset")
end

function Addon:ApplyFrameLock()
  if self.Display and self.Display.ApplyLock then
    self.Display:ApplyLock()
  end
end

-- Slash commands
local function Slash(msg)
  msg = U.Trim(msg or "")
  if msg == "" then
    Addon:ToggleConfig()
    return
  end

  local cmd, arg = msg:match("^(%S+)%s*(.-)$")
  cmd = (cmd or ""):lower()

  if cmd == "debug" then
    local v = (arg == "1" or arg == "on" or arg == "true")
    Addon:SetDebug(v)
    Addon:Log("INFO", v and "Debug ON" or "Debug OFF")
  elseif cmd == "lock" then
    Addon.db.frame.locked = true
    Addon:ApplyFrameLock()
    Addon:Log("INFO", "Frame locked")
  elseif cmd == "unlock" then
    Addon.db.frame.locked = false
    Addon:ApplyFrameLock()
    Addon:Log("INFO", "Frame unlocked")
  elseif cmd == "log" then
    Addon:DumpLog(tonumber(arg) or 50)
  elseif cmd == "reset" then
    Addon:ResetDB()
  else
    Addon:Log("INFO", "Commands: /rst, /rst debug on|off, /rst lock|unlock, /rst log [N], /rst reset")
  end
end

-- Events
local E = CreateFrame("Frame")
E:RegisterEvent("ADDON_LOADED")
E:RegisterEvent("PLAYER_LOGIN")

E:SetScript("OnEvent", function(_, event, a1, ...)
  if event == "ADDON_LOADED" then
    if a1 ~= ADDON then return end

    Addon:InitLogger()
    Addon:InitDB()
    Addon:InitMinimapIcon()
    Addon:UpdateMinimapIcon()

    -- slash
    SLASH_ROTHSPELLTRACKER1 = "/rst"
    SlashCmdList["ROTHSPELLTRACKER"] = Slash

    Addon:Log("INFO", "Loaded v" .. Addon.VERSION)
  elseif event == "PLAYER_LOGIN" then
    if Addon.Display and Addon.Display.Init then
      Addon.Display:Init()
    end
    if Addon.Tracker and Addon.Tracker.Init then
      Addon.Tracker:Init()
      Addon.Tracker:RequestRefresh()
    end
  end
end)

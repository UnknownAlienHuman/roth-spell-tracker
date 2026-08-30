local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

RothSpellTrackerDB = RothSpellTrackerDB or nil

local TRACK_CAP = 500

local function NewDB()
  return U.DeepCopy(Addon.Defaults) or {
    version = Addon.DB_VERSION,
    nextUID = 1,
    debug = false,
    minimap = { hide = false, minimapPos = 220 },
    frame = { point = "CENTER", relPoint = "CENTER", x = 0, y = -120, size = 44, spacing = 6, locked = true, grow = "RIGHT" },
    tracks = {},
  }
end

local function MigrateV1toV2(db)
  local spells = U.SafeTable(db.spells)
  local tracks = {}
  if spells then
    for rawID, rawEntry in pairs(spells) do
      if #tracks >= TRACK_CAP then break end
      local id = U.ToNumber(rawID)
      local entry = U.SafeTable(rawEntry)
      if id and id >= 1 and entry then
        local mode = U.SafeString(entry.mode) or "AURA"
        local kind = mode == "COOLDOWN" and "SPELL" or "AURA"
        tracks[#tracks + 1] = {
          id = math.floor(id + 0.5),
          kind = kind,
          enabled = U.SafeBool(entry.enabled) ~= false,
          showWhen = U.SafeString(entry.showWhen) or (kind == "SPELL" and "READY" or "ACTIVE"),
          ignoreGCD = U.SafeBool(entry.ignoreGCD) ~= false,
          unit = U.SafeString(entry.unit) or "player",
          auraType = U.SafeString(entry.auraType) or "HELPFUL",
        }
      end
    end
  end
  table.sort(tracks, function(a, b)
    if a.id == b.id then return a.kind < b.kind end
    return a.id < b.id
  end)
  db.tracks = tracks
  db.spells = nil
  db.version = 2
end

local function MigrateV2toV3(db)
  local tracks = U.SafeTable(db.tracks) or {}
  local nextUID = 1
  for index = 1, #tracks do
    local entry = U.SafeTable(tracks[index])
    if entry then
      local uid = U.SafeNumber(entry.uid)
      if not uid or uid < 1 then
        uid = nextUID
        entry.uid = uid
      end
      uid = math.floor(uid + 0.5)
      if uid >= nextUID then nextUID = uid + 1 end

      local kind = U.SafeString(entry.kind) or "AURA"
      if kind == "AURA" then
        local showWhen = U.SafeString(entry.showWhen)
        if showWhen ~= "ACTIVE" and showWhen ~= "ALWAYS" then
          entry.showWhen = "ALWAYS"
        end
        entry.minStacks = nil
      end
    end
  end
  db.nextUID = nextUID
  db.version = 3
end

local function SanitizeFrame(db)
  db.frame = U.SafeTable(db.frame) or {}
  local frame = db.frame
  frame.point = U.SafeString(frame.point) or "CENTER"
  frame.relPoint = U.SafeString(frame.relPoint) or "CENTER"
  frame.x = U.SafeNumber(frame.x) or 0
  frame.y = U.SafeNumber(frame.y) or -120

  local size = U.SafeNumber(frame.size) or 44
  if size < 16 then size = 16 elseif size > 128 then size = 128 end
  frame.size = math.floor(size + 0.5)

  local spacing = U.SafeNumber(frame.spacing) or 6
  if spacing < 0 then spacing = 0 elseif spacing > 60 then spacing = 60 end
  frame.spacing = math.floor(spacing + 0.5)

  frame.locked = U.SafeBool(frame.locked) ~= false
  local grow = U.SafeString(frame.grow) or "RIGHT"
  if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" then
    grow = "RIGHT"
  end
  frame.grow = grow
end

local function SanitizeMinimap(db)
  db.minimap = U.SafeTable(db.minimap) or {}
  db.minimap.hide = U.SafeBool(db.minimap.hide) == true
  local position = U.SafeNumber(db.minimap.minimapPos) or 220
  if position < 0 then position = 0 elseif position > 360 then position = 360 end
  db.minimap.minimapPos = position
end

local function SanitizeTracks(db)
  local source = U.SafeTable(db.tracks) or {}
  local numericKeys = {}
  for key in pairs(source) do
    if type(key) == "number" and key >= 1 then numericKeys[#numericKeys + 1] = key end
  end
  table.sort(numericKeys)

  local nextUID = U.SafeNumber(db.nextUID) or 1
  nextUID = math.max(1, math.floor(nextUID + 0.5))
  local seenUID = {}
  local seenTrack = {}
  local output = {}

  for _, key in ipairs(numericKeys) do
    if #output >= TRACK_CAP then break end
    local entry = U.SafeTable(source[key])
    if entry then
      local id = U.SafeNumber(entry.id)
      id = id and math.floor(id + 0.5) or nil
      if id and id >= 1 then
        local kind = U.SafeString(entry.kind) or "AURA"
        if kind ~= "SPELL" and kind ~= "AURA" then kind = "AURA" end

        local uid = U.SafeNumber(entry.uid)
        uid = uid and math.floor(uid + 0.5) or nil
        if not uid or uid < 1 or seenUID[uid] then
          while seenUID[nextUID] do nextUID = nextUID + 1 end
          uid = nextUID
          nextUID = nextUID + 1
        end
        seenUID[uid] = true
        if uid >= nextUID then nextUID = uid + 1 end

        local clean = {
          uid = uid,
          id = id,
          kind = kind,
          enabled = U.SafeBool(entry.enabled) ~= false,
        }

        local dedupeKey
        if kind == "SPELL" then
          local showWhen = U.SafeString(entry.showWhen) or "ALWAYS"
          if showWhen ~= "ALWAYS" and showWhen ~= "READY" and showWhen ~= "NOTREADY" then
            showWhen = "ALWAYS"
          end
          clean.showWhen = showWhen
          clean.ignoreGCD = U.SafeBool(entry.ignoreGCD) ~= false
          dedupeKey = "SPELL:" .. id
        else
          local showWhen = U.SafeString(entry.showWhen) or "ALWAYS"
          if showWhen ~= "ALWAYS" and showWhen ~= "ACTIVE" then showWhen = "ALWAYS" end
          clean.showWhen = showWhen

          local unit = U.SafeString(entry.unit) or "player"
          if unit ~= "player" and unit ~= "target" and unit ~= "focus" then unit = "player" end
          clean.unit = unit

          local auraType = U.SafeString(entry.auraType) or "HELPFUL"
          if auraType ~= "HELPFUL" and auraType ~= "HARMFUL" then auraType = "HELPFUL" end
          clean.auraType = auraType
          dedupeKey = table.concat({ "AURA", id, unit, auraType }, ":")
        end

        if not seenTrack[dedupeKey] then
          seenTrack[dedupeKey] = true
          output[#output + 1] = clean
        end
      end
    end
  end

  db.tracks = output
  db.nextUID = nextUID
end

local function SanitizeDB(db)
  db.debug = U.SafeBool(db.debug) == true
  SanitizeMinimap(db)
  SanitizeFrame(db)
  SanitizeTracks(db)
  db.version = Addon.DB_VERSION
end

function Addon:AllocateTrackUID()
  local nextUID = self.db and U.SafeNumber(self.db.nextUID) or 1
  nextUID = math.max(1, math.floor((nextUID or 1) + 0.5))
  self.db.nextUID = nextUID + 1
  return nextUID
end

function Addon:InitDB()
  local db = U.SafeTable(RothSpellTrackerDB)
  if not db then db = NewDB() end

  local version = U.SafeNumber(db.version)
  if version == 1 then
    MigrateV1toV2(db)
    version = 2
  end
  if version == 2 then
    MigrateV2toV3(db)
    version = 3
  end
  if version ~= Addon.DB_VERSION then
    local oldMinimap = U.DeepCopy(U.SafeTable(db.minimap))
    local oldFrame = U.DeepCopy(U.SafeTable(db.frame))
    db = NewDB()
    if oldMinimap then db.minimap = oldMinimap end
    if oldFrame then db.frame = oldFrame end
  end

  U.CopyDefaults(db, Addon.Defaults)
  SanitizeDB(db)
  RothSpellTrackerDB = db
  self.db = db
end

function Addon:RequestRebuild()
  if self.Display and self.Display.RequestRebuild then self.Display:RequestRebuild() end
  if self.Tracker and self.Tracker.RequestRefresh then self.Tracker:RequestRefresh() end
end

function Addon:ResetDB()
  local keepMinimap = self.db and U.DeepCopy(U.SafeTable(self.db.minimap)) or nil
  RothSpellTrackerDB = NewDB()
  if keepMinimap then RothSpellTrackerDB.minimap = keepMinimap end
  self.db = RothSpellTrackerDB
  SanitizeDB(self.db)
  self:UpdateMinimapIcon()
  self:RequestRebuild()
  self:Log("INFO", "DB reset")
end

function Addon:ApplyFrameLock()
  if self.Display and self.Display.ApplyLock then self.Display:ApplyLock() end
end

local function Slash(message)
  message = U.Trim(message)
  if message == "" or message == "config" then
    Addon:ToggleConfig()
    return
  end

  local command, argument = message:match("^(%S+)%s*(.-)$")
  command = (command or ""):lower()
  if command == "debug" then
    local enabled = argument == "1" or argument == "on" or argument == "true"
    Addon:SetDebug(enabled)
    Addon:Log("INFO", enabled and "Debug ON" or "Debug OFF")
  elseif command == "lock" then
    Addon.db.frame.locked = true
    Addon:ApplyFrameLock()
    Addon:Log("INFO", "Frame locked")
  elseif command == "unlock" then
    Addon.db.frame.locked = false
    Addon:ApplyFrameLock()
    Addon:Log("INFO", "Frame unlocked")
  elseif command == "log" then
    Addon:DumpLog(U.ToNumber(argument) or 50)
  elseif command == "reset" then
    Addon:ResetDB()
  else
    Addon:Log("INFO", "Commands: /rothspelltracker, /rspellt, /spelltracker; debug on|off; lock; unlock; log [N]; reset")
  end
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:SetScript("OnEvent", function(_, event, argument)
  if event == "ADDON_LOADED" then
    if argument ~= ADDON then return end
    Addon:InitLogger()
    Addon:InitDB()
    Addon:InitMinimapIcon()
    Addon:UpdateMinimapIcon()

    SLASH_ROTHSPELLTRACKER1 = "/rothspelltracker"
    SLASH_ROTHSPELLTRACKER2 = "/rspellt"
    SLASH_ROTHSPELLTRACKER3 = "/spelltracker"
    SlashCmdList.ROTHSPELLTRACKER = Slash
    Addon:Log("INFO", "Loaded v" .. Addon.VERSION)
  elseif event == "PLAYER_LOGIN" then
    if Addon.Display and Addon.Display.Init then Addon.Display:Init() end
    if Addon.ManagedAuras and Addon.ManagedAuras.Init then Addon.ManagedAuras:Init() end
    if Addon.Tracker and Addon.Tracker.Init then Addon.Tracker:Init() end
    Addon:RequestRebuild()
  end
end)

local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

RothSpellTrackerDB = RothSpellTrackerDB or nil

local TRACK_CAP = Addon.MAX_TRACKS or 500
local TRACK_INPUT_CAP = Addon.MAX_TRACK_INPUTS or (TRACK_CAP * 4)
local SPELL_ID_CAP = Addon.MAX_SPELL_ID or 2147483647
local LEGACY_ID_TEXT_CAP = Addon.MAX_LEGACY_ID_TEXT or 64
local ENUM_TEXT_CAP = Addon.MAX_ENUM_TEXT or 32
local ICON_SIZE_MIN = Addon.MIN_ICON_SIZE or 24
local ICON_SIZE_MAX = Addon.MAX_ICON_SIZE or 96
local ICON_SPACING_MAX = Addon.MAX_ICON_SPACING or 30
local RESET_DIALOG_KEY = "ROTH_SPELL_TRACKER_CONFIRM_RESET"
local VALID_POINTS = {
  TOPLEFT = true, TOP = true, TOPRIGHT = true,
  LEFT = true, CENTER = true, RIGHT = true,
  BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function ShortString(value, maximumLength)
  local text = U.SafeString(value)
  if not text or #text > (maximumLength or ENUM_TEXT_CAP) then return nil end
  return text
end

local function ParseLegacySpellID(value)
  local number = U.SafeNumber(value)
  if number then return U.SafeInteger(number, 1, SPELL_ID_CAP) end

  local text = U.SafeString(value)
  if not text or #text > LEGACY_ID_TEXT_CAP then return nil end
  return U.SafeInteger(U.ToNumber(text), 1, SPELL_ID_CAP)
end

local function LegacySourceOrder(rawID, id)
  if type(rawID) == "number" then return 0, tostring(id) end

  local text = ShortString(rawID, LEGACY_ID_TEXT_CAP) or ""
  local canonical = tostring(id)
  if text == canonical then return 1, text end
  if U.Trim(text) == canonical then return 2, text end
  return 3, text
end

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

local function CopyMinimapPreferences(source, destination)
  local minimap = source and U.SafeTable(source.minimap)
  if not minimap then return end

  local hide = U.SafeBool(minimap.hide)
  if hide ~= nil then destination.minimap.hide = hide end
  local position = U.SafeNumber(minimap.minimapPos)
  if position then destination.minimap.minimapPos = position end
end

local function CopyFramePreferences(source, destination)
  local frame = source and U.SafeTable(source.frame)
  if not frame then return end

  local point = ShortString(frame.point, 16)
  local relativePoint = ShortString(frame.relPoint, 16)
  local grow = ShortString(frame.grow)
  local x = U.SafeNumber(frame.x)
  local y = U.SafeNumber(frame.y)
  local size = U.SafeNumber(frame.size)
  local spacing = U.SafeNumber(frame.spacing)
  local locked = U.SafeBool(frame.locked)

  if point then destination.frame.point = point end
  if relativePoint then destination.frame.relPoint = relativePoint end
  if grow then destination.frame.grow = grow end
  if x then destination.frame.x = x end
  if y then destination.frame.y = y end
  if size then destination.frame.size = size end
  if spacing then destination.frame.spacing = spacing end
  if locked ~= nil then destination.frame.locked = locked end
end

local function MigrateV1toV2(db)
  local spells = U.SafeTable(db.spells)
  local tracks = {}
  local scanned = 0
  local overflow = false

  if spells then
    for rawID, rawEntry in pairs(spells) do
      scanned = scanned + 1
      if scanned > TRACK_INPUT_CAP then
        overflow = true
        break
      end

      local id = ParseLegacySpellID(rawID)
      local entry = U.SafeTable(rawEntry)
      if id and entry then
        local mode = ShortString(entry.mode) or "AURA"
        local kind = mode == "COOLDOWN" and "SPELL" or "AURA"
        local unit = ShortString(entry.unit) or "player"
        if unit ~= "player" and unit ~= "target" and unit ~= "focus" then unit = "player" end
        local auraType = ShortString(entry.auraType) or "HELPFUL"
        if auraType ~= "HELPFUL" and auraType ~= "HARMFUL" then auraType = "HELPFUL" end
        local sourceRank, sourceKey = LegacySourceOrder(rawID, id)

        tracks[#tracks + 1] = {
          id = id,
          kind = kind,
          enabled = U.SafeBool(entry.enabled) ~= false,
          showWhen = ShortString(entry.showWhen) or (kind == "SPELL" and "READY" or "ACTIVE"),
          ignoreGCD = U.SafeBool(entry.ignoreGCD) ~= false,
          unit = unit,
          auraType = auraType,
          _legacySourceRank = sourceRank,
          _legacySourceKey = sourceKey,
        }
      end
    end
  end

  if overflow then
    tracks = {}
  else
    table.sort(tracks, function(a, b)
      if a.id ~= b.id then return a.id < b.id end
      if a.kind ~= b.kind then return a.kind < b.kind end

      local aUnit = a.kind == "AURA" and a.unit or ""
      local bUnit = b.kind == "AURA" and b.unit or ""
      if aUnit ~= bUnit then return aUnit < bUnit end

      local aAuraType = a.kind == "AURA" and a.auraType or ""
      local bAuraType = b.kind == "AURA" and b.auraType or ""
      if aAuraType ~= bAuraType then return aAuraType < bAuraType end

      if a._legacySourceRank ~= b._legacySourceRank then
        return a._legacySourceRank < b._legacySourceRank
      end
      return a._legacySourceKey < b._legacySourceKey
    end)
  end

  db.tracks = tracks
  db.spells = nil
  db.version = 2
end

local function MigrateV2toV3(db)
  local tracks = U.SafeTable(db.tracks) or {}
  local length = #tracks
  if length > TRACK_INPUT_CAP then
    db.tracks = {}
    db.version = 3
    return
  end

  for index = 1, length do
    local entry = U.SafeTable(tracks[index])
    if entry and ShortString(entry.kind) == "AURA" then
      local showWhen = ShortString(entry.showWhen)
      if showWhen ~= "ACTIVE" and showWhen ~= "ALWAYS" then entry.showWhen = "ALWAYS" end
      entry.minStacks = nil
    end
  end
  db.version = 3
end

local function NormalizePoint(value, fallback)
  value = ShortString(value, 16)
  if value and VALID_POINTS[value] then return value end
  return fallback
end

local function SanitizeFrame(db)
  db.frame = U.SafeTable(db.frame) or {}
  local frame = db.frame
  frame.point = NormalizePoint(frame.point, "CENTER")
  frame.relPoint = NormalizePoint(frame.relPoint, "CENTER")

  local x = U.SafeNumber(frame.x) or 0
  local y = U.SafeNumber(frame.y) or -120
  if x < -32768 then x = -32768 elseif x > 32768 then x = 32768 end
  if y < -32768 then y = -32768 elseif y > 32768 then y = 32768 end
  frame.x = x
  frame.y = y

  local size = U.SafeNumber(frame.size) or 44
  if size < ICON_SIZE_MIN then size = ICON_SIZE_MIN elseif size > ICON_SIZE_MAX then size = ICON_SIZE_MAX end
  frame.size = math.floor(size + 0.5)

  local spacing = U.SafeNumber(frame.spacing) or 6
  if spacing < 0 then spacing = 0 elseif spacing > ICON_SPACING_MAX then spacing = ICON_SPACING_MAX end
  frame.spacing = math.floor(spacing + 0.5)

  frame.locked = U.SafeBool(frame.locked) ~= false
  local grow = ShortString(frame.grow) or "RIGHT"
  if grow ~= "RIGHT" and grow ~= "LEFT" and grow ~= "UP" and grow ~= "DOWN" then grow = "RIGHT" end
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
  local scanned = 0

  for key in pairs(source) do
    scanned = scanned + 1
    if scanned > TRACK_INPUT_CAP then
      db.tracks = {}
      db.nextUID = 1
      return
    end
    if U.CanAccess(key) and type(key) == "number" and key >= 1 and key == math.floor(key) then
      numericKeys[#numericKeys + 1] = key
    end
  end
  table.sort(numericKeys)

  local output = {}
  local seenTrack = {}
  local seenUID = {}
  local uidCursor = 1

  local function ClaimUID(requested)
    requested = U.SafeInteger(requested, 1, TRACK_CAP)
    if requested and not seenUID[requested] then
      seenUID[requested] = true
      return requested
    end

    for offset = 0, TRACK_CAP - 1 do
      local candidate = ((uidCursor + offset - 1) % TRACK_CAP) + 1
      if not seenUID[candidate] then
        seenUID[candidate] = true
        uidCursor = (candidate % TRACK_CAP) + 1
        return candidate
      end
    end
    return nil
  end

  for _, key in ipairs(numericKeys) do
    if #output >= TRACK_CAP then break end
    local entry = U.SafeTable(source[key])
    if entry then
      local id = U.SafeInteger(entry.id, 1, SPELL_ID_CAP)
      if id then
        local kind = ShortString(entry.kind) or "AURA"
        if kind ~= "SPELL" and kind ~= "AURA" then kind = "AURA" end

        local clean = {
          id = id,
          kind = kind,
          enabled = U.SafeBool(entry.enabled) ~= false,
        }

        local dedupeKey
        if kind == "SPELL" then
          local showWhen = ShortString(entry.showWhen) or "ALWAYS"
          if showWhen ~= "ALWAYS" and showWhen ~= "READY" and showWhen ~= "NOTREADY" then showWhen = "ALWAYS" end
          clean.showWhen = showWhen
          clean.ignoreGCD = U.SafeBool(entry.ignoreGCD) ~= false
          dedupeKey = "SPELL:" .. id
        else
          local showWhen = ShortString(entry.showWhen) or "ALWAYS"
          if showWhen ~= "ALWAYS" and showWhen ~= "ACTIVE" then showWhen = "ALWAYS" end
          clean.showWhen = showWhen

          local unit = ShortString(entry.unit) or "player"
          if unit ~= "player" and unit ~= "target" and unit ~= "focus" then unit = "player" end
          clean.unit = unit

          local auraType = ShortString(entry.auraType) or "HELPFUL"
          if auraType ~= "HELPFUL" and auraType ~= "HARMFUL" then auraType = "HELPFUL" end
          clean.auraType = auraType
          dedupeKey = table.concat({ "AURA", id, unit, auraType }, ":")
        end

        if not seenTrack[dedupeKey] then
          local uid = ClaimUID(entry.uid)
          if not uid then break end
          clean.uid = uid
          seenTrack[dedupeKey] = true
          output[#output + 1] = clean
        end
      end
    end
  end

  local nextUID = 1
  for candidate = 1, TRACK_CAP do
    if not seenUID[candidate] then nextUID = candidate break end
  end

  db.tracks = output
  db.nextUID = nextUID
end

local function CanonicalizeDB(db)
  db.debug = U.SafeBool(db.debug) == true
  SanitizeMinimap(db)
  SanitizeFrame(db)
  SanitizeTracks(db)

  local minimap = db.minimap
  local frame = db.frame
  return {
    version = Addon.DB_VERSION,
    nextUID = db.nextUID,
    debug = db.debug,
    minimap = {
      hide = minimap.hide,
      minimapPos = minimap.minimapPos,
    },
    frame = {
      point = frame.point,
      relPoint = frame.relPoint,
      x = frame.x,
      y = frame.y,
      size = frame.size,
      spacing = frame.spacing,
      locked = frame.locked,
      grow = frame.grow,
    },
    tracks = db.tracks,
  }
end

local function BuildRuntimeFallback(source)
  local db = NewDB()
  CopyMinimapPreferences(source, db)
  CopyFramePreferences(source, db)
  return CanonicalizeDB(db)
end

function Addon:AllocateTrackUID()
  if not self.db then return nil end

  local used = {}
  for _, entry in ipairs(U.SafeTable(self.db.tracks) or {}) do
    local uid = U.SafeTable(entry) and U.SafeInteger(entry.uid, 1, TRACK_CAP) or nil
    if uid then used[uid] = true end
  end

  local start = U.SafeInteger(self.db.nextUID, 1, TRACK_CAP) or 1
  for offset = 0, TRACK_CAP - 1 do
    local candidate = ((start + offset - 1) % TRACK_CAP) + 1
    if not used[candidate] then
      self.db.nextUID = (candidate % TRACK_CAP) + 1
      return candidate
    end
  end
  return nil
end

function Addon:IsDBReadOnly()
  return self.dbReadOnly == true
end

function Addon:InitDB()
  self.dbReadOnly = false
  self.dbSourceVersion = nil

  local source = U.SafeTable(RothSpellTrackerDB)
  local version = source and U.SafeInteger(source.version, 0) or nil
  if source and version and version > Addon.DB_VERSION then
    self.dbReadOnly = true
    self.dbSourceVersion = version
    self.db = BuildRuntimeFallback(source)
    return
  end

  local db = source or NewDB()
  if version == 1 then MigrateV1toV2(db); version = 2 end
  if version == 2 then MigrateV2toV3(db); version = 3 end
  if version ~= Addon.DB_VERSION then
    db = BuildRuntimeFallback(source)
  else
    U.CopyDefaults(db, Addon.Defaults)
    db = CanonicalizeDB(db)
  end

  RothSpellTrackerDB = db
  self.db = db
end

function Addon:RequestRebuild()
  if self.Display and self.Display.RequestRebuild then self.Display:RequestRebuild() end
  if self.Tracker and self.Tracker.RequestRefresh then self.Tracker:RequestRefresh() end
end

function Addon:RequestLayout()
  if self.Display and self.Display.RequestLayout then self.Display:RequestLayout() end
end

function Addon:ResetDB()
  local db = NewDB()
  CopyMinimapPreferences(self.db, db)
  db = CanonicalizeDB(db)

  RothSpellTrackerDB = db
  self.db = db
  self.dbReadOnly = false
  self.dbSourceVersion = nil
  self:UpdateMinimapIcon()
  self:RequestRebuild()
  self:Notify("INFO", "Database reset")
end

local function CompleteConfirmedReset()
  Addon:ResetDB()
  local ui = Addon.UI
  if ui and type(ui.OnDatabaseReset) == "function" then ui:OnDatabaseReset() end
end

function Addon:ConfirmResetDB()
  if type(StaticPopupDialogs) ~= "table" or type(StaticPopup_Show) ~= "function" then
    self:Notify("ERROR", "Reset confirmation UI is unavailable")
    return false
  end

  local dialog = StaticPopupDialogs[RESET_DIALOG_KEY]
  if not dialog then
    dialog = {
      text = "",
      button1 = _G.YES or "Yes",
      button2 = _G.NO or "No",
      OnAccept = CompleteConfirmedReset,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
    StaticPopupDialogs[RESET_DIALOG_KEY] = dialog
  end

  if self.dbReadOnly then
    dialog.text = "The saved database was created by a newer addon schema. Resetting will permanently replace it. Continue?"
  else
    dialog.text = "Reset Roth Spell Tracker settings and remove all tracks?"
  end
  StaticPopup_Show(RESET_DIALOG_KEY)
  return true
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
    Addon:Notify("INFO", enabled and "Debug enabled" or "Debug disabled")
  elseif command == "lock" then
    Addon.db.frame.locked = true
    Addon:ApplyFrameLock()
    Addon:Notify("INFO", "Frame locked")
  elseif command == "unlock" then
    Addon.db.frame.locked = false
    Addon:ApplyFrameLock()
    Addon:Notify("INFO", "Frame unlocked")
  elseif command == "log" then
    Addon:DumpLog(U.ToNumber(argument) or 50)
  elseif command == "reset" then
    Addon:ConfirmResetDB()
  else
    Addon:Notify("INFO", "Commands: /rothspelltracker; debug on|off; lock; unlock; log [N]; reset")
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

    if Addon.dbReadOnly then
      Addon:Notify(
        "WARN",
        string.format(
          "Saved database schema %d is newer than supported schema %d. Running with session-only settings until Reset DB replaces it.",
          Addon.dbSourceVersion,
          Addon.DB_VERSION
        )
      )
    end
  elseif event == "PLAYER_LOGIN" then
    if Addon.ManagedAuras and Addon.ManagedAuras.Init then Addon.ManagedAuras:Init() end
    if Addon.Display and Addon.Display.Init then Addon.Display:Init() end
    if Addon.Tracker and Addon.Tracker.Init then Addon.Tracker:Init() end
    Addon:RequestRebuild()
  end
end)

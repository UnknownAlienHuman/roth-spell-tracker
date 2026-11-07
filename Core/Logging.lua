local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

local DEFAULT_CAP = 250
local PREFIX = "|cff66c0ffRothSpellTracker|r "

local function Now()
  if type(date) ~= "function" then return "--:--:--" end
  local ok, value = pcall(date, "%H:%M:%S")
  return ok and U.SafeString(value) or "--:--:--"
end

function Addon:InitLogger()
  self._logCap = DEFAULT_CAP
  self._log = {}
  self._logStart = 1
  self._logCount = 0
end

function Addon:SetDebug(enabled)
  if self.db then self.db.debug = enabled == true end
end

function Addon:IsDebug()
  return self.db and self.db.debug == true
end

function Addon:Log(level, message)
  local safeLevel = U.SafeString(level) or "INFO"
  local safeMessage = U.SafeToString(message, "<unavailable>")
  local line = string.format("[%s] %s: %s", Now(), safeLevel, safeMessage)

  self._log = self._log or {}
  local cap = self._logCap or DEFAULT_CAP
  local start = self._logStart or 1
  local count = self._logCount or 0
  local index

  if count < cap then
    index = ((start + count - 1) % cap) + 1
    count = count + 1
  else
    index = start
    start = (start % cap) + 1
  end

  self._log[index] = line
  self._logStart = start
  self._logCount = count

  if self:IsDebug() and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. line)
  end
end

function Addon:Notify(level, message)
  local safeLevel = U.SafeString(level) or "INFO"
  local safeMessage = U.SafeToString(message, "<unavailable>")
  self:Log(safeLevel, safeMessage)
  if not self:IsDebug() and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. safeMessage)
  end
end

function Addon:DumpLog(maxLines)
  maxLines = U.SafeNumber(maxLines) or 50
  maxLines = math.floor(maxLines)
  if maxLines < 1 then maxLines = 1 end

  local cap = self._logCap or DEFAULT_CAP
  if maxLines > cap then maxLines = cap end

  local count = self._logCount or 0
  if maxLines > count then maxLines = count end
  local start = self._logStart or 1
  local skip = count - maxLines

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. "---- log ----")
    for offset = skip, count - 1 do
      local index = ((start + offset - 1) % cap) + 1
      local line = self._log and self._log[index]
      if U.SafeString(line) then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. line) end
    end
  end
end

local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

local DEFAULT_CAP = 250

local function Now()
  if type(date) ~= "function" then return "--:--:--" end
  local ok, value = pcall(date, "%H:%M:%S")
  return ok and U.SafeString(value) or "--:--:--"
end

function Addon:InitLogger()
  self._logCap = DEFAULT_CAP
  self._log = {}
  self._logN = 0
end

function Addon:SetDebug(enabled)
  if self.db then
    self.db.debug = enabled == true
  end
end

function Addon:IsDebug()
  return self.db and self.db.debug == true
end

function Addon:Log(level, message)
  local safeLevel = U.SafeString(level) or "INFO"
  local safeMessage = U.SafeToString(message, "<unavailable>")
  local line = string.format("[%s] %s: %s", Now(), safeLevel, safeMessage)

  local n = (self._logN or 0) + 1
  self._logN = n
  self._log[(n - 1) % (self._logCap or DEFAULT_CAP) + 1] = line

  if self:IsDebug() and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66c0ffRothSpellTracker|r " .. line)
  end
end

function Addon:DumpLog(maxLines)
  maxLines = U.SafeNumber(maxLines) or 50
  if maxLines < 1 then maxLines = 1 end
  local cap = self._logCap or DEFAULT_CAP
  if maxLines > cap then maxLines = cap end

  local n = self._logN or 0
  local startIndex = math.max(1, n - maxLines + 1)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66c0ffRothSpellTracker|r ---- log ----")
    for sequence = startIndex, n do
      local index = (sequence - 1) % cap + 1
      local line = self._log[index]
      if U.SafeString(line) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66c0ffRothSpellTracker|r " .. line)
      end
    end
  end
end

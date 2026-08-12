local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

local DEFAULT_CAP = 250

local function Now()
  return date("%H:%M:%S")
end

function Addon:InitLogger()
  self._logCap = DEFAULT_CAP
  self._log = {}
  self._logN = 0
end

function Addon:SetDebug(enabled)
  if self.db then
    self.db.debug = enabled and true or false
  end
end

function Addon:IsDebug()
  return self.db and self.db.debug == true
end

function Addon:Log(level, msg)
  if not msg then return end
  level = level or "INFO"
  local line = ("[%s] %s: %s"):format(Now(), level, tostring(msg))

  -- ring buffer
  local n = (self._logN or 0) + 1
  self._logN = n
  self._log[(n - 1) % (self._logCap or DEFAULT_CAP) + 1] = line

  if self:IsDebug() and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66c0ffRothSpellTracker|r " .. line)
  end
end

function Addon:DumpLog(maxLines)
  maxLines = tonumber(maxLines) or 50
  if maxLines < 1 then maxLines = 1 end
  if maxLines > (self._logCap or DEFAULT_CAP) then maxLines = (self._logCap or DEFAULT_CAP) end

  local out = {}
  local n = self._logN or 0
  local cap = self._logCap or DEFAULT_CAP
  local start = math.max(1, n - maxLines + 1)

  for i = start, n do
    local idx = (i - 1) % cap + 1
    out[#out + 1] = self._log[idx]
  end

  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66c0ffRothSpellTracker|r ---- log ----")
    for i = 1, #out do
      DEFAULT_CHAT_FRAME:AddMessage("|cff66c0ffRothSpellTracker|r " .. out[i])
    end
  end
end

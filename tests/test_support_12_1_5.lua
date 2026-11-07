local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function canaccessvalue() return true end
function canaccesstable() return true end
function issecretvalue() return false end

local messages = {}
DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, message) messages[#messages + 1] = message end,
}

local LDB = {}
function LDB:NewDataObject(name, object)
  self.name = name
  self.object = object
  return object
end

local DBIcon = {}
function DBIcon:Register(name, object, db)
  self.name = name
  self.object = object
  self.db = db
end
function DBIcon:Refresh(name, db)
  self.refreshName = name
  self.db = db
  self.refreshCount = (self.refreshCount or 0) + 1
end
function DBIcon:Show(name) self.shown = name end
function DBIcon:Hide(name) self.hidden = name end

function LibStub(name)
  if name == "LibDataBroker-1.1" then return LDB end
  if name == "LibDBIcon-1.0" then return DBIcon end
end

local NS = { Addon = {} }
assert(loadfile("Core/Config.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Logging.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Minimap.lua"))("RothSpellTracker", NS)
local Addon = NS.Addon
Addon.db = {
  debug = false,
  minimap = { hide = false, minimapPos = 220 },
  frame = { locked = true },
}
Addon.ToggleConfig = function() end
Addon.ApplyFrameLock = function() end

Addon:InitLogger()
Addon:InitMinimapIcon()
local originalMinimap = Addon.db.minimap
assertEq(DBIcon.db, originalMinimap, "initial minimap settings reference")

Addon.db.minimap = { hide = true, minimapPos = 90 }
Addon:UpdateMinimapIcon()
assertEq(DBIcon.db, Addon.db.minimap, "LibDBIcon reference refreshed after DB replacement")
assertEq(DBIcon.refreshCount, 1, "LibDBIcon refresh count")
assertEq(DBIcon.hidden, "RothSpellTracker", "minimap hide applied")

for index = 1, 300 do Addon:Log("INFO", "line " .. index) end
assertEq(Addon._logCount, 250, "bounded log count")
assert(#Addon._log <= 250, "bounded log storage")

messages = {}
Addon:DumpLog(3.9)
assertEq(#messages, 4, "log header plus floored line count")
assert(messages[2]:find("line 298", 1, true), "oldest requested ring line")
assert(messages[4]:find("line 300", 1, true), "latest ring line")

messages = {}
Addon:Notify("ERROR", "visible error")
assertEq(#messages, 1, "notification visible when debug is disabled")
assert(messages[1]:find("visible error", 1, true), "notification content")

Addon.db.debug = true
messages = {}
Addon:Notify("INFO", "debug notice")
assertEq(#messages, 1, "debug notification should not duplicate chat output")
assert(messages[1]:find("debug notice", 1, true), "debug notification content")

print("PASS: support layer bounds logs, exposes validation messages and refreshes LibDBIcon DB ownership")

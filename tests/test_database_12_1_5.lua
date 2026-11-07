local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function canaccessvalue() return true end
function canaccesstable() return true end
function issecretvalue() return false end

SlashCmdList = {}
StaticPopupDialogs = {}
local shownPopup
function StaticPopup_Show(key) shownPopup = key end

function CreateFrame()
  local frame = { events = {} }
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:SetScript(name, callback) self[name] = callback end
  return frame
end

local function ValidFrame()
  return {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -120,
    size = 44,
    spacing = 6,
    locked = true,
    grow = "RIGHT",
  }
end

local tracks = {
  { uid = 1, id = math.huge, kind = "SPELL" },
  { uid = 2, id = 1.5, kind = "SPELL" },
  { uid = 9999, id = 1001, kind = "SPELL", enabled = true, showWhen = "ALWAYS", ignoreGCD = true },
  { uid = 9999, id = 1001, kind = "SPELL", enabled = true, showWhen = "READY", ignoreGCD = false },
}
for index = 5, 505 do
  tracks[index] = {
    uid = 10000 + index,
    id = 1000 + index,
    kind = "SPELL",
    enabled = true,
    showWhen = "ALWAYS",
    ignoreGCD = true,
  }
end

RothSpellTrackerDB = {
  version = 3,
  nextUID = math.huge,
  debug = false,
  futureRoot = { retain = false },
  minimap = { hide = false, minimapPos = 220, futureMinimap = { retain = false } },
  frame = {
    point = "BROKEN_POINT",
    relPoint = "ALSO_BROKEN",
    x = math.huge,
    y = -math.huge,
    size = 999,
    spacing = -10,
    locked = true,
    grow = "SIDEWAYS",
    futureFrame = { retain = false },
  },
  tracks = tracks,
}

local NS = { Addon = {} }
assert(loadfile("Core/Config.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Core.lua"))("RothSpellTracker", NS)
local Addon = NS.Addon
Addon:InitDB()

assertEq(Addon.VERSION, "0.4.4", "addon version")
assertEq(Addon.MAX_TRACK_INPUTS, Addon.MAX_TRACKS * 4, "persistence scan bound")
assertEq(Addon.MAX_LEGACY_ID_TEXT, 64, "legacy key length bound")
assertEq(Addon.MAX_ENUM_TEXT, 32, "enum length bound")
assertEq(#Addon.db.tracks, Addon.MAX_TRACKS, "track cap")
assertEq(Addon.db.frame.point, "CENTER", "invalid point fallback")
assertEq(Addon.db.frame.relPoint, "CENTER", "invalid relative point fallback")
assertEq(Addon.db.frame.x, 0, "infinite x fallback")
assertEq(Addon.db.frame.y, -120, "infinite y fallback")
assertEq(Addon.db.frame.size, Addon.MAX_ICON_SIZE, "size clamp")
assertEq(Addon.db.frame.spacing, 0, "spacing clamp")
assertEq(Addon.db.frame.grow, "RIGHT", "grow fallback")
assertEq(Addon.db.futureRoot, nil, "unknown root key retained")
assertEq(Addon.db.minimap.futureMinimap, nil, "unknown minimap key retained")
assertEq(Addon.db.frame.futureFrame, nil, "unknown frame key retained")
assertEq(Addon.Util.SafeNumber(math.huge), nil, "positive infinity rejection")
assertEq(Addon.Util.SafeNumber(-math.huge), nil, "negative infinity rejection")

local seenUID = {}
local seenSpell = {}
for _, entry in ipairs(Addon.db.tracks) do
  assert(entry.uid >= 1 and entry.uid <= Addon.MAX_TRACKS, "uid outside bounded domain")
  assert(not seenUID[entry.uid], "duplicate uid")
  assert(not seenSpell[entry.id], "duplicate spell identity")
  assert(entry.id == math.floor(entry.id), "fractional spell ID survived")
  assert(entry.id >= 1 and entry.id <= Addon.MAX_SPELL_ID, "spell ID outside bounded domain")
  seenUID[entry.uid] = true
  seenSpell[entry.id] = true
end
assertEq(seenSpell[1001], true, "valid row after malformed prefix was lost")

assertEq(Addon:AllocateTrackUID(), nil, "full UID domain should reject allocation")
local removedUID = Addon.db.tracks[250].uid
table.remove(Addon.db.tracks, 250)
local reusedUID = Addon:AllocateTrackUID()
assertEq(reusedUID, removedUID, "allocator should reuse a free bounded UID")

local duplicateHeavyLegacy = {}
for index = 1, Addon.MAX_TRACKS do
  duplicateHeavyLegacy[string.rep(" ", index) .. "1"] = {
    mode = "COOLDOWN",
    enabled = true,
    showWhen = "READY",
    ignoreGCD = true,
  }
end
duplicateHeavyLegacy["9999"] = {
  mode = "COOLDOWN",
  enabled = true,
  showWhen = "READY",
  ignoreGCD = true,
}
RothSpellTrackerDB = {
  version = 1,
  minimap = { hide = false, minimapPos = 220 },
  frame = ValidFrame(),
  spells = duplicateHeavyLegacy,
}
Addon:InitDB()
assertEq(#Addon.db.tracks, 2, "legacy aliases must deduplicate before the runtime cap")
local migratedIDs = {}
for _, entry in ipairs(Addon.db.tracks) do migratedIDs[entry.id] = true end
assertEq(migratedIDs[1], true, "deduplicated legacy identity missing")
assertEq(migratedIDs[9999], true, "later distinct legacy identity was evicted by aliases")

RothSpellTrackerDB = {
  version = 1,
  minimap = { hide = false, minimapPos = 220 },
  frame = ValidFrame(),
  spells = {
    [42] = { mode = "COOLDOWN", enabled = false, showWhen = "NOTREADY", ignoreGCD = false },
    ["42"] = { mode = "COOLDOWN", enabled = true, showWhen = "READY", ignoreGCD = true },
    [" 42 "] = { mode = "COOLDOWN", enabled = true, showWhen = "ALWAYS", ignoreGCD = true },
    [string.rep("9", Addon.MAX_LEGACY_ID_TEXT + 1)] = { mode = "COOLDOWN" },
  },
}
Addon:InitDB()
assertEq(#Addon.db.tracks, 1, "legacy aliases should collapse to one canonical identity")
assertEq(Addon.db.tracks[1].id, 42, "canonical legacy ID")
assertEq(Addon.db.tracks[1].enabled, false, "numeric legacy key must win deterministically")
assertEq(Addon.db.tracks[1].showWhen, "NOTREADY", "canonical legacy settings")
assertEq(Addon.db.tracks[1].ignoreGCD, false, "canonical legacy GCD setting")

local oversized = {}
for index = 1, Addon.MAX_TRACK_INPUTS + 1 do
  oversized[index] = {
    uid = index,
    id = 100000 + index,
    kind = "SPELL",
    enabled = true,
    showWhen = "ALWAYS",
    ignoreGCD = true,
  }
end
RothSpellTrackerDB = {
  version = 3,
  minimap = { hide = false, minimapPos = 220 },
  frame = ValidFrame(),
  tracks = oversized,
}
Addon:InitDB()
assertEq(#Addon.db.tracks, 0, "oversized current-schema input must reset deterministically")
assertEq(Addon.db.nextUID, 1, "oversized current-schema UID reset")

local legacy = {}
for index = 1, Addon.MAX_TRACK_INPUTS + 1 do
  legacy[tostring(index)] = {
    mode = "COOLDOWN",
    enabled = true,
    showWhen = "READY",
    ignoreGCD = true,
  }
end
RothSpellTrackerDB = {
  version = 1,
  minimap = { hide = false, minimapPos = 220 },
  frame = ValidFrame(),
  spells = legacy,
}
Addon:InitDB()
assertEq(Addon.db.version, Addon.DB_VERSION, "oversized legacy schema migration version")
assertEq(#Addon.db.tracks, 0, "oversized legacy input must not retain a pairs-order prefix")
assertEq(Addon.db.nextUID, 1, "oversized legacy UID reset")

local futureRoot = {
  version = Addon.DB_VERSION + 7,
  minimap = { hide = true, minimapPos = 90, futureField = "keep" },
  frame = ValidFrame(),
  tracks = {
    { uid = 1, id = 12345, kind = "SPELL", enabled = true, futureField = "keep" },
  },
  futurePayload = { sentinel = "preserve" },
}
futureRoot.frame.futureField = "keep"
RothSpellTrackerDB = futureRoot
Addon:InitDB()
assertEq(Addon:IsDBReadOnly(), true, "future schema guard")
assertEq(Addon.dbSourceVersion, futureRoot.version, "future schema version receipt")
assertEq(RothSpellTrackerDB, futureRoot, "future database root must remain untouched")
assertEq(futureRoot.futurePayload.sentinel, "preserve", "future payload preserved")
assertEq(#Addon.db.tracks, 0, "future tracks must not be interpreted by an older schema")
assertEq(Addon.db.minimap.hide, true, "safe minimap preference carried into session view")
assertEq(Addon.db.futurePayload, nil, "future root leaked into session view")
assertEq(Addon.db.minimap.futureField, nil, "future minimap field leaked into session view")
assertEq(Addon.db.frame.futureField, nil, "future frame field leaked into session view")

Addon.UpdateMinimapIcon = function() end
Addon.RequestRebuild = function() end
Addon.Notify = function() end
shownPopup = nil
assertEq(Addon:ConfirmResetDB(), true, "reset confirmation request")
assertEq(shownPopup, "ROTH_SPELL_TRACKER_CONFIRM_RESET", "reset confirmation popup")
assertEq(RothSpellTrackerDB, futureRoot, "confirmation must not mutate before acceptance")
assert(type(StaticPopupDialogs[shownPopup].OnAccept) == "function", "reset accept handler")
StaticPopupDialogs[shownPopup].OnAccept()
assertEq(Addon:IsDBReadOnly(), false, "confirmed reset clears future-schema guard")
assert(RothSpellTrackerDB ~= futureRoot, "confirmed reset replaces future database")
assertEq(RothSpellTrackerDB.version, Addon.DB_VERSION, "confirmed reset schema")

print("PASS: DB migration canonicalizes supported state and preserves future schemas until confirmed replacement")

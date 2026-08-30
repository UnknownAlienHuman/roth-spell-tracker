local SECRET = setmetatable({}, {
  __tostring = function() error("secret value stringified") end,
  __lt = function() error("secret value compared") end,
  __le = function() error("secret value compared") end,
  __add = function() error("secret value added") end,
  __div = function() error("secret value divided") end,
  __index = function() error("secret value indexed") end,
})

local mode = "explicit_gcd"

local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function canaccessvalue(value) return value ~= SECRET end
function issecretvalue(value) return value == SECRET end
function issecrettable() return false end

C_Spell = {
  IsSpellKnown = function() return true end,
  IsSpellUsable = function()
    if mode == "secret" then return SECRET, SECRET end
    return true, false
  end,
  GetSpellTexture = function() return 136243 end,
  GetSpellName = function() return "Test Spell" end,
  GetSpellCharges = function()
    if mode == "charges" then
      return { currentCharges = 0, maxCharges = 2, cooldownStartTime = 10, cooldownDuration = 8, chargeModRate = 1 }
    end
    if mode == "secret" then return SECRET end
    return nil
  end,
  GetSpellCooldown = function()
    if mode == "explicit_gcd" then
      return { startTime = 100, duration = 1.5, isEnabled = true, isOnGCD = true, modRate = 1 }
    elseif mode == "unknown_short" then
      return { startTime = 100, duration = 1.5, isEnabled = true, isOnGCD = SECRET, modRate = 1 }
    elseif mode == "real_cd" then
      return { startTime = 100, duration = 30, isEnabled = true, isOnGCD = false, modRate = 1 }
    elseif mode == "charges" then
      return { startTime = 100, duration = 1.5, isEnabled = true, isOnGCD = true, modRate = 1 }
    elseif mode == "secret" then
      return SECRET
    end
    return { startTime = 0, duration = 0, isEnabled = true, isOnGCD = false, modRate = 1 }
  end,
}

local NS = { Addon = {} }
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Modules/Tracker.lua"))("RothSpellTracker", NS)
local tracker = NS.Addon.Tracker
local track = { uid = 1, id = 12345, kind = "SPELL", enabled = true, showWhen = "ALWAYS", ignoreGCD = true }

mode = "explicit_gcd"
local state = tracker.EvalSpell(track)
assertEq(state.active, true, "explicit GCD should be ignored")
assertEq(state.cooldownStart, nil, "explicit GCD should not render cooldown")

mode = "unknown_short"
local ok, result = pcall(tracker.EvalSpell, track)
assert(ok, result)
state = result
assertEq(state.active, false, "unknown short cooldown must fail closed")
assertEq(state.cooldownStart, 100, "unknown short cooldown must remain visible")
assertEq(state.cooldownDuration, 1.5, "unknown short cooldown duration")

mode = "real_cd"
state = tracker.EvalSpell(track)
assertEq(state.active, false, "real cooldown readiness")
assertEq(state.cooldownDuration, 30, "real cooldown duration")

mode = "charges"
state = tracker.EvalSpell(track)
assertEq(state.active, false, "empty charges readiness")
assertEq(state.count, 0, "empty charge count")
assertEq(state.cooldownStart, 10, "charge cooldown start")
assertEq(state.cooldownDuration, 8, "charge cooldown duration")

mode = "secret"
ok, result = pcall(tracker.EvalSpell, track)
assert(ok, result)
state = result
assertEq(state.active, false, "inaccessible spell state must fail closed")
assertEq(state.cooldownStart, nil, "inaccessible cooldown must not leak")
assertEq(state.count, 0, "inaccessible charge count")

print("PASS: SPELL tracks ignore only explicit GCD evidence and fail closed on inaccessible cooldown/charge/usability values")

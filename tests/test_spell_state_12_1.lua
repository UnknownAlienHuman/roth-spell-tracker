local SECRET = setmetatable({}, {
  __tostring = function() error("secret value stringified") end,
  __lt = function() error("secret value compared") end,
  __le = function() error("secret value compared") end,
  __add = function() error("secret value added") end,
  __div = function() error("secret value divided") end,
  __index = function() error("secret value indexed") end,
})
local INACCESSIBLE_TABLE = {}
local mode = "ready"
local baseCalls, overrideCalls, knownCalls = 0, 0, 0

local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function canaccessvalue(value) return value ~= SECRET end
function canaccesstable(value) return value ~= INACCESSIBLE_TABLE end
function issecretvalue(value) return value == SECRET end
function issecrettable(value) return value == INACCESSIBLE_TABLE end

IsPlayerSpell = nil
IsSpellKnown = nil

C_SpellBook = {
  IsSpellKnown = function(id)
    knownCalls = knownCalls + 1
    if mode == "known_secret" then return SECRET end
    if mode == "known_false" then return false end
    if mode == "override" then return id == 200 end
    return true
  end,
}

C_Spell = {
  GetBaseSpell = function(id)
    baseCalls = baseCalls + 1
    return id == 200 and 100 or id
  end,
  GetOverrideSpell = function(id)
    overrideCalls = overrideCalls + 1
    if mode == "override" and id == 100 then return 200 end
    return id
  end,
  IsSpellUsable = function()
    if mode == "usable_secret" then return SECRET, false end
    if mode == "unusable" or mode == "loc_replace_unusable" then return false, true end
    return true, false
  end,
  GetSpellTexture = function(id) return 136000 + id end,
  GetSpellName = function(id) return "Spell " .. id end,
  GetSpellCharges = function()
    if mode == "charges_empty" then
      return { currentCharges = 0, maxCharges = 2, cooldownStartTime = 10, cooldownDuration = 8, chargeModRate = 1.25, isActive = true }
    elseif mode == "charges_partial" or mode == "charges_and_real_cd" then
      return { currentCharges = 1, maxCharges = 2, cooldownStartTime = 10, cooldownDuration = 8, chargeModRate = 1.5, isActive = true }
    elseif mode == "charges_current_secret" then
      return { currentCharges = SECRET, maxCharges = 2, cooldownStartTime = SECRET, cooldownDuration = SECRET, chargeModRate = SECRET, isActive = true }
    elseif mode == "charges_table_inaccessible" then
      return INACCESSIBLE_TABLE
    end
    return nil
  end,
  GetSpellCooldown = function()
    if mode == "explicit_gcd" or mode == "charges_empty" or mode == "charges_partial" then
      return { startTime = 100, duration = 1.5, isEnabled = true, isActive = true, modRate = 1, isOnGCD = true }
    elseif mode == "real_cd" or mode == "charges_and_real_cd" then
      return { startTime = 100, duration = 30, isEnabled = true, isActive = true, modRate = 1.2, isOnGCD = false }
    elseif mode == "secret_timing" then
      return { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = true, modRate = SECRET, isOnGCD = false }
    elseif mode == "inactive_secret_timing" then
      return { startTime = SECRET, duration = SECRET, isEnabled = true, isActive = false, modRate = SECRET, isOnGCD = nil }
    elseif mode == "cooldown_table_inaccessible" then
      return INACCESSIBLE_TABLE
    elseif mode == "on_hold" then
      return { startTime = 100, duration = 30, isEnabled = false, isActive = false, modRate = 1, isOnGCD = false }
    end
    return { startTime = 0, duration = 0, isEnabled = true, isActive = false, modRate = 1, isOnGCD = false }
  end,
  GetSpellLossOfControlCooldownInfo = function()
    if mode == "loc_replace" or mode == "loc_replace_unusable" then
      return { startTime = 200, duration = 6, modRate = 1, isActive = true, shouldReplaceNormalCooldown = true }
    elseif mode == "loc_parallel" then
      return { startTime = 200, duration = 6, modRate = 1, isActive = true, shouldReplaceNormalCooldown = false }
    elseif mode == "loc_secret_timing" then
      return { startTime = SECRET, duration = SECRET, modRate = SECRET, isActive = true, shouldReplaceNormalCooldown = true }
    elseif mode == "loc_table_inaccessible" then
      return INACCESSIBLE_TABLE
    end
    return { startTime = 0, duration = 0, modRate = 1, isActive = false, shouldReplaceNormalCooldown = false }
  end,
}

local NS = { Addon = {} }
assert(loadfile("Core/Config.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Modules/Tracker.lua"))("RothSpellTracker", NS)
local Addon = NS.Addon
local tracker = Addon.Tracker
local track = { uid = 1, id = 100, kind = "SPELL", enabled = true, showWhen = "ALWAYS", ignoreGCD = true }

mode = "ready"
local state = tracker.EvalSpell(track, nil)
assertEq(state.active, true, "ordinary ready spell")
assertEq(state.showCount, false, "ordinary spell must not show a charge count")
assertEq(knownCalls > 0, true, "modern spellbook knowledge API used")

local primaryKnown = C_SpellBook.IsSpellKnown
local fallbackCalls = 0
C_SpellBook.IsSpellKnown = nil
C_SpellBook.IsSpellKnownOrInSpellBook = function(id)
  fallbackCalls = fallbackCalls + 1
  return id == 100
end
local fallbackKnown, fallbackReadable = Addon.Util.IsSpellKnown(100)
assertEq(fallbackKnown, true, "current spellbook fallback result")
assertEq(fallbackReadable, true, "current spellbook fallback readability")
assertEq(fallbackCalls, 1, "current spellbook fallback call count")
C_SpellBook.IsSpellKnown = primaryKnown
C_SpellBook.IsSpellKnownOrInSpellBook = nil

mode = "known_false"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "unknown spell")
assertEq(state.showCount, false, "unknown spell count visibility")
assertEq(state._knownReadable, true, "known false remains readable")

mode = "known_secret"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "inaccessible known state must fail closed")
assertEq(state._knownReadable, false, "inaccessible known marker")

mode = "explicit_gcd"
local evidence = { spellID = 100, startTime = 100, duration = 1.5, isOnGCD = true }
state = tracker.EvalSpell(track, evidence)
assertEq(state.active, true, "matching explicit GCD should be ignored")
assertEq(state._evidenceMatched, true, "matching GCD evidence")
assertEq(state.cooldownStart, nil, "GCD should not render as real cooldown")

local stale = { spellID = 100, startTime = 101, duration = 1.5, isOnGCD = true }
state = tracker.EvalSpell(track, stale)
assertEq(state.active, false, "stale GCD evidence must fail closed")

track.ignoreGCD = false
state = tracker.EvalSpell(track, evidence)
assertEq(state.active, false, "configured GCD display must block readiness")
track.ignoreGCD = true

mode = "real_cd"
state = tracker.EvalSpell(track, { spellID = 100, startTime = 100, duration = 30, isOnGCD = false })
assertEq(state.active, false, "real cooldown readiness")
assertEq(state.cooldownDuration, 30, "normal cooldown duration")
assertEq(state.cooldownModRate, 1.2, "normal cooldown mod rate")

mode = "charges_partial"
state = tracker.EvalSpell(track, evidence)
assertEq(state.active, true, "remaining charge should stay ready when explicit GCD is ignored")
assertEq(state.showCount, true, "multi-charge spell should show its charge count")
assertEq(state.count, 1, "remaining charge count")
assertEq(state.chargeCooldownStart, 10, "charge lane start")
assertEq(state.chargeCooldownDuration, 8, "charge lane duration")
assertEq(state.chargeCooldownModRate, 1.5, "charge lane mod rate")
assertEq(state.cooldownStart, nil, "ignored GCD must not occupy normal lane")

mode = "charges_empty"
state = tracker.EvalSpell(track, evidence)
assertEq(state.active, false, "empty charges readiness")
assertEq(state.showCount, true, "empty multi-charge spell should show zero")
assertEq(state.count, 0, "empty charge count")
assertEq(state.chargeCooldownModRate, 1.25, "empty charge mod rate")

mode = "charges_and_real_cd"
state = tracker.EvalSpell(track, { spellID = 100, startTime = 100, duration = 30, isOnGCD = false })
assertEq(state.active, false, "real cooldown blocks a spell with a remaining charge")
assertEq(state.showCount, true, "charge count remains visible during a normal cooldown")
assertEq(state.count, 1, "charge count remains authoritative")
assertEq(state.cooldownDuration, 30, "normal lane remains independent")
assertEq(state.chargeCooldownDuration, 8, "charge lane remains independent")

mode = "loc_replace"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, true, "LoC replacement is presentation-only when usability remains true")
assertEq(state.lossOfControlDuration, 6, "loss-of-control lane duration")
assertEq(state.cooldownStart, nil, "replacing LoC suppresses normal lane")
assertEq(state.chargeCooldownStart, nil, "replacing LoC suppresses charge lane")
assertEq(state._lossOfControlReplaces, true, "LoC replacement marker")

mode = "loc_replace_unusable"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "authoritative usability still blocks during LoC")
assertEq(state.lossOfControlDuration, 6, "unusable replacing LoC presentation")

mode = "loc_parallel"
state = tracker.EvalSpell(track, nil)
assertEq(state.lossOfControlDuration, 6, "parallel LoC lane")
assertEq(state.active, true, "non-replacing LoC leaves readiness to spell state")

mode = "loc_secret_timing"
local ok, result = pcall(tracker.EvalSpell, track, nil)
assert(ok, result)
state = result
assertEq(state.active, true, "secret LoC timing must not become a readiness oracle")
assertEq(state.lossOfControlStart, nil, "secret LoC timing must not leak")
assertEq(state._lossOfControlStateReadable, true, "NeverSecret LoC flags remain readable")

mode = "loc_table_inaccessible"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, true, "optional inaccessible LoC presentation must not erase castability")
assertEq(state._lossOfControlStateReadable, false, "inaccessible LoC state marker")

mode = "inactive_secret_timing"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, true, "NeverSecret inactive cooldown remains usable without timing")

mode = "secret_timing"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "active cooldown with inaccessible timing must fail closed")
assertEq(state.cooldownStart, nil, "secret cooldown timing must not leak")

mode = "cooldown_table_inaccessible"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "inaccessible normal cooldown table must fail closed")
assertEq(state._cooldownStateReadable, false, "normal cooldown readability marker")

mode = "on_hold"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "disabled/on-hold cooldown must fail closed")

mode = "charges_current_secret"
state = tracker.EvalSpell(track, evidence)
assertEq(state.active, false, "inaccessible current charges must fail closed")
assertEq(state._chargeStateReadable, false, "charge state readability")

mode = "charges_table_inaccessible"
state = tracker.EvalSpell(track, evidence)
assertEq(state.active, false, "inaccessible charge table must fail closed")

mode = "usable_secret"
state = tracker.EvalSpell(track, nil)
assertEq(state.active, false, "inaccessible usability must fail closed")

mode = "override"
state = tracker.EvalSpell(track, nil)
assertEq(state._resolvedID, 200, "explicit base/override resolution")
assertEq(state.icon, 136200, "resolved override icon")
assertEq(state.active, true, "resolved override readiness")

local eventFrame
local queued
function CreateFrame()
  eventFrame = { events = {}, unitEvents = {} }
  function eventFrame:RegisterEvent(event) self.events[event] = true end
  function eventFrame:RegisterUnitEvent(event, unit) self.unitEvents[event] = unit end
  function eventFrame:SetScript(_, callback) self.OnEvent = callback end
  return eventFrame
end
C_Timer = { After = function(_, callback) queued = callback end }

mode = "explicit_gcd"
baseCalls, overrideCalls = 0, 0
Addon.db = { tracks = { track } }
Addon.Display = { anchor = {}, pendingRebuild = false, UpdateSpell = function() end }
tracker:Init()
assertEq(eventFrame.events.SPELL_UPDATE_USABLE, true, "spell usability event")
assertEq(eventFrame.events.SPELL_UPDATE_USES, true, "spell uses event")
assertEq(eventFrame.events.UPDATE_SHAPESHIFT_FORM, true, "shapeshift identity event")
assertEq(eventFrame.events.LEARNED_SPELL_IN_SKILL_LINE, true, "spellbook learned event")
assertEq(eventFrame.unitEvents.LOSS_OF_CONTROL_ADDED, "player", "LoC added unit event")
assertEq(eventFrame.unitEvents.LOSS_OF_CONTROL_UPDATE, "player", "LoC update unit event")

eventFrame.OnEvent(eventFrame, "SPELL_UPDATE_COOLDOWN")
assert(type(queued) == "function", "cooldown event should coalesce full rendering")
assertEq(tracker.cooldownEvidence[1].isOnGCD, true, "GCD evidence captured in callback")
queued()
assertEq(tracker.states[1].active, true, "queued render consumes GCD evidence")
local cachedBaseCalls, cachedOverrideCalls = baseCalls, overrideCalls
tracker:Refresh()
assertEq(baseCalls, cachedBaseCalls, "resolved spell cache avoids repeated base lookup")
assertEq(overrideCalls, cachedOverrideCalls, "resolved spell cache avoids repeated override lookup")

queued = nil
eventFrame.OnEvent(eventFrame, "LEARNED_SPELL_IN_SKILL_LINE")
assertEq(next(tracker.resolvedSpells), nil, "spellbook event clears resolved spell cache")
assert(type(queued) == "function", "spellbook event queues refresh")
queued()
assertEq(baseCalls > cachedBaseCalls, true, "spellbook refresh resolves spell again")

queued = nil
eventFrame.OnEvent(eventFrame, "SPELL_SECRECY_CHANGED")
assertEq(next(tracker.cooldownEvidence), nil, "secrecy change clears GCD evidence")
assert(type(queued) == "function", "secrecy change queues refresh")
local secrecyRefresh = queued
queued = nil
secrecyRefresh()

eventFrame.OnEvent(eventFrame, "LOSS_OF_CONTROL_UPDATE")
assert(type(queued) == "function", "LoC update queues refresh")

print("PASS: spell state exposes authoritative multi-charge counts and preserves cooldown/LoC boundaries")

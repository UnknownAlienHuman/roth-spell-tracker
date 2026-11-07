local combat = false
local framesCreated = 0
local auraContainers = {}
local eventFrames = {}
local unpack = unpack or table.unpack

local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function newRegion(objectType, parent)
  local region = {
    objectType = objectType or "Frame",
    parent = parent,
    shown = true,
    point = { "CENTER", parent, "CENTER", 0, 0 },
    width = 44,
    height = 44,
  }
  function region:SetSize(width, height) self.width, self.height = width, height end
  function region:GetSize() return self.width, self.height end
  function region:GetCenter() return 500, 500 end
  function region:SetPoint(...) self.point = { ... } end
  function region:GetPoint() return unpack(self.point) end
  function region:ClearAllPoints() self.point = {} end
  function region:SetAllPoints(relative) self.allPoints = relative or self.parent end
  function region:SetFrameStrata(value) self.strata = value end
  function region:SetFrameLevel(value) self.level = value end
  function region:GetFrameLevel() return self.level or 1 end
  function region:SetClampedToScreen(value) self.clamped = value end
  function region:SetMovable(value) self.movable = value end
  function region:RegisterForDrag(value) self.drag = value end
  function region:EnableMouse(value) self.mouse = value end
  function region:SetScript(name, callback) self[name] = callback end
  function region:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
  function region:RegisterUnitEvent(event, unit) self.unitEvents = self.unitEvents or {}; self.unitEvents[event] = unit end
  function region:SetShown(value) self.shown = value end
  function region:IsShown() return self.shown end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:SetAlpha(value) self.alpha = value end
  function region:StartMoving() self.moving = true end
  function region:StopMovingOrSizing() self.moving = false end
  function region:SetParent(value) self.parent = value end
  function region:GetParent() return self.parent end
  function region:SetTexture(value) self.texture = value end
  function region:SetTexCoord(...) self.texCoord = { ... } end
  function region:SetBlendMode(value) self.blendMode = value end
  function region:SetText(value) self.text = value end
  function region:SetColorTexture(...) self.color = { ... } end
  function region:SetDrawBling(value) self.drawBling = value end
  function region:SetDrawEdge(value) self.drawEdge = value end
  function region:SetSwipeColor(...) self.swipeColor = { ... } end
  function region:SetHideCountdownNumbers(value) self.hideCountdown = value end
  function region:SetCooldown(startTime, duration, modRate)
    self.cooldownCalls = (self.cooldownCalls or 0) + 1
    self.cooldownStart = startTime
    self.cooldownDuration = duration
    self.cooldownModRate = modRate
  end
  function region:CreateTexture(_, layer, _, subLevel)
    local texture = newRegion("Texture", self)
    texture.layer, texture.subLevel = layer, subLevel
    return texture
  end
  function region:CreateFontString()
    return newRegion("FontString", self)
  end
  return region
end

local function newAuraButton(parent)
  local button = newRegion("AuraButton", parent)
  function button:SetIcon(texture) self.icon = texture end
  function button:SetApplicationCount(fontString, options) self.count = fontString; self.countOptions = options end
  function button:SetDurationCooldown(cooldown) self.cooldown = cooldown end
  return button
end

local function newAuraContainer(parent)
  local container = newRegion("AuraContainer", parent)
  function container:SetUnit(unit) self.unit = unit end
  function container:SetEnabled(value) self.enabled = value end
  function container:UpdateAllAuras() error("addon must not append UpdateAllAuras") end
  function container:AddAuraSlot(key, filter, options)
    self.slotKey = key
    self.filter = filter
    self.options = options
    self.button = newAuraButton(self)
    options.initializeFrame(self.button)
    return self.button
  end
  function container:SetAuraSlotFilterString(_, filter)
    self.filter = filter
    self.filterUpdates = (self.filterUpdates or 0) + 1
  end
  function container:SetAuraSlotCandidateFilters(_, filters)
    self.options.candidateFilters = filters
    self.candidateUpdates = (self.candidateUpdates or 0) + 1
  end
  auraContainers[#auraContainers + 1] = container
  return container
end

function canaccessvalue() return true end
function canaccesstable() return true end
function issecretvalue() return false end
function InCombatLockdown() return combat end
function GetSpellTexture() return 136243 end
function GetSpellInfo() return "Test Spell" end

UIParent = newRegion("Frame")
NumberFontNormal = "NumberFontNormal"
C_Spell = {
  GetSpellName = function(id) return "Spell " .. id end,
  GetSpellTexture = function() return 136243 end,
}
C_Timer = { After = function(_, callback) callback() end }
AuraContainerSortMethod = { Default = 0 }
AuraContainerSortDirection = { Normal = 0 }

function CreateFrame(objectType, _, parent)
  framesCreated = framesCreated + 1
  local frame
  if objectType == "AuraContainer" then
    frame = newAuraContainer(parent)
  else
    frame = newRegion(objectType, parent)
  end
  if not parent then eventFrames[#eventFrames + 1] = frame end
  return frame
end

local NS = { Addon = {} }
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Config.lua"))("RothSpellTracker", NS)
assert(loadfile("Modules/Display.lua"))("RothSpellTracker", NS)
assert(loadfile("Modules/ManagedAuras.lua"))("RothSpellTracker", NS)

local Addon = NS.Addon
Addon.Notify = function() end
Addon.db = {
  frame = { point = "CENTER", relPoint = "CENTER", x = 0, y = -120, size = 44, spacing = 6, locked = true, grow = "RIGHT" },
  tracks = {
    { uid = 1, id = 12345, kind = "AURA", enabled = true, showWhen = "ALWAYS", unit = "player", auraType = "HELPFUL" },
  },
}

Addon.ManagedAuras:Init()
Addon.Display:Init()
assertEq(#auraContainers, 0, "Display:Init must not perform a duplicate structural rebuild")
Addon.Display:Rebuild()

assertEq(#auraContainers, 1, "managed container count")
local container = auraContainers[1]
assertEq(container.unit, "player", "managed unit")
assertEq(container.filter, "HELPFUL", "managed filter")
assertEq(container.options.candidateFilters.includeSpellIDs[12345], true, "spell candidate filter")
assertEq(container.button.allPoints, container, "managed button anchor")
assert(container.button.icon, "icon sink missing")
assert(container.button.count, "application count sink missing")
assert(container.button.cooldown, "duration cooldown sink missing")
assert(container.button.count.parent:GetFrameLevel() > container.button.cooldown:GetFrameLevel(), "managed count must render above cooldown")

local displayEvent
for _, frame in ipairs(eventFrames) do
  if frame.events and frame.events.PLAYER_REGEN_ENABLED then displayEvent = frame end
end
assert(displayEvent, "display event owner missing")
assertEq(displayEvent.events.UI_SCALE_CHANGED, true, "UI scale invalidation event")
assertEq(displayEvent.events.DISPLAY_SIZE_CHANGED, true, "display-size invalidation event")

local targetEvent
for _, frame in ipairs(eventFrames) do
  if frame.events and (frame.events.PLAYER_TARGET_CHANGED or frame.events.PLAYER_FOCUS_CHANGED) then targetEvent = frame end
end
assertEq(targetEvent, nil, "managed module must rely on native target/focus lifecycle")

local state = Addon.ManagedAuras.states[1]
assertEq(state.placeholder.shown, true, "always placeholder")
Addon.db.tracks[1].showWhen = "ACTIVE"
Addon.Display:Rebuild()
assertEq(state.placeholder.shown, false, "active-only placeholder")

Addon.db.tracks[1].id = 22222
Addon.db.tracks[1].unit = "target"
Addon.db.tracks[1].auraType = "HARMFUL"
Addon.Display:Rebuild()
assertEq(container.unit, "target", "reconfigured unit")
assertEq(container.filter, "HARMFUL", "reconfigured filter")
assertEq(container.options.candidateFilters.includeSpellIDs[22222], true, "reconfigured spell ID")
assertEq(container.filterUpdates, 1, "filter setter count")
assertEq(container.candidateUpdates, 1, "candidate setter count")

Addon.db.tracks[#Addon.db.tracks + 1] = {
  uid = 2, id = 33333, kind = "SPELL", enabled = true, showWhen = "ALWAYS", ignoreGCD = true,
}
Addon.Display:Rebuild()
local spellSlot = Addon.Display:GetSlot(2)
assert(spellSlot.spell.chargeCooldown, "charge cooldown lane missing")
assert(spellSlot.spell.cooldown, "normal cooldown lane missing")
assert(spellSlot.spell.lossOfControlCooldown, "loss-of-control lane missing")
assert(spellSlot.spell.overlay:GetFrameLevel() > spellSlot.spell.lossOfControlCooldown:GetFrameLevel(), "presentation overlay must render above every cooldown lane")
assert(spellSlot.spell.chargeCooldown:GetFrameLevel() < spellSlot.spell.cooldown:GetFrameLevel(), "charge lane order")
assert(spellSlot.spell.cooldown:GetFrameLevel() < spellSlot.spell.lossOfControlCooldown:GetFrameLevel(), "LoC lane order")

local track = Addon.db.tracks[2]
Addon.Display:UpdateSpell(track, {
  active = false,
  icon = 136243,
  count = 1,
  showCount = true,
  chargeCooldownStart = 10,
  chargeCooldownDuration = 8,
  chargeCooldownModRate = 1.5,
  cooldownStart = 20,
  cooldownDuration = 30,
  cooldownModRate = 1.2,
  lossOfControlStart = 40,
  lossOfControlDuration = 6,
  lossOfControlModRate = 1,
})
assertEq(spellSlot.spell.chargeCooldown.cooldownDuration, 8, "charge lane update")
assertEq(spellSlot.spell.cooldown.cooldownDuration, 30, "normal lane update")
assertEq(spellSlot.spell.lossOfControlCooldown.cooldownDuration, 6, "LoC lane update")
assertEq(spellSlot.spell.count.text, "1", "single remaining charge must be visible")

Addon.Display:UpdateSpell(track, {
  active = false,
  icon = 136243,
  count = 0,
  showCount = true,
})
assertEq(spellSlot.spell.count.text, "0", "empty multi-charge spell must show zero")
Addon.Display:UpdateSpell(track, {
  active = false,
  icon = 136243,
  count = 0,
  showCount = false,
})
assertEq(spellSlot.spell.count.text, "", "ordinary spell must clear charge text")

Addon.Display:UpdateSpell(track, {
  active = false, icon = 136243, count = 0,
  cooldownStart = 100, cooldownDuration = 30, cooldownModRate = 1,
})
local normal = spellSlot.spell.cooldown
local callsAtA = normal.cooldownCalls
combat = true
Addon.Display:UpdateSpell(track, {
  active = false, icon = 136243, count = 0,
  cooldownStart = 200, cooldownDuration = 40, cooldownModRate = 1,
})
assertEq(normal.shown, false, "changed protected cooldown hidden in combat")
assertEq(normal.rstSuppressed, true, "suppression marker")
Addon.Display:UpdateSpell(track, {
  active = false, icon = 136243, count = 0,
  cooldownStart = 100, cooldownDuration = 30, cooldownModRate = 1,
})
assertEq(normal.shown, false, "same prior tuple remains hidden during combat")
combat = false
Addon.Display:UpdateSpell(track, {
  active = false, icon = 136243, count = 0,
  cooldownStart = 100, cooldownDuration = 30, cooldownModRate = 1,
})
assertEq(normal.shown, true, "same tuple restored after combat")
assertEq(normal.rstSuppressed, false, "suppression cleared after combat")
assertEq(normal.cooldownCalls, callsAtA, "same tuple recovery should not rewrite protected timing")

local directSetCooldown = normal.SetCooldown
normal.SetCooldown = nil
CooldownFrame_Set = function(frame, startTime, duration, enable, forceShowDrawEdge, modRate)
  frame.cooldownCalls = (frame.cooldownCalls or 0) + 1
  frame.cooldownStart = startTime
  frame.cooldownDuration = duration
  frame.cooldownModRate = modRate
  frame.fallbackEnable = enable
  frame.fallbackForceEdge = forceShowDrawEdge
end
Addon.Display:UpdateSpell(track, {
  active = false, icon = 136243, count = 0,
  cooldownStart = 300, cooldownDuration = 15, cooldownModRate = 1.75,
})
assertEq(normal.cooldownModRate, 1.75, "compatibility cooldown modRate")
assertEq(normal.fallbackEnable, true, "compatibility cooldown enable")
assertEq(normal.fallbackForceEdge, false, "compatibility cooldown edge policy")
normal.SetCooldown = directSetCooldown

Addon.db.frame.grow = "LEFT"
Addon.Display:ApplyLayout()
assertEq(Addon.Display.anchor.point[1], "RIGHT", "left growth anchor edge")
assertEq(Addon.Display:GetSlot(1).point[1], "RIGHT", "left growth first slot edge")

Addon.db.frame.size = 60
displayEvent.OnEvent(displayEvent, "UI_SCALE_CHANGED")
assertEq(Addon.Display:GetSlot(1).width, 60, "UI scale event reapplies layout")
assertEq(Addon.Display:GetSlot(2).width, 60, "UI scale event resizes every slot")

combat = true
Addon.db.frame.size = 70
displayEvent.OnEvent(displayEvent, "DISPLAY_SIZE_CHANGED")
assertEq(Addon.Display.pendingLayout, true, "display-size layout deferred in combat")
assertEq(Addon.Display:GetSlot(1).width, 60, "combat display-size event must not mutate geometry")
combat = false
displayEvent.OnEvent(displayEvent, "PLAYER_REGEN_ENABLED")
assertEq(Addon.Display:GetSlot(1).width, 70, "deferred display-size layout applied after combat")

combat = true
local beforeFrames = framesCreated
Addon.db.tracks[#Addon.db.tracks + 1] = {
  uid = 3, id = 44444, kind = "AURA", enabled = true, showWhen = "ALWAYS", unit = "focus", auraType = "HELPFUL",
}
Addon.Display:RequestRebuild()
assertEq(framesCreated, beforeFrames, "frame created in combat")
assertEq(Addon.Display.pendingRebuild, true, "combat rebuild not deferred")
combat = false
displayEvent.OnEvent(displayEvent, "PLAYER_REGEN_ENABLED")
assertEq(#auraContainers, 2, "deferred aura container creation")

assertEq(_G.C_UnitAuras, nil, "test unexpectedly provided raw aura API")
assertEq(_G.UnitAura, nil, "test unexpectedly provided legacy raw aura API")
print("PASS: display preserves managed ownership, cooldown layers and authoritative charge counts")

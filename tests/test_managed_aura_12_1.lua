local combat = false
local framesCreated = 0
local auraContainers = {}
local eventFrames = {}

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
  function region:SetPoint(...) self.point = { ... } end
  function region:GetPoint() return unpack(self.point) end
  function region:ClearAllPoints() self.point = {} end
  function region:SetAllPoints(relative) self.allPoints = relative end
  function region:SetFrameStrata(value) self.strata = value end
  function region:SetFrameLevel(value) self.level = value end
  function region:GetFrameLevel() return self.level or 1 end
  function region:SetClampedToScreen(value) self.clamped = value end
  function region:SetMovable(value) self.movable = value end
  function region:RegisterForDrag(value) self.drag = value end
  function region:EnableMouse(value) self.mouse = value end
  function region:SetScript(name, callback) self[name] = callback end
  function region:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
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
  container.updateCount = 0
  function container:SetUnit(unit) self.unit = unit end
  function container:SetEnabled(value) self.enabled = value end
  function container:UpdateAllAuras() self.updateCount = self.updateCount + 1 end
  function container:AddAuraSlot(key, filter, options)
    self.slotKey = key
    self.filter = filter
    self.options = options
    self.button = newAuraButton(self)
    options.initializeFrame(self.button)
    return self.button
  end
  function container:SetAuraSlotFilterString(_, filter) self.filter = filter end
  function container:SetAuraSlotCandidateFilters(_, filters) self.options.candidateFilters = filters end
  auraContainers[#auraContainers + 1] = container
  return container
end

function canaccessvalue() return true end
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
Addon.Log = function() end
Addon.db = {
  frame = { point = "CENTER", relPoint = "CENTER", x = 0, y = -120, size = 44, spacing = 6, locked = true, grow = "RIGHT" },
  tracks = {
    { uid = 1, id = 12345, kind = "AURA", enabled = true, showWhen = "ALWAYS", unit = "player", auraType = "HELPFUL" },
  },
}

Addon.Display:Init()
Addon.ManagedAuras:Init()
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

local targetEvent
for _, frame in ipairs(eventFrames) do
  if frame.events and frame.events.PLAYER_TARGET_CHANGED then targetEvent = frame end
end
assert(targetEvent, "target/focus refresh owner missing")
local beforeUpdate = container.updateCount
targetEvent.OnEvent(targetEvent, "PLAYER_TARGET_CHANGED")
assertEq(container.updateCount, beforeUpdate + 1, "target change did not refresh managed container")

combat = true
local beforeFrames = framesCreated
Addon.db.tracks[#Addon.db.tracks + 1] = { uid = 2, id = 33333, kind = "AURA", enabled = true, showWhen = "ALWAYS", unit = "focus", auraType = "HARMFUL" }
Addon.Display:RequestRebuild()
assertEq(framesCreated, beforeFrames, "frame created in combat")
assertEq(Addon.Display.pendingRebuild, true, "combat rebuild not deferred")

combat = false
local regenEvent
for _, frame in ipairs(eventFrames) do
  if frame.events and frame.events.PLAYER_REGEN_ENABLED then regenEvent = frame end
end
assert(regenEvent, "regen rebuild owner missing")
regenEvent.OnEvent(regenEvent, "PLAYER_REGEN_ENABLED")
assertEq(#auraContainers, 2, "deferred managed container was not created")

assertEq(_G.C_UnitAuras, nil, "test unexpectedly provided raw aura API")
assertEq(_G.UnitAura, nil, "test unexpectedly provided legacy raw aura API")
print("PASS: AURA tracks use managed AddAuraSlot sinks without raw aura reads or combat-time frame creation")

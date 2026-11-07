local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function canaccessvalue() return true end
function canaccesstable() return true end
function issecretvalue() return false end
function InCombatLockdown() return false end

C_SpellBook = {
  IsSpellKnown = function() return true end,
}

C_Spell = {
  GetBaseSpell = function(id) return id end,
  GetOverrideSpell = function(id) return id end,
  IsSpellUsable = function() return true, false end,
  GetSpellTexture = function() return 136243 end,
  GetSpellCharges = function() return nil end,
  GetSpellCooldown = function()
    return {
      startTime = 100,
      duration = 30,
      isEnabled = false,
      isActive = false,
      modRate = 1,
      isOnGCD = false,
    }
  end,
  GetSpellLossOfControlCooldownInfo = function()
    return {
      startTime = 0,
      duration = 0,
      modRate = 1,
      isActive = false,
      shouldReplaceNormalCooldown = false,
    }
  end,
}

local NS = { Addon = {} }
assert(loadfile("Core/Config.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Modules/Tracker.lua"))("RothSpellTracker", NS)

local Addon = NS.Addon
local track = {
  uid = 1,
  id = 12345,
  kind = "SPELL",
  enabled = true,
  showWhen = "ALWAYS",
  ignoreGCD = true,
}

local spellState = Addon.Tracker.EvalSpell(track, nil)
assertEq(spellState.active, false, "on-hold spell readiness")
assertEq(spellState.cooldownStart, nil, "on-hold cooldown must not draw a radial")
assertEq(spellState.cooldownDuration, nil, "on-hold cooldown duration must stay hidden")

local auraContainers = {}

local function newRegion(objectType, parent)
  local region = {
    objectType = objectType,
    parent = parent,
    shown = true,
    frameLevel = 1,
    setParentCalls = 0,
  }

  function region:SetAllPoints(relative) self.allPoints = relative or self.parent end
  function region:ClearAllPoints() self.allPoints = nil end
  function region:SetPoint(...) self.point = { ... } end
  function region:SetFrameLevel(level) self.frameLevel = level end
  function region:GetFrameLevel() return self.frameLevel end
  function region:SetParent(value)
    self.setParentCalls = self.setParentCalls + 1
    self.parent = value
  end
  function region:SetShown(value) self.shown = value end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:SetAlpha(value) self.alpha = value end
  function region:SetTexture(value) self.texture = value end
  function region:SetTexCoord(...) self.texCoord = { ... } end
  function region:SetBlendMode(value) self.blendMode = value end
  function region:CreateTexture(_, layer, _, subLevel)
    local texture = newRegion("Texture", self)
    texture.layer = layer
    texture.subLevel = subLevel
    return texture
  end
  function region:CreateFontString()
    return newRegion("FontString", self)
  end

  return region
end

local function newAuraButton(parent)
  local button = newRegion("AuraButton", parent)
  function button:SetIcon(icon) self.icon = icon end
  function button:SetApplicationCount(count, options)
    self.count = count
    self.countOptions = options
  end
  function button:SetDurationCooldown(cooldown) self.cooldown = cooldown end
  return button
end

local function newAuraContainer(parent)
  local container = newRegion("AuraContainer", parent)
  function container:SetUnit(unit) self.unit = unit end
  function container:SetEnabled(value) self.enabled = value end
  function container:AddAuraSlot(key, filter, options)
    self.slotKey = key
    self.filter = filter
    self.options = options
    self.button = newAuraButton(self)
    options.initializeFrame(self.button)
  end
  function container:SetAuraSlotFilterString(_, filter) self.filter = filter end
  function container:SetAuraSlotCandidateFilters(_, filters) self.options.candidateFilters = filters end
  auraContainers[#auraContainers + 1] = container
  return container
end

function CreateFrame(objectType, _, parent)
  if objectType == "AuraContainer" then return newAuraContainer(parent) end
  return newRegion(objectType, parent)
end

AuraContainerSortMethod = { Default = 0 }
AuraContainerSortDirection = { Normal = 0 }

assert(loadfile("Modules/ManagedAuras.lua"))("RothSpellTracker", NS)
Addon.Display = { pendingRebuild = false }
Addon.ManagedAuras:Init()

local slotOne = newRegion("Slot", nil)
local slotTwo = newRegion("Slot", nil)
local auraTrack = {
  uid = 2,
  id = 67890,
  kind = "AURA",
  enabled = true,
  showWhen = "ALWAYS",
  unit = "player",
  auraType = "HELPFUL",
}

assertEq(Addon.ManagedAuras:Attach(auraTrack, slotOne), true, "initial managed attach")
local retiredState = Addon.ManagedAuras.states[2]
local retiredContainer = retiredState.container
assertEq(#auraContainers, 1, "initial managed graph count")

assertEq(Addon.ManagedAuras:Attach(auraTrack, slotTwo), true, "replacement managed attach")
local replacementState = Addon.ManagedAuras.states[2]
assertEq(#auraContainers, 2, "slot replacement creates a fresh managed graph")
assertEq(retiredContainer.setParentCalls, 0, "adopted container must never be reparented")
assertEq(retiredContainer.enabled, false, "retired managed container disabled")
assertEq(retiredContainer.shown, false, "retired managed container hidden")
assertEq(replacementState.slot, slotTwo, "replacement state owns the new slot")
assert(replacementState.container ~= retiredContainer, "managed graph was reused after adoption")

print("PASS: on-hold cooldowns stay presentation-inactive and adopted AuraContainers are never reparented")

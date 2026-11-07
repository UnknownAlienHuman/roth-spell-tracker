local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.Tracker = Addon.Tracker or {}
local T = Addon.Tracker

local IDENTITY_EVENTS = {
  SPELLS_CHANGED = true,
  LEARNED_SPELL_IN_SKILL_LINE = true,
  SPELL_UPDATE_ICON = true,
  UPDATE_SHAPESHIFT_FORM = true,
  PLAYER_ENTERING_WORLD = true,
  PLAYER_SPECIALIZATION_CHANGED = true,
  PLAYER_TALENT_UPDATE = true,
  TRAIT_CONFIG_UPDATED = true,
  COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = true,
}

local function WipeMap(map)
  for key in pairs(map or {}) do map[key] = nil end
end

local function EvidenceMatches(evidence, spellID, cooldown)
  return evidence
    and evidence.spellID == spellID
    and cooldown
    and evidence.startTime == cooldown.startTime
    and evidence.duration == cooldown.duration
end

local function GetTiming(info, startKey, durationKey, rateKey)
  if not info then return nil end
  local startTime = info[startKey]
  local duration = info[durationKey]
  local modRate = info[rateKey]
  if startTime and startTime > 0
    and duration and duration > 0.05
    and modRate and modRate > 0 then
    return startTime, duration, modRate
  end
  return nil
end

local function EvalSpell(track, evidence, resolvedSpellID)
  local configuredID = U.SafeInteger(track.id, 1, Addon.MAX_SPELL_ID or 2147483647)
  local spellID = resolvedSpellID or U.ResolveSpellID(configuredID) or configuredID
  local icon = U.GetSpellIcon(spellID) or U.GetSpellIcon(configuredID)

  local known, knownReadable = U.IsSpellKnown(spellID)
  if not knownReadable or not known then
    return {
      active = false,
      icon = icon,
      count = 0,
      showCount = false,
      _resolvedID = spellID,
      _evidenceMatched = false,
      _knownReadable = knownReadable,
    }
  end

  local usable, usableReadable = U.IsSpellUsable(spellID)
  local charges, chargesReadable = U.GetSpellCharges(spellID)
  local cooldown, cooldownReadable = U.GetSpellCooldown(spellID, false)
  local lossOfControl, lossOfControlReadable = U.GetSpellLossOfControlCooldown(spellID)

  local hasCharges = false
  local chargeStateReadable = chargesReadable == true
  local currentCharges, maximumCharges
  if chargesReadable and charges then
    maximumCharges = U.SafeInteger(charges.maxCharges, 1)
    currentCharges = maximumCharges and U.SafeInteger(charges.currentCharges, 0, maximumCharges) or nil
    if not maximumCharges or currentCharges == nil or charges.isActive == nil then
      chargeStateReadable = false
    else
      hasCharges = true
    end
  end

  local cooldownStateReadable = cooldownReadable == true and cooldown ~= nil
  local normalCooldownActive = false
  local onRealCooldown = true
  local evidenceMatched = false
  if cooldownStateReadable then
    local isEnabled = cooldown.isEnabled
    local isActive = cooldown.isActive
    if isEnabled == nil or isActive == nil then
      cooldownStateReadable = false
    elseif isEnabled == false then
      -- On-hold cooldowns block readiness but are not active presentation.
      -- Blizzard clears the radial while isActive is false.
      onRealCooldown = true
    elseif isActive == false then
      onRealCooldown = false
    else
      normalCooldownActive = true
      evidenceMatched = EvidenceMatches(evidence, spellID, cooldown) == true
      onRealCooldown = not (
        track.ignoreGCD ~= false
        and evidenceMatched
        and evidence.isOnGCD == true
      )
    end
  end

  local lossOfControlStateReadable = lossOfControlReadable == true
  local lossOfControlReplaces = false
  if lossOfControlReadable and lossOfControl then
    if lossOfControl.isActive == nil or lossOfControl.shouldReplaceNormalCooldown == nil then
      lossOfControlStateReadable = false
    else
      lossOfControlReplaces = lossOfControl.isActive == true
        and lossOfControl.shouldReplaceNormalCooldown == true
    end
  end

  local ready = usableReadable == true
    and chargeStateReadable
    and cooldownStateReadable
    and usable == true
    and (not hasCharges or currentCharges > 0)
    and not onRealCooldown

  local showCount = hasCharges and maximumCharges > 1
  local count = showCount and currentCharges or 0

  local cooldownStart, cooldownDuration, cooldownModRate
  local chargeCooldownStart, chargeCooldownDuration, chargeCooldownModRate
  local lossOfControlStart, lossOfControlDuration, lossOfControlModRate

  if lossOfControl and lossOfControl.isActive == true then
    lossOfControlStart, lossOfControlDuration, lossOfControlModRate =
      GetTiming(lossOfControl, "startTime", "duration", "modRate")
  end

  if not lossOfControlReplaces then
    if normalCooldownActive and onRealCooldown and cooldownStateReadable then
      cooldownStart, cooldownDuration, cooldownModRate =
        GetTiming(cooldown, "startTime", "duration", "modRate")
    end

    if hasCharges and charges.isActive == true then
      chargeCooldownStart, chargeCooldownDuration, chargeCooldownModRate =
        GetTiming(charges, "cooldownStartTime", "cooldownDuration", "chargeModRate")
    end
  end

  return {
    active = ready == true,
    icon = icon,
    count = count,
    showCount = showCount,

    cooldownStart = cooldownStart,
    cooldownDuration = cooldownDuration,
    cooldownModRate = cooldownModRate,

    chargeCooldownStart = chargeCooldownStart,
    chargeCooldownDuration = chargeCooldownDuration,
    chargeCooldownModRate = chargeCooldownModRate,

    lossOfControlStart = lossOfControlStart,
    lossOfControlDuration = lossOfControlDuration,
    lossOfControlModRate = lossOfControlModRate,

    _resolvedID = spellID,
    _evidenceMatched = evidenceMatched,
    _knownReadable = knownReadable,
    _usableReadable = usableReadable,
    _chargeStateReadable = chargeStateReadable,
    _cooldownStateReadable = cooldownStateReadable,
    _lossOfControlStateReadable = lossOfControlStateReadable,
    _lossOfControlReplaces = lossOfControlReplaces,
  }
end

function T:ClearCooldownEvidence()
  self.cooldownEvidence = self.cooldownEvidence or {}
  WipeMap(self.cooldownEvidence)
end

function T:ClearResolvedSpells()
  self.resolvedSpells = self.resolvedSpells or {}
  WipeMap(self.resolvedSpells)
end

function T:GetResolvedSpellID(track)
  local uid = U.SafeInteger(track and track.uid, 1, Addon.MAX_TRACKS or 500)
  local configuredID = U.SafeInteger(track and track.id, 1, Addon.MAX_SPELL_ID or 2147483647)
  if not uid or not configuredID then return nil end

  self.resolvedSpells = self.resolvedSpells or {}
  local cached = self.resolvedSpells[uid]
  if cached and cached.configuredID == configuredID then
    return cached.spellID
  end

  local spellID = U.ResolveSpellID(configuredID) or configuredID
  self.resolvedSpells[uid] = {
    configuredID = configuredID,
    spellID = spellID,
  }
  return spellID
end

function T:CaptureCooldownEvidence()
  self.cooldownEvidence = self.cooldownEvidence or {}
  WipeMap(self.cooldownEvidence)

  for _, track in ipairs(Addon.db and Addon.db.tracks or {}) do
    if type(track) == "table"
      and track.enabled ~= false
      and track.kind == "SPELL"
      and track.ignoreGCD ~= false then
      local uid = U.SafeInteger(track.uid, 1, Addon.MAX_TRACKS or 500)
      local spellID = self:GetResolvedSpellID(track)
      if uid and spellID then
        local cooldown, readable = U.GetSpellCooldown(spellID, true)
        if readable
          and cooldown
          and cooldown.isEnabled == true
          and cooldown.isActive == true
          and cooldown.isOnGCD ~= nil
          and cooldown.startTime
          and cooldown.startTime > 0
          and cooldown.duration
          and cooldown.duration > 0.05 then
          self.cooldownEvidence[uid] = {
            spellID = spellID,
            startTime = cooldown.startTime,
            duration = cooldown.duration,
            isOnGCD = cooldown.isOnGCD == true,
          }
        end
      end
    end
  end
end

function T:Init()
  if self.eventFrame then return end

  local frame = CreateFrame("Frame")
  self.eventFrame = frame
  for _, event in ipairs({
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELL_UPDATE_USABLE",
    "SPELL_UPDATE_USES",
    "SPELL_UPDATE_ICON",
    "UPDATE_SHAPESHIFT_FORM",
    "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE",
    "SPELL_SECRECY_CHANGED",
    "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
  }) do
    frame:RegisterEvent(event)
  end
  frame:RegisterUnitEvent("LOSS_OF_CONTROL_ADDED", "player")
  frame:RegisterUnitEvent("LOSS_OF_CONTROL_UPDATE", "player")
  frame:SetScript("OnEvent", function(_, event)
    T:HandleEvent(event)
  end)
end

function T:HandleEvent(event)
  if event == "SPELL_UPDATE_COOLDOWN" then
    self:CaptureCooldownEvidence()
  elseif IDENTITY_EVENTS[event] then
    self:ClearResolvedSpells()
    self:ClearCooldownEvidence()
  elseif event == "SPELL_SECRECY_CHANGED" then
    self:ClearCooldownEvidence()
  end
  self:RequestRefresh()
end

function T:RequestRefresh()
  if self.refreshQueued then return end
  self.refreshQueued = true

  local function Run()
    T.refreshQueued = false
    T:Refresh()
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, Run)
  else
    Run()
  end
end

function T:Refresh()
  if not Addon.db or not Addon.Display or not Addon.Display.anchor then return end

  if Addon.Display.pendingRebuild then Addon.Display:RequestRebuild() end
  self.states = self.states or {}
  self.cooldownEvidence = self.cooldownEvidence or {}
  self.resolvedSpells = self.resolvedSpells or {}
  local seen = {}

  for _, track in ipairs(Addon.db.tracks or {}) do
    if type(track) == "table" and track.enabled ~= false and track.kind == "SPELL" then
      local uid = U.SafeInteger(track.uid, 1, Addon.MAX_TRACKS or 500)
      if uid then
        local spellID = self:GetResolvedSpellID(track)
        local state = EvalSpell(track, self.cooldownEvidence[uid], spellID)
        self.states[uid] = state
        seen[uid] = true
        if self.cooldownEvidence[uid] and not state._evidenceMatched then
          self.cooldownEvidence[uid] = nil
        end
        Addon.Display:UpdateSpell(track, state)
      end
    end
  end

  for uid in pairs(self.states) do
    if not seen[uid] then self.states[uid] = nil end
  end
  for uid in pairs(self.cooldownEvidence) do
    if not seen[uid] then self.cooldownEvidence[uid] = nil end
  end
  for uid in pairs(self.resolvedSpells) do
    if not seen[uid] then self.resolvedSpells[uid] = nil end
  end
end

T.EvalSpell = EvalSpell

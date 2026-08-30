local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.Tracker = Addon.Tracker or {}
local T = Addon.Tracker

local function EvalSpell(track)
  local spellID = track.id
  local known = U.IsSpellKnown(spellID)
  local usable = known and U.IsUsableSpell(spellID) or false

  local charges = U.GetSpellCharges(spellID)
  local currentCharges = charges and charges.currentCharges or nil
  local maximumCharges = charges and charges.maxCharges or nil
  local hasCharges = currentCharges ~= nil and maximumCharges ~= nil and maximumCharges > 0

  local cooldown = U.GetSpellCooldown(spellID)
  local startTime = cooldown and cooldown.startTime or nil
  local duration = cooldown and cooldown.duration or nil
  local isOnGCD = cooldown and cooldown.isOnGCD or nil

  local onRealCooldown = false
  if startTime and duration and duration > 0.05 and startTime > 0 then
    if track.ignoreGCD ~= false and isOnGCD == true then
      onRealCooldown = false
    else
      -- Unknown GCD classification fails closed: short duration alone is not
      -- sufficient evidence that this is only the global cooldown.
      onRealCooldown = true
    end
  end

  local ready
  if hasCharges then
    ready = usable and currentCharges > 0
  else
    ready = usable and not onRealCooldown
  end

  local count = 0
  if hasCharges and maximumCharges > 1 then count = currentCharges end

  local cooldownStart, cooldownDuration
  if hasCharges then
    if currentCharges <= 0 and charges.cooldownStartTime and charges.cooldownDuration
      and charges.cooldownDuration > 0.05 then
      cooldownStart = charges.cooldownStartTime
      cooldownDuration = charges.cooldownDuration
    end
  elseif onRealCooldown then
    cooldownStart = startTime
    cooldownDuration = duration
  end

  return {
    active = ready == true,
    icon = U.GetSpellIcon(spellID),
    count = count,
    cooldownStart = cooldownStart,
    cooldownDuration = cooldownDuration,
  }
end

function T:Init()
  if self.eventFrame then return end

  local frame = CreateFrame("Frame")
  self.eventFrame = frame
  for _, event in ipairs({
    "SPELL_UPDATE_COOLDOWN",
    "SPELL_UPDATE_CHARGES",
    "SPELLS_CHANGED",
    "ACTIONBAR_UPDATE_USABLE",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED",
  }) do
    frame:RegisterEvent(event)
  end
  frame:SetScript("OnEvent", function()
    T:RequestRefresh()
  end)
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
  if not Addon.db or not Addon.Display then return end
  if not Addon.Display.anchor then return end

  if Addon.Display.pendingRebuild then Addon.Display:RequestRebuild() end
  for _, track in ipairs(Addon.db.tracks or {}) do
    if type(track) == "table" and track.enabled ~= false and track.kind == "SPELL" then
      Addon.Display:UpdateSpell(track, EvalSpell(track))
    end
  end
end

T.EvalSpell = EvalSpell

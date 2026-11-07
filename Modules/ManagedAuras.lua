local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.ManagedAuras = Addon.ManagedAuras or {}
local M = Addon.ManagedAuras

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local SLOT_KEY = "track"

local function InitializeManagedButton(button, container)
  button:SetAllPoints(container)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(button)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button:SetIcon(icon)

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints(button)
  if type(cooldown.SetFrameLevel) == "function" and type(button.GetFrameLevel) == "function" then
    cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
  end
  button:SetDurationCooldown(cooldown)

  local overlay = CreateFrame("Frame", nil, button)
  overlay:SetAllPoints(button)
  if type(overlay.SetFrameLevel) == "function" and type(button.GetFrameLevel) == "function" then
    overlay:SetFrameLevel(button:GetFrameLevel() + 2)
  end

  local count = overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  count:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -2, 2)
  button:SetApplicationCount(count, {})

  local glow = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetAllPoints(overlay)
  glow:SetAlpha(0.9)
end

local function BuildCandidateFilters(spellID)
  return { includeSpellIDs = { [spellID] = true } }
end

function M:Init()
  self.states = self.states or {}
end

function M:CreateState(track, slot)
  if InCombatLockdown() then
    if Addon.Display then Addon.Display.pendingRebuild = true end
    return nil
  end

  local uid = U.SafeInteger(track.uid, 1, Addon.MAX_TRACKS or 500)
  local spellID = U.SafeInteger(track.id, 1, Addon.MAX_SPELL_ID or 2147483647)
  if not uid or not spellID then return nil end

  local placeholder = slot:CreateTexture(nil, "BACKGROUND")
  placeholder:SetAllPoints(slot)
  placeholder:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  placeholder:SetAlpha(0.35)

  local container = CreateFrame("AuraContainer", nil, slot, "CustomAuraContainerTemplate")
  container:SetAllPoints(slot)
  container:SetUnit(track.unit)
  container:AddAuraSlot(SLOT_KEY, track.auraType, {
    initializeFrame = function(button) InitializeManagedButton(button, container) end,
    candidateFilters = BuildCandidateFilters(spellID),
    sortMethod = AuraContainerSortMethod.Default,
    sortDirection = AuraContainerSortDirection.Normal,
  })
  container:SetEnabled(true)

  local state = {
    uid = uid,
    slot = slot,
    container = container,
    placeholder = placeholder,
    spellID = spellID,
    unit = track.unit,
    auraType = track.auraType,
    enabled = true,
  }
  self.states[uid] = state
  return state
end

function M:Attach(track, slot)
  if not self.states then self:Init() end
  if InCombatLockdown() then
    if Addon.Display then Addon.Display.pendingRebuild = true end
    return false
  end

  local uid = U.SafeInteger(track.uid, 1, Addon.MAX_TRACKS or 500)
  local spellID = U.SafeInteger(track.id, 1, Addon.MAX_SPELL_ID or 2147483647)
  if not uid or not spellID then return false end

  local state = self.states[uid]
  if not state then state = self:CreateState(track, slot) end
  if not state then return false end

  if state.slot ~= slot then
    -- An AuraContainer adopts restricted descendants during AddAuraSlot.
    -- Never reparent that graph after adoption. Retire the stale graph and
    -- construct a fresh one with its final parent instead.
    state.enabled = false
    state.placeholder:Hide()
    state.container:SetEnabled(false)
    state.container:Hide()
    self.states[uid] = nil

    state = self:CreateState(track, slot)
    if not state then return false end
  end

  if state.unit ~= track.unit then
    state.container:SetUnit(track.unit)
    state.unit = track.unit
  end
  if state.auraType ~= track.auraType then
    state.container:SetAuraSlotFilterString(SLOT_KEY, track.auraType)
    state.auraType = track.auraType
  end
  if state.spellID ~= spellID then
    state.container:SetAuraSlotCandidateFilters(SLOT_KEY, BuildCandidateFilters(spellID))
    state.spellID = spellID
  end

  local wasEnabled = state.enabled == true
  state.enabled = true
  state.placeholder:SetTexture(U.GetSpellIcon(spellID) or QUESTION_ICON)
  state.placeholder:SetShown(track.showWhen == "ALWAYS")
  state.container:Show()
  if not wasEnabled then state.container:SetEnabled(true) end
  return true
end

function M:Disable(uid)
  if not self.states then return end
  uid = U.SafeInteger(uid, 1, Addon.MAX_TRACKS or 500)
  local state = uid and self.states[uid]
  if not state then return end
  if InCombatLockdown() then
    if Addon.Display then Addon.Display.pendingRebuild = true end
    return
  end
  if state.enabled ~= true then return end

  state.enabled = false
  state.placeholder:Hide()
  state.container:SetEnabled(false)
  state.container:Hide()
end

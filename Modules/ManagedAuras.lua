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

  local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  button:SetApplicationCount(count, {})

  local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  cooldown:SetAllPoints(button)
  button:SetDurationCooldown(cooldown)

  local glow = button:CreateTexture(nil, "OVERLAY", nil, 2)
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER", button, "CENTER", 0, 0)
  glow:SetSize(1, 1)
  glow:SetAlpha(0.9)
end

local function BuildCandidateFilters(spellID)
  return {
    includeSpellIDs = {
      [spellID] = true,
    },
  }
end

local function BuildSignature(track)
  return table.concat({ track.id, track.unit, track.auraType }, ":")
end

function M:Init()
  if self.states then return end
  self.states = {}

  local eventFrame = CreateFrame("Frame")
  eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
  eventFrame:SetScript("OnEvent", function(_, event)
    local changedUnit = event == "PLAYER_TARGET_CHANGED" and "target" or "focus"
    for _, state in pairs(M.states) do
      if state.unit == changedUnit and state.enabled and state.container
        and type(state.container.UpdateAllAuras) == "function" then
        state.container:UpdateAllAuras()
      end
    end
  end)
  self.eventFrame = eventFrame
end

function M:CreateState(track, slot)
  if InCombatLockdown() then
    if Addon.Display then Addon.Display.pendingRebuild = true end
    return nil
  end

  local placeholder = slot:CreateTexture(nil, "BACKGROUND")
  placeholder:SetAllPoints(slot)
  placeholder:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  placeholder:SetAlpha(0.35)

  local container = CreateFrame("AuraContainer", nil, slot, "CustomAuraContainerTemplate")
  container:SetAllPoints(slot)
  container:SetUnit(track.unit)

  local options = {
    initializeFrame = function(button)
      InitializeManagedButton(button, container)
    end,
    candidateFilters = BuildCandidateFilters(track.id),
    sortMethod = AuraContainerSortMethod.Default,
    sortDirection = AuraContainerSortDirection.Normal,
  }
  container:AddAuraSlot(SLOT_KEY, track.auraType, options)
  container:SetEnabled(true)

  local state = {
    uid = track.uid,
    slot = slot,
    container = container,
    placeholder = placeholder,
    signature = BuildSignature(track),
    unit = track.unit,
    enabled = true,
  }
  self.states[track.uid] = state
  return state
end

function M:Attach(track, slot)
  if not self.states then self:Init() end
  if InCombatLockdown() then
    if Addon.Display then Addon.Display.pendingRebuild = true end
    return false
  end

  local state = self.states[track.uid]
  if not state then state = self:CreateState(track, slot) end
  if not state then return false end

  if state.slot ~= slot then
    state.slot = slot
    state.container:SetParent(slot)
    state.container:ClearAllPoints()
    state.container:SetAllPoints(slot)
    state.placeholder:SetParent(slot)
    state.placeholder:ClearAllPoints()
    state.placeholder:SetAllPoints(slot)
  end

  local signature = BuildSignature(track)
  if state.signature ~= signature then
    state.container:SetUnit(track.unit)
    state.container:SetAuraSlotFilterString(SLOT_KEY, track.auraType)
    state.container:SetAuraSlotCandidateFilters(SLOT_KEY, BuildCandidateFilters(track.id))
    state.signature = signature
  end

  state.unit = track.unit
  state.enabled = true
  state.placeholder:SetTexture(U.GetSpellIcon(track.id) or QUESTION_ICON)
  state.placeholder:SetShown(track.showWhen == "ALWAYS")
  state.container:Show()
  state.container:SetEnabled(true)
  state.container:UpdateAllAuras()
  return true
end

function M:Disable(uid)
  if not self.states then return end
  local state = self.states[uid]
  if not state then return end
  if InCombatLockdown() then
    if Addon.Display then Addon.Display.pendingRebuild = true end
    return
  end
  state.enabled = false
  state.placeholder:Hide()
  state.container:SetEnabled(false)
  state.container:Hide()
end

function M:GetStateCount()
  local count = 0
  for _ in pairs(self.states or {}) do count = count + 1 end
  return count
end

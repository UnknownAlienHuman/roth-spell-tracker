local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.Display = Addon.Display or {}
local D = Addon.Display

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function SetCooldown(cooldown, startTime, duration)
  if not cooldown then return end
  startTime = U.SafeNumber(startTime)
  duration = U.SafeNumber(duration)
  if not startTime or not duration or duration <= 0.05 then
    startTime, duration = 0, 0
  end
  if type(cooldown.SetCooldown) == "function" then
    cooldown:SetCooldown(startTime, duration)
  elseif type(CooldownFrame_Set) == "function" then
    CooldownFrame_Set(cooldown, startTime, duration, true)
  end
end

local function CreateSpellVisual(slot)
  local visual = CreateFrame("Frame", nil, slot)
  visual:SetAllPoints(slot)

  visual.icon = visual:CreateTexture(nil, "ARTWORK")
  visual.icon:SetAllPoints(visual)
  visual.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  visual.icon:SetTexture(QUESTION_ICON)

  visual.cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
  visual.cooldown:SetAllPoints(visual)

  visual.count = visual:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  visual.count:SetPoint("BOTTOMRIGHT", visual, "BOTTOMRIGHT", -2, 2)
  visual.count:SetText("")

  visual.border = visual:CreateTexture(nil, "OVERLAY")
  visual.border:SetAllPoints(visual)
  visual.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  visual.border:SetBlendMode("ADD")
  visual.border:SetAlpha(0.45)

  visual.glow = visual:CreateTexture(nil, "OVERLAY", nil, 2)
  visual.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  visual.glow:SetBlendMode("ADD")
  visual.glow:SetPoint("CENTER", visual, "CENTER", 0, 0)
  visual.glow:SetSize(1, 1)
  visual.glow:SetAlpha(0.9)
  visual.glow:Hide()

  visual:Hide()
  return visual
end

function D:Init()
  if self.anchor then
    self:RequestRebuild()
    return
  end

  self.slots = {}
  self.order = {}
  self.pendingRebuild = false

  local anchor = CreateFrame("Frame", "RothSpellTrackerAnchor", UIParent)
  anchor:SetSize(64, 64)
  anchor:SetFrameStrata("MEDIUM")
  anchor:SetClampedToScreen(true)
  anchor:SetMovable(true)
  anchor:RegisterForDrag("LeftButton")
  self.anchor = anchor

  anchor.background = anchor:CreateTexture(nil, "BACKGROUND")
  anchor.background:SetAllPoints(anchor)
  anchor.background:SetColorTexture(0, 0, 0, 0.25)

  anchor.label = anchor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  anchor.label:SetPoint("CENTER")
  anchor.label:SetText("Roth Spell Tracker")

  anchor:SetScript("OnDragStart", function(selfFrame)
    if Addon.db.frame.locked then return end
    if InCombatLockdown() then
      Addon:Log("WARN", "Cannot move in combat")
      return
    end
    selfFrame:StartMoving()
  end)

  anchor:SetScript("OnDragStop", function(selfFrame)
    selfFrame:StopMovingOrSizing()
    D:SavePosition()
  end)

  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:SetScript("OnEvent", function()
    if D.pendingRebuild then D:Rebuild() end
  end)
  self.events = events

  self:RequestRebuild()
end

function D:SavePosition()
  if not self.anchor or InCombatLockdown() then return end
  local point, _, relativePoint, x, y = self.anchor:GetPoint(1)
  point = U.SafeString(point)
  relativePoint = U.SafeString(relativePoint)
  x = U.SafeNumber(x)
  y = U.SafeNumber(y)
  if not point or not relativePoint or not x or not y then return end

  local frame = Addon.db.frame
  frame.point = point
  frame.relPoint = relativePoint
  frame.x = math.floor(x + 0.5)
  frame.y = math.floor(y + 0.5)
end

function D:ResetPosition()
  if not Addon.db or not Addon.db.frame then return end
  Addon.db.frame.point = "CENTER"
  Addon.db.frame.relPoint = "CENTER"
  Addon.db.frame.x = 0
  Addon.db.frame.y = -120
  self:RequestRebuild()
end

function D:ApplyLock()
  if not self.anchor then return end
  if InCombatLockdown() then
    self.pendingRebuild = true
    return
  end
  local locked = Addon.db.frame.locked == true
  self.anchor.background:SetShown(not locked)
  self.anchor.label:SetShown(not locked)
  self.anchor:EnableMouse(not locked)
end

function D:EnsureSlot(track)
  local uid = U.SafeNumber(track.uid)
  if not uid then return nil end
  local slot = self.slots[uid]
  if slot then return slot end
  if InCombatLockdown() then
    self.pendingRebuild = true
    return nil
  end

  slot = CreateFrame("Frame", nil, self.anchor)
  slot.uid = uid
  slot.spell = CreateSpellVisual(slot)
  slot:Hide()
  self.slots[uid] = slot
  return slot
end

function D:GetSlot(uid)
  uid = U.SafeNumber(uid)
  return uid and self.slots and self.slots[uid] or nil
end

function D:ApplyLayout()
  if not self.anchor or InCombatLockdown() then
    self.pendingRebuild = true
    return false
  end

  local frame = Addon.db.frame
  self.anchor:ClearAllPoints()
  self.anchor:SetPoint(frame.point, UIParent, frame.relPoint, frame.x, frame.y)

  local size = frame.size
  local spacing = frame.spacing
  local grow = frame.grow
  local dx, dy = 1, 0
  if grow == "LEFT" then dx = -1
  elseif grow == "UP" then dx, dy = 0, 1
  elseif grow == "DOWN" then dx, dy = 0, -1 end

  for index, uid in ipairs(self.order) do
    local slot = self.slots[uid]
    if slot then
      slot:SetSize(size, size)
      slot:ClearAllPoints()
      slot:SetPoint(
        "CENTER",
        self.anchor,
        "CENTER",
        (index - 1) * dx * (size + spacing),
        (index - 1) * dy * (size + spacing)
      )
      if slot.spell and slot.spell.glow then
        slot.spell.glow:SetSize(size * 1.4, size * 1.4)
      end
      slot:Show()
    end
  end

  local count = math.max(1, #self.order)
  local width = size + (dx ~= 0 and (count - 1) * (size + spacing) or 0)
  local height = size + (dy ~= 0 and (count - 1) * (size + spacing) or 0)
  self.anchor:SetSize(width + 20, height + 20)
  self:ApplyLock()
  return true
end

function D:Rebuild()
  if not self.anchor or not Addon.db then return false end
  if InCombatLockdown() then
    self.pendingRebuild = true
    return false
  end

  self.pendingRebuild = false
  local seen = {}
  local order = {}
  for _, track in ipairs(Addon.db.tracks or {}) do
    if type(track) == "table" and track.enabled ~= false then
      local slot = self:EnsureSlot(track)
      if slot then
        local uid = track.uid
        seen[uid] = true
        order[#order + 1] = uid
        slot.trackKind = track.kind
        if track.kind == "AURA" then
          slot.spell:Hide()
          if Addon.ManagedAuras then Addon.ManagedAuras:Attach(track, slot) end
        else
          if Addon.ManagedAuras then Addon.ManagedAuras:Disable(uid) end
          slot.spell:Show()
        end
      end
    end
  end

  for uid, slot in pairs(self.slots) do
    if not seen[uid] then
      slot:Hide()
      slot.spell:Hide()
      if Addon.ManagedAuras then Addon.ManagedAuras:Disable(uid) end
    end
  end

  self.order = order
  return self:ApplyLayout()
end

function D:RequestRebuild()
  if not self.anchor then return end
  if InCombatLockdown() then
    self.pendingRebuild = true
    return
  end
  self:Rebuild()
end

function D:UpdateSpell(track, state)
  local slot = self:GetSlot(track.uid)
  if not slot or slot.trackKind ~= "SPELL" then
    self:RequestRebuild()
    return
  end

  local visual = slot.spell
  local active = state.active == true
  local showWhen = track.showWhen or "ALWAYS"
  local shown
  if showWhen == "READY" then
    shown = active
  elseif showWhen == "NOTREADY" then
    shown = not active
  else
    shown = true
  end

  local texture = state.icon or U.GetSpellIcon(track.id) or QUESTION_ICON
  visual.icon:SetTexture(texture)
  visual:SetShown(shown)
  visual:SetAlpha(showWhen == "ALWAYS" and (active and 1 or 0.35) or 1)
  visual.glow:SetShown(active)

  local count = U.SafeNumber(state.count)
  if count and count > 1 then
    visual.count:SetText(tostring(math.floor(count + 0.5)))
  else
    visual.count:SetText("")
  end
  SetCooldown(visual.cooldown, state.cooldownStart, state.cooldownDuration)
end

local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.Display = Addon.Display or {}
local D = Addon.Display

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local PADDING = 10

local function SetCooldown(cooldown, startTime, duration, modRate)
  if not cooldown then return false end

  startTime = U.SafeNumber(startTime)
  duration = U.SafeNumber(duration)
  modRate = U.SafeNumber(modRate)
  if not modRate or modRate <= 0 then modRate = 1 end
  if not startTime or not duration or duration <= 0.05 then
    startTime, duration, modRate = 0, 0, 1
  end

  local sameTuple = cooldown.rstStart == startTime
    and cooldown.rstDuration == duration
    and cooldown.rstModRate == modRate

  if sameTuple then
    if cooldown.rstSuppressed == true then
      if InCombatLockdown() then return false end
      cooldown.rstSuppressed = false
      cooldown:SetShown(duration > 0.05)
    end
    return true
  end

  if InCombatLockdown() then
    if cooldown.rstSuppressed ~= true then
      cooldown:Hide()
      cooldown.rstSuppressed = true
    end
    return false
  end

  if type(cooldown.SetCooldown) == "function" then
    cooldown:SetCooldown(startTime, duration, modRate)
  elseif type(CooldownFrame_Set) == "function" then
    CooldownFrame_Set(cooldown, startTime, duration, true, false, modRate)
  else
    return false
  end

  cooldown.rstStart = startTime
  cooldown.rstDuration = duration
  cooldown.rstModRate = modRate
  cooldown.rstSuppressed = false
  cooldown:SetShown(duration > 0.05)
  return true
end

local function CreateCooldown(parent, levelOffset)
  local cooldown = CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")
  cooldown:SetAllPoints(parent)
  if type(cooldown.SetFrameLevel) == "function" and type(parent.GetFrameLevel) == "function" then
    cooldown:SetFrameLevel(parent:GetFrameLevel() + (levelOffset or 1))
  end
  return cooldown
end

local function CreateSpellVisual(slot)
  local visual = CreateFrame("Frame", nil, slot)
  visual:SetAllPoints(slot)

  visual.icon = visual:CreateTexture(nil, "ARTWORK")
  visual.icon:SetAllPoints(visual)
  visual.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  visual.icon:SetTexture(QUESTION_ICON)

  visual.chargeCooldown = CreateCooldown(visual, 1)
  if type(visual.chargeCooldown.SetDrawBling) == "function" then visual.chargeCooldown:SetDrawBling(false) end
  if type(visual.chargeCooldown.SetDrawEdge) == "function" then visual.chargeCooldown:SetDrawEdge(false) end
  if type(visual.chargeCooldown.SetSwipeColor) == "function" then
    visual.chargeCooldown:SetSwipeColor(0.15, 0.45, 0.85, 0.65)
  end

  visual.cooldown = CreateCooldown(visual, 2)

  visual.lossOfControlCooldown = CreateCooldown(visual, 3)
  visual.lossOfControlCooldown:ClearAllPoints()
  visual.lossOfControlCooldown:SetPoint("TOPLEFT", visual, "TOPLEFT", 3, -3)
  visual.lossOfControlCooldown:SetPoint("BOTTOMRIGHT", visual, "BOTTOMRIGHT", -3, 3)
  if type(visual.lossOfControlCooldown.SetDrawBling) == "function" then
    visual.lossOfControlCooldown:SetDrawBling(false)
  end
  if type(visual.lossOfControlCooldown.SetHideCountdownNumbers) == "function" then
    visual.lossOfControlCooldown:SetHideCountdownNumbers(true)
  end

  visual.overlay = CreateFrame("Frame", nil, visual)
  visual.overlay:SetAllPoints(visual)
  if type(visual.overlay.SetFrameLevel) == "function" and type(visual.GetFrameLevel) == "function" then
    visual.overlay:SetFrameLevel(visual:GetFrameLevel() + 4)
  end

  visual.count = visual.overlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  visual.count:SetPoint("BOTTOMRIGHT", visual.overlay, "BOTTOMRIGHT", -2, 2)
  visual.count:SetText("")

  visual.border = visual.overlay:CreateTexture(nil, "OVERLAY")
  visual.border:SetAllPoints(visual.overlay)
  visual.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  visual.border:SetBlendMode("ADD")
  visual.border:SetAlpha(0.45)

  visual.glow = visual.overlay:CreateTexture(nil, "OVERLAY", nil, 2)
  visual.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  visual.glow:SetBlendMode("ADD")
  visual.glow:SetPoint("CENTER", visual.overlay, "CENTER", 0, 0)
  visual.glow:SetSize(1, 1)
  visual.glow:SetAlpha(0.9)
  visual.glow:Hide()

  visual:Hide()
  return visual
end

local function ResetSpellVisual(slot)
  local visual = slot and slot.spell
  if not visual then return end

  visual:Hide()
  visual:SetAlpha(1)
  visual.icon:SetTexture(QUESTION_ICON)
  visual.count:SetText("")
  visual.glow:Hide()
  visual.rstShown = false
  visual.rstAlpha = 1
  visual.rstTexture = QUESTION_ICON
  visual.rstCount = ""
  visual.rstGlow = false
  SetCooldown(visual.chargeCooldown, nil, nil, nil)
  SetCooldown(visual.cooldown, nil, nil, nil)
  SetCooldown(visual.lossOfControlCooldown, nil, nil, nil)
end

function D:Init()
  if self.anchor then return end

  self.slots = {}
  self.order = {}
  self.pendingRebuild = false
  self.pendingLayout = false

  local origin = CreateFrame("Frame", nil, UIParent)
  origin:SetSize(1, 1)
  self.origin = origin

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
      Addon:Notify("WARN", "Cannot move the tracker in combat")
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
  events:RegisterEvent("UI_SCALE_CHANGED")
  events:RegisterEvent("DISPLAY_SIZE_CHANGED")
  events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if D.pendingRebuild then
        D:Rebuild()
      elseif D.pendingLayout then
        D:ApplyLayout()
      end
    else
      D:RequestLayout()
    end
  end)
  self.events = events
end

function D:SavePosition()
  if not self.anchor or InCombatLockdown() then return end

  local x, y
  local firstUID = self.order and self.order[1]
  local firstSlot = firstUID and self.slots[firstUID]
  if firstSlot and type(firstSlot.GetCenter) == "function" then x, y = firstSlot:GetCenter() end
  if (not x or not y) and type(self.anchor.GetCenter) == "function" then x, y = self.anchor:GetCenter() end
  if not x or not y or not UIParent or type(UIParent.GetCenter) ~= "function" then return end

  local parentX, parentY = UIParent:GetCenter()
  x, y = U.SafeNumber(x), U.SafeNumber(y)
  parentX, parentY = U.SafeNumber(parentX), U.SafeNumber(parentY)
  if not x or not y or not parentX or not parentY then return end

  local frame = Addon.db.frame
  frame.point = "CENTER"
  frame.relPoint = "CENTER"
  frame.x = math.floor(x - parentX + 0.5)
  frame.y = math.floor(y - parentY + 0.5)
  self:RequestLayout()
end

function D:ResetPosition()
  if not Addon.db or not Addon.db.frame then return end
  Addon.db.frame.point = "CENTER"
  Addon.db.frame.relPoint = "CENTER"
  Addon.db.frame.x = 0
  Addon.db.frame.y = -120
  self:RequestLayout()
end

function D:ApplyLock()
  if not self.anchor then return end
  if InCombatLockdown() then
    self.pendingLayout = true
    return
  end

  local locked = Addon.db.frame.locked == true
  self.anchor.background:SetShown(not locked)
  self.anchor.label:SetShown(not locked)
  self.anchor:EnableMouse(not locked)
end

function D:EnsureSlot(track)
  local uid = U.SafeInteger(track.uid, 1, Addon.MAX_TRACKS or 500)
  if not uid then return nil end

  local slot = self.slots[uid]
  if slot then return slot end
  if InCombatLockdown() then
    self.pendingRebuild = true
    return nil
  end

  slot = CreateFrame("Frame", nil, self.anchor)
  slot.uid = uid
  slot:Hide()
  self.slots[uid] = slot
  return slot
end

function D:GetSlot(uid)
  uid = U.SafeInteger(uid, 1, Addon.MAX_TRACKS or 500)
  return uid and self.slots and self.slots[uid] or nil
end

function D:ApplyLayout()
  if not self.anchor or not self.origin or InCombatLockdown() then
    self.pendingLayout = true
    return false
  end

  self.pendingLayout = false
  local frame = Addon.db.frame
  local size = frame.size
  local spacing = frame.spacing
  local grow = frame.grow
  local count = #self.order
  local extentCount = math.max(1, count)
  local horizontal = grow == "RIGHT" or grow == "LEFT"
  local width = horizontal and (extentCount * size + (extentCount - 1) * spacing + PADDING * 2) or (size + PADDING * 2)
  local height = horizontal and (size + PADDING * 2) or (extentCount * size + (extentCount - 1) * spacing + PADDING * 2)

  self.origin:ClearAllPoints()
  self.origin:SetPoint(frame.point, UIParent, frame.relPoint, frame.x, frame.y)

  self.anchor:ClearAllPoints()
  self.anchor:SetSize(width, height)
  if grow == "LEFT" then
    self.anchor:SetPoint("RIGHT", self.origin, "CENTER", PADDING + size / 2, 0)
  elseif grow == "UP" then
    self.anchor:SetPoint("BOTTOM", self.origin, "CENTER", 0, -(PADDING + size / 2))
  elseif grow == "DOWN" then
    self.anchor:SetPoint("TOP", self.origin, "CENTER", 0, PADDING + size / 2)
  else
    self.anchor:SetPoint("LEFT", self.origin, "CENTER", -(PADDING + size / 2), 0)
  end

  for index, uid in ipairs(self.order) do
    local slot = self.slots[uid]
    if slot then
      local offset = (index - 1) * (size + spacing)
      slot:SetSize(size, size)
      slot:ClearAllPoints()
      if grow == "LEFT" then
        slot:SetPoint("RIGHT", self.anchor, "RIGHT", -(PADDING + offset), 0)
      elseif grow == "UP" then
        slot:SetPoint("BOTTOM", self.anchor, "BOTTOM", 0, PADDING + offset)
      elseif grow == "DOWN" then
        slot:SetPoint("TOP", self.anchor, "TOP", 0, -(PADDING + offset))
      else
        slot:SetPoint("LEFT", self.anchor, "LEFT", PADDING + offset, 0)
      end
      if slot.spell and slot.spell.glow then slot.spell.glow:SetSize(size * 1.4, size * 1.4) end
      slot:Show()
    end
  end

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
  self.pendingLayout = false
  local seen = {}
  local order = {}

  for _, track in ipairs(Addon.db.tracks or {}) do
    if type(track) == "table" and track.enabled ~= false then
      local slot = self:EnsureSlot(track)
      if slot and not seen[slot.uid] then
        local uid = slot.uid
        seen[uid] = true
        order[#order + 1] = uid

        if track.kind == "SPELL" and not slot.spell then slot.spell = CreateSpellVisual(slot) end
        if slot.trackKind ~= track.kind then ResetSpellVisual(slot) end
        slot.trackKind = track.kind

        if track.kind == "AURA" then
          if slot.spell then slot.spell:Hide() end
          if Addon.ManagedAuras then Addon.ManagedAuras:Attach(track, slot) end
        else
          if Addon.ManagedAuras then Addon.ManagedAuras:Disable(uid) end
        end
      end
    end
  end

  for uid, slot in pairs(self.slots) do
    if not seen[uid] then
      slot.trackKind = nil
      slot:Hide()
      ResetSpellVisual(slot)
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

function D:RequestLayout()
  if not self.anchor then return end
  if InCombatLockdown() then
    self.pendingLayout = true
    return
  end
  self:ApplyLayout()
end

function D:UpdateSpell(track, state)
  local slot = self:GetSlot(track.uid)
  if not slot or slot.trackKind ~= "SPELL" then
    self:RequestRebuild()
    return
  end

  local visual = slot.spell
  if not visual or type(state) ~= "table" then
    self:RequestRebuild()
    return
  end

  local active = state.active == true
  local showWhen = track.showWhen or "ALWAYS"
  local shown = showWhen == "READY" and active
    or showWhen == "NOTREADY" and not active
    or showWhen ~= "READY" and showWhen ~= "NOTREADY"
  local alpha = showWhen == "ALWAYS" and (active and 1 or 0.35) or 1
  local texture = state.icon or U.GetSpellIcon(track.id) or QUESTION_ICON
  local count = U.SafeNumber(state.count)
  local countText = state.showCount == true and count and tostring(math.floor(count + 0.5)) or ""

  if visual.rstTexture ~= texture then visual.icon:SetTexture(texture); visual.rstTexture = texture end
  if visual.rstShown ~= shown then visual:SetShown(shown); visual.rstShown = shown end
  if visual.rstAlpha ~= alpha then visual:SetAlpha(alpha); visual.rstAlpha = alpha end
  if visual.rstGlow ~= active then visual.glow:SetShown(active); visual.rstGlow = active end
  if visual.rstCount ~= countText then visual.count:SetText(countText); visual.rstCount = countText end

  SetCooldown(visual.chargeCooldown, state.chargeCooldownStart, state.chargeCooldownDuration, state.chargeCooldownModRate)
  SetCooldown(visual.cooldown, state.cooldownStart, state.cooldownDuration, state.cooldownModRate)
  SetCooldown(visual.lossOfControlCooldown, state.lossOfControlStart, state.lossOfControlDuration, state.lossOfControlModRate)
end

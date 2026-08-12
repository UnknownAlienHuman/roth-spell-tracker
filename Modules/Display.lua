local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.Display = Addon.Display or {}
local D = Addon.Display

local function SetCooldown(cd, startTime, duration)
  if not cd then return end
  if CooldownFrame_Set then
    CooldownFrame_Set(cd, startTime or 0, duration or 0, true)
    return
  end
  if cd.SetCooldown then
    cd:SetCooldown(startTime or 0, duration or 0)
  end
end

-- Blizzard-style proc glow overlay (SpellActivationAlert templates).
-- This is intentionally copied in spirit from InterruptGlow (same author) to be:
--  * resilient to template name differences
--  * safe to call on addon-owned frames
local PROC_TEMPLATES = {
  "ActionButtonSpellAlertTemplate",
  "ActionBarButtonSpellActivationAlert",
  "ActionButtonSpellActivationAlert",
  "SpellActivationAlertTemplate",
  "SpellActivationAlert",
}

local function EnsureGlow(frame)
  if not frame or not CreateFrame then return nil end
  if frame.__RST_Alert then return frame.__RST_Alert end
  if frame.IsForbidden and frame:IsForbidden() then return nil end

  local w, h = 0, 0
  if frame.GetSize then w, h = frame:GetSize() end

  for i = 1, #PROC_TEMPLATES do
    local tmpl = PROC_TEMPLATES[i]
    local ok, alert = pcall(CreateFrame, "Frame", nil, frame, tmpl)
    if ok and alert then
      if w and h and w > 0 and h > 0 then
        alert:SetSize(w * 1.4, h * 1.4)
      else
        alert:SetAllPoints(frame)
      end
      alert:SetPoint("CENTER", frame, "CENTER", 0, 0)
      alert:SetFrameStrata("HIGH")
      alert:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 50)
      alert:Hide()

      frame.__RST_Alert = alert
      return alert
    end
  end

  return nil
end

local function HookAlertAnims(alert)
  if not alert or alert.__RST_AnimHooked or not alert.HookScript then return end
  alert.__RST_AnimHooked = true

  local function SafePlay(obj)
    if obj and obj.Play then pcall(obj.Play, obj) end
  end
  local function SafeStop(obj)
    if obj and obj.Stop then pcall(obj.Stop, obj) end
  end

  local function StartProc(self)
    local start = self.ProcStartAnim or self.procStartAnim or self.AnimIn or self.animIn
    local loop  = self.ProcLoopAnim  or self.procLoopAnim  or self.AnimLoop or self.animLoop

    local startFB = self.ProcStartFlipbook or self.procStartFlipbook
    local loopFB  = self.ProcLoopFlipbook  or self.procLoopFlipbook
    local loopFB2 = self.ProcLoopFlipbook2 or self.procLoopFlipbook2
    local loopFB3 = self.ProcLoopFlipbook3 or self.procLoopFlipbook3

    local out = self.ProcEndAnim or self.procEndAnim or self.AnimOut or self.animOut
    if out and out.IsPlaying and out:IsPlaying() then pcall(out.Stop, out) end

    SafePlay(start or startFB)
    SafePlay(loop or loopFB)
    SafePlay(loopFB2)
    SafePlay(loopFB3)
  end

  local function StopProc(self)
    local out = self.ProcEndAnim or self.procEndAnim or self.AnimOut or self.animOut
    if out and out.Play then
      pcall(out.Play, out)
      return
    end

    SafeStop(self.ProcStartAnim or self.procStartAnim or self.AnimIn or self.animIn)
    SafeStop(self.ProcLoopAnim  or self.procLoopAnim  or self.AnimLoop or self.animLoop)
    SafeStop(self.ProcStartFlipbook or self.procStartFlipbook)
    SafeStop(self.ProcLoopFlipbook  or self.procLoopFlipbook)
    SafeStop(self.ProcLoopFlipbook2 or self.procLoopFlipbook2)
    SafeStop(self.ProcLoopFlipbook3 or self.procLoopFlipbook3)
  end

  alert:HookScript("OnShow", StartProc)
  alert:HookScript("OnHide", StopProc)
end

local function SetGlow(frame, enabled)
  local alert = EnsureGlow(frame)
  if not alert then return end
  HookAlertAnims(alert)
  alert:SetShown(enabled == true)
end

function D:Init()
  if self.anchor then
    self:ApplyLayout()
    self:ApplyLock()
    return
  end

  local f = CreateFrame("Frame", "RothSpellTrackerAnchor", UIParent)
  f:SetSize(200, 60)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)

  self.anchor = f
  self.icons = {}

  f.bg = f:CreateTexture(nil, "BACKGROUND")
  f.bg:SetAllPoints(true)
  f.bg:SetColorTexture(0, 0, 0, 0.25)

  f.label = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  f.label:SetPoint("CENTER")
  f.label:SetText("Roth Spell Tracker")

  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    if Addon.db.frame.locked then return end
    if InCombatLockdown and InCombatLockdown() then
      Addon:Log("WARN", "Cannot move in combat")
      return
    end
    f:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    D:SavePosition()
  end)

  self:ApplyLayout()
  self:ApplyLock()
end

function D:SavePosition()
  if not self.anchor then return end
  local p, _, rp, x, y = self.anchor:GetPoint(1)
  if not p then return end
  local dbf = Addon.db.frame
  dbf.point = p
  dbf.relPoint = rp
  dbf.x = math.floor((x or 0) + 0.5)
  dbf.y = math.floor((y or 0) + 0.5)
end

function D:ResetPosition()
  local dbf = Addon.db and Addon.db.frame
  if not dbf then return end
  dbf.point = "CENTER"
  dbf.relPoint = "CENTER"
  dbf.x = 0
  dbf.y = -120
  self:ApplyLayout()
end

function D:ApplyLayout()
  if not self.anchor then return end
  local dbf = Addon.db.frame

  self.anchor:ClearAllPoints()
  self.anchor:SetPoint(dbf.point, UIParent, dbf.relPoint, dbf.x, dbf.y)

  local size = dbf.size or 44
  local spacing = dbf.spacing or 6

  -- layout icons
  local grow = dbf.grow or "RIGHT"

  local ox, oy = 0, 0
  local dx, dy = 1, 0
  if grow == "LEFT" then dx = -1; dy = 0
  elseif grow == "UP" then dx = 0; dy = 1
  elseif grow == "DOWN" then dx = 0; dy = -1 end

  local count = self.count or #self.icons
  for i = 1, count do
    local ic = self.icons[i]
    ic:SetSize(size, size)
    ic:ClearAllPoints()
    ic:SetPoint("CENTER", self.anchor, "CENTER",
      ox + (i - 1) * dx * (size + spacing),
      oy + (i - 1) * dy * (size + spacing)
    )
  end

  -- anchor extents (approx)
  count = math.max(1, count)
  local w = size + (dx ~= 0 and (count - 1) * (size + spacing) or 0)
  local h = size + (dy ~= 0 and (count - 1) * (size + spacing) or 0)
  self.anchor:SetSize(w + 20, h + 20)
end

function D:ApplyLock()
  if not self.anchor then return end
  local locked = Addon.db.frame.locked == true
  self.anchor.bg:SetShown(not locked)
  self.anchor.label:SetShown(not locked)
  self.anchor:EnableMouse(not locked)
end

function D:GetIcon(i)
  local ic = self.icons[i]
  if ic then return ic end

  ic = CreateFrame("Frame", nil, self.anchor)
  ic:SetSize(Addon.db.frame.size or 44, Addon.db.frame.size or 44)
  ic:SetFrameStrata("HIGH")

  ic.tex = ic:CreateTexture(nil, "ARTWORK")
  ic.tex:SetAllPoints(true)
  ic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  ic.count = ic:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  ic.count:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -2, 2)
  ic.count:SetText("")

  ic.cooldown = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
  ic.cooldown:SetAllPoints(true)

  ic.border = ic:CreateTexture(nil, "OVERLAY")
  ic.border:SetAllPoints(true)
  ic.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  ic.border:SetBlendMode("ADD")
  ic.border:SetAlpha(0.75)

  ic:SetAlpha(1)
  ic.__RST_Glow = false

  ic:SetShown(false)
  self.icons[i] = ic
  return ic
end

function D:SetIconGlow(i, active)
  local ic = self.icons[i]
  if not ic then return end
  if active == ic.__RST_Glow then return end
  ic.__RST_Glow = active == true
  SetGlow(ic, ic.__RST_Glow)
end

function D:SetIconAlpha(i, alpha)
  local ic = self.icons[i]
  if not ic or not ic.SetAlpha then return end
  if type(alpha) ~= "number" then alpha = 1 end
  ic:SetAlpha(alpha)
end

function D:UpdateIconCount(i, n)
  local ic = self.icons[i]
  if not ic or not ic.count then return end
  if type(n) == "number" and n > 1 then
    ic.count:SetText(tostring(n))
  else
    ic.count:SetText("")
  end
end

function D:UpdateIconCooldown(i, startTime, duration)
  local ic = self.icons[i]
  if not ic or not ic.cooldown then return end

  if type(startTime) == "number" and type(duration) == "number" and duration > 0.05 then
    SetCooldown(ic.cooldown, startTime, duration)
  else
    SetCooldown(ic.cooldown, 0, 0)
  end
end

function D:UpdateIconTexture(i, tex)
  local ic = self.icons[i]
  if not ic or not ic.tex then return end
  if tex then ic.tex:SetTexture(tex) end
end

function D:SetIconShown(i, shown)
  local ic = self.icons[i]
  if not ic then return end
  U.SafeSetShown(ic, shown)
end

function D:SetCount(n)
  self.count = tonumber(n) or 0
  if self.count < 0 then self.count = 0 end
  -- ensure pool size
  for i = #self.icons + 1, self.count do
    self:GetIcon(i)
  end

  -- hide the rest
  for i = self.count + 1, #self.icons do
    self:SetIconShown(i, false)
  end

  self:ApplyLayout()
end

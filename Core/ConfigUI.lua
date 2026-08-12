local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

local UI = {}
Addon.UI = UI

-- ==========================================================
-- Dropdown data
-- ==========================================================

local KINDS = {
  { key = "SPELL", text = "Spell (usable)" },
  { key = "AURA",  text = "Aura" },
}

local SHOW_SPELL = {
  { key = "ALWAYS",   text = "Always" },
  { key = "READY",    text = "Only when usable" },
  { key = "NOTREADY", text = "Only when NOT usable" },
}

local SHOW_AURA = {
  { key = "ALWAYS",   text = "Always" },
  { key = "ACTIVE",   text = "Only when active" },
  { key = "INACTIVE", text = "Only when missing" },
}

local UNITS = {
  { key = "player", text = "player" },
  { key = "target", text = "target" },
  { key = "focus",  text = "focus" },
}

local AURATYPES = {
  { key = "HELPFUL", text = "HELPFUL (buff)" },
  { key = "HARMFUL", text = "HARMFUL (debuff)" },
}

local GROWS = {
  { key = "RIGHT", text = "RIGHT" },
  { key = "LEFT",  text = "LEFT" },
  { key = "UP",    text = "UP" },
  { key = "DOWN",  text = "DOWN" },
}

local function EnsureDropdown(drop)
  if drop._rstInit then return end
  UIDropDownMenu_SetWidth(drop, 170)
  UIDropDownMenu_SetText(drop, "")
  drop._rstInit = true
end

local function SetDropdownValue(drop, value, display)
  drop.value = value
  UIDropDownMenu_SetText(drop, display or tostring(value))
end

local function InitDropdown(drop, items, onSelect)
  EnsureDropdown(drop)
  UIDropDownMenu_Initialize(drop, function(_, level)
    for i = 1, #items do
      local it = items[i]
      local info = UIDropDownMenu_CreateInfo()
      info.text = it.text
      info.value = it.key
      info.func = function()
        SetDropdownValue(drop, it.key, it.text)
        if onSelect then onSelect(it.key) end
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)
end

-- ==========================================================
-- Small UI helpers
-- ==========================================================

local function CreateLabel(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function TryCreateInset(parent)
  local templates = { "InsetFrameTemplate3", "InsetFrameTemplate2", "InsetFrameTemplate" }
  for i = 1, #templates do
    local ok, fr = pcall(CreateFrame, "Frame", nil, parent, templates[i])
    if ok and fr then
      return fr
    end
  end
  return nil
end

local function CreateEditBox(parent, width, height, x, y)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetSize(width, height)
  eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); if UI.SaveEntryFromForm then UI:SaveEntryFromForm() end end)
  return eb
end

local function CreateCheckbox(parent, label, x, y, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb.Text:SetText(label)
  cb:SetScript("OnClick", function(self) if onClick then onClick(self:GetChecked() == true) end end)
  return cb
end

local function CreateButton(parent, text, width, height, x, y, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, height)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function CreateSlider(parent, label, minV, maxV, step, x, y, width, get, set)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  s:SetWidth(width)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  local n = s.GetName and s:GetName() or nil
  local txt = s.Text or (n and _G[n .. "Text"]) or nil
  local low = s.Low  or (n and _G[n .. "Low"])  or nil
  local high = s.High or (n and _G[n .. "High"]) or nil
  if txt and txt.SetText then txt:SetText(label) end
  if low and low.SetText then low:SetText(tostring(minV)) end
  if high and high.SetText then high:SetText(tostring(maxV)) end
  s:SetScript("OnValueChanged", function(self, v)
    v = math.floor(v / step + 0.5) * step
    set(v)
    local nn = self.GetName and self:GetName() or nil
    local t = self.Text or (nn and _G[nn .. "Text"]) or nil
    if t and t.SetText then
      t:SetText(label .. ": " .. v)
    end
  end)
  local v = get()
  s:SetValue(v)
  if txt and txt.SetText then txt:SetText(label .. ": " .. v) end
  return s
end

-- ==========================================================
-- Data helpers
-- ==========================================================

local function EnsureDBTracks()
  if not (Addon.db and type(Addon.db.tracks) == "table") then
    Addon.db.tracks = {}
  end
  return Addon.db.tracks
end

local function FindExistingIndex(tracks, id, kind)
  for i = 1, #tracks do
    local e = tracks[i]
    if type(e) == "table" and e.id == id and (e.kind or "AURA") == kind then
      return i
    end
  end
  return nil
end

local function KindDefaultShow(kind)
  return "ALWAYS"
end

local function PrettyEntry(e)
  if type(e) ~= "table" then return "" end
  local id = e.id
  local kind = e.kind or "AURA"
  local name = U.GetSpellName(id) or "unknown"

  if kind == "AURA" then
    local unit = e.unit or "player"
    local at = e.auraType or "HELPFUL"
    local ms = tonumber(e.minStacks) or 0
    local extra = unit .. " " .. at
    if ms and ms > 0 then extra = extra .. " stacks≥" .. ms end
    return ("%d  |cffaaaaaa(Aura)|r  %s  |cff666666[%s]|r"):format(id, name, extra)
  end

  local ig = (e.ignoreGCD ~= false) and "ignoreGCD" or "GCD"
  return ("%d  |cffaaaaaa(Spell)|r  %s  |cff666666[%s]|r"):format(id, name, ig)
end

-- ==========================================================
-- UI creation
-- ==========================================================

function UI:Create()
  if self.frame then return end

  local f = CreateFrame("Frame", "RothSpellTrackerConfigFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(660, 560)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()

  f.Title:SetText("Roth Spell Tracker")
  self.frame = f

  -- Decorative insets (safe: no layout dependency)
  do
    local topInset = TryCreateInset(f)
    if topInset then
      topInset:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
      topInset:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -56)
      topInset:SetHeight(250)
      topInset:SetFrameLevel(f:GetFrameLevel() - 1)
      self._topInset = topInset
    end

    local listInset = TryCreateInset(f)
    if listInset then
      listInset:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -328)
      listInset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
      listInset:SetFrameLevel(f:GetFrameLevel() - 1)
      self._listInset = listInset
    end
  end

  -- Add / Edit section
  CreateLabel(f, "Add / Edit:", 18, -36)

  -- ID
  self.idLabel = CreateLabel(f, "ID", 18, -60)
  self.idBox = CreateEditBox(f, 100, 20, 18, -80)
  self.idBox:SetNumeric(true)

  -- Icon preview
  self.idIcon = f:CreateTexture(nil, "ARTWORK")
  self.idIcon:SetSize(20, 20)
  self.idIcon:SetPoint("LEFT", self.idBox, "RIGHT", 10, 0)
  self.idIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  self.idName = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  self.idName:SetPoint("LEFT", self.idIcon, "RIGHT", 8, 0)
  self.idName:SetWidth(240)
  self.idName:SetJustifyH("LEFT")

  -- Kind
  self.kindLabel = CreateLabel(f, "Type", 420, -60)
  self.kindDrop = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  self.kindDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 410, -72)

  -- Show
  self.showLabel = CreateLabel(f, "Show", 18, -112)
  self.showDrop = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  self.showDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -124)

  -- Aura fields
  self.unitLabel = CreateLabel(f, "Unit", 220, -112)
  self.unitDrop = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  self.unitDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 210, -124)

  self.auraLabel = CreateLabel(f, "Aura type", 420, -112)
  self.auraDrop = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  self.auraDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 410, -124)

  self.stacksLabel = CreateLabel(f, "Min stacks", 18, -156)
  self.stacksBox = CreateEditBox(f, 70, 20, 18, -176)
  self.stacksBox:SetNumeric(true)

  -- Spell fields
  self.ignoreGCDCB = CreateCheckbox(f, "Ignore GCD", 220, -176, function(v)
    -- stored on save
  end)

  -- Buttons
  self.saveBtn = CreateButton(f, "Save", 90, 22, 420, -176, function() UI:SaveEntryFromForm() end)
  self.clearBtn = CreateButton(f, "Clear", 70, 22, 516, -176, function() UI:ClearForm() end)

  -- Global settings
  CreateLabel(f, "Global:", 18, -214)

  self.lockCB = CreateCheckbox(f, "Lock tracker frame", 18, -236, function(v)
    Addon.db.frame.locked = v and true or false
    Addon:ApplyFrameLock()
  end)

  self.debugCB = CreateCheckbox(f, "Debug log to chat", 220, -236, function(v)
    Addon:SetDebug(v)
  end)

  self.mmHideCB = CreateCheckbox(f, "Hide minimap icon", 420, -236, function(v)
    Addon.db.minimap.hide = v and true or false
    Addon:UpdateMinimapIcon()
  end)

  self.sizeSlider = CreateSlider(f, "Icon size", 24, 96, 1, 18, -266, 220,
    function() return Addon.db.frame.size end,
    function(v) Addon.db.frame.size = v; Addon.Display:ApplyLayout() end
  )

  self.spacingSlider = CreateSlider(f, "Spacing", 0, 30, 1, 260, -266, 220,
    function() return Addon.db.frame.spacing end,
    function(v) Addon.db.frame.spacing = v; Addon.Display:ApplyLayout() end
  )

  -- Grow direction
  self.growLabel = CreateLabel(f, "Grow", 500, -262)
  self.growDrop = CreateFrame("Frame", nil, f, "UIDropDownMenuTemplate")
  self.growDrop:SetPoint("TOPLEFT", f, "TOPLEFT", 490, -274)

  -- Tracks list
  -- Utility buttons (above the list)
  self.resetPosBtn = CreateButton(f, "Reset position", 110, 22, 420, -304, function()
    if Addon.Display and Addon.Display.ResetPosition then
      Addon.Display:ResetPosition()
    end
  end)

  self.resetDBBtn = CreateButton(f, "Reset DB", 90, 22, 536, -304, function()
    Addon:ResetDB()
    UI:ClearForm()
    UI:Refresh()
  end)

  CreateLabel(f, "Tracked:", 18, -312)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -334)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 14)

  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(1, 1)
  scroll:SetScrollChild(child)

  self.scroll = scroll
  self.listChild = child
  self.rows = {}
  self.selectedIndex = nil

  -- Dropdowns init
  InitDropdown(self.kindDrop, KINDS, function(kind)
    UI:OnKindChanged(kind)
  end)

  InitDropdown(self.unitDrop, UNITS, nil)
  InitDropdown(self.auraDrop, AURATYPES, nil)
  InitDropdown(self.growDrop, GROWS, function(v)
    Addon.db.frame.grow = v
    Addon.Display:ApplyLayout()
  end)

  self:ClearForm()
end

function UI:OnKindChanged(kind)
  kind = kind or "AURA"

  local showItems = (kind == "SPELL") and SHOW_SPELL or SHOW_AURA
  InitDropdown(self.showDrop, showItems, nil)

  -- default selections
  if not self.showDrop.value then
    SetDropdownValue(self.showDrop, KindDefaultShow(kind), "Always")
  end

  -- show/hide kind-specific fields
  local isAura = (kind == "AURA")
  self.unitDrop:SetShown(isAura)
  self.auraDrop:SetShown(isAura)
  self.stacksBox:SetShown(isAura)

  if self.unitLabel then self.unitLabel:SetShown(isAura) end
  if self.auraLabel then self.auraLabel:SetShown(isAura) end
  if self.stacksLabel then self.stacksLabel:SetShown(isAura) end

  self.ignoreGCDCB:SetShown(not isAura)
end

function UI:UpdateIDPreview()
  if not self.idBox then return end
  local id = U.ToNumber(self.idBox:GetText())
  local tex = id and U.GetSpellIcon(id) or nil
  local name = id and U.GetSpellName(id) or nil

  if tex then
    self.idIcon:SetTexture(tex)
    self.idIcon:Show()
  else
    self.idIcon:Hide()
  end

  if id and name then
    self.idName:SetText(name)
  elseif id then
    self.idName:SetText("unknown")
  else
    self.idName:SetText("")
  end
end

function UI:ClearForm()
  self.selectedIndex = nil
  self.idBox:SetText("")
  self.stacksBox:SetText("0")

  local k = KINDS[1]
  SetDropdownValue(self.kindDrop, k.key, k.text)
  self:OnKindChanged(k.key)

  SetDropdownValue(self.showDrop, "ALWAYS", "Always")

  local u = UNITS[1]
  SetDropdownValue(self.unitDrop, u.key, u.text)

  local a = AURATYPES[1]
  SetDropdownValue(self.auraDrop, a.key, a.text)

  self.ignoreGCDCB:SetChecked(true)

  self:UpdateIDPreview()
end

function UI:LoadEntryToForm(index)
  local tracks = EnsureDBTracks()
  local e = tracks[index]
  if type(e) ~= "table" then return end

  self.selectedIndex = index
  self.idBox:SetText(tostring(e.id or ""))

  local kind = e.kind or "AURA"
  for i = 1, #KINDS do
    if KINDS[i].key == kind then
      SetDropdownValue(self.kindDrop, kind, KINDS[i].text)
      break
    end
  end

  self:OnKindChanged(kind)

  local showWhen = e.showWhen or KindDefaultShow(kind)
  local items = (kind == "SPELL") and SHOW_SPELL or SHOW_AURA
  for i = 1, #items do
    if items[i].key == showWhen then
      SetDropdownValue(self.showDrop, showWhen, items[i].text)
      break
    end
  end

  local unit = e.unit or "player"
  for i = 1, #UNITS do
    if UNITS[i].key == unit then
      SetDropdownValue(self.unitDrop, unit, UNITS[i].text)
      break
    end
  end

  local auraType = e.auraType or "HELPFUL"
  for i = 1, #AURATYPES do
    if AURATYPES[i].key == auraType then
      SetDropdownValue(self.auraDrop, auraType, AURATYPES[i].text)
      break
    end
  end

  self.stacksBox:SetText(tostring(e.minStacks or 0))
  self.ignoreGCDCB:SetChecked(e.ignoreGCD ~= false)

  self:UpdateIDPreview()
end

function UI:SaveEntryFromForm()
  local id = U.ToNumber(self.idBox:GetText())
  if not id or id < 1 then
    Addon:Log("ERROR", "Invalid ID")
    return
  end

  local kind = self.kindDrop.value or "AURA"
  local showWhen = self.showDrop.value or KindDefaultShow(kind)

  local entry = {
    id = id,
    kind = kind,
    enabled = true,
    showWhen = showWhen,
  }

  if kind == "AURA" then
    entry.unit = self.unitDrop.value or "player"
    entry.auraType = self.auraDrop.value or "HELPFUL"
    entry.minStacks = U.ToNumber(self.stacksBox:GetText()) or 0
  else
    entry.ignoreGCD = (self.ignoreGCDCB:GetChecked() == true)
  end

  local tracks = EnsureDBTracks()

  if self.selectedIndex and tracks[self.selectedIndex] then
    -- Edit existing row
    local old = tracks[self.selectedIndex]
    entry.enabled = (old.enabled ~= false)
    tracks[self.selectedIndex] = entry
    Addon:Log("INFO", ("Updated %d (%s)"):format(id, kind))
  else
    -- Add: de-duplicate by (id,kind)
    local existing = FindExistingIndex(tracks, id, kind)
    if existing then
      local old = tracks[existing]
      entry.enabled = (old.enabled ~= false)
      tracks[existing] = entry
      Addon:Log("INFO", ("Updated %d (%s)"):format(id, kind))
    else
      tracks[#tracks + 1] = entry
      Addon:Log("INFO", ("Added %d (%s)"):format(id, kind))
    end
  end

  self.selectedIndex = nil
  self:Refresh()
  Addon.Tracker:RequestRefresh()
end

function UI:RemoveEntry(index)
  local tracks = EnsureDBTracks()
  if not tracks[index] then return end
  local id = tracks[index].id
  table.remove(tracks, index)
  Addon:Log("INFO", ("Removed %s"):format(tostring(id)))

  if self.selectedIndex == index then
    self:ClearForm()
  elseif self.selectedIndex and self.selectedIndex > index then
    self.selectedIndex = self.selectedIndex - 1
  end

  self:Refresh()
  Addon.Tracker:RequestRefresh()
end

local function EnsureRow(self, idx)
  local row = self.rows[idx]
  if row then return row end

  local parent = self.listChild
  row = CreateFrame("Frame", nil, parent)
  row:SetSize(600, 26)

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints(true)
  row.bg:SetColorTexture(0, 0, 0, 0.15)

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.enable = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  row.enable:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  row.enable:SetSize(24, 24)

  row.upBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.upBtn:SetSize(22, 20)
  row.upBtn:SetPoint("LEFT", row.enable, "RIGHT", 2, 0)
  row.upBtn:SetText("^")

  row.downBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.downBtn:SetSize(22, 20)
  row.downBtn:SetPoint("LEFT", row.upBtn, "RIGHT", 2, 0)
  row.downBtn:SetText("v")

  row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.text:SetPoint("LEFT", row.downBtn, "RIGHT", 4, 0)
  row.text:SetWidth(320)
  row.text:SetJustifyH("LEFT")

  row.sel = row:CreateTexture(nil, "HIGHLIGHT")
  row.sel:SetAllPoints(true)
  row.sel:SetColorTexture(1, 1, 1, 0.06)
  row.sel:Hide()

  row.hover = row:CreateTexture(nil, "HIGHLIGHT")
  row.hover:SetAllPoints(true)
  row.hover:SetColorTexture(1, 1, 1, 0.03)
  row.hover:Hide()

  row:EnableMouse(true)
  row:SetScript("OnEnter", function() row.hover:Show() end)
  row:SetScript("OnLeave", function() row.hover:Hide() end)

  row.editBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.editBtn:SetSize(50, 20)
  row.editBtn:SetPoint("LEFT", row.text, "RIGHT", 10, 0)
  row.editBtn:SetText("Edit")

  row.delBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.delBtn:SetSize(60, 20)
  row.delBtn:SetPoint("LEFT", row.editBtn, "RIGHT", 6, 0)
  row.delBtn:SetText("Remove")

  self.rows[idx] = row
  return row
end

function UI:Refresh()
  if not self.frame then self:Create() end

  -- Sync global toggles
  self.lockCB:SetChecked(Addon.db.frame.locked == true)
  self.debugCB:SetChecked(Addon.db.debug == true)
  self.mmHideCB:SetChecked(Addon.db.minimap.hide == true)

  -- Grow dropdown current value
  if self.growDrop and Addon.db and Addon.db.frame then
    local g = Addon.db.frame.grow or "RIGHT"
    for i = 1, #GROWS do
      if GROWS[i].key == g then
        SetDropdownValue(self.growDrop, g, GROWS[i].text)
        break
      end
    end
  end

  -- Preview reacts to ID changes
  if not self._idPreviewHooked then
    self._idPreviewHooked = true
    self.idBox:HookScript("OnTextChanged", function() UI:UpdateIDPreview() end)
  end

  local tracks = EnsureDBTracks()

  local y = -2
  local rowH = 26

  for i = 1, #self.rows do
    self.rows[i]:Hide()
  end

  for i = 1, #tracks do
    local e = tracks[i]
    if type(e) == "table" then
      local row = EnsureRow(self, i)
      row:SetPoint("TOPLEFT", self.listChild, "TOPLEFT", 0, y)
      y = y - rowH

      row.bg:SetAlpha((i % 2 == 0) and 0.10 or 0.15)

      local tex = U.GetSpellIcon(e.id)
      if tex then
        row.icon:SetTexture(tex)
        row.icon:Show()
      else
        row.icon:Hide()
      end

      row.text:SetText(PrettyEntry(e))

      row.enable:SetChecked(e.enabled ~= false)
      row.enable:SetScript("OnClick", function(btn)
        e.enabled = (btn:GetChecked() == true)
        Addon.Tracker:RequestRefresh()
      end)

      row.editBtn:SetScript("OnClick", function()
        UI:LoadEntryToForm(i)
      end)

      row.delBtn:SetScript("OnClick", function()
        UI:RemoveEntry(i)
      end)

      row.upBtn:SetScript("OnClick", function()
        UI:MoveEntry(i, -1)
      end)
      row.downBtn:SetScript("OnClick", function()
        UI:MoveEntry(i, 1)
      end)

      if self.selectedIndex == i then
        row.sel:Show()
      else
        row.sel:Hide()
      end

      row:Show()
    end
  end

  self.listChild:SetHeight(math.max(1, -y))
end

function UI:MoveEntry(index, delta)
  local tracks = EnsureDBTracks()
  local n = #tracks
  local j = index + delta
  if not (index and j and index >= 1 and j >= 1 and index <= n and j <= n) then
    return
  end

  tracks[index], tracks[j] = tracks[j], tracks[index]

  if self.selectedIndex == index then
    self.selectedIndex = j
  elseif self.selectedIndex == j then
    self.selectedIndex = index
  end

  self:Refresh()
  Addon.Tracker:RequestRefresh()
end

function Addon:ToggleConfig()
  if not UI.frame then UI:Create() end
  if UI.frame:IsShown() then
    UI.frame:Hide()
  else
    UI:Refresh()
    UI.frame:Show()
  end
end

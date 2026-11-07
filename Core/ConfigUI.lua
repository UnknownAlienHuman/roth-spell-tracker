local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

local UI = {}
Addon.UI = UI

local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ROW_HEIGHT = 26
local ROW_SPACING = 1
local KINDS = {
  { key = "SPELL", text = "Spell readiness" },
  { key = "AURA", text = "Managed aura" },
}
local SHOW_SPELL = {
  { key = "ALWAYS", text = "Always (dim when unavailable)" },
  { key = "READY", text = "Only when ready" },
  { key = "NOTREADY", text = "Only when not ready" },
}
local SHOW_AURA = {
  { key = "ALWAYS", text = "Always (dim placeholder when missing)" },
  { key = "ACTIVE", text = "Only when active" },
}
local UNITS = {
  { key = "player", text = "player" },
  { key = "target", text = "target" },
  { key = "focus", text = "focus" },
}
local AURA_TYPES = {
  { key = "HELPFUL", text = "HELPFUL (buff)" },
  { key = "HARMFUL", text = "HARMFUL (debuff)" },
}
local GROWS = {
  { key = "RIGHT", text = "RIGHT" },
  { key = "LEFT", text = "LEFT" },
  { key = "UP", text = "UP" },
  { key = "DOWN", text = "DOWN" },
}

local function CreateLabel(parent, text, template)
  local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
  label:SetText(text)
  label:SetJustifyH("LEFT")
  return label
end

local function CreateEditBox(parent, width)
  local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  edit:SetSize(width, 20)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    UI:SaveEntryFromForm()
  end)
  return edit
end

local function CreateButton(parent, text, width, callback)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", callback)
  return button
end

local function CreateCheckbox(parent, text, callback)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check.Text:SetText(text)
  check:SetScript("OnClick", function(self)
    callback(self:GetChecked() == true)
  end)
  return check
end

local function InitializeDropdown(dropdown, items, onSelect)
  UIDropDownMenu_SetWidth(dropdown, 190)
  UIDropDownMenu_Initialize(dropdown, function()
    for _, item in ipairs(items) do
      local itemKey = item.key
      local itemText = item.text
      local info = UIDropDownMenu_CreateInfo()
      info.text = itemText
      info.value = itemKey
      info.checked = dropdown.value == itemKey
      info.func = function()
        dropdown.value = itemKey
        UIDropDownMenu_SetSelectedValue(dropdown, itemKey)
        UIDropDownMenu_SetText(dropdown, itemText)
        if onSelect then onSelect(itemKey) end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
end

local function SetDropdown(dropdown, items, value)
  local selected = items[1]
  for _, item in ipairs(items) do
    if item.key == value then selected = item break end
  end
  dropdown.value = selected.key
  UIDropDownMenu_SetSelectedValue(dropdown, selected.key)
  UIDropDownMenu_SetText(dropdown, selected.text)
end

local function CreateSlider(parent, labelText, minimum, maximum, step, getter, setter)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(260, 48)

  local label = CreateLabel(holder, labelText)
  label:SetPoint("TOPLEFT", 0, 0)
  local valueLabel = CreateLabel(holder, "", "GameFontHighlightSmall")
  valueLabel:SetPoint("TOPRIGHT", 0, 0)

  local slider = CreateFrame("Slider", nil, holder, "UISliderTemplate")
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -10)
  slider:SetSize(220, 16)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)

  local refreshing = false
  local function Format(value)
    return step < 1 and string.format("%.2f", value) or tostring(math.floor(value + 0.5))
  end
  holder.Refresh = function()
    refreshing = true
    local value = getter()
    slider:SetValue(value)
    valueLabel:SetText(Format(value))
    refreshing = false
  end
  slider:SetScript("OnValueChanged", function(_, value)
    if refreshing then return end
    local rounded = math.floor(value / step + 0.5) * step
    setter(rounded)
    valueLabel:SetText(Format(rounded))
  end)
  return holder
end

local function EnsureTracks()
  Addon.db.tracks = U.SafeTable(Addon.db.tracks) or {}
  return Addon.db.tracks
end

local function FindExisting(tracks, entry, excludeIndex)
  for index, current in ipairs(tracks) do
    if index ~= excludeIndex
      and type(current) == "table"
      and current.kind == entry.kind
      and current.id == entry.id then
      if entry.kind == "SPELL" then return index end
      if current.unit == entry.unit and current.auraType == entry.auraType then return index end
    end
  end
  return nil
end

local function ResolveEntryID(entry)
  if entry.kind ~= "SPELL" then return entry.id end
  if Addon.Tracker and type(Addon.Tracker.GetResolvedSpellID) == "function" then
    local spellID = Addon.Tracker:GetResolvedSpellID(entry)
    if spellID then return spellID end
  end
  return U.ResolveSpellID(entry.id) or entry.id
end

local function PrettyEntry(entry, displayID, name)
  displayID = displayID or ResolveEntryID(entry)
  name = name or U.GetSpellName(displayID) or "unknown"
  if entry.kind == "AURA" then
    return string.format(
      "%d  |cffaaaaaa(Aura)|r  %s  |cff666666[%s %s, %s]|r",
      entry.id, name, entry.unit, entry.auraType, entry.showWhen
    )
  end
  return string.format(
    "%d  |cffaaaaaa(Spell)|r  %s  |cff666666[%s, %s]|r",
    entry.id, name, entry.showWhen,
    entry.ignoreGCD ~= false and "ignore explicit GCD" or "show GCD"
  )
end

local function GetRowDataIndex(row)
  if type(row.GetElementData) ~= "function" then return nil end
  return U.SafeInteger(row:GetElementData(), 1, Addon.MAX_TRACKS or 500)
end

local function InitializeTrackRow(row)
  if row.rstInitialized then return end
  row.rstInitialized = true

  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(20, 20)
  row.icon:SetPoint("LEFT", 2, 0)
  row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  row.enabled = CreateCheckbox(row, "", function() end)
  row.enabled:SetPoint("LEFT", row.icon, "RIGHT", 2, 0)
  row.up = CreateButton(row, "^", 22, function() end)
  row.up:SetPoint("LEFT", row.enabled, "RIGHT", 2, 0)
  row.down = CreateButton(row, "v", 22, function() end)
  row.down:SetPoint("LEFT", row.up, "RIGHT", 2, 0)
  row.text = CreateLabel(row, "", "GameFontHighlight")
  row.text:SetPoint("LEFT", row.down, "RIGHT", 6, 0)
  row.text:SetWidth(390)
  row.edit = CreateButton(row, "Edit", 50, function() end)
  row.edit:SetPoint("LEFT", row.text, "RIGHT", 6, 0)
  row.remove = CreateButton(row, "Remove", 64, function() end)
  row.remove:SetPoint("LEFT", row.edit, "RIGHT", 6, 0)

  row.enabled:SetScript("OnClick", function(button)
    local dataIndex = GetRowDataIndex(row)
    local entry = dataIndex and EnsureTracks()[dataIndex]
    if not entry then return end
    entry.enabled = button:GetChecked() == true
    Addon:RequestRebuild()
  end)
  row.up:SetScript("OnClick", function()
    local dataIndex = GetRowDataIndex(row)
    if dataIndex then UI:MoveEntry(dataIndex, -1) end
  end)
  row.down:SetScript("OnClick", function()
    local dataIndex = GetRowDataIndex(row)
    if dataIndex then UI:MoveEntry(dataIndex, 1) end
  end)
  row.edit:SetScript("OnClick", function()
    local dataIndex = GetRowDataIndex(row)
    if dataIndex then UI:LoadEntry(dataIndex) end
  end)
  row.remove:SetScript("OnClick", function()
    local dataIndex = GetRowDataIndex(row)
    if dataIndex then UI:RemoveEntry(dataIndex) end
  end)
end

function UI:InitializeTrackRow(row, dataIndex)
  InitializeTrackRow(row)

  local tracks = EnsureTracks()
  local entry = tracks[dataIndex]
  if not entry then return end

  local displayID = ResolveEntryID(entry)
  local name = U.GetSpellName(displayID) or "unknown"
  row.icon:SetTexture(U.GetSpellIcon(displayID) or QUESTION_ICON)
  row.text:SetText(PrettyEntry(entry, displayID, name))
  row.enabled:SetChecked(entry.enabled ~= false)
  row.up:SetShown(dataIndex > 1)
  row.down:SetShown(dataIndex < #tracks)
end

function UI:ResetTrackRow(row)
  if not row.rstInitialized then return end
  row.icon:SetTexture(nil)
  row.text:SetText("")
  row.enabled:SetChecked(false)
end

function UI:Create()
  if self.frame then return end

  local frame = CreateFrame("Frame", "RothSpellTrackerConfigFrame", UIParent, "UIPanelDialogTemplate")
  frame:SetSize(700, 600)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", function(self) self:Raise() end)
  frame:SetClampedToScreen(true)
  frame:Hide()
  frame.Title:SetText("Roth Spell Tracker")
  self.frame = frame

  if type(UISpecialFrames) == "table" then
    local registered = false
    for _, name in ipairs(UISpecialFrames) do
      if name == frame:GetName() then registered = true break end
    end
    if not registered then UISpecialFrames[#UISpecialFrames + 1] = frame:GetName() end
  end

  local heading = CreateLabel(frame, "Add / edit track", "GameFontNormalLarge")
  heading:SetPoint("TOPLEFT", 20, -42)
  self.heading = heading

  self.dbWarning = CreateLabel(frame, "", "GameFontHighlightSmall")
  self.dbWarning:SetPoint("TOPRIGHT", -22, -45)
  self.dbWarning:SetWidth(360)
  self.dbWarning:SetJustifyH("RIGHT")
  self.dbWarning:SetTextColor(1, 0.25, 0.25)
  self.dbWarning:Hide()

  local idLabel = CreateLabel(frame, "Spell ID")
  idLabel:SetPoint("TOPLEFT", 20, -75)
  self.idBox = CreateEditBox(frame, 110)
  self.idBox:SetPoint("TOPLEFT", 20, -95)
  self.idBox:SetNumeric(true)
  self.idBox:SetMaxLetters(10)
  self.idBox:HookScript("OnTextChanged", function() UI:UpdatePreview() end)

  self.previewIcon = frame:CreateTexture(nil, "ARTWORK")
  self.previewIcon:SetSize(24, 24)
  self.previewIcon:SetPoint("LEFT", self.idBox, "RIGHT", 10, 0)
  self.previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  self.previewName = CreateLabel(frame, "", "GameFontHighlight")
  self.previewName:SetPoint("LEFT", self.previewIcon, "RIGHT", 8, 0)
  self.previewName:SetWidth(220)

  local kindLabel = CreateLabel(frame, "Type")
  kindLabel:SetPoint("TOPLEFT", 390, -75)
  self.kindDrop = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
  self.kindDrop:SetPoint("TOPLEFT", 374, -88)
  InitializeDropdown(self.kindDrop, KINDS, function(kind) UI:OnKindChanged(kind) end)

  local showLabel = CreateLabel(frame, "Display")
  showLabel:SetPoint("TOPLEFT", 20, -135)
  self.showDrop = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
  self.showDrop:SetPoint("TOPLEFT", 4, -148)

  self.unitLabel = CreateLabel(frame, "Unit")
  self.unitLabel:SetPoint("TOPLEFT", 265, -135)
  self.unitDrop = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
  self.unitDrop:SetPoint("TOPLEFT", 249, -148)
  InitializeDropdown(self.unitDrop, UNITS)

  self.auraTypeLabel = CreateLabel(frame, "Aura type")
  self.auraTypeLabel:SetPoint("TOPLEFT", 500, -135)
  self.auraTypeDrop = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
  self.auraTypeDrop:SetPoint("TOPLEFT", 484, -148)
  InitializeDropdown(self.auraTypeDrop, AURA_TYPES)

  self.ignoreGCD = CreateCheckbox(frame, "Ignore only explicitly identified GCD", function() end)
  self.ignoreGCD:SetPoint("TOPLEFT", 265, -190)

  self.auraNote = CreateLabel(
    frame,
    "Aura spell-ID matching is relationship-constrained; unfilterable identities are rejected. Missing-only and stack-threshold checks are unavailable.",
    "GameFontHighlightSmall"
  )
  self.auraNote:SetPoint("TOPLEFT", 20, -190)
  self.auraNote:SetWidth(620)
  self.auraNote:SetWordWrap(true)

  self.saveButton = CreateButton(frame, "Save", 90, function() UI:SaveEntryFromForm() end)
  self.saveButton:SetPoint("TOPRIGHT", -120, -225)
  self.clearButton = CreateButton(frame, "Clear", 90, function() UI:ClearForm() end)
  self.clearButton:SetPoint("LEFT", self.saveButton, "RIGHT", 8, 0)

  local globalHeading = CreateLabel(frame, "Global", "GameFontNormalLarge")
  globalHeading:SetPoint("TOPLEFT", 20, -260)
  self.lockCheck = CreateCheckbox(frame, "Lock tracker frame", function(value)
    Addon.db.frame.locked = value
    Addon:ApplyFrameLock()
  end)
  self.lockCheck:SetPoint("TOPLEFT", 20, -288)
  self.debugCheck = CreateCheckbox(frame, "Debug log to chat", function(value) Addon:SetDebug(value) end)
  self.debugCheck:SetPoint("TOPLEFT", 220, -288)
  self.minimapCheck = CreateCheckbox(frame, "Hide minimap icon", function(value)
    Addon.db.minimap.hide = value
    Addon:UpdateMinimapIcon()
  end)
  self.minimapCheck:SetPoint("TOPLEFT", 420, -288)

  self.sizeSlider = CreateSlider(frame, "Icon size", Addon.MIN_ICON_SIZE, Addon.MAX_ICON_SIZE, 1,
    function() return Addon.db.frame.size end,
    function(value) Addon.db.frame.size = value; Addon:RequestLayout() end)
  self.sizeSlider:SetPoint("TOPLEFT", 20, -324)

  self.spacingSlider = CreateSlider(frame, "Spacing", 0, Addon.MAX_ICON_SPACING, 1,
    function() return Addon.db.frame.spacing end,
    function(value) Addon.db.frame.spacing = value; Addon:RequestLayout() end)
  self.spacingSlider:SetPoint("TOPLEFT", 300, -324)

  local growLabel = CreateLabel(frame, "Grow")
  growLabel:SetPoint("TOPLEFT", 570, -324)
  self.growDrop = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
  self.growDrop:SetPoint("TOPLEFT", 554, -338)
  InitializeDropdown(self.growDrop, GROWS, function(value)
    Addon.db.frame.grow = value
    Addon:RequestLayout()
  end)

  self.resetPosition = CreateButton(frame, "Reset position", 115, function() Addon.Display:ResetPosition() end)
  self.resetPosition:SetPoint("TOPLEFT", 20, -385)
  self.resetDB = CreateButton(frame, "Reset DB", 100, function() Addon:ConfirmResetDB() end)
  self.resetDB:SetPoint("LEFT", self.resetPosition, "RIGHT", 8, 0)

  local listHeading = CreateLabel(frame, "Tracked", "GameFontNormalLarge")
  listHeading:SetPoint("TOPLEFT", 20, -422)
  self.listHeading = listHeading

  local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
  scrollBox:SetPoint("TOPLEFT", 20, -450)
  scrollBox:SetPoint("BOTTOMRIGHT", -50, 18)
  local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
  scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
  scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)

  local view = CreateScrollBoxListLinearView(0, 0, 0, 0, ROW_SPACING)
  view:SetElementExtent(ROW_HEIGHT)
  view:SetElementInitializer("Frame", function(row, dataIndex)
    UI:InitializeTrackRow(row, dataIndex)
  end)
  view:SetElementResetter(function(row)
    UI:ResetTrackRow(row)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

  self.scrollBox = scrollBox
  self.scrollBar = scrollBar
  self.selectedIndex = nil
  self:ClearForm()
end

function UI:OnKindChanged(kind)
  kind = kind == "AURA" and "AURA" or "SPELL"
  local isAura = kind == "AURA"
  InitializeDropdown(self.showDrop, isAura and SHOW_AURA or SHOW_SPELL)
  SetDropdown(self.showDrop, isAura and SHOW_AURA or SHOW_SPELL, "ALWAYS")
  self.unitDrop:SetShown(isAura)
  self.unitLabel:SetShown(isAura)
  self.auraTypeDrop:SetShown(isAura)
  self.auraTypeLabel:SetShown(isAura)
  self.auraNote:SetShown(isAura)
  self.ignoreGCD:SetShown(not isAura)
  if self.idBox then self:UpdatePreview() end
end

function UI:UpdatePreview()
  local id = U.SafeInteger(U.ToNumber(self.idBox:GetText()), 1, Addon.MAX_SPELL_ID)
  local displayID = id
  if id and self.kindDrop and self.kindDrop.value == "SPELL" then
    displayID = U.ResolveSpellID(id) or id
  end
  local icon = displayID and U.GetSpellIcon(displayID) or nil
  local name = displayID and U.GetSpellName(displayID) or nil
  if icon then
    self.previewIcon:SetTexture(icon)
    self.previewIcon:Show()
  else
    self.previewIcon:Hide()
  end
  self.previewName:SetText(name or (id and "unknown" or ""))
end

function UI:ClearForm()
  self.selectedIndex = nil
  self.idBox:SetText("")
  SetDropdown(self.kindDrop, KINDS, "SPELL")
  self:OnKindChanged("SPELL")
  SetDropdown(self.showDrop, SHOW_SPELL, "ALWAYS")
  SetDropdown(self.unitDrop, UNITS, "player")
  SetDropdown(self.auraTypeDrop, AURA_TYPES, "HELPFUL")
  self.ignoreGCD:SetChecked(true)
  self:UpdatePreview()
end

function UI:SaveEntryFromForm()
  local id = U.SafeInteger(U.ToNumber(self.idBox:GetText()), 1, Addon.MAX_SPELL_ID)
  if not id then
    Addon:Notify("ERROR", "Enter a valid spell ID")
    return
  end

  local kind = self.kindDrop.value == "AURA" and "AURA" or "SPELL"
  local entry = { id = id, kind = kind, enabled = true }
  if kind == "AURA" then
    entry.showWhen = self.showDrop.value == "ACTIVE" and "ACTIVE" or "ALWAYS"
    entry.unit = self.unitDrop.value or "player"
    entry.auraType = self.auraTypeDrop.value or "HELPFUL"
  else
    local showWhen = self.showDrop.value or "ALWAYS"
    if showWhen ~= "READY" and showWhen ~= "NOTREADY" then showWhen = "ALWAYS" end
    entry.showWhen = showWhen
    entry.ignoreGCD = self.ignoreGCD:GetChecked() == true
  end

  local tracks = EnsureTracks()
  local selectedIndex = self.selectedIndex
  local duplicateIndex = FindExisting(tracks, entry, selectedIndex)
  if selectedIndex and duplicateIndex then
    Addon:Notify("ERROR", "That track already exists")
    return
  end

  local index = selectedIndex or duplicateIndex
  if index and tracks[index] then
    entry.uid = tracks[index].uid
    entry.enabled = tracks[index].enabled ~= false
    tracks[index] = entry
    Addon:Notify("INFO", string.format("Updated %d (%s)", id, kind))
  else
    if #tracks >= (Addon.MAX_TRACKS or 500) then
      Addon:Notify("ERROR", "Track limit reached")
      return
    end
    local uid = Addon:AllocateTrackUID()
    if not uid then
      Addon:Notify("ERROR", "No free track slot")
      return
    end
    entry.uid = uid
    tracks[#tracks + 1] = entry
    Addon:Notify("INFO", string.format("Added %d (%s)", id, kind))
  end

  self.selectedIndex = nil
  self:Refresh()
  Addon:RequestRebuild()
end

function UI:LoadEntry(index)
  local entry = EnsureTracks()[index]
  if type(entry) ~= "table" then return end
  self.selectedIndex = index
  self.idBox:SetText(tostring(entry.id))
  SetDropdown(self.kindDrop, KINDS, entry.kind)
  self:OnKindChanged(entry.kind)
  if entry.kind == "AURA" then
    SetDropdown(self.showDrop, SHOW_AURA, entry.showWhen)
    SetDropdown(self.unitDrop, UNITS, entry.unit)
    SetDropdown(self.auraTypeDrop, AURA_TYPES, entry.auraType)
  else
    SetDropdown(self.showDrop, SHOW_SPELL, entry.showWhen)
    self.ignoreGCD:SetChecked(entry.ignoreGCD ~= false)
  end
  self:UpdatePreview()
  self:Refresh()
end

function UI:RemoveEntry(index)
  local tracks = EnsureTracks()
  if not tracks[index] then return end
  table.remove(tracks, index)
  if self.selectedIndex == index then
    self:ClearForm()
  elseif self.selectedIndex and self.selectedIndex > index then
    self.selectedIndex = self.selectedIndex - 1
  end
  self:Refresh()
  Addon:RequestRebuild()
end

function UI:MoveEntry(index, delta)
  local tracks = EnsureTracks()
  local target = index + delta
  if index < 1 or target < 1 or index > #tracks or target > #tracks then return end
  tracks[index], tracks[target] = tracks[target], tracks[index]
  if self.selectedIndex == index then
    self.selectedIndex = target
  elseif self.selectedIndex == target then
    self.selectedIndex = index
  end
  self:Refresh()
  Addon:RequestRebuild()
end

function UI:Refresh()
  if not self.frame then self:Create() end

  local readOnly = Addon.IsDBReadOnly and Addon:IsDBReadOnly()
  if readOnly then
    self.dbWarning:SetText(string.format(
      "Saved DB schema %d is newer than supported schema %d. Changes are session-only.",
      Addon.dbSourceVersion or 0,
      Addon.DB_VERSION or 0
    ))
    self.dbWarning:Show()
    self.resetDB:SetText("Replace DB")
  else
    self.dbWarning:Hide()
    self.resetDB:SetText("Reset DB")
  end

  self.lockCheck:SetChecked(Addon.db.frame.locked == true)
  self.debugCheck:SetChecked(Addon.db.debug == true)
  self.minimapCheck:SetChecked(Addon.db.minimap.hide == true)
  self.sizeSlider:Refresh()
  self.spacingSlider:Refresh()
  SetDropdown(self.growDrop, GROWS, Addon.db.frame.grow)

  local tracks = EnsureTracks()
  self.listHeading:SetText(string.format("Tracked (%d)", #tracks))
  local dataProvider = CreateIndexRangeDataProvider(#tracks)
  self.scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)
end

function UI:OnDatabaseReset()
  if not self.frame then return end
  self:ClearForm()
  self:Refresh()
  self.scrollBox:ScrollToBegin()
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

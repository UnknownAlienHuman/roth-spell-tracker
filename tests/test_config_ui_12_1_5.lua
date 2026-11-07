local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local createdFrames = 0
local configFrame

local function newRegion(objectType, parent, name, template)
  createdFrames = createdFrames + 1
  local region = {
    objectType = objectType,
    parent = parent,
    name = name,
    template = template,
    shown = true,
    text = "",
    checked = false,
    scripts = {},
    hooks = {},
  }

  function region:SetSize(width, height) self.width, self.height = width, height end
  function region:SetWidth(width) self.width = width end
  function region:SetHeight(height) self.height = height end
  function region:SetPoint(...) self.point = { ... } end
  function region:SetFrameStrata(value) self.strata = value end
  function region:SetToplevel(value) self.toplevel = value end
  function region:SetMovable(value) self.movable = value end
  function region:EnableMouse(value) self.mouse = value end
  function region:RegisterForDrag(value) self.drag = value end
  function region:SetClampedToScreen(value) self.clamped = value end
  function region:SetAutoFocus(value) self.autoFocus = value end
  function region:SetNumeric(value) self.numeric = value end
  function region:SetMaxLetters(value) self.maxLetters = value end
  function region:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
  function region:SetValueStep(value) self.valueStep = value end
  function region:SetObeyStepOnDrag(value) self.obeyStep = value end
  function region:SetText(value) self.text = value or "" end
  function region:GetText() return self.text end
  function region:SetJustifyH(value) self.justifyH = value end
  function region:SetTextColor(...) self.textColor = { ... } end
  function region:SetWordWrap(value) self.wordWrap = value end
  function region:SetTexture(value) self.texture = value end
  function region:SetTexCoord(...) self.texCoord = { ... } end
  function region:SetChecked(value) self.checked = value == true end
  function region:GetChecked() return self.checked end
  function region:SetShown(value) self.shown = value == true end
  function region:IsShown() return self.shown end
  function region:Show() self.shown = true end
  function region:Hide() self.shown = false end
  function region:Raise() self.raised = true end
  function region:GetName() return self.name end
  function region:ClearFocus() self.focused = false end
  function region:StartMoving() self.moving = true end
  function region:StopMovingOrSizing() self.moving = false end
  function region:SetScript(script, callback) self.scripts[script] = callback; self[script] = callback end
  function region:HookScript(script, callback)
    self.hooks[script] = self.hooks[script] or {}
    self.hooks[script][#self.hooks[script] + 1] = callback
  end
  function region:SetValue(value)
    self.value = value
    local callback = self.scripts.OnValueChanged
    if callback then callback(self, value) end
  end
  function region:CreateTexture()
    return newRegion("Texture", self)
  end
  function region:CreateFontString()
    return newRegion("FontString", self)
  end

  if objectType == "CheckButton" then
    region.Text = newRegion("FontString", region)
  elseif template == "UIPanelDialogTemplate" then
    region.Title = newRegion("FontString", region)
  end

  return region
end

function CreateFrame(objectType, name, parent, template)
  local frame = newRegion(objectType, parent, name, template)
  if name == "RothSpellTrackerConfigFrame" then configFrame = frame end
  return frame
end

function canaccessvalue() return true end
function canaccesstable() return true end
function issecretvalue() return false end
function InCombatLockdown() return false end

UIParent = newRegion("Frame")
UISpecialFrames = {}

function UIDropDownMenu_SetWidth(dropdown, width) dropdown.dropdownWidth = width end
function UIDropDownMenu_Initialize(dropdown, initializer) dropdown.dropdownInitializer = initializer end
function UIDropDownMenu_SetSelectedValue(dropdown, value) dropdown.selectedValue = value end
function UIDropDownMenu_SetText(dropdown, text) dropdown.text = text end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end

ScrollBoxConstants = { RetainScrollPosition = true }

function CreateIndexRangeDataProvider(count)
  return { count = count }
end

function CreateScrollBoxListLinearView(_, _, _, _, spacing)
  local view = { spacing = spacing }
  function view:SetElementExtent(extent) self.extent = extent end
  function view:SetElementInitializer(frameType, initializer)
    self.frameType = frameType
    self.initializer = initializer
  end
  function view:SetElementResetter(resetter) self.resetter = resetter end
  return view
end

ScrollUtil = {}
function ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
  scrollBox.view = view
  scrollBox.scrollBar = scrollBar
  scrollBox.frames = scrollBox.frames or {}

  function scrollBox:SetDataProvider(provider, retainPosition)
    self.provider = provider
    self.retainPosition = retainPosition
    local visible = math.min(provider.count, 3)

    for index, frame in ipairs(self.frames) do
      if view.resetter then view.resetter(frame) end
      frame.GetElementData = nil
      if index > visible then frame:Hide() end
    end

    for index = 1, visible do
      local row = self.frames[index]
      if not row then
        row = newRegion("Frame", self)
        self.frames[index] = row
      end
      local elementIndex = index
      row.GetElementData = function() return elementIndex end
      view.initializer(row, elementIndex)
      row:Show()
    end
  end

  function scrollBox:ScrollToBegin() self.scrolledToBegin = true end
end

C_Spell = {
  GetBaseSpell = function(id) return id end,
  GetOverrideSpell = function(id) return id end,
  GetSpellTexture = function(id) return 136000 + id end,
  GetSpellName = function(id) return "Spell " .. id end,
}

local NS = { Addon = {} }
assert(loadfile("Core/Config.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/Util.lua"))("RothSpellTracker", NS)
assert(loadfile("Core/ConfigUI.lua"))("RothSpellTracker", NS)
local Addon = NS.Addon

local tracks = {}
for index = 1, Addon.MAX_TRACKS do
  tracks[index] = {
    uid = index,
    id = 10000 + index,
    kind = "SPELL",
    enabled = true,
    showWhen = "ALWAYS",
    ignoreGCD = true,
  }
end

Addon.db = {
  debug = false,
  minimap = { hide = false, minimapPos = 220 },
  frame = { point = "CENTER", relPoint = "CENTER", x = 0, y = -120, size = 44, spacing = 6, locked = true, grow = "RIGHT" },
  tracks = tracks,
}
Addon.Display = { ResetPosition = function() end }
Addon.Tracker = {
  GetResolvedSpellID = function(_, entry) return entry.id end,
}
Addon.SetDebug = function(_, value) Addon.db.debug = value end
Addon.UpdateMinimapIcon = function() end
Addon.ApplyFrameLock = function() end
Addon.RequestLayout = function() end
Addon.RequestRebuild = function() Addon.rebuilds = (Addon.rebuilds or 0) + 1 end
Addon.Notify = function() end
Addon.AllocateTrackUID = function() return nil end
Addon.IsDBReadOnly = function(self) return self.dbReadOnly == true end
Addon.ConfirmResetDB = function() Addon.resetConfirmations = (Addon.resetConfirmations or 0) + 1 end

Addon:ToggleConfig()
local UI = Addon.UI
assert(configFrame and configFrame:IsShown(), "configuration frame did not open")
assertEq(configFrame.strata, "DIALOG", "configuration frame strata")
assertEq(configFrame.toplevel, true, "configuration frame top-level ownership")
assertEq(UISpecialFrames[1], "RothSpellTrackerConfigFrame", "Escape-close registration")
assertEq(UI.idBox.maxLetters, 10, "spell ID input bound")
assertEq(UI.scrollBox.provider.count, Addon.MAX_TRACKS, "index-range provider size")
assertEq(UI.scrollBox.view.frameType, "Frame", "plain pooled row frame type")
assertEq(UI.scrollBox.view.extent, 26, "row extent")
assertEq(#UI.scrollBox.frames, 3, "mock viewport should realize only visible rows")
assert(createdFrames < 100, "configuration created a frame tree per track")

local firstRow = UI.scrollBox.frames[1]
local secondRow = UI.scrollBox.frames[2]
assertEq(firstRow:GetElementData(), 1, "first row element index")
assertEq(secondRow:GetElementData(), 2, "second row element index")
assertEq(firstRow.text.text:find("10001", 1, true) ~= nil, true, "first row text")

secondRow.up.OnClick(secondRow.up)
assertEq(Addon.db.tracks[1].id, 10002, "recycled row move action")
assertEq(Addon.db.tracks[2].id, 10001, "recycled row move target")
assertEq(UI.scrollBox.retainPosition, ScrollBoxConstants.RetainScrollPosition, "scroll position retention")
assertEq(#UI.scrollBox.frames, 3, "refresh allocated extra visible rows")

firstRow = UI.scrollBox.frames[1]
firstRow.enabled:SetChecked(false)
firstRow.enabled.OnClick(firstRow.enabled)
assertEq(Addon.db.tracks[1].enabled, false, "recycled row enable action")

local oldCount = #Addon.db.tracks
firstRow.remove.OnClick(firstRow.remove)
assertEq(#Addon.db.tracks, oldCount - 1, "recycled row remove action")
assertEq(UI.scrollBox.provider.count, oldCount - 1, "provider refreshed after removal")
assertEq(#UI.scrollBox.frames, 3, "removal allocated extra rows")

UI.resetDB.OnClick(UI.resetDB)
assertEq(Addon.resetConfirmations, 1, "reset must use confirmation owner")

Addon.dbReadOnly = true
Addon.dbSourceVersion = 99
UI:Refresh()
assertEq(UI.dbWarning.shown, true, "future-schema warning visibility")
assertEq(UI.dbWarning.text:find("session%-only") ~= nil, true, "future-schema warning text")
assertEq(UI.resetDB.text, "Replace DB", "future-schema reset label")

UI:OnDatabaseReset()
assertEq(UI.scrollBox.scrolledToBegin, true, "database reset scroll position")

Addon:ToggleConfig()
assertEq(configFrame:IsShown(), false, "configuration frame did not close")

print("PASS: configuration uses current ScrollBox virtualization and re-resolves recycled row actions")

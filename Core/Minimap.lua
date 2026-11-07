local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
local OBJECT_NAME = "RothSpellTracker"

function Addon:InitMinimapIcon()
  if not (LDB and DBIcon) then
    self:Log("WARN", "LibDataBroker/LibDBIcon not available")
    return
  end
  if self._dataobj then return end

  local obj = LDB:NewDataObject(OBJECT_NAME, {
    type = "data source",
    text = "Roth Spell Tracker",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    OnClick = function(_, button)
      if button == "LeftButton" then
        Addon:ToggleConfig()
      elseif button == "RightButton" and Addon.db and Addon.db.frame then
        Addon.db.frame.locked = not Addon.db.frame.locked
        Addon:ApplyFrameLock()
        Addon:Notify("INFO", Addon.db.frame.locked and "Frame locked" or "Frame unlocked")
      end
    end,
    OnTooltipShow = function(tooltip)
      if not tooltip or type(tooltip.AddLine) ~= "function" then return end
      tooltip:AddLine("Roth Spell Tracker")
      tooltip:AddLine("Left-click: settings", 1, 1, 1)
      tooltip:AddLine("Right-click: lock/unlock frame", 1, 1, 1)
    end,
  })

  self._dataobj = obj
  DBIcon:Register(OBJECT_NAME, obj, self.db.minimap)
end

function Addon:UpdateMinimapIcon()
  if not (DBIcon and self._dataobj and self.db and self.db.minimap) then return end

  -- ResetDB replaces the minimap settings table. LibDBIcon retains the table
  -- passed to Register, so refresh its reference before applying visibility.
  if type(DBIcon.Refresh) == "function" then
    DBIcon:Refresh(OBJECT_NAME, self.db.minimap)
  end

  if self.db.minimap.hide then
    DBIcon:Hide(OBJECT_NAME)
  else
    DBIcon:Show(OBJECT_NAME)
  end
end

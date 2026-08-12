local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

function Addon:InitMinimapIcon()
  if not (LDB and DBIcon) then
    self:Log("WARN", "LibDataBroker/LibDBIcon not available")
    return
  end

  if self._dataobj then return end

  local obj = LDB:NewDataObject("RothSpellTracker", {
    type = "data source",
    text = "Roth Spell Tracker",
    icon = "Interface\\Icons\\INV_Misc_QuestionMark",
    OnClick = function(_, button)
      if button == "LeftButton" then
        Addon:ToggleConfig()
      elseif button == "RightButton" then
        Addon.db.frame.locked = not Addon.db.frame.locked
        Addon:ApplyFrameLock()
        Addon:Log("INFO", Addon.db.frame.locked and "Frame locked" or "Frame unlocked")
      end
    end,
    OnTooltipShow = function(tooltip)
      if not tooltip or not tooltip.AddLine then return end
      tooltip:AddLine("Roth Spell Tracker")
      tooltip:AddLine("Left-click: settings", 1, 1, 1)
      tooltip:AddLine("Right-click: lock/unlock frame", 1, 1, 1)
    end,
  })

  self._dataobj = obj
  DBIcon:Register("RothSpellTracker", obj, self.db.minimap)
end

function Addon:UpdateMinimapIcon()
  if not (DBIcon and self._dataobj and self.db and self.db.minimap) then return end
  if self.db.minimap.hide then
    DBIcon:Hide("RothSpellTracker")
  else
    DBIcon:Show("RothSpellTracker")
  end
end

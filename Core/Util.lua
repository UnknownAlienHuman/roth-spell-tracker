local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

Addon.Util = Addon.Util or {}
local U = Addon.Util

function U.CanAccess(value)
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
  end
  return true
end

function U.CanAccessTable(value)
  if not U.CanAccess(value) then return false end
  if type(value) ~= "table" then return false end

  -- issecrettable classifies a table; it is not an access decision. The
  -- selected Retail contract exposes canaccesstable for the actual gate.
  if type(canaccesstable) == "function" then
    local ok, accessible = pcall(canaccesstable, value)
    return ok and accessible == true
  end
  return true
end

function U.SafeBool(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "boolean" then return nil end
  return value
end

function U.SafeNumber(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "number" or value ~= value then return nil end
  if value == math.huge or value == -math.huge then return nil end
  return value
end

function U.SafeInteger(value, minimum, maximum)
  value = U.SafeNumber(value)
  if not value or value ~= math.floor(value) then return nil end
  if minimum and value < minimum then return nil end
  if maximum and value > maximum then return nil end
  return value
end

function U.SafeString(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "string" then return nil end
  return value
end

function U.SafeTable(value)
  if not U.CanAccessTable(value) then return nil end
  return value
end

function U.SafeToString(value, fallback)
  if not U.CanAccess(value) then return fallback or "<inaccessible>" end
  local valueType = type(value)
  if valueType == "string" then return value end
  if valueType == "number" or valueType == "boolean" then return tostring(value) end
  if value == nil then return fallback or "" end
  return fallback or ("<" .. valueType .. ">")
end

function U.Trim(value)
  local text = U.SafeString(value)
  if not text then return "" end
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

function U.ToNumber(value)
  local number = U.SafeNumber(value)
  if number then return number end
  local text = U.SafeString(value)
  if not text then return nil end
  text = U.Trim(text)
  if text == "" then return nil end
  return U.SafeNumber(tonumber(text))
end

function U.CopyDefaults(destination, source)
  destination = U.SafeTable(destination) or {}
  source = U.SafeTable(source) or {}

  for key, value in pairs(source) do
    if U.CanAccess(key) and U.CanAccess(value) then
      local keyType = type(key)
      if keyType == "string" or keyType == "number" then
        if type(value) == "table" then
          destination[key] = U.CopyDefaults(destination[key], value)
        elseif destination[key] == nil then
          destination[key] = value
        end
      end
    end
  end
  return destination
end

function U.DeepCopy(value, depth, seen)
  if not U.CanAccess(value) then return nil end
  depth = depth or 0
  if depth > 12 then return nil end

  local valueType = type(value)
  if valueType ~= "table" then return value end
  if not U.SafeTable(value) then return nil end

  seen = seen or {}
  if seen[value] then return nil end
  seen[value] = true

  local result = {}
  local count = 0
  for key, child in pairs(value) do
    count = count + 1
    if count > 1000 then break end
    if U.CanAccess(key) and U.CanAccess(child) then
      local keyType = type(key)
      if keyType == "string" or keyType == "number" then
        result[key] = U.DeepCopy(child, depth + 1, seen)
      end
    end
  end
  seen[value] = nil
  return result
end

local function QueryBoolean(fn, ...)
  if type(fn) ~= "function" then return nil, false end
  local ok, value = pcall(fn, ...)
  if not ok then return nil, false end
  value = U.SafeBool(value)
  if value == nil then return nil, false end
  return value, true
end

function U.ResolveSpellID(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return nil end

  local baseID = spellID
  if C_Spell and type(C_Spell.GetBaseSpell) == "function" then
    local ok, value = pcall(C_Spell.GetBaseSpell, spellID)
    local candidate = ok and U.SafeInteger(value, 1, Addon.MAX_SPELL_ID) or nil
    if candidate then baseID = candidate end
  end

  if C_Spell and type(C_Spell.GetOverrideSpell) == "function" then
    local ok, value = pcall(C_Spell.GetOverrideSpell, baseID, 0, true, 0)
    local candidate = ok and U.SafeInteger(value, 1, Addon.MAX_SPELL_ID) or nil
    if candidate then return candidate end
  end

  return baseID
end

function U.GetSpellName(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return nil end

  if C_Spell and type(C_Spell.GetSpellName) == "function" then
    local ok, value = pcall(C_Spell.GetSpellName, spellID)
    if ok then
      local name = U.SafeString(value)
      if name and name ~= "" then return name end
    end
  end

  if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    local ok, value = pcall(C_Spell.GetSpellInfo, spellID)
    local info = ok and U.SafeTable(value) or nil
    if info then
      local name = U.SafeString(info.name)
      if name and name ~= "" then return name end
    end
  end

  if type(GetSpellInfo) == "function" then
    local ok, value = pcall(GetSpellInfo, spellID)
    if ok then return U.SafeString(value) end
  end
  return nil
end

function U.GetSpellIcon(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return nil end

  if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
    local ok, value = pcall(C_Spell.GetSpellTexture, spellID)
    if ok then
      local icon = U.SafeNumber(value) or U.SafeString(value)
      if icon then return icon end
    end
  end

  if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
    local ok, value = pcall(C_Spell.GetSpellInfo, spellID)
    local info = ok and U.SafeTable(value) or nil
    if info then
      local iconID = U.SafeNumber(info.iconID)
      if iconID then return iconID end
      local icon = U.SafeNumber(info.icon) or U.SafeString(info.icon)
      if icon then return icon end
    end
  end

  if type(GetSpellTexture) == "function" then
    local ok, value = pcall(GetSpellTexture, spellID)
    if ok then return U.SafeNumber(value) or U.SafeString(value) end
  end
  return nil
end

function U.IsSpellKnown(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return false, false end

  -- Retail owns spellbook knowledge through C_SpellBook. The old globals are
  -- compatibility fallbacks and can be absent when loadDeprecationFallbacks
  -- is disabled, so never make them the primary contract.
  if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
    return QueryBoolean(C_SpellBook.IsSpellKnown, spellID)
  end
  if C_SpellBook and type(C_SpellBook.IsSpellKnownOrInSpellBook) == "function" then
    return QueryBoolean(C_SpellBook.IsSpellKnownOrInSpellBook, spellID)
  end

  if type(_G.IsPlayerSpell) == "function" then
    return QueryBoolean(_G.IsPlayerSpell, spellID)
  end
  if type(_G.IsSpellKnown) == "function" then
    return QueryBoolean(_G.IsSpellKnown, spellID)
  end
  return false, false
end

function U.IsSpellUsable(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return false, false end

  local fn = C_Spell and C_Spell.IsSpellUsable or _G.IsUsableSpell
  if type(fn) ~= "function" then return false, false end
  local ok, usableRaw = pcall(fn, spellID)
  if not ok then return false, false end

  local usable = U.SafeBool(usableRaw)
  if usable == nil then return false, false end
  return usable, true
end

function U.GetSpellCooldown(spellID, includeGCDClassification)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return nil, false end

  if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
    local ok, value = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or not U.CanAccess(value) or value == nil then return nil, false end
    local info = U.SafeTable(value)
    if not info then return nil, false end

    local result = {
      startTime = U.SafeNumber(info.startTime),
      duration = U.SafeNumber(info.duration),
      isEnabled = U.SafeBool(info.isEnabled),
      isActive = U.SafeBool(info.isActive),
      modRate = U.SafeNumber(info.modRate),
    }
    if includeGCDClassification == true then
      result.isOnGCD = U.SafeBool(info.isOnGCD)
    end
    return result, true
  end

  if type(_G.GetSpellCooldown) == "function" then
    local ok, startTime, duration, enabled, modRate = pcall(_G.GetSpellCooldown, spellID)
    if not ok then return nil, false end

    startTime = U.SafeNumber(startTime)
    duration = U.SafeNumber(duration)
    local enabledNumber = U.SafeNumber(enabled)
    local enabledBool = U.SafeBool(enabled)
    local isEnabled = enabledBool
    if isEnabled == nil and enabledNumber ~= nil then isEnabled = enabledNumber ~= 0 end
    local isActive = startTime ~= nil and duration ~= nil and startTime > 0 and duration > 0

    return {
      startTime = startTime,
      duration = duration,
      isEnabled = isEnabled,
      isActive = isActive,
      modRate = U.SafeNumber(modRate),
      isOnGCD = nil,
    }, true
  end
  return nil, false
end

function U.GetSpellCharges(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return nil, false end

  if C_Spell and type(C_Spell.GetSpellCharges) == "function" then
    local ok, value = pcall(C_Spell.GetSpellCharges, spellID)
    if not ok or not U.CanAccess(value) then return nil, false end
    if value == nil then return nil, true end

    local info = U.SafeTable(value)
    if not info then return nil, false end
    return {
      currentCharges = U.SafeNumber(info.currentCharges),
      maxCharges = U.SafeNumber(info.maxCharges),
      cooldownStartTime = U.SafeNumber(info.cooldownStartTime),
      cooldownDuration = U.SafeNumber(info.cooldownDuration),
      chargeModRate = U.SafeNumber(info.chargeModRate),
      isActive = U.SafeBool(info.isActive),
    }, true
  end

  if type(_G.GetSpellCharges) == "function" then
    local ok, current, maximum, startTime, duration, modRate = pcall(_G.GetSpellCharges, spellID)
    if not ok then return nil, false end
    if not U.CanAccess(current) or not U.CanAccess(maximum) then return nil, false end
    if current == nil and maximum == nil then return nil, true end

    current = U.SafeNumber(current)
    maximum = U.SafeNumber(maximum)
    startTime = U.SafeNumber(startTime)
    duration = U.SafeNumber(duration)
    return {
      currentCharges = current,
      maxCharges = maximum,
      cooldownStartTime = startTime,
      cooldownDuration = duration,
      chargeModRate = U.SafeNumber(modRate),
      isActive = startTime ~= nil and duration ~= nil and startTime > 0 and duration > 0,
    }, true
  end
  return nil, false
end

function U.GetSpellLossOfControlCooldown(spellID)
  spellID = U.SafeInteger(spellID, 1, Addon.MAX_SPELL_ID)
  if not spellID then return nil, false end

  local fn = C_Spell and C_Spell.GetSpellLossOfControlCooldownInfo
  if type(fn) ~= "function" then
    -- Optional compatibility boundary. The selected 12.1.5 contract exposes
    -- this API; older clients simply have no separate LoC lane.
    return nil, true
  end

  local ok, value = pcall(fn, spellID)
  if not ok or not U.CanAccess(value) then return nil, false end
  if value == nil then return nil, true end

  local info = U.SafeTable(value)
  if not info then return nil, false end
  return {
    startTime = U.SafeNumber(info.startTime),
    duration = U.SafeNumber(info.duration),
    modRate = U.SafeNumber(info.modRate),
    isActive = U.SafeBool(info.isActive),
    shouldReplaceNormalCooldown = U.SafeBool(info.shouldReplaceNormalCooldown),
  }, true
end

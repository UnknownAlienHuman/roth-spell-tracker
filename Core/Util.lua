local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

Addon.Util = Addon.Util or {}
local U = Addon.Util

local unpack = unpack or table.unpack

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

function U.IsSecret(value)
  if not U.CanAccess(value) then return false end
  if type(issecretvalue) ~= "function" then return false end
  local ok, secret = pcall(issecretvalue, value)
  return ok and secret == true
end

function U.SafeBool(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "boolean" then return nil end
  return value
end

function U.SafeNumber(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "number" or value ~= value then return nil end
  return value
end

function U.SafeString(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "string" then return nil end
  return value
end

function U.SafeTable(value)
  if not U.CanAccess(value) then return nil end
  if type(value) ~= "table" then return nil end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret == true then return nil end
  end
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

function U.SafeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local args = { ... }
  local ok, a, b, c, d, e = pcall(function()
    return fn(unpack(args))
  end)
  if ok then return a, b, c, d, e end
  return nil
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
  return tonumber(text)
end

function U.CopyDefaults(destination, source)
  destination = U.SafeTable(destination) or {}
  source = U.SafeTable(source) or {}
  for key, value in pairs(source) do
    if type(value) == "table" then
      destination[key] = U.CopyDefaults(destination[key], value)
    elseif destination[key] == nil then
      destination[key] = value
    end
  end
  return destination
end

function U.DeepCopy(value, depth, seen)
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
    local safeKey = key
    if type(key) ~= "string" and type(key) ~= "number" then
      safeKey = nil
    end
    if safeKey ~= nil then
      result[safeKey] = U.DeepCopy(child, depth + 1, seen)
    end
  end
  seen[value] = nil
  return result
end

local function CallBoolean(fn, spellID)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, spellID)
  if not ok then return nil end
  return U.SafeBool(value)
end

function U.GetSpellName(spellID)
  spellID = U.SafeNumber(spellID)
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
  spellID = U.SafeNumber(spellID)
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
  spellID = U.SafeNumber(spellID)
  if not spellID then return false end

  local predicates = {}
  if C_Spell and type(C_Spell.IsSpellKnown) == "function" then
    predicates[#predicates + 1] = C_Spell.IsSpellKnown
  end
  if type(_G.IsPlayerSpell) == "function" then predicates[#predicates + 1] = _G.IsPlayerSpell end
  if type(_G.IsSpellKnown) == "function" then predicates[#predicates + 1] = _G.IsSpellKnown end

  for _, predicate in ipairs(predicates) do
    local value = CallBoolean(predicate, spellID)
    if value == true then return true end
  end
  return false
end

function U.IsUsableSpell(spellID)
  spellID = U.SafeNumber(spellID)
  if not spellID then return false end

  local fn = C_Spell and C_Spell.IsSpellUsable or _G.IsUsableSpell
  if type(fn) ~= "function" then return false end
  local ok, usableRaw, noManaRaw = pcall(fn, spellID)
  if not ok then return false end
  local usable = U.SafeBool(usableRaw)
  local noMana = U.SafeBool(noManaRaw)
  return usable == true and noMana ~= true
end

function U.GetSpellCooldown(spellID)
  spellID = U.SafeNumber(spellID)
  if not spellID then return nil end

  if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
    local ok, value = pcall(C_Spell.GetSpellCooldown, spellID)
    local info = ok and U.SafeTable(value) or nil
    if not info then return nil end
    return {
      startTime = U.SafeNumber(info.startTime),
      duration = U.SafeNumber(info.duration),
      isEnabled = U.SafeBool(info.isEnabled),
      isOnGCD = U.SafeBool(info.isOnGCD),
      modRate = U.SafeNumber(info.modRate),
    }
  end

  if type(_G.GetSpellCooldown) == "function" then
    local ok, startTime, duration, enabled, modRate = pcall(_G.GetSpellCooldown, spellID)
    if not ok then return nil end
    return {
      startTime = U.SafeNumber(startTime),
      duration = U.SafeNumber(duration),
      isEnabled = U.SafeBool(enabled),
      isOnGCD = nil,
      modRate = U.SafeNumber(modRate),
    }
  end
  return nil
end

function U.GetSpellCharges(spellID)
  spellID = U.SafeNumber(spellID)
  if not spellID then return nil end

  if C_Spell and type(C_Spell.GetSpellCharges) == "function" then
    local ok, value = pcall(C_Spell.GetSpellCharges, spellID)
    local info = ok and U.SafeTable(value) or nil
    if not info then return nil end
    return {
      currentCharges = U.SafeNumber(info.currentCharges),
      maxCharges = U.SafeNumber(info.maxCharges),
      cooldownStartTime = U.SafeNumber(info.cooldownStartTime),
      cooldownDuration = U.SafeNumber(info.cooldownDuration),
      chargeModRate = U.SafeNumber(info.chargeModRate),
    }
  end

  if type(_G.GetSpellCharges) == "function" then
    local ok, current, maximum, startTime, duration, modRate = pcall(_G.GetSpellCharges, spellID)
    if not ok then return nil end
    return {
      currentCharges = U.SafeNumber(current),
      maxCharges = U.SafeNumber(maximum),
      cooldownStartTime = U.SafeNumber(startTime),
      cooldownDuration = U.SafeNumber(duration),
      chargeModRate = U.SafeNumber(modRate),
    }
  end
  return nil
end

function U.SafeSetShown(frame, value)
  if not frame or type(frame.SetShown) ~= "function" then return end
  frame:SetShown(value == true)
end

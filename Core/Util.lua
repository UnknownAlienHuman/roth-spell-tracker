local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon

Addon.Util = Addon.Util or {}
local U = Addon.Util

-- Secret helpers (WoW 12.0+).
-- IMPORTANT: secret booleans must NOT be used in control flow (if/and/or/not).
U.IsSecret = function(x)
  if type(issecretvalue) == "function" then
    return issecretvalue(x) == true
  end
  return false
end

U.CanAccess = function(x)
  if type(canaccessvalue) == "function" then
    local ok, v = pcall(canaccessvalue, x)
    if ok then
      return v == true
    end
  end
  return not U.IsSecret(x)
end

U.SafeBool = function(v)
  if not U.CanAccess(v) then return nil end
  if v == true then return true end
  if v == false then return false end
  return nil
end

U.SafeNumber = function(v)
  if not U.CanAccess(v) then return nil end
  if type(v) == "number" then return v end
  return nil
end

U.CopyDefaults = function(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      U.CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

U.DeepCopy = function(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do
    r[k] = U.DeepCopy(v)
  end
  return r
end

U.SafeCall = function(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if ok then return a, b, c, d, e end
end

U.Trim = function(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

U.ToNumber = function(s)
  if type(s) == "number" then return s end
  if type(s) ~= "string" then return nil end
  s = U.Trim(s)
  if s == "" then return nil end
  return tonumber(s)
end

U.GetSpellName = function(spellID)
  if not spellID then return nil end
  if GetSpellInfo then
    local name = GetSpellInfo(spellID)
    if name then return name end
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name or nil
  end
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(spellID)
  end
  return nil
end

U.GetSpellIcon = function(spellID)
  if not spellID then return nil end
  if GetSpellTexture then
    local tex = GetSpellTexture(spellID)
    if tex then return tex end
  end
  if C_Spell and C_Spell.GetSpellTexture then
    return C_Spell.GetSpellTexture(spellID)
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if info then return info.iconID or info.icon end
  end
  return nil
end

U.IsSpellKnown = function(spellID)
  if not spellID then return false end
  if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
  if IsSpellKnown and IsSpellKnown(spellID) then return true end
  if C_Spell and C_Spell.IsSpellKnown and C_Spell.IsSpellKnown(spellID) then return true end
  return false
end

U.IsUsableSpell = function(spellID)
  if not spellID then return false end
  if IsUsableSpell then
    local usable, nomana = IsUsableSpell(spellID)
    usable = U.SafeBool(usable)
    nomana = U.SafeBool(nomana)
    return usable == true and nomana ~= true
  end
  if C_Spell and C_Spell.IsSpellUsable then
    local usable, nomana = C_Spell.IsSpellUsable(spellID)
    usable = U.SafeBool(usable)
    nomana = U.SafeBool(nomana)
    return usable == true and nomana ~= true
  end
  return false
end

U.SafeSetShown = function(frame, flag)
  if not frame or not frame.SetShown then return end
  -- Frame:SetShown(secretFlag) is safe in WoW 12.0+ per Secret Value docs.
  frame:SetShown(flag)
end

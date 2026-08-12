local ADDON, NS = ...
NS = NS or {}
NS.Addon = NS.Addon or {}
local Addon = NS.Addon
local U = Addon.Util

Addon.Tracker = Addon.Tracker or {}
local T = Addon.Tracker

-- NOTE: All hot paths are event-driven. No permanent OnUpdate.

local function WipeMap(t)
  if type(t) ~= "table" then return end
  for k in pairs(t) do t[k] = nil end
end

-- Aura cache: per refresh we build an index { [spellID] = auraData }
-- for each unit+filter used by configured AURA entries.
T._auraCache = T._auraCache or {
  player = { HELPFUL = {}, HARMFUL = {} },
  target = { HELPFUL = {}, HARMFUL = {} },
  focus  = { HELPFUL = {}, HARMFUL = {} },
}

local MAX_AURAS_SCAN = 200

local function GetAuraDataByIndex(unit, index, filter)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
  end

  -- Fallback: legacy UnitAura (best-effort; may not exist on all builds).
  if UnitAura then
    local name, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitAura(unit, index, filter)
    if name and spellID then
      return {
        name = name,
        icon = icon,
        applications = count,
        duration = duration,
        expirationTime = expirationTime,
        spellId = spellID,
      }
    end
  end

  return nil
end

local function BuildAuraIndex(unit, filter, out)
  WipeMap(out)

  -- UnitExists() can theoretically return a secret boolean on some unit tokens.
  -- For player/target/focus it should be safe, but we still guard.
  if UnitExists then
    local exists = U.SafeBool(UnitExists(unit))
    if exists ~= true then
      return
    end
  end

  for i = 1, MAX_AURAS_SCAN do
    local aura = GetAuraDataByIndex(unit, i, filter)
    if not aura then
      break
    end

    local sid = aura.spellId or aura.spellID
    if type(sid) == "number" then
      out[sid] = aura
    end
  end
end

local function GetSpellCooldown(spellID)
  if C_Spell and C_Spell.GetSpellCooldown then
    return C_Spell.GetSpellCooldown(spellID)
  end
  if GetSpellCooldown then
    local startTime, duration, enabled = GetSpellCooldown(spellID)
    return { startTime = startTime, duration = duration, isEnabled = enabled }
  end
  return nil
end

local function GetSpellCharges(spellID)
  if C_Spell and C_Spell.GetSpellCharges then
    return C_Spell.GetSpellCharges(spellID)
  end
  if GetSpellCharges then
    local currentCharges, maxCharges, cooldownStart, cooldownDuration, chargeModRate = GetSpellCharges(spellID)
    return {
      currentCharges = currentCharges,
      maxCharges = maxCharges,
      cooldownStartTime = cooldownStart,
      cooldownDuration = cooldownDuration,
      chargeModRate = chargeModRate,
    }
  end
  return nil
end

local GCD_THRESHOLD = 1.8 -- seconds; treat short shared cooldowns as GCD

local function EvalAura(entry, auraCache)
  local spellID = entry.id
  local unit = entry.unit or "player"
  local filter = entry.auraType or "HELPFUL"
  local minStacks = tonumber(entry.minStacks) or 0

  local byUnit = auraCache[unit]
  local byFilter = byUnit and byUnit[filter]
  local aura = byFilter and byFilter[spellID] or nil

  local active = (aura ~= nil)
  local icon = aura and aura.icon or nil

  local count = 0
  if active then
    local c = aura.applications or aura.stacks or aura.count
    if type(c) == "number" then count = c end
    if minStacks > 0 and count < minStacks then
      active = false
    end
  end

  local cdStart, cdDur
  if active then
    local dur = U.SafeNumber(aura.duration)
    local exp = U.SafeNumber(aura.expirationTime)
    if dur and exp and dur > 0.05 then
      cdStart = exp - dur
      cdDur = dur
    end
  end

  return active, icon, count, cdStart, cdDur
end

local function EvalSpell(entry)
  local spellID = entry.id

  local known = U.IsSpellKnown(spellID)
  local usable = known and U.IsUsableSpell(spellID)

  local charges = GetSpellCharges(spellID)
  local curCharges, maxCharges
  local chCdStart, chCdDur

  if type(charges) == "table" then
    curCharges = U.SafeNumber(charges.currentCharges or charges.currentCharge)
    maxCharges = U.SafeNumber(charges.maxCharges)
    chCdStart = U.SafeNumber(charges.cooldownStartTime)
    chCdDur = U.SafeNumber(charges.cooldownDuration)
  end

  local hasCharges = (type(curCharges) == "number" and type(maxCharges) == "number" and maxCharges > 0)

  local cd = GetSpellCooldown(spellID)
  local startTime, duration, isOnGCD
  if type(cd) == "table" then
    startTime = U.SafeNumber(cd.startTime)
    duration = U.SafeNumber(cd.duration)
    isOnGCD = U.SafeBool(cd.isOnGCD)
  end

  local ignoreGCD = (entry.ignoreGCD ~= false)

  local onRealCD = false
  if startTime and duration and duration > 0.05 then
    local treatAsGCD = (duration <= GCD_THRESHOLD) or (isOnGCD == true)
    if ignoreGCD and treatAsGCD then
      onRealCD = false
    else
      onRealCD = startTime > 0
    end
  end

  local ready
  if hasCharges then
    ready = usable and (curCharges or 0) > 0
  else
    ready = usable and (not onRealCD)
  end

  local count = 0
  if hasCharges and maxCharges and maxCharges > 1 then
    count = curCharges or 0
  end

  -- Cooldown swirl:
  --  * for charges: show charge cooldown only when empty
  --  * otherwise: show real cooldown (ignore GCD)
  local cdStart, cdDur
  if hasCharges then
    if (curCharges or 0) <= 0 and chCdStart and chCdDur and chCdDur > 0.05 then
      cdStart, cdDur = chCdStart, chCdDur
    end
  else
    if onRealCD and startTime and duration then
      cdStart, cdDur = startTime, duration
    end
  end

  return ready == true, nil, count, cdStart, cdDur
end

local function ShowWhenDefault(kind)
  -- Default behavior requested: glow indicates availability, icon stays visible.
  return "ALWAYS"
end

local function ShouldShow(kind, showWhen, active)
  showWhen = showWhen or ShowWhenDefault(kind)

  if showWhen == "ALWAYS" then
    return true
  end

  if kind == "SPELL" then
    if showWhen == "READY" then return active == true end
    if showWhen == "NOTREADY" then return active ~= true end
    return active == true
  end

  -- AURA
  if showWhen == "ACTIVE" then return active == true end
  if showWhen == "INACTIVE" then return active ~= true end
  return active == true
end

local function AlphaFor(kind, showWhen, active)
  -- When icons are always visible, dim inactive state.
  if (showWhen or "") == "ALWAYS" then
    return (active == true) and 1 or 0.35
  end
  return 1
end

function T:Init()
  if self._ev then return end

  local f = CreateFrame("Frame")
  self._ev = f

  f:RegisterEvent("UNIT_AURA")
  f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  f:RegisterEvent("SPELL_UPDATE_CHARGES")
  f:RegisterEvent("SPELLS_CHANGED")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("PLAYER_FOCUS_CHANGED")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:RegisterEvent("PLAYER_REGEN_ENABLED")

  f:SetScript("OnEvent", function(_, event, a1)
    if event == "UNIT_AURA" then
      if a1 == "player" or a1 == "target" or a1 == "focus" then
        T:RequestRefresh()
      end
    else
      T:RequestRefresh()
    end
  end)
end

function T:RequestRefresh()
  if self._refreshQueued then return end
  self._refreshQueued = true

  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      T._refreshQueued = false
      T:Refresh()
    end)
  else
    self._refreshQueued = false
    self:Refresh()
  end
end

function T:Refresh()
  if not (Addon.db and Addon.Display) then return end

  local tracks = Addon.db.tracks
  if type(tracks) ~= "table" then
    Addon.Display:SetCount(0)
    return
  end

  -- 1) Determine which aura caches we need to build.
  local needAura = false
  local need = {
    player = { HELPFUL = false, HARMFUL = false },
    target = { HELPFUL = false, HARMFUL = false },
    focus  = { HELPFUL = false, HARMFUL = false },
  }

  for i = 1, #tracks do
    local e = tracks[i]
    if type(e) == "table" and e.enabled ~= false and type(e.id) == "number" then
      local kind = e.kind or "AURA"
      if kind == "AURA" then
        needAura = true
        local unit = e.unit or "player"
        local filter = e.auraType or "HELPFUL"
        if need[unit] and need[unit][filter] ~= nil then
          need[unit][filter] = true
        end
      end
    end
  end

  -- 2) Build requested aura caches.
  local auraCache = self._auraCache
  if needAura then
    for unit, fset in pairs(need) do
      for filter, required in pairs(fset) do
        if required == true then
          BuildAuraIndex(unit, filter, auraCache[unit][filter])
        else
          -- Keep cache empty when not required this refresh.
          WipeMap(auraCache[unit][filter])
        end
      end
    end
  else
    -- No aura entries: keep all caches empty.
    for unit, byFilter in pairs(auraCache) do
      WipeMap(byFilter.HELPFUL)
      WipeMap(byFilter.HARMFUL)
    end
  end

  -- 3) Render icons in stable order, compacting hidden rows.
  local shown = 0
  for i = 1, #tracks do
    local e = tracks[i]
    if type(e) == "table" and e.enabled ~= false and type(e.id) == "number" and e.id >= 1 then
      local spellID = e.id
      local kind = e.kind or "AURA"
      local active, icon, count, cdStart, cdDur

      if kind == "SPELL" then
        active, icon, count, cdStart, cdDur = EvalSpell(e)
      else
        active, icon, count, cdStart, cdDur = EvalAura(e, auraCache)
      end

      local showWhen = e.showWhen or ShowWhenDefault(kind)
      local show = ShouldShow(kind, showWhen, active)

      if show then
        shown = shown + 1

        -- Ensure pooled icon exists before we update it.
        if Addon.Display.GetIcon then
          Addon.Display:GetIcon(shown)
        end

        local tex = icon or U.GetSpellIcon(spellID)
        Addon.Display:UpdateIconTexture(shown, tex)
        Addon.Display:UpdateIconCount(shown, count)
        Addon.Display:UpdateIconCooldown(shown, cdStart, cdDur)
        Addon.Display:SetIconAlpha(shown, AlphaFor(kind, showWhen, active))
        Addon.Display:SetIconGlow(shown, active)
        Addon.Display:SetIconShown(shown, true)
      end
    end
  end

  Addon.Display:SetCount(shown)

  -- Ensure hidden pooled icons are truly hidden + no lingering glow.
  for j = shown + 1, #Addon.Display.icons do
    Addon.Display:SetIconGlow(j, false)
    Addon.Display:SetIconShown(j, false)
  end
end

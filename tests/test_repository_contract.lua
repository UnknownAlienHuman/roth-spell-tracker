local function read(path)
  local handle, err = io.open(path, "rb")
  assert(handle, err or ("cannot open " .. path))
  local content = handle:read("*a")
  handle:close()
  return content
end

local toc = read("RothSpellTracker.toc")
assert(toc:find("## Interface: 120105", 1, true), "wrong Interface")
assert(toc:find("## Version: 0.4.4", 1, true), "wrong TOC version")
assert(toc:find("## X-DB-Schema: 3", 1, true), "DB schema receipt missing")
assert(not toc:find("Libs\\", 1, true), "TOC library path case is wrong")

for line in toc:gmatch("[^\r\n]+") do
  if line ~= "" and not line:match("^##") then
    local path = line:gsub("\\", "/")
    local handle = io.open(path, "rb")
    assert(handle, "TOC path does not exist with exact case: " .. path)
    handle:close()
  end
end

local config = read("Core/Config.lua")
assert(config:find('Addon.VERSION = "0.4.4"', 1, true), "Config version mismatch")
assert(config:find("Addon.MAX_TRACKS = 500", 1, true), "track bound missing")
assert(config:find("Addon.MAX_TRACK_INPUTS = 2000", 1, true), "persistence scan bound missing")
assert(config:find("Addon.MAX_LEGACY_ID_TEXT = 64", 1, true), "legacy key bound missing")
assert(config:find("Addon.MAX_ENUM_TEXT = 32", 1, true), "enum bound missing")
assert(config:find("Addon.MIN_ICON_SIZE = 24", 1, true), "icon minimum missing")
assert(config:find("Addon.MAX_ICON_SIZE = 96", 1, true), "icon maximum missing")
assert(config:find("Addon.MAX_ICON_SPACING = 30", 1, true), "spacing maximum missing")

local runtimePaths = {
  "Core/Config.lua",
  "Core/Util.lua",
  "Core/Logging.lua",
  "Core/Minimap.lua",
  "Core/ConfigUI.lua",
  "Core/Core.lua",
  "Modules/Display.lua",
  "Modules/ManagedAuras.lua",
  "Modules/Tracker.lua",
}
for _, path in ipairs(runtimePaths) do
  local content = read(path)
  assert(not content:find("C_UnitAuras", 1, true), path .. " contains raw aura API")
  assert(not content:find("UNIT_AURA", 1, true), path .. " contains raw aura event")
  assert(not content:find("UpdateAllAuras", 1, true), path .. " appends managed refresh")
end

local util = read("Core/Util.lua")
local modernKnown = assert(util:find("C_SpellBook.IsSpellKnown", 1, true), "modern spellbook knowledge API missing")
local legacyKnown = assert(util:find("_G.IsPlayerSpell", 1, true), "compatibility knowledge fallback missing")
assert(modernKnown < legacyKnown, "deprecated knowledge API precedes current contract")
assert(not util:find("C_Spell.IsSpellKnown", 1, true), "nonexistent C_Spell knowledge API used")
assert(util:find("GetSpellLossOfControlCooldownInfo", 1, true), "LoC query wrapper missing")
assert(util:find("canaccesstable", 1, true), "table access gate missing")

local managed = read("Modules/ManagedAuras.lua")
assert(not managed:find("PLAYER_TARGET_CHANGED", 1, true), "addon owns target refresh")
assert(not managed:find("PLAYER_FOCUS_CHANGED", 1, true), "addon owns focus refresh")
assert(managed:find("local overlay = CreateFrame", 1, true), "managed count overlay layer missing")

local tracker = read("Modules/Tracker.lua")
assert(tracker:find('event == "SPELL_UPDATE_COOLDOWN"', 1, true), "event-scoped GCD gate missing")
assert(tracker:find('"LEARNED_SPELL_IN_SKILL_LINE"', 1, true), "spellbook identity invalidation missing")
assert(tracker:find('RegisterUnitEvent("LOSS_OF_CONTROL_ADDED", "player")', 1, true), "LoC added event missing")
assert(tracker:find('RegisterUnitEvent("LOSS_OF_CONTROL_UPDATE", "player")', 1, true), "LoC update event missing")
assert(tracker:find("self.resolvedSpells", 1, true), "resolved spell cache missing")
assert(tracker:find("showCount = showCount", 1, true), "authoritative charge-count visibility missing")
assert(not tracker:find("and not lossOfControlReplaces", 1, true), "LoC display policy still gates readiness")
assert(not tracker:find("and lossOfControlStateReadable", 1, true), "optional LoC query still gates readiness")
assert(not tracker:find("ACTIONBAR_UPDATE_USABLE", 1, true), "obsolete actionbar usability owner")

local display = read("Modules/Display.lua")
assert(display:find("visual.chargeCooldown", 1, true), "charge cooldown lane missing")
assert(display:find("visual.lossOfControlCooldown", 1, true), "LoC cooldown lane missing")
assert(display:find("visual.overlay", 1, true), "top presentation overlay missing")
assert(display:find("state.showCount == true", 1, true), "zero/one charge rendering missing")
assert(display:find('RegisterEvent("UI_SCALE_CHANGED")', 1, true), "UI scale invalidation missing")
assert(display:find('RegisterEvent("DISPLAY_SIZE_CHANGED")', 1, true), "display-size invalidation missing")
assert(display:find("CooldownFrame_Set(cooldown, startTime, duration, true, false, modRate)", 1, true), "fallback loses modRate")
assert(display:find("cooldown.rstSuppressed == true", 1, true), "suppression recovery missing")

local core = read("Core/Core.lua")
assert(not core:find('"/rst"', 1, true), "conflicting slash alias restored")
assert(core:find("ManagedAuras.Init", 1, true), "managed owner init missing")
assert(core:find("scanned > TRACK_INPUT_CAP", 1, true), "pre-sanitization scan bound missing")
assert(core:find("version > Addon.DB_VERSION", 1, true), "forward-version guard missing")
assert(core:find("self.dbReadOnly = true", 1, true), "future DB read-only mode missing")
assert(core:find("LegacySourceOrder", 1, true), "deterministic legacy alias ordering missing")
assert(core:find("CanonicalizeDB", 1, true), "allowlisted DB canonicalization missing")
assert(core:find("CopyMinimapPreferences", 1, true), "allowlisted minimap carry-forward missing")
assert(core:find("CopyFramePreferences", 1, true), "allowlisted frame carry-forward missing")
assert(core:find("ConfirmResetDB", 1, true), "destructive reset confirmation missing")
assert(core:find("ICON_SIZE_MAX", 1, true), "persistence/UI icon bounds are not shared")
assert(core:find("ICON_SPACING_MAX", 1, true), "persistence/UI spacing bounds are not shared")

local configUI = read("Core/ConfigUI.lua")
assert(configUI:find("relationship%-constrained"), "AuraContainer relationship limit is not surfaced")
assert(configUI:find("Addon.MIN_ICON_SIZE", 1, true), "UI icon minimum is not shared")
assert(configUI:find("Addon.MAX_ICON_SIZE", 1, true), "UI icon maximum is not shared")
assert(configUI:find("Addon.MAX_ICON_SPACING", 1, true), "UI spacing maximum is not shared")
assert(configUI:find("Addon:ConfirmResetDB()", 1, true), "UI bypasses reset confirmation")
assert(not configUI:find("Addon:ResetDB()", 1, true), "UI performs destructive reset directly")
assert(configUI:find("Changes are session%-only"), "future-schema UI warning missing")
assert(configUI:find("UISpecialFrames", 1, true), "Escape-close ownership missing")
assert(configUI:find('"WowScrollBoxList"', 1, true), "current ScrollBox template missing")
assert(configUI:find('"MinimalScrollBar"', 1, true), "current ScrollBar template missing")
assert(configUI:find("CreateScrollBoxListLinearView", 1, true), "linear ScrollBox view missing")
assert(configUI:find("CreateIndexRangeDataProvider", 1, true), "index-range provider missing")
assert(configUI:find("GetElementData", 1, true), "recycled rows do not re-resolve current index")
assert(configUI:find("SetElementResetter", 1, true), "row resetter missing")
assert(not configUI:find("UIPanelScrollFrameTemplate", 1, true), "deprecated UIPanel scroll owner restored")
assert(not configUI:find("FauxScrollFrame", 1, true), "deprecated FauxScrollFrame restored")
assert(not configUI:find("HybridScrollFrame", 1, true), "deprecated HybridScrollFrame restored")

local workflow = read(".github/workflows/validate.yml")
assert(workflow:find("permissions:", 1, true), "workflow permissions missing")
assert(workflow:find("contents: read", 1, true), "workflow is not read-only")
assert(workflow:find("luac5.1", 1, true), "Lua 5.1 syntax gate missing")
assert(workflow:find('for test in tests/test_*.lua', 1, true), "regression test discovery missing")
assert(not workflow:find("continue-on-error", 1, true), "CI failures are ignored")

print("PASS: repository contract canonicalizes persistence and uses current Retail ownership/UI APIs")

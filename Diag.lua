local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- /ld diag: compact report for the first in-game tests. Every probe is
-- protected; the report contains no character or realm names.
---------------------------------------------------------------------------
-- A string is one function Luredon needs. A table lists alternatives (1.16): Luredon uses the
-- first one present, so only "none present" is a gap; the report names the one in use
-- (e.g. the modern client has GetMouseFoci, the old GetMouseFocus is gone, and that is fine).
local APIS = {
  "GetProfessions", "GetProfessionInfo",
  { label = "spell known api", "C_SpellBook.IsSpellKnown", "IsPlayerSpell" },
  { label = "weapon enchant api", "GetWeaponEnchantInfo", "C_PaperDollInfo.GetTemporaryEnchantmentInfo" },
  "UnitCastingInfo", "UnitChannelInfo", "UnitExists", "canaccessvalue", "issecretvalue",
  { label = "mouse focus api", "GetMouseFoci", "GetMouseFocus" },
  "IsMouselooking", "SetOverrideBindingClick", "ClearOverrideBindings", "GetBindingAction",
  "C_TooltipInfo.GetItemByID",
  { label = "bag item api", "C_Container.GetContainerItemID", "C_Container.GetContainerItemInfo" },
  { label = "item info instant api", "C_Item.GetItemInfoInstant", "GetItemInfoInstant" },
  { label = "item info api", "C_Item.GetItemInfo", "GetItemInfo" },
  { label = "item count api", "C_Item.GetItemCount", "GetItemCount" },
  { label = "spell name api", "C_Spell.GetSpellName", "C_Spell.GetSpellInfo", "GetSpellInfo" },
  "IsFishingLoot", "GetLootSlotLink", "C_Minimap.SetTracking", "C_Minimap.GetTrackingInfo",
  "C_EquipmentSet.UseEquipmentSet", "C_UnitAuras.GetPlayerAuraBySpellID", "C_DateAndTime.GetCurrentCalendarTime",
  "C_Map.GetBestMapForUnit", "PlaySound", "IsSwimming", "IsFlying", "UnitOnTaxi", "UnitIsDeadOrGhost",
  "Settings.RegisterAddOnSetting", "CreateSettingsButtonInitializer",
}
local CONSTANTS = {
  "ERR_FISH_ESCAPED", "ERR_FISH_NOT_HOOKED", "ITEM_MIN_SKILL", "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE",
  "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "INVSLOT_MAINHAND",
}

local function Lookup(path)
  local v = _G
  for part in path:gmatch("[^%.]+") do
    if type(v) ~= "table" then return nil end
    v = v[part]
  end
  return v
end

-- Any value as short text: nil, secret, or the value.
local function Show(v)
  if type(v) == "nil" then return "nil" end
  if not ns.Usable(v) then return "secret" end
  if type(v) == "number" then
    if v == math.floor(v) then return tostring(v) end
    return ("%.2f"):format(v)
  end
  if type(v) == "boolean" then return v and "yes" or "no" end
  return tostring(v)
end

-- Calls fn protected; returns "error" or the values.
local function Probe(fn, ...)
  if not fn then return "missing" end
  local result = { pcall(fn, ...) }
  if not result[1] then return "error" end
  return unpack(result, 2, 6)
end

local function Ago(t)
  return ("-%.1fs"):format(math.max(0, GetTime() - (t or 0)))
end

-- Sections; one failing section does not stop the report.
local function Header(out)
  local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
  local build, buildNumber, _, toc
  if GetBuildInfo then build, buildNumber, _, toc = GetBuildInfo() end
  out[#out + 1] = ("addon %s, client %s (build %s, interface %s), locale %s"):format(Show(version),
    Show(build), Show(buildNumber), Show(toc), Show(GetLocale and GetLocale()))
  out[#out + 1] = ("options: easyCast %s, autoLure %s, sounds %s, softInteract %s, conflict %s"):format(
    Show(ns.db.easyCast), Show(ns.db.autoLure), Show(ns.db.sounds), Show(ns.db.softInteract), Show(ns.conflict or "none"))
  local pos = type(ns.db.panelPos) == "table" and ns.db.panelPos
  out[#out + 1] = ("window: show %s, only with pole %s, shown %s, locked %s, scale %s, alpha %s, collapsed %s, combat dim %s, pos %s, kit %s"):format(
    Show(ns.db.showPanel), Show(ns.db.panelOnlyWithPole), Show(ns.panel and ns.panel:IsShown()), Show(ns.db.panelLocked),
    Show(ns.db.panelScale), Show(ns.db.panelAlpha), Show(ns.db.panelCollapsed), Show(ns.db.combatFade),
    pos and ("%s %s %s %s"):format(Show(pos[1]), Show(pos[2]), Show(pos[3]), Show(pos[4])) or "default",
    Show(ns.Style and ns.Style.VERSION))
  out[#out + 1] = "texts cut: " .. Show(ns.Style and ns.Style.TextCutCount and ns.Style.TextCutCount())
  -- 1.16: which timers run (none without pole and without Fishing learned).
  out[#out + 1] = ("tickers: window %s, lure check %s"):format(Show(ns.PanelTicking and ns.PanelTicking()),
    Show(ns.LureTicking and ns.LureTicking()))
  out[#out + 1] = ("mouse: right button %s, pass-through api %s"):format(Show(ns.clickMode),
    (ns.panel and type(ns.panel.SetPassThroughButtons) == "function") and "yes" or "no")
end

-- Which of the alternatives is present (the first one wins, as in the code), or nil.
local function FirstPresent(entry)
  for _, name in ipairs(entry) do
    if type(Lookup(name)) == "function" then return name end
  end
end

-- Returns the lines "apis: ..." and "api alternatives: ..." (also used by the tests).
function ns.DiagApiLines()
  local missing, chosen = {}, {}
  for _, entry in ipairs(APIS) do
    if type(entry) == "table" then
      local used = FirstPresent(entry)
      if used then
        chosen[#chosen + 1] = entry.label .. ": " .. used
      else
        missing[#missing + 1] = table.concat(entry, "/")
      end
    elseif type(Lookup(entry)) ~= "function" then
      missing[#missing + 1] = entry
    end
  end
  local apis = ("apis: %d of %d present"):format(#APIS - #missing, #APIS)
    .. (#missing > 0 and (", missing: " .. table.concat(missing, ", ")) or "")
  return apis, "api alternatives: " .. (#chosen > 0 and table.concat(chosen, ", ") or "none")
end

local function Apis(out)
  local apis, alternatives = ns.DiagApiLines()
  out[#out + 1] = apis
  out[#out + 1] = alternatives
  local consts = {}
  for _, name in ipairs(CONSTANTS) do
    local v = Lookup(name)
    consts[#consts + 1] = name .. "=" .. (type(v) == "nil" and "missing" or "ok")
  end
  out[#out + 1] = "constants: " .. table.concat(consts, ", ")
  out[#out + 1] = ("pole class/subclass: %s/%s"):format(
    Show(Enum and Enum.ItemClass and Enum.ItemClass.Weapon), Show(Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole))
end

local function Fishing(out)
  local index, how = ns.FishingProfession()
  local spellBook, playerSpell = ns.FishingKnownProbe()
  out[#out + 1] = ("fishing known: professions %s (index %s), IsSpellKnown(7620) %s, IsPlayerSpell(7620) %s -> %s"):format(
    how, Show(index), spellBook, playerSpell, Show(ns.KnowsFishing()))
  local rank, maxRank, modifier = ns.GetSkill()
  local castWith = ns.FishingCastSpell()
  out[#out + 1] = ("skill: %d/%d, modifier %d, spell name %s, cast by %s, double-click %s"):format(rank, maxRank, modifier,
    ns.FishingSpellName() and "ok" or "nil", type(castWith) == "number" and ("id " .. castWith) or "name",
    Show(ns.CastBlockReason and ns.CastBlockReason() or "ready"))
  local mapID, need, parts = ns.ZoneRequirement()
  out[#out + 1] = ("zone: map %s, needs %s, parts %s%s"):format(Show(mapID), Show(need), Show(parts),
    ns.IsNewForeverZone(mapID) and ", new Forever zone" or "")
end

local function Pole(out)
  out[#out + 1] = ("pole: %s (item %s)"):format(Show(ns.HasPole()), Show(ns.PoleItemID()))
  local has, raw, charges, enchantID = Probe(GetWeaponEnchantInfo)
  out[#out + 1] = ("GetWeaponEnchantInfo: has %s, expiration %s, charges %s, enchant %s"):format(
    Show(has), Show(raw), Show(charges), Show(enchantID))
  local lure, left, id = ns.GetLure()
  out[#out + 1] = ("lure: %s, left %s s, enchant %s, unit %s"):format(Show(lure), left and ("%.0f"):format(left) or "nil",
    Show(id), ns.lureSeconds and "s (detected)" or "ms")
  local best = ns.BestLure()
  local learned = {}
  for item, enchant in pairs(ns.db.lureEnchants or {}) do learned[#learned + 1] = ("%s=%s"):format(Show(item), Show(enchant)) end
  table.sort(learned)
  out[#out + 1] = ("best lure in bags: %s, learned enchants: %s"):format(best and ("item:" .. best.item) or "none",
    #learned > 0 and table.concat(learned, " ") or "none")
end

local function Mouse(out)
  local exists = Probe(UnitExists, "mouseover")
  local focus = "missing"
  if GetMouseFoci then
    local foci = Probe(GetMouseFoci)
    if type(foci) == "table" then
      local f = foci[1]
      focus = f == nil and "none" or f == WorldFrame and "WorldFrame" or "frame"
    else
      focus = Show(foci)
    end
  end
  local casting = "missing"
  if UnitCastingInfo then
    local ok, name = pcall(UnitCastingInfo, "player")
    casting = not ok and "error" or type(name) == "nil" and "no" or ns.Usable(name) and "yes" or "secret"
  end
  out[#out + 1] = ("mouseover: UnitExists %s, focus %s, mouselook %s"):format(Show(exists), focus, Show(Probe(IsMouselooking)))
  out[#out + 1] = ("state: combat %s, mounted %s, swimming %s, flying %s, taxi %s, dead %s, casting %s"):format(
    Show(InCombatLockdown()), Show(Probe(IsMounted)), Show(Probe(IsSwimming)), Show(Probe(IsFlying)),
    Show(Probe(UnitOnTaxi, "player")), Show(Probe(UnitIsDeadOrGhost, "player")),
    casting)
end

local function Binding(out)
  local s = ns.CastState and ns.CastState() or {}
  local bound = GetBindingAction and Probe(GetBindingAction, "BUTTON2", true)
  out[#out + 1] = ("override: active %s, BUTTON2 -> %s"):format(Show(s.override), Show(bound ~= "" and bound or "default"))
  out[#out + 1] = ("next click: %s%s, lure wait %.1fs, lure casting %s, applied lure %s, renew skipped %s, line in %s"):format(
    Show(s.nextAction), s.nextLure and (" item:" .. s.nextLure) or "", s.lureWait or 0, Show(s.lureCasting or false),
    s.appliedLure and ("item:" .. s.appliedLure) or "none", Show(s.renewSkipped or false),
    s.lineInAgo and ("%.1fs ago"):format(s.lineInAgo) or "never")
end

local function Sounds(out)
  local values = {}
  for _, cvar in ipairs(ns.SOUND_CVARS or {}) do
    local v = GetCVar and Probe(GetCVar, cvar)
    values[#values + 1] = cvar:gsub("^Sound_", ""):gsub("^SoftTarget", "Soft") .. "=" .. Show(v)
  end
  out[#out + 1] = "cvars: " .. table.concat(values, " ")
  out[#out + 1] = ("saved copies: sounds %s, soft interact %s"):format(Show(ns.db.savedSounds ~= nil), Show(ns.db.savedSoft ~= nil))
end

local function Extras(out)
  local progress, goal, item = ns.GoalProgress()
  out[#out + 1] = ("goal: %s, rare alert %s from quality %s, background sound %s"):format(
    progress and ("%d/%d %s"):format(progress, goal, item and ("item:" .. item) or "fish") or "off",
    Show(ns.db.rareAlert), Show(ns.db.rareQuality), Show(ns.db.bgSound))
  -- (1.0) auction prices (Auctionator): does the call answer in this client?
  local sample = (ns.session and next(ns.session.items)) or 6291 -- a caught item, else Raw Brilliant Smallfish
  local price, failed = Probe(ns.AuctionPrice, sample)
  out[#out + 1] = ("auction prices: option %s, Auctionator %s, price of item:%d %s"):format(
    Show(ns.db.auctionPrices), ns.AuctionatorLoaded() and "API found" or "not found", sample,
    price == "error" and "error" or (price and ("%d copper"):format(price) or (failed and "error" or "none (no scan or no price)")))
  local weekday, startHour, endHour, custom = ns.DerbySchedule()
  local state, seconds = ns.DerbyState()
  out[#out + 1] = ("derby: day %d %d-%d (%s), %s %s, tastyfish %d"):format(weekday, startHour, endHour,
    custom and "custom" or "classic", Show(state), seconds and ns.Duration(seconds) or "-", ns.ItemCount(ns.DERBY.fish))
  -- 1.16: where the schedule comes from (realm time from the calendar API; day 1 = Sunday).
  local d = ns.DERBY
  out[#out + 1] = custom and "derby source: /ld derby (set by the player)"
    or ("derby source: built-in classic time, same as Forever client data (Holiday %d, build %s), %s"):format(
      d.holiday or 0, tostring(d.dataBuild or "?"), d.announced and "announced" or "not announced by Blizzard: unconfirmed")
  out[#out + 1] = ("tracking saved: %s"):format(ns.db.savedTracking and table.concat(ns.db.savedTracking, " ") or "none")
  -- 1.17: catch log and fishing view (no names: item counts and settings only).
  local lb = type(ns.db.logbook) == "table" and ns.db.logbook or {}
  local rec = type(lb.records) == "table" and lb.records or {}
  local kinds, total = ns.LogTotals()
  out[#out + 1] = ("catch log: schema %s of %d, %s, kinds %d/%d, catches %d, record streak %s, best %s fish/h, streak now %d, skipped unreadable %d"):format(
    Show(lb.schema), ns.LOG_SCHEMA, ns.logLocked and "locked (newer schema)" or "ok", kinds, ns.LOG_MAX, total,
    Show(rec.streak), Show(rec.fph), ns.LogStreak(), ns.logSkipped.secret or 0)
  out[#out + 1] = ("fishing view: mode %s, active %s"):format(Show(ns.db.fishingView), Show(ns.FishingViewActive and ns.FishingViewActive()))
  -- (1.4) whole interface hidden while fishing
  local hs = ns.hideUIStats or {}
  out[#out + 1] = ("hide interface: option %s, asked %s, hidden now %s, hides %s, shows %s, failed %s, last back %s, ticker lines %s, api %s"):format(
    Show(ns.db.hideUI), Show(ns.db.askedHideUI), Show(ns.InterfaceHidden and ns.InterfaceHidden()), Show(hs.hides), Show(hs.shows),
    Show(hs.failed), Show(hs.lastReason), Show(hs.lines), Show(type(SetUIVisibility) == "function"))
  -- (1.4.1) Alt+Z by the player, bobber pointer
  out[#out + 1] = ("hide interface by player: released %s, left alone %s, watch %s, auto loot tip %s"):format(
    Show(hs.released or 0), Show(hs.playerHidden or 0), Show(ns.HideWatchRunning and ns.HideWatchRunning()), Show(ns.db.autoLootHinted or false))
  if ns.BobberPointerState then
    local bp = ns.BobberPointerState()
    out[#out + 1] = ("bobber pointer: option %s, line out %s, ticking %s, shown %s"):format(Show(ns.db.bobberCursor), Show(bp.lineOut), Show(bp.ticking), Show(bp.shown))
  end
  if ns.ShareDiag then out[#out + 1] = ns.ShareDiag() end -- 1.0.1
  if ns.ZoneFishDiag then out[#out + 1] = "zone fish: " .. ns.ZoneFishDiag() end -- 1.2
end

local function Decisions(out)
  local list = ns.diag.decisions
  out[#out + 1] = ("## double-click decisions (last %d)"):format(#list)
  for _, d in ipairs(list) do
    out[#out + 1] = ("%s %s%s%s"):format(Ago(d.t), d.code, d.gap and (" gap " .. d.gap .. "ms") or "",
      d.detail and (" " .. d.detail) or "")
  end
end

local function Events(out)
  local list = ns.diag.events
  out[#out + 1] = ("## line, loot and catch events (last %d)"):format(#list)
  for _, e in ipairs(list) do
    out[#out + 1] = ("%s %s%s"):format(Ago(e.t), e.kind, e.detail and (" " .. e.detail) or "")
  end
end

local function Errors(out)
  local list = ns.diag.errors
  out[#out + 1] = ("## errors (%d%s)"):format(#list, ns.diag.droppedErrors > 0 and (", " .. ns.diag.droppedErrors .. " more not kept") or "")
  for _, e in ipairs(list) do
    out[#out + 1] = ("%s %s x%d: %s"):format(Ago(e.t), e.where, e.count, e.msg)
  end
end

local SECTIONS = {
  { "header", Header }, { "apis", Apis }, { "fishing", Fishing }, { "pole", Pole }, { "mouse", Mouse },
  { "binding", Binding }, { "sounds", Sounds }, { "extras", Extras }, { "decisions", Decisions }, { "events", Events }, { "errors", Errors },
}

-- Character and realm names never go into the report (also not via error texts).
local function Scrub(text)
  local sources = { UnitName, GetRealmName, GetNormalizedRealmName }
  for i = 1, 3 do
    local ok, name = false, nil
    if sources[i] then ok, name = pcall(sources[i], "player") end
    if ok and ns.Usable(name) and type(name) == "string" and #name >= 2 then
      text = text:gsub(name:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1"), "<name>")
    end
  end
  return text
end

function ns.DiagText()
  local out = { "# Luredon diagnostics, format 1" }
  for _, section in ipairs(SECTIONS) do
    local ok, err = pcall(section[2], out)
    if not ok then out[#out + 1] = ("%s: probe failed (%s)"):format(section[1], tostring(err)) end
  end
  return Scrub(table.concat(out, "\n"))
end

function ns.ShowDiag()
  local text = ns.DiagText()
  -- If the window cannot be built, the report goes to chat instead.
  if not ns.Call("diag window", ns.ShowText, L["Diagnostics"], text) then
    for line in text:gmatch("[^\n]+") do print(line) end
  end
end

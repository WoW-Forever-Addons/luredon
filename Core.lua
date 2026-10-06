local addonName, ns = ...
local L = ns.L

ns.defaults = {
  easyCast = true,
  autoLure = true,
  lureWarning = true,
  bagWarning = true,
  sounds = true,
  softInteract = false,
  findFish = true,
  showPanel = true,
  panelOnlyWithPole = true,
  derby = true,
  sessionSummary = true,
  auctionPrices = true, -- (1.0) show auction prices when Auctionator is installed
  fishingSet = "",
  normalSet = "",
  panelPos = nil,
  savedSounds = nil,
  savedSoft = nil,
  zones = {},
  catches = {},
  lifetime = { casts = 0, fish = 0, getaways = 0 },
  skills = {}, -- per character: ["Name-Realm"] = { last, sinceUp, history }
  camp = {},
  lureEnchants = {}, -- lure itemID -> weapon enchant ID, learned when Luredon applies a lure
  panelScale = 1,
  panelAlpha = 0.82,    -- background opacity (Style kit default)
  panelLocked = false,  -- window cannot be dragged
  panelCollapsed = false, -- window shows only its title bar
  combatFade = false,   -- dim the window to 40 % in combat
  bgSound = true,       -- splashes also audible while the game runs in the background
  rareAlert = true,     -- chat line and sound for a rare catch
  rareQuality = "3",    -- from this item quality on (2 uncommon, 3 rare, 4 epic); string for the dropdown
  goalCount = 0,        -- catch goal (0 = off)
  goalItem = 0,         -- 0 = all fish of the session, otherwise this item in the bags
  derbyDay = 0,         -- Fishing Extravaganza weekday (1 = Sunday); 0 = classic schedule
  derbyHour = 14,       -- start hour (realm time), only with derbyDay > 0
  savedTracking = nil,  -- tracking that Find Fish switched off, restored without the pole
  logbook = {},         -- 1.17: catch log (schema, fish per item ID, records), see Log.lua
  logPos = nil,         -- 1.17: position of the catch log window
  logCollapsed = false, -- 1.17: catch log window shows only its title bar
  fishingView = "off",  -- 1.17: while the line is out: "off", "compact" (title bar only) or "faded" (no background)
  shareData = true,     -- 1.0.1: send own fishing totals to guild and group (Share.lua)
  shared = {},          -- 1.0.1: totals other players reported, per key and reporter
  shareSent = {},       -- 1.0.1: [key] = the total last sent
  tempo = {},           -- 1.0.1: [skill step] = { p = skill points, c = casts } (account wide)
}

---------------------------------------------------------------------------
-- Diagnostics: small ring buffers for /ld diag (cheap, capped, session only)
---------------------------------------------------------------------------
local MAX_DECISIONS, MAX_EVENTS, MAX_ERRORS = 10, 12, 5
ns.diag = { decisions = {}, events = {}, errors = {}, droppedErrors = 0 }

local function Remember(list, entry, cap)
  entry.t = GetTime and GetTime() or 0
  list[#list + 1] = entry
  if #list > cap then table.remove(list, 1) end
end

-- Why a double-click was acted on or ignored (reason code, gap between the clicks in ms).
function ns.Decide(code, gap, detail)
  Remember(ns.diag.decisions, { code = code, gap = gap, detail = detail }, MAX_DECISIONS)
end

-- Line in, loot and catch events (kind, short detail without names).
function ns.NoteEvent(kind, detail)
  Remember(ns.diag.events, { kind = kind, detail = detail }, MAX_EVENTS)
end

-- First few distinct errors; one chat line per session points to /ld diag.
local errorNoticeShown = false
function ns.RecordError(where, err)
  local msg
  if ns.Usable(err) and type(err) == "string" then msg = err else msg = "(" .. type(err) .. ")" end
  msg = msg:gsub("^.-AddOns[/\\]", ""):sub(1, 240)
  where = tostring(where or "?")
  for _, e in ipairs(ns.diag.errors) do
    if e.msg == msg and e.where == where then e.count = e.count + 1 return end
  end
  if #ns.diag.errors < MAX_ERRORS then
    Remember(ns.diag.errors, { where = where, msg = msg, count = 1 }, MAX_ERRORS)
  else
    ns.diag.droppedErrors = ns.diag.droppedErrors + 1
  end
  if not errorNoticeShown then
    errorNoticeShown = true
    ns.Print(L["An error occurred. Details with /ld diag."])
  end
end

-- Errors in Luredon's callbacks that the Style kit caught (row tooltip, click, get/set, fades)
-- land in the same error log as the rest (/ld diag) instead of staying silent.
if ns.Style then
  ns.Style.onError = function(where, err) ns.RecordError("ui " .. tostring(where), err) end
end

-- Runs fn protected; an error is recorded instead of stopping the other handlers.
-- Recording itself never throws (it must not turn one error into an endless chain).
function ns.Call(where, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then pcall(ns.RecordError, where, err) end
  return ok
end

-- Wraps fn for timers and tickers.
function ns.Safe(where, fn)
  return function(...) return ns.Call(where, fn, ...) end
end

-- 1.16: a ticker that only runs while it has something to do. Without a fishing pole and
-- without Fishing learned nothing ticks (CPU idle); events switch it on again.
-- ticker:SetActive(on) starts or stops it, ticker:IsActive() tells.
function ns.GatedTicker(where, interval, fn)
  local t = {}
  local safe = ns.Safe(where, fn)
  local handle
  function t:SetActive(on)
    if on and not handle then
      handle = C_Timer.NewTicker(interval, safe)
    elseif not on and handle then
      handle:Cancel()
      handle = nil
    end
  end
  function t:IsActive() return handle ~= nil end
  return t
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
local listeners, initCallbacks = {}, {}

-- Several modules may listen to one event. Unknown events throw, so register defensively.
function ns.On(event, fn)
  if not listeners[event] then
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok then return false end
    listeners[event] = {}
  end
  table.insert(listeners[event], fn)
  return true
end

-- Player-only unit events (other units' arguments may be secret).
local unitFrame = CreateFrame("Frame")
local unitListeners = {}
function ns.OnPlayer(event, fn)
  if not unitListeners[event] then
    local ok = pcall(unitFrame.RegisterUnitEvent, unitFrame, event, "player")
    if not ok then return false end
    unitListeners[event] = {}
  end
  table.insert(unitListeners[event], fn)
  return true
end

-- One failing handler must not stop the others (pcall per handler).
local function Dispatch(list, event, ...)
  if not list then return end
  for i = 1, #list do ns.Call(event, list[i], event, ...) end
end

unitFrame:SetScript("OnEvent", function(_, event, ...)
  if not ns.db then return end
  Dispatch(unitListeners[event], event, ...)
end)

function ns.OnInit(fn) table.insert(initCallbacks, fn) end

local function MergeDefaults(db, defaults)
  for k, v in pairs(defaults) do
    -- 1.17: a table setting that is no table in the saved data (damaged file) starts again
    -- instead of failing in every later `ns.db.zones[...]`.
    if type(v) == "table" and db[k] ~= nil and type(db[k]) ~= "table" then db[k] = nil end
    if db[k] == nil then
      if type(v) == "table" then
        db[k] = {}
        MergeDefaults(db[k], v)
      else
        db[k] = v
      end
    elseif type(v) == "table" and type(db[k]) == "table" then
      MergeDefaults(db[k], v)
    end
  end
end

-- 1.11: window settings for the Style kit. Values the player chose stay; only the untouched
-- old default background (0.75 on the textured tooltip backdrop) moves to the new flat default.
-- Out-of-range or broken values from older versions are repaired.
local UI_VERSION = 2
local OLD_DEFAULT_ALPHA = 0.75
local function Clamp(v, lo, hi, default)
  v = tonumber(v)
  if not v or v ~= v then return default end
  return math.max(lo, math.min(hi, v))
end
function ns.MigrateUI(db)
  if (tonumber(db.uiVersion) or 0) >= UI_VERSION then return end
  if db.panelAlpha == OLD_DEFAULT_ALPHA then db.panelAlpha = ns.defaults.panelAlpha end
  db.panelAlpha = Clamp(db.panelAlpha, 0, 1, ns.defaults.panelAlpha)
  db.panelScale = Clamp(db.panelScale, 0.6, 1.6, 1)
  local pos = db.panelPos
  if pos ~= nil and not (type(pos) == "table" and type(pos[1]) == "string" and tonumber(pos[3]) and tonumber(pos[4])) then
    db.panelPos = nil
  end
  db.panelLocked = db.panelLocked and true or false
  db.combatFade = db.combatFade and true or false
  db.uiVersion = UI_VERSION
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= addonName then return end
    if LuredonDB == nil and type(AngelKompassDB) == "table" then LuredonDB = AngelKompassDB end -- data from AngelKompass
    AngelKompassDB = nil
    LuredonDB = LuredonDB or {}
    MergeDefaults(LuredonDB, ns.defaults)
    ns.MigrateUI(LuredonDB)
    ns.db = LuredonDB
    for _, fn in ipairs(initCallbacks) do ns.Call("init", fn) end
    frame:UnregisterEvent("ADDON_LOADED")
    return
  end
  if not ns.db then return end
  Dispatch(listeners[event], event, ...)
end)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- Chat lines: wordmark prefix, heading in the accent colour, details in the secondary colour.
local WORDMARK = "|cff3fa9f5Lure|rdon"
local ACCENT, SECONDARY = "|cff3fa9f5", "|cff9ea3ad"
ns.WORDMARK = WORDMARK

function ns.Print(msg)
  print(WORDMARK .. ": " .. msg)
end

-- heading (accent), text (normal chat colour), detail (secondary, optional)
function ns.Report(heading, text, detail)
  local line = ACCENT .. heading .. "|r"
  if text and text ~= "" then line = line .. " " .. text end
  if detail and detail ~= "" then line = line .. "  " .. SECONDARY .. detail .. "|r" end
  ns.Print(line)
end

function ns.Warn(msg)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then
    UIErrorsFrame:AddMessage(msg, 1, 0.82, 0)
  else
    ns.Print(msg)
  end
end

-- Secret values (Midnight rules) must never reach comparisons or arithmetic.
function ns.Usable(v)
  if v == nil then return false end
  if canaccessvalue then return canaccessvalue(v) end
  if issecretvalue then return not issecretvalue(v) end
  return true
end

-- Short sound for alerts (plain PlaySound, nothing in Blizzard's state changes).
-- kind: "rare", "goal" or "derby". Each sound ID has a numeric fallback.
local ALERT_SOUNDS = {
  rare  = { "RAID_WARNING", 8959 },
  goal  = { "READY_CHECK", 8960 },
  derby = { "RAID_WARNING", 8959 },
}
function ns.PlayAlert(kind)
  local entry = ALERT_SOUNDS[kind]
  if not (entry and PlaySound) then return false end
  local id = SOUNDKIT and SOUNDKIT[entry[1]] or entry[2]
  return pcall(PlaySound, id, "Master") and true or false
end

function ns.Money(copper)
  copper = math.floor(copper or 0)
  if GetMoneyString then return GetMoneyString(copper, true) end
  return tostring(copper)
end

-- Number with decimals in the client's notation (deDE "9,0", enUS "9.0").
-- DECIMAL_SEPERATOR (Blizzard's spelling) comes from the client's global strings; the locale is the fallback.
local COMMA_LOCALES = { deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true, ruRU = true }
function ns.DecimalSeparator()
  local sep = rawget(_G, "DECIMAL_SEPERATOR") or rawget(_G, "DECIMAL_SEPARATOR")
  if type(sep) == "string" and ns.Usable(sep) and sep ~= "" then return sep end
  return COMMA_LOCALES[GetLocale and GetLocale() or ""] and "," or "."
end

function ns.Decimal(value, places)
  value = tonumber(value) or 0
  if value ~= value then value = 0 end
  local text = ("%." .. (tonumber(places) or 1) .. "f"):format(value)
  local sep = ns.DecimalSeparator()
  if sep ~= "." then text = text:gsub("%.", sep, 1) end
  return text
end

function ns.Duration(seconds)
  seconds = math.max(0, math.floor(seconds or 0))
  local d = math.floor(seconds / 86400)
  local h = math.floor(seconds % 86400 / 3600)
  local m = math.floor(seconds % 3600 / 60)
  local s = seconds % 60
  if d > 0 then return ns.L["%dd %dh"]:format(d, h) end
  if h > 0 then return ns.L["%d:%02d h"]:format(h, m) end
  return ("%d:%02d"):format(m, s)
end

function ns.GetItemInfo(item)
  local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if fn then return fn(item) end
end

function ns.GetSellPrice(item)
  local name, _, _, _, _, _, _, _, _, _, price = ns.GetItemInfo(item)
  if not name then
    if type(item) == "number" and C_Item and C_Item.RequestLoadItemDataByID then
      C_Item.RequestLoadItemDataByID(item)
    end
    return nil
  end
  return price or 0
end

function ns.ItemID(link)
  if not link or not ns.Usable(link) then return nil end
  if type(link) == "number" then return link end
  if type(link) ~= "string" then return nil end
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  return fn and fn(link) or tonumber(link:match("item:(%d+)"))
end

-- Always a number (a missing, secret or broken answer counts as 0).
function ns.ItemCount(itemID)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not fn then return 0 end
  local ok, n = pcall(fn, itemID)
  if ok and ns.Usable(n) and type(n) == "number" then return n end
  return 0
end

function ns.SpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    return info and info.name
  end
  if GetSpellInfo then return (GetSpellInfo(spellID)) end
end

---------------------------------------------------------------------------
-- Mouse on Luredon's windows (1.13)
-- Left clicks stay in the window (no click into the world behind it). The right button
-- passes through to the world, so holding it over the window turns the camera as usual.
-- A double right-click there still never casts: Cast.lua checks whether the pointer is over
-- a Luredon window before it binds the button.
-- SetPassThroughButtons may be restricted in combat, so it is only called out of combat;
-- frames created in combat get it after the fight. Without the function (older client)
-- the window lets every click through (behaviour of 1.11), the cast check still holds.
-- ns.clickMode for /ld diag: "passthrough", "clickthrough", "pending" or "error".
---------------------------------------------------------------------------
local passPending = {}
ns.clickMode = "pending"

local function ApplyPassThrough(f)
  if type(f.SetPassThroughButtons) ~= "function" then
    if f.EnableMouse and f._ldWindow then pcall(f.EnableMouse, f, false) end
    if ns.clickMode ~= "passthrough" then ns.clickMode = "clickthrough" end
    return true
  end
  if InCombatLockdown and InCombatLockdown() then return false end
  local ok = pcall(f.SetPassThroughButtons, f, "RightButton")
  if ok then
    if ns.clickMode ~= "error" then ns.clickMode = "passthrough" end
  else
    -- The call failed: let every click through instead of blocking camera turning.
    if f.EnableMouse and f._ldWindow then pcall(f.EnableMouse, f, false) end
    ns.clickMode = "error"
  end
  return true
end

-- window: the panel itself (left clicks swallowed); parts: header and rows on it.
function ns.RightClickThrough(window, parts)
  if not window then return end
  window._ldWindow = true
  if window.EnableMouse then pcall(window.EnableMouse, window, true) end
  local list = { window }
  for _, f in ipairs(parts or {}) do if f then list[#list + 1] = f end end
  for _, f in ipairs(list) do
    if not ApplyPassThrough(f) then passPending[#passPending + 1] = f end
  end
end

ns.On("PLAYER_REGEN_ENABLED", function()
  if #passPending == 0 then return end
  local list = passPending
  passPending = {}
  for _, f in ipairs(list) do
    if not ApplyPassThrough(f) then passPending[#passPending + 1] = f end
  end
end)

function ns.IsAddOnLoaded(name)
  if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
  return IsAddOnLoaded and IsAddOnLoaded(name)
end

function Luredon_OnAddonCompartmentClick()
  if ns.OpenOptions then ns.Call("compartment", ns.OpenOptions) end
end

-- 1.14: one short line on the very first login with Luredon (no fishing recorded yet).
-- Existing players with statistics never see it. With another fishing addon loaded the
-- double-click belongs to that addon, so the line is left out (Cast.lua says so already).
-- Returns true when the line was printed.
function ns.MaybeWelcome()
  if ns.db.welcomed then return false end
  ns.db.welcomed = true
  if ns.conflict or (ns.db.lifetime and (tonumber(ns.db.lifetime.casts) or 0) > 0) then return false end
  -- 1.16: a character that certainly has not learned Fishing gets no line yet (it would ask
  -- for a double-click that does nothing); it comes once Fishing is learned.
  if ns.KnowsFishing and not ns.KnowsFishing() then
    ns.db.welcomed = nil
    return false
  end
  ns.Print(L["Ready. Equip a fishing pole and double right-click into the world: Luredon applies a lure if needed and casts. /ld help lists the commands."])
  return true
end
local welcomeTried
ns.On("PLAYER_ENTERING_WORLD", function()
  if welcomeTried then return end
  welcomeTried = true
  ns.MaybeWelcome()
end)
-- 1.16: Fishing learned at the trainer during this session: the line comes now.
ns.On("SKILL_LINES_CHANGED", function()
  if welcomeTried and not ns.db.welcomed then ns.MaybeWelcome() end
end)

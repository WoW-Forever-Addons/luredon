local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- 1.17: Catch log (/ld log). A permanent, account-wide record per kind of fish: how many,
-- first and last catch with the zone, plus two records (longest streak without a getaway,
-- best fish per hour of a session). Only items are stored (item ID, no names, no character
-- names); names come from the game when the window is shown.
-- Small on purpose: at most LOG_MAX kinds, the one caught longest ago is dropped first.
-- Only catches the client reports in readable form are counted; a secret loot line or link
-- is skipped and counted for /ld diag.
---------------------------------------------------------------------------
ns.LOG_SCHEMA = 1   -- layout of LuredonDB.logbook; raise it when the layout changes
ns.LOG_MAX = 150    -- kinds kept
local BEST_MIN_ACTIVE = 600 -- a session counts for the fish per hour record from 10 minutes of fishing
local PAGE_SIZE = 10
local WIDTH = 280
local DEFAULT_POINT = { "RIGHT", "RIGHT", -320, 60 }

local function ServerNow() return GetServerTime and GetServerTime() or time() end

-- A finite number or nil.
local function Num(v)
  v = tonumber(v)
  if v and v == v and v ~= math.huge and v ~= -math.huge then return v end
end
-- A whole number of 0 or more, or nil.
local function Count(v)
  v = Num(v)
  if v and v >= 0 then return math.floor(v) end
end

ns.logSkipped = { secret = 0 } -- this session, for /ld diag
function ns.LogSkip(kind)
  ns.logSkipped[kind] = (ns.logSkipped[kind] or 0) + 1
end

local streak = 0 -- catches in a row without a getaway (this session only)
function ns.LogStreak() return streak end
function ns.LogSessionReset() streak = 0 end
function ns.LogGetaway() streak = 0 end

---------------------------------------------------------------------------
-- Storage and migration
---------------------------------------------------------------------------
-- Brings LuredonDB.logbook to the current schema: repairs broken entries, drops the ones caught
-- longest ago above LOG_MAX. A logbook written by a NEWER schema stays untouched and read-only
-- (logging pauses; nothing a newer version wrote is lost by an older one).
-- Returns "ok", "new" (created) or "newer".
function ns.MigrateLog(db)
  db = db or ns.db
  local lb = db.logbook
  local state = "ok"
  if type(lb) ~= "table" then lb = {}; db.logbook = lb; state = "new" end
  local schema = tonumber(lb.schema) or 0
  if schema > ns.LOG_SCHEMA then
    ns.logLocked = true
    return "newer"
  end
  ns.logLocked = nil
  local fish, list = {}, {}
  if type(lb.fish) == "table" then
    for id, e in pairs(lb.fish) do
      id = Num(id)
      local n = type(e) == "table" and Count(e.n)
      if id and id > 0 and id == math.floor(id) and n and n > 0 then
        local entry = { n = n, first = Num(e.first), last = Num(e.last), fz = Count(e.fz), lz = Count(e.lz) }
        fish[id] = entry
        list[#list + 1] = id
      end
    end
  end
  if #list > ns.LOG_MAX then
    table.sort(list, function(a, b)
      local la, lb2 = fish[a].last or 0, fish[b].last or 0
      if la ~= lb2 then return la > lb2 end
      return a < b
    end)
    for i = ns.LOG_MAX + 1, #list do fish[list[i]] = nil end
  end
  local old = type(lb.records) == "table" and lb.records or {}
  local rate = Num(old.fph)
  lb.fish = fish
  lb.records = {
    streak = Count(old.streak) or 0, streakAt = Num(old.streakAt),
    fph = rate and rate > 0 and rate or 0, fphAt = Num(old.fphAt),
  }
  lb.schema = ns.LOG_SCHEMA
  return state
end
ns.OnInit(function() ns.MigrateLog(ns.db) end)

local function Book()
  if ns.logLocked then return nil end
  local lb = ns.db and ns.db.logbook
  if type(lb) ~= "table" or type(lb.fish) ~= "table" or type(lb.records) ~= "table" then
    if not ns.db or ns.MigrateLog(ns.db) == "newer" then return nil end
    lb = ns.db.logbook
  end
  return lb
end

local function DropOldest(fish, keep)
  local worst, worstLast
  for id, e in pairs(fish) do
    if id ~= keep then
      local last = e.last or 0
      if not worst or last < worstLast or (last == worstLast and id < worst) then worst, worstLast = id, last end
    end
  end
  if worst then fish[worst] = nil end
end

-- Best fish per hour of this session (junk does not count), only from BEST_MIN_ACTIVE seconds on.
local function CheckRate(rec, now)
  local s = ns.session
  if not s or (s.active or 0) < BEST_MIN_ACTIVE then return end
  local rate = math.max(0, (s.fish or 0) - (s.junk or 0)) / (s.active / 3600)
  rate = math.floor(rate * 10 + 0.5) / 10
  if rate > (rec.fph or 0) then rec.fph, rec.fphAt = rate, now end
end

-- One catch item (called from Stats.lua with readable values only).
-- newCatch: first item of a new catch (the streak counts catches, not items).
-- Junk (quality 0) counts for the streak but is not a kind of fish.
function ns.LogCatch(id, quantity, mapID, quality, newCatch)
  local lb = Book()
  if not lb then return end
  local now = ServerNow()
  local rec = lb.records
  if newCatch then
    streak = streak + 1
    if streak > (rec.streak or 0) then rec.streak, rec.streakAt = streak, now end
  end
  id, quantity = Count(id), Count(quantity)
  if not id or id <= 0 or not quantity or quantity <= 0 then return end
  if quality == 0 then return end
  local fish = lb.fish
  local e = fish[id]
  if not e then
    e = { n = 0, first = now, fz = Count(mapID) }
    fish[id] = e
    local kinds = 0
    for _ in pairs(fish) do kinds = kinds + 1 end
    while kinds > ns.LOG_MAX do DropOldest(fish, id); kinds = kinds - 1 end
  end
  e.n = e.n + quantity
  e.last = now
  local zone = Count(mapID)
  if zone then e.lz = zone end
  CheckRate(rec, now)
  if ns.logPanel and ns.logPanel:IsShown() then ns.UpdateLog() end
end

-- Sorted kinds: { {id, entry}, ... } most caught first.
function ns.LogEntries()
  local list = {}
  local lb = ns.db and ns.db.logbook
  if type(lb) ~= "table" or type(lb.fish) ~= "table" then return list end
  for id, e in pairs(lb.fish) do list[#list + 1] = { id = id, e = e } end
  table.sort(list, function(a, b)
    if a.e.n ~= b.e.n then return a.e.n > b.e.n end
    return a.id < b.id
  end)
  return list
end

function ns.LogTotals()
  local kinds, total = 0, 0
  for _, item in ipairs(ns.LogEntries()) do kinds = kinds + 1; total = total + item.e.n end
  return kinds, total
end

function ns.LogReset()
  if ns.logLocked then return false end
  ns.db.logbook = nil
  ns.MigrateLog(ns.db)
  streak = 0
  if ns.logPanel and ns.logPanel:IsShown() then ns.UpdateLog() end
  return true
end

---------------------------------------------------------------------------
-- Export (same window as the catch data export): item ID, count, first and last catch as
-- server time (seconds since 1970), map IDs. No names.
---------------------------------------------------------------------------
function ns.LogExportText()
  local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Luredon", "Version")
  local build, _, _, toc
  if GetBuildInfo then build, _, _, toc = GetBuildInfo() end
  local out = {
    "# Luredon catch log export, format 1",
    ("# addon %s, client %s (%s), locale %s"):format(tostring(version or "?"), tostring(build or "?"),
      tostring(toc or "?"), tostring(GetLocale and GetLocale() or "?")),
    "# fish;itemID;count;firstSeen;lastSeen;firstMapID;lastMapID",
    "# record;streak;value;seen",
    "# record;fishPerHour;value;seen",
  }
  local lb = ns.db.logbook
  if type(lb) == "table" and type(lb.records) == "table" then
    local r = lb.records
    out[#out + 1] = ("record;streak;%d;%d"):format(r.streak or 0, r.streakAt or 0)
    out[#out + 1] = ("record;fishPerHour;%.1f;%d"):format(r.fph or 0, r.fphAt or 0)
  end
  for _, item in ipairs(ns.LogEntries()) do
    local e = item.e
    out[#out + 1] = ("fish;%d;%d;%d;%d;%d;%d"):format(item.id, e.n, e.first or 0, e.last or 0, e.fz or 0, e.lz or 0)
  end
  return table.concat(out, "\n")
end

function ns.ShowLogExport()
  ns.ShowText(L["Catch log export"], ns.LogExportText())
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local panel
local rows, headers = {}, {}
local page = 1

-- Position and collapsed state are the window's own; size, opacity, lock and combat dimming
-- follow the main window (same settings page).
local SHARED = { locked = "panelLocked", scale = "panelScale", alpha = "panelAlpha", combatFade = "combatFade" }
local OWN = { pos = "logPos", collapsed = "logCollapsed" }
local function Get(key)
  local k = SHARED[key] or OWN[key]
  if k and ns.db then return ns.db[k] end
end
local function Set(key, value)
  local k = OWN[key]
  if k and ns.db then ns.db[k] = value end
end

local function DateText(ts)
  ts = Num(ts)
  if not ts or ts <= 0 then return "-" end
  local fmt = GetLocale and GetLocale() == "deDE" and "%d.%m.%Y" or "%Y-%m-%d"
  local f = date or (os and os.date)
  local ok, text = pcall(f, fmt, ts)
  return ok and type(text) == "string" and text or "-"
end

local function ZoneText(mapID)
  mapID = Count(mapID)
  if not mapID or mapID <= 0 then return L["unknown"] end
  return ns.MapName(mapID) or L["unknown"]
end

local function ItemText(id)
  local name, link = ns.GetItemInfo(id)
  return link or name or ("item:" .. id)
end

local function PageCount(total) return math.max(1, math.ceil(total / PAGE_SIZE)) end

local function FishTooltip(id, e)
  local lines = {
    { L["Caught"], Style.Number(e.n) },
    { L["First catch"], ("%s, %s"):format(DateText(e.first), ZoneText(e.fz)) },
    { L["Last catch"], ("%s, %s"):format(DateText(e.last), ZoneText(e.lz)) },
  }
  -- (1.0) auction price per piece (Auctionator), only if there is one
  if ns.AuctionPricesOn() then
    local price = ns.AuctionPrice(id)
    lines[#lines + 1] = { L["Auction price"], price and ns.Money(price) or L["no price"] }
  end
  return ItemText(id), lines, L["Counted from all your sessions on this account."]
end

function ns.UpdateLog()
  if not panel then return end
  local list = ns.LogEntries()
  local kinds, total = ns.LogTotals()
  local lb = ns.db.logbook
  local rec = type(lb) == "table" and type(lb.records) == "table" and lb.records or {}

  local streakRec = rec.streak or 0
  Style.KeyValue(rows.streak, L["Longest streak"], streakRec > 0 and L["%d catches in a row"]:format(streakRec) or "-")
  local rate = rec.fph or 0
  Style.KeyValue(rows.rate, L["Best session"], rate > 0 and L["%s fish/h"]:format(ns.Decimal(rate, 1)) or "-")
  Style.KeyValue(rows.kinds, L["Kinds"], ("%d / %d"):format(kinds, ns.LOG_MAX))
  Style.KeyValue(rows.total, L["Caught"], Style.Number(total))

  local pages = PageCount(#list)
  if page > pages then page = pages end
  if page < 1 then page = 1 end
  rows.empty:SetShown(#list == 0)
  if #list == 0 then rows.empty:SetText(L["No catches in the log yet."], "textHint") end
  for i, row in ipairs(rows.fish) do
    local item = list[(page - 1) * PAGE_SIZE + i]
    row:SetShown(item and true or false)
    if item then
      row._logID, row._logEntry = item.id, item.e
      local text = ItemText(item.id)
      local q = ns.ItemQuality(item.id)
      if q and q >= ns.RARE_QUALITY then text = text .. " " .. Style.Colorize(L["(rare)"], "warning") end
      row:SetText(text, "textPrimary")
      row:SetValue(Style.Number(item.e.n), "textPrimary")
    end
  end
  rows.page:SetShown(pages > 1)
  if pages > 1 then rows.page:SetText(L["Page %d of %d"]:format(page, pages), "textHint") end
  local prev, nextB = panel:GetButton("prev"), panel:GetButton("next")
  if prev then prev:SetEnabled(page > 1) end
  if nextB then nextB:SetEnabled(page < pages) end

  rows.locked:SetShown(ns.logLocked and true or false)
  if ns.logLocked then rows.locked:SetText(L["The log comes from a newer Luredon version and stays unchanged."], "textHint") end
  local skipped = ns.logSkipped.secret or 0
  rows.skipped:SetShown(skipped > 0)
  if skipped > 0 then rows.skipped:SetText(L["Skipped this session: %d unreadable loot lines."]:format(skipped), "textHint") end
end

local function ChangePage(delta)
  page = page + delta
  ns.UpdateLog()
end

local function Create()
  panel = Style.Panel("LuredonLogPanel", UIParent, {
    title = Style.Wordmark("Lure", "don") .. "  " .. Style.Colorize(L["Catch log"], "textSecondary"),
    width = WIDTH,
    close = true,
    collapse = true,
    get = Get,
    set = Set,
    defaultPoint = DEFAULT_POINT,
    closeTooltip = { L["Close"], nil, L["/ld log shows it again."] },
    collapseTooltip = { L["Collapse / expand"], nil, L["Collapsed, only the title bar stays."] },
    onCollapse = function(_, collapsed) if not collapsed then ns.UpdateLog() end end,
    buttons = {
      { kind = "forward", key = "next", tooltip = { L["Next page"] }, onClick = function() ChangePage(1) end },
      { kind = "back", key = "prev", tooltip = { L["Previous page"] }, onClick = function() ChangePage(-1) end },
    },
  })

  headers.records = Style.Header(panel, L["Records"])
  rows.streak = Style.Row(panel)
  rows.rate = Style.Row(panel)
  rows.kinds = Style.Row(panel)
  rows.total = Style.Row(panel)

  headers.fish = Style.Header(panel, L["Fish"])
  rows.empty = Style.Row(panel)
  rows.fish = {}
  for i = 1, PAGE_SIZE do
    local row = Style.Row(panel)
    row:SetTooltip(function(r) if r._logEntry then return FishTooltip(r._logID, r._logEntry) end end)
    rows.fish[i] = row
  end
  rows.page = Style.Row(panel)
  rows.locked = Style.Row(panel)
  rows.skipped = Style.Row(panel)
  rows.export = Style.Row(panel):SetText(L["Copy as text"], "accent"):SetGapBefore(Style.SPACING.section)
  rows.export:SetOnClick(function(_, button)
    if button == nil or button == "LeftButton" then ns.ShowLogExport() end
  end)
  rows.export:SetTooltip(function()
    return L["Catch log export"], nil, L["Opens the export window. Contains no character or realm names."]
  end)

  -- Left clicks stay in the window, the right button reaches the world (camera turning);
  -- a double right-click on it never casts (Cast.lua checks the pointer).
  local parts = { panel._header }
  for _, item in ipairs(panel._items or {}) do
    if item._kind == "row" then parts[#parts + 1] = item end
  end
  ns.RightClickThrough(panel, parts)
  Style.CombatFade(panel, ns.db.combatFade)
  panel:SetLocked(ns.db.panelLocked, true)
  panel:SetPanelScale(ns.db.panelScale or 1, true)
  panel:SetBackgroundAlpha(ns.db.panelAlpha, true)
  ns.logPanel = panel
  if ns.ApplyFishingView then ns.ApplyFishingView(panel) end
end

function ns.ApplyLogSettings()
  if not panel then return end
  panel:SetLocked(ns.db.panelLocked, true)
  panel:SetPanelScale(ns.db.panelScale or 1, true)
  panel:SetBackgroundAlpha(ns.db.panelAlpha, true)
  Style.CombatFade(panel, ns.db.combatFade)
end

-- show: nil toggles, true/false sets.
function ns.ToggleLog(show)
  if not panel then
    if show == false then return end
    Create()
  end
  if show == nil then show = not panel:IsShown() end
  if show then
    page = 1
    ns.UpdateLog()
    panel:FadeIn()
  else
    panel:FadeOut()
  end
end

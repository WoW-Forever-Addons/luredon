local _, ns = ...
local L = ns.L

local IDLE_GAP = 90 -- seconds without fishing that do not count as fishing time
local BAGS_LOW = 2  -- warn from this many free bag slots on

local session
function ns.ResetSession()
  session = { active = 0, last = nil, casts = 0, catches = 0, fish = 0, junk = 0,
              getaways = 0, missed = 0, reported = 0, items = {} }
  ns.session = session
  -- A session goal starts again from zero.
  if ns.db and ns.ResetGoalBaseline then ns.ResetGoalBaseline() end
  -- 1.17: the catch log's streak is a session value.
  if ns.LogSessionReset then ns.LogSessionReset() end
end
ns.ResetSession()

-- 1.13: the session survives /reload and a short relog (same character, within
-- SESSION_KEEP seconds). Saved at logout, restored when the world is entered.
-- Note: the Forever beta does not load SavedVariables yet; then a new session starts as before.
local SESSION_KEEP = 15 * 60
local SESSION_FIELDS = { "active", "casts", "catches", "fish", "junk", "getaways", "missed", "reported" }
local function ServerNow() return GetServerTime and GetServerTime() or time() end

local function Touch()
  local now = GetTime()
  if session.last and now - session.last < IDLE_GAP then
    session.active = session.active + (now - session.last)
  end
  session.last = now
end

-- Zone the line was cast in. Getaways and catches belong to it, even if the player
-- crossed a zone border (or a loading screen came) before the line came in.
local castMap
local castBucket -- (1.0.1) total skill step of the current cast

local function CurrentMap()
  local mapID = ns.ZoneRequirement()
  return mapID
end

-- 1.15: zone data from older versions may lack counters (e.g. getaways, junk). Counting into
-- such a zone threw an error, and the getaway or catch was lost for the zone.
local ZONE_COUNTERS = { "casts", "catches", "getaways", "junk" }
local checkedZones = setmetatable({}, { __mode = "k" }) -- zone tables repaired this session
local function Zone(mapID)
  mapID = mapID or CurrentMap()
  if not mapID then return nil end
  local z = ns.db.zones[mapID]
  if type(z) ~= "table" then
    z = { casts = 0, catches = 0, getaways = 0, junk = 0, fish = {} }
    ns.db.zones[mapID] = z
  elseif not checkedZones[z] then
    for _, k in ipairs(ZONE_COUNTERS) do
      if type(z[k]) ~= "number" then z[k] = tonumber(z[k]) or 0 end
    end
    if type(z.fish) ~= "table" then z.fish = {} end
    checkedZones[z] = true
  end
  return z, mapID
end
ns.StatsZone = Zone

---------------------------------------------------------------------------
-- Skill-up tracking: casts needed per skill point
---------------------------------------------------------------------------
-- Skill data is per character (SavedVariables are account-wide; 1.1 shared one
-- table between all characters, so switching characters produced fake skill-ups).
-- 1.15: the key is kept once name and realm are readable (the window asks every second).
local charKey
local function CharKey()
  if charKey then return charKey end
  local name = UnitName and UnitName("player")
  local realm = GetRealmName and GetRealmName()
  if not (ns.Usable(name) and type(name) == "string") then name = nil end
  if not (ns.Usable(realm) and type(realm) == "string") then realm = nil end
  local key = (name or "?") .. "-" .. (realm or "?")
  if name and realm then charKey = key end
  return key
end
-- Asked again after a loading screen (and by the tests after a character change).
function ns.ResetCharKey() charKey = nil end
ns.On("PLAYER_ENTERING_WORLD", function() charKey = nil end)

local function NewSkill() return { last = 0, sinceUp = 0, history = {} } end

function ns.SkillData()
  local key = CharKey()
  local s = ns.db.skills[key]
  if not s then
    s = NewSkill()
    -- Take over the old account-wide table once (first character after the update).
    local old = ns.db.skill
    if type(old) == "table" and type(old.history) == "table" then
      s.last, s.sinceUp, s.history = old.last or 0, old.sinceUp or 0, old.history
    end
    ns.db.skill = nil
    ns.db.skills[key] = s
  end
  return s
end

function ns.ResetSkillData()
  wipe(ns.db.skills)
  ns.db.skill = nil
end

function ns.SaveSession()
  if session.casts == 0 and next(session.items) == nil then ns.db.lastSession = nil return end
  local saved = { char = CharKey(), at = ServerNow(), items = {} }
  for _, k in ipairs(SESSION_FIELDS) do saved[k] = session[k] end
  for id, n in pairs(session.items) do saved.items[id] = n end
  ns.db.lastSession = saved
end

-- Returns true when a saved session was taken over.
function ns.RestoreSession()
  local saved = ns.db.lastSession
  ns.db.lastSession = nil
  if type(saved) ~= "table" or saved.char ~= CharKey() then return false end
  local at = tonumber(saved.at)
  local age = at and ServerNow() - at
  if not age or age < 0 or age > SESSION_KEEP then return false end
  -- Only sessions started before the reload count; one already running stays.
  if session.casts > 0 then return false end
  for _, k in ipairs(SESSION_FIELDS) do
    local v = tonumber(saved[k])
    if v and v == v and v >= 0 then session[k] = v end
  end
  if type(saved.items) == "table" then
    for id, n in pairs(saved.items) do
      id, n = tonumber(id), tonumber(n)
      if id and n and n > 0 then session.items[id] = n end
    end
  end
  -- The restored progress is the starting point of the goal (no alert for it).
  if ns.ResetGoalBaseline then ns.ResetGoalBaseline() end
  return true
end

ns.On("PLAYER_LOGOUT", function() ns.SaveSession() end)
local restoreTried
ns.On("PLAYER_ENTERING_WORLD", function()
  if restoreTried then return end
  restoreTried = true
  if ns.RestoreSession() then ns.NoteEvent("session-restored", ("casts %d"):format(session.casts)) end
end)

local function CheckSkill()
  local rank = ns.GetSkill()
  local s = ns.SkillData()
  if rank > 0 and s.last > 0 and rank > s.last then
    -- Only a single point with casts behind it is a sample. A jump of several points (fished
    -- without the addon, skill raised elsewhere) or a point without casts would skew the average.
    if rank - s.last == 1 and s.sinceUp > 0 then
      table.insert(s.history, s.sinceUp)
      while #s.history > 20 do table.remove(s.history, 1) end
      -- (1.0.1) account wide by skill step: skill points and their casts (Share.lua)
      if type(ns.db.tempo) ~= "table" then ns.db.tempo = {} end
      local step = math.floor(s.last / 25) * 25
      local t = ns.db.tempo[step]
      if type(t) ~= "table" then t = { p = 0, c = 0 } ns.db.tempo[step] = t end
      t.p, t.c = (tonumber(t.p) or 0) + 1, (tonumber(t.c) or 0) + s.sinceUp
    end
    s.sinceUp = 0
  end
  if rank > 0 then s.last = rank end
end

function ns.CastsPerPoint()
  local h = ns.SkillData().history
  if #h == 0 then return nil end
  local sum = 0
  for _, n in ipairs(h) do sum = sum + n end
  return sum / #h
end

-- Estimates need a few skill-ups behind them; with fewer the panel shows none.
ns.SKILL_ESTIMATE_MIN_SAMPLES = 3

-- Casts still needed to reach the next zone tier, the next camp object and the skill cap,
-- from the recorded casts per skill point: { {kind, skill, casts}, ... } in ascending skill.
-- Empty without enough samples or at the cap. Targets above the current cap are left out
-- (the next rank has to be trained first).
function ns.SkillUpEstimates(rank, maxRank)
  local list = {}
  local h = ns.SkillData().history
  rank, maxRank = rank or 0, maxRank or 0
  -- (1.0.1) too few own samples: casts per point other players needed at this skill
  local avg
  if #h >= ns.SKILL_ESTIMATE_MIN_SAMPLES then
    avg = ns.CastsPerPoint()
  elseif ns.SharedCastsPerPoint then
    avg = ns.SharedCastsPerPoint(rank)
  end
  if not avg then return list end
  if rank <= 0 or maxRank <= 0 or rank >= maxRank then return list end
  local sinceUp = ns.SkillData().sinceUp or 0
  local function Add(kind, skill)
    if not skill or skill <= rank or skill > maxRank then return end
    for _, e in ipairs(list) do if e.skill == skill then return end end
    local casts = math.ceil((skill - rank) * avg - sinceUp)
    list[#list + 1] = { kind = kind, skill = skill, casts = math.max(casts, 1) }
  end
  local tier
  for _, need in pairs(ns.ZONE_SKILL) do
    if need > rank and (not tier or need < tier) then tier = need end
  end
  Add("zone", tier)
  Add("camp", select(2, ns.NextCampUnlock(rank)))
  Add("max", maxRank)
  table.sort(list, function(a, b) return a.skill < b.skill end)
  return list
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if not ns.IsFishingSpell(spellID) then return end
  Touch()
  session.casts = session.casts + 1
  ns.db.lifetime.casts = ns.db.lifetime.casts + 1
  -- Casts at the skill cap bring no skill-up: counting them would add all of them to the
  -- first point after training the next rank and skew "casts per skill point".
  local sk = ns.SkillData()
  local rank, maxRank = ns.GetSkill()
  if maxRank <= 0 or rank < maxRank then sk.sinceUp = sk.sinceUp + 1 end
  local z, mapID = Zone()
  castMap = mapID
  if z then z.casts = z.casts + 1 end
  -- (1.0.1) casts and getaways by total skill (25 point steps): which skill a zone needs,
  -- also where no value is published (shared with guild and group, Share.lua)
  castBucket = nil
  local _, _, modifier = ns.GetSkill()
  local total = (tonumber(rank) or 0) + (tonumber(modifier) or 0)
  if z and total > 0 then
    castBucket = math.floor(total / 25) * 25
    if type(z.byskill) ~= "table" then z.byskill = {} end
    local b = z.byskill[castBucket]
    if type(b) ~= "table" then b = { c = 0, g = 0 } z.byskill[castBucket] = b end
    b.c = (tonumber(b.c) or 0) + 1
  end

  if ns.db.lureWarning and ns.GetLure() == false then
    ns.Warn(L["Your fishing pole has no lure."])
  end
  if ns.db.bagWarning then
    local free = ns.FreeBagSlots()
    if free and free == 0 then
      ns.Warn(L["Your bags are full!"])
    elseif free and free <= BAGS_LOW then
      ns.Warn(L["Only %d free bag slots left."]:format(free))
    end
  end
end)

ns.On("UI_ERROR_MESSAGE", function(_, _, message)
  if not ns.Usable(message) then return end
  if ERR_FISH_ESCAPED and message == ERR_FISH_ESCAPED then
    Touch()
    session.getaways = session.getaways + 1
    ns.db.lifetime.getaways = ns.db.lifetime.getaways + 1
    local z = Zone(castMap)
    if z then z.getaways = z.getaways + 1 end
    local b = z and castBucket and type(z.byskill) == "table" and z.byskill[castBucket]
    if type(b) == "table" then b.g = (tonumber(b.g) or 0) + 1 end
    if ns.LogGetaway then ns.LogGetaway() end -- ends the catch log's streak
    ns.NoteEvent("got-away")
  elseif ERR_FISH_NOT_HOOKED and message == ERR_FISH_NOT_HOOKED then
    session.missed = session.missed + 1
    ns.NoteEvent("not-hooked")
  end
end)

---------------------------------------------------------------------------
-- Catches
-- Auto loot (Blizzard's or another addon's fast loot) can empty the loot window
-- before we read it, so items are counted from the loot chat messages
-- ("You receive loot: ...") right after a fishing cast ends. A snapshot of the
-- loot window is only the fallback if no chat message arrives.
---------------------------------------------------------------------------
local LOOT_WINDOW = 4    -- seconds after the line comes in in which loot counts as a catch
local LOOT_LATE = 1      -- after the loot window closed: chat messages may still arrive
local lootUntil = 0
-- Fishing loot window is open. Without auto loot the player takes the items one by one,
-- possibly long after LOOT_WINDOW: their chat messages still belong to this catch.
local lootOpen = false
local catch = nil        -- current catch: { counted = bool, snapshot = {...} }

local function Debug(msg)
  if ns.debug then ns.Print("|cff999999[debug]|r " .. msg) end
end

---------------------------------------------------------------------------
-- Rare catch alert and catch goal
---------------------------------------------------------------------------
local QUALITY_NAMES = { [2] = "uncommon", [3] = "rare", [4] = "epic" }
local QUALITY_LABELS = { [2] = L["Uncommon"], [3] = L["Rare"], [4] = L["Epic"], [5] = L["Legendary"] }

-- Chat line and sound for a catch from the chosen quality on (junk and common fish never).
local function RareAlert(id, quality, link)
  if not ns.db.rareAlert or type(quality) ~= "number" then return end
  local from = tonumber(ns.db.rareQuality) or 3
  if from < 2 then from = 2 end
  if quality < from then return end
  local name = link
  if not (type(name) == "string" and ns.Usable(name)) then
    local itemName, itemLink = ns.GetItemInfo(id)
    name = itemLink or itemName or ("item:" .. id)
  end
  ns.Report(L["Rare catch"], name, QUALITY_LABELS[quality])
  ns.PlayAlert("rare")
  ns.NoteEvent("rare", ("item:%d q%d"):format(id, quality))
end
ns.QUALITY_NAMES = QUALITY_NAMES

-- Goal: number of fish this session (junk not counted), or a number of one item in the bags
-- (e.g. for a recipe or a quest). Returns progress, goal, itemID (nil itemID = session fish);
-- nil when no goal is set.
function ns.GoalProgress()
  local goal = math.floor((tonumber(ns.db.goalCount) or 0) + 0.5) -- the slider may give 24.999
  if goal <= 0 then return nil end
  local item = tonumber(ns.db.goalItem) or 0
  if item > 0 then return ns.ItemCount(item) or 0, goal, item end
  return math.max(0, session.fish - session.junk), goal, nil
end

-- Progress at the last check. The alert only comes when a catch crosses the goal, not when the
-- bags load after login or the goal is set below what the bags already hold.
local goalLast
local goalWatchUntil = 0 -- item goals: the bag count follows the catch a moment later
local GOAL_WATCH = 3

function ns.CheckGoal(allowAlert)
  local progress, goal, item = ns.GoalProgress()
  if not progress then goalLast = nil return end
  if allowAlert and goalLast and goalLast < goal and progress >= goal then
    local what
    if item then
      local name, link = ns.GetItemInfo(item)
      what = ("%d x %s"):format(goal, link or name or ("item:" .. item))
    else
      what = L["%d fish"]:format(goal)
    end
    ns.Report(L["Goal reached"], what, L["after %d casts"]:format(session.casts))
    ns.Warn(L["Goal reached: %s"]:format(what))
    ns.PlayAlert("goal")
  end
  goalLast = progress
end

-- New goal or new session: the current progress is the starting point.
function ns.ResetGoalBaseline()
  goalLast = nil
  goalWatchUntil = 0
  ns.CheckGoal(false)
end

ns.On("BAG_UPDATE_DELAYED", function()
  ns.CheckGoal(GetTime() <= goalWatchUntil)
end)
ns.OnInit(function() ns.ResetGoalBaseline() end)

-- /ld goal: count and optional item (link or ID). count 0 switches the goal off.
function ns.SetGoal(count, item)
  -- 1.17: at most 99999 (no absurd goals from a typo), never NaN.
  count = tonumber(count) or 0
  if count ~= count then count = 0 end
  ns.db.goalCount = math.min(99999, math.max(0, math.floor(count)))
  ns.db.goalItem = item or 0
  ns.ResetGoalBaseline()
end

-- source: "chat" or "snapshot" (for /ld diag)
local function RecordItem(c, id, quantity, quality, source, link)
  if not id then return end
  quantity = quantity or 1
  if not (ns.Usable(quality) and type(quality) == "number") then quality = nil end
  if not (ns.Usable(quantity) and type(quantity) == "number") then quantity = 1 end
  local z, zoneMap = Zone(c and c.mapID)
  local newCatch = false
  if c and not c.counted then
    c.counted = true
    newCatch = true
    session.catches = session.catches + 1
    if z then z.catches = z.catches + 1 end
  end
  Touch()
  session.items[id] = (session.items[id] or 0) + quantity
  session.fish = session.fish + quantity
  ns.db.lifetime.fish = ns.db.lifetime.fish + quantity
  ns.db.catches[id] = (ns.db.catches[id] or 0) + quantity
  if z then z.fish[id] = (z.fish[id] or 0) + quantity end
  if quality == nil then
    local _, _, q = ns.GetItemInfo(id)
    if ns.Usable(q) and type(q) == "number" then quality = q end
  end
  if quality == 0 then
    session.junk = session.junk + quantity
    if z then z.junk = z.junk + quantity end
  end
  ns.NoteEvent(source or "loot", ("item:%d x%d q%s"):format(id, quantity, tostring(quality)))
  Debug(("+%d item:%d"):format(quantity, id))
  -- 1.17: catch log (item ID, count, zone, quality only; protected, a failure never stops the catch).
  if ns.LogCatch then ns.Call("catch log", ns.LogCatch, id, quantity, zoneMap, quality, newCatch) end
  ns.Call("rare alert", RareAlert, id, quality, link)
  goalWatchUntil = GetTime() + GOAL_WATCH
  ns.CheckGoal(true)
end

-- newCatch: the line came in, so earlier loot belongs to the previous catch.
-- LOOT_READY keeps the current catch, even if chat messages already counted it
-- (they can arrive before LOOT_READY; a new catch would count the snapshot twice).
local function OpenCatch(reason, newCatch)
  lootUntil = GetTime() + LOOT_WINDOW
  if not catch or catch.closed or (newCatch and catch.counted) then
    catch = { counted = false, snapshot = {}, mapID = castMap }
  end
  Debug("catch window: " .. reason)
end

-- 1.15: a fish that got away brings no loot. Its catch window is closed, so loot from a mob
-- killed right afterwards does not count as a catch. The getaway message may come just before
-- or just after the line comes in.
local ESCAPE_GAP = 1
local escapedAt = -math.huge
ns.On("UI_ERROR_MESSAGE", function(_, _, message)
  if not (ns.Usable(message) and ERR_FISH_ESCAPED and message == ERR_FISH_ESCAPED) then return end
  escapedAt = GetTime()
  if catch and not catch.counted and not lootOpen then
    catch.closed = true
    lootUntil = 0
  end
end)

-- The line comes in (bobber clicked, fish got away or cast cancelled).
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  if ns.IsFishingSpell(spellID) then
    if GetTime() - escapedAt > ESCAPE_GAP then OpenCatch("channel stop", true) end
    ns.NoteEvent("line-in")
  end
end)

-- 1.15: a loot window that never reported LOOT_CLOSED (loading screen) must not keep the catch
-- open; every later loot line would count as a catch. A new cast or a loading screen ends it.
local function EndLootWindow()
  lootOpen = false
end
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if lootOpen and ns.IsFishingSpell(spellID) then EndLootWindow() end
end)
ns.On("PLAYER_LEAVING_WORLD", EndLootWindow)

local function IsFishing()
  if IsFishingLoot and IsFishingLoot() then return true end
  return GetTime() <= lootUntil
end

-- Snapshot the loot window as fallback (it may already be empty with fast loot).
ns.On("LOOT_READY", function()
  local fishing = IsFishing()
  local count = GetNumLootItems and GetNumLootItems() or 0
  if not (ns.Usable(count) and type(count) == "number") then count = 0 end
  Debug(("LOOT_READY fishing=%s items=%d"):format(tostring(fishing), count))
  if not fishing then return end
  ns.NoteEvent("loot-ready", ("slots %d"):format(count))
  OpenCatch("loot ready")
  lootOpen = true
  -- LOOT_READY can fire more than once per loot: replace the snapshot, never append.
  -- A later, already emptied window (fast loot) keeps the earlier snapshot.
  local snapshot = {}
  for i = 1, count do
    local link = GetLootSlotLink(i)
    if not (ns.Usable(link) and type(link) == "string") then
      -- 1.17: a secret link cannot be read; the catch log counts the skip (type() is safe on secrets).
      if type(link) ~= "nil" and ns.LogSkip then ns.LogSkip("secret") end
      link = nil
    end
    local _, _, quantity, _, quality = GetLootSlotInfo(i)
    local id = ns.ItemID(link)
    if id then snapshot[#snapshot + 1] = { id = id, quantity = quantity or 1, quality = quality, link = link } end
  end
  if #snapshot > 0 then catch.snapshot = snapshot end
end)

-- Chat: "You receive loot: [item]x2." / "You receive loot: [item]."
local patterns
local function LootPatterns()
  if patterns then return patterns end
  patterns = {}
  for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF" }) do
    local fmt = _G[key]
    if type(fmt) == "string" then
      patterns[#patterns + 1] = "^" .. ns.FormatToPattern(fmt) .. "$"
    end
  end
  return patterns
end

-- Grey item links (|cff9d9d9d, or the quality tag |cnIQ0: of newer clients) are
-- junk, even if the item is not cached yet.
-- Uncommon, rare and epic link colours serve the rare catch alert for items not cached yet.
local POOR_COLOR = "|cff9d9d9d"
local LINK_COLORS = { ["|cff1eff00"] = 2, ["|cff0070dd"] = 3, ["|cffa335ee"] = 4 }
local function LinkQuality(link)
  if link:find(POOR_COLOR, 1, true) then return 0 end
  local q = link:match("|cnIQ(%d+):")
  if q then return tonumber(q) end
  local color = link:match("^(|cff%x%x%x%x%x%x)")
  return color and LINK_COLORS[color:lower()] or nil
end

function ns.ParseLootMessage(msg)
  for _, pattern in ipairs(LootPatterns()) do
    local link, count = msg:match(pattern)
    if link then
      local id = ns.ItemID(link)
      if id then
        return id, tonumber(count) or 1, LinkQuality(link), link
      end
    end
  end
end

ns.On("CHAT_MSG_LOOT", function(_, msg)
  -- A closed catch was already settled (possibly from the snapshot): late messages must not count twice.
  if not catch or catch.closed then return end
  if not lootOpen and GetTime() > lootUntil then return end
  -- 1.17: during a catch window an unreadable line is skipped and counted (/ld diag); so is a non-text one.
  if not (ns.Usable(msg) and type(msg) == "string") then
    if ns.LogSkip then ns.LogSkip("secret") end
    return
  end
  local id, quantity, quality, link = ns.ParseLootMessage(msg)
  Debug(("CHAT_MSG_LOOT parsed=%s"):format(tostring(id)))
  if id then RecordItem(catch, id, quantity, quality, "chat", link) end
end)

ns.On("LOOT_CLOSED", function()
  local current = catch
  if lootOpen then
    lootOpen = false
    lootUntil = math.max(lootUntil, GetTime() + LOOT_LATE)
  end
  if not current then return end
  -- Chat messages can arrive just after the window closes; then fall back to the snapshot.
  C_Timer.After(1, ns.Safe("loot closed", function()
    if not current.counted and #current.snapshot > 0 then
      Debug("using loot snapshot")
      for _, e in ipairs(current.snapshot) do RecordItem(current, e.id, e.quantity, e.quality, "snapshot", e.link) end
    end
    current.closed = true
  end))
end)

function ns.ToggleDebug()
  ns.debug = not ns.debug
  ns.Print("debug " .. (ns.debug and "on" or "off"))
end

ns.On("CHAT_MSG_SKILL", function() C_Timer.After(0.5, ns.Safe("skill", CheckSkill)) end)
ns.On("SKILL_LINES_CHANGED", CheckSkill)
ns.On("PLAYER_ENTERING_WORLD", CheckSkill)

---------------------------------------------------------------------------
-- Derived numbers for the panel
---------------------------------------------------------------------------
function ns.SessionValue()
  local total = 0
  for id, n in pairs(session.items) do
    total = total + (ns.GetSellPrice(id) or 0) * n
  end
  return total
end

---------------------------------------------------------------------------
-- (1.0) Auction prices (optional). Only Auctionator's public price function is
-- used; without Auctionator, without a scan or without a price for an item
-- everything stays as it was. Every call is protected and the answer checked.
---------------------------------------------------------------------------
local AH_CALLER = "Luredon"
local AH_CACHE_SECONDS = 5
local ahCache, ahCacheAt = {}, 0

local function AuctionatorAPI()
  local a = _G.Auctionator
  local v1 = type(a) == "table" and type(a.API) == "table" and a.API.v1
  if type(v1) == "table" and type(v1.GetAuctionPriceByItemID) == "function" then return v1 end
end

function ns.AuctionatorLoaded() return AuctionatorAPI() ~= nil end
function ns.AuctionPricesOn() return ns.db.auctionPrices and ns.AuctionatorLoaded() and true or false end

-- Copper per piece, or nil (no Auctionator, no scan, no price, unreadable answer).
-- Second result: "error" when the call failed.
function ns.AuctionPrice(itemID)
  local api = AuctionatorAPI()
  if not api or type(itemID) ~= "number" then return nil end
  local now = GetTime and GetTime() or 0
  if now - ahCacheAt > AH_CACHE_SECONDS then ahCache, ahCacheAt = {}, now end
  local hit = ahCache[itemID]
  if hit ~= nil then return hit or nil end
  local ok, price = pcall(api.GetAuctionPriceByItemID, AH_CALLER, itemID)
  if not ok then ahCache[itemID] = false return nil, "error" end
  if type(price) == "number" and ns.Usable(price) and price == price and price > 0 and price < math.huge then
    price = math.floor(price)
  else
    price = nil
  end
  ahCache[itemID] = price or false
  return price
end

-- Value of the session at auction prices: total of the items that have a price,
-- how many pieces had one, how many had none (poor items cannot be sold at the
-- auction house and are not counted as missing).
function ns.SessionValueAH()
  local total, priced, missing = 0, 0, 0
  for id, n in pairs(session.items) do
    local price = ns.AuctionPrice(id)
    if price then
      total, priced = total + price * n, priced + n
    else
      local q = ns.ItemQuality(id)
      if q == nil or q > 0 then missing = missing + n end
    end
  end
  return total, priced, missing
end

function ns.PerHour(value)
  if session.active < 60 then return nil end
  return value / (session.active / 3600)
end

-- Top catches in a zone: { {id, count, share}, ... }
function ns.ZoneTopCatches(mapID, limit)
  local z = ns.db.zones[mapID]
  if not z then return {} end
  local list, total = {}, 0
  for id, n in pairs(z.fish) do
    list[#list + 1] = { id = id, count = n }
    total = total + n
  end
  table.sort(list, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.id < b.id end)
  for i = #list, (limit or 5) + 1, -1 do list[i] = nil end
  for _, e in ipairs(list) do e.share = total > 0 and e.count / total or 0 end
  return list
end

-- Item quality (0 poor, 1 common, 2 uncommon, ...) or nil while the item is not cached.
-- C_Item.GetItemQualityByID is guarded: it may be missing or error on unknown IDs.
function ns.ItemQuality(id)
  local _, _, quality = ns.GetItemInfo(id)
  if ns.Usable(quality) and type(quality) == "number" then return quality end
  if C_Item and C_Item.GetItemQualityByID then
    local ok, q = pcall(C_Item.GetItemQualityByID, id)
    if ok and ns.Usable(q) and type(q) == "number" then return q end
  end
end

-- Catches from uncommon quality on count as rare (camp fish, pets, chests).
ns.RARE_QUALITY = 2

-- Top catches of this session: { {id, count}, ... }
function ns.SessionTopCatches(limit)
  local list = {}
  for id, n in pairs(session.items) do list[#list + 1] = { id = id, count = n } end
  table.sort(list, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.id < b.id end)
  for i = #list, (limit or 10) + 1, -1 do list[i] = nil end
  return list
end

---------------------------------------------------------------------------
-- Session summary in chat when the pole goes back into the bags
---------------------------------------------------------------------------
-- Returns the main text and the details (value, fish per hour) for ns.Report.
function ns.SessionSummaryText()
  local s = session
  local text = L["%d casts, %d catches, %d got away"]:format(s.casts, s.catches, s.getaways)
  local detail = L["value %s"]:format(ns.Money(ns.SessionValue()))
  if ns.AuctionPricesOn() then
    local ah, priced = ns.SessionValueAH()
    if priced > 0 then detail = detail .. ", " .. L["auction %s"]:format(ns.Money(ah)) end
  end
  local fishH = ns.PerHour(s.fish)
  if fishH then detail = detail .. ", " .. L["%d fish/h"]:format(fishH) end
  return text, detail
end

local hadPole
ns.On("PLAYER_ENTERING_WORLD", function() hadPole = ns.HasPole() end)
ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
  if slot ~= (INVSLOT_MAINHAND or 16) then return end
  local has = ns.HasPole()
  -- Only once per stretch of fishing: nothing new since the last summary, no summary.
  if hadPole and not has and ns.db.sessionSummary and session.casts > session.reported then
    session.reported = session.casts
    ns.Report(L["Session"], ns.SessionSummaryText())
  end
  hadPole = has
end)

---------------------------------------------------------------------------
-- Export: catches per zone as plain text (no character or realm names)
---------------------------------------------------------------------------
local function SortedKeys(t)
  local keys = {}
  for k in pairs(t) do if type(k) == "number" then keys[#keys + 1] = k end end
  table.sort(keys)
  return keys
end

function ns.ExportText()
  local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Luredon", "Version")
  local build, _, _, toc
  if GetBuildInfo then build, _, _, toc = GetBuildInfo() end
  local out = {
    "# Luredon catch export, format 1",
    ("# addon %s, client %s (%s), locale %s"):format(tostring(version or "?"), tostring(build or "?"),
      tostring(toc or "?"), tostring(GetLocale and GetLocale() or "?")),
    "# zone;mapID;casts;catches;getaways;junk",
    "# fish;mapID;itemID;count",
  }
  for _, mapID in ipairs(SortedKeys(ns.db.zones)) do
    local z = ns.db.zones[mapID]
    if (z.casts or 0) > 0 or next(z.fish or {}) then
      out[#out + 1] = ("zone;%d;%d;%d;%d;%d"):format(mapID, z.casts or 0, z.catches or 0, z.getaways or 0, z.junk or 0)
      for _, id in ipairs(SortedKeys(z.fish or {})) do
        out[#out + 1] = ("fish;%d;%d;%d"):format(mapID, id, z.fish[id])
      end
    end
  end
  return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- 1.14: zones for your skill (/ld zones, options tool)
-- From Luredon's zone table (Wowhead fishing guide for Forever, see Data.lua): the highest tier
-- your total skill (base + lure + gear) reaches, where nothing gets away, and the next tier.
-- Zones without a published value (new Forever zones, Searing Gorge, Blasted Lands) are not listed.
---------------------------------------------------------------------------
-- Returns the tier reached (nil below the lowest) and the next tier (nil above the highest).
function ns.ZoneTiers(total)
  total = tonumber(total) or 0
  local reached, nextTier
  for _, need in pairs(ns.ZONE_SKILL) do
    if need <= total then
      if not reached or need > reached then reached = need end
    elseif not nextTier or need < nextTier then
      nextTier = need
    end
  end
  return reached, nextTier
end

-- Zones of one tier as display names, sorted. A zone with parts that need more than total
-- gets that value in brackets.
function ns.ZoneNamesOfTier(tier, total)
  local list = {}
  for mapID, need in pairs(ns.ZONE_SKILL) do
    if need == tier then
      local name = ns.MapName(mapID) or ("map " .. mapID)
      local parts = ns.ZONE_SKILL_PARTS[mapID]
      if parts and parts > (total or 0) then name = name .. " (" .. L["parts %d"]:format(parts) .. ")" end
      list[#list + 1] = name
    end
  end
  table.sort(list)
  return list
end

-- Chat lines (without the heading) for the current skill; nil when Fishing is not learned.
function ns.BestZonesLines()
  if not ns.KnowsFishing() then return nil end
  local rank, _, modifier = ns.GetSkill()
  local total = rank + modifier
  local reached, nextTier = ns.ZoneTiers(total)
  local lines = {}
  if reached then
    lines[#lines + 1] = L["Highest tier without getaways (%d): %s"]:format(reached,
      table.concat(ns.ZoneNamesOfTier(reached, total), ", "))
  else
    lines[#lines + 1] = L["Below %d fish get away everywhere; a lure helps."]:format(nextTier or 0)
  end
  if nextTier then
    lines[#lines + 1] = L["Next tier %d (%d more): %s"]:format(nextTier, nextTier - total,
      table.concat(ns.ZoneNamesOfTier(nextTier, total), ", "))
  else
    lines[#lines + 1] = L["Nothing gets away in any listed zone."]
  end
  return lines, total
end

function ns.PrintBestZones()
  local lines, total = ns.BestZonesLines()
  if not lines then ns.Print(L["Fishing not learned yet. Visit a fishing trainer."]) return end
  ns.Report(L["Zones for your skill"], L["skill %d incl. lure and gear"]:format(total))
  for _, line in ipairs(lines) do ns.Print(line) end
end

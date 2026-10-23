local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (1.0.1) Sharing fishing data with guild and group.
--
-- Every Luredon sends only its OWN totals (account wide, no names):
--   C <map> <casts>                     casts in a zone
--   Z <map> <item> <count>              catches of one item in a zone
--   E <map> <step> <casts> <getaways>   casts and getaways at a total skill
--                                       (base + lure + gear) of step..step+24
--   P <step> <points> <casts>           skill points gained at step..step+24
--                                       and the casts they took
-- message "D2:<seq>:<account token>:<line>;<line>;..." (at most MAX_MSG characters), prefix LdShare
-- ("D1:<seq>:..." from Luredon before 1.1 is still read).
--
-- Others keep the latest totals per reporter (QuestdonDB-like table
-- LuredonDB.shared: [key] = { r = { [reporter] = value }, t }) and add them up
-- over reporters. Nothing is passed on, so reporters are real players.
-- Reporters are a 24 bit checksum of "Name-Realm" (to count them), never shown
-- or exported. Used: zone catch table when you have no catches there yet, the
-- skill a zone needs when no value is published (two or more reporters), and
-- casts per skill point when you have too few samples yourself.
-- Sending: option shareData (on), guild and group (not to the group when all
-- members are guild mates), at most MAX_PER_FLUSH messages every FLUSH_GAP
-- seconds and MAX_PER_HOUR per hour, never in a chat lockdown or combat. A
-- total is sent again once it grew by a quarter and by at least 10.
---------------------------------------------------------------------------
local PREFIX = "LdShare"
local FLUSH_GAP = 300        -- seconds between two sends (totals grow steadily while fishing)
local MAX_PER_FLUSH = 5
local MAX_PER_HOUR = 12      -- messages per hour
local MAX_MSG = 240
local MAX_SHARED = 5000      -- keys kept
local MAX_REPORTERS = 30     -- reporters kept per key
local PER_SENDER = 300       -- lines per sender and hour
local CONFIRM = 2            -- reporters needed for the zone skill and the tempo
local MIN_CASTS = 50         -- casts behind a zone skill estimate

local stats = { sentMsgs = 0, sentLines = 0, recvMsgs = 0, recvLines = 0, bad = 0, own = 0, limited = 0, blocked = 0 }
ns.shareStats = stats
local registered = false
local seq = 0
local senders = {}

local function Usable(v) return v ~= nil and ns.Usable(v) end
local function Value(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if ok and Usable(v) then return v end
end
local function True(v) return v ~= nil and Usable(v) and v == true end
local function Now() local t = Value(GetTime) return type(t) == "number" and t or 0 end

local function DB()
  local db = ns.db
  if type(db.shared) ~= "table" then db.shared = {} end
  if type(db.shareSent) ~= "table" then db.shareSent = {} end
  if db.sharedVersion ~= 2 then -- (1.1) see the account token below: start clean once
    wipe(db.shared)
    db.sharedVersion = 2
  end
  return db
end

-- (1.1) Account token: 8 hex digits, made once per account and kept in the
-- saved data. Messages carry it ("D2:<seq>:<token>:..."), so one account
-- counts as ONE reporter whatever character sends, and the own echo is
-- recognised even when the client spells the own name differently (Questdon's
-- group test 04.10.: the own echo counted as a second player). A sender name
-- may use one token per session; older clients send "D1" (reporter = name).
local tokenOf = {}
local function MyToken()
  local db = DB()
  local t = db.shareToken
  if type(t) ~= "string" or not t:match("^%x%x%x%x%x%x%x%x$") then
    t = ("%04x%04x"):format(math.random(0, 65535), math.random(0, 65535))
    db.shareToken = t
  end
  return t
end


local function Locked()
  local fn = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
  if type(fn) ~= "function" then return false end
  local ok, v = pcall(fn)
  if not ok or v == nil then return false end
  return not ns.Usable(v) or v == true
end

local function Hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 16777216 end
  return ("%06x"):format(h)
end

local myName
local function MyFullName()
  if myName then return myName end
  local name, realm
  if type(UnitFullName) == "function" then
    local ok, n, r = pcall(UnitFullName, "player")
    if ok then name, realm = n, r end
  end
  if not (type(name) == "string" and Usable(name)) then return nil end
  if not (type(realm) == "string" and Usable(realm) and realm ~= "") then
    realm = Value(GetNormalizedRealmName) or Value(GetRealmName)
    realm = type(realm) == "string" and realm:gsub("%s", "") or nil
  end
  if realm and realm ~= "" then myName = name .. "-" .. realm end
  return myName or name
end

local function FullSender(sender)
  if type(sender) ~= "string" or not Usable(sender) or sender == "" then return nil end
  if sender:find("-", 1, true) then return sender end
  local me = MyFullName()
  local realm = me and me:match("%-(.+)$")
  return realm and (sender .. "-" .. realm) or sender
end

---------------------------------------------------------------------------
-- Lines
---------------------------------------------------------------------------
local function Int(v, hi) v = tonumber(v) return v and v >= 0 and v < hi and v == math.floor(v) and v or nil end
local function Step(v) v = Int(v, 1000) return v and v % 25 == 0 and v or nil end

-- key, value (number or { a, b }), the number that decides a resend
local PARSE = {
  C = function(l)
    local m, c = l:match("^C (%d+) (%d+)$")
    if not (Int(m, 1e5) and Int(c, 1e7)) then return nil end
    return "C " .. m, tonumber(c), tonumber(c)
  end,
  Z = function(l)
    local m, item, n = l:match("^Z (%d+) (%d+) (%d+)$")
    if not (Int(m, 1e5) and Int(item, 1e7) and Int(n, 1e7) and tonumber(item) > 0) then return nil end
    return ("Z %s %s"):format(m, item), tonumber(n), tonumber(n)
  end,
  E = function(l)
    local m, st, c, g = l:match("^E (%d+) (%d+) (%d+) (%d+)$")
    if not (Int(m, 1e5) and Step(st) and Int(c, 1e7) and Int(g, 1e7) and tonumber(g) <= tonumber(c)) then return nil end
    return ("E %s %s"):format(m, st), { tonumber(c), tonumber(g) }, tonumber(c)
  end,
  P = function(l)
    local st, p, c = l:match("^P (%d+) (%d+) (%d+)$")
    if not (Step(st) and Int(p, 1e5) and Int(c, 1e7) and tonumber(p) > 0) then return nil end
    return "P " .. st, { tonumber(p), tonumber(c) }, tonumber(p)
  end,
}

function ns.ParseShareLine(line)
  if type(line) ~= "string" or #line > 60 then return nil end
  local p = PARSE[line:sub(1, 1)]
  if not p then return nil end
  return p(line)
end
local Parse = ns.ParseShareLine

-- Own totals as lines.
local function OwnLines()
  local lines = {}
  for mapID, z in pairs(ns.db.zones or {}) do
    if type(mapID) == "number" and type(z) == "table" then
      local casts = tonumber(z.casts) or 0
      if casts > 0 then lines[#lines + 1] = ("C %d %d"):format(mapID, casts) end
      for item, n in pairs(type(z.fish) == "table" and z.fish or {}) do
        n = tonumber(n)
        if type(item) == "number" and n and n > 0 then lines[#lines + 1] = ("Z %d %d %d"):format(mapID, item, n) end
      end
      for step, b in pairs(type(z.byskill) == "table" and z.byskill or {}) do
        local c, g = type(b) == "table" and tonumber(b.c) or 0, type(b) == "table" and tonumber(b.g) or 0
        if type(step) == "number" and c > 0 then lines[#lines + 1] = ("E %d %d %d %d"):format(mapID, step, c, math.min(g, c)) end
      end
    end
  end
  for step, t in pairs(type(ns.db.tempo) == "table" and ns.db.tempo or {}) do
    local p, c = type(t) == "table" and tonumber(t.p) or 0, type(t) == "table" and tonumber(t.c) or 0
    if type(step) == "number" and p > 0 then lines[#lines + 1] = ("P %d %d %d"):format(step, p, c) end
  end
  table.sort(lines)
  return lines
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local sharedCount
local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

local function Prune()
  local shared = DB().shared
  local list = {}
  for key, e in pairs(shared) do list[#list + 1] = { key = key, n = Count(type(e.r) == "table" and e.r or {}), t = tonumber(e.t) or 0 } end
  table.sort(list, function(a, b) if a.n ~= b.n then return a.n < b.n end return a.t < b.t end)
  for i = 1, math.max(#list - math.floor(MAX_SHARED * 0.9), 0) do shared[list[i].key] = nil end
  sharedCount = nil
end

local function Store(key, value, reporter)
  local shared = DB().shared
  local e = shared[key]
  if not e then
    sharedCount = sharedCount or Count(shared)
    if sharedCount >= MAX_SHARED then Prune() end
    e = { r = {} }
    shared[key] = e
    sharedCount = (sharedCount or 0) + 1
  end
  if e.r[reporter] == nil and Count(e.r) >= MAX_REPORTERS then return end
  e.r[reporter] = value -- the latest total of this player replaces the older one
  e.t = Now()
end

local function Allowed(reporter, n)
  local now = Now()
  local s = senders[reporter]
  if not s or now - s.t > 3600 then s = { t = now, n = 0 } senders[reporter] = s end
  if s.n >= PER_SENDER then return false end
  s.n = s.n + n
  return true
end

local function OnMessage(_, prefix, text, _, sender)
  if prefix ~= PREFIX then return end
  if type(text) ~= "string" or not Usable(text) or #text > 255 then return end
  local full = FullSender(sender)
  if not full then return end
  if full == MyFullName() then stats.own = stats.own + 1 return end
  local reporter
  local token, payload = text:match("^D2:%d+:(%x%x%x%x%x%x%x%x):(.+)$")
  if token then
    if token == MyToken() then stats.own = stats.own + 1 return end
    if tokenOf[full] and tokenOf[full] ~= token then stats.bad = stats.bad + 1 return end
    tokenOf[full] = token
    reporter = "a" .. token
  else
    payload = text:match("^D1:%d+:(.+)$") -- Luredon before 1.1
    reporter = Hash(full)
  end
  if not payload then stats.bad = stats.bad + 1 return end
  stats.recvMsgs = stats.recvMsgs + 1
  local lines = {}
  for line in payload:gmatch("[^;]+") do lines[#lines + 1] = line end
  if not Allowed(reporter, #lines) then stats.limited = stats.limited + #lines return end
  for _, line in ipairs(lines) do
    local key, value = Parse(line)
    if key then
      Store(key, value, reporter)
      stats.recvLines = stats.recvLines + 1
    else
      stats.bad = stats.bad + 1
    end
  end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
-- Everybody in the group is in the guild too: the guild message reaches them already.
local function GroupInGuild()
  if type(UnitIsInMyGuild) ~= "function" then return false end
  local raid = True(Value(IsInRaid))
  local n = tonumber(Value(GetNumGroupMembers)) or 0
  if n <= 1 then return false end
  for i = 1, raid and n or math.min(n - 1, 4) do
    local unit = (raid and "raid" or "party") .. i
    if True(Value(UnitExists, unit)) and not True(Value(UnitIsUnit, unit, "player")) and not True(Value(UnitIsInMyGuild, unit)) then
      return false
    end
  end
  return true
end

local function Channels()
  local list = {}
  local guild = True(Value(IsInGuild))
  if guild then list[#list + 1] = "GUILD" end
  if True(Value(IsInGroup)) and not (guild and GroupInGuild()) then
    local instance = LE_PARTY_CATEGORY_INSTANCE and True(Value(IsInGroup, LE_PARTY_CATEGORY_INSTANCE))
    list[#list + 1] = instance and "INSTANCE_CHAT" or (True(Value(IsInRaid)) and "RAID" or "PARTY")
  end
  return list
end

local sentTimes = {}
local function HourBudget()
  local now = Now()
  while sentTimes[1] and now - sentTimes[1] > 3600 do table.remove(sentTimes, 1) end
  return MAX_PER_HOUR - #sentTimes
end

local function Register()
  if registered then return true end
  if not (C_ChatInfo and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function") then return false end
  local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  registered = ok and (result == true or result == nil or result == 0 or result == 1) or false
  return registered
end

local function SendTo(msg, channels)
  local any = false
  for _, ch in ipairs(channels) do
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, ch)
    if ok and (result == nil or result == true or result == 0) then any = true else stats.blocked = stats.blocked + 1 end
  end
  return any
end

-- A total goes out again once it grew by a quarter, and by at least 10.
local function Due(last, now)
  if type(last) ~= "number" then return true end
  return now - last >= 10 and now >= last * 1.25
end

function ns.ShareFlush()
  if not (ns.db and ns.db.shareData) then return 0 end
  if not (C_ChatInfo and type(C_ChatInfo.SendAddonMessage) == "function") then return 0 end
  if Locked() or True(Value(InCombatLockdown)) then stats.blocked = stats.blocked + 1 return 0 end
  local channels = Channels()
  if #channels == 0 or not Register() then return 0 end
  local budget = math.min(MAX_PER_FLUSH, HourBudget())
  if budget <= 0 then return 0 end
  local sent = DB().shareSent
  local pending = {}
  for _, line in ipairs(OwnLines()) do
    local key, _, n = Parse(line)
    if key and Due(sent[key], n) then pending[#pending + 1] = { key, n, line } end
  end
  local msgs, i = 0, 1
  while i <= #pending and msgs < budget do
    seq = (seq + 1) % 1000
    local head = ("D2:%d:%s:"):format(seq, MyToken())
    local parts, used, size = {}, {}, #head
    while i <= #pending and size + #pending[i][3] + (#parts > 0 and 1 or 0) <= MAX_MSG do
      size = size + #pending[i][3] + (#parts > 0 and 1 or 0)
      parts[#parts + 1] = pending[i][3]
      used[#used + 1] = pending[i]
      i = i + 1
    end
    if #parts == 0 then
      i = i + 1
    elseif SendTo(head .. table.concat(parts, ";"), channels) then
      msgs = msgs + 1
      sentTimes[#sentTimes + 1] = Now()
      stats.sentMsgs = stats.sentMsgs + 1
      stats.sentLines = stats.sentLines + #used
      for _, p in ipairs(used) do sent[p[1]] = p[2] end
    else
      break
    end
  end
  return msgs
end

---------------------------------------------------------------------------
-- Using shared data
---------------------------------------------------------------------------
-- Catches others reported in a zone: list { {id, count, share} }, total, reporters.
function ns.SharedZoneCatches(mapID, limit)
  local shared = ns.db and ns.db.shared or {}
  local byItem, total, who = {}, 0, {}
  local prefix = "Z " .. tostring(mapID) .. " "
  for key, e in pairs(shared) do
    if type(key) == "string" and key:sub(1, #prefix) == prefix and type(e) == "table" and type(e.r) == "table" then
      local item = tonumber(key:sub(#prefix + 1))
      for r, n in pairs(e.r) do
        if item and type(n) == "number" then
          byItem[item] = (byItem[item] or 0) + n
          total = total + n
          who[r] = true
        end
      end
    end
  end
  local list = {}
  for id, n in pairs(byItem) do list[#list + 1] = { id = id, count = n, share = total > 0 and n / total or 0 } end
  table.sort(list, function(a, b) if a.count ~= b.count then return a.count > b.count end return a.id < b.id end)
  for k = #list, (limit or 8) + 1, -1 do list[k] = nil end
  return list, total, Count(who)
end

-- Skill a zone needs as others measured it: the lowest step from which on
-- nobody had a getaway, with MIN_CASTS casts and CONFIRM reporters behind it.
-- Returns need, reporters, casts (or nil).
function ns.SharedZoneSkill(mapID)
  local shared = ns.db and ns.db.shared or {}
  local steps = {}
  local prefix = "E " .. tostring(mapID) .. " "
  for key, e in pairs(shared) do
    if type(key) == "string" and key:sub(1, #prefix) == prefix and type(e) == "table" and type(e.r) == "table" then
      local step = tonumber(key:sub(#prefix + 1))
      if step then
        local s = steps[step] or { c = 0, g = 0, who = {} }
        steps[step] = s
        for r, v in pairs(e.r) do
          if type(v) == "table" and tonumber(v[1]) then
            s.c, s.g = s.c + v[1], s.g + (tonumber(v[2]) or 0)
            s.who[r] = true
          end
        end
      end
    end
  end
  local order = {}
  for step in pairs(steps) do order[#order + 1] = step end
  table.sort(order)
  -- walk down from the top: the clean steps above the highest step with a getaway
  local casts, who, need = 0, {}, nil
  for k = #order, 1, -1 do
    local s = steps[order[k]]
    if s.g > 0 then break end
    need = order[k]
    casts = casts + s.c
    for r in pairs(s.who) do who[r] = true end
  end
  local n = Count(who)
  if not need or casts < MIN_CASTS or n < CONFIRM then return nil end
  -- nobody fished below the clean steps: the zone may need less than that
  local lowestSeen = order[1] == need
  return need, n, casts, lowestSeen
end

-- Casts per skill point others needed at this skill (step of 25), with CONFIRM reporters.
function ns.SharedCastsPerPoint(rank)
  local e = ns.db and ns.db.shared and ns.db.shared["P " .. (math.floor((tonumber(rank) or 0) / 25) * 25)]
  if type(e) ~= "table" or type(e.r) ~= "table" then return nil end
  local p, c, n = 0, 0, 0
  for _, v in pairs(e.r) do
    if type(v) == "table" and tonumber(v[1]) and tonumber(v[2]) then p, c, n = p + v[1], c + v[2], n + 1 end
  end
  if n < CONFIRM or p <= 0 then return nil end
  return c / p, n
end

function ns.ShareDiag()
  local shared = ns.db and ns.db.shared or {}
  return ("sharing: %s, sent %d lines in %d messages, received %d lines in %d messages (bad %d, limited %d, own %d), blocked %d, shared keys %d"):format(
    ns.db and ns.db.shareData and "on" or "off", stats.sentLines, stats.sentMsgs, stats.recvLines, stats.recvMsgs,
    stats.bad, stats.limited, stats.own, stats.blocked, Count(shared))
end

function ns.ResetShared()
  local db = DB()
  wipe(db.shared)
  wipe(db.shareSent)
  sharedCount = 0
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.On("CHAT_MSG_ADDON", function(...) OnMessage(...) end)

local ticker
ns.OnInit(function()
  Register()
  if not ticker and C_Timer and type(C_Timer.NewTicker) == "function" then
    ticker = C_Timer.NewTicker(FLUSH_GAP, function() ns.Call("share", ns.ShareFlush) end)
  end
end)

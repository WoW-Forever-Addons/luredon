local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Camp objects (Fishing Rack / Fishing Hut) and Fish Bowl buff
---------------------------------------------------------------------------
local function Now() return GetServerTime and GetServerTime() or time() end

function ns.StartCampTimer(key)
  local c = ns.CAMP[key]
  if c then ns.db.camp[key] = Now() + c.seconds end
end

ns.OnPlayer("UNIT_SPELLCAST_SUCCEEDED", function(_, _, _, spellID)
  if not ns.Usable(spellID) then return end
  for key, c in pairs(ns.CAMP) do
    if spellID == c.spell then ns.StartCampTimer(key) end
  end
end)

-- Fish Bowl buff: seconds left or nil. Aura data can be secret in combat; then the time read
-- last stays in use (the row does not vanish and come back with every fight).
local bowlEnds -- GetTime() at which the buff ends, as read last
local function FishBowlLeft()
  local now = GetTime()
  local api = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  if api and not InCombatLockdown() then
    local ok, aura = pcall(api, ns.FISH_BOWL_AURA)
    if ok and aura == nil then
      bowlEnds = nil -- buff gone (or cancelled)
    elseif ok and ns.Usable(aura) and type(aura) == "table" then
      local ends = aura.expirationTime
      if ns.Usable(ends) and type(ends) == "number" and ends > 0 then bowlEnds = ends end
    end
  end
  if bowlEnds and bowlEnds > now then return bowlEnds - now end
  bowlEnds = nil
end

-- Returns { {label, secondsLeft}, ... }
function ns.CampTimers()
  local list = {}
  local now = Now()
  for _, key in ipairs({ "hut", "rack" }) do
    local ends = ns.db.camp[key]
    -- 1.17: a damaged value (no number) is dropped; it used to stop the whole window update.
    if ends ~= nil and not (type(ends) == "number" and ends == ends) then
      ns.db.camp[key] = nil
      ends = nil
    end
    if ends then
      if ends > now then
        list[#list + 1] = { label = L[ns.CAMP[key].label], left = ends - now }
      else
        ns.db.camp[key] = nil
      end
    end
  end
  local bowl = FishBowlLeft()
  if bowl then list[#list + 1] = { label = L["Fish Bowl buff"], left = bowl } end
  return list
end

---------------------------------------------------------------------------
-- Stranglethorn Fishing Extravaganza
---------------------------------------------------------------------------
-- Schedule: the classic one from Data.lua, or the one set with /ld derby (the Forever schedule
-- was not published before launch). Returns weekday (1 = Sunday), start hour, end hour, custom.
function ns.DerbySchedule()
  local d = ns.DERBY
  local day, hour = tonumber(ns.db.derbyDay) or 0, tonumber(ns.db.derbyHour)
  if day >= 1 and day <= 7 and hour and hour >= 0 and hour <= 23 then
    return day, hour, hour + d.hours, true
  end
  return d.weekday, d.startHour, d.endHour, false
end

-- Returns state ("running"/"upcoming"), seconds (left / until start)
function ns.DerbyState()
  if not (C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime) then return nil end
  local ok, t = pcall(C_DateAndTime.GetCurrentCalendarTime) -- realm time, weekday 1 = Sunday
  if not ok or type(t) ~= "table" then return nil end
  for _, key in ipairs({ "weekday", "hour", "minute" }) do
    if not (ns.Usable(t[key]) and type(t[key]) == "number") then return nil end
  end
  local weekday, startHour, endHour = ns.DerbySchedule()
  local nowMin = t.hour * 60 + t.minute
  -- Minutes since the start of this week's contest day (a contest may run past midnight).
  local sinceStart = ((t.weekday - weekday) % 7) * 1440 + nowMin - startHour * 60
  local length = (endHour - startHour) * 60
  if sinceStart >= 0 and sinceStart < length then
    return "running", (length - sinceStart) * 60
  end
  local untilStart = (7 * 1440 - sinceStart) % (7 * 1440)
  return "upcoming", untilStart * 60
end

-- Weekday names for /ld derby: the client's own day names (Blizzard's WEEKDAY_SUNDAY ..
-- WEEKDAY_SATURDAY, the start is enough when only one day begins like that), then English
-- (first two letters). German two-letter forms only in the German and English client, so
-- "do" means domingo in a Spanish or Portuguese client.
local DAYS_EN = { su = 1, mo = 2, tu = 3, we = 4, th = 5, fr = 6, sa = 7 }
local DAYS_DE = { so = 1, mo = 2, di = 3, mi = 4, ["do"] = 5, fr = 6, sa = 7 }
local WEEKDAY_GLOBALS = { "WEEKDAY_SUNDAY", "WEEKDAY_MONDAY", "WEEKDAY_TUESDAY", "WEEKDAY_WEDNESDAY",
  "WEEKDAY_THURSDAY", "WEEKDAY_FRIDAY", "WEEKDAY_SATURDAY" }
-- lower case incl. Cyrillic capitals (string.lower only knows ASCII): Воскресенье = воскресенье
local function Lower(s)
  s = s:lower()
  s = s:gsub("\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
  s = s:gsub("\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end)
  return (s:gsub("\208\129", "\209\145")) -- Ё
end
-- accents off (miércoles = miercoles, sábado = sabado, terça = terca)
local ACCENTS = { ["á"] = "a", ["à"] = "a", ["â"] = "a", ["ã"] = "a", ["é"] = "e", ["è"] = "e", ["ê"] = "e",
  ["í"] = "i", ["î"] = "i", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ú"] = "u", ["û"] = "u", ["ç"] = "c",
  ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ç"] = "c" }
local function Fold(s)
  return (s:gsub("[\195][\128-\191]", function(c) return ACCENTS[c] end))
end
-- short day names players type: Russian пн..вс, Chinese 日/一..六 (after 星期, 週, 周, 禮拜)
local SHORT = { ["вс"] = 1, ["пн"] = 2, ["вт"] = 3, ["ср"] = 4, ["чт"] = 5, ["пт"] = 6, ["сб"] = 7,
  ["日"] = 1, ["天"] = 1, ["一"] = 2, ["二"] = 3, ["三"] = 4, ["四"] = 5, ["五"] = 6, ["六"] = 7 }
local function ShortDay(text)
  for _, p in ipairs({ "星期", "週", "周", "禮拜" }) do
    if text:sub(1, #p) == p then text = text:sub(#p + 1) break end
  end
  return SHORT[text]
end
local function LocalDay(text)
  local short = ShortDay(text)
  if short then return short end
  text = Fold(text)
  if #text < 2 then return nil end
  local found
  for i, g in ipairs(WEEKDAY_GLOBALS) do
    local name = rawget(_G, g)
    if type(name) == "string" and name ~= "" then
      name = Fold(Lower(name))
      if name == text then return i end
      if name:sub(1, #text) == text then
        if found and found ~= i then return nil end -- two days start like that
        found = i
      end
    end
  end
  return found
end
function ns.ParseWeekday(text)
  text = Lower(tostring(text or ""))
  local n = tonumber(text)
  if n then return (n >= 1 and n <= 7) and math.floor(n) or nil end
  local day = LocalDay(text)
  if day then return day end
  local loc = type(GetLocale) == "function" and GetLocale() or "enUS"
  if loc == "deDE" or loc == "enUS" or loc == "enGB" then
    day = DAYS_DE[text:sub(1, 2)]
    if day and (loc == "deDE" or not DAYS_EN[text:sub(1, 2)]) then return day end
  end
  return DAYS_EN[text:sub(1, 2)]
end

-- Tastyfish alert: once per contest, when the bags hold the fish needed for the turn-in.
-- In Forever the first 50 players win, so every minute counts.
local derbyAlerted -- alerted in the contest that is running now
ns.On("BAG_UPDATE_DELAYED", function()
  if not ns.db.derby then return end
  local state, seconds = ns.DerbyState()
  if state ~= "running" then derbyAlerted = nil return end
  if derbyAlerted or ns.ItemCount(ns.DERBY.fish) < ns.DERBY.needed then return end
  derbyAlerted = true
  ns.Warn(L["%d Tastyfish: turn them in at Booty Bay now!"]:format(ns.DERBY.needed))
  ns.Report(L["Fishing Extravaganza"], L["%d Tastyfish: turn them in at Booty Bay now!"]:format(ns.DERBY.needed),
    L["%s left"]:format(ns.Duration(seconds)))
  ns.PlayAlert("derby")
end)

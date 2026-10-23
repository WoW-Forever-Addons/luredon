local _, ns = ...

local INVSLOT_MAIN = INVSLOT_MAINHAND or 16
local LAST_BAG = NUM_BAG_SLOTS or 4
local WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local POLE = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20

---------------------------------------------------------------------------
-- Spell
---------------------------------------------------------------------------
local fishingName
local fishingIDs = {}
for _, id in ipairs(ns.FISHING_SPELLS) do fishingIDs[id] = true end

-- Readable, non-empty text or nil (secret values never leave here).
local function Text(v)
  if ns.Usable(v) and type(v) == "string" and v ~= "" then return v end
end

-- Localized name of Fishing (any client language). Only a readable name is kept;
-- a secret or missing answer is asked again next time.
function ns.FishingSpellName()
  if not fishingName then
    local ok, name = pcall(ns.SpellName, ns.FISHING_SPELLS[1])
    fishingName = ok and Text(name) or nil
  end
  return fishingName
end

-- Forgets the cached name (test hook; the name never changes while the game runs).
function ns.ResetSpellNameCache() fishingName = nil end

-- 1.14: what the secure button casts. The name picks the highest known rank; without a
-- readable name the spell ID of the highest known rank (the secure button casts IDs as well).
function ns.FishingCastSpell()
  local name = ns.FishingSpellName()
  if name then return name end
  local isKnown = IsPlayerSpell or (C_SpellBook and C_SpellBook.IsSpellKnown)
  if isKnown then
    for i = #ns.FISHING_SPELLS, 1, -1 do
      local ok, known = pcall(isKnown, ns.FISHING_SPELLS[i])
      if ok and ns.Usable(known) and known then return ns.FISHING_SPELLS[i] end
    end
  end
  return ns.FISHING_SPELLS[1]
end

function ns.IsFishingSpell(spellID)
  if not ns.Usable(spellID) or type(spellID) ~= "number" then return false end
  if fishingIDs[spellID] then return true end
  local name = ns.FishingSpellName()
  if not name then return false end
  local ok, other = pcall(ns.SpellName, spellID)
  return ok and Text(other) == name
end

---------------------------------------------------------------------------
-- Skill: rank, max, modifier (lure + gear), localized profession name
---------------------------------------------------------------------------
local FISHING_SKILL_LINE = 356

local function Num(v)
  if ns.Usable(v) and type(v) == "number" then return v end
  return 0
end

-- Finds Fishing in GetProfessions(). Order there: two primary professions,
-- archaeology/first aid, fishing, cooking. If Forever orders them differently,
-- the skill line ID (356) finds it anyway. Returns index, how it was found.
-- 1.15: one pass returns the profession values too (the window used to ask for them a second time).
local slots = {}
local function FindFishing()
  if not (GetProfessions and GetProfessionInfo) then return nil, "no-api" end
  local ok, p1, p2, p3, p4, p5 = pcall(GetProfessions)
  if not ok then return nil, "error" end
  slots[1], slots[2], slots[3], slots[4], slots[5] = p4, p1, p2, p3, p5
  for i = 1, 5 do
    local index = slots[i]
    if ns.Usable(index) then
      local ok2, name, _, rank, maxRank, _, _, skillLine, modifier = pcall(GetProfessionInfo, index)
      if ok2 then
        local how
        if ns.Usable(skillLine) then
          if skillLine == FISHING_SKILL_LINE then how = i == 1 and "slot4" or "scan" end
        elseif i == 1 then
          how = "slot4-unchecked" -- no skill line reported: trust the documented order
        end
        if how then return index, how, name, rank, maxRank, modifier end
      end
    end
  end
  return nil, "none"
end

function ns.FishingProfession()
  local index, how = FindFishing()
  return index, how
end

-- Old skill list (Classic API), only if GetProfessions is missing.
local function SkillLineFallback()
  if not (GetNumSkillLines and GetSkillLineInfo) then return nil end
  local name = ns.FishingSpellName()
  if not name then return nil end
  local ok, n = pcall(GetNumSkillLines)
  if not ok or not ns.Usable(n) then return nil end
  for i = 1, n do
    local ok2, skillName, isHeader, _, rank, _, modifier, maxRank = pcall(GetSkillLineInfo, i)
    if ok2 and not isHeader and ns.Usable(skillName) and skillName == name then
      return Num(rank), Num(maxRank), Num(modifier), skillName
    end
  end
end

-- Returns rank, maxRank, modifier, localized name, and true when the profession list has Fishing
-- (then Fishing is certainly learned; the window saves a second lookup with it).
function ns.GetSkill()
  local index, _, name, rank, maxRank, modifier = FindFishing()
  if index then
    return Num(rank), Num(maxRank), Num(modifier), (ns.Usable(name) and type(name) == "string") and name or nil, true
  elseif not GetProfessions then
    local rank, maxRank, modifier, name = SkillLineFallback()
    if rank then return rank, maxRank, modifier, name end
  end
  return 0, 0, 0, nil
end

-- How the client answers "is Fishing learned" (spell ID 7620), for /ld diag.
local function KnownBy(fn, id)
  if not fn then return "missing" end
  local ok, known = pcall(fn, id)
  if not ok then return "error" end
  if not ns.Usable(known) then return type(known) == "nil" and "nil" or "secret" end
  return known and "yes" or "no"
end
function ns.FishingKnownProbe()
  local spellBook = C_SpellBook and C_SpellBook.IsSpellKnown
  return KnownBy(spellBook, ns.FISHING_SPELLS[1]), KnownBy(IsPlayerSpell, ns.FISHING_SPELLS[1])
end

-- False only if the character certainly has not learned Fishing (low-level
-- characters): then the double-click keeps its normal meaning and no lure is used.
-- When the client cannot tell, it counts as learned.
function ns.KnowsFishing()
  if ns.FishingProfession() then return true end
  local isKnown = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell
  if not isKnown then return true end
  for _, id in ipairs(ns.FISHING_SPELLS) do
    local ok, known = pcall(isKnown, id)
    if not ok or not ns.Usable(known) or known then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Pole and lure
---------------------------------------------------------------------------
local function ItemInfoInstant(item)
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not fn then return nil end
  local ok, id, _, _, _, _, classID, subclassID = pcall(fn, item)
  if ok then return id, classID, subclassID end
end

function ns.IsPole(item)
  if not item or not ns.Usable(item) then return false end
  local _, classID, subclassID = ItemInfoInstant(item)
  return classID == WEAPON and subclassID == POLE
end

function ns.PoleItemID()
  if not GetInventoryItemID then return nil end
  local ok, id = pcall(GetInventoryItemID, "player", INVSLOT_MAIN)
  if ok and ns.Usable(id) then return id end
end

function ns.HasPole()
  return ns.IsPole(ns.PoleItemID())
end

-- Returns hasLure, secondsLeft, enchantID, rawExpiration.
-- hasLure is nil if the client cannot tell; secondsLeft and enchantID may be nil.
-- GetWeaponEnchantInfo reports milliseconds; should Forever report seconds,
-- Cast.lua notices it on the first lure it applies (ns.lureSeconds).
function ns.GetLure()
  if GetWeaponEnchantInfo then
    local ok, has, expiration, _, enchantID = pcall(GetWeaponEnchantInfo)
    if not ok then return nil end
    if type(has) == "nil" then return false end
    if not ns.Usable(has) then return nil end
    if not has then return false end
    local raw = ns.Usable(expiration) and type(expiration) == "number" and expiration or nil
    local left = raw and raw / (ns.lureSeconds and 1 or 1000) or nil
    if not (ns.Usable(enchantID) and type(enchantID) == "number" and enchantID > 0) then enchantID = nil end
    return true, left, enchantID, raw
  end
  if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
    local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, INVSLOT_MAIN)
    if ok and ns.Usable(info) then return info ~= nil end
  end
  return nil
end

-- Lures that are not in our table (e.g. Forever camp lures): read the tooltip once.
local lureCache = {}
local known = {}
for _, lure in ipairs(ns.LURES) do known[lure.item] = lure end

-- Turns a GlobalString format ("Requires %s (%d)") into a Lua pattern.
local function FormatToPattern(fmt)
  local p = fmt:gsub("%%%d?%$?s", "\1"):gsub("%%%d?%$?d", "\2")
  p = p:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
  p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
  return p
end
ns.FormatToPattern = FormatToPattern

local function ParseLure(itemID)
  if lureCache[itemID] ~= nil then return lureCache[itemID] or nil end
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then lureCache[itemID] = false return nil end
  local _, classID = ItemInfoInstant(itemID)
  if classID ~= 0 then lureCache[itemID] = false return nil end -- consumables only
  local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
  if not ok or not (ns.Usable(data) and type(data) == "table" and type(data.lines) == "table") then return nil end -- not cached yet, try again later
  local _, _, _, skillName = ns.GetSkill()
  skillName = skillName or ns.FishingSpellName()
  if not skillName then return nil end
  local requirePattern = ITEM_MIN_SKILL and FormatToPattern(ITEM_MIN_SKILL)
  local bonus, skill
  for _, line in ipairs(data.lines) do
    local text = line.leftText
    if ns.Usable(text) and type(text) == "string" and text:find(skillName, 1, true) then
      if requirePattern then
        local name, value = text:match(requirePattern)
        if name == skillName then skill = tonumber(value) end
      end
      if not bonus then
        local b = text:match("%+(%d+)")
        if b then bonus = tonumber(b) end
      end
    end
  end
  if bonus then
    lureCache[itemID] = { item = itemID, skill = skill or 0, bonus = bonus }
  elseif ns.GetItemInfo(itemID) then
    lureCache[itemID] = false
  else
    -- Item data not loaded yet: the tooltip may lack its lines. Ask again later instead of
    -- remembering "no lure" for the whole session.
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return nil
  end
  return lureCache[itemID] or nil
end

-- Item ID in a bag slot without building a table per slot (GetContainerItemInfo returns one).
local function SlotItemID(bag, slot)
  local id
  if C_Container.GetContainerItemID then
    id = C_Container.GetContainerItemID(bag, slot)
  else
    local info = C_Container.GetContainerItemInfo(bag, slot)
    id = info and info.itemID
  end
  if ns.Usable(id) and type(id) == "number" then return id end
end

-- 1.15: the best lure is kept until the bags or the skill change. The window asks every second
-- and the cast ticker every 3 seconds; scanning all bag slots each time was the largest cost.
-- A lure whose tooltip is not loaded yet keeps the result short-lived (asked again in 5 s).
local LURE_CACHE_TIME, LURE_CACHE_PENDING = 30, 5
local bestCache = { valid = false }
function ns.InvalidateLureCache() bestCache.valid = false end

local function ScanBestLure(rank)
  local best, pending
  for _, lure in ipairs(ns.LURES) do
    if rank >= lure.skill and ns.ItemCount(lure.item) > 0 then best = lure break end
  end
  if C_Container then
    for bag = 0, LAST_BAG do
      for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
        local id = SlotItemID(bag, slot)
        if id and not known[id] then
          local lure = ParseLure(id)
          if lure == nil and lureCache[id] == nil then pending = true end
          if lure and rank >= lure.skill and (not best or lure.bonus > best.bonus) then
            best = lure
          end
        end
      end
    end
  end
  return best, pending
end

-- Best usable lure in the bags for the current base skill, or nil. rank: the caller's
-- base skill if it has read it already.
function ns.BestLure(rank)
  rank = tonumber(rank) or ns.GetSkill()
  local now = GetTime()
  local c = bestCache
  if c.valid and c.rank == rank and now < c.untilTime then return c.best end
  local best, pending = ScanBestLure(rank)
  c.valid, c.rank, c.best, c.pending = true, rank, best, pending
  c.untilTime = now + (pending and LURE_CACHE_PENDING or LURE_CACHE_TIME)
  return best
end

-- Bags, skill or item data changed: decide again on the next request.
ns.On("BAG_UPDATE_DELAYED", ns.InvalidateLureCache)
ns.On("SKILL_LINES_CHANGED", ns.InvalidateLureCache)
ns.On("PLAYER_ENTERING_WORLD", ns.InvalidateLureCache)
ns.On("GET_ITEM_INFO_RECEIVED", function() if bestCache.pending then bestCache.valid = false end end)

-- 1.13: how many of the best usable lure are left in the bags (for the window).
-- Returns itemID (nil when none fits the skill), count.
function ns.LureStock(rank)
  local best = ns.BestLure(rank)
  if not best then return nil, 0 end
  return best.item, ns.ItemCount(best.item) or 0
end

---------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------
function ns.FreeBagSlots()
  if not C_Container then return nil end
  local free = 0
  for bag = 0, LAST_BAG do
    local n, family = C_Container.GetContainerNumFreeSlots(bag)
    if not (ns.Usable(family) and type(family) == "number") then family = 0 end
    if family == 0 and ns.Usable(n) and type(n) == "number" then free = free + n end
  end
  return free
end

-- Returns mapID, skill needed so nothing gets away (nil = unknown), highest need in
-- parts of the zone (nil if the whole zone is the same). Unknown maps (new Forever
-- zones without data, caves, instances) give nil: better "unknown" than a wrong number.
function ns.IsNewForeverZone(mapID)
  return mapID ~= nil and ns.FOREVER_NEW_ZONES[mapID] == true
end

-- Map names by map ID (they never change); nil when the client gives none.
local mapNames = {}
function ns.MapName(mapID)
  if not mapID then return nil end
  local name = mapNames[mapID]
  if name == nil then
    local info
    if C_Map and C_Map.GetMapInfo then
      local ok, result = pcall(C_Map.GetMapInfo, mapID)
      if ok and ns.Usable(result) and type(result) == "table" then info = result end
    end
    name = info and Text(info.name) or false
    mapNames[mapID] = name
  end
  return name or nil
end

function ns.ZoneRequirement()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not ok or not ns.Usable(mapID) or type(mapID) ~= "number" then return nil end
  return mapID, ns.ZONE_SKILL[mapID], ns.ZONE_SKILL_PARTS[mapID]
end

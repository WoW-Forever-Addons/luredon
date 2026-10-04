local _, ns = ...

-- Fishing spell ranks (Apprentice .. Artisan). Casting by name picks the highest known rank.
ns.FISHING_SPELLS = { 7620, 7731, 7732, 18248 }
ns.FIND_FISH_SPELL = 43308

-- Classic lures, best first. skill = required fishing skill, bonus = fishing skill bonus.
ns.LURES = {
  { item = 6533, skill = 100, bonus = 100 }, -- Aquadynamic Fish Attractor (5 min)
  { item = 6532, skill = 100, bonus = 75 },  -- Bright Baubles
  { item = 7307, skill = 100, bonus = 75 },  -- Flesh Eating Worm
  { item = 6530, skill = 50,  bonus = 50 },  -- Nightcrawlers
  { item = 6811, skill = 50,  bonus = 50 },  -- Aquadynamic Fish Lens
  { item = 6529, skill = 0,   bonus = 25 },  -- Shiny Bauble
}

-- Total fishing skill (incl. lure and gear) needed so no fish gets away, by classic UiMap ID.
-- Source: Wowhead, "Fishing Profession Overview in Forever" (zone table "100% Catch"), checked
-- 2026-10-02; Warcraft Tavern's Classic guide has the same tiers from 150 on. Zones the guide does
-- not list have no entry (shown as unknown): Searing Gorge, Blasted Lands and the new Forever zones.
-- The classic UiMap IDs below match the Forever client data (ATT Forever DB, UiMap of build
-- 1.60.1.70170 and .config/constants/maps.lua, checked 2026-10-02).
ns.ZONE_SKILL = {
  -- 25 (Zephras Isle, UiMap 2521, is in this row of the Forever guide)
  [1411] = 25, [1412] = 25, [1420] = 25, [1426] = 25, [1429] = 25, [1438] = 25, [2521] = 25,
  -- 75 (incl. the capital cities)
  [1413] = 75, [1421] = 75, [1432] = 75, [1436] = 75, [1439] = 75, [1453] = 75,
  [1454] = 75, [1455] = 75, [1456] = 75, [1457] = 75, [1458] = 75,
  -- 150
  [1424] = 150, [1431] = 150, [1433] = 150, [1437] = 150, [1440] = 150, [1442] = 150,
  -- 225
  [1416] = 225, [1417] = 225, [1434] = 225, [1435] = 225, [1441] = 225, [1443] = 225, [1445] = 225,
  -- 300
  [1422] = 300, [1425] = 300, [1444] = 300, [1446] = 300, [1447] = 300, [1448] = 300,
  [1449] = 300, [1450] = 300,
  -- 425 (only reachable with lure and gear)
  [1423] = 425, [1428] = 425, [1430] = 425, [1451] = 425, [1452] = 425,
}

-- New Forever zones (UiMap IDs from the client data of build 1.60.1.70170, ATT Forever DB:
-- .contrib/.db/forever/.config/.wago/UiMap.1.60.1.70170.csv). No fishing skill is published for
-- them yet, so the window says so instead of a plain "unknown". Zephras Isle (2521) has its value
-- above; its second map 2665 is a flight map (System 1), not a place to fish.
ns.FOREVER_NEW_ZONES = { [2482] = true, [2548] = true, [2652] = true } -- Mount Hyjal, Riverglades, Shen'dralas

-- Parts of a zone that need more (same source): Stranglethorn Vale (Jaguero Isle) 300,
-- Azshara (Bay of Storms, Hetaera's Clutch, Scalebeard's Cave) 425, Feralas (Jademir Lake) 425.
-- They have no map of their own, so the panel names the higher value as a hint.
ns.ZONE_SKILL_PARTS = { [1434] = 300, [1447] = 425, [1444] = 425 }

-- Trainer milestones: skill cap -> skill from which the next rank can be learned, hint text key.
ns.MILESTONES = {
  [75]  = { from = 50,  text = "Learn Journeyman Fishing from a fishing trainer." },
  -- Old Man Heming (NPC 2626) sells the book in Forever too (ATT Forever DB, zones/eastern kingdoms/stranglethorn vale.lua).
  [150] = { from = 125, text = "Buy 'Expert Fishing - The Bass and You' from Old Man Heming in Booty Bay." },
  [225] = { from = 225, text = "Do the quest 'Nat Pagle, Angler Extreme' (Nat Pagle, Dustwallow Marsh) for Artisan." },
}

-- Forever camp objects: placement spell IDs (Wowhead Forever: "Places a Fishing Rack/Hut that
-- grants the ability to catch uncommon/rare fish for 1 hour"). Not the recipe spells 1262990 (Rack)
-- and 1262998 (Hut), which only craft the item. Fish Bowl: recipe 1229745, placement 1307245.
-- Fish Bowl aura 1230098 ("Boosted Stats", 1 hour) is UNVERIFIED as the Fish Bowl's own buff.
-- ATT Forever DB (checked 2026-10-02): the Fish Bowl recipe 1229745 comes from the quest "Camping 101:
-- Fishing" (level 4; Zephras Isle 97967, Dun Morogh 96050, Elwynn 97920, Durotar 97904, Mulgore 97932,
-- Teldrassil 97943, Tirisfal 97956); recipes 1229745, 1262990 and 1262998 are on the Fishing skill line.
-- Placed items: Fish Bowl 279967, Fishing Rack 279965, Fishing Hut 279966 (blueprints 273141, 273119).
ns.CAMP = {
  rack = { spell = 1307247, seconds = 3600, label = "Fishing Rack (uncommon fish)" },
  hut  = { spell = 1307246, seconds = 3600, label = "Fishing Hut (rare fish)" },
}
ns.FISH_BOWL_AURA = 1230098

-- Fishing skill needed to make the camp objects (Wowhead Forever camping guide).
ns.CAMP_UNLOCKS = {
  { skill = 20,  label = "Fish Bowl" },
  { skill = 140, label = "Fishing Rack" },
  { skill = 300, label = "Fishing Hut" },
}

-- Next camp object the fishing skill does not reach yet: label, skill (nil when all are unlocked).
function ns.NextCampUnlock(rank)
  for _, u in ipairs(ns.CAMP_UNLOCKS) do
    if (rank or 0) < u.skill then return u.label, u.skill end
  end
end

-- Stranglethorn Fishing Extravaganza: Sunday 14:00-16:00 realm time. The Forever client data has the
-- same schedule (Holiday 301, start packed as Sunday 14:00 for any date, duration 2 hours; ATT Forever DB
-- .contrib/.db/forever/.config/.wago/Holiday.1.60.1.70170.csv, checked 2026-10-02). Blizzard has not
-- announced it yet, so /ld derby stays. In Forever the first 50 players win, not only the first one.
-- /ld derby <day> <hour> sets another start; the contest keeps its two hours.
-- holiday/dataBuild: where the time was checked (for /ld diag and the window's source hint, 1.16).
ns.DERBY = { weekday = 1, startHour = 14, endHour = 16, hours = 2, fish = 19807, needed = 40,
  holiday = 301, dataBuild = "1.60.1.70170", announced = false }

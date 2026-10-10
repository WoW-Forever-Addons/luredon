local _, ns = ...

---------------------------------------------------------------------------
-- (1.2) Which fish can be caught in a zone (Daniel's idea, 04.10.): the bundled list
-- (Data_Fish.lua, Wowhead Forever zone pages) merged with your own catches of the zone.
-- Shown in the zone tooltip of the window and in the catch log (/ld log, section "This zone").
-- Item IDs only; names come from the game in the client's language.
---------------------------------------------------------------------------

-- List for a zone: { { id, share = 0-1 (data) or nil, caught = your catches here, kind = "f"|"c",
-- data = true when in the bundled list }, ... }, sorted by the data's share (own extras last),
-- plus kinds (fish only), caughtKinds, classic. nil when the zone has no bundled list.
-- (1.3) Zones above level 30 have no Forever data yet: the Wowhead Classic list is used
-- (ns.ZONE_FISH_CLASSIC); classic = true, entries carry classic = true. A fish you caught
-- there counts as confirmed.
function ns.ZoneFishData(mapID)
  local data = mapID and ns.ZONE_FISH and ns.ZONE_FISH[mapID]
  if type(data) == "table" then return data, false end
  data = mapID and ns.ZONE_FISH_CLASSIC and ns.ZONE_FISH_CLASSIC[mapID]
  if type(data) == "table" then return data, true end
  return nil
end

-- (1.3) Is an item a kind for the fish atlas? Everything in a bundled list is. Other items count
-- unless the game names them as something else: potions, elixirs and flasks (class 0, sub 1-3),
-- weapons (2), armor (4), recipes (9) and quest items (12). Unknown item info counts as fish.
local fishIDs
local NOT_FISH_CLASS = { [2] = true, [4] = true, [9] = true, [12] = true }
local NOT_FISH_CONSUMABLE = { [1] = true, [2] = true, [3] = true }
function ns.IsFishKind(id)
  id = tonumber(id)
  if not id then return false end
  if not fishIDs then
    fishIDs = {}
    for _, src in ipairs({ ns.ZONE_FISH or {}, ns.ZONE_FISH_CLASSIC or {} }) do
      for _, list in pairs(src) do
        for _, e in ipairs(type(list) == "table" and list or {}) do
          if type(e) == "table" and type(e[1]) == "number" then fishIDs[e[1]] = true end
        end
      end
    end
  end
  if fishIDs[id] then return true end
  local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  if not fn then return true end
  local ok, _, _, _, _, _, classID, subclassID = pcall(fn, id)
  if not ok or type(classID) ~= "number" then return true end
  if NOT_FISH_CLASS[classID] then return false end
  if classID == 0 and NOT_FISH_CONSUMABLE[subclassID] then return false end
  return true
end

-- (1.4.1) A fifth result: true when the list comes from Luredon's own catches (ns.ZONE_FISH_OWN,
-- zones Wowhead has no list for yet, e.g. Zephras Isle); its entries carry fromOwn = true.
function ns.ZoneFishList(mapID)
  local data, classic = ns.ZoneFishData(mapID)
  if type(data) ~= "table" then return nil end
  local ownList = not classic and ns.ZONE_FISH_OWN and ns.ZONE_FISH_OWN[mapID] and true or nil
  local z = ns.db and type(ns.db.zones) == "table" and ns.db.zones[mapID]
  local own = type(z) == "table" and type(z.fish) == "table" and z.fish or {}
  local list, seen, kinds, caughtKinds = {}, {}, 0, 0
  for _, e in ipairs(data) do
    local id, share, kind = e[1], tonumber(e[2]), e[3]
    if type(id) == "number" and not seen[id] then
      seen[id] = true
      local caught = tonumber(own[id]) or 0
      list[#list + 1] = { id = id, share = share and share / 100 or nil, caught = caught, kind = kind == "c" and "c" or "f", data = true,
        classic = classic or nil, fromOwn = ownList }
      if kind ~= "c" then
        kinds = kinds + 1
        if caught > 0 then caughtKinds = caughtKinds + 1 end
      end
    end
  end
  -- caught here but not in the list (newer data, rare finds): appended, but only fish
  -- and containers (a potion or a piece of armor from the water is no kind of fish)
  local extra = {}
  for id, n in pairs(own) do
    if type(id) == "number" and not seen[id] and (tonumber(n) or 0) > 0 and ns.IsFishKind(id) then
      extra[#extra + 1] = { id = id, caught = tonumber(n), kind = "f" }
    end
  end
  table.sort(extra, function(a, b) if a.caught ~= b.caught then return a.caught > b.caught end return a.id < b.id end)
  for _, e in ipairs(extra) do list[#list + 1] = e end
  return list, kinds, caughtKinds, classic, ownList
end

-- For /ld diag: how many zones have a list, and the current zone.
function ns.ZoneFishDiag()
  local n, c = 0, 0
  for _ in pairs(ns.ZONE_FISH or {}) do n = n + 1 end
  for _ in pairs(ns.ZONE_FISH_CLASSIC or {}) do c = c + 1 end
  local mapID = ns.ZoneRequirement and ns.ZoneRequirement()
  local list, kinds, caught = ns.ZoneFishList(mapID)
  return ("lists for %d zones (%s), classic %d (%s), here %s"):format(n, tostring(ns.ZONE_FISH_DATE or "?"),
    c, tostring(ns.ZONE_FISH_CLASSIC_DATE or "?"),
    list and ("%d of %d kinds caught, %d entries"):format(caught, kinds, #list) or "no list")
end

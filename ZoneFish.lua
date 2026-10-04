local _, ns = ...

---------------------------------------------------------------------------
-- (1.2) Which fish can be caught in a zone (Daniel's idea, 04.10.): the bundled list
-- (Data_Fish.lua, Wowhead Forever zone pages) merged with your own catches of the zone.
-- Shown in the zone tooltip of the window and in the catch log (/ld log, section "This zone").
-- Item IDs only; names come from the game in the client's language.
---------------------------------------------------------------------------

-- List for a zone: { { id, share = 0-1 (data) or nil, caught = your catches here, kind = "f"|"c",
-- data = true when in the bundled list }, ... }, sorted by the data's share (own extras last),
-- plus kinds (fish only), caughtKinds. nil when the zone has no bundled list.
function ns.ZoneFishList(mapID)
  local data = mapID and ns.ZONE_FISH and ns.ZONE_FISH[mapID]
  if type(data) ~= "table" then return nil end
  local z = ns.db and type(ns.db.zones) == "table" and ns.db.zones[mapID]
  local own = type(z) == "table" and type(z.fish) == "table" and z.fish or {}
  local list, seen, kinds, caughtKinds = {}, {}, 0, 0
  for _, e in ipairs(data) do
    local id, share, kind = e[1], tonumber(e[2]), e[3]
    if type(id) == "number" and not seen[id] then
      seen[id] = true
      local caught = tonumber(own[id]) or 0
      list[#list + 1] = { id = id, share = share and share / 100 or nil, caught = caught, kind = kind == "c" and "c" or "f", data = true }
      if kind ~= "c" then
        kinds = kinds + 1
        if caught > 0 then caughtKinds = caughtKinds + 1 end
      end
    end
  end
  -- caught here but not in the list (newer data, rare finds): appended
  local extra = {}
  for id, n in pairs(own) do
    if type(id) == "number" and not seen[id] and (tonumber(n) or 0) > 0 then
      extra[#extra + 1] = { id = id, caught = tonumber(n), kind = "f" }
    end
  end
  table.sort(extra, function(a, b) if a.caught ~= b.caught then return a.caught > b.caught end return a.id < b.id end)
  for _, e in ipairs(extra) do list[#list + 1] = e end
  return list, kinds, caughtKinds
end

-- For /ld diag: how many zones have a list, and the current zone.
function ns.ZoneFishDiag()
  local n = 0
  for _ in pairs(ns.ZONE_FISH or {}) do n = n + 1 end
  local mapID = ns.ZoneRequirement and ns.ZoneRequirement()
  local list, kinds, caught = ns.ZoneFishList(mapID)
  return ("lists for %d zones (%s), here %s"):format(n, tostring(ns.ZONE_FISH_DATE or "?"),
    list and ("%d of %d kinds caught, %d entries"):format(caught, kinds, #list) or "no list")
end

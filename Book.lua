local _, ns = ...
local L = ns.L
local Style = ns.Style
local C = Style.COLORS

---------------------------------------------------------------------------
-- (1.3) The fishing book (/ld book): one large window with three tabs, in the
-- look of Questdon's quest book.
--
--   Logbook    every fishing session as one line (zone, time, fish, getaways,
--              fish per hour, value), rare catches, skill milestones and new
--              records as bands in between; today's numbers on top.
--   Fish atlas every kind of fish and container as a card: caught ones with
--              count and first catch, missing ones with where they bite and
--              the skill needed. Details of the picked kind on the right.
--   Waters     every zone with the skill it needs (green: yours is enough),
--              the zone with its map, your numbers there and its fish, with
--              the share in the open data (CMaNGOS) next to your own.
--
-- Sessions: LuredonDB.book.chars[character] = { e = { entries }, open = running
-- session, ms = { [cap] = true }, best = { fph, t, z } }. A session starts with
-- the first cast and ends when the pole goes back into the bags or after
-- GAP seconds without fishing. Only numbers and item IDs, no names.
-- The kinds of fish come from the catch log (Log.lua) and the zone lists
-- (Data_Fish.lua, CMaNGOS classic-db and Luredon's own catches, tools/open/build_fish.py).
---------------------------------------------------------------------------
local GAP = 20 * 60
local IDLE = 90
local MAX_ENTRIES = 400
local MIN_RATE_SECONDS = 600
local MAX_NEW = 6

local function Num(v)
  v = tonumber(v)
  if v and v == v and v ~= math.huge and v ~= -math.huge then return v end
end
local function Now() return Num(GetServerTime and GetServerTime()) or time() end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------
local function Store()
  local db = ns.db
  if not db then return nil end
  if type(db.book) ~= "table" then db.book = { v = 1, chars = {} } end
  if type(db.book.chars) ~= "table" then db.book.chars = {} end
  return db.book
end

local function CharBook()
  local store = Store()
  if not store then return nil end
  local key = ns.CharKey and ns.CharKey() or "?"
  local cb = store.chars[key]
  if type(cb) ~= "table" then cb = {} store.chars[key] = cb end
  if type(cb.e) ~= "table" then cb.e = {} end
  if type(cb.ms) ~= "table" then cb.ms = {} end
  return cb
end
ns.BookCharData = CharBook

local function Add(cb, entry)
  cb.e[#cb.e + 1] = entry
  while #cb.e > MAX_ENTRIES do table.remove(cb.e, 1) end
end

local function MainZone(open)
  local best, n = nil, -1
  for m, c in pairs(open.zc or {}) do
    m, c = Num(m), Num(c) or 0
    if m and (c > n or (c == n and m < (best or m + 1))) then best, n = m, c end
  end
  return best
end

local function Skill()
  local rank = ns.GetSkill and ns.GetSkill()
  return Num(rank) or 0
end

-- The running session becomes an entry (with a record band when it beat your best).
local function Close(cb)
  local o = cb and cb.open
  if type(o) ~= "table" then return end
  cb.open = nil
  if (Num(o.c) or 0) <= 0 and (Num(o.f) or 0) <= 0 then return end
  -- (1.4.1) m: missed bites (the line came in by itself)
  local entry = { k = "s", t = o.t, t2 = o.l, z = MainZone(o), c = o.c, f = o.f, j = o.j, g = o.g, a = o.a,
    v = o.v, ah = (Num(o.ah) or 0) > 0 and o.ah or nil, s0 = o.s0, s1 = o.s1, nw = o.nw, m = (Num(o.m) or 0) > 0 and o.m or nil }
  Add(cb, entry)
  local a, f = Num(o.a) or 0, Num(o.f) or 0
  local closed = entry
  if a >= MIN_RATE_SECONDS and f > 0 then
    local rate = math.floor(f / (a / 3600) * 10 + 0.5) / 10
    local best = type(cb.best) == "table" and Num(cb.best.fph) or 0
    if rate > best then
      if best > 0 then
        Add(cb, { k = "x", t = (Num(o.l) or Now()) + 1, v = rate, old = best, oz = cb.best.z, ot = cb.best.t, z = entry.z })
      end
      cb.best = { fph = rate, t = o.l, z = entry.z }
    end
  end
  return closed
end
ns.BookCloseSession = function() Close(CharBook()) end

local function Open(cb, now)
  local o = cb.open
  if type(o) == "table" and now - (Num(o.l) or 0) > GAP then Close(cb) o = nil end
  if type(o) ~= "table" then
    o = { t = now, l = now, c = 0, f = 0, j = 0, g = 0, a = 0, v = 0, ah = 0, zc = {}, s0 = Skill(), nw = {} }
    cb.open = o
  end
  return o
end

local function Act(o, now)
  local gap = now - (Num(o.l) or now)
  if gap > 0 and gap < IDLE then o.a = (Num(o.a) or 0) + gap end
  o.l = now
  o.s1 = Skill()
end

function ns.BookCast(mapID)
  local cb = CharBook()
  if not cb then return end
  local now = Now()
  local o = Open(cb, now)
  Act(o, now)
  o.c = (Num(o.c) or 0) + 1
  mapID = Num(mapID)
  if mapID then o.zc[mapID] = (Num(o.zc[mapID]) or 0) + 1 end
end

-- (1.4.1) the line came in by itself (Stats.lua decides)
function ns.BookBiteMissed()
  local cb = CharBook()
  local o = cb and cb.open
  if type(o) ~= "table" then return end
  o.m = (Num(o.m) or 0) + 1
end

function ns.BookGetaway()
  local cb = CharBook()
  local o = cb and cb.open
  if type(o) ~= "table" then return end
  local now = Now()
  Act(o, now)
  o.g = (Num(o.g) or 0) + 1
end

-- One catch item (Stats.lua, before the catch log counts it: newKind = never caught before).
function ns.BookCatch(id, quantity, quality, mapID, newKind)
  local cb = CharBook()
  if not cb then return end
  id, quantity = Num(id), Num(quantity) or 1
  if not id then return end
  local now = Now()
  local o = Open(cb, now)
  Act(o, now)
  if quality == 0 then
    o.j = (Num(o.j) or 0) + quantity
    return
  end
  o.f = (Num(o.f) or 0) + quantity
  o.v = (Num(o.v) or 0) + (Num(ns.GetSellPrice and ns.GetSellPrice(id)) or 0) * quantity
  if ns.AuctionPricesOn and ns.AuctionPricesOn() then
    o.ah = (Num(o.ah) or 0) + (Num(ns.AuctionPrice(id)) or 0) * quantity
  end
  if newKind and #o.nw < MAX_NEW then o.nw[#o.nw + 1] = id end
  if type(quality) == "number" and quality >= (ns.RARE_QUALITY or 2) then
    Add(cb, { k = "r", t = now, id = id, q = quality, z = Num(mapID), n = quantity })
  end
end

-- Skill at its cap with a trainer milestone (75, 150, 225): one band per cap and character.
function ns.BookSkill(rank, maxRank)
  local cb = CharBook()
  if not cb then return end
  rank, maxRank = Num(rank) or 0, Num(maxRank) or 0
  if cb.open then cb.open.s1 = rank end
  if rank > 0 and maxRank > 0 and rank >= maxRank and ns.MILESTONES and ns.MILESTONES[maxRank] and not cb.ms[maxRank] then
    cb.ms[maxRank] = true
    Add(cb, { k = "m", t = Now(), rank = maxRank })
  end
end

-- After a loading screen: a session idle for longer than GAP is over.
ns.On("PLAYER_ENTERING_WORLD", function()
  local cb = CharBook()
  if cb and type(cb.open) == "table" and Now() - (Num(cb.open.l) or 0) > GAP then Close(cb) end
end)
-- Pole back into the bags: the session ends. (1.4.1, Daniel 09.10.) The chat summary describes
-- exactly this session (Stats.lua builds the text).
ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
  if slot ~= (INVSLOT_MAINHAND or 16) then return end
  if ns.HasPole and not ns.HasPole() then
    local cb = CharBook()
    if cb and cb.open then
      local entry = Close(cb)
      if entry and ns.ReportSessionSummary then ns.Call("session summary", ns.ReportSessionSummary, entry) end
      if ns.UpdateBook then ns.UpdateBook() end
    end
  end
end)

-- Entries newest first; the running session first, marked running.
function ns.BookEntries()
  local cb = CharBook()
  local out = {}
  if not cb then return out end
  for i = #cb.e, 1, -1 do
    local e = cb.e[i]
    if type(e) == "table" and e.k then out[#out + 1] = e end
  end
  table.sort(out, function(a, b) return (Num(a.t) or 0) > (Num(b.t) or 0) end)
  local o = cb.open
  if type(o) == "table" and (Num(o.c) or 0) > 0 then
    table.insert(out, 1, { k = "s", running = true, t = o.t, t2 = o.l, z = MainZone(o), c = o.c, f = o.f, j = o.j,
      g = o.g, a = o.a, v = o.v, ah = (Num(o.ah) or 0) > 0 and o.ah or nil, s0 = o.s0, s1 = o.s1, nw = o.nw, m = o.m })
  end
  return out
end

---------------------------------------------------------------------------
-- Kinds of fish (atlas) and zones (waters)
---------------------------------------------------------------------------
local ALLIANCE_ZONES = { [1429] = true, [1426] = true, [1438] = true, [1453] = true, [1455] = true, [1457] = true }
local HORDE_ZONES = { [1411] = true, [1412] = true, [1420] = true, [1454] = true, [1456] = true, [1458] = true }
local function OtherFactionZones()
  local ok, f = false, nil
  if UnitFactionGroup then ok, f = pcall(UnitFactionGroup, "player") end
  if ok and f == "Alliance" then return HORDE_ZONES elseif ok and f == "Horde" then return ALLIANCE_ZONES end
  return {}
end

local function TotalSkill()
  local rank, _, mod = 0, 0, 0
  if ns.GetSkill then rank, _, mod = ns.GetSkill() end
  return (Num(rank) or 0) + (Num(mod) or 0), Num(rank) or 0
end

local function Quality(id)
  local q = ns.ItemQuality and ns.ItemQuality(id)
  if q == nil and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return q
end

-- { [id] = { id, kind, zones = { {map, share, classic} }, minSkill, caught, first, fz, last, lz, classic } }
function ns.AtlasKinds()
  local kinds = {}
  local function Kind(id, kind)
    local k = kinds[id]
    if not k then k = { id = id, kind = kind or "f", zones = {}, classic = true } kinds[id] = k end
    return k
  end
  local function Scan(tbl, classic)
    for map, list in pairs(tbl or {}) do
      if not (classic and ns.ZONE_FISH and ns.ZONE_FISH[map]) then
        for _, e in ipairs(list) do
          local id, share, kind = Num(e[1]), Num(e[2]), e[3]
          if id then
            local k = Kind(id, kind == "c" and "c" or "f")
            k.zones[#k.zones + 1] = { map = map, share = (share or 0) / 100, classic = classic or nil }
            if not classic then k.classic = false end
            local need = ns.ZONE_SKILL and ns.ZONE_SKILL[map]
            if need and (not k.minSkill or need < k.minSkill) then k.minSkill = need end
          end
        end
      end
    end
  end
  Scan(ns.ZONE_FISH, false)
  Scan(ns.ZONE_FISH_CLASSIC, true)
  local lb = ns.db and ns.db.logbook
  for id, e in pairs(type(lb) == "table" and type(lb.fish) == "table" and lb.fish or {}) do
    id = Num(id)
    if id and type(e) == "table" then
      local k = Kind(id, nil)
      k.caught, k.first, k.fz, k.last, k.lz = Num(e.n) or 0, Num(e.first), Num(e.fz), Num(e.last), Num(e.lz)
      k.classic = false -- caught: confirmed
    end
  end
  -- where it bites: zones of the other faction's start areas and capitals last
  local other = OtherFactionZones()
  for id, k in pairs(kinds) do
    table.sort(k.zones, function(a, b)
      local oa, ob = other[a.map] and 1 or 0, other[b.map] and 1 or 0
      if oa ~= ob then return oa < ob end
      return a.share > b.share
    end)
    -- (1.3) only fish and containers: a potion or a quest item from the water is no kind
    if ns.IsFishKind and not ns.IsFishKind(id) then kinds[id] = nil end
  end
  return kinds
end

-- All zones of the book: { map, need, group } (need nil = unknown).
local FOREVER_START = { [2521] = true } -- Zephras Isle: new in Forever, with a published value
function ns.WaterZones()
  local maps = {}
  for m in pairs(ns.ZONE_SKILL or {}) do maps[m] = true end
  for m in pairs(ns.ZONE_FISH or {}) do maps[m] = true end
  for m in pairs(ns.ZONE_FISH_CLASSIC or {}) do maps[m] = true end
  for m in pairs(ns.FOREVER_NEW_ZONES or {}) do maps[m] = true end
  for m, z in pairs(type(ns.db and ns.db.zones) == "table" and ns.db.zones or {}) do
    if Num(m) and type(z) == "table" and (Num(z.casts) or 0) > 0 then maps[Num(m)] = true end
  end
  local out = {}
  for m in pairs(maps) do
    out[#out + 1] = { map = m, need = ns.ZONE_SKILL and ns.ZONE_SKILL[m], forever = (FOREVER_START[m] or (ns.FOREVER_NEW_ZONES and ns.FOREVER_NEW_ZONES[m])) and true or nil }
  end
  return out
end

---------------------------------------------------------------------------
-- Window (02.11.2026, StyleKit 2 step 4, docs/layout_2026-11-02/luredon/): the book is a window of DonCore's kit like
-- Questdon's quest book and Golddon: Kit.Window (flat head, tabs, cog, grip, 720x420 to 1300x900), tiles, chips,
-- Kit.List, Kit.Detail, Kit.Hero, a table. Nothing of its own look is left; only the content and the zone map are Luredon's.
---------------------------------------------------------------------------
local Kit = LibStub("DonCore-1.0"):Get("Kit", 11)
local KC, S = Kit and Kit.C, Kit and Kit.SIZE
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local TABS = { "log", "atlas", "waters" }
local TAB_TITLE = { log = L["Logbook"], atlas = L["Fish atlas"], waters = L["Waters"] }
local JMAP = 52       -- the round map in the first tile of the logbook
local TILE_H = 72
local HERO_H = 96
local SIDE_W, SIDE_NARROW = 232, 180
local DETAIL_W = 290
local CARD_MIN = 200  -- an item card is at least this wide (the atlas takes as many per row as fit)

local book
local tab = "log"
local lists, P = {}, {}
local lfilter, afilter = "all", "all"
local selKind, selZone
local zoneSeg = "fish"
local zoneQuery = ""
local showHigher = false
local Refresh

local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function ItemName(id)
  local name, link = ns.GetItemInfo(id)
  if type(name) == "string" and ns.Usable(name) then return name end
  if type(link) == "string" and ns.Usable(link) then return Plain(link) end
  Quality(id)
  return ("item:%d"):format(id)
end
local function ItemIcon(id)
  local icon
  if C_Item and C_Item.GetItemIconByID then local ok, v = pcall(C_Item.GetItemIconByID, id) if ok then icon = v end end
  if not icon and GetItemIcon then local ok, v = pcall(GetItemIcon, id) if ok then icon = v end end
  if icon ~= nil and ns.Usable(icon) then return icon end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- money in the kit's coins; nil for nothing
local function Coins(copper)
  copper = Num(copper)
  if not copper or copper <= 0 then return nil end
  return Kit.Money(math.floor(copper))
end
local function ZoneName(m) return (m and ns.MapName(m)) or L["unknown"] end

local WEEKDAYS = { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"], L["Saturday"] }
local MONTHS = { L["January"], L["February"], L["March"], L["April"], L["May"], L["June"], L["July"], L["August"],
  L["September"], L["October"], L["November"], L["December"] }
local function DateT(t) local f = date or (os and os.date) local ok, d = pcall(f, "*t", t) return ok and type(d) == "table" and d or nil end
local function DayKey(t) local d = t and DateT(t) return d and (d.year * 1000 + d.yday) or 0 end
local function DayTitle(t)
  local d = t and DateT(t)
  if not d then return L["Unknown date"] end
  local today = DayKey(Now())
  local wd = (WEEKDAYS[d.wday] or "?")
  if DayKey(t) == today then wd = L["Today"] elseif DayKey(t + 86400) == today then wd = L["Yesterday"] end
  return (L["{wd}, {mon} {d}, {y}"]:gsub("{wd}", wd):gsub("{mon}", (MONTHS[d.month] or "?")):gsub("{d}", tostring(d.day)):gsub("{y}", tostring(d.year)))
end
local function ShortDate(t)
  local d = t and DateT(t)
  if not d then return "-" end
  return (L["{m}/{d}"]:gsub("{m}", tostring(d.month)):gsub("{d}", tostring(d.day)))
end
local function Clock(t) local f = date or (os and os.date) local ok, s = pcall(f, "%H:%M", t) return ok and s or "--:--" end
local function Span(sec)
  sec = Num(sec) or 0
  if sec < 3600 then return L["%d min"]:format(math.max(1, math.floor(sec / 60 + 0.5))) end
  return L["%d:%02d h"]:format(math.floor(sec / 3600), math.floor(sec % 3600 / 60))
end
-- fish per hour, only from 5 minutes of fishing on (a short start gives absurd rates)
local function Rate(f, a) a = Num(a) or 0 if a < 300 then return nil end return math.floor((Num(f) or 0) / (a / 3600) + 0.5) end

---------------------------------------------------------------------------
-- The zone map (Luredon's content: drawn from the world map's tiles)
---------------------------------------------------------------------------
-- Folder of the zone map in Interface\\WorldMap (when the client gives no map art layers)
local MAPFILE = {
  [1438] = "Teldrassil", [1411] = "Durotar", [1412] = "Mulgore", [1439] = "Darkshore", [1413] = "Barrens",
  [1442] = "StonetalonMountains", [1440] = "Ashenvale", [1441] = "ThousandNeedles", [1443] = "Desolace",
  [1445] = "Dustwallow", [1444] = "Feralas", [1446] = "Tanaris", [1447] = "Aszhara", [1448] = "Felwood",
  [1449] = "UngoroCrater", [1452] = "Winterspring", [1450] = "Moonglade", [1451] = "Silithus",
  [1457] = "Darnassis", [1454] = "Ogrimmar", [1456] = "ThunderBluff",
  [1429] = "Elwynn", [1426] = "DunMorogh", [1420] = "Tirisfal", [1436] = "Westfall", [1432] = "LochModan",
  [1421] = "Silverpine", [1433] = "Redridge", [1431] = "Duskwood", [1437] = "Wetlands", [1424] = "Hilsbrad",
  [1416] = "Alterac", [1417] = "Arathi", [1434] = "Stranglethorn", [1418] = "Badlands", [1435] = "SwampOfSorrows",
  [1425] = "Hinterlands", [1427] = "SearingGorge", [1419] = "BlastedLands", [1428] = "BurningSteppes",
  [1422] = "WesternPlaguelands", [1423] = "EasternPlaguelands", [1430] = "DeadwindPass",
  [1453] = "Stormwind", [1455] = "Ironforge", [1458] = "Undercity",
}
local function ArtFromClient(m)
  local okL, layers = false, nil
  if C_Map and C_Map.GetMapArtLayers then okL, layers = pcall(C_Map.GetMapArtLayers, m) end
  local okT, textures = false, nil
  if C_Map and C_Map.GetMapArtLayerTextures then okT, textures = pcall(C_Map.GetMapArtLayerTextures, m, 1) end
  local layer = okL and type(layers) == "table" and layers[1]
  if type(layer) ~= "table" or not okT or type(textures) ~= "table" or #textures == 0 then return nil end
  local tw, th, lw, lh = Num(layer.tileWidth), Num(layer.tileHeight), Num(layer.layerWidth), Num(layer.layerHeight)
  if not (tw and th and lw and lh) or tw <= 0 or lw <= 0 then return nil end
  return textures, tw, th, lw, lh
end
-- The classic world map: 12 tiles of 256 pixels, 4 by 3, of which 1002 by 668 count.
local function ArtFromFiles(m)
  local name = m and MAPFILE[m]
  if not name then return nil end
  local textures = {}
  for i = 1, 12 do textures[i] = "Interface\\WorldMap\\" .. name .. "\\" .. name .. i end
  return textures, 256, 256, 1002, 668
end

-- The map of a zone into a frame, with the explored parts (as in Questdon's quest book): the banner of Waters and the
-- round map of the logbook (a circle mask on every piece).
local function DrawMapArt(hero, m, width, HEIGHT, mask)
  for _, t in ipairs(hero.tiles) do t:Hide() end
  hero.artMap, hero.artW = m, width
  local textures, tw, th, lw, lh = ArtFromClient(m)
  if not textures then textures, tw, th, lw, lh = ArtFromFiles(m) end
  if not textures then hero.artDrawn = 0 return false end
  local scale = math.max(width / lw, HEIGHT / lh)
  local shift = ((lh * scale) - HEIGHT) / 2
  local shiftX = ((lw * scale) - width) / 2
  local drawn = 0
  local function Piece(file, x, y, w, h, u, v, sub)
    local X, Y, Wd, Ht = x * scale - shiftX, y * scale - shift, w * scale, h * scale
    local ya, yb = math.max(0, Y), math.min(HEIGHT, Y + Ht)
    local xa, xb = math.max(0, X), math.min(width, X + Wd)
    if yb <= ya or xb <= xa then return end
    drawn = drawn + 1
    local t = hero.tiles[drawn]
    if not t then
      t = hero:CreateTexture(nil, "BACKGROUND", nil, 2)
      hero.tiles[drawn] = t
      if mask and t.AddMaskTexture then pcall(t.AddMaskTexture, t, mask) end
    end
    if t.SetDrawLayer then t:SetDrawLayer("BACKGROUND", sub or 2) end
    t:SetTexture(file)
    t:SetTexCoord(u * (xa - X) / Wd, u * (xb - X) / Wd, v * (ya - Y) / Ht, v * (yb - Y) / Ht)
    t:SetSize(xb - xa, yb - ya)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", hero, "TOPLEFT", xa, -ya)
    t:Show()
  end
  local cols = math.ceil(lw / tw)
  for i, file in ipairs(textures) do
    local row, col = math.floor((i - 1) / cols), (i - 1) % cols
    Piece(file, col * tw, row * th, tw, th, 1, 1, 2)
  end
  local okE, explored = false, nil
  if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then okE, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, m) end
  if okE and type(explored) == "table" then
    for _, info in ipairs(explored) do
      pcall(function()
        if info.isShownByMouseOver then return end
        local w, h = Num(info.textureWidth), Num(info.textureHeight)
        local ox, oy = Num(info.offsetX) or 0, Num(info.offsetY) or 0
        local files = info.fileDataIDs
        if not (w and h and w > 0 and h > 0 and type(files) == "table") then return end
        local wide, tall = math.ceil(w / tw), math.ceil(h / th)
        for jj = 1, tall do
          local ph, fh = th, th
          if jj == tall then ph = h % th if ph == 0 then ph = th end fh = 16 while fh < ph do fh = fh * 2 end end
          for kk = 1, wide do
            local pw, fw = tw, tw
            if kk == wide then pw = w % tw if pw == 0 then pw = tw end fw = 16 while fw < pw do fw = fw * 2 end end
            local file = files[(jj - 1) * wide + kk]
            if file then Piece(file, ox + tw * (kk - 1), oy + th * (jj - 1), pw, ph, pw / fw, ph / fh, 3) end
          end
        end
      end)
    end
  end
  hero.artDrawn = drawn
  return drawn > 0
end

---------------------------------------------------------------------------
-- Building the lists (Kit.List items)
---------------------------------------------------------------------------
local FILTERS = { "all", "s", "r", "m", "x", "zone" }
local FILTER_TITLE = { all = L["All"], s = L["Sessions"], r = L["Rare catches"], m = L["Skill"], x = L["Records"], zone = L["This zone"] }

local function HereZone() return ns.ZoneRequirement and ns.ZoneRequirement() end

-- one entry of the book as a list row: time on the left, a symbol, title and details, value on the right; the mark on
-- the left: yellow running, the quality colour for a rare catch, gold for a skill milestone, green for a record
local function EntryRow(e)
  local it = { kind = "row", e = e, lead = e.t and Clock(e.t) or "", h = 38 }
  local title, sub
  if e.k == "s" then
    title = (e.running and L["Fishing now in %s"] or L["Session in %s"]):format(ZoneName(e.z))
    local parts = { Span(Num(e.t2) and Num(e.t) and (e.t2 - e.t) or e.a), L["%d fish"]:format(Num(e.f) or 0) }
    if (Num(e.g) or 0) > 0 then parts[#parts + 1] = L["%d got away"]:format(e.g) end
    if (Num(e.m) or 0) > 0 then parts[#parts + 1] = L["%d bites missed"]:format(e.m) end -- (1.4.1)
    local rate = Rate(e.f, e.a)
    if rate then parts[#parts + 1] = L["%d per hour"]:format(rate) end
    local s0, s1 = Num(e.s0) or 0, Num(e.s1) or 0
    if s0 > 0 and s1 > s0 then parts[#parts + 1] = L["skill %d to %d"]:format(s0, s1) end
    if type(e.nw) == "table" and e.nw[1] then parts[#parts + 1] = L["first catch: %s"]:format(ItemName(e.nw[1])) end
    sub = table.concat(parts, "  ·  ")
    it.icon = "Interface\\Icons\\Trade_Fishing"
    it.right = Coins(e.v)
    if e.ah then it.right2 = L["AH %s"]:format(Coins(e.ah) or "0") end
    if e.running then it.status = "yellow" end
  elseif e.k == "r" then
    local q = Quality(e.id)
    title = L["Rare catch: %s"]:format(ItemName(e.id))
    sub = ZoneName(e.z)
    it.icon, it.quality, it.itemID = ItemIcon(e.id), q, e.id
    it.markColor = q and Kit.QualityColor(q) or KC.blue
  elseif e.k == "m" then
    local ms = ns.MILESTONES and ns.MILESTONES[e.rank]
    title = L["Fishing skill %d: next rank needed"]:format(Num(e.rank) or 0)
    sub = ms and L[ms.text] or ""
    it.iconKind, it.markColor, it.titleColor = "step_skillup", KC.goldBright, KC.txGold
  elseif e.k == "x" then
    title = L["New record: %s fish per hour"]:format(ns.Decimal and ns.Decimal(e.v, 1) or tostring(e.v))
    sub = L["old best %s, %s in %s"]:format(ns.Decimal and ns.Decimal(e.old, 1) or tostring(e.old), ShortDate(e.ot), ZoneName(e.oz))
    it.icon, it.status, it.titleColor = "Interface\\Icons\\Trade_Fishing", "green", KC.green
  end
  it.title, it.sub = title or "", sub or ""
  if e.z then it.onClick = function() if ns.OpenBook then ns.OpenBook("waters", e.z) end end end
  it.tooltipFn = function()
    local lines = {}
    lines[#lines + 1] = { L["Date"], DayTitle(e.t) .. "  " .. Clock(e.t) }
    if e.k == "s" then
      lines[#lines + 1] = { L["Zone"], ZoneName(e.z) }
      lines[#lines + 1] = { L["Casts"], tostring(Num(e.c) or 0) }
      lines[#lines + 1] = { L["Fish"], tostring(Num(e.f) or 0) }
      if (Num(e.j) or 0) > 0 then lines[#lines + 1] = { L["Junk"], tostring(e.j) } end
      lines[#lines + 1] = { L["Got away"], tostring(Num(e.g) or 0) }
      if (Num(e.m) or 0) > 0 then lines[#lines + 1] = { L["Bites missed"], tostring(e.m) } end -- (1.4.1)
      lines[#lines + 1] = { L["Fishing time"], Span(e.a) }
      if e.v then lines[#lines + 1] = { L["Value"], Coins(e.v) or "0" } end
      if e.ah then lines[#lines + 1] = { L["Auction value"], Coins(e.ah) or "0" } end
      if type(e.nw) == "table" and e.nw[1] then
        lines[#lines + 1] = { header = L["First catches"] }
        for _, id in ipairs(e.nw) do lines[#lines + 1] = ItemName(id) end
      end
    elseif e.k == "r" then
      lines[#lines + 1] = { L["Zone"], ZoneName(e.z) }
    end
    return Plain(title or ""), lines, e.z and L["Click: show the zone on the tab Waters."] or nil
  end
  return it
end

-- entries with a divider for every day
local function DayItems(entries, keep)
  local items, day, head = {}, nil, nil
  for _, e in ipairs(entries) do
    if keep(e) then
      local key = DayKey(e.t)
      if key ~= day then
        day = key
        head = { kind = "divider", text = DayTitle(e.t), n = 0 }
        items[#items + 1] = head
      end
      head.n = head.n + 1
      head.right = tostring(head.n)
      items[#items + 1] = EntryRow(e)
    end
  end
  return items
end

local function LogItems()
  local here = HereZone()
  return DayItems(ns.BookEntries(), function(e)
    return lfilter == "all" or e.k == lfilter or (lfilter == "zone" and e.z ~= nil and e.z == here)
  end)
end

local AFILTERS = { "all", "caught", "missing", "rare", "c", "skill" }
local AFILTER_TITLE = { all = L["All"], caught = L["Caught"], missing = L["Missing"], rare = L["Rare (catches)"], c = L["Containers"], skill = L["For my skill"] }

local function SortedKinds()
  local list = {}
  for _, k in pairs(ns.AtlasKinds()) do list[#list + 1] = k end
  table.sort(list, function(a, b)
    local ca, cb = (a.caught or 0) > 0, (b.caught or 0) > 0
    if ca ~= cb then return ca end
    if ca then if a.caught ~= b.caught then return a.caught > b.caught end
    else
      local sa, sb = a.minSkill or 999, b.minSkill or 999
      if sa ~= sb then return sa < sb end
      local za, zb = a.zones[1] and a.zones[1].share or 0, b.zones[1] and b.zones[1].share or 0
      if za ~= zb then return za > zb end
    end
    return a.id < b.id
  end)
  return list
end

-- one kind of fish as an item card: caught ones with count and first catch, missing ones dimmed with where they bite
local function KindCard(k)
  local name = ItemName(k.id)
  local caught = (k.caught or 0) > 0
  local d = { itemID = k.id, quality = Quality(k.id), title = name, kind = k, selected = selKind == k.id }
  if caught then
    d.sub = L["%s · first %s"]:format(tostring(k.caught), ShortDate(k.first))
    d.right, d.status = k.caught, "green"
  else
    local z = k.zones[1]
    local where = z and (ZoneName(z.map) .. (z.share > 0 and ("  " .. Style.Percent(z.share)) or "")) or L["unknown"]
    d.sub = (k.minSkill and (L["skill %d"]:format(k.minSkill) .. "  ·  ") or "") .. where
    d.right = k.classic and L["classic"] or L["new"]
    d.rightColor = k.classic and KC.quiet or KC.yellow
    d.dim = true
  end
  d.onClick = function()
    selKind = k.id
    if P.mode ~= "full" then P.overlay = true end
    Refresh()
  end
  d.tooltipFn = function()
    local lines = {}
    if caught then
      lines[#lines + 1] = { L["Caught"], tostring(k.caught) }
      lines[#lines + 1] = { L["First catch"], ShortDate(k.first) .. ", " .. ZoneName(k.fz) }
    end
    for j = 1, math.min(4, #k.zones) do
      local z = k.zones[j]
      lines[#lines + 1] = { ZoneName(z.map), Style.Percent(z.share) .. (z.classic and (" " .. L["(Classic)"]) or "") }
    end
    return name, lines, L["Click: details on the right."]
  end
  return d
end

local function AtlasItems(list, cols)
  local total = TotalSkill()
  local shown = {}
  for _, k in ipairs(list) do
    local caught = (k.caught or 0) > 0
    local q = Quality(k.id)
    local keep = afilter == "all" or (afilter == "caught" and caught) or (afilter == "missing" and not caught)
      or (afilter == "rare" and q and q >= (ns.RARE_QUALITY or 2)) or (afilter == "c" and k.kind == "c")
      or (afilter == "skill" and not caught and k.minSkill ~= nil and k.minSkill <= total)
    if keep then shown[#shown + 1] = k end
  end
  local items = {}
  for i = 1, #shown, cols do
    local row, cards = {}, {}
    for j = 0, cols - 1 do
      local k = shown[i + j]
      if k then row[#row + 1] = k cards[#cards + 1] = KindCard(k) end
    end
    items[#items + 1] = { kind = "itemcards", cols = cols, cards = cards, kinds = row }
  end
  return items, #shown
end

local function SessionsIn(m)
  local list, a, f, v = {}, 0, 0, 0
  for _, e in ipairs(ns.BookEntries()) do
    if e.k == "s" and e.z == m then
      list[#list + 1] = e
      a, f, v = a + (Num(e.a) or 0), f + (Num(e.f) or 0), v + (Num(e.v) or 0)
    end
  end
  return list, a, f, v
end

local function ZoneListItems()
  local items = {}
  local total = TotalSkill()
  local here = HereZone()
  local shown = selZone or here
  local q = zoneQuery:lower():gsub("^%s+", ""):gsub("%s+$", "")
  local ok, next, higher, forever, unknown = {}, {}, {}, {}, {}
  local nextNeed
  for _, z in ipairs(ns.WaterZones()) do
    if z.need and z.need > total and not z.forever and (not nextNeed or z.need < nextNeed) then nextNeed = z.need end
  end
  for _, z in ipairs(ns.WaterZones()) do
    local name = ZoneName(z.map)
    if q == "" or name:lower():find(q, 1, true) then
      local good = z.need ~= nil and z.need <= total
      local row = { kind = "row", h = 30, map = z.map, name = name, title = name, need = z.need, ok = good,
        here = z.map == here, selected = z.map == shown, active = z.map == shown or nil,
        level = z.need and tostring(z.need) or "?", levelStatus = z.need == nil and "grey" or (good and "green" or "red"),
        markColor = z.map == here and KC.blue or nil }
      row.onClick = function() selZone = z.map zoneSeg = "fish" Refresh(true) end
      row.tooltipFn = function()
        local lines = { { L["Skill needed"], z.need and tostring(z.need) or L["unknown"] } }
        if z.need then lines[#lines + 1] = { L["Your skill with bonus"], tostring(total), good and KC.green or KC.red } end
        return name, lines
      end
      if z.forever then forever[#forever + 1] = row
      elseif not z.need then unknown[#unknown + 1] = row
      elseif good then ok[#ok + 1] = row
      elseif z.need == nextNeed then next[#next + 1] = row
      else higher[#higher + 1] = row end
    end
  end
  local function Sort(t) table.sort(t, function(a, b) if (a.need or 0) ~= (b.need or 0) then return (a.need or 0) < (b.need or 0) end return a.name < b.name end) end
  local function Group(title, rows, collapsible)
    if #rows == 0 then return end
    Sort(rows)
    local open = not collapsible or showHigher or q ~= ""
    items[#items + 1] = { kind = "group", text = title, count = #rows, right = tostring(#rows), static = not collapsible or nil,
      collapsed = not open, foldable = collapsible or nil }
    if open then for _, r in ipairs(rows) do items[#items + 1] = r end end
  end
  Group(L["Your skill is enough"], ok)
  Group(L["Next step"], next)
  Group(L["New in Forever"], forever)
  Group(L["Higher"], higher, true)
  Group(L["Skill unknown"], unknown, true)
  return items
end

local function ZoneFishItems(m)
  local items = {}
  local list, kinds, caughtKinds, classic, ownList = nil, 0, 0, false, nil
  if ns.ZoneFishList then list, kinds, caughtKinds, classic, ownList = ns.ZoneFishList(m) end
  local z = ns.db.zones and ns.db.zones[m]
  local ownTotal = 0
  for _, n in pairs(type(z) == "table" and type(z.fish) == "table" and z.fish or {}) do ownTotal = ownTotal + (Num(n) or 0) end
  if classic then
    items[#items + 1] = { kind = "note", text = L["Fish from CMaNGOS's classic data, not confirmed for Forever yet."], color = KC.yellow }
  elseif ownList then -- (1.4.1) Zephras Isle
    items[#items + 1] = { kind = "note", text = L["Fish from Luredon's own catches, the open data has no list for this zone yet."], color = KC.muted }
  end
  if not list then return items, 0, 0, L["No fish list for this zone yet."] end
  if #list == 0 then return items, kinds, caughtKinds, L["No fishing waters known in this zone."] end
  for _, e in ipairs(list) do
    local own = ownTotal > 0 and (e.caught or 0) / ownTotal or nil
    local name = ItemName(e.id) .. (e.kind == "c" and ("  " .. L["(container)"]) or "")
    local caughtHere = (e.caught or 0) > 0
    local it = { kind = "table", e = e, own = own, icon = ItemIcon(e.id), quality = Quality(e.id), dim = not caughtHere or nil,
      cells = { name,
        { bar = e.share and math.min(1, e.share) or 0, text = e.share and Style.Percent(e.share) or "-", barColor = KC.grey },
        { bar = own and math.min(1, own) or 0, text = own and Style.Percent(own) or "-", barColor = KC.goldBright },
        caughtHere and { tostring(e.caught), KC.green } or { L["new"], KC.yellow } } }
    it.onClick = function() selKind = e.id if ns.OpenBook then ns.OpenBook("atlas") end end
    it.tooltipFn = function()
      local lines = {}
      if e.share then
        local label = e.classic and L["Share (CMaNGOS, classic)"] or e.fromOwn and L["Share (Luredon's own catches)"] or L["Share (CMaNGOS)"]
        lines[#lines + 1] = { label, Style.Percent(e.share) }
      end
      if own then lines[#lines + 1] = { L["Your share here"], Style.Percent(own) } end
      lines[#lines + 1] = { L["Caught here"], caughtHere and tostring(e.caught) or L["not yet"] }
      return ItemName(e.id), lines, L["Click: in the fish atlas."]
    end
    items[#items + 1] = it
  end
  return items, kinds, caughtKinds
end

local function ZoneSessionItems(m)
  return (DayItems(SessionsIn(m), function() return true end))
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function OnList(list) return function(it, button) if it and type(it.onClick) == "function" then ns.Call("book click", it.onClick, list, button) end end end

local function CreateLogPage(page)
  P.ltiles = { Kit.Tile(page, { art = JMAP, height = TILE_H, onClick = function()
      local m = P.lmap and P.lmap.m
      if m and ns.OpenBook then ns.OpenBook("waters", m) end
    end }),
    Kit.Tile(page, { height = TILE_H }), Kit.Tile(page, { height = TILE_H }), Kit.Tile(page, { height = TILE_H }) }
  P.ltiles[1]._tipFn = function(t)
    local m = P.lmap and P.lmap.m
    if not m then return nil end
    local lines = {}
    for _, fs in ipairs(t._cutTexts or {}) do lines[#lines + 1] = Kit.FullText(fs) end
    return ZoneName(m), lines, L["Click: show the zone on the tab Waters."]
  end
  -- the zone you fish in, round in a gold ring (as Questdon's journal)
  local jm = CreateFrame("Frame", nil, P.ltiles[1].art)
  jm:SetSize(JMAP, JMAP)
  jm:SetPoint("CENTER", P.ltiles[1].art, "CENTER", 0, 0)
  jm.ringTex = jm:CreateTexture(nil, "BACKGROUND", nil, 0)
  jm.ringTex:SetSize(JMAP + 4, JMAP + 4)
  jm.ringTex:SetPoint("CENTER", jm, "CENTER", 0, 0)
  jm.ringTex:SetTexture(CIRCLE)
  Kit.SetColor(jm.ringTex, KC.gold)
  jm.base = jm:CreateTexture(nil, "BACKGROUND", nil, 1)
  jm.base:SetAllPoints(jm)
  jm.base:SetTexture(CIRCLE)
  Kit.SetColor(jm.base, KC.input)
  jm.tiles = {}
  if jm.CreateMaskTexture then
    local ok, mask = pcall(jm.CreateMaskTexture, jm)
    if ok and mask then
      pcall(mask.SetTexture, mask, CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(jm)
      jm.mask = mask
    end
  end
  P.lmap = jm
  P.lchips = Kit.ChipBar(page, { onChange = function(key) lfilter = key Refresh(true) end })
  for _, key in ipairs(FILTERS) do P.lchips:Add(key, FILTER_TITLE[key]) end
  lists.log = Kit.List(page, { onClick = OnList("log") })
end

local function CreateAtlasPage(page)
  P.atiles = { Kit.Tile(page, { height = TILE_H }), Kit.Tile(page, { height = TILE_H }), Kit.Tile(page, { height = TILE_H }) }
  P.achips = Kit.ChipBar(page, { onChange = function(key) afilter = key Refresh(true) end })
  for _, key in ipairs(AFILTERS) do P.achips:Add(key, AFILTER_TITLE[key]) end
  lists.atlas = Kit.List(page)
  P.detail = Kit.Detail(page, { onClose = function(d) P.overlay = nil d:Hide() end })
  P.barList = Kit.BarList(page, {})
  P.barList:Hide()
end

local function CreateWatersPage(page)
  P.side = CreateFrame("Frame", nil, page)
  Kit.Fill(P.side, KC.panel)
  P.sideEdge = Kit.Tex(P.side, "ARTWORK", KC.goldMuted)
  P.sideEdge:SetPoint("TOPRIGHT") P.sideEdge:SetPoint("BOTTOMRIGHT") P.sideEdge:SetWidth(1)
  P.zoneBox = Kit.SearchBox(P.side, { placeholder = L["Find a zone"], onChange = function(text) zoneQuery = text or "" Refresh() end })
  lists.zones = Kit.List(P.side, { onClick = OnList("zones"), onToggle = function() showHigher = not showHigher Refresh() end })
  P.main = CreateFrame("Frame", nil, page)
  local hero = Kit.Hero(P.main, { height = HERO_H, column = 150 })
  hero.map = CreateFrame("Frame", nil, hero.art)
  hero.map:SetAllPoints(hero.art)
  hero.map.tiles = {}
  P.hero = hero
  P.stats = Kit.Text(P.main, "sub", KC.muted)
  P.seg = Kit.Segmented(P.main, { items = { { value = "fish", text = L["Fish here"] }, { value = "sessions", text = L["Your sessions here"] } },
    get = function() return zoneSeg end, set = function(v) zoneSeg = v Refresh(true) end })
  P.segHere = Kit.Button(P.main, L["Back to my zone"], { small = true, onClick = function() selZone = nil Refresh(true) end })
  P.fishHead = Kit.TableHead(P.main, { icon = true, columns = {
    { key = "name", text = L["Fish"], grow = true },
    { key = "share", text = L["Share (CMaNGOS)"], width = 140 },
    { key = "own", text = L["Your share here"], width = 140 },
    { key = "caught", text = L["Caught here"], width = 70, justify = "RIGHT" } } })
  lists.waters = Kit.List(P.main, { onClick = OnList("waters") })
  P.fishHead:Bind(lists.waters)
end

local function PlaceTiles(tiles, page, w, top)
  local n = #tiles
  local each = math.floor((w - (n + 1) * S.gap) / n)
  for i, t in ipairs(tiles) do
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", page, "TOPLEFT", S.gap + (i - 1) * (each + S.gap), -top)
    t:Layout(each)
  end
  return top + TILE_H + S.gap
end

-- every page placed for the body's width and height (Kit.Window onLayout and after each drawing)
local function LayoutPages()
  local w, h, mode = P.bw or 976, P.bh or 580, P.mode or "full"
  for _, page in pairs(P.pages) do page:SetSize(w, h) end
  if tab == "log" then
    local page = P.pages.log
    local y = PlaceTiles(P.ltiles, page, w, S.gap)
    P.lchips:ClearAllPoints()
    P.lchips:SetPoint("TOPLEFT", page, "TOPLEFT", S.pad, -y)
    P.lchips:Layout(w - 2 * S.pad)
    y = y + S.chip + S.gap
    lists.log:ClearAllPoints()
    lists.log:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    lists.log:Resize(w, math.max(40, h - y))
  elseif tab == "atlas" then
    local page = P.pages.atlas
    local full = mode == "full"
    local dw = full and DETAIL_W or 0
    local y = PlaceTiles(P.atiles, page, w - dw, S.gap)
    P.achips:ClearAllPoints()
    P.achips:SetPoint("TOPLEFT", page, "TOPLEFT", S.pad, -y)
    P.achips:Layout(w - dw - 2 * S.pad)
    y = y + S.chip + S.gap
    lists.atlas:ClearAllPoints()
    lists.atlas:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    lists.atlas:Resize(w - dw, math.max(40, h - y))
    if full or P.overlay then
      local ow = full and dw or math.min(DETAIL_W + 40, w - 40)
      P.detail:ClearAllPoints()
      P.detail:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
      P.detail:Layout(ow, h)
      if P.detail.close then if full then P.detail.close:Hide() else P.detail.close:Show() end end
      P.detail:Show()
    else
      P.detail:Hide()
    end
  else
    local page = P.pages.waters
    local sw = mode == "full" and SIDE_W or SIDE_NARROW
    P.side:ClearAllPoints()
    P.side:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    P.side:SetSize(sw, h)
    P.zoneBox:ClearAllPoints()
    P.zoneBox:SetPoint("TOPLEFT", P.side, "TOPLEFT", S.gap, -S.gap)
    P.zoneBox:Layout(sw - 2 * S.gap)
    lists.zones:ClearAllPoints()
    lists.zones:SetPoint("TOPLEFT", P.side, "TOPLEFT", 0, -(S.gap + S.button + S.gap))
    lists.zones:Resize(sw - 1, math.max(40, h - S.button - 2 * S.gap))
    local mw = w - sw
    P.main:ClearAllPoints()
    P.main:SetPoint("TOPLEFT", page, "TOPLEFT", sw, 0)
    P.main:SetSize(mw, h)
    P.hero:ClearAllPoints()
    P.hero:SetPoint("TOPLEFT", P.main, "TOPLEFT", 0, 0)
    P.hero:Layout(mw)
    if P.hero.map.artMap and P.hero.map.artW ~= mw then DrawMapArt(P.hero.map, P.hero.map.artMap, mw, HERO_H) end
    local y = HERO_H + S.unit
    P.stats:ClearAllPoints()
    P.stats:SetPoint("TOPLEFT", P.main, "TOPLEFT", S.pad, -y - 4)
    Kit.Fit(P.stats, mw - 2 * S.pad)
    y = y + 22
    local hereW = P.segHere:IsShown() and math.min(P.segHere.natural or 140, 180) or 0
    P.seg:ClearAllPoints()
    P.seg:SetPoint("TOPLEFT", P.main, "TOPLEFT", S.pad, -y)
    P.seg:Layout(math.min(360, mw - 2 * S.pad - (hereW > 0 and hereW + S.gap or 0)))
    if hereW > 0 then
      P.segHere:ClearAllPoints()
      P.segHere:SetPoint("TOPRIGHT", P.main, "TOPRIGHT", -S.pad, -y)
      P.segHere:Layout(hereW)
    end
    y = y + S.button + S.gap
    if zoneSeg == "fish" then
      P.fishHead:ClearAllPoints()
      P.fishHead:SetPoint("TOPLEFT", P.main, "TOPLEFT", 0, -y)
      P.fishHead:Layout(mw)
      P.fishHead:Show()
      y = y + S.chip
    else
      P.fishHead:Hide()
    end
    lists.waters:ClearAllPoints()
    lists.waters:SetPoint("TOPLEFT", P.main, "TOPLEFT", 0, -y)
    lists.waters:Resize(mw, math.max(40, h - y))
  end
end

local function Create()
  if not Kit then return end
  ns.db.bookWin = type(ns.db.bookWin) == "table" and ns.db.bookWin or {}
  book = Kit.Window("LuredonBook", { title = "Luredon", subtitle = L["Fishing book"], logo = "Interface\\Icons\\Trade_Fishing",
    options = "Luredon", hint = "/ld options", footer = true, store = ns.db.bookWin, width = 980, height = 640,
    onTab = function(key) if book and book.built then ns.OpenBook(key) end end,
    onLayout = function(_, w, h, mode)
      P.bw, P.bh, P.mode = w, h, mode
      if mode == "full" then P.overlay = nil end
      if book and book.built then
        -- the number of item cards per row follows the width
        if tab == "atlas" and Kit.ItemCardCols(w - (mode == "full" and DETAIL_W or 0), CARD_MIN) ~= P.cols then Refresh(false) return end
        LayoutPages()
      end
    end })
  book:Hide()
  book:SetFrameStrata("HIGH")
  for _, key in ipairs(TABS) do book:AddTab(key, TAB_TITLE[key]) end
  P.tabs, P.options, P.close = {}, book.gear, book.close
  for _, t in ipairs(book.tabs) do P.tabs[t.key] = t end
  P.pages = {}
  for _, key in ipairs(TABS) do
    local page = CreateFrame("Frame", nil, book.body)
    page:SetPoint("TOPLEFT", book.body, "TOPLEFT", 0, 0)
    page:Hide()
    P.pages[key] = page
  end
  CreateLogPage(P.pages.log)
  CreateAtlasPage(P.pages.atlas)
  CreateWatersPage(P.pages.waters)
  -- the right button turns the camera through the head, as before
  ns.RightClickThrough(book, { book.header })
  ns.bookFrame = book
  book.built = true
  book:Layout()
end

---------------------------------------------------------------------------
-- Drawing the tabs
---------------------------------------------------------------------------
-- The logbook's round map: the zone you are in.
local function UpdateLogMap()
  local jm = P.lmap
  if not jm then return end
  local m = HereZone()
  jm.m = m
  if m ~= jm.artMap then
    if not DrawMapArt(jm, m, JMAP, JMAP, jm.mask) then jm.artMap = m end
  end
end

local function RenderLog(reset)
  UpdateLogMap()
  local today = DayKey(Now())
  local fish, active, value, ah, s0 = 0, 0, 0, 0, nil
  for _, e in ipairs(ns.BookEntries()) do
    if e.k == "s" and DayKey(e.t) == today then
      fish, active, value, ah = fish + (Num(e.f) or 0), active + (Num(e.a) or 0), value + (Num(e.v) or 0), ah + (Num(e.ah) or 0)
      if Num(e.s0) and Num(e.s0) > 0 and (not s0 or e.s0 < s0) then s0 = e.s0 end
    end
  end
  local t = P.ltiles
  local rate = Rate(fish, active)
  local m = P.lmap.m
  t[1]:SetData(L["Fish today"], tostring(fish), (m and ZoneName(m) or "") .. (rate and ("  ·  " .. L["%d per hour"]:format(rate)) or ""))
  local rank, maxRank = 0, 0
  if ns.GetSkill then rank, maxRank = ns.GetSkill() end
  rank, maxRank = Num(rank) or 0, Num(maxRank) or 0
  local gained = s0 and math.max(0, rank - s0) or 0
  t[2]:SetData(L["Skill today"], gained > 0 and ("+" .. gained) or "0", maxRank > 0 and ("%d / %d"):format(rank, maxRank) or "",
    gained > 0 and KC.green or nil)
  t[2]:SetProgress(maxRank > 0 and rank / maxRank or nil)
  t[3]:SetData(L["Value today"], Coins(value) or "0", ah > 0 and L["AH %s"]:format(Coins(ah) or "") or "")
  local cb = CharBook()
  local best = cb and type(cb.best) == "table" and cb.best
  t[4]:SetData(L["Best session"], best and (ns.Decimal and ns.Decimal(best.fph, 1) or tostring(best.fph)) or "-",
    best and L["fish per hour, %s"]:format(ShortDate(best.t)) or "", best and KC.txGold or nil)
  local counts = { s = 0, r = 0, m = 0, x = 0 }
  local casts, total = 0, 0
  for _, e in ipairs(ns.BookEntries()) do
    counts[e.k] = (counts[e.k] or 0) + 1
    if e.k == "s" then casts, total = casts + (Num(e.c) or 0), total + (Num(e.f) or 0) end
  end
  for _, chip in ipairs(P.lchips.chips) do chip:SetCount((counts[chip.key] or 0) > 0 and counts[chip.key] or nil) end
  P.lchips:SetActive(lfilter)
  book:SetStatus(L["%d sessions, %d fish, %d casts"]:format(counts.s, total, casts))
  lists.log:SetEmpty(lfilter == "all" and L["No sessions yet. Equip your pole and cast: every session is written down here."] or L["Nothing for this filter."])
  lists.log:SetItems(LogItems(), reset)
end

-- the picked kind in the focus card on the right
local function FillDetail(k)
  local d = P.detail
  local text = {}
  local function Line(l, r, color)
    d:Line(l, nil, r, color)
    text[#text + 1] = l .. ((r and r ~= "") and (" " .. Plain(r)) or "")
  end
  if not k then
    d:SetHead({ title = L["Pick a kind"] })
    d:Begin() d:End()
    P.detailText = ""
    return
  end
  local name = ItemName(k.id)
  local q = Quality(k.id)
  d:SetHead({ icon = ItemIcon(k.id), title = name, titleColor = q and q ~= 1 and Kit.QualityColor(q) or nil,
    meta = (k.kind == "c" and L["Container"] or L["Fish (kind)"]) .. (q and q >= (ns.RARE_QUALITY or 2) and ("  ·  " .. L["Rare (badge)"]) or ""),
    pill = (k.caught or 0) > 0 and { tostring(k.caught), "green" } or nil })
  text[#text + 1] = name
  d:Begin()
  d:Section(L["Your catches"]) text[#text + 1] = L["Your catches"]
  if (k.caught or 0) > 0 then
    Line(L["Caught"], tostring(k.caught))
    Line(L["First catch"], ShortDate(k.first) .. ", " .. ZoneName(k.fz))
    Line(L["Last catch"], ShortDate(k.last) .. ", " .. ZoneName(k.lz))
  else
    Line(L["Caught"], L["not yet"], KC.yellow)
  end
  d:Section(L["Where it bites"]) text[#text + 1] = L["Where it bites"]
  local entries = {}
  for i = 1, math.min(5, #k.zones) do
    local z = k.zones[i]
    local pct = Style.Percent(z.share) .. (z.classic and ("  " .. L["(Classic)"]) or "")
    entries[#entries + 1] = { key = z.map, text = ZoneName(z.map), value = z.share, value2 = z.share, right = Style.Percent(z.share),
      color = z.classic and KC.grey or KC.gold, tooltip = { ZoneName(z.map), { pct } } }
    text[#text + 1] = ZoneName(z.map) .. " " .. pct
  end
  if #entries > 0 then
    P.barList:SetEntries(entries, 1)
    d:Block(P.barList, #entries * 18)
  else
    Line(L["unknown"], "")
  end
  if k.minSkill then Line(L["Skill needed"], tostring(k.minSkill)) end
  d:Section(L["Value"]) text[#text + 1] = L["Value"]
  local sell = Num(ns.GetSellPrice and ns.GetSellPrice(k.id))
  Line(L["Vendor"], Coins(sell) or "-")
  if ns.AuctionPricesOn and ns.AuctionPricesOn() then Line(L["Auction house"], Coins(ns.AuctionPrice(k.id)) or L["no price"]) end
  if k.classic then d:Space(4) d:Line(L["Classic data, not confirmed for Forever yet"], KC.muted) text[#text + 1] = L["Classic data, not confirmed for Forever yet"] end
  d:End()
  P.detailText = table.concat(text, "\n")
end

local function RenderAtlas(reset)
  local list = SortedKinds()
  local kinds, caught, rare, rareCaught = 0, 0, 0, 0
  local total = TotalSkill()
  local nextNew, byId = nil, {}
  for _, k in ipairs(list) do
    byId[k.id] = k
    kinds = kinds + 1
    local c = (k.caught or 0) > 0
    if c then caught = caught + 1 end
    local q = Quality(k.id)
    if q and q >= (ns.RARE_QUALITY or 2) then rare = rare + 1 if c then rareCaught = rareCaught + 1 end end
    if not c and k.minSkill and k.minSkill <= total and k.zones[1] and (not nextNew or k.zones[1].share > nextNew.zones[1].share) then nextNew = k end
  end
  local t = P.atiles
  t[1]:SetData(L["Kinds caught"], ("%d / %d"):format(caught, kinds), L["fish and containers known so far"])
  t[1]:SetProgress(kinds > 0 and caught / kinds or nil, "green")
  t[2]:SetData(L["Rare kinds"], ("%d / %d"):format(rareCaught, rare), "")
  t[3]:SetData(L["Next new one"], nextNew and ItemName(nextNew.id) or "-", nextNew and ZoneName(nextNew.zones[1].map) or "")
  local counts = { all = kinds, caught = caught, missing = kinds - caught }
  for _, chip in ipairs(P.achips.chips) do chip:SetCount((counts[chip.key] or 0) > 0 and counts[chip.key] or nil) end
  P.achips:SetActive(afilter)
  if not selKind or not byId[selKind] then selKind = list[1] and list[1].id or nil end
  FillDetail(selKind and byId[selKind])
  local full = (P.mode or "full") == "full"
  P.cols = Kit.ItemCardCols((P.bw or 976) - (full and DETAIL_W or 0), CARD_MIN)
  local items, n = AtlasItems(list, P.cols)
  book:SetStatus(L["Kinds caught"] .. ": " .. caught .. " / " .. kinds .. "  ·  " .. n)
  lists.atlas:SetEmpty(L["Nothing for this filter."])
  lists.atlas:SetItems(items, reset)
end

local function RenderWaters(reset)
  local here = HereZone()
  local m = selZone or here
  lists.zones:SetEmpty(L["No zone found."])
  lists.zones:SetItems(ZoneListItems(), false)
  local need = m and ns.ZONE_SKILL and ns.ZONE_SKILL[m]
  local total = TotalSkill()
  local meta
  if need then
    meta = L["Skill %d needed, yours %d"]:format(need, total) .. "  ·  "
      .. (total >= need and L["nothing gets away"] or L["%d points missing"]:format(need - total))
  elseif m and ns.IsNewForeverZone and ns.IsNewForeverZone(m) then
    meta = L["New Forever zone: skill needed not published yet."]
  else
    meta = L["Skill needed not known"]
  end
  local items, kinds, caughtKinds, empty
  if zoneSeg == "sessions" then
    items = ZoneSessionItems(m)
    local _, k, c = ZoneFishItems(m)
    kinds, caughtKinds = k, c
    empty = L["No sessions in this zone yet."]
  else
    items, kinds, caughtKinds, empty = ZoneFishItems(m)
  end
  P.hero:SetData({ kicker = meta, title = m and ZoneName(m) or L["unknown"], value = ("%d / %d"):format(caughtKinds or 0, kinds or 0),
    label = L["kinds caught here"], progress = (kinds or 0) > 0 and math.min(1, (caughtKinds or 0) / kinds) or nil })
  P.hero.kicker:SetTextColor(need and total < need and KC.red[1] or KC.txGold[1], need and total < need and KC.red[2] or KC.txGold[2],
    need and total < need and KC.red[3] or KC.txGold[3], 1)
  if m ~= P.hero.map.artMap then DrawMapArt(P.hero.map, m, P.main:GetWidth() or (P.bw or 976) - SIDE_W, HERO_H) P.hero.map.artMap = m end
  local z = ns.db.zones and ns.db.zones[m]
  local casts, gotAway, fishN = 0, 0, 0
  if type(z) == "table" then
    casts, gotAway = Num(z.casts) or 0, Num(z.getaways) or 0
    for _, n in pairs(type(z.fish) == "table" and z.fish or {}) do fishN = fishN + (Num(n) or 0) end
  end
  local sessions, a, f = SessionsIn(m)
  -- value of everything you caught here (same source as "Fish"); per hour from the sessions
  local value = 0
  if type(z) == "table" and type(z.fish) == "table" then
    for id, n in pairs(z.fish) do value = value + (Num(ns.GetSellPrice and ns.GetSellPrice(id)) or 0) * (Num(n) or 0) end
  end
  local parts = { L["Casts %s"]:format(Style.Number(casts)), L["Fish %s"]:format(Style.Number(fishN)) }
  if casts > 0 then parts[#parts + 1] = L["Got away %s"]:format(Style.Percent(gotAway / casts)) end
  local rate = Rate(f, a)
  if rate then parts[#parts + 1] = L["%d per hour"]:format(rate) end
  if value > 0 then parts[#parts + 1] = L["Value %s"]:format(Coins(value) or "0") end
  P.stats:SetText(table.concat(parts, "    "))
  P.seg.fields[1].text:SetText(L["Fish here"] .. "  " .. (kinds or 0))
  P.seg.fields[2].text:SetText(L["Your sessions here"] .. "  " .. #sessions)
  P.seg:Update()
  if selZone ~= nil and selZone ~= here then P.segHere:Show() else P.segHere:Hide() end
  book:SetStatus(L["Fish %s"]:format(Style.Number(fishN)) .. "  ·  " .. ZoneName(m))
  lists.waters:SetEmpty(empty or L["Nothing for this filter."])
  lists.waters:SetItems(items, reset)
end

local lastTab
function Refresh(reset)
  if not book or not book:IsShown() then return end
  for key, page in pairs(P.pages) do if key == tab then page:Show() else page:Hide() end end
  for _, t in ipairs(book.tabs) do t:SetSelected(t.key == tab) end
  book.tab = tab
  if tab ~= lastTab then reset = true lastTab = tab end
  if tab == "log" then RenderLog(reset) elseif tab == "atlas" then RenderAtlas(reset) else RenderWaters(reset) end
  LayoutPages()
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function ns.UpdateBook() if book and book:IsShown() then Refresh(false) end end

-- which: "log", "atlas" or "waters" (nil: the last one); mapID: the zone on Waters.
-- (1.5.0) the book opens on the tab you left it on, also after /reload
local function LastTab()
  local t = ns.db and ns.db.bookTab
  if TAB_TITLE[t] then return t end
end
function ns.OpenBook(which, mapID)
  if not book then Create() tab = LastTab() or tab end
  if not book then return end
  which = TAB_TITLE[which] and which or tab
  if mapID then selZone = mapID zoneSeg = "fish" end
  tab = which
  if ns.db then ns.db.bookTab = tab end
  if not book:IsShown() then book:Show() end
  Refresh(true)
end

function ns.ToggleBook(which)
  if not book then Create() tab = LastTab() or tab end
  if not book then return end
  if book:IsShown() and (which == nil or which == tab) then book:Hide() return end
  ns.OpenBook(which)
end
function ns.BookTab() return tab end
function ns.BookParts() return P end -- (tests)
function ns.BookZone() return selZone or HereZone() end
function ns.BookFilter(key) if key then lfilter = key Refresh(true) end return lfilter end
function ns.BookAtlasFilter(key) if key then afilter = key Refresh(true) end return afilter end
function ns.BookSelectKind(id) selKind = id Refresh() end
function ns.BookSegment(key) if key then zoneSeg = key Refresh(true) end return zoneSeg end
function ns.BookItems(which) local l = lists[which or tab] return l and l.items or {} end
function ns.BookLines(which) local l = lists[which or tab] return l and l:Rows() or {} end
function ns.BookDetailText() return P.detailText or "" end
function ns.BookLogMap() local jm = P.lmap return jm and jm.m, jm and jm.artMap end
function ns.BookArt() local h = P.hero and P.hero.map return h and ("map %s, %d tiles drawn"):format(tostring(h.artMap), h.artDrawn or 0) or "not built" end

local pending
local function Queue()
  if not (book and book:IsShown()) or pending then return end
  pending = true
  C_Timer.After(0.5, ns.Safe("book refresh", function() pending = false ns.UpdateBook() end))
end
ns.On("BAG_UPDATE_DELAYED", Queue)
ns.On("CHAT_MSG_SKILL", Queue)
ns.On("ZONE_CHANGED_NEW_AREA", Queue)
ns.On("GET_ITEM_INFO_RECEIVED", Queue)
ns.On("LOOT_CLOSED", Queue)

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
--              the share at Wowhead next to your own.
--
-- Sessions: LuredonDB.book.chars[character] = { e = { entries }, open = running
-- session, ms = { [cap] = true }, best = { fph, t, z } }. A session starts with
-- the first cast and ends when the pole goes back into the bags or after
-- GAP seconds without fishing. Only numbers and item IDs, no names.
-- The kinds of fish come from the catch log (Log.lua) and the zone lists
-- (Data_Fish.lua, Wowhead Forever; above level 30 Wowhead Classic).
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
-- Window helpers (the family kit's colours; our own frames)
---------------------------------------------------------------------------
-- (1.4.1, Daniel 09.10.) the look of Questdon's quest book 1.3.4: navy to violet,
-- a gold frame with ornaments in the corners, gold-framed tabs, every line as
-- a card, the zone you fish in round in a gold ring, statistic cards.
local W, H = 980, 640
local HEADER_H = 42
local SIDE_W = 232
local HERO_H = 116
local JHERO_H = 188 -- logbook: round map and four statistic cards
local TILE_H = 70
local DETAIL_W = 272
local ROW_H, HEAD_H = 46, 30
local CARD_H = 72
local COLS = 3
local MEDIA = "Interface\\AddOns\\Luredon\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local TABS = { "log", "atlas", "waters" }
local TAB_TITLE = { log = L["Logbook"], atlas = L["Fish atlas"], waters = L["Waters"] }
local TAB_ICON = { log = "Interface\\Icons\\INV_Misc_Book_09", atlas = "Interface\\Icons\\INV_Misc_Fish_02", waters = "Interface\\Icons\\Trade_Fishing" }
local QCOLOR = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0.29, 0.64, 1 }, [4] = { 0.76, 0.49, 1 }, [5] = { 1, 0.5, 0 } }

local book
local tab = "log"
local lists, P = {}, {}
local lfilter, afilter = "all", "all"
local selKind, selZone
local zoneSeg = "fish"
local zoneQuery = ""
local showHigher = false
local Refresh

-- The book's own colours, the same as Questdon's quest book (the panel and the
-- other windows keep Style.COLORS).
local THEME = {
  background    = { 0.10, 0.11, 0.22 },
  backgroundLow = { 0.15, 0.10, 0.25 },
  header        = { 0.07, 0.08, 0.17 },
  textPrimary   = { 0.96, 0.92, 0.84 },
  textSecondary = { 0.80, 0.76, 0.68 },
  textHint      = { 0.58, 0.57, 0.66 },
  gold          = { 0.86, 0.71, 0.42 },
  goldLight     = { 0.97, 0.87, 0.60 },
  goldDark      = { 0.42, 0.30, 0.14 },
  accent        = { 0.40, 0.68, 0.98 },
  good          = { 0.47, 0.84, 0.44 },
  warning       = { 0.98, 0.80, 0.34 },
  critical      = { 0.93, 0.40, 0.36 },
  divider       = { 0.86, 0.71, 0.42, 0.22 },
  rowHover      = { 1, 1, 1, 0.05 },
  rowActive     = { 0.86, 0.71, 0.42, 0.16 },
  barBackground = { 1, 1, 1, 0.09 },
  card          = { 0.17, 0.21, 0.40 },
  cardLow       = { 0.11, 0.13, 0.28 },
  cardEdge      = { 0.86, 0.71, 0.42, 0.30 },
  violet        = { 0.66, 0.36, 0.95 },
  cyan          = { 0.30, 0.86, 0.95 },
}
for _, c in pairs(THEME) do
  c.hex = string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end
ns.BOOK_THEME = THEME -- (tests)

local function RGB(c) if type(c) == "string" then c = THEME[c] or C[c] end return c or THEME.textPrimary end
-- Coloured text in the book's colours.
local function Colorize(text, color)
  local c = RGB(color)
  local hex = c.hex or string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
  return "|c" .. hex .. tostring(text or "") .. "|r"
end
local function Fill(tex, color, alpha)
  local c = RGB(color)
  if tex.SetColorTexture then tex:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
  else tex:SetTexture(WHITE) tex:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1) end
end
local function Tex(parent, layer, color, alpha, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
  if color then Fill(t, color, alpha) end
  return t
end
-- A colour gradient on a texture (vertical: c1 at the bottom, c2 at the top); plain fill if the client cannot.
local function Gradient(tex, orientation, c1, a1, c2, a2)
  local x, y = RGB(c1), RGB(c2)
  if tex.SetGradient and CreateColor then
    if not tex:GetTexture() then Fill(tex, { 1, 1, 1 }, 1) end
    local ok = pcall(tex.SetGradient, tex, orientation, CreateColor(x[1], x[2], x[3], a1 or 1), CreateColor(y[1], y[2], y[3], a2 or 1))
    if ok then return end
  end
  Fill(tex, c2, a2)
end
-- Rounded cards: the client cuts our 64 px texture into nine parts
-- (SetTextureSliceMargins); an older client gets a plain card with thin edges.
local SLICE
local function CanSlice(tex)
  if SLICE == nil then SLICE = type(tex.SetTextureSliceMargins) == "function" end
  return SLICE
end
local function CardTex(parent, layer, file, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  if CanSlice(t) and t:SetTexture(MEDIA .. file) ~= false then
    if not pcall(t.SetTextureSliceMargins, t, 12, 12, 12, 12) then SLICE = false end
    if SLICE and t.SetTextureSliceMode then pcall(t.SetTextureSliceMode, t, 0) end
  end
  return t
end
-- A card behind a line or tile: f.cardFill, f.cardEdge (or four lines), inset from the frame's edges.
local function Card(f, inset, insetY)
  inset, insetY = inset or 0, insetY or 0
  f.cardFill = CardTex(f, "BACKGROUND", "CardFill", 1)
  f.cardFill:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -insetY)
  f.cardFill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, insetY)
  if SLICE then
    f.cardEdge = CardTex(f, "BORDER", "CardBorder", 1)
    f.cardEdge:SetAllPoints(f.cardFill)
  else
    f.cardFill:SetTexture(WHITE)
    f.cardLines = {}
    local fl = f.cardFill
    local function Line(a, b, horiz)
      local t = f:CreateTexture(nil, "BORDER")
      t:SetTexture(WHITE)
      t:SetPoint(a, fl, a) t:SetPoint(b, fl, b)
      if horiz then t:SetHeight(1) else t:SetWidth(1) end
      f.cardLines[#f.cardLines + 1] = t
    end
    Line("TOPLEFT", "TOPRIGHT", true) Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line("TOPLEFT", "BOTTOMLEFT") Line("TOPRIGHT", "BOTTOMRIGHT")
  end
  local function Edge(self, edge, edgeAlpha)
    local e = RGB(edge or "cardEdge")
    local ea = edgeAlpha or e[4] or 1
    if self.cardEdge then self.cardEdge:SetVertexColor(e[1], e[2], e[3], ea) end
    for _, t in ipairs(self.cardLines or {}) do t:SetVertexColor(e[1], e[2], e[3], ea) end
  end
  function f:SetCardLook(fillTop, fillBottom, fillAlpha, edge, edgeAlpha)
    self._look = { fillTop, fillBottom, fillAlpha, edge, edgeAlpha }
    Gradient(self.cardFill, "VERTICAL", fillBottom or "cardLow", fillAlpha or 0.92, fillTop or "card", fillAlpha or 0.92)
    Edge(self, edge, edgeAlpha)
  end
  -- mouse over: a brighter gold edge
  function f:SetCardHover(on)
    local l = self._look or {}
    if on then Edge(self, "goldLight", 0.85) else Edge(self, l[4], l[5]) end
  end
  f:SetCardLook()
  return f
end
-- Thin edges around a region (icon frames, badges).
local function Edges(f, region, color, alpha, layer)
  local out = {}
  local function Line(p1, p2, horiz)
    local t = f:CreateTexture(nil, layer or "BORDER")
    t:SetTexture(WHITE)
    t:SetPoint(p1, region, p1) t:SetPoint(p2, region, p2)
    if horiz then t:SetHeight(1) else t:SetWidth(1) end
    out[#out + 1] = t
  end
  Line("TOPLEFT", "TOPRIGHT", true) Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
  Line("TOPLEFT", "BOTTOMLEFT") Line("TOPRIGHT", "BOTTOMRIGHT")
  function out:SetColor(col, a)
    local cc = RGB(col)
    for _, t in ipairs(self) do t:SetVertexColor(cc[1], cc[2], cc[3], a or cc[4] or 1) end
  end
  out:SetColor(color, alpha)
  return out
end
local fontPath
local function FontPath()
  if fontPath then return fontPath end
  local obj = _G.GameFontHighlightSmall
  local ok, path = false, nil
  if type(obj) == "table" and type(obj.GetFont) == "function" then ok, path = pcall(obj.GetFont, obj) end
  fontPath = (ok and type(path) == "string" and path) or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
  return fontPath
end
local function SetColor(fs, color, alpha) local c = RGB(color) fs:SetTextColor(c[1], c[2], c[3], alpha or 1) end
local function Text(parent, size, color, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlightSmall")
  if size and fs.SetFont then pcall(fs.SetFont, fs, FontPath(), size, "") end
  SetColor(fs, color or "textPrimary")
  if justify then fs:SetJustifyH(justify) end
  fs:SetWordWrap(false)
  return fs
end
local function Icon(parent, size, file, layer)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetSize(size, size)
  if file and t:SetTexture(file) == false then t:SetTexture(WHITE) end
  return t
end
local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function TextWidth(fs)
  local w = Num(fs.GetStringWidth and fs:GetStringWidth())
  if w and w > 0 then return w end
  return #Plain(fs:GetText()) * 6
end
local function Border(f, color, alpha)
  local t = Tex(f, "BORDER", color, alpha) t:SetPoint("TOPLEFT") t:SetPoint("TOPRIGHT") t:SetHeight(1)
  local b = Tex(f, "BORDER", color, alpha) b:SetPoint("BOTTOMLEFT") b:SetPoint("BOTTOMRIGHT") b:SetHeight(1)
  local l = Tex(f, "BORDER", color, alpha) l:SetPoint("TOPLEFT") l:SetPoint("BOTTOMLEFT") l:SetWidth(1)
  local r = Tex(f, "BORDER", color, alpha) r:SetPoint("TOPRIGHT") r:SetPoint("BOTTOMRIGHT") r:SetWidth(1)
end
local function PassRight(f) if ns.RightClickThrough then ns.RightClickThrough(f) end end

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
local function QName(id)
  local q = Quality(id)
  local c = QCOLOR[q or 1] or QCOLOR[1]
  return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, ItemName(id)), q
end
local COIN = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
local function Coins(copper, size)
  copper = Num(copper)
  if not copper or copper <= 0 then return nil end
  copper = math.floor(copper)
  local parts = { math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100 }
  local out, icon = {}, ":" .. (size or 0) .. ":" .. (size or 0) .. ":2:0|t"
  for i, n in ipairs(parts) do if n > 0 then out[#out + 1] = n .. "|T" .. COIN[i] .. icon end end
  return table.concat(out, " ")
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

-- (i18n) A text in a fixed space (Style.FitText): first a little smaller, then
-- cut with "..."; the whole text then shows in the tooltip of its line or tile.
local function Fit(fs, budget, owner)
  local ok = Style.FitText(fs, budget)
  if owner then
    owner._cut = owner._cut or {}
    owner._cut[fs] = (not ok) and Style.FullText(fs) or nil
  end
  return ok
end
local function ShowCut(owner)
  if type(owner._cut) ~= "table" then return false end
  local out = {}
  for _, t in pairs(owner._cut) do out[#out + 1] = t end
  if #out == 0 then return false end
  table.sort(out)
  local rest = {}
  for i = 2, #out do rest[#rest + 1] = out[i] end
  Style.Tooltip(owner, out[1], rest, nil, "ANCHOR_RIGHT")
  return true
end
local function CutTip(f)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self) ShowCut(self) end)
  f:SetScript("OnLeave", function(self) Style.HideTooltip(self) end)
end
-- Width of a list line: its real width in the game, else what the layout gives it.
local function RowW(f)
  local w = Num(f.GetWidth and f:GetWidth())
  if w and w > 50 then return w end
  return (f._list and f._list.rowW) or (W - 20)
end

local function Clickable(f)
  f:EnableMouse(true)
  f.hover = Tex(f, "BACKGROUND", "rowHover", nil, 1)
  f.hover:SetAllPoints(f)
  f.hover:Hide()
  if f.RegisterForClicks then f:RegisterForClicks("LeftButtonUp") end
  f:SetScript("OnEnter", function(self)
    if self.onClick or self.tooltip then
      if self.SetCardHover and self.cardFill:IsShown() then self:SetCardHover(true) else self.hover:Show() end
    end
    if self.tooltip then
      local ok, title, lines, hint = pcall(self.tooltip, self)
      if ok and title then Style.Tooltip(self, title, lines, hint, "ANCHOR_RIGHT") end
    else
      ShowCut(self)
    end
  end)
  f:SetScript("OnLeave", function(self)
    self.hover:Hide()
    if self.SetCardHover then self:SetCardHover(false) end
    Style.HideTooltip(self)
  end)
  f:SetScript("OnClick", function(self, button) if self.onClick then ns.Call("book click", self.onClick, self, button) end end)
  PassRight(f)
end

---------------------------------------------------------------------------
-- Virtual list (only the lines in sight are frames; mouse wheel scrolls)
---------------------------------------------------------------------------
local function NewList(parent, factories, rowW)
  local list = CreateFrame("Frame", nil, parent)
  list.rowW = rowW -- width of a line when the game cannot tell yet (layout constants)
  list.items, list.offset, list.pools, list.used, list.factories = {}, 1, {}, {}, factories
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-(tonumber(delta) or 0) * 3) end)
  list.track = Tex(list, "ARTWORK", "barBackground")
  list.track:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, 0)
  list.track:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -1, 0)
  list.track:SetWidth(3)
  list.thumb = Tex(list, "OVERLAY", "textHint", 0.9)
  list.thumb:SetWidth(3)
  list:SetScript("OnSizeChanged", function(self) self:Render() end)
  function list:Height() local h = Num(self:GetHeight()) or 0 if h <= 1 then h = 420 end return h end
  function list:SetItems(items, keep) self.items = items or {} if not keep then self.offset = 1 end self:Render() end
  function list:MaxOffset()
    local h, sum = self:Height(), 0
    for i = #self.items, 1, -1 do sum = sum + (self.items[i].h or ROW_H) if sum > h then return math.min(#self.items, i + 1) end end
    return 1
  end
  function list:Scroll(d)
    local o = math.max(1, math.min(self:MaxOffset(), self.offset + d))
    if o ~= self.offset then self.offset = o self:Render() end
  end
  function list:Acquire(kind)
    local pool = self.pools[kind]
    if not pool then pool = {} self.pools[kind] = pool end
    for _, r in ipairs(pool) do if not r.inUse then r.inUse = true return r end end
    local r = self.factories[kind].create(self)
    r._list = self
    r.inUse = true
    pool[#pool + 1] = r
    return r
  end
  function list:Render()
    for _, r in ipairs(self.used) do r:Hide() r.inUse = false end
    self.used = {}
    local h, y = self:Height(), 0
    if self.offset > self:MaxOffset() then self.offset = self:MaxOffset() end
    for i = self.offset, #self.items do
      local it = self.items[i]
      local ih = it.h or ROW_H
      if y > 0 and y + ih > h + 0.5 then break end
      local row = self:Acquire(it.kind)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
      row:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -y)
      row:SetHeight(ih)
      row.item = it
      row:Show()
      ns.Call("book row", self.factories[it.kind].render, row, it)
      self.used[#self.used + 1] = row
      y = y + ih
    end
    local total, before = 0, 0
    for i, it in ipairs(self.items) do
      total = total + (it.h or ROW_H)
      if i < self.offset then before = before + (it.h or ROW_H) end
    end
    if total <= h then self.thumb:Hide() self.track:Hide()
    else
      local th = math.max(18, h * h / total)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", -1, -(h - th) * math.min(1, before / math.max(1, total - h)))
      self.thumb:SetHeight(th)
      self.thumb:Show() self.track:Show()
    end
  end
  return list
end

---------------------------------------------------------------------------
-- Line kinds
---------------------------------------------------------------------------
local HeadKind = {
  create = function(list)
    local f = CreateFrame("Button", nil, list)
    Clickable(f)
    f.text = Text(f, 12, "gold", "LEFT")
    f.text:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 7)
    f.count = Text(f, 11, "textHint", "LEFT")
    f.count:SetPoint("LEFT", f.text, "RIGHT", 6, 0)
    f.right = Text(f, 11, "textHint", "RIGHT")
    f.right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 7)
    f.line = Tex(f, "ARTWORK", "divider")
    f.line:SetHeight(1)
    return f
  end,
  render = function(f, it)
    f.text:SetText(it.text or "")
    SetColor(f.text, (it.color == nil or it.color == "textPrimary" or it.color == "textSecondary") and "gold" or it.color)
    f.count:SetText(it.count and tostring(it.count) or "")
    f.right:SetText(it.right or "")
    local rw = RowW(f)
    local rightW = 0
    if it.right and it.right ~= "" then Fit(f.right, rw * 0.5, f) rightW = TextWidth(f.right) + 16 end
    local countW = it.count and (TextWidth(f.count) + 6) or 0
    Fit(f.text, rw - 40 - countW - rightW, f)
    f.line:ClearAllPoints()
    f.line:SetPoint("LEFT", f.count, "RIGHT", 8, 0)
    if it.right and it.right ~= "" then f.line:SetPoint("RIGHT", f.right, "LEFT", -8, 0) else f.line:SetPoint("RIGHT", f, "RIGHT", -10, 0) end
    f.onClick, f.tooltip = it.onClick, it.tooltip
  end,
}

local EmptyKind = {
  create = function(list)
    local f = CreateFrame("Frame", nil, list)
    f.text = Text(f, 12, "textHint", "CENTER")
    f.text:SetPoint("LEFT", f, "LEFT", 10, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.text:SetWordWrap(true) -- (i18n) a long note wraps instead of being cut
    return f
  end,
  render = function(f, it) f.text:SetText(it.text or "") SetColor(f.text, it.color or "textHint") end,
}

-- Logbook line (1.4.1: a card as in Questdon's journal): time on the left, a
-- round mark in a gold ring (the fish for a rare catch), title and details,
-- value on the right. Skill milestones as a golden card, records and rare
-- catches with a coloured edge.
local BAND = { r = "accent", m = "warning", x = "goldLight" }
local EntryKind = {
  create = function(list)
    local f = CreateFrame("Button", nil, list)
    Card(f, 4, 3)
    Clickable(f)
    f.time = Text(f, 11, "textHint", "LEFT")
    f.time:SetPoint("LEFT", f, "LEFT", 16, 0)
    f.disc = Icon(f, 24, CIRCLE, "ARTWORK")
    f.disc:SetPoint("CENTER", f, "LEFT", 72, 0)
    local d = THEME.cardLow
    f.disc:SetVertexColor(d[1] * 0.7, d[2] * 0.7, d[3] * 0.7, 1)
    f.ring = Icon(f, 30, MEDIA .. "BookRing", "ARTWORK")
    f.ring:SetPoint("CENTER", f.disc, "CENTER", 0, 0)
    f.dot = Icon(f, 9, CIRCLE, "OVERLAY")
    f.dot:SetPoint("CENTER", f.disc, "CENTER", 0, 0)
    f.icon = Icon(f, 20, nil, "OVERLAY")
    f.icon:SetPoint("CENTER", f.disc, "CENTER", 0, 0)
    if f.icon.SetTexCoord then f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if f.icon.AddMaskTexture and f.CreateMaskTexture then
      local ok, mask = pcall(f.CreateMaskTexture, f)
      if ok and mask then
        pcall(mask.SetTexture, mask, CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(f.icon)
        pcall(f.icon.AddMaskTexture, f.icon, mask)
      end
    end
    f.title = Text(f, 14, "textPrimary", "LEFT")
    f.sub = Text(f, 11, "textHint", "LEFT")
    f.r1 = Text(f, 14, "warning", "RIGHT")
    f.r1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -9)
    f.r2 = Text(f, 11, "textSecondary", "RIGHT")
    f.r2:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 9)
    return f
  end,
  render = function(f, it)
    local e = it.e
    f.time:SetText(e.t and Clock(e.t) or "")
    local band = BAND[e.k]
    if e.k == "m" then f:SetCardLook("goldDark", "cardLow", 0.92, "gold", 0.75)
    elseif band then f:SetCardLook("card", "cardLow", 0.92, band, 0.6)
    else f:SetCardLook() end
    local dc = RGB(band or "accent")
    f.dot:SetVertexColor(dc[1], dc[2], dc[3], 1)
    f.dot:Show()
    f.icon:Hide()
    local title, sub, r1, r2
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
      r1 = Coins(e.v)
      if e.ah then r2 = L["AH %s"]:format(Coins(e.ah) or "0") end
    elseif e.k == "r" then
      local name = QName(e.id)
      title = L["Rare catch: %s"]:format(name)
      sub = ZoneName(e.z)
      f.icon:SetTexture(ItemIcon(e.id))
      f.icon:Show()
      f.dot:Hide()
    elseif e.k == "m" then
      local ms = ns.MILESTONES and ns.MILESTONES[e.rank]
      title = Colorize(L["Fishing skill %d: next rank needed"]:format(Num(e.rank) or 0), "warning")
      sub = ms and L[ms.text] or ""
    elseif e.k == "x" then
      title = Colorize(L["New record: %s fish per hour"]:format(ns.Decimal and ns.Decimal(e.v, 1) or tostring(e.v)), "accent")
      sub = L["old best %s, %s in %s"]:format(ns.Decimal and ns.Decimal(e.old, 1) or tostring(e.old), ShortDate(e.ot), ZoneName(e.oz))
    end
    f.title:SetText(title or "")
    f.sub:SetText(sub or "")
    f.r1:SetText(r1 or "")
    f.r2:SetText(r2 or "")
    f.r1:ClearAllPoints()
    if not r2 then f.r1:SetPoint("RIGHT", f, "RIGHT", -18, 0) else f.r1:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -9) end
    Fit(f.r1, 120, f) Fit(f.r2, 120, f)
    f.title:ClearAllPoints()
    f.sub:ClearAllPoints()
    local left, rightW = 96, (r1 or r2) and 136 or 18
    Fit(f.title, RowW(f) - left - rightW, f) Fit(f.sub, RowW(f) - left - rightW, f)
    local h = Num(f:GetHeight()) or it.h or ROW_H
    local top = math.floor((h - 32) / 2)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", left, -top - 1)
    f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rightW, -top - 1)
    f.sub:SetPoint("TOPLEFT", f, "TOPLEFT", left, -top - 18)
    f.sub:SetPoint("TOPRIGHT", f, "TOPRIGHT", -rightW, -top - 18)
    f.onClick = e.z and function() if ns.OpenBook then ns.OpenBook("waters", e.z) end end or nil
    f.tooltip = function()
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
          local names = {}
          for _, id in ipairs(e.nw) do names[#names + 1] = ItemName(id) end
          lines[#lines + 1] = { header = L["First catches"] }
          for _, n in ipairs(names) do lines[#lines + 1] = { n } end
        end
      elseif e.k == "r" then
        lines[#lines + 1] = { L["Zone"], ZoneName(e.z) }
      end
      return Plain(title or ""), lines, e.z and L["Click: show the zone on the tab Waters."] or nil
    end
  end,
}

-- A row of up to four kind cards (fish atlas).
local function CardCreate(parent)
  local c = CreateFrame("Button", nil, parent)
  Card(c, 0, 0)
  c.sel = Tex(c, "BACKGROUND", "rowActive", nil, 2)
  c.sel:SetAllPoints(c.cardFill)
  Clickable(c)
  c.frame = Tex(c, "ARTWORK", "cardLow", 0.95)
  c.frame:SetSize(44, 44)
  c.frame:SetPoint("LEFT", c, "LEFT", 10, 0)
  c.frameEdge = Edges(c, c.frame, "gold", 0.55, "ARTWORK")
  c.icon = Icon(c, 40, nil, "OVERLAY")
  c.icon:SetPoint("CENTER", c.frame, "CENTER", 0, 0)
  c.name = Text(c, 13, "textPrimary", "LEFT")
  c.name:SetPoint("TOPLEFT", c.frame, "TOPRIGHT", 10, -4)
  c.name:SetPoint("RIGHT", c, "RIGHT", -8, 0)
  c.sub = Text(c, 11, "textHint", "LEFT")
  c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -5)
  c.sub:SetPoint("RIGHT", c, "RIGHT", -8, 0)
  c.new = Text(c, 10, "warning", "RIGHT")
  c.new:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 6)
  return c
end
local CardsKind = {
  create = function(list)
    local f = CreateFrame("Frame", nil, list)
    f.cards = {}
    for i = 1, COLS do f.cards[i] = CardCreate(f) end
    return f
  end,
  render = function(f, it)
    local w = RowW(f) - 12
    local each = (w - (COLS - 1) * 8) / COLS
    for i, c in ipairs(f.cards) do
      local k = it.kinds[i]
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", f, "TOPLEFT", 6 + (i - 1) * (each + 8), -4)
      c:SetSize(each, CARD_H - 8)
      if not k then c:Hide() else
        c:Show()
        local name = QName(k.id)
        c.icon:SetTexture(ItemIcon(k.id))
        c.name:SetText(name)
        local caught = (k.caught or 0) > 0
        if caught then
          c.sub:SetText(L["%s · first %s"]:format(tostring(k.caught), ShortDate(k.first)))
          c.icon:SetDesaturated(false) c.icon:SetAlpha(1) c.name:SetAlpha(1) c.new:SetText("")
        else
          local z = k.zones[1]
          local where = z and (ZoneName(z.map) .. (z.share > 0 and ("  " .. Style.Percent(z.share)) or "")) or L["unknown"]
          c.sub:SetText(where .. (k.minSkill and ("  ·  " .. L["skill %d"]:format(k.minSkill)) or ""))
          c.icon:SetDesaturated(true) c.icon:SetAlpha(0.45) c.name:SetAlpha(0.6)
          c.new:SetText(k.classic and L["classic"] or L["new"])
          SetColor(c.new, k.classic and "textHint" or "warning")
        end
        Fit(c.new, 60, c)
        Fit(c.name, each - 72, c)
        local subRoom = each - 72 - (caught and 0 or TextWidth(c.new) + 4)
        if not Fit(c.sub, subRoom, c) and not caught and k.minSkill then
          -- (i18n) too long: the zone first, the skill is in the tooltip and the details
          Style.TextCuts[c.sub:GetText() or ""] = nil
          local z = k.zones[1]
          c.sub:SetText(z and (ZoneName(z.map) .. (z.share > 0 and ("  " .. Style.Percent(z.share)) or "")) or L["unknown"])
          Fit(c.sub, subRoom, c)
        end
        if selKind == k.id then
          c.sel:Show() c:SetCardLook("card", "cardLow", 0.98, "gold", 0.9)
        else
          c.sel:Hide()
          if caught then c:SetCardLook() else c:SetCardLook("cardLow", "cardLow", 0.7, "cardEdge", 0.18) end
        end
        c.frameEdge:SetColor(caught and "gold" or "textHint", caught and 0.6 or 0.3)
        c.onClick = function() selKind = k.id Refresh() end
        c.tooltip = function()
          local lines = {}
          if caught then
            lines[#lines + 1] = { L["Caught"], tostring(k.caught) }
            lines[#lines + 1] = { L["First catch"], ShortDate(k.first) .. ", " .. ZoneName(k.fz) }
          end
          for j = 1, math.min(4, #k.zones) do
            local z = k.zones[j]
            lines[#lines + 1] = { ZoneName(z.map), Style.Percent(z.share) .. (z.classic and (" " .. L["(Classic)"]) or "") }
          end
          return Plain(name), lines, L["Click: details on the right."]
        end
      end
    end
  end,
}

-- Zone in the list on the left (Waters): name, skill badge.
local ZoneKind = {
  create = function(list)
    local f = CreateFrame("Button", nil, list)
    Clickable(f)
    f.sel = Tex(f, "BACKGROUND", "rowActive", nil, 2)
    f.sel:SetAllPoints(f)
    f.bar = Tex(f, "ARTWORK", "gold")
    f.bar:SetPoint("TOPLEFT") f.bar:SetPoint("BOTTOMLEFT") f.bar:SetWidth(2)
    f.here = Icon(f, 7, CIRCLE, "OVERLAY")
    f.here:SetVertexColor(THEME.goldLight[1], THEME.goldLight[2], THEME.goldLight[3], 1)
    f.here:SetPoint("LEFT", f, "LEFT", 12, 0)
    f.name = Text(f, 12, "textSecondary", "LEFT")
    f.badgeText = Text(f, 11, "textPrimary", "CENTER")
    f.badgeText:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.badge = Tex(f, "ARTWORK", "good", 0.15)
    f.badge:SetPoint("TOPLEFT", f.badgeText, "TOPLEFT", -7, 4)
    f.badge:SetPoint("BOTTOMRIGHT", f.badgeText, "BOTTOMRIGHT", 7, -4)
    f.badgeEdge = Edges(f, f.badge, "good", 0.6, "ARTWORK")
    return f
  end,
  render = function(f, it)
    f.name:ClearAllPoints()
    f.name:SetPoint("LEFT", f, "LEFT", it.here and 24 or 12, 0)
    f.name:SetPoint("RIGHT", f.badge, "LEFT", -6, 0)
    f.name:SetText(it.name)
    SetColor(f.name, it.selected and "textPrimary" or "textSecondary")
    if it.here then f.here:Show() else f.here:Hide() end
    if it.selected then f.sel:Show() f.bar:Show() else f.sel:Hide() f.bar:Hide() end
    local color = it.need == nil and "textHint" or (it.ok and "good" or "critical")
    f.badgeText:SetText(it.need and tostring(it.need) or "?")
    Fit(f.name, RowW(f) - (it.here and 24 or 12) - 16 - 12 - TextWidth(f.badgeText) - 6, f)
    SetColor(f.badgeText, color)
    Fill(f.badge, color, it.need and 0.22 or 0.08)
    f.badgeEdge:SetColor(color, it.need and 0.7 or 0.3)
    f.onClick = function() selZone = it.map zoneSeg = "fish" Refresh(true) end
    f.tooltip = function()
      local lines = { { L["Skill needed"], it.need and tostring(it.need) or L["unknown"] } }
      local total = TotalSkill()
      if it.need then lines[#lines + 1] = { L["Your skill with bonus"], tostring(total), total >= it.need and "good" or "critical" } end
      return it.name, lines
    end
  end,
}

-- Fish of a zone (Waters): icon, name, two share bars (data, yours), count.
local FishKind = {
  create = function(list)
    local f = CreateFrame("Button", nil, list)
    Card(f, 4, 3)
    Clickable(f)
    f.frame = Tex(f, "ARTWORK", "cardLow", 0.95)
    f.frame:SetSize(32, 32)
    f.frame:SetPoint("LEFT", f, "LEFT", 14, 0)
    f.frameEdge = Edges(f, f.frame, "gold", 0.55, "ARTWORK")
    f.icon = Icon(f, 28, nil, "OVERLAY")
    f.icon:SetPoint("CENTER", f.frame, "CENTER", 0, 0)
    f.name = Text(f, 13, "textPrimary", "LEFT")
    f.name:SetPoint("LEFT", f.frame, "RIGHT", 10, 0)
    f.name:SetPoint("RIGHT", f, "RIGHT", -300, 0)
    f.t1 = Tex(f, "ARTWORK", "textPrimary", 0.07)
    f.t1:SetSize(200, 5)
    f.t1:SetPoint("RIGHT", f, "RIGHT", -88, 5)
    f.b1 = Tex(f, "OVERLAY", "textSecondary")
    f.b1:SetPoint("TOPLEFT", f.t1, "TOPLEFT") f.b1:SetPoint("BOTTOMLEFT", f.t1, "BOTTOMLEFT")
    f.t2 = Tex(f, "ARTWORK", "textPrimary", 0.07)
    f.t2:SetSize(200, 5)
    f.t2:SetPoint("RIGHT", f, "RIGHT", -88, -5)
    f.b2 = Tex(f, "OVERLAY", "good")
    f.b2:SetPoint("TOPLEFT", f.t2, "TOPLEFT") f.b2:SetPoint("BOTTOMLEFT", f.t2, "BOTTOMLEFT")
    f.pct = Text(f, 11, "textHint", "RIGHT")
    f.pct:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -9)
    f.cnt = Text(f, 11, "good", "RIGHT")
    f.cnt:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 9)
    return f
  end,
  render = function(f, it)
    local e = it.e
    f.icon:SetTexture(ItemIcon(e.id))
    f.name:SetText(QName(e.id) .. (e.kind == "c" and ("  " .. Colorize(L["(container)"], "textHint")) or ""))
    if e.share and e.share > 0 then f.b1:SetWidth(math.max(1, 200 * math.min(1, e.share))) f.b1:Show() else f.b1:Hide() end
    if it.own and it.own > 0 then f.b2:SetWidth(math.max(1, 200 * math.min(1, it.own))) f.b2:Show() else f.b2:Hide() end
    Fit(f.name, RowW(f) - 14 - 32 - 10 - 300, f)
    local caughtHere = (e.caught or 0) > 0
    if caughtHere then f:SetCardLook() else f:SetCardLook("cardLow", "cardLow", 0.7, "cardEdge", 0.18) end
    f.frameEdge:SetColor(caughtHere and "gold" or "textHint", caughtHere and 0.6 or 0.3)
    f.pct:SetText(e.share and Style.Percent(e.share) or "-")
    if (e.caught or 0) > 0 then f.cnt:SetText(tostring(e.caught)) SetColor(f.cnt, "good")
    else f.cnt:SetText(L["new"]) SetColor(f.cnt, "warning") end
    Fit(f.cnt, 70, f)
    f.onClick = function() selKind = e.id if ns.OpenBook then ns.OpenBook("atlas") end end
    f.tooltip = function()
      local lines = {}
      if e.share then
        local label = e.classic and L["Share (Wowhead Classic)"] or e.fromOwn and L["Share (Luredon's own catches)"] or L["Share (Wowhead)"]
        lines[#lines + 1] = { label, Style.Percent(e.share) }
      end
      if it.own then lines[#lines + 1] = { L["Your share here"], Style.Percent(it.own) } end
      lines[#lines + 1] = { L["Caught here"], (e.caught or 0) > 0 and tostring(e.caught) or L["not yet"] }
      return Plain(QName(e.id)), lines, L["Click: in the fish atlas."]
    end
  end,
}

local KINDS = { head = HeadKind, empty = EmptyKind, entry = EntryKind, cards = CardsKind, zone = ZoneKind, fish = FishKind }

---------------------------------------------------------------------------
-- Building the lists
---------------------------------------------------------------------------
local FILTERS = { "all", "s", "r", "m", "x", "zone" }
local FILTER_TITLE = { all = L["All"], s = L["Sessions"], r = L["Rare catches"], m = L["Skill"], x = L["Records"], zone = L["This zone"] }

local function HereZone() return ns.ZoneRequirement and ns.ZoneRequirement() end

local function LogItems()
  local items = {}
  local here = HereZone()
  local day
  for _, e in ipairs(ns.BookEntries()) do
    local keep = lfilter == "all" or e.k == lfilter or (lfilter == "zone" and e.z ~= nil and e.z == here)
    if keep then
      local key = DayKey(e.t)
      if key ~= day then
        day = key
        items[#items + 1] = { kind = "head", h = HEAD_H, text = DayTitle(e.t), color = "textPrimary" }
      end
      items[#items + 1] = { kind = "entry", h = ROW_H, e = e }
    end
  end
  if #items == 0 then
    items[1] = { kind = "empty", h = 70, text = lfilter == "all" and L["No sessions yet. Equip your pole and cast: every session is written down here."] or L["Nothing for this filter."] }
  end
  return items
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

local function AtlasItems(list)
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
  for i = 1, #shown, COLS do
    local row = {}
    for j = 0, COLS - 1 do row[#row + 1] = shown[i + j] end
    items[#items + 1] = { kind = "cards", h = CARD_H, kinds = row }
  end
  if #items == 0 then items[1] = { kind = "empty", h = 60, text = L["Nothing for this filter."] } end
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
      local row = { kind = "zone", h = 30, map = z.map, name = name, need = z.need, ok = z.need ~= nil and z.need <= total,
        here = z.map == here, selected = z.map == shown }
      if z.forever then forever[#forever + 1] = row
      elseif not z.need then unknown[#unknown + 1] = row
      elseif z.need <= total then ok[#ok + 1] = row
      elseif z.need == nextNeed then next[#next + 1] = row
      else higher[#higher + 1] = row end
    end
  end
  local function Sort(t) table.sort(t, function(a, b) if (a.need or 0) ~= (b.need or 0) then return (a.need or 0) < (b.need or 0) end return a.name < b.name end) end
  local function Group(title, rows, collapsible)
    if #rows == 0 then return end
    Sort(rows)
    local head = { kind = "head", h = HEAD_H, text = title, count = #rows }
    if collapsible then
      head.right = (showHigher or q ~= "") and "-" or "+"
      head.onClick = function() showHigher = not showHigher Refresh() end
    end
    items[#items + 1] = head
    if not collapsible or showHigher or q ~= "" then for _, r in ipairs(rows) do items[#items + 1] = r end end
  end
  Group(L["Your skill is enough"], ok)
  Group(L["Next step"], next)
  Group(L["New in Forever"], forever)
  Group(L["Higher"], higher, true)
  Group(L["Skill unknown"], unknown, true)
  if #items == 0 then items[1] = { kind = "empty", h = 50, text = L["No zone found."] } end
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
    items[#items + 1] = { kind = "empty", h = 26, text = L["Fish from Wowhead's Classic data, not confirmed for Forever yet."], color = "warning" }
  elseif ownList then -- (1.4.1) Zephras Isle
    items[#items + 1] = { kind = "empty", h = 26, text = L["Fish from Luredon's own catches, Wowhead has no list for this zone yet."], color = "textHint" }
  end
  if not list then
    items[#items + 1] = { kind = "empty", h = 60, text = L["No fish list for this zone yet."] }
    return items, 0, 0
  end
  if #list == 0 then items[#items + 1] = { kind = "empty", h = 60, text = L["No fishing waters known in this zone."] }
  else items[#items + 1] = { kind = "head", h = 22, text = L["Fish"], right = L["share: Wowhead (grey), yours (green)  ·  caught"] } end
  for _, e in ipairs(list) do
    items[#items + 1] = { kind = "fish", h = ROW_H, e = e, own = ownTotal > 0 and (e.caught or 0) / ownTotal or nil }
  end
  return items, kinds, caughtKinds
end

local function ZoneSessionItems(m)
  local items = {}
  local list = SessionsIn(m)
  local day
  for _, e in ipairs(list) do
    local key = DayKey(e.t)
    if key ~= day then day = key items[#items + 1] = { kind = "head", h = HEAD_H, text = DayTitle(e.t), color = "textPrimary" } end
    items[#items + 1] = { kind = "entry", h = ROW_H, e = e }
  end
  if #items == 0 then items[1] = { kind = "empty", h = 60, text = L["No sessions in this zone yet."] } end
  return items
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function Chip(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetHeight(22)
  b.bg = Tex(b, "BACKGROUND", "textPrimary", 0.05)
  b.bg:SetAllPoints(b)
  b.text = Text(b, 11, "textSecondary", "CENTER")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b:SetScript("OnEnter", function(self) if not self.on then Fill(self.bg, "textPrimary", 0.10) end ShowCut(self) end)
  b:SetScript("OnLeave", function(self) if not self.on then Fill(self.bg, "textPrimary", 0.05) end Style.HideTooltip(self) end)
  b:SetScript("OnClick", function(self) if onClick then ns.Call("book chip", onClick, self) end end)
  function b:Set(text, on)
    self.text:SetText(text)
    Style.FitText(self.text, 1e6) -- back to the normal size (Layout may make it smaller)
    if self._cut then self._cut[self.text] = nil end
    self.on = on and true or false
    Fill(self.bg, on and "accent" or "textPrimary", on and 0.20 or 0.05)
    SetColor(self.text, on and "textPrimary" or "textSecondary")
    self:SetWidth(TextWidth(self.text) + 20)
  end
  PassRight(b)
  return b
end
-- (i18n) avail: room for the whole row; too long texts get smaller, then cut.
local function Layout(chips, avail)
  if avail then
    local total, n = 0, 0
    for _, c in ipairs(chips) do
      if c:IsShown() then total = total + (Num(c:GetWidth()) or TextWidth(c.text) + 20) n = n + 1 end
    end
    if n > 0 and total + 6 * (n - 1) > avail then
      local each = math.floor((avail - 6 * (n - 1)) / n) - 20
      for _, c in ipairs(chips) do
        if c:IsShown() then Fit(c.text, each, c) c:SetWidth(TextWidth(c.text) + 20) end
      end
    end
  end
  local prev
  for _, c in ipairs(chips) do
    if c:IsShown() then
      if prev then c:ClearAllPoints() c:SetPoint("LEFT", prev, "RIGHT", 6, 0) end
      prev = c
    end
  end
end
local function Tile(parent)
  local t = CreateFrame("Frame", nil, parent)
  Card(t, 0, 0)
  t:SetCardLook("card", "cardLow", 0.92, "gold", 0.45)
  t.label = Text(t, 11, "textSecondary", "LEFT")
  t.label:SetPoint("TOPLEFT", t, "TOPLEFT", 12, -9)
  t.value = Text(t, 22, "textPrimary", "LEFT")
  t.value:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 12, 16)
  t.small = Text(t, 11, "textHint", "LEFT")
  t.small:SetPoint("BOTTOMLEFT", t.value, "BOTTOMRIGHT", 8, 2)
  t.track = Tex(t, "ARTWORK", "barBackground")
  t.track:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 12, 8)
  t.track:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -12, 8)
  t.track:SetHeight(6)
  t.fill = Tex(t, "OVERLAY", "accent")
  t.fill:SetPoint("TOPLEFT", t.track, "TOPLEFT") t.fill:SetPoint("BOTTOMLEFT", t.track, "BOTTOMLEFT")
  t.track:Hide() t.fill:Hide()
  CutTip(t)
  -- (i18n) after the texts are set: label, value and small text fit the tile
  function t:FitTexts()
    local w = self._w or 200
    Fit(self.label, w - 24, self)
    Fit(self.value, w - 24, self)
    Fit(self.small, w - 32 - TextWidth(self.value), self)
  end
  -- frac 0..1; color: a plain colour, else the family's violet to cyan
  function t:SetBar(frac, color)
    if not frac then self.track:Hide() self.fill:Hide() return end
    local w = math.max(1, (Num(self:GetWidth()) or self._w or 200) - 24)
    self.track:Show()
    if frac > 0 then
      self.fill:SetWidth(w * math.min(1, frac))
      if color then Fill(self.fill, color) else Gradient(self.fill, "HORIZONTAL", "violet", 1, "cyan", 1) end
      self.fill:Show()
    else self.fill:Hide() end
  end
  return t
end
-- n tiles in a row (widths: parts of the row) or, with grid, two by two
-- right of the round map (logbook).
local function Tiles(page, n, top, widths, left)
  local tiles = {}
  for i = 1, n do tiles[i] = Tile(page) end
  left = left or 0
  local function Place(w)
    if left > 0 then
      local each = (w - left - 14 - 10) / 2
      local th = (JHERO_H - 12 - 10) / 2
      for i, t in ipairs(tiles) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", page, "TOPLEFT", left + col * (each + 10), -top - row * (th + 10))
        t:SetSize(each, th)
        t._w = each
      end
      return
    end
    local units = 0
    for i = 1, n do units = units + (widths and widths[i] or 1) end
    local unit = (w - 28 - (n - 1) * 10) / units
    local x = 14
    for i, t in ipairs(tiles) do
      local tw = unit * (widths and widths[i] or 1)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", page, "TOPLEFT", x, -top)
      t:SetSize(tw, TILE_H)
      t._w = tw
      x = x + tw + 10
    end
  end
  Place(W - 2) -- widths before the first layout
  page:SetScript("OnSizeChanged", function(_, w) Place(Num(w) or (W - 2)) end)
  return tiles
end

local function EditBox(parent, placeholderText, onChange, budget)
  local box = CreateFrame("Frame", nil, parent)
  Tex(box, "BACKGROUND", "textPrimary", 0.06):SetAllPoints(box)
  Border(box, "gold", 0.30)
  box.icon = Icon(box, 12, "Interface\\Common\\UI-Searchbox-Icon", "ARTWORK")
  box.icon:SetPoint("LEFT", box, "LEFT", 8, 0)
  box.icon:SetVertexColor(THEME.textHint[1], THEME.textHint[2], THEME.textHint[3], 1)
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(40)
  edit:SetFontObject(ChatFontNormal or "ChatFontNormal")
  edit:SetPoint("TOPLEFT", box, "TOPLEFT", 26, 0)
  edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 0)
  local tc = THEME.textPrimary
  if edit.SetTextColor then edit:SetTextColor(tc[1], tc[2], tc[3]) end
  box.placeholder = Text(box, 12, "textHint", "LEFT")
  box.placeholder:SetPoint("LEFT", box, "LEFT", 26, 0)
  box.placeholder:SetText(placeholderText)
  if budget then Fit(box.placeholder, budget, box) CutTip(box) end
  edit:SetScript("OnTextChanged", function(self)
    local text = tostring(self:GetText() or "")
    if text == "" then box.placeholder:Show() else box.placeholder:Hide() end
    ns.Call("book search", onChange, text)
  end)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  box.edit = edit
  return box
end

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

-- The map of a zone into a frame, with the explored parts (as in Questdon's
-- quest book): the banner of Waters (middle stripe) and the round map of the
-- logbook (a circle mask on every piece).
local function DrawMapArt(hero, m, width, HEIGHT, mask)
  for _, t in ipairs(hero.tiles) do t:Hide() end
  hero.artMap = m
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
local function UpdateHeroArt(m)
  local width = Num(P.hero:GetWidth()) or 0
  if width <= 1 then width = W - 2 - SIDE_W end
  return DrawMapArt(P.hero, m, width, HERO_H)
end
-- The logbook's round map: the zone you are in.
local function UpdateLogMap()
  local jm = P.lmap
  if not jm then return end
  local m = HereZone()
  jm.m = m
  jm.name:SetText(m and ZoneName(m) or "")
  Fit(jm.name, JHERO_H - 60, jm)
  if m ~= jm.artMap then
    local d = JHERO_H - 20
    if not DrawMapArt(jm, m, d, d, jm.mask) then jm.artMap = m end
  end
end

local function CreateLogPage(page)
  -- the zone you fish in, round in a gold ring
  local MAPD = JHERO_H - 20
  local jm = CreateFrame("Frame", nil, page)
  jm:SetSize(MAPD, MAPD)
  jm:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -12)
  jm.base = Icon(jm, MAPD, CIRCLE, "BACKGROUND")
  jm.base:SetAllPoints(jm)
  local cl = THEME.cardLow
  jm.base:SetVertexColor(cl[1], cl[2], cl[3], 1)
  jm.tiles = {}
  if jm.CreateMaskTexture then
    local ok, mask = pcall(jm.CreateMaskTexture, jm)
    if ok and mask then
      pcall(mask.SetTexture, mask, CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(jm)
      jm.mask = mask
    end
  end
  local ringF = CreateFrame("Frame", nil, jm)
  ringF:SetAllPoints(jm)
  local rl = Num(jm.GetFrameLevel and jm:GetFrameLevel())
  if rl and ringF.SetFrameLevel then ringF:SetFrameLevel(rl + 3) end
  jm.ring = ringF:CreateTexture(nil, "OVERLAY")
  jm.ring:SetPoint("CENTER", jm, "CENTER", 0, 0)
  jm.ring:SetSize(MAPD + 18, MAPD + 18)
  if jm.ring:SetTexture(MEDIA .. "BookRing") == false then jm.ring:Hide() end
  jm.name = Text(ringF, 11, "goldLight", "CENTER", "OVERLAY")
  jm.name:SetPoint("BOTTOM", jm, "BOTTOM", 0, 18)
  jm:EnableMouse(true)
  jm:SetScript("OnEnter", function(self) if self.m then Style.Tooltip(self, ZoneName(self.m), { { L["Click: show the zone on the tab Waters."] } }, nil, "ANCHOR_RIGHT") end end)
  jm:SetScript("OnLeave", function(self) Style.HideTooltip(self) end)
  jm:SetScript("OnMouseUp", function(self) if self.m and ns.OpenBook then ns.OpenBook("waters", self.m) end end)
  P.lmap = jm
  P.ltiles = Tiles(page, 4, 12, nil, 20 + MAPD + 24)
  P.lchips = {}
  for i, key in ipairs(FILTERS) do
    local c = Chip(page, function() lfilter = key Refresh(true) end)
    c.key = key
    if i == 1 then c:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -JHERO_H - 6) end
    P.lchips[i] = c
  end
  P.lfoot = CreateFrame("Frame", nil, page)
  P.lfoot:SetPoint("BOTTOMLEFT") P.lfoot:SetPoint("BOTTOMRIGHT") P.lfoot:SetHeight(28)
  local fbg = Tex(P.lfoot, "BACKGROUND")
  fbg:SetAllPoints(P.lfoot)
  Gradient(fbg, "VERTICAL", "header", 0.85, "header", 0.0)
  CutTip(P.lfoot)
  P.lfootText = Text(P.lfoot, 11, "textHint", "LEFT")
  P.lfootText:SetPoint("LEFT", P.lfoot, "LEFT", 14, 0)
  local list = NewList(page, KINDS, W - 2 - 10 - 8)
  list:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -JHERO_H - 36)
  list:SetPoint("BOTTOMRIGHT", P.lfoot, "TOPRIGHT", -8, 4)
  lists.log = list
end

local function CreateAtlasPage(page)
  P.atiles = Tiles(page, 3, 12, { 2, 1, 1 })
  local top = 12 + TILE_H
  P.achips = {}
  for i, key in ipairs(AFILTERS) do
    local c = Chip(page, function() afilter = key Refresh(true) end)
    c.key = key
    if i == 1 then c:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top - 8) end
    P.achips[i] = c
  end
  local detail = CreateFrame("Frame", nil, page)
  detail:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -top - 40)
  detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 12)
  detail:SetWidth(DETAIL_W)
  Card(detail, 0, 0)
  detail:SetCardLook("card", "cardLow", 0.97, "gold", 0.6)
  detail.frame = Tex(detail, "ARTWORK", "cardLow", 0.95)
  detail.frame:SetSize(58, 58)
  detail.frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -14)
  Edges(detail, detail.frame, "gold", 0.6, "ARTWORK")
  detail.icon = Icon(detail, 56, nil, "OVERLAY")
  detail.icon:SetPoint("CENTER", detail.frame, "CENTER", 0, 0)
  detail.name = Text(detail, 15, "goldLight", "LEFT")
  detail.name:SetPoint("TOPLEFT", detail.frame, "TOPRIGHT", 10, -4)
  detail.name:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
  detail.name:SetWordWrap(true)
  if detail.name.SetMaxLines then pcall(detail.name.SetMaxLines, detail.name, 2) end
  detail.kind = Text(detail, 11, "textHint", "LEFT")
  detail.kind:SetPoint("BOTTOMLEFT", detail.frame, "BOTTOMRIGHT", 10, 4)
  CutTip(detail)
  detail.lines = {}
  for i = 1, 16 do
    local l = Text(detail, 12, "textHint", "LEFT")
    l:SetPoint("TOPLEFT", detail, "TOPLEFT", 14, -86 - (i - 1) * 19)
    local r = Text(detail, 12, "textPrimary", "RIGHT")
    r:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -14, -86 - (i - 1) * 19)
    detail.lines[i] = { l = l, r = r }
  end
  P.detail = detail
  local list = NewList(page, KINDS, W - 2 - DETAIL_W - 12 - 12 - 8)
  list:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -top - 40)
  list:SetPoint("BOTTOMRIGHT", detail, "BOTTOMLEFT", -8, 0)
  lists.atlas = list
end

local function CreateWatersPage(page)
  local side = CreateFrame("Frame", nil, page)
  side:SetPoint("TOPLEFT") side:SetPoint("BOTTOMLEFT") side:SetWidth(SIDE_W)
  Tex(side, "BACKGROUND", { 0, 0, 0 }, 0.22):SetAllPoints(side)
  local edge = Tex(side, "BORDER", "gold", 0.35) edge:SetPoint("TOPRIGHT") edge:SetPoint("BOTTOMRIGHT") edge:SetWidth(1)
  P.zoneBox = EditBox(side, L["Find a zone"], function(text) zoneQuery = text Refresh() end, SIDE_W - 20 - 34)
  P.zoneBox:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -10)
  P.zoneBox:SetPoint("TOPRIGHT", side, "TOPRIGHT", -10, -10)
  P.zoneBox:SetHeight(24)
  local zl = NewList(side, KINDS, SIDE_W + 2 - 8)
  zl:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -40)
  zl:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", 2, 6)
  lists.zones = zl
  local main = CreateFrame("Frame", nil, page)
  main:SetPoint("TOPLEFT", side, "TOPRIGHT") main:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT")
  local hero = CreateFrame("Frame", nil, main)
  hero:SetPoint("TOPLEFT") hero:SetPoint("TOPRIGHT") hero:SetHeight(HERO_H)
  hero.base = Tex(hero, "BACKGROUND", "header") hero.base:SetAllPoints(hero)
  hero.tiles = {}
  hero.shade = CreateFrame("Frame", nil, hero)
  hero.shade:SetAllPoints(hero)
  local lvl = Num(hero.GetFrameLevel and hero:GetFrameLevel())
  if lvl and hero.shade.SetFrameLevel then hero.shade:SetFrameLevel(lvl + 2) end
  Tex(hero.shade, "BACKGROUND", { 0, 0, 0 }, 0.35):SetAllPoints(hero.shade)
  local fade = Tex(hero.shade, "BORDER", { 0, 0, 0 }, 0.5)
  fade:SetPoint("TOPLEFT") fade:SetPoint("BOTTOMLEFT") fade:SetWidth(380)
  if fade.SetGradient and CreateColor then pcall(fade.SetGradient, fade, "HORIZONTAL", CreateColor(0, 0, 0, 0.75), CreateColor(0, 0, 0, 0)) end
  local bottom = Tex(hero.shade, "BORDER", "gold", 0.6)
  bottom:SetPoint("BOTTOMLEFT") bottom:SetPoint("BOTTOMRIGHT") bottom:SetHeight(1)
  hero.name = Text(hero.shade, 24, "textPrimary", "LEFT")
  hero.name:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", 20, 38)
  hero.meta = Text(hero.shade, 12, "textSecondary", "LEFT")
  hero.meta:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", 20, 18)
  hero.count = Text(hero.shade, 22, "textPrimary", "RIGHT")
  hero.count:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -20, -24)
  hero.countLabel = Text(hero.shade, 11, "textSecondary", "RIGHT")
  hero.countLabel:SetPoint("TOPRIGHT", hero.count, "BOTTOMRIGHT", 0, -4)
  hero.track = Tex(hero.shade, "ARTWORK", "textPrimary", 0.15)
  hero.track:SetSize(150, 4)
  hero.track:SetPoint("TOPRIGHT", hero.countLabel, "BOTTOMRIGHT", 0, -8)
  hero.fill = Tex(hero.shade, "OVERLAY", "gold")
  hero.fill:SetPoint("TOPLEFT", hero.track, "TOPLEFT") hero.fill:SetPoint("BOTTOMLEFT", hero.track, "BOTTOMLEFT")
  Gradient(hero.fill, "HORIZONTAL", "goldDark", 1, "goldLight", 1)
  CutTip(hero.shade)
  P.hero = hero
  P.stats = Text(main, 12, "textSecondary", "LEFT")
  P.stats:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 14, -10)
  P.segFish = Chip(main, function() zoneSeg = "fish" Refresh(true) end)
  P.segFish:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 14, -30)
  P.segSess = Chip(main, function() zoneSeg = "sessions" Refresh(true) end)
  P.segHere = Chip(main, function() selZone = nil Refresh(true) end)
  P.segHere:SetPoint("TOPRIGHT", hero, "BOTTOMRIGHT", -14, -30)
  local list = NewList(main, KINDS, W - 2 - SIDE_W - 10 - 8)
  list:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 6, -58)
  list:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -4, 6)
  lists.waters = list
end

local function TabButton(parent, key)
  local b = CreateFrame("Button", nil, parent)
  b.key = key
  b:SetSize(118, HEADER_H - 8)
  -- a framed tab; the open one brighter with a gold frame
  Card(b, 2, 0)
  b.hover = Tex(b, "BACKGROUND", "rowHover", nil, 3)
  b.hover:SetAllPoints(b.cardFill)
  b.hover:Hide()
  b.icon = Icon(b, 16, TAB_ICON[key], "ARTWORK")
  if b.icon.SetTexCoord then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  b.text = Text(b, 13, "textSecondary", "LEFT")
  b.text:SetText(TAB_TITLE[key])
  b.icon:SetPoint("RIGHT", b, "CENTER", -TextWidth(b.text) / 2 + 2, 0)
  b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
  b.mark = Tex(b, "OVERLAY", "goldLight")
  b.mark:SetPoint("TOPLEFT", b.cardFill, "TOPLEFT", 10, -1)
  b.mark:SetPoint("TOPRIGHT", b.cardFill, "TOPRIGHT", -10, -1)
  b.mark:SetHeight(1)
  b:SetScript("OnEnter", function(self) self.hover:Show() ShowCut(self) end)
  b:SetScript("OnLeave", function(self) self.hover:Hide() Style.HideTooltip(self) end)
  b:SetScript("OnClick", function(self) ns.OpenBook(self.key) end)
  PassRight(b)
  return b
end

local function Create()
  book = CreateFrame("Frame", "LuredonBook", UIParent)
  book:SetSize(W, H)
  book:SetFrameStrata("HIGH")
  book:SetToplevel(true)
  book:SetClampedToScreen(true)
  book:SetMovable(true)
  book:Hide()
  -- navy at the top to violet at the bottom, a gold frame (as Questdon's quest book)
  local bg = Tex(book, "BACKGROUND")
  bg:SetAllPoints(book)
  Gradient(bg, "VERTICAL", "backgroundLow", 0.97, "background", 0.97)
  Border(book, "gold", 0.95)
  local inner = CreateFrame("Frame", nil, book)
  inner:SetPoint("TOPLEFT", book, "TOPLEFT", 3, -3)
  inner:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -3, 3)
  Border(inner, "goldDark", 0.9)
  local inner2 = CreateFrame("Frame", nil, book)
  inner2:SetPoint("TOPLEFT", book, "TOPLEFT", 5, -5)
  inner2:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -5, 5)
  Border(inner2, "gold", 0.35)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "LuredonBook") end
  local header = CreateFrame("Frame", nil, book)
  header:SetPoint("TOPLEFT", book, "TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", book, "TOPRIGHT", -1, -1)
  header:SetHeight(HEADER_H)
  local hbg = Tex(header, "BACKGROUND")
  hbg:SetAllPoints(header)
  Gradient(hbg, "VERTICAL", "background", 0.0, "header", 0.85)
  local hl = Tex(header, "BORDER", "gold", 0.7)
  hl:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 8, 0) hl:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -8, 0) hl:SetHeight(1)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() book:StartMoving() end)
  header:SetScript("OnDragStop", function()
    book:StopMovingOrSizing()
    local p, _, rp, x, y = book:GetPoint()
    if type(p) == "string" then ns.db.bookPos = { p, rp or p, Num(x) or 0, Num(y) or 0 } end
  end)
  local title = Text(header, 15, "textPrimary", "LEFT")
  title:SetPoint("LEFT", header, "LEFT", 14, 0)
  title:SetText(Style.Wordmark("Lure", "don"))
  local sub = Text(header, 12, "textSecondary", "LEFT")
  sub:SetPoint("LEFT", title, "RIGHT", 10, 0)
  sub:SetText(L["Fishing book"])
  local close = Style.IconButton(header, "close")
  close:SetPoint("RIGHT", header, "RIGHT", -10, 0)
  close:SetTooltip(L["Close"])
  close:SetOnClick(function() book:Hide() end)
  P.tabs = {}
  local prev = close
  for i = #TABS, 1, -1 do
    local b = TabButton(header, TABS[i])
    if prev == close then b:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -44, 0) else b:SetPoint("BOTTOMRIGHT", prev, "BOTTOMLEFT", -4, 0) end
    P.tabs[TABS[i]] = b
    prev = b
  end
  -- (i18n) tabs as wide as their text needs (at least 118 px); the subtitle gets what is left
  local titleW = TextWidth(title)
  local each = math.floor((W - 2 - 14 - titleW - 10 - 60 - 38) / #TABS) - 50
  local tabsW = 0
  for _, key in ipairs(TABS) do
    local b = P.tabs[key]
    Fit(b.text, each, b)
    local w = math.max(118, TextWidth(b.text) + 50)
    b:SetWidth(w)
    b.icon:ClearAllPoints()
    b.icon:SetPoint("RIGHT", b, "CENTER", -TextWidth(b.text) / 2 + 2, 0)
    tabsW = tabsW + w
  end
  Fit(sub, W - 2 - 14 - titleW - 10 - tabsW - 38 - 16, header)
  header:SetScript("OnEnter", function(self) ShowCut(self) end)
  header:SetScript("OnLeave", function(self) Style.HideTooltip(self) end)
  P.pages = {}
  for _, key in ipairs(TABS) do
    local page = CreateFrame("Frame", nil, book)
    page:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -1, 1)
    page:Hide()
    P.pages[key] = page
  end
  CreateLogPage(P.pages.log)
  CreateAtlasPage(P.pages.atlas)
  CreateWatersPage(P.pages.waters)
  -- the ornaments lie on top of everything and take no clicks
  local orn = CreateFrame("Frame", nil, book)
  orn:SetAllPoints(book)
  local lvl = Num(book.GetFrameLevel and book:GetFrameLevel())
  if lvl and orn.SetFrameLevel then orn:SetFrameLevel(lvl + 30) end
  if orn.EnableMouse then orn:EnableMouse(false) end
  P.corners = {}
  for i, c in ipairs({ { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 }, { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
    local t = orn:CreateTexture(nil, "OVERLAY")
    t:SetSize(44, 44)
    if t:SetTexture(MEDIA .. "BookCorner") == false then t:Hide() end
    t:SetTexCoord(c[2], c[3], c[4], c[5])
    t:SetPoint(c[1], book, c[1], c[1]:find("LEFT") and -3 or 3, c[1]:find("TOP") and 3 or -3)
    P.corners[i] = t
  end
  ns.RightClickThrough(book, { header })
  ns.bookFrame = book
  book:ClearAllPoints()
  local pos = ns.db.bookPos
  if not (type(pos) == "table" and type(pos[1]) == "string" and pcall(book.SetPoint, book, pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)) then
    book:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  end
end

---------------------------------------------------------------------------
-- Drawing the tabs
---------------------------------------------------------------------------
local function RenderLog(reset)
  UpdateLogMap()
  local today = DayKey(Now())
  local fish, active, value, ah, s0, s1 = 0, 0, 0, 0, nil, nil
  for _, e in ipairs(ns.BookEntries()) do
    if e.k == "s" and DayKey(e.t) == today then
      fish, active, value, ah = fish + (Num(e.f) or 0), active + (Num(e.a) or 0), value + (Num(e.v) or 0), ah + (Num(e.ah) or 0)
      if Num(e.s0) and Num(e.s0) > 0 and (not s0 or e.s0 < s0) then s0 = e.s0 end
      if Num(e.s1) and (not s1 or e.s1 > s1) then s1 = e.s1 end
    end
  end
  local t = P.ltiles
  t[1].label:SetText(L["Fish today"])
  t[1].value:SetText(tostring(fish))
  local rate = Rate(fish, active)
  t[1].small:SetText(rate and L["%d per hour"]:format(rate) or "")
  local rank, maxRank = 0, 0
  if ns.GetSkill then rank, maxRank = ns.GetSkill() end
  rank, maxRank = Num(rank) or 0, Num(maxRank) or 0
  local gained = s0 and math.max(0, rank - s0) or 0
  t[2].label:SetText(L["Skill today"])
  t[2].value:SetText(gained > 0 and ("+" .. gained) or "0")
  SetColor(t[2].value, gained > 0 and "good" or "textPrimary")
  t[2].small:SetText(maxRank > 0 and ("%d / %d"):format(rank, maxRank) or "")
  t[2]:SetBar(maxRank > 0 and rank / maxRank or nil)
  t[3].label:SetText(L["Value today"])
  t[3].value:SetText(Coins(value, 16) or "0")
  t[3].small:SetText(ah > 0 and L["AH %s"]:format(Coins(ah) or "") or "")
  local cb = CharBook()
  local best = cb and type(cb.best) == "table" and cb.best
  t[4].label:SetText(L["Best session"])
  t[4].value:SetText(best and (ns.Decimal and ns.Decimal(best.fph, 1) or tostring(best.fph)) or "-")
  t[4].small:SetText(best and L["fish per hour, %s"]:format(ShortDate(best.t)) or "")
  SetColor(t[4].value, best and "goldLight" or "textPrimary")
  local counts = { s = 0, r = 0, m = 0, x = 0 }
  local entries, casts, total = ns.BookEntries(), 0, 0
  for _, e in ipairs(entries) do
    counts[e.k] = (counts[e.k] or 0) + 1
    if e.k == "s" then casts, total = casts + (Num(e.c) or 0), total + (Num(e.f) or 0) end
  end
  for _, chip in ipairs(P.lchips) do
    local label = FILTER_TITLE[chip.key]
    if counts[chip.key] and counts[chip.key] > 0 then label = label .. "  " .. counts[chip.key] end
    chip:Set(label, chip.key == lfilter)
  end
  for _, tile in ipairs(t) do tile:FitTexts() end
  Layout(P.lchips, W - 2 - 28)
  P.lfootText:SetText(L["%d sessions, %d fish, %d casts"]:format(counts.s, total, casts))
  Fit(P.lfootText, W - 2 - 28, P.lfoot)
  lists.log:SetItems(LogItems(), not reset)
end

local function DetailLines(k)
  local d = P.detail
  local rows = {}
  local function Row(l, r, color) rows[#rows + 1] = { l, r, color } end
  if not k then
    d.icon:SetTexture(nil) d.name:SetText(L["Pick a kind"]) d.kind:SetText("")
  else
    d.icon:SetTexture(ItemIcon(k.id))
    local name, q = QName(k.id)
    d.name:SetText(name)
    local qn = q and ns.QUALITY_NAMES and ns.QUALITY_NAMES[q]
    d.kind:SetText((k.kind == "c" and L["Container"] or L["Fish (kind)"]) .. (q and q >= (ns.RARE_QUALITY or 2) and ("  ·  " .. L["Rare (badge)"]) or ""))
    Row({ header = L["Your catches"] })
    if (k.caught or 0) > 0 then
      Row(L["Caught"], tostring(k.caught))
      Row(L["First catch"], ShortDate(k.first) .. ", " .. ZoneName(k.fz))
      Row(L["Last catch"], ShortDate(k.last) .. ", " .. ZoneName(k.lz))
    else
      Row(L["Caught"], L["not yet"], "warning")
    end
    Row({ header = L["Where it bites"] })
    for i = 1, math.min(5, #k.zones) do
      local z = k.zones[i]
      Row(ZoneName(z.map), Style.Percent(z.share) .. (z.classic and ("  " .. L["(Classic)"]) or ""), z.classic and "textHint" or nil)
    end
    if #k.zones == 0 then Row(L["unknown"], "") end
    if k.minSkill then Row(L["Skill needed"], tostring(k.minSkill)) end
    Row({ header = L["Value"] })
    local sell = Num(ns.GetSellPrice and ns.GetSellPrice(k.id))
    Row(L["Vendor"], Coins(sell) or "-")
    if ns.AuctionPricesOn and ns.AuctionPricesOn() then Row(L["Auction house"], Coins(ns.AuctionPrice(k.id)) or L["no price"]) end
    if k.classic then Row({ header = L["Classic data, not confirmed for Forever yet"] }) end
  end
  local inner = DETAIL_W - 28
  Fit(d.kind, DETAIL_W - 14 - 58 - 10 - 10, d)
  for i, line in ipairs(d.lines) do
    local r = rows[i]
    if not r then line.l:SetText("") line.r:SetText("")
    elseif type(r[1]) == "table" then
      line.l:SetText(r[1].header) SetColor(line.l, "gold") line.r:SetText("")
    else
      line.l:SetText(r[1]) SetColor(line.l, "textHint")
      line.r:SetText(r[2] or "") SetColor(line.r, r[3] or "textPrimary")
    end
    if r then
      Fit(line.r, inner * 0.55, d)
      local rw = (line.r:GetText() or "") ~= "" and (TextWidth(line.r) + 8) or 0
      Fit(line.l, inner - rw, d)
    else
      Fit(line.l, inner, d) Fit(line.r, inner, d)
    end
  end
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
  t[1].label:SetText(L["Kinds caught"])
  t[1].value:SetText(("%d / %d"):format(caught, kinds))
  t[1].small:SetText(L["fish and containers known so far"])
  t[1]:SetBar(kinds > 0 and caught / kinds or nil, "good")
  t[2].label:SetText(L["Rare kinds"])
  t[2].value:SetText(("%d / %d"):format(rareCaught, rare))
  t[3].label:SetText(L["Next new one"])
  t[3].value:SetText(nextNew and ItemName(nextNew.id) or "-")
  t[3].small:SetText(nextNew and ZoneName(nextNew.zones[1].map) or "")
  local counts = { caught = caught, missing = kinds - caught }
  for _, chip in ipairs(P.achips) do
    local label = AFILTER_TITLE[chip.key]
    if counts[chip.key] and counts[chip.key] > 0 then label = label .. "  " .. counts[chip.key] end
    chip:Set(label, chip.key == afilter)
  end
  for _, tile in ipairs(t) do tile:FitTexts() end
  Layout(P.achips, W - 2 - 28)
  if not selKind or not byId[selKind] then selKind = list[1] and list[1].id or nil end
  DetailLines(selKind and byId[selKind])
  lists.atlas:SetItems((AtlasItems(list)), not reset)
end

local function RenderWaters(reset)
  local here = HereZone()
  local m = selZone or here
  lists.zones:SetItems(ZoneListItems(), true)
  local hero = P.hero
  hero.name:SetText(m and ZoneName(m) or L["unknown"])
  local need = m and ns.ZONE_SKILL and ns.ZONE_SKILL[m]
  local total = TotalSkill()
  local meta
  if need then
    meta = L["Skill %d needed, yours %d"]:format(need, total) .. "  ·  "
      .. (total >= need and Colorize(L["nothing gets away"], "good") or Colorize(L["%d points missing"]:format(need - total), "critical"))
  elseif m and ns.IsNewForeverZone and ns.IsNewForeverZone(m) then
    meta = L["New Forever zone: skill needed not published yet."]
  else
    meta = L["Skill needed not known"]
  end
  hero.meta:SetText(meta)
  if m ~= hero.artMap then UpdateHeroArt(m) end
  local items, kinds, caughtKinds
  if zoneSeg == "sessions" then
    items = ZoneSessionItems(m)
    local _, k, c = ZoneFishItems(m)
    kinds, caughtKinds = k, c
  else
    items, kinds, caughtKinds = ZoneFishItems(m)
  end
  hero.count:SetText(("%d / %d"):format(caughtKinds or 0, kinds or 0))
  hero.countLabel:SetText(L["kinds caught here"])
  if (kinds or 0) > 0 then
    hero.track:Show()
    local frac = math.min(1, (caughtKinds or 0) / kinds)
    if frac > 0 then hero.fill:SetWidth(math.max(1, 150 * frac)) hero.fill:Show() else hero.fill:Hide() end
  else hero.track:Hide() hero.fill:Hide() end
  local heroW = W - 2 - SIDE_W
  Fit(hero.countLabel, 150, hero.shade)
  Fit(hero.name, heroW - 40 - 170, hero.shade)
  Fit(hero.meta, heroW - 40 - 170, hero.shade)
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
  Fit(P.stats, W - 2 - SIDE_W - 28, P.hero.shade)
  P.segFish:Set(L["Fish here"] .. "  " .. (kinds or 0), zoneSeg == "fish")
  P.segSess:Set(L["Your sessions here"] .. "  " .. #sessions, zoneSeg == "sessions")
  P.segSess:ClearAllPoints()
  P.segSess:SetPoint("LEFT", P.segFish, "RIGHT", 6, 0)
  local hereW = 0
  if selZone and selZone ~= here then
    P.segHere:Set(L["Back to my zone"], false) P.segHere:Show()
    hereW = (Num(P.segHere:GetWidth()) or 0) + 12
  else P.segHere:Hide() end
  Layout({ P.segFish, P.segSess }, W - 2 - SIDE_W - 28 - hereW)
  lists.waters:SetItems(items, not reset)
end

local lastTab
function Refresh(reset)
  if not book or not book:IsShown() then return end
  for key, b in pairs(P.tabs) do
    local on = key == tab
    SetColor(b.text, on and "goldLight" or "textSecondary")
    if on then b:SetCardLook("card", "cardLow", 0.98, "gold", 0.9) else b:SetCardLook("cardLow", "cardLow", 0.75, "gold", 0.35) end
    if b.icon.SetDesaturated then b.icon:SetDesaturated(not on) end
    b.icon:SetAlpha(on and 1 or 0.6)
    if on then b.mark:Show() else b.mark:Hide() end
  end
  for key, page in pairs(P.pages) do if key == tab then page:Show() else page:Hide() end end
  if tab ~= lastTab then reset = true lastTab = tab end
  if tab == "log" then RenderLog(reset) elseif tab == "atlas" then RenderAtlas(reset) else RenderWaters(reset) end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
function ns.UpdateBook() if book and book:IsShown() then Refresh(false) end end

-- which: "log", "atlas" or "waters" (nil: the last one); mapID: the zone on Waters.
function ns.OpenBook(which, mapID)
  if not book then Create() end
  which = which or tab
  if mapID then selZone = mapID zoneSeg = "fish" end
  tab = which
  if not book:IsShown() then book:Show() end
  Refresh(true)
end

function ns.ToggleBook(which)
  if not book then Create() end
  if book:IsShown() and (which == nil or which == tab) then book:Hide() return end
  ns.OpenBook(which)
end
function ns.BookTab() return tab end
function ns.BookZone() return selZone or HereZone() end
function ns.BookFilter(key) if key then lfilter = key Refresh(true) end return lfilter end
function ns.BookAtlasFilter(key) if key then afilter = key Refresh(true) end return afilter end
function ns.BookSelectKind(id) selKind = id Refresh() end
function ns.BookSegment(key) if key then zoneSeg = key Refresh(true) end return zoneSeg end
function ns.BookItems(which) local l = lists[which or tab] return l and l.items or {} end
function ns.BookLines(which) local l = lists[which or tab] return l and l.used or {} end
function ns.BookDetailText()
  local out = {}
  for _, line in ipairs(P.detail and P.detail.lines or {}) do
    local l, r = line.l:GetText() or "", line.r:GetText() or ""
    if l ~= "" then out[#out + 1] = l .. (r ~= "" and (" " .. r) or "") end
  end
  return table.concat(out, "\n")
end
function ns.BookLogMap() local jm = P.lmap return jm and jm.m, jm and jm.artMap end
function ns.BookArt() local h = P.hero return h and ("map %s, %d tiles drawn"):format(tostring(h.artMap), h.artDrawn or 0) or "not built" end

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

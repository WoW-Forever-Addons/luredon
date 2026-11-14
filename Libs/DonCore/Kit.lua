local Kit = LibStub("DonCore-1.0"):NewModule("Kit", 25)

---------------------------------------------------------------------------
-- DonCore module "Kit" (minor 1, 01.11.2026, STYLEKIT_PLAN.md "Schritt 2"; minor 2, 02.11.2026: Kit.IconButton, the symbols from
-- Style.ICONS, used by the Options module; minor 3, 02.11.2026, StyleKit 2 step 4 with Questdon: Hero, Detail, Columns,
-- List with own kinds / own heights / empty text, ListRow with an icon, ZoneRow with range and progress, Window with logo,
-- subtitle and the options cog, the helpers Kit.Fill/Tex/Border/SetColor/TextColor/Clickable for an addon's own rows;
-- for Questdon's quest book also: ListRow indent and right2 (a second right line), Card and CardRow (index cards in a grid,
-- list kind "cards"), Tile art/side/SetProgress, Sidebar opts.kinds, ChipBar skips hidden chips and bar:Chip(key)):
-- (minor 4, 02.11.2026, Guildon step 4: ClassColor/ClassText/ClassIcon, TableHead/TableRow (list kind "table"), ItemIcon,
-- EditBox, Segmented, BarList, Dialog, ShowCopy, Detail:Item)
-- (minor 4, 02.11.2026, Golddon step 4, docs/layout_2026-11-02/golddon/BAUSTEINE.md: Money, ParseMoney, ItemTooltip, Table
-- with ItemRow (list kind "trow": symbol, title and sub line, number columns from the right that go under a width),
-- NoteRow / WarnRow (kind "note"), MoneyBox, ActionBar, Box, LineChart, Button kind "danger" and opts.confirm, Tab:SetAlert,
-- Chip:SetCount and add chips, ListRow quality / itemID, Hero plainCase / valueColor, Detail opts.actionsBottom)
-- (minor 8, 02.11.2026) a compact row forgets the size Style.FitText kept from the old font (it put the big font back)
-- (minor 9, 02.11.2026, Daniel: "Ja, überall flach") Kit.Window has the flat head (32, tabs 26, logo 20) by default
-- (minor 10, 02.11.2026, Dropdon step 4, docs/layout_2026-11-02/dropdon/BAUSTEINE.md: Window opts.buttons (more symbols in the
-- head), ItemIcon:SetUnusable and ItemRow item.unusable (red symbol like Blizzard's unusable items, reason red in the tooltip),
-- Kit.ItemGrid (item symbols in rows by width), dropdown entries with right / rightColor / header)
-- (minor 11, 02.11.2026, Luredon step 4, docs/layout_2026-11-02/luredon/BAUSTEINE.md: Kit.ItemCard, a compact 64 px card for an
-- item (symbol with quality edge, name, line below, number on the right; list kind "itemcards", Kit.ItemCardCols), ListRow
-- item.lead (a quiet narrow column left of the symbol: a time or date))
-- (minor 12, 02.11.2026) Kit.ItemCard measures its number with Kit.TextWidth (a client without GetStringWidth left the card
-- half drawn: not picked, not laid out)
-- (minor 13, 02.11.2026, Daniel: "Maßstab 80 % für alle Kit-Fenster, im Optionsfenster einstellbar von 60 bis 110 %") one
-- scale for every Kit window, dialog and menu: Kit.scale, Kit.SetScale, Kit.Scaled, win:SetOwnScale (block before Window)
-- (minor 14, 02.11.2026, Daniel on Questdon's chain parts: "part 1 und 2 sind ja schon erledigt, kann man das besser
-- kennzeichnen?") ChainMark:SetDone(on): a green box with a tick instead of the number; ListRow item.chainDone
-- (minor 15, 03.11.2026) FocusCard:SetPlain(on) hides the symbol's dark box as well
-- (minor 18, 04.11.2026, Guildon's map tooltip) Kit.Tooltip: a head with class symbol, sub line and badge, class symbols
-- before lines, opts.anchor and opts.edge = "gold"; Kit.IconText, Kit.CLASS_SHEET
-- (minor 19, 05.11.2026, Daniel on Dropdon: "tooltip dauerhaft am laden? tooltip sollte auch direkt da öffnen, wo man drüber
-- hovert") Kit.TipAnchor(owner): a wide owner (a list row) gets the tooltip at the mouse, a small one keeps ANCHOR_RIGHT
-- (Kit.Tooltip without opts.anchor, Kit.ItemTooltip); Kit.ItemTooltip asks the game for an item it does not know yet and
-- builds the tooltip again when GET_ITEM_INFO_RECEIVED brings it (it stayed on "Retrieving item information"); Forever
-- never answers for some items, so the caller may give a stand-in (item.tipFallback = { name, quality, lines }: the name in
-- the quality colour, the lines muted) that shows until the game knows the item (Kit.ItemTipFn, Kit.ItemGrid entries)
-- (minor 16, 04.11.2026, Era-Test, Daniel: "die zahlen sind sehr eng an dem / geschrieben besonders die 1") Kit.Fraction(a, b):
-- "a / b" with a space on each side of the slash (Ring, ListRow progress); a Kit.Dialog always shows at Kit.scale times
-- its own factor (d:SetOwnScale), a SetScale from outside before Show no longer stacks on top (Luredon's 1.5)
-- (minor 25, 12.11.2026, Questdon's item buttons in the quest list, Daniel: "Gleiches kommt aus DonCore") Kit.ItemButton:
-- a protected button that uses an item (icon, count, cooldown, a watch while a change waits for the end of a fight)
-- (minor 24, 11.11.2026, Profitdon's Auswertung, Daniel's picture 122142: two lines without a name, one peak of 196g
-- pressed five days of the curve flat) LineChart: opts.legend (the labels of the series in their colours, top left) and
-- opts.clipPeak = factor (a peak more than factor times the 90 % value is cut at the top edge, c.clipped holds its real
-- value, opts.clipText(value) adds a note to the legend); the mouse still shows the real values
-- (minor 23, 11.11.2026, Profitdon's Durchsicht, Daniel: "Gleiches gehört ins Kit, nicht je Addon") three blocks Profitdon
-- had built for itself: ActionBar a:Input(opts) (a number box left of the buttons), Kit.PlaceRight (a row of controls
-- from the right edge, hidden ones take no room), Kit.SecureButton (a protected action button in the Don look)
-- (minor 22, 11.11.2026, Finddon, Daniel: map pin "rund im Goldring wie die Minimap-Knöpfe", footer "Pfeil: Name" to click)
-- Kit.RoundIcon(parent, size, opts): a round symbol on a dark disc in the gold ring of the minimap buttons;
-- Window: f:SetStatus(text, onClick, tooltip) makes the footer text take a click
-- (minor 21, 08.11.2026, Profitdon's shopping list, Daniel: "fehlt weiterhin das X für löschen am besten am hauptitem links
-- daneben", "bei der anzahl unter kaufen wollte ich ein beschreibbares feld") ItemRow: item.onRemove's X stands left of the
-- symbol (the 07.11. X came without a new minor, so an older Kit 20 of another addon won and showed none); item.edit =
-- { key, value, onCommit(item, n), tip }: a number box in place of that column's text, committed on Enter or on leaving
-- (minor 20, 05.11.2026, Daniel on Golddon's sell row: "felder für g / s / c nicht alles in einem") Kit.CoinBox: money in
-- three number boxes with the coin symbols, the same calls as Kit.MoneyBox
-- (minor 7, 02.11.2026, Daniel: the coming steps "gerne kleiner, das wirkt fast so als könnte man es auswählen": ListRow
-- item.compact, a quiet small row: title in the sub font, its second line smaller, title colour body; give the item h = 28)
-- (minor 6, 02.11.2026, Daniel after Leveldon in the game: "der kreis mit % sollte durchgängig sein", "die ? ! und schwerter in der
-- leiste ohne hintergrund und kleiner": Kit.Ring opts.solid (a closed arc, the value as text), ListRow item.iconPlain)
-- (minor 5, 02.11.2026, Leveldon step 4, docs/layout_2026-11-02/leveldon/BAUSTEINE.md: Hint, SegmentBar, Divider (kind
-- "divider"), DoneRow (kind "done"), Spark, FocusCard, Kit.Menu, Radio, TextBox, Diamond; ListRow iconKind, badgeRight, radio)
-- the building blocks of the Don style
-- ("edles Buch + Fokus + Karteikarten", docs/layout_2026-11-01/6_designsystem.png and questdon_mockup_v4.html).
--   local Kit = LibStub("DonCore-1.0"):Get("Kit", 1)
-- Blocks: Window (header, book tabs, grip, size bounds, width thresholds), Sidebar, List (virtual: only visible rows),
-- ListRow, GroupHeader, SubRow (chain step), ZoneRow, ChainMark ("4a"), LevelBadge, Chip, ChipBar, Pill (exception
-- only), Tile, Button (primary, secondary, icon), Toggle, Slider, Dropdown, SearchBox, ProgressBar, Ring ("3/6"),
-- Dots, OptionRow, ScrollArea, Tooltip. Every interactive block has the states normal / hover / selected / disabled
-- (SetSelected, SetDisabled, GetState).
-- Size rules: one line per text, cut with "..." and the whole text in the tooltip (Kit.Fit, Kit.FullText); fixed
-- columns plus one growing; more height = more rows; under 960 px the detail goes over the list, under 800 px the
-- sidebar becomes an icon rail; chips scroll instead of wrapping.
-- /doncore kit shows every block and a window to drag (720x420 to 1300x900).
-- Only own frames, no hooks. The kit owns no SavedVariables: a window keeps its place in the table opts.store.
---------------------------------------------------------------------------
if not Kit then return end -- the same or a newer Kit is loaded already
local Core = LibStub("DonCore-1.0")
Kit.VERSION = 25

local WHITE = "Interface\\Buttons\\WHITE8x8"
local floor, ceil, max, min, abs, pi, sin, cos = math.floor, math.ceil, math.max, math.min, math.abs, math.pi, math.sin, math.cos
local pairs, ipairs, type, tostring, tonumber, pcall = pairs, ipairs, type, tostring, tonumber, pcall
local unpack = unpack or table.unpack

local function Call(obj, method, ...)
  if obj and type(obj[method]) == "function" then return pcall(obj[method], obj, ...) end
  return false
end

-- Kit.onError = function(where, err) ... end (set by an addon); nil: errors of callbacks stay silent
local function Safe(where, fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  if type(Kit.onError) == "function" then pcall(Kit.onError, where, a) end
end

local function Clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v ~= v or v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function StyleKit() return Core:Get("Style", 3) end

---------------------------------------------------------------------------
-- Tokens (design system sheet, section 1 and 2)
---------------------------------------------------------------------------
local function Hex(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255,
    hex = "ff" .. h:lower() }
end

local C = {
  window = Hex("0C0F16"), panel = Hex("121722"), card = Hex("171E2C"), row = Hex("141B28"), rowAlt = Hex("171E2C"),
  rowHover = Hex("1E2738"), rowSel = Hex("242E42"), input = Hex("090C12"), group = Hex("101520"), sub = Hex("0F141E"),
  tab = Hex("0E131D"), primary = Hex("282011"), primaryHover = Hex("362B16"), chipActive = Hex("231D12"),
  switchOn = Hex("261F10"),
  gold = Hex("8C6D32"), goldBright = Hex("D4AF5A"), goldMuted = Hex("3A3324"), mid = Hex("323D52"),
  divider = Hex("252D3D"), outer = Hex("030406"),
  hero = Hex("F7EBD2"), title = Hex("EFE5CF"), body = Hex("D2C8B4"), muted = Hex("8792A8"), quiet = Hex("5E687D"),
  txGold = Hex("D4AF5A"),
  green = Hex("66BB6A"), greenBg = Hex("112416"), greenBd = Hex("28572C"),
  yellow = Hex("FFD54F"), yellowBg = Hex("26200E"), yellowBd = Hex("6B5616"),
  blue = Hex("29B6F6"), blueBg = Hex("0E2233"), blueBd = Hex("1E547A"),
  grey = Hex("6E788A"), greyBg = Hex("181C26"), greyBd = Hex("323A4C"),
  red = Hex("EF5350"), redBg = Hex("2B1315"), redBd = Hex("6E2426"),
}
Kit.C = C

-- status colours: green done, yellow in the log / current, blue available / next, grey later, red elite / dungeon
local STATUS = {}
for _, k in ipairs({ "green", "yellow", "blue", "grey", "red" }) do
  STATUS[k] = { fg = C[k], bg = C[k .. "Bg"], bd = C[k .. "Bd"] }
end
STATUS.done, STATUS.current, STATUS.next, STATUS.later = STATUS.green, STATUS.yellow, STATUS.blue, STATUS.grey
Kit.STATUS = STATUS

-- (01.11.2026, Daniel: "Farben, die Blizzard auch nutzt") quest levels in Blizzard's quest difficulty colours: the game's
-- table QuestDifficultyColors (same in Era and Forever), these values only if it is missing. Background and edge of a
-- level badge are the same colour, darker.
local QUEST_FALLBACK = {
  impossible = { 1, 0.1, 0.1 }, verydifficult = { 1, 0.5, 0.25 }, difficult = { 1, 0.82, 0 },
  standard = { 0.25, 0.75, 0.25 }, trivial = { 0.5, 0.5, 0.5 },
}
Kit.QUEST_KEYS = { "impossible", "verydifficult", "difficult", "standard", "trivial" }
local function Shade(c, f) return { c[1] * f, c[2] * f, c[3] * f } end
function Kit.UpdateQuestColors()
  local game = type(QuestDifficultyColors) == "table" and QuestDifficultyColors or {}
  for _, k in ipairs(Kit.QUEST_KEYS) do
    local g = game[k]
    local c = (type(g) == "table" and tonumber(g.r)) and { g.r, g.g, g.b } or QUEST_FALLBACK[k]
    STATUS[k] = { fg = c, bg = Shade(c, 0.16), bd = Shade(c, 0.45) }
  end
end
Kit.UpdateQuestColors()

-- Blizzard's rule (GetQuestDifficultyColor): 5+ above red, 3+ orange, from 2 below yellow, within the green range green,
-- else grey. playerLevel: default the player's level.
function Kit.QuestDifficulty(level, playerLevel)
  level = tonumber(level)
  if not level then return "trivial" end
  playerLevel = tonumber(playerLevel) or (type(UnitLevel) == "function" and tonumber(UnitLevel("player"))) or 1
  local d = level - playerLevel
  if d >= 5 then return "impossible" elseif d >= 3 then return "verydifficult" elseif d >= -2 then return "difficult" end
  local range
  if type(UnitQuestTrivialLevelRange) == "function" then range = tonumber(UnitQuestTrivialLevelRange("player")) end
  if not range and type(GetQuestGreenRange) == "function" then range = tonumber(GetQuestGreenRange()) end
  if -d <= (range or 8) then return "standard" end
  return "trivial"
end

-- 4 px grid; fixed heights
local S = {
  unit = 4, gap = 8, pad = 12, row = 36, sub = 28, head = 44, tab = 36, button = 28, buttonSmall = 24, chip = 24,
  mark = 18, badgeW = 28, badgeH = 20, icon = 16, iconMid = 24, iconBig = 36, bar = 6, sidebar = 220, rail = 48,
  colRight = 96, footer = 28, menuRow = 24, indent = 36, markBar = 3, card = 124,
  lead = 42, itemCard = 64, -- (minor 11)
}
Kit.SIZE = S
Kit.BREAK = { overlay = 960, rail = 800 }      -- under overlay: detail over the list; under rail: sidebar as icons
Kit.WINDOW_MIN, Kit.WINDOW_MAX = { 720, 420 }, { 1300, 900 }
Kit.DISABLED_ALPHA, Kit.DIM_ALPHA = 0.4, 0.72

-- Font roles: "head" is the game's title font (Friz Quadrata in the western clients), "body" Arial Narrow in the
-- western clients; the other clients keep their own font (Korean, Chinese, Russian letters). No own font files.
local FONTS = {
  hero = { "head", 20 }, title = { "head", 14 }, tab = { "head", 12 }, group = { "head", 11 },
  row = { "body", 13 }, button = { "body", 12 }, sub = { "body", 11 }, mono = { "body", 10 }, badge = { "body", 11 },
}
Kit.FONTS = FONTS

local function FontFile(kind)
  local ok, path = Call(_G.GameFontNormal, "GetFont")
  path = ok and type(path) == "string" and path or nil
  if kind == "body" and (not path or path:upper():find("FRIZQT__%.TTF")) then return "Fonts\\ARIALN.TTF" end
  return path or "Fonts\\FRIZQT__.TTF"
end

Kit.fontObjects = Kit.fontObjects or {}
function Kit.Font(role)
  if not FONTS[role] then role = "row" end
  local name = "DonKitFont_" .. role
  local f = Kit.fontObjects[role] or _G[name]
  if not f and type(CreateFont) == "function" then
    f = CreateFont(name)
    Call(f, "SetFont", FontFile(FONTS[role][1]), FONTS[role][2], "")
  end
  Kit.fontObjects[role] = f
  return f
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Col(c)
  if type(c) == "string" then c = C[c] or (STATUS[c] and STATUS[c].fg) end
  return type(c) == "table" and c or C.body
end

local function SetCol(tex, c, a)
  c = Col(c)
  tex:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
end

local function Tex(parent, layer, color, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
  t:SetTexture(WHITE)
  SetCol(t, color)
  return t
end

local function Fill(f, color, layer)
  local t = Tex(f, layer, color)
  t:SetAllPoints(f)
  return t
end

local SIDES = { "top", "bottom", "left", "right" }
-- 1 px frame inside the edge (inset px in)
local function Border(f, color, inset, layer)
  inset = inset or 0
  local b = {}
  for _, s in ipairs(SIDES) do b[s] = Tex(f, layer or "BORDER", color) end
  b.top:SetPoint("TOPLEFT", inset, -inset) b.top:SetPoint("TOPRIGHT", -inset, -inset) b.top:SetHeight(1)
  b.bottom:SetPoint("BOTTOMLEFT", inset, inset) b.bottom:SetPoint("BOTTOMRIGHT", -inset, inset) b.bottom:SetHeight(1)
  b.left:SetPoint("TOPLEFT", inset, -inset) b.left:SetPoint("BOTTOMLEFT", inset, inset) b.left:SetWidth(1)
  b.right:SetPoint("TOPRIGHT", -inset, -inset) b.right:SetPoint("BOTTOMRIGHT", -inset, inset) b.right:SetWidth(1)
  function b:SetColor(c, a) for _, s in ipairs(SIDES) do SetCol(self[s], c, a) end end
  return b
end

local function TextColor(fs, c)
  c = Col(c)
  fs:SetTextColor(c[1], c[2], c[3], 1)
end

local function Text(parent, role, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local fo = Kit.Font(role)
  if fo then Call(fs, "SetFontObject", fo) end
  TextColor(fs, color or C.body)
  fs:SetJustifyH(justify or "LEFT")
  Call(fs, "SetJustifyV", "MIDDLE")
  Call(fs, "SetWordWrap", false)
  Call(fs, "SetNonSpaceWrap", false)
  Call(fs, "SetMaxLines", 1)
  return fs
end
Kit.Text = Text

-- width of the whole text on one line
local function TextW(fs)
  local ok, w = Call(fs, "GetUnboundedStringWidth")
  if not (ok and type(w) == "number" and w > 0) then ok, w = Call(fs, "GetStringWidth") end
  return (ok and type(w) == "number" and w == w) and ceil(w) or 0
end
Kit.TextWidth = TextW

-- One line, at most width wide: first up to 2 points smaller, then cut with "..."; the whole text stays for the
-- tooltip (Kit.FullText). Uses Style.FitText, so cuts show up in Style.TextCuts for /diag and the tests.
function Kit.Fit(fs, width)
  width = max(1, floor(tonumber(width) or 1))
  local St = StyleKit()
  if St then St.FitText(fs, width, "cut") else fs:SetWidth(width) end
  return fs
end

function Kit.FullText(fs)
  local St = StyleKit()
  return St and St.FullText(fs) or nil
end

-- (minor 18, 04.11.2026, Guildon's map tooltip, Daniel: "der Tooltip sieht einfach aus") a symbol in front of a text as an
-- escape: t.class (the class symbol from the class sheet) or t.icon (a texture, t.coords = { l, r, t, b } of it)
local function IconText(t, size)
  local tex, tc = t.icon, t.coords
  if t.class then
    local c = Kit.ClassCoords(t.class)
    if c then tex, tc = Kit.CLASS_SHEET, c end
  end
  if not tex then return "" end
  if tc then
    return ("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t "):format(tex, size, size, floor(tc[1] * 256 + 0.5), floor(tc[2] * 256 + 0.5),
      floor(tc[3] * 256 + 0.5), floor(tc[4] * 256 + 0.5))
  end
  return ("|T%s:%d:%d|t "):format(tostring(tex), size, size)
end
Kit.IconText = IconText

-- (minor 18) the gold edge of a Kit tooltip: the game's tooltip keeps it only while this owner holds it; a small watcher
-- (no hook) gives the edge its old colour back once the tooltip is hidden or taken by someone else
local edge = {}
local function EdgeColor(tt, r, g, b)
  local nine = tt.NineSlice
  if type(nine) == "table" and type(nine.SetBorderColor) == "function" then return pcall(nine.SetBorderColor, nine, r, g, b) end
  if type(tt.SetBackdropBorderColor) == "function" then return pcall(tt.SetBackdropBorderColor, tt, r, g, b) end
end
local function EdgeNow(tt)
  local nine = tt.NineSlice
  local piece = type(nine) == "table" and nine.TopLeftCorner or nil
  if type(piece) == "table" and type(piece.GetVertexColor) == "function" then
    local ok, r, g, b = pcall(piece.GetVertexColor, piece)
    if ok and r then return r, g, b end
  end
  if type(tt.GetBackdropBorderColor) == "function" then
    local ok, r, g, b = pcall(tt.GetBackdropBorderColor, tt)
    if ok and r then return r, g, b end
  end
  return 1, 1, 1
end
local function EdgeBack()
  if not edge.owner then return end
  local tt = GameTooltip
  if tt then EdgeColor(tt, edge.r, edge.g, edge.b) end
  edge.owner = nil
  if edge.watch then edge.watch:Hide() end
end
local function EdgeGold(tt, owner)
  if not edge.owner then edge.r, edge.g, edge.b = EdgeNow(tt) end
  edge.owner = owner
  EdgeColor(tt, C.goldBright[1], C.goldBright[2], C.goldBright[3])
  if not edge.watch then
    edge.watch = CreateFrame("Frame")
    edge.watch:SetScript("OnUpdate", function()
      local okS, shown = pcall(tt.IsShown, tt)
      local okO, owned = pcall(tt.IsOwned, tt, edge.owner)
      if not (okS and shown and okO and owned) then EdgeBack() end
    end)
  end
  edge.watch:Show()
end
Kit.TooltipEdgeOwner = function() return edge.owner end -- (tests)

-- (minor 19) where a tooltip opens: at the mouse for a wide owner (a list row, the tooltip right of the window was far from
-- the row), right of a small one (a symbol)
Kit.TIP_WIDE = 160
function Kit.TipAnchor(owner)
  local ok, w = false, nil
  if owner and type(owner.GetWidth) == "function" then ok, w = pcall(owner.GetWidth, owner) end
  if ok and type(w) == "number" and w >= Kit.TIP_WIDE then return "ANCHOR_CURSOR_RIGHT", 12, 4 end
  return "ANCHOR_RIGHT", 0, 0
end
local function TipOwner(tt, owner, anchor)
  if anchor then return pcall(tt.SetOwner, tt, owner, anchor) end
  local a, x, y = Kit.TipAnchor(owner)
  if pcall(tt.SetOwner, tt, owner, a, x, y) then return true end
  return pcall(tt.SetOwner, tt, owner, "ANCHOR_RIGHT")
end

-- tooltip in the Don colours; lines: strings, { label, value [, colour], class = "MAGE" (symbol before the label) } or
-- { header = "Text" }. (minor 18) title may be a head { text, sub, class or icon (+ coords), badge (gold, on the right) };
-- opts.anchor (default "ANCHOR_RIGHT"), opts.edge = "gold"
function Kit.Tooltip(owner, title, lines, hint, opts)
  local tt = GameTooltip
  if not tt or not owner then return end
  opts = type(opts) == "table" and opts or {}
  EdgeBack()
  if not TipOwner(tt, owner, opts.anchor) then return end
  local T, B, M, Q, G = C.hero, C.body, C.muted, C.quiet, C.txGold
  if type(title) == "table" then
    local text = IconText(title, 22) .. tostring(title.text or "")
    if title.badge ~= nil and title.badge ~= "" then
      pcall(tt.AddDoubleLine, tt, text, tostring(title.badge), T[1], T[2], T[3], G[1], G[2], G[3])
    else
      pcall(tt.AddLine, tt, text, T[1], T[2], T[3], true)
    end
    if title.sub and title.sub ~= "" then pcall(tt.AddLine, tt, tostring(title.sub), M[1], M[2], M[3], true) end
  elseif title and title ~= "" then
    pcall(tt.AddLine, tt, tostring(title), T[1], T[2], T[3], true)
  end
  for _, line in ipairs(type(lines) == "table" and lines or {}) do
    if type(line) == "table" and line.header then
      pcall(tt.AddLine, tt, tostring(line.header), G[1], G[2], G[3], true)
    elseif type(line) == "table" and line[2] ~= nil then
      local v = Col(line[3] or B)
      pcall(tt.AddDoubleLine, tt, IconText(line, 14) .. tostring(line[1] or ""), tostring(line[2]), M[1], M[2], M[3], v[1], v[2], v[3])
    elseif line ~= nil then
      local text = type(line) == "table" and (IconText(line, 14) .. tostring(line[1] or "")) or tostring(line)
      pcall(tt.AddLine, tt, text, B[1], B[2], B[3], true)
    end
  end
  if hint and hint ~= "" then pcall(tt.AddLine, tt, tostring(hint), Q[1], Q[2], Q[3], true) end
  pcall(tt.Show, tt)
  if opts.edge == "gold" then EdgeGold(tt, owner) end
end

function Kit.HideTooltip(owner)
  local tt = GameTooltip
  if not tt then return end
  local ok, owned = pcall(tt.IsOwned, tt, owner)
  if ok and owned then pcall(tt.Hide, tt) EdgeBack() end
end

-- shows the whole text of every cut FontString of a block (fs list), with the block's own tooltip first
local function CutTip(owner, title, lines, fsList)
  local cut = {}
  for _, fs in ipairs(fsList or {}) do
    local full = Kit.FullText(fs)
    if full then cut[#cut + 1] = full end
  end
  if not title and #cut == 0 then return end
  local all = {}
  for _, l in ipairs(lines or {}) do all[#all + 1] = l end
  for _, t in ipairs(cut) do all[#all + 1] = t end
  Kit.Tooltip(owner, title or table.remove(all, 1), all)
end

---------------------------------------------------------------------------
-- States: normal / hover / selected / disabled. paint(w, state) colours the block.
---------------------------------------------------------------------------
local function Refresh(w)
  local st = w._disabled and "disabled" or w._selected and "selected" or w._hover and "hover" or "normal"
  w._state = st
  if w._paint then Safe("paint", w._paint, w, st) end
  w:SetAlpha(st == "disabled" and Kit.DISABLED_ALPHA or w._dim and Kit.DIM_ALPHA or 1)
end
Kit.Refresh = Refresh

local Methods = {}
function Methods:SetSelected(on) self._selected = on and true or nil Refresh(self) return self end
function Methods:IsSelected() return self._selected == true end
function Methods:SetDisabled(on)
  self._disabled = on and true or nil
  if self._onDisabled then Safe("disabled", self._onDisabled, self, self._disabled) end
  Refresh(self)
  return self
end
function Methods:IsDisabled() return self._disabled == true end
function Methods:SetDimmed(on) self._dim = on and true or nil Refresh(self) return self end
function Methods:GetState() return self._state end
function Methods:SetTooltip(title, lines, hint) self._tip = { title, lines, hint } return self end

local function Stateful(w, paint)
  for k, fn in pairs(Methods) do w[k] = fn end
  w._paint = paint
  Call(w, "EnableMouse", true)
  w:SetScript("OnEnter", function(self)
    self._hover = true
    Refresh(self)
    if self._onHover then Safe("hover", self._onHover, self, true) end
    if type(self._tipFn) == "function" then
      -- (minor 3) a tooltip made when the mouse comes: fn(self) returns title, lines, hint; cut texts follow
      local ok, title, lines, hint = pcall(self._tipFn, self)
      if ok and title then
        local all = {}
        for _, l in ipairs(type(lines) == "table" and lines or {}) do all[#all + 1] = l end
        Kit.Tooltip(self, title, all, hint)
      elseif self._cutTexts then CutTip(self, nil, nil, self._cutTexts) end
    elseif self._tip then Kit.Tooltip(self, self._tip[1], self._tip[2], self._tip[3])
    elseif self._cutTexts then CutTip(self, nil, nil, self._cutTexts) end
  end)
  w:SetScript("OnLeave", function(self)
    self._hover = nil
    Refresh(self)
    if self._onHover then Safe("hover", self._onHover, self, false) end
    Kit.HideTooltip(self)
  end)
  Refresh(w)
  return w
end
Kit.Stateful = Stateful

local function Clickable(b, onClick)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if self._disabled then return end
    Safe("click", self._onClick or onClick, self, button)
  end)
end

-- (minor 3) capitals for titles in every client language: string.upper only knows A-Z, so "Östliche" became "öSTLICHE"
-- and Russian stayed small. Latin-1 letters (à to þ, not ÷ and ß) and Cyrillic (а to я, ё) are raised here as well.
local function UpperTwo(a, b)
  local x, y = a:byte(), b:byte()
  if x == 0xC3 and y >= 0xA0 and y <= 0xBE and y ~= 0xB7 then return string.char(0xC3, y - 0x20) end
  if x == 0xD0 and y >= 0xB0 and y <= 0xBF then return string.char(0xD0, y - 0x20) end
  if x == 0xD1 and y >= 0x80 and y <= 0x8F then return string.char(0xD0, y + 0x20) end
  if x == 0xD1 and y == 0x91 then return string.char(0xD0, 0x81) end
  return a .. b
end
function Kit.Upper(text)
  if text == nil then return "" end
  text = tostring(text)
  -- colour codes keep their small letters (|cffd4af5a, |r)
  local out = {}
  local i = 1
  while i <= #text do
    local c = text:sub(i, i)
    if c == "|" and text:sub(i + 1, i + 1) == "c" then out[#out + 1] = text:sub(i, i + 9) i = i + 10
    elseif c == "|" and text:sub(i + 1, i + 1) == "r" then out[#out + 1] = "|r" i = i + 2
    else
      local j = text:find("|", i, true) or (#text + 1)
      out[#out + 1] = (text:sub(i, j - 1):upper():gsub("([\195\208\209])([\128-\191])", UpperTwo))
      i = j
    end
  end
  return table.concat(out)
end
local Upper = Kit.Upper

-- (minor 3) the helpers for an addon's own blocks in the Don style (own list kinds, cards), so nobody builds them again
Kit.Fill, Kit.Tex, Kit.Border, Kit.SetColor, Kit.TextColor, Kit.Clickable, Kit.Color = Fill, Tex, Border, SetCol, TextColor, Clickable, Col

---------------------------------------------------------------------------
-- Small marks: LevelBadge, ChainMark, Pill, Dots, ProgressBar, Ring
---------------------------------------------------------------------------
-- level badge 28x20, colour by status
-- (minor 3, Daniel 02.11.2026: "die kästen der queststufe auch weglassen", "hier bitte auch ... mit [15] in der jeweiligen
-- farbe") Kit.LEVEL_PLAIN: the level as "[15]" in its colour, without the box (the default); false brings the box back
Kit.LEVEL_PLAIN = true
function Kit.LevelBadge(parent, level, status)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(S.badgeW, S.badgeH)
  f.bg = Fill(f, C.greyBg)
  f.bd = Border(f, C.greyBd)
  f.text = Text(f, "badge", C.grey, "CENTER")
  f.text:SetPoint("CENTER", 0, 0)
  function f:SetLevel(lvl, st)
    local c = STATUS[st] or STATUS.grey
    SetCol(self.bg, c.bg) self.bd:SetColor(c.bd) TextColor(self.text, c.fg)
    self.plain = Kit.LEVEL_PLAIN and true or nil
    if self.plain then self.bg:Hide() self.bd:SetColor(c.bd, 0) else self.bg:Show() end
    local t = lvl ~= nil and tostring(lvl) or ""
    self.text:SetText((self.plain and t ~= "") and ("[" .. t .. "]") or t)
    Kit.Fit(self.text, S.badgeW + (self.plain and 4 or -2))
  end
  f:SetLevel(level, status)
  return f
end

-- chain step mark "4a", 18 high, gold, no pill
function Kit.ChainMark(parent, text)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(S.mark)
  f.bg = Fill(f, C.tab)
  f.bd = Border(f, C.goldMuted)
  f.text = Text(f, "mono", C.txGold, "CENTER")
  f.text:SetPoint("CENTER", 0, 0)
  function f:SetText(t)
    self.text:SetText(t or "")
    self:SetWidth(max(26, TextW(self.text) + 8))
  end
  -- (minor 14) done: green box, a tick in place of the number (the width stays)
  function f:SetDone(on)
    on = on and true or nil
    if on == self._done then return end
    self._done = on
    if on and not self.tick then
      self.tick = self:CreateTexture(nil, "OVERLAY")
      self.tick:SetSize(12, 12)
      self.tick:SetPoint("CENTER", 0, 0)
      local St = StyleKit()
      if St and St.SetIcon then St.SetIcon(self.tick, "check") else self.tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready") end
    end
    SetCol(self.bg, on and C.greenBg or C.tab)
    self.bd:SetColor(on and C.greenBd or C.goldMuted)
    self.text:SetAlpha(on and 0 or 1)
    if self.tick then if on then self.tick:Show() else self.tick:Hide() end end
  end
  f:SetText(text)
  return f
end

-- pill: only for exceptions ("Ready", "Group 2+"); kind ready (green), elite (red), else blue
local PILL = { ready = "green", elite = "red", info = "blue", warn = "yellow" }
function Kit.Pill(parent, text, kind)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(S.mark)
  f.bg = Fill(f, C.greenBg)
  f.bd = Border(f, C.greenBd)
  f.text = Text(f, "mono", C.green, "CENTER")
  f.text:SetPoint("CENTER", 0, 0)
  function f:SetPill(t, k)
    local c = STATUS[PILL[k] or k] or STATUS.blue
    SetCol(self.bg, c.bg) self.bd:SetColor(c.bd) TextColor(self.text, c.fg)
    self.text:SetText(t or "")
    self:SetWidth(TextW(self.text) + 12)
  end
  f:SetPill(text, kind)
  return f
end

-- row of 6x6 squares (chain steps), colours by status
function Kit.Dots(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(6)
  f.dots = {}
  function f:SetDots(list)
    list = list or {}
    for i, st in ipairs(list) do
      local d = self.dots[i]
      if not d then
        d = Tex(self, "ARTWORK", C.grey)
        d:SetSize(6, 6)
        d:SetPoint("LEFT", (i - 1) * 9, 0)
        self.dots[i] = d
      end
      SetCol(d, (STATUS[st] or STATUS.grey).fg)
      d:Show()
    end
    for i = #list + 1, #self.dots do self.dots[i]:Hide() end
    self:SetWidth(max(1, #list * 9 - 3))
  end
  return f
end

-- 6 px bar; SetValue(0..1), colour gold or a status
function Kit.ProgressBar(parent, color)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(S.bar)
  Fill(f, C.input)
  Border(f, C.divider)
  f.fill = Tex(f, "ARTWORK", color or C.goldBright)
  f.fill:SetPoint("TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  f.value = 0
  function f:SetColor(c) SetCol(self.fill, (STATUS[c] and STATUS[c].fg) or c or C.goldBright) end
  function f:SetValue(v)
    self.value = Clamp(v, 0, 1)
    local w = (self._w or self:GetWidth() or 0) - 2
    if self.value <= 0 or w <= 0 then self.fill:Hide() return end
    self.fill:SetWidth(max(1, w * self.value))
    self.fill:Show()
  end
  function f:Layout(w) self._w = w self:SetWidth(w) self:SetValue(self.value) end
  return f
end

-- (minor 22) round symbol in the gold ring of the game's minimap buttons (a dark disc, the symbol cut round, Blizzard's
-- tracking border on top; measures of a 31 px button scaled to size). opts.ring = false: the symbol alone.
-- f:SetIcon(file, coords): an icon of Interface\Icons loses its dark border, any other picture is shown whole.
-- f:SetRing(on), f:SetRoundSize(size)
function Kit.RoundIcon(parent, size, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, parent)
  f.disc = f:CreateTexture(nil, "BACKGROUND")
  f.disc:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.ring = f:CreateTexture(nil, "OVERLAY")
  f.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  if f.CreateMaskTexture then
    local ok, mask = pcall(f.CreateMaskTexture, f)
    if ok and mask then
      pcall(mask.SetTexture, mask, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
      mask:SetAllPoints(f.icon)
      if f.icon.AddMaskTexture then pcall(f.icon.AddMaskTexture, f.icon, mask) end
    end
  end
  f._ring = opts.ring ~= false
  function f:SetRoundSize(sz)
    sz = tonumber(sz) or 31
    self._size = sz
    local k = sz / 31
    self:SetSize(sz, sz)
    self.disc:ClearAllPoints() self.icon:ClearAllPoints() self.ring:ClearAllPoints()
    if self._ring then
      self.disc:SetSize(20 * k, 20 * k)
      self.disc:SetPoint("TOPLEFT", self, "TOPLEFT", 7 * k, -5 * k)
      self.icon:SetSize(17 * k, 17 * k)
      self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", 7 * k, -6 * k)
      self.ring:SetSize(53 * k, 53 * k)
      self.ring:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
      self.disc:Show() self.ring:Show()
    else
      self.icon:SetAllPoints(self)
      self.disc:Hide() self.ring:Hide()
    end
  end
  function f:SetRing(on)
    on = on and true or false
    if on == self._ring then return end
    self._ring = on
    self:SetRoundSize(self._size)
  end
  function f:SetIcon(file, coords)
    self.icon:SetTexture(file)
    local tc = coords
    if type(tc) ~= "table" then
      tc = (type(file) == "string" and file:lower():find("^interface[\\/]icons[\\/]")) and { 0.08, 0.92, 0.08, 0.92 } or { 0, 1, 0, 1 }
    end
    Call(self.icon, "SetTexCoord", tc[1], tc[2], tc[3], tc[4])
  end
  f:SetRoundSize(size)
  if opts.icon then f:SetIcon(opts.icon, opts.iconCoords) end
  return f
end

-- ring "3/6": squares on a circle (filled gold, all done green), the count in the middle
-- (minor 6) opts.solid: a closed arc of small overlapping squares (no single dots), filled clockwise from the top to
-- done/total; f:SetText(text) puts another text in the middle ("38%")
function Kit.Ring(parent, size, opts)
  local solid = opts and opts.solid
  size = size or S.iconBig
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  f.segs = {}
  f.text = Text(f, "mono", C.title, "CENTER")
  f.text:SetPoint("CENTER", 0, 0)
  function f:SetValue(done, total)
    done, total = floor(tonumber(done) or 0), floor(tonumber(total) or 0)
    self.done, self.total = done, total
    local n = solid and floor(size * 2) or Clamp(total, 1, 24)
    local filled = total > 0 and floor(n * min(done, total) / total + 0.5) or 0
    local seg, r = solid and 3 or (n > 12 and 3 or 4), size / 2 - 3
    local fullColor = (total > 0 and done >= total) and C.green or C.goldBright
    for i = 1, n do
      local t = self.segs[i]
      if not t then t = Tex(self, "ARTWORK", C.mid) self.segs[i] = t end
      local a = pi / 2 - (i - 1) * 2 * pi / n -- from the top, clockwise
      t:SetSize(seg, seg)
      t:ClearAllPoints()
      t:SetPoint("CENTER", self, "CENTER", r * cos(a), r * sin(a))
      SetCol(t, i <= filled and fullColor or C.mid)
      t:Show()
    end
    for i = n + 1, #self.segs do self.segs[i]:Hide() end
    self.text:SetText(total > 0 and Kit.Fraction(done, total) or "")
    if solid then self.text:SetText(total > 0 and (floor(100 * min(done, total) / total + 0.5) .. "%") or "") end
    Kit.Fit(self.text, size - 8)
  end
  function f:SetText(t) self.text:SetText(t or "") Kit.Fit(self.text, size - 8) end
  f:SetValue(0, 0)
  return f
end

---------------------------------------------------------------------------
-- Button: kind "primary" (gold), "secondary" (navy, default), "icon" (square); opts.small = 24 px
---------------------------------------------------------------------------
local BUTTON_PAINT = {
  secondary = { normal = { C.card, C.mid, C.title }, hover = { C.rowHover, C.gold, C.hero }, selected = { C.rowSel, C.goldBright, C.hero } },
  primary = { normal = { C.primary, C.gold, C.txGold }, hover = { C.primaryHover, C.goldBright, C.hero }, selected = { C.primaryHover, C.goldBright, C.hero } },
}
BUTTON_PAINT.icon = BUTTON_PAINT.secondary
-- (minor 4) red: a button armed for its second click, or one that removes something
BUTTON_PAINT.danger = { normal = { C.redBg, C.redBd, C.red }, hover = { C.redBg, C.red, C.hero }, selected = { C.redBg, C.red, C.hero } }

-- (minor 4) "Sure?" of a confirm button in the client's language
local SURE = { deDE = "Sicher?", frFR = "S\195\187r ?", esES = "\194\191Seguro?", esMX = "\194\191Seguro?", ptBR = "Certeza?",
  itIT = "Sicuro?", ruRU = "\208\163\208\178\208\181\209\128\208\181\208\189\209\139?", koKR = "Sure?", zhCN = "Sure?", zhTW = "Sure?" }
function Kit.SureWord()
  local loc = type(GetLocale) == "function" and GetLocale() or "enUS"
  return SURE[loc] or "Sure?"
end

function Kit.Button(parent, text, opts)
  opts = opts or {}
  local kind = BUTTON_PAINT[opts.kind] and opts.kind or "secondary"
  local h = opts.small and S.buttonSmall or S.button
  local b = CreateFrame("Button", nil, parent)
  b.kind = kind
  b:SetHeight(h)
  b.bg = Fill(b, C.card)
  b.bd = Border(b, C.mid)
  b.text = Text(b, "button", C.title, "CENTER")
  b.text:SetPoint("CENTER", 0, 0)
  if opts.icon then
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(S.icon, S.icon)
    b.icon:SetPoint("CENTER", 0, 0)
    if not (opts.atlas and Call(b.icon, "SetAtlas", opts.icon)) then b.icon:SetTexture(opts.icon) end
  end
  function b:SetText(t)
    self.text:SetText(t or "")
    if self.kind == "icon" then self:SetWidth(h) else self:SetWidth(max(h, TextW(self.text) + (opts.small and 16 or 24))) end
    self.natural = self:GetWidth()
  end
  -- (minor 3) another kind later ("primary" / "secondary")
  function b:SetKind(k) if BUTTON_PAINT[k] then self.kind = k Kit.Refresh(self) end end
  -- a fixed width chosen by the caller: the text is cut to fit
  function b:Layout(w) self._fixedW = w self:SetWidth(w) Kit.Fit(self.text, w - (opts.small and 12 or 16)) end
  b:SetText(text)
  b._cutTexts = { b.text }
  Clickable(b, opts.onClick)
  -- (minor 4) opts.confirm (true or a text): the first click turns the button red ("Sure? ..."), the second within 3 s
  -- runs onClick, after 3 s it goes back; b:SetArmed(on, text) shows the same look for an addon's own two-click logic
  function b:SetArmed(on, t)
    if on and not self._armed then self._armed, self._plainKind, self._plainText = true, self.kind, self.text:GetText() end
    if on then
      self.kind = "danger"
      self:SetText(t or (Kit.SureWord() .. " " .. (self._plainText or "")))
    elseif self._armed then
      self._armed, self.kind = nil, self._plainKind or self.kind
      self:SetText(self._plainText or "")
    end
    if self._fixedW then self:Layout(self._fixedW) end
    Kit.Refresh(self)
  end
  function b:IsArmed() return self._armed == true end
  if opts.confirm then
    b:SetScript("OnClick", function(self, button)
      if self._disabled then return end
      if not self._armed then
        self:SetArmed(true, type(opts.confirm) == "string" and opts.confirm or nil)
        self._armedAt = type(GetTime) == "function" and GetTime() or 0
        local at = self._armedAt
        if C_Timer and C_Timer.After then C_Timer.After(3, function() if self._armedAt == at then self:SetArmed(false) end end) end
        return
      end
      self._armedAt = nil
      self:SetArmed(false)
      Safe("click", self._onClick or opts.onClick, self, button)
    end)
  end
  Stateful(b, function(self, st)
    local p = BUTTON_PAINT[self.kind][st] or BUTTON_PAINT[self.kind].normal
    SetCol(self.bg, p[1]) self.bd:SetColor(p[2]) TextColor(self.text, p[3])
    if self.icon then SetCol(self.icon, st == "normal" and C.title or C.hero) end
  end)
  b._onDisabled = function(self, off) if off then Call(self, "Disable") else Call(self, "Enable") end end
  if opts.tooltip then b:SetTooltip(opts.tooltip, opts.tooltipLines) end
  return b
end

-- (01.11.2026, Daniel: "Alles was überall gleich sein kann, sollten die addons aus dem gleichen kit ziehen ... auch
-- Symbole") an icon button with the one set of symbols every Don addon uses (Style.ICONS: close, options, collapse,
-- expand, back, forward, report; atlas where the client has it, else a file), the size of Style's title bar buttons
-- unless opts.size says otherwise. opts.onClick, opts.tooltip, opts.hint.
-- Without Style (never in a Don addon) a small text button stands in.
local ICON_TEXT = { close = "x", options = "*", collapse = "-", expand = "+", back = "<", forward = ">", report = "!" }
function Kit.IconButton(parent, kind, opts)
  opts = opts or {}
  local St = StyleKit()
  local b
  if St and St.IconButton then
    b = St.IconButton(parent, kind)
    if opts.size then b:SetSize(opts.size, opts.size) end
    if opts.onClick then b:SetOnClick(opts.onClick) end
    if opts.tooltip then b:SetTooltip(opts.tooltip, nil, opts.hint) end
  else
    b = Kit.Button(parent, ICON_TEXT[kind] or "?", { kind = "icon", small = true, onClick = opts.onClick, tooltip = opts.tooltip })
  end
  b.donKind = kind
  return b
end

-- book tab: 36 high, active 38 with a bright gold top line
function Kit.Tab(parent, text, onClick)
  local t = CreateFrame("Button", nil, parent)
  t:SetHeight(S.tab)
  t.bg = Fill(t, C.tab)
  t.bd = Border(t, C.divider)
  t.bd.bottom:Hide()
  t.topLine = Tex(t, "OVERLAY", C.goldBright)
  t.topLine:SetPoint("TOPLEFT") t.topLine:SetPoint("TOPRIGHT") t.topLine:SetHeight(2)
  t.text = Text(t, "tab", C.muted, "CENTER")
  t.text:SetPoint("CENTER", 0, -1)
  -- (minor 4) t:SetAlert(on): a small red square right of the text (something waits there: undercut, ready to hand in)
  t.alert = Tex(t, "OVERLAY", C.red)
  t.alert:SetSize(6, 6)
  t.alert:SetPoint("LEFT", t.text, "RIGHT", 6, 1)
  t.alert:Hide()
  function t:SetText(s)
    self.text:SetText(s or "")
    self.natural = TextW(self.text) + 28 + (self.alert:IsShown() and 12 or 0)
    self:SetWidth(self.natural)
  end
  function t:SetAlert(on)
    if (on and true or false) == self.alert:IsShown() then return end
    if on then self.alert:Show() else self.alert:Hide() end
    self:SetText(self.text:GetText())
    local win = self:GetParent() and self:GetParent():GetParent()
    if win and win.tabs and win.Layout then win:Layout() end
  end
  function t:Layout(w)
    self:SetWidth(w)
    local a = self.alert:IsShown() and 12 or 0
    Kit.Fit(self.text, w - 12 - a)
    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", -floor(a / 2), -1)
  end
  t:SetText(text)
  t._cutTexts = { t.text }
  Clickable(t, onClick)
  Stateful(t, function(self, st)
    local active = st == "selected"
    local th = self.h or S.tab
    self:SetHeight(active and th + 2 or th)
    SetCol(self.bg, active and C.card or st == "hover" and C.rowHover or C.tab)
    self.bd:SetColor(active and C.gold or st == "hover" and C.goldMuted or C.divider)
    TextColor(self.text, active and C.hero or st == "hover" and C.title or C.muted)
    if active then self.topLine:Show() else self.topLine:Hide() end
  end)
  return t
end

-- chip 24 high: filter on (selected) / off; text may carry a count
-- (minor 4) c:SetCount(n, color): a number right of the text (gold, or a colour: "red" for warnings; nil hides it);
-- opts.add: the chip that adds something ("+ New list"), drawn fainter
function Kit.Chip(parent, text, onClick, opts)
  opts = opts or {}
  local c = CreateFrame("Button", nil, parent)
  c:SetHeight(S.chip)
  c.add = opts.add and true or nil
  c.bg = Fill(c, C.sub)
  c.bd = Border(c, C.divider)
  c.text = Text(c, "badge", C.muted, "LEFT")
  c.text:SetPoint("LEFT", 8, 0)
  c.count = Text(c, "badge", C.txGold, "LEFT")
  c.count:SetPoint("LEFT", c.text, "RIGHT", 6, 0)
  c.count:Hide()
  function c:Size()
    self:SetWidth(TextW(self.text) + 16 + (self.count:IsShown() and TextW(self.count) + 6 or 0))
  end
  function c:SetText(t) self.text:SetText(t or "") self:Size() end
  function c:SetCount(n, color)
    if n == nil or n == "" then self.count:Hide() else
      self.count:SetText(tostring(n)) TextColor(self.count, color or C.txGold) self.count:Show()
    end
    self:Size()
  end
  c:SetText(text)
  Clickable(c, onClick)
  Stateful(c, function(self, st)
    local on = st == "selected"
    SetCol(self.bg, on and C.chipActive or C.sub, self.add and 0.4 or nil)
    self.bd:SetColor(on and C.gold or st == "hover" and C.mid or self.add and C.goldMuted or C.divider)
    TextColor(self.text, on and C.hero or st == "hover" and C.title or self.add and C.quiet or C.muted)
  end)
  return c
end

-- chips on one line; more chips than room: the mouse wheel scrolls them sideways (no wrapping)
function Kit.ChipBar(parent, opts)
  opts = opts or {}
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(S.chip)
  Call(bar, "SetClipsChildren", true)
  Call(bar, "EnableMouseWheel", true)
  bar.chips, bar.offset, bar.active = {}, 0, {}
  -- (minor 4) count: a number in the chip (chip:SetCount later); copts.add: an add chip, copts.onClick: its own click
  -- (no selection)
  function bar:Add(key, text, count, copts)
    copts = copts or {}
    local chip = Kit.Chip(self, text, function(c, button)
      if copts.onClick then Safe("chip", copts.onClick, c, button) return end
      if opts.multi then self.active[key] = not self.active[key] or nil
      else self.active = { [key] = true } end
      self:Paint()
      Safe("chip", opts.onChange, key, self.active[key] == true, self, button)
    end, copts)
    if count ~= nil then chip:SetCount(count) end
    chip.key = key
    self.chips[#self.chips + 1] = chip
    self:Place()
    return chip
  end
  function bar:SetActive(key, on)
    if not opts.multi then self.active = {} end
    self.active[key] = on ~= false or nil
    self:Paint()
  end
  function bar:Paint() for _, c in ipairs(self.chips) do c:SetSelected(self.active[c.key]) end end
  -- (minor 3) a hidden chip takes no room (chip:Hide(), then bar:Place())
  function bar:ContentWidth()
    local w, n = 0, 0
    for _, c in ipairs(self.chips) do
      if c:IsShown() then w = w + (c:GetWidth() or 0) + (n > 0 and S.unit or 0) n = n + 1 end
    end
    return w
  end
  function bar:Place()
    local room = self._w or self:GetWidth() or 0
    self.offset = Clamp(self.offset, 0, max(0, self:ContentWidth() - room))
    local x = -self.offset
    for _, c in ipairs(self.chips) do
      c:ClearAllPoints()
      c:SetPoint("LEFT", self, "LEFT", x, 0)
      if c:IsShown() then x = x + (c:GetWidth() or 0) + S.unit end
    end
  end
  -- (minor 3) the chip of a key (nil: none)
  function bar:Chip(key) for _, c in ipairs(self.chips) do if c.key == key then return c end end end
  function bar:Layout(w) self._w = w self:SetWidth(w) self:Place() end
  bar:SetScript("OnMouseWheel", function(self, d) self.offset = self.offset - d * 40 self:Place() end)
  return bar
end

-- tile (card with a gold top edge): label, big value, line below
-- (minor 3, Questdon step 4) opts.art = size: a square frame t.art on the left for an addon's own picture (a round map),
-- the texts stand right of it; opts.side = width: room on the right for an own block (t.side, e.g. Kit.Columns);
-- t:SetProgress(v, color): a 4 px bar at the bottom (nil hides it), the line moves above it
function Kit.Tile(parent, opts)
  opts = opts or {}
  local t = CreateFrame("Button", nil, parent)
  t:SetHeight(opts.height or 72)
  t.bg = Fill(t, C.card)
  t.bd = Border(t, C.divider)
  t.top = Tex(t, "OVERLAY", C.goldMuted)
  t.top:SetPoint("TOPLEFT") t.top:SetPoint("TOPRIGHT") t.top:SetHeight(2)
  t.artSize, t.sideW = tonumber(opts.art) or 0, tonumber(opts.side) or 0
  if t.artSize > 0 then
    t.art = CreateFrame("Frame", nil, t)
    t.art:SetSize(t.artSize, t.artSize)
    t.art:SetPoint("LEFT", 10, 0)
  end
  if t.sideW > 0 then
    t.side = CreateFrame("Frame", nil, t)
    t.side:SetPoint("TOPRIGHT", -10, -10)
    t.side:SetPoint("BOTTOMRIGHT", -10, 10)
    t.side:SetWidth(t.sideW)
  end
  local x = 10 + (t.artSize > 0 and t.artSize + S.gap or 0)
  t.label = Text(t, "sub", C.muted)
  t.label:SetPoint("TOPLEFT", x, -10)
  t.value = Text(t, "hero", C.hero)
  t.value:SetPoint("LEFT", x, 0)
  t.line = Text(t, "sub", C.quiet)
  t.line:SetPoint("BOTTOMLEFT", x, 8)
  t.bar = Kit.ProgressBar(t)
  t.bar:SetHeight(4)
  t.bar:SetPoint("BOTTOMLEFT", x, 8)
  t.bar:Hide()
  function t:SetData(label, value, line, color)
    self.label:SetText(label or "") self.value:SetText(value ~= nil and tostring(value) or "") self.line:SetText(line or "")
    TextColor(self.value, color or C.hero)
    if self._w then self:Layout(self._w) end
  end
  function t:SetProgress(v, color)
    if v == nil then self.bar:Hide() else self.bar:SetColor(color) self.bar:Show() self.bar.value = Clamp(v, 0, 1) end
    self.line:ClearAllPoints()
    self.line:SetPoint("BOTTOMLEFT", 10 + (self.artSize > 0 and self.artSize + S.gap or 0), v == nil and 8 or 16)
    if self._w then self:Layout(self._w) end
  end
  function t:Layout(w)
    self._w = w
    self:SetWidth(w)
    local room = w - 20 - (self.artSize > 0 and self.artSize + S.gap or 0) - (self.sideW > 0 and self.sideW + S.gap or 0)
    for _, fs in ipairs({ self.label, self.value, self.line }) do Kit.Fit(fs, max(1, room)) end
    if self.bar:IsShown() then self.bar:Layout(max(1, room + (self.sideW > 0 and self.sideW + S.gap or 0))) end
  end
  t:SetData(opts.label, opts.value, opts.line, opts.color)
  t._cutTexts = { t.label, t.value, t.line }
  Clickable(t, opts.onClick)
  Stateful(t, function(self, st)
    SetCol(self.top, (st == "hover" or st == "selected") and C.goldBright or C.goldMuted)
    self.bd:SetColor(st == "selected" and C.gold or C.divider)
  end)
  return t
end

---------------------------------------------------------------------------
-- Controls: Toggle, Slider, Dropdown, SearchBox
---------------------------------------------------------------------------
-- switch 28x16; opts.get(), opts.set(value), opts.label (text right of it)
function Kit.Toggle(parent, opts)
  opts = opts or {}
  local t = CreateFrame("Button", nil, parent)
  t:SetHeight(20)
  t.track = CreateFrame("Frame", nil, t)
  t.track:SetSize(28, 16)
  t.track:SetPoint("LEFT", 0, 0)
  t.trackBg = Fill(t.track, C.input)
  t.trackBd = Border(t.track, C.mid)
  t.thumb = Tex(t.track, "ARTWORK", C.muted)
  t.thumb:SetSize(10, 10)
  if opts.label then
    t.label = Text(t, "sub", C.body)
    t.label:SetPoint("LEFT", t.track, "RIGHT", 6, 0)
    t.label:SetText(opts.label)
  end
  t.value = false
  function t:SetValue(v)
    self.value = v and true or false
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("LEFT", self.track, "LEFT", self.value and 16 or 2, 0)
    Refresh(self)
  end
  function t:GetValue() return self.value end
  function t:Update() self:SetValue(Safe("toggle get", opts.get)) end
  t:SetWidth(28 + (t.label and 6 + TextW(t.label) or 0))
  t._cutTexts = { t.label }
  Clickable(t, function(self)
    self:SetValue(not self.value)
    Safe("toggle", opts.set, self.value, self)
  end)
  Stateful(t, function(self, st)
    local on = self.value
    SetCol(self.trackBg, on and C.switchOn or C.input)
    self.trackBd:SetColor(on and (st == "hover" and C.goldBright or C.gold) or (st == "hover" and C.gold or C.mid))
    SetCol(self.thumb, on and C.goldBright or (st == "hover" and C.title or C.muted))
  end)
  t._onDisabled = function(self, off) if off then Call(self, "Disable") else Call(self, "Enable") end end
  if opts.get then t:Update() else t:SetValue(opts.value) end
  return t
end

-- slider: opts.min, opts.max, opts.step, opts.get(), opts.set(value), opts.format(value) -> text; Layout(width)
function Kit.Slider(parent, opts)
  opts = opts or {}
  local lo, hi, step = tonumber(opts.min) or 0, tonumber(opts.max) or 1, tonumber(opts.step) or 0.01
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(20)
  local s = CreateFrame("Slider", nil, f)
  f.slider = s
  Call(s, "SetOrientation", "HORIZONTAL")
  s:SetHeight(16)
  s:SetPoint("LEFT", 0, 0)
  s:SetMinMaxValues(lo, hi)
  Call(s, "SetValueStep", step)
  Call(s, "SetObeyStepOnDrag", true)
  Call(s, "EnableMouseWheel", false)
  f.track = CreateFrame("Frame", nil, s)
  f.track:SetHeight(S.bar)
  f.track:SetPoint("LEFT", 0, 0)
  f.track:SetPoint("RIGHT", 0, 0)
  Fill(f.track, C.input)
  Border(f.track, C.divider)
  f.fill = Tex(f.track, "ARTWORK", C.gold)
  f.fill:SetPoint("TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMLEFT", 1, 1)
  Call(s, "SetThumbTexture", WHITE)
  local okT, thumb = Call(s, "GetThumbTexture")
  f.thumb = okT and thumb or nil
  if f.thumb then f.thumb:SetSize(8, 16) SetCol(f.thumb, C.goldBright) end
  f.text = Text(f, "mono", C.title, "RIGHT")
  f.text:SetPoint("RIGHT", 0, 0)
  local function Snap(v)
    v = Clamp(v, lo, hi)
    v = lo + floor((v - lo) / step + 0.5) * step
    return floor(Clamp(v, lo, hi) * 1e6 + 0.5) / 1e6
  end
  f.Snap = Snap
  function f:ShowValue(v)
    self.value = v
    self.text:SetText(opts.format and Safe("slider format", opts.format, v) or tostring(v))
    local w = (self._sw or 0) - 2
    local frac = hi > lo and (v - lo) / (hi - lo) or 0
    if w > 0 and frac > 0 then self.fill:SetWidth(max(1, w * frac)) self.fill:Show() else self.fill:Hide() end
  end
  s:SetScript("OnValueChanged", function(_, v)
    v = Snap(v)
    if v == f.value then return end
    f:ShowValue(v)
    if not f._quiet then Safe("slider", opts.set, v, f) end
  end)
  function f:SetValue(v)
    v = Snap(v)
    self._quiet = true
    s:SetValue(v)
    self._quiet = nil
    self:ShowValue(v)
  end
  function f:GetValue() return self.value end
  function f:Update() self:SetValue(Safe("slider get", opts.get) or lo) end
  function f:Layout(w)
    self:SetWidth(w)
    self._sw = max(40, w - 48)
    s:SetWidth(self._sw)
    self:ShowValue(self.value or lo)
  end
  Stateful(f, function(self, st)
    if self.thumb then SetCol(self.thumb, st == "hover" and C.hero or C.goldBright) end
    SetCol(self.fill, st == "hover" and C.goldBright or C.gold)
  end)
  -- the mouse is over the slider widget, not over f
  s:SetScript("OnEnter", function() f:GetScript("OnEnter")(f) end)
  s:SetScript("OnLeave", function() f:GetScript("OnLeave")(f) end)
  f._onDisabled = function(self, off)
    if off then Call(s, "Disable") else Call(s, "Enable") end
    Call(s, "EnableMouse", not off)
  end
  f:Layout(opts.width or 160)
  if opts.get then f:Update() else f:SetValue(opts.value or lo) end
  return f
end

-- the one open dropdown list (shared by all dropdowns)
local MENU_ROWS = 12
local function Menu()
  local m = Kit._menu
  if m then return m end
  m = CreateFrame("Frame", "DonKitMenu", UIParent)
  Kit.Scaled(m) -- (minor 13)
  Call(m, "SetFrameStrata", "FULLSCREEN_DIALOG")
  Call(m, "SetClampedToScreen", true)
  Call(m, "EnableMouse", true)
  Call(m, "EnableMouseWheel", true)
  Fill(m, C.card)
  Border(m, C.gold)
  m.rows, m.items, m.offset = {}, {}, 0
  m:Hide()
  if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "DonKitMenu" end
  m:SetScript("OnHide", function(self)
    local o = self.owner
    self.owner = nil
    if o then o._open = nil Refresh(o) end
  end)
  m:SetScript("OnMouseWheel", function(self, d)
    self.offset = Clamp(self.offset - d, 0, max(0, #self.items - MENU_ROWS))
    self:Draw()
  end)
  function m:Draw()
    local w = tonumber(self:GetWidth()) or self._w or 160
    for i = 1, min(#self.items, MENU_ROWS) do
      local r = self.rows[i]
      if not r then
        r = CreateFrame("Button", nil, self)
        r:SetHeight(S.menuRow)
        r:SetPoint("TOPLEFT", 1, -1 - (i - 1) * S.menuRow)
        r.bg = Fill(r, C.card)
        r.mark = Tex(r, "ARTWORK", C.goldBright)
        r.mark:SetPoint("TOPLEFT") r.mark:SetPoint("BOTTOMLEFT") r.mark:SetWidth(S.markBar)
        r.text = Text(r, "row", C.body)
        r.text:SetPoint("LEFT", 10, 0)
        -- (minor 10) item.right: a short text on the right (item.rightColor); item.header: a group title, not to choose
        r.right = Text(r, "sub", C.muted, "RIGHT")
        r.right:SetPoint("RIGHT", -8, 0)
        Clickable(r, function(row)
          if row.item and row.item.header then return end
          local o = self.owner
          self:Hide()
          if o then o:Choose(row.item.value) end
        end)
        Stateful(r, function(row, st)
          local head = row.item and row.item.header
          SetCol(row.bg, head and C.group or st == "hover" and C.rowHover or row.current and C.rowSel or C.card)
          TextColor(row.text, head and C.txGold or (st == "hover" or row.current) and C.hero or (row.item and row.item.color) or C.body)
          if row.current and not head then row.mark:Show() else row.mark:Hide() end
        end)
        r._cutTexts = { r.text }
        self.rows[i] = r
      end
      local it = self.items[i + self.offset]
      r.item = it
      r.current = self.owner and not it.header and it.value == self.owner.value
      r:SetWidth(w - 2)
      r.text:SetText(it.header and Kit.Upper(it.text or "") or it.text or tostring(it.value))
      r.right:SetText(it.right or "")
      TextColor(r.right, it.rightColor or C.muted)
      local rw = (it.right and it.right ~= "") and (TextW(r.right) + S.gap) or 0
      Kit.Fit(r.text, w - 20 - rw)
      Refresh(r)
      r:Show()
    end
    for i = min(#self.items, MENU_ROWS) + 1, #self.rows do self.rows[i]:Hide() end
  end
  Kit._menu = m
  return m
end

-- dropdown: opts.items = { { value = v, text = "..." }, ... } (or a function returning them), opts.get(), opts.set(v)
function Kit.Dropdown(parent, opts)
  opts = opts or {}
  local d = CreateFrame("Button", nil, parent)
  d:SetHeight(S.button)
  d.bg = Fill(d, C.input)
  d.bd = Border(d, C.mid)
  d.text = Text(d, "row", C.body)
  d.text:SetPoint("LEFT", 8, 0)
  -- (02.11.2026, Daniel: "das v beim dropdown verstehe ich nicht") the arrow from the shared symbols (Style.ICONS.dropdown)
  d.arrow = d:CreateTexture(nil, "ARTWORK")
  d.arrow:SetSize(12, 12)
  d.arrow:SetPoint("RIGHT", -8, 0)
  local St = StyleKit()
  if St and St.SetIcon then St.SetIcon(d.arrow, "dropdown") else d.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up") end
  Call(d.arrow, "SetDesaturated", true)
  SetCol(d.arrow, C.txGold)
  local function Items()
    local list = type(opts.items) == "function" and Safe("dropdown items", opts.items) or opts.items
    return type(list) == "table" and list or {}
  end
  function d:Update(v)
    if v == nil then v = Safe("dropdown get", opts.get) end
    self.value = v
    local text = ""
    for _, it in ipairs(Items()) do if not it.header and it.value == v then text = it.text or tostring(v) end end
    self.text:SetText(text)
    Kit.Fit(self.text, (self._w or self:GetWidth() or 0) - 28)
  end
  function d:Choose(v)
    self:Update(v)
    Safe("dropdown", opts.set, v, self)
  end
  function d:Layout(w) self._w = w self:SetWidth(w) self:Update(self.value) end
  function d:Open()
    local m = Menu()
    if m:IsShown() and m.owner == self then m:Hide() return end
    m:Hide()
    m.owner, m.items, m.offset = self, Items(), 0
    for i, it in ipairs(m.items) do if not it.header and it.value == self.value then m.offset = Clamp(i - MENU_ROWS, 0, max(0, #m.items - MENU_ROWS)) end end
    local w = self._w or self:GetWidth() or 120
    for _, it in ipairs(m.items) do
      self.text:SetText(it.text or tostring(it.value))
      local extra = 0
      if it.right and it.right ~= "" then self.text:SetText(it.right) extra = TextW(self.text) + S.gap + 8 self.text:SetText(it.text or tostring(it.value)) end
      w = max(w, min(360, TextW(self.text) + 24 + extra))
    end
    self:Update(self.value)
    m._w = w
    m:SetSize(w, min(#m.items, MENU_ROWS) * S.menuRow + 2)
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    self._open = true
    m:Show()
    m:Draw()
    Refresh(self)
  end
  d._cutTexts = { d.text }
  Clickable(d, function(self) self:Open() end)
  d:SetScript("OnHide", function(self) local m = Kit._menu if m and m.owner == self then m:Hide() end end)
  Stateful(d, function(self, st)
    self.bd:SetColor((self._open or st == "hover") and C.gold or C.mid)
    TextColor(self.text, st == "hover" and C.hero or C.body)
    SetCol(self.arrow, (self._open or st == "hover") and C.hero or C.txGold)
  end)
  d._onDisabled = function(self, off) if off then Call(self, "Disable") self:GetScript("OnHide")(self) else Call(self, "Enable") end end
  d:Layout(opts.width or 160)
  d:Update()
  return d
end

-- search box 28 high: placeholder, clear button, opts.onChange(text) on every typed change
function Kit.SearchBox(parent, opts)
  opts = opts or {}
  local e = CreateFrame("EditBox", nil, parent)
  e:SetHeight(S.button)
  Call(e, "SetAutoFocus", false)
  local fo = Kit.Font("row")
  if fo then Call(e, "SetFontObject", fo) end
  Call(e, "SetTextColor", C.body[1], C.body[2], C.body[3], 1)
  Call(e, "SetTextInsets", 8, 24, 0, 0)
  Call(e, "SetMaxLetters", 80)
  e.bg = Fill(e, C.input)
  e.bd = Border(e, C.mid)
  e.hint = Text(e, "row", C.quiet)
  e.hint:SetPoint("LEFT", 8, 0)
  e.hint:SetText(opts.placeholder or "Search...")
  e.clear = CreateFrame("Button", nil, e)
  e.clear:SetSize(16, 16)
  e.clear:SetPoint("RIGHT", -6, 0)
  e.clear.text = Text(e.clear, "badge", C.muted, "CENTER")
  e.clear.text:SetPoint("CENTER", 0, 0)
  e.clear.text:SetText("x")
  local function Changed(self, user)
    local t = self:GetText() or ""
    if t == "" then self.hint:Show() self.clear:Hide() else self.hint:Hide() self.clear:Show() end
    if user then Safe("search", opts.onChange, t, self) end
  end
  e.clear:SetScript("OnClick", function()
    e:SetText("")
    e:ClearFocus()
    Changed(e, true)
  end)
  e:SetScript("OnTextChanged", Changed)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEditFocusGained", function(self) self._focus = true Refresh(self) end)
  e:SetScript("OnEditFocusLost", function(self) self._focus = nil Refresh(self) end)
  function e:Layout(w) self:SetWidth(w) Kit.Fit(self.hint, w - 32) end
  Stateful(e, function(self, st)
    self.bd:SetColor(self._focus and C.gold or st == "hover" and C.goldMuted or C.mid)
  end)
  e._onDisabled = function(self, off) Call(self, "EnableMouse", not off) if off then self:ClearFocus() end end
  e:Layout(opts.width or 200)
  Changed(e, false)
  return e
end

---------------------------------------------------------------------------
-- Rows: ListRow (36), GroupHeader (28), SubRow (28, chain step), ZoneRow (28), OptionRow (36)
-- SetItem(item, index, list) fills a row; Layout(width) places the parts (fixed columns, the title grows).
---------------------------------------------------------------------------
local function RowBase(parent, h, color)
  local r = CreateFrame("Button", nil, parent)
  r:SetHeight(h)
  r.bg = Fill(r, color)
  r.mark = Tex(r, "ARTWORK", C.grey)
  r.mark:SetPoint("TOPLEFT") r.mark:SetPoint("BOTTOMLEFT") r.mark:SetWidth(S.markBar)
  r.lineB = Tex(r, "ARTWORK", C.divider)
  r.lineB:SetPoint("BOTTOMLEFT") r.lineB:SetPoint("BOTTOMRIGHT") r.lineB:SetHeight(1)
  r.lineT = Tex(r, "ARTWORK", C.gold)
  r.lineT:SetPoint("TOPLEFT") r.lineT:SetPoint("TOPRIGHT") r.lineT:SetHeight(1)
  r.lineT:Hide()
  return r
end

local function MarkColor(st) local c = STATUS[st] return c and c.fg end

-- (minor 3, Daniel 02.11.2026: the quest list "ohne Hintergrund und Rahmen", variant A) a plain row over the game world:
-- no fill unless the mouse is on it or it is picked; marks and the fine lines stay. row.plain is set by its list.
local function PlainBg(row, keep)
  if row.plain and not keep then row.bg:Hide() else row.bg:Show() end
end

-- item: status, level, title, sub, right, chain ("4a"), pill = { text, kind }, dots = { status, ... }, ring = { done, total },
-- done (dimmed), tooltip = { title, lines }
-- (minor 3) icon (texture path or file ID: a framed 24 px square instead of the level badge; iconCoords), levelStatus,
-- markColor ({ r, g, b }: the left mark in a colour of the addon's own), titleColor, subColor, rightColor (Kit.C keys or
-- { r, g, b }), tooltipFn(row) returns title, lines, hint; onHover(row, on); active (the row looks picked)
-- (minor 3, Questdon step 4) indent (px: the parts of a chain stand in by S.indent; the mark stays at the edge), right2 (a
-- second line in the right column under right: "+1.080 XP" over the money), right2Color; title and sub sit in the middle
-- of a row taller than 36 (item.h)
-- (minor 4, Golddon) quality (0..7: the icon's edge and the title in the item quality colour unless titleColor), itemID
-- (the mouse shows the game's item tooltip unless tooltip / tooltipFn; shift-click links the item in the chat)
-- (minor 11, Luredon) lead (a short quiet text in a column of S.lead px left of everything: "18:20"), leadColor
-- (minor 14) chainDone (the chain mark green with a tick: a part already done)
function Kit.ListRow(parent)
  local r = RowBase(parent, S.row, C.row)
  r.badge = Kit.LevelBadge(r)
  r.badge:SetPoint("LEFT", S.markBar + 8, 0)
  r.iconBox = CreateFrame("Frame", nil, r)
  r.iconBox:SetSize(S.iconMid, S.iconMid)
  r.iconBox:SetPoint("LEFT", S.markBar + 8, 0)
  r.iconBox.bg = Fill(r.iconBox, C.input)
  r.iconBox.bd = Border(r.iconBox, C.goldMuted)
  r.icon = r.iconBox:CreateTexture(nil, "ARTWORK")
  r.icon:SetPoint("TOPLEFT", 1, -1) r.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  r.iconBox:Hide()
  r.chain = Kit.ChainMark(r, "")
  r.title = Text(r, "row", C.title)
  r.sub = Text(r, "sub", C.muted)
  r.right = Text(r, "sub", C.muted, "RIGHT")
  r.right:SetPoint("RIGHT", -S.pad, 0)
  r.right2 = Text(r, "sub", C.muted, "RIGHT")
  r.pill = Kit.Pill(r)
  r.dots = Kit.Dots(r)
  r.ring = Kit.Ring(r, 28)
  function r:SetItem(it, index)
    self.item, self._alt = it, index and index % 2 == 0
    -- (minor 7) item.compact: smaller fonts
    local compact = it.compact and true or nil
    if compact ~= self._compact then
      self._compact = compact
      local ft, fs = Kit.Font(compact and "sub" or "row"), Kit.Font(compact and "mono" or "sub")
      if ft then Call(self.title, "SetFontObject", ft) end
      if fs then Call(self.sub, "SetFontObject", fs) end
      -- (minor 8) Style.FitText keeps the first font as the base and puts it back: start from the new one
      self.title._fitBase, self.title._fitSize, self.sub._fitBase, self.sub._fitSize = nil, nil, nil, nil
    end
    -- (minor 11) item.lead: a quiet column on the left (a time)
    if it.lead ~= nil then
      if not self.lead then self.lead = Text(self, "sub", C.muted, "RIGHT") end
      self.lead:SetText(tostring(it.lead))
      TextColor(self.lead, it.leadColor or C.muted)
      self.lead:Show()
    elseif self.lead then
      self.lead:Hide()
    end
    -- (minor 5) item.radio (true / false): a choice point on the left (exactly one of a list)
    if it.radio ~= nil then
      if not self.radio then self.radio = Kit.Radio(self) self.radio:EnableMouse(false) end
      self.radio:SetChecked(it.radio)
      self.radio:Show()
    elseif self.radio then
      self.radio:Hide()
    end
    if it.icon or it.iconKind then
      -- (minor 5) item.badgeRight: the level badge in the right column, the symbol stays on the left (Leveldon's steps)
      if it.badgeRight and it.level ~= nil then
        self.badge:SetLevel(it.level, it.levelStatus or (tonumber(it.level) and Kit.QuestDifficulty(it.level)) or it.status)
        self.badge:Show()
      else
        self.badge:Hide()
      end
      -- (minor 5) item.iconKind: a symbol of Style.ICONS (atlas or file), e.g. "step_accept"
      local St = it.iconKind and StyleKit()
      if St then
        St.SetIcon(self.icon, it.iconKind)
      else
        Call(self.icon, "SetTexture", it.icon)
        if it.iconCoords then Call(self.icon, "SetTexCoord", unpack(it.iconCoords)) else Call(self.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93) end
      end
      self.iconBox.bd:SetColor(it.quality and Kit.QualityColor(it.quality) or C.goldMuted)
      -- (minor 6) item.iconPlain: the symbol 16 px without the box (the column keeps its width)
      self.icon:ClearAllPoints()
      if it.iconPlain then
        self.iconBox.bg:Hide()
        self.iconBox.bd:SetColor(C.goldMuted, 0)
        self.icon:SetSize(S.icon, S.icon)
        self.icon:SetPoint("CENTER", 0, 0)
      else
        self.iconBox.bg:Show()
        self.icon:SetPoint("TOPLEFT", 1, -1) self.icon:SetPoint("BOTTOMRIGHT", -1, 1)
      end
      self.iconBox:Show()
    elseif it.radio ~= nil then
      self.badge:Hide()
      self.iconBox:Hide()
    else
      self.iconBox:Hide()
      local lv = it.level
      self.badge:SetLevel(lv, it.levelStatus or (tonumber(lv) and Kit.QuestDifficulty(lv)) or it.status)
      if lv == nil then self.badge:Hide() else self.badge:Show() end
    end
    -- a chain mark is a text ("4a") or a number; anything else (a flag of the addon's own) is no mark
    -- item.mark: the same small mark without meaning a chain step (a follow-up under its prerequisite: "2a")
    local m = it.chain ~= nil and it.chain or it.mark
    local ch = (type(m) == "string" or type(m) == "number") and tostring(m) or nil
    self.chain:SetText(ch) if ch then self.chain:Show() else self.chain:Hide() end
    self.chain:SetDone(ch and it.chainDone) -- (minor 14)
    self.title:SetText(it.title or "")
    self.sub:SetText(it.sub or "")
    self.right:SetText(it.right or "")
    self.right2:SetText(it.right2 or "")
    if type(it.pill) == "table" then self.pill:SetPill(it.pill[1], it.pill[2]) self.pill:Show() else self.pill:Hide() end
    if it.dots then self.dots:SetDots(it.dots) self.dots:Show() else self.dots:Hide() end
    if it.ring then self.ring:SetValue(it.ring[1], it.ring[2]) self.ring:Show() else self.ring:Hide() end
    TextColor(self.sub, it.subColor or C.muted)
    TextColor(self.right, it.rightColor or C.muted)
    TextColor(self.right2, it.right2Color or C.muted)
    self._tip = type(it.tooltip) == "table" and { it.tooltip[1], it.tooltip[2] } or nil -- (a function: the addon's own, see tooltipFn)
    self._tipFn, self._onHover = it.tooltipFn, it.onHover
    if not self._tip and not self._tipFn and it.itemID then self._tipFn = Kit.ItemTipFn end
    self._dim = it.done and true or nil
    self._active = it.active and true or nil
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    self._w = w
    local indent = self.item and tonumber(self.item.indent) or 0
    local x0 = S.markBar + 8 + indent
    local right = self.item and self.item.badgeRight and self.iconBox:IsShown()
    if self.lead and self.lead:IsShown() then
      self.lead:ClearAllPoints() self.lead:SetPoint("LEFT", x0, 0)
      Call(self.lead, "SetWidth", S.lead)
      Kit.Fit(self.lead, S.lead)
      x0 = x0 + S.lead + S.gap
    end
    if self.radio and self.radio:IsShown() then
      self.radio:ClearAllPoints() self.radio:SetPoint("LEFT", x0, 0)
      x0 = x0 + 16 + S.gap
    end
    self.badge:ClearAllPoints()
    if not right then self.badge:SetPoint("LEFT", x0, 0) end
    self.iconBox:ClearAllPoints() self.iconBox:SetPoint("LEFT", x0, 0)
    local x = x0 + ((self.badge:IsShown() and not right) and S.badgeW + S.gap or 0) + (self.iconBox:IsShown() and S.iconMid + S.gap or 0)
    if self.chain:IsShown() then
      self.chain:ClearAllPoints() self.chain:SetPoint("LEFT", x, 0)
      x = x + self.chain:GetWidth() + 6
    end
    -- two lines in a taller row: in its middle
    local rowH = tonumber(self:GetHeight()) or S.row
    local top = max(3, floor((rowH - S.row) / 2) + 5)
    -- right column (fixed): the right text at the edge, a ring, pill or dots left of it; right2 under right
    local colW = self.item and self.item.rightWidth or S.colRight
    local part
    for _, p in ipairs({ self.ring, self.pill, self.dots }) do if p:IsShown() then part = p break end end
    local rx = S.pad
    local two = self.right2:GetText() ~= ""
    self.right:ClearAllPoints() self.right2:ClearAllPoints()
    if two then
      self.right:SetPoint("TOPRIGHT", -S.pad, -top)
      self.right2:SetPoint("TOPRIGHT", -S.pad, -top - 15)
      Kit.Fit(self.right2, part and 40 or colW)
    else
      self.right:SetPoint("RIGHT", -S.pad, 0)
    end
    if self.right:GetText() ~= "" or two then
      local tw = part and 40 or colW
      Kit.Fit(self.right, tw)
      rx = rx + min(max(TextW(self.right), two and TextW(self.right2) or 0), tw) + 6
    end
    if part then part:ClearAllPoints() part:SetPoint("RIGHT", -rx, 0) rx = rx + (part:GetWidth() or 0) + 6 end
    -- (minor 5) the level badge on the right: in the right column, left of the right text
    if right and self.badge:IsShown() then self.badge:SetPoint("RIGHT", -rx, 0) end
    local budget = w - x - S.pad - colW - S.gap
    self.title:ClearAllPoints() self.sub:ClearAllPoints()
    if self._compact then top = max(2, floor((rowH - 26) / 2) + 2) end
    if self.sub:GetText() ~= "" then
      self.title:SetPoint("TOPLEFT", x, -top)
      self.sub:SetPoint("TOPLEFT", x, -top - (self._compact and 12 or 15))
    else
      self.title:SetPoint("LEFT", x, 0)
    end
    Kit.Fit(self.title, budget)
    Kit.Fit(self.sub, budget)
  end
  r._cutTexts = { r.title, r.sub, r.right, r.right2 }
  Stateful(r, function(self, st)
    local sel = st == "selected" or self._active
    local it = self.item
    SetCol(self.bg, sel and C.rowSel or st == "hover" and C.rowHover or self._alt and C.rowAlt or C.row)
    local mc = sel and C.goldBright or (it and it.markColor) or MarkColor(it and it.status)
    if mc then SetCol(self.mark, mc) self.mark:Show() else self.mark:Hide() end
    SetCol(self.lineB, sel and C.gold or C.divider)
    if sel then self.lineT:Show() else self.lineT:Hide() end
    TextColor(self.title, (it and it.titleColor) or (it and it.quality and Kit.QualityColor(it.quality)) or (sel and C.hero or (it and it.compact) and C.body or C.title))
    PlainBg(self, sel or st == "hover")
  end)
  return r
end

-- group header 28: gold capitals, + / - to fold, count on the right; item.text, item.count, item.collapsed;
-- item.static = no folding (a section title)
-- (minor 3) item.color (the title in a status colour, e.g. "green"), item.right (a short text before the count, e.g. "show"),
-- item.tooltipFn(row); item.plainCase keeps the case of the text (dates, names)
function Kit.GroupHeader(parent)
  local r = RowBase(parent, S.sub, C.group)
  r.mark:Hide()
  r.arrow = Text(r, "group", C.txGold, "CENTER")
  r.arrow:SetPoint("LEFT", S.pad - 2, 0)
  r.arrow:SetWidth(10)
  r.text = Text(r, "group", C.txGold)
  r.count = Text(r, "sub", C.muted, "RIGHT")
  r.count:SetPoint("RIGHT", -S.pad, 0)
  function r:SetItem(it)
    self.item = it
    self.arrow:SetText(it.static and "" or it.collapsed and "+" or "-")
    local t = tostring(it.text or "")
    self.text:SetText(it.plainCase and t or Upper(t))
    TextColor(self.text, it.color or C.txGold)
    local right = it.right and tostring(it.right) or ""
    if it.count ~= nil then right = right ~= "" and (right .. "  " .. tostring(it.count)) or tostring(it.count) end
    self.count:SetText(right)
    self._tipFn = it.tooltipFn
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    self._w = w
    local x = self.item and self.item.static and S.pad or S.pad + 14
    self.text:ClearAllPoints()
    self.text:SetPoint("LEFT", x, 0)
    Kit.Fit(self.count, max(60, floor(w * 0.45)))
    Kit.Fit(self.text, w - x - S.pad - TextW(self.count) - S.gap)
  end
  r._cutTexts = { r.text }
  Stateful(r, function(self, st)
    local hover = st == "hover" and not (self.item and self.item.static)
    SetCol(self.bg, hover and C.rowHover or C.group)
    PlainBg(self, hover)
  end)
  return r
end

-- chain step 28, indented: item.chain ("4a"), item.title, item.status = done / current / next / later, item.right
function Kit.SubRow(parent)
  local r = RowBase(parent, S.sub, C.sub)
  r.chain = Kit.ChainMark(r, "")
  r.chain:SetPoint("LEFT", S.indent, 0)
  r.title = Text(r, "row", C.title)
  r.right = Text(r, "sub", C.muted, "RIGHT")
  r.right:SetPoint("RIGHT", -S.pad, 0)
  function r:SetItem(it)
    self.item = it
    self.chain:SetText(it.chain or "")
    self.title:SetText(it.title or "")
    self.right:SetText(it.right or "")
    self._tip = type(it.tooltip) == "table" and { it.tooltip[1], it.tooltip[2] } or nil -- (a function: the addon's own, see tooltipFn)
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    self._w = w
    local x = S.indent + self.chain:GetWidth() + S.gap
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", x, 0)
    Kit.Fit(self.right, 60)
    local rw = self.right:GetText() ~= "" and TextW(self.right) + S.gap or 0
    Kit.Fit(self.title, w - x - S.pad - rw)
  end
  r._cutTexts = { r.title }
  Stateful(r, function(self, st)
    local s = self.item and self.item.status
    local current = s == "current"
    SetCol(self.bg, st == "selected" and C.rowSel or st == "hover" and C.rowHover or current and C.rowSel or C.sub)
    SetCol(self.mark, st == "selected" and C.goldBright or MarkColor(s) or C.mid)
    TextColor(self.title, (current or st == "selected") and C.hero or s == "next" and C.title or C.muted)
    PlainBg(self, st ~= "normal")
  end)
  return r
end

-- sidebar row 28: item.text, item.count, item.short (shown in the icon rail), item.status (mark colour)
-- (minor 3) item.range (right, "10-20"), item.progress = { done, total } (a 3 px gold bar and "12/48" below the name;
-- give the item h = 36), item.here (a blue dot: you are here), item.quiet (dimmed name: nothing to do there)
function Kit.ZoneRow(parent)
  local r = RowBase(parent, S.sub, C.row)
  r.text = Text(r, "row", C.body)
  r.count = Text(r, "sub", C.muted, "RIGHT")
  r.short = Text(r, "badge", C.body, "CENTER")
  r.short:SetPoint("CENTER", 1, 0)
  -- (minor 4, Guildon Crafts) item.icon (texture, item.iconCoords): 16 px left of the name; in the icon rail instead of the letters
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(S.icon, S.icon)
  r.icon:Hide()
  r.here = Tex(r, "OVERLAY", C.blue)
  r.here:SetSize(5, 5)
  r.track = Tex(r, "ARTWORK", C.input)
  r.track:SetHeight(3)
  r.fill = Tex(r, "OVERLAY", C.gold)
  r.fill:SetHeight(3)
  r.num = Text(r, "mono", C.quiet, "RIGHT")
  function r:SetItem(it, index, list)
    self.item, self.rail = it, list and list.rail
    self.text:SetText(it.text or "")
    self.count:SetText(it.range or (it.count ~= nil and tostring(it.count)) or "")
    self.short:SetText(it.short or tostring(it.text or ""):sub(1, 2))
    if it.icon then
      Call(self.icon, "SetTexture", it.icon)
      if it.iconCoords then Call(self.icon, "SetTexCoord", unpack(it.iconCoords)) else Call(self.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93) end
    end
    local p = it.progress
    self.num:SetText(p and p[2] and p[2] > 0 and Kit.Fraction(p[1], p[2]) or "")
    self._tip = self.rail and { it.text, { it.range or (it.count and tostring(it.count)) or nil, self.num:GetText() ~= "" and self.num:GetText() or nil } } or nil
    self._tipFn = (not self.rail) and it.tooltipFn or nil
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    self._w = w
    local it = self.item or {}
    local p = it.progress
    local twoLines = p and p[2] and p[2] > 0 and not self.rail
    if self.rail then
      self.text:Hide() self.count:Hide() self.short:Show() self.track:Hide() self.fill:Hide() self.num:Hide()
      if it.icon then
        self.short:Hide()
        self.icon:ClearAllPoints() self.icon:SetPoint("CENTER", 1, 0) self.icon:SetSize(S.iconMid - 4, S.iconMid - 4) self.icon:Show()
      else
        self.icon:Hide()
      end
      if it.here then self.here:ClearAllPoints() self.here:SetPoint("TOPRIGHT", -5, -5) self.here:Show() else self.here:Hide() end
      Kit.Fit(self.short, w - 8)
      return
    end
    self.text:Show() self.count:Show() self.short:Hide()
    local x = S.markBar + 8
    if it.icon then
      self.icon:ClearAllPoints() self.icon:SetPoint("LEFT", x, twoLines and 6 or 0) self.icon:SetSize(S.icon, S.icon) self.icon:Show()
      x = x + S.icon + 6
    else
      self.icon:Hide()
    end
    if it.here then
      self.here:ClearAllPoints() self.here:SetPoint("LEFT", x, twoLines and 5 or 0) self.here:Show()
      x = x + 9
    else
      self.here:Hide()
    end
    local y = twoLines and 6 or 0
    self.text:ClearAllPoints() self.count:ClearAllPoints()
    self.text:SetPoint("LEFT", x, y)
    self.count:SetPoint("RIGHT", -8, y)
    Kit.Fit(self.count, 56)
    Kit.Fit(self.text, w - x - 8 - TextW(self.count) - 6)
    if twoLines then
      Kit.Fit(self.num, 56) -- (minor 16) room for the spaces of Kit.Fraction
      local nw = max(TextW(self.num), 28)
      self.num:ClearAllPoints() self.num:SetPoint("RIGHT", -8, -8)
      local bw = max(10, w - S.markBar - 8 - 8 - nw - 6)
      self.track:ClearAllPoints() self.track:SetPoint("LEFT", S.markBar + 8, -8) self.track:SetWidth(bw)
      local f = min(1, p[1] / p[2])
      if f > 0 then
        self.fill:ClearAllPoints() self.fill:SetPoint("LEFT", self.track, "LEFT", 0, 0) self.fill:SetWidth(max(1, bw * f))
        SetCol(self.fill, f >= 1 and C.green or C.gold)
        self.fill:Show()
      else
        self.fill:Hide()
      end
      self.track:Show() self.num:Show()
    else
      self.track:Hide() self.fill:Hide() self.num:Hide()
    end
  end
  r._cutTexts = { r.text }
  Stateful(r, function(self, st)
    local sel = st == "selected"
    local it = self.item
    SetCol(self.bg, sel and C.rowSel or st == "hover" and C.rowHover or C.row)
    local mc = sel and C.goldBright or MarkColor(it and it.status)
    if mc then SetCol(self.mark, mc) self.mark:Show() else self.mark:Hide() end
    local tc = sel and C.hero or (it and it.quiet) and C.quiet or C.body
    TextColor(self.text, tc)
    TextColor(self.short, tc)
  end)
  return r
end

-- option row 36: label, description below, the control (Toggle, Slider, Dropdown, Button) on the right;
-- opts.indent for a sub-option; SetDisabled greys the row and its control
function Kit.OptionRow(parent, opts)
  opts = opts or {}
  local r = RowBase(parent, S.row, C.row)
  r.mark:Hide()
  r.indent = opts.indent and S.indent - S.pad or 0
  r.label = Text(r, "row", C.title)
  r.desc = Text(r, "sub", C.muted)
  r.control = opts.control
  if r.control then
    r.control:SetParent(r)
    r.control:ClearAllPoints()
    r.control:SetPoint("RIGHT", -S.pad, 0)
  end
  function r:SetText(label, desc)
    self.label:SetText(label or "")
    self.desc:SetText(desc or "")
    if self._w then self:Layout(self._w) end
  end
  function r:Layout(w)
    self._w = w
    self:SetWidth(w)
    local x = S.pad + self.indent
    local cw = self.control and self.control:GetWidth() or 0
    self.label:ClearAllPoints() self.desc:ClearAllPoints()
    if self.desc:GetText() ~= "" then
      self.label:SetPoint("TOPLEFT", x, -5)
      self.desc:SetPoint("TOPLEFT", x, -20)
    else
      self.label:SetPoint("LEFT", x, 0)
    end
    local budget = w - x - S.pad - cw - S.pad
    Kit.Fit(self.label, budget)
    Kit.Fit(self.desc, budget)
  end
  r:SetText(opts.label, opts.desc)
  r._cutTexts = { r.label, r.desc }
  r._onDisabled = function(self, off) if self.control and self.control.SetDisabled then self.control:SetDisabled(off) end end
  Stateful(r, function(self, st) SetCol(self.bg, st == "hover" and C.rowHover or C.row) end)
  return r
end

---------------------------------------------------------------------------
-- (minor 3, Questdon step 4: the dungeons as index cards) Card: an index card of fixed height S.card. A square c.art on the
-- left of the head for the addon's own picture, title and a line below, a ring "3/6" on the right; a status line with a
-- 3 px mark in a status colour; up to two buttons at the bottom (half the width each).
--   c:SetData({ title, sub, ring = { done, total }, status = text, statusColor = "green" | ..., selected,
--     buttons = { { text, onClick(button), kind, tooltip = { title, lines, hint }, disabled }, ... }, tooltipFn(card),
--     art = function(card, data) (draws into card.art) })
--   c:Layout(width). The card itself is not clickable; the mouse over it brightens its edge.
-- CardRow: a row of cards for Kit.List (kind "cards": item.cards = { data, ... }, item.cols; height S.card + S.gap)
---------------------------------------------------------------------------
function Kit.Card(parent)
  local c = CreateFrame("Frame", nil, parent)
  c:SetHeight(S.card)
  c.bg = Fill(c, C.card)
  c.bd = Border(c, C.divider)
  c.top = Tex(c, "OVERLAY", C.goldMuted)
  c.top:SetPoint("TOPLEFT") c.top:SetPoint("TOPRIGHT") c.top:SetHeight(2)
  c.art = CreateFrame("Frame", nil, c)
  c.art:SetSize(S.iconBig, S.iconBig)
  c.art:SetPoint("TOPLEFT", S.pad, -S.pad)
  Fill(c.art, C.input)
  c.art.bd = Border(c.art, C.goldMuted)
  c.title = Text(c, "title", C.hero)
  c.title:SetPoint("TOPLEFT", S.pad + S.iconBig + S.gap, -S.pad - 2)
  c.sub = Text(c, "sub", C.muted)
  c.sub:SetPoint("TOPLEFT", S.pad + S.iconBig + S.gap, -S.pad - 20)
  c.ring = Kit.Ring(c, S.iconBig)
  c.ring:SetPoint("TOPRIGHT", -S.pad, -S.pad)
  c.line = CreateFrame("Frame", nil, c)
  c.line:SetHeight(S.buttonSmall)
  c.line:SetPoint("TOPLEFT", S.pad, -(S.pad + S.iconBig + S.gap))
  c.line:SetPoint("TOPRIGHT", -S.pad, -(S.pad + S.iconBig + S.gap))
  Fill(c.line, C.sub)
  c.line.mark = Tex(c.line, "ARTWORK", C.grey)
  c.line.mark:SetPoint("TOPLEFT") c.line.mark:SetPoint("BOTTOMLEFT") c.line.mark:SetWidth(S.markBar)
  c.status = Text(c.line, "sub", C.body)
  c.status:SetPoint("LEFT", S.markBar + 6, 0)
  c.buttons = {}
  for i = 1, 2 do
    local b = Kit.Button(c, "", { small = true })
    b:Hide()
    c.buttons[i] = b
  end
  function c:SetData(d)
    d = d or {}
    self.data = d
    self.title:SetText(d.title and Upper(d.title) or "")
    self.sub:SetText(d.sub or "")
    if d.ring then self.ring:SetValue(d.ring[1], d.ring[2]) self.ring:Show() else self.ring:Hide() end
    self.status:SetText(d.status or "")
    SetCol(self.line.mark, MarkColor(d.statusColor) or C.mid)
    for i, b in ipairs(self.buttons) do
      local a = d.buttons and d.buttons[i]
      if a then
        b:SetText(a.text or "")
        b._onClick = a.onClick
        if a.tooltip then b:SetTooltip(a.tooltip[1], a.tooltip[2], a.tooltip[3]) else b._tip = nil end
        b:SetKind(a.kind or "secondary")
        b:SetDisabled(a.disabled)
        b:Show()
      else
        b:Hide()
      end
    end
    self._tipFn = d.tooltipFn
    self._selected = d.selected and true or nil
    if type(d.art) == "function" then Safe("card art", d.art, self, d) end
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function c:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    self:SetWidth(w)
    local tx = S.pad + S.iconBig + S.gap
    local room = w - tx - S.pad - (self.ring:IsShown() and S.iconBig + S.gap or 0)
    Kit.Fit(self.title, max(1, room))
    Kit.Fit(self.sub, max(1, room))
    Kit.Fit(self.status, max(1, w - 2 * S.pad - S.markBar - 12))
    local shown = {}
    for _, b in ipairs(self.buttons) do if b:IsShown() then shown[#shown + 1] = b end end
    local each = floor((w - 2 * S.pad - (#shown - 1) * S.gap) / max(1, #shown))
    for i, b in ipairs(shown) do
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", S.pad + (i - 1) * (each + S.gap), S.pad)
      b:Layout(max(1, each))
    end
  end
  c._cutTexts = { c.title, c.sub, c.status }
  Stateful(c, function(self, st)
    local on = st == "hover" or st == "selected"
    SetCol(self.top, on and C.goldBright or C.goldMuted)
    self.bd:SetColor(st == "selected" and C.gold or st == "hover" and C.goldMuted or C.divider)
  end)
  return c
end

function Kit.CardRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r.cards = {}
  function r:SetItem(it)
    self.item = it
    local list = it.cards or {}
    for i, d in ipairs(list) do
      local c = self.cards[i]
      if not c then c = Kit.Card(self) self.cards[i] = c end
      c:Show()
      c:SetData(d)
    end
    for i = #list + 1, #self.cards do self.cards[i]:Hide() end
    self:Layout(self._w or self:GetWidth())
  end
  function r:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    local cols = max(1, tonumber(self.item and self.item.cols) or 3)
    local each = floor((w - 2 * S.gap - (cols - 1) * S.gap) / cols)
    for i, c in ipairs(self.cards) do
      if c:IsShown() then
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self, "TOPLEFT", S.gap + (i - 1) * (each + S.gap), 0)
        c:Layout(max(1, each))
      end
    end
  end
  return r
end

---------------------------------------------------------------------------
-- List: virtual, only the visible rows exist (pooled per kind). items = { { kind = "row" | "group" | "sub" | "zone", ... } }
-- opts.onClick(item, button, list), opts.onToggle(item, list) (group headers), opts.zebra (default true)
-- (minor 3) opts.kinds = { name = { make = function(list) return row end, h = 36 } }: an addon's own kinds (a row has
-- SetItem(item, index, list) and Layout(width); Kit.Stateful/Kit.Fill etc. help); item.h: a height of its own;
-- item.onClick(row, button) when opts.onClick is not given; opts.plain / l:SetPlain(on): rows without fill (variant A);
-- l:SetEmpty(text) shows a quiet line in the middle when there are no items; l:Rows() the rows drawn now.
---------------------------------------------------------------------------
local KIND_H = { row = S.row, group = S.sub, sub = S.sub, zone = S.sub, cards = S.card + S.gap }
Kit.KIND_HEIGHT = KIND_H
local ROW_MAKER = { row = Kit.ListRow, group = Kit.GroupHeader, sub = Kit.SubRow, zone = Kit.ZoneRow, cards = Kit.CardRow }

function Kit.List(parent, opts)
  opts = opts or {}
  local kinds = opts.kinds or {}
  local l = CreateFrame("Frame", nil, parent)
  Call(l, "SetClipsChildren", true)
  Call(l, "EnableMouseWheel", true)
  l.items, l.tops, l.total, l.offset, l.w, l.h = {}, {}, 0, 0, 0, 0
  l.pools, l.made, l.drawnRows = {}, 0, {}
  l.plain = opts.plain and true or nil
  l.thumb = Tex(l, "OVERLAY", C.goldMuted)
  l.thumb:SetWidth(3)
  l.thumb:Hide()
  l.empty = Text(l, "row", C.quiet, "CENTER")
  l.empty:SetPoint("TOP", 0, -24)
  l.empty:Hide()
  local function Height(it)
    if it.h then return it.h end
    local k = it.kind or "row"
    return (kinds[k] and kinds[k].h) or KIND_H[k] or S.row
  end
  l.ItemHeight = function(_, it) return Height(it) end
  function l:SetItems(items, reset)
    self.items = items or {}
    local y = 0
    self.tops = {}
    for i, it in ipairs(self.items) do self.tops[i] = y y = y + Height(it) end
    self.total = y
    if reset then self.offset = 0 end -- (minor 3) reset = true: back to the top
    self:SetOffset(self.offset, true)
  end
  function l:SetEmpty(text) self.emptyText = text self:Draw() end
  function l:SetPlain(on) self.plain = on and true or nil self:Draw() end
  function l:Resize(w, h)
    self.w, self.h = w, h
    self:SetSize(w, h)
    self:SetOffset(self.offset, true)
  end
  function l:SetRail(on) self.rail = on and true or nil self:Draw() end
  function l:MaxOffset() return max(0, self.total - self.h) end
  function l:SetOffset(o, force)
    o = floor(Clamp(o, 0, self:MaxOffset()))
    if o == self.offset and not force then return end
    self.offset = o
    self:Draw()
  end
  function l:Scroll(dy) self:SetOffset(self.offset + dy) end
  -- first item whose bottom lies below the top edge (binary search)
  function l:First()
    local lo, hi = 1, #self.items
    while lo < hi do
      local mid = floor((lo + hi) / 2)
      if self.tops[mid] + Height(self.items[mid]) <= self.offset then lo = mid + 1 else hi = mid end
    end
    return lo
  end
  function l:Acquire(kind)
    local pool = self.pools[kind]
    if not pool then pool = { used = 0 } self.pools[kind] = pool end
    pool.used = pool.used + 1
    local r = pool[pool.used]
    if not r then
      local maker = kinds[kind] and kinds[kind].make or ROW_MAKER[kind] or Kit.ListRow
      r = maker(self)
      r.list = self
      if r.RegisterForClicks then
        Clickable(r, function(row, button)
          local it = row.item
          if not it then return end
          -- (minor 4) shift-click on an item row: the link into the chat, nothing else
          if it.itemID and Kit.LinkItem(it.itemID) then return end
          if (it.kind == "group") and not it.static and not it.onClick then
            it.collapsed = not it.collapsed
            Safe("list toggle", opts.onToggle, it, self)
          elseif opts.onClick then
            Safe("list click", opts.onClick, it, button, self)
          elseif type(it.onClick) == "function" then
            Safe("list click", it.onClick, row, button)
          end
        end)
      end
      pool[pool.used] = r
      self.made = self.made + 1
    end
    return r
  end
  function l:Draw()
    for _, pool in pairs(self.pools) do pool.used = 0 end
    local drawn = self.drawnRows
    for k = #drawn, 1, -1 do drawn[k] = nil end
    local scroll = self.total > self.h
    local w = self.w - (scroll and 5 or 0)
    self.drawn = 0
    local i = self:First()
    while i <= #self.items and self.tops[i] < self.offset + self.h do
      local it = self.items[i]
      local kind = it.kind or "row"
      local r = self:Acquire(kind)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(self.tops[i] - self.offset))
      r:SetSize(w, Height(it))
      r._w = w
      r.plain = self.plain
      r._selected = (self.selected ~= nil and self.selected == it) or nil
      r.onClick = it.onClick -- (tests and old callers: the row says what a click does)
      local ok, err = pcall(r.SetItem, r, it, opts.zebra ~= false and i or nil, self)
      if not ok and type(Kit.onError) == "function" then pcall(Kit.onError, "list row " .. tostring(kind), err) end
      r:Show()
      self.drawn = self.drawn + 1
      drawn[#drawn + 1] = r
      i = i + 1
    end
    for _, pool in pairs(self.pools) do
      for k = pool.used + 1, #pool do pool[k]:Hide() end
    end
    if #self.items == 0 and self.emptyText and self.emptyText ~= "" then
      self.empty:SetText(self.emptyText)
      Kit.Fit(self.empty, max(40, self.w - 2 * S.pad))
      self.empty:Show()
    else
      self.empty:Hide()
    end
    if scroll then
      local th = max(20, self.h * self.h / self.total)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", -1, -(self.h - th) * self.offset / max(1, self:MaxOffset()))
      self.thumb:Show()
    else
      self.thumb:Hide()
    end
  end
  function l:Rows() return self.drawnRows end
  function l:Select(it) self.selected = it self:Draw() end
  -- scrolls so the item is in view (an item or its index); top = true puts it at the top
  function l:ScrollTo(it, top)
    for i, x in ipairs(self.items) do
      if x == it or i == it then
        local y, h = self.tops[i], Height(x)
        if top or y < self.offset then self:SetOffset(y)
        elseif y + h > self.offset + self.h then self:SetOffset(y + h - self.h) end
        return
      end
    end
  end
  l:SetScript("OnMouseWheel", function(self, d) self:Scroll(-d * S.row * 2) end)
  return l
end

-- frame with content taller than itself: the mouse wheel scrolls; a.content gets the children
function Kit.ScrollArea(parent)
  local a = CreateFrame("Frame", nil, parent)
  Call(a, "SetClipsChildren", true)
  Call(a, "EnableMouseWheel", true)
  a.content = CreateFrame("Frame", nil, a)
  a.offset, a.contentH, a.w, a.h = 0, 0, 0, 0
  a.thumb = Tex(a, "OVERLAY", C.goldMuted)
  a.thumb:SetWidth(3)
  a.thumb:Hide()
  function a:SetOffset(o)
    self.offset = floor(Clamp(o, 0, max(0, self.contentH - self.h)))
    self.content:ClearAllPoints()
    self.content:SetPoint("TOPLEFT", self, "TOPLEFT", 0, self.offset)
    self.content:SetSize(max(1, self.w), max(1, self.contentH))
    if self.contentH > self.h and self.h > 0 then
      local th = max(20, self.h * self.h / self.contentH)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", -1, -(self.h - th) * self.offset / max(1, self.contentH - self.h))
      self.thumb:Show()
    else
      self.thumb:Hide()
    end
  end
  function a:SetContentHeight(h) self.contentH = h self:SetOffset(self.offset) end
  function a:Resize(w, h) self.w, self.h = w, h self:SetSize(w, h) self:SetOffset(self.offset) end
  a:SetScript("OnMouseWheel", function(self, d) self:SetOffset(self.offset - d * S.row * 2) end)
  return a
end

-- sidebar 220 (icon rail 48): opts.search (placeholder) puts a search box on top; s.list holds ZoneRow items
-- (minor 3) opts.kinds: the list's own kinds (as Kit.List); the list knows list.rail in the icon rail
function Kit.Sidebar(parent, opts)
  opts = opts or {}
  local s = CreateFrame("Frame", nil, parent)
  Fill(s, C.window)
  s.line = Tex(s, "ARTWORK", C.divider)
  s.line:SetPoint("TOPRIGHT") s.line:SetPoint("BOTTOMRIGHT") s.line:SetWidth(1)
  if opts.search then
    s.search = Kit.SearchBox(s, { placeholder = opts.search, onChange = opts.onSearch })
    s.search:SetPoint("TOPLEFT", S.gap, -S.gap)
  end
  s.list = Kit.List(s, { onClick = opts.onClick, zebra = false, kinds = opts.kinds })
  function s:Width() return self.rail and S.rail or S.sidebar end
  function s:Layout(h, rail)
    self.rail = rail and true or nil
    local w = self:Width()
    self:SetSize(w, h)
    local top = 0
    if self.search then
      if self.rail then self.search:Hide() else self.search:Show() self.search:Layout(w - 2 * S.gap) top = S.button + 2 * S.gap end
    end
    self.list:ClearAllPoints()
    self.list:SetPoint("TOPLEFT", 0, -top)
    self.list.rail = self.rail
    self.list:Resize(w - 1, h - top)
  end
  return s
end

---------------------------------------------------------------------------
-- Window: header 44 (title, book tabs, close), body, optional footer 28, grip; size between opts.min and opts.max.
-- opts: title, width, height, min = { w, h }, max = { w, h }, footer, store (table for place and size),
-- onLayout(win, bodyWidth, bodyHeight, mode), onTab(key, win). mode: "full" | "overlay" (< 960) | "rail" (< 800)
-- (minor 3) opts.logo (texture: the addon's mark in a gold square left of the title), opts.subtitle (gold, after the
-- title, cut first), opts.options = "<Addon>" (the cog of DonCore's options window left of the close button),
-- opts.hint (tooltip line of the cog), opts.onClose(win); win:SetSubtitle(text)
---------------------------------------------------------------------------
function Kit.Mode(w)
  return w < Kit.BREAK.rail and "rail" or w < Kit.BREAK.overlay and "overlay" or "full"
end

---------------------------------------------------------------------------
-- (minor 13, 02.11.2026, Daniel: "Maßstab 80 % für alle Kit-Fenster, im Optionsfenster einstellbar von 60 bis 110 %, deine
-- gespeicherten Fenstergrößen werden einmal zurückgesetzt") one scale for every Kit window, dialog and menu of all Don
-- addons. Kit.scale (Kit.SCALE_MIN to Kit.SCALE_MAX, default 0.8); Kit.SetScale(v) sets it (steps of 5 %) and rescales
-- every one around its middle; the shared options window (Options minor 4, page "General") keeps it in the SavedVariables
-- of every Don addon. A window's own factor on top (Dropdon's size option): win:SetOwnScale(f), shown at Kit.scale * f.
-- Kit.Scaled(frame) puts any own frame under the scale. A Kit.Window forgets the size kept in its store once (scaleReset).
---------------------------------------------------------------------------
Kit.SCALE_DEFAULT, Kit.SCALE_MIN, Kit.SCALE_MAX = 0.8, 0.6, 1.1
Kit.scale = Kit.scale or Kit.SCALE_DEFAULT
Kit.scaled = Kit.scaled or {}   -- the frames under the scale (kept across upgrades)

local function ApplyScale(f, keep)
  local want = (Kit.scale or 1) * (tonumber(f._ownScale) or 1)
  local okS, old = Call(f, "GetScale")
  old = okS and tonumber(old) or 1
  if old <= 0 then old = 1 end
  if abs(old - want) < 0.001 then return end
  local okC, cx, cy = Call(f, "GetCenter")
  Call(f, "SetScale", want)
  if keep and okC and tonumber(cx) and tonumber(cy) then
    -- the same middle on the screen: its place in frame units times the old factor, divided by the new one
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * old / want, cy * old / want)
    if f.Save then Safe("scale save", f.Save, f) end
  end
end
function Kit.Scaled(f)
  if not f then return f end
  local known
  for _, g in ipairs(Kit.scaled) do if g == f then known = true break end end
  if not known then Kit.scaled[#Kit.scaled + 1] = f end
  ApplyScale(f, false)
  return f
end
-- returns the scale it set and whether it changed
function Kit.SetScale(v)
  v = Clamp(floor((tonumber(v) or Kit.SCALE_DEFAULT) * 20 + 0.5) / 20, Kit.SCALE_MIN, Kit.SCALE_MAX)
  local changed = abs(v - (Kit.scale or 1)) > 0.001
  Kit.scale = v
  for _, f in ipairs(Kit.scaled) do ApplyScale(f, true) end
  return v, changed
end
function Kit.GetScale() return Kit.scale or 1 end

function Kit.Window(name, opts)
  opts = opts or {}
  -- (minor 13) the size kept before the shared scale is dropped once; the place stays
  if type(opts.store) == "table" and opts.store.scaleReset ~= 1 then
    opts.store.w, opts.store.h, opts.store.scaleReset = nil, nil, 1
  end
  local minW, minH = (opts.min or Kit.WINDOW_MIN)[1], (opts.min or Kit.WINDOW_MIN)[2]
  local maxW, maxH = (opts.max or Kit.WINDOW_MAX)[1], (opts.max or Kit.WINDOW_MAX)[2]
  local f = CreateFrame("Frame", name, UIParent)
  f.opts, f.tabs, f.minW, f.minH, f.maxW, f.maxH = opts, {}, minW, minH, maxW, maxH
  Call(f, "SetFrameStrata", "HIGH")
  Call(f, "SetToplevel", true)
  Call(f, "SetClampedToScreen", true)
  Call(f, "SetMovable", true)
  Call(f, "SetResizable", true)
  Call(f, "EnableMouse", true)
  if f.SetResizeBounds then Call(f, "SetResizeBounds", minW, minH, maxW, maxH)
  else Call(f, "SetMinResize", minW, minH) Call(f, "SetMaxResize", maxW, maxH) end
  Fill(f, C.window)
  Border(f, C.outer, 0)
  f.frameLine = Border(f, C.gold, 1)
  -- header
  f.header = CreateFrame("Frame", nil, f)
  f.header:SetPoint("TOPLEFT", 2, -2)
  f.header:SetPoint("TOPRIGHT", -2, -2)
  -- (02.11.2026, Daniel on Guildon and Crafts: "den kopfbereich schon seeehr groß") opts.compact: a flat head (32 instead
  -- of 44, tabs 26, logo 20)
  -- (02.11.2026, Daniel: "Ja, überall flach") the flat head is every window's default; opts.compact = false keeps the old 44
  local flat = opts.compact ~= false
  f.headH = flat and 32 or S.head
  f.tabH = flat and 26 or S.tab
  f.logoS = flat and 20 or S.iconMid
  f.header:SetHeight(f.headH - 2)
  Fill(f.header, C.panel)
  f.headerLine = Tex(f.header, "ARTWORK", C.gold)
  f.headerLine:SetPoint("BOTTOMLEFT") f.headerLine:SetPoint("BOTTOMRIGHT") f.headerLine:SetHeight(1)
  Call(f.header, "EnableMouse", true)
  Call(f.header, "RegisterForDrag", "LeftButton")
  f.header:SetScript("OnDragStart", function() f:StartMoving() end)
  f.header:SetScript("OnDragStop", function() f:StopMovingOrSizing() f:Save() end)
  local titleX = S.pad
  if opts.logo then
    f.logo = CreateFrame("Frame", nil, f.header)
    f.logo:SetSize(f.logoS, f.logoS)
    f.logo:SetPoint("LEFT", S.pad, 0)
    Fill(f.logo, C.window)
    Border(f.logo, C.gold)
    f.logo.tex = f.logo:CreateTexture(nil, "ARTWORK")
    f.logo.tex:SetPoint("TOPLEFT", 2, -2) f.logo.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    Call(f.logo.tex, "SetTexture", opts.logo)
    titleX = S.pad + f.logoS + S.gap
  end
  f.title = Text(f.header, "title", C.hero)
  f.title:SetPoint("LEFT", titleX, 0)
  f.title:SetText(opts.title and Upper(opts.title) or "")
  -- (minor 3) a small gold square between title and subtitle (a drawn dot: no text starts with a separator)
  f.subDot = Tex(f.header, "ARTWORK", C.txGold)
  f.subDot:SetSize(3, 3)
  f.subDot:SetPoint("LEFT", f.title, "RIGHT", S.gap, -1)
  f.subtitle = Text(f.header, "tab", C.txGold)
  f.subtitle:SetPoint("LEFT", f.subDot, "RIGHT", S.gap, 0)
  f.subtitle:SetText(opts.subtitle and Upper(opts.subtitle) or "")
  f.close = Kit.IconButton(f.header, "close", { size = S.buttonSmall - 4, onClick = function()
    f:Hide()
    if opts.onClose then Safe("window close", opts.onClose, f) end
  end })
  f.close:SetPoint("RIGHT", -S.pad + 2, 0)
  if opts.options then
    local O = Core:Get("Options", 1)
    f.gear = O and O.Button(f.header, opts.options)
    if f.gear then
      f.gear:SetSize(S.buttonSmall - 4, S.buttonSmall - 4)
      f.gear:SetPoint("RIGHT", f.close, "LEFT", -S.unit - 2, 0)
      if opts.hint and f.gear.SetTooltip then f.gear:SetTooltip(O.Label and O.Label("Options") or "Options", nil, opts.hint) end
    end
  end
  -- (minor 10) opts.buttons = { { kind (Style.ICONS), tooltip, hint, onClick(win) }, ... }: more symbols left of the cog
  f.extra = {}
  local anchor = f.gear or f.close
  for _, bo in ipairs(opts.buttons or {}) do
    local b = Kit.IconButton(f.header, bo.kind, { size = S.buttonSmall - 4, tooltip = bo.tooltip, hint = bo.hint,
      onClick = function() Safe("window button", bo.onClick, f) end })
    b:SetPoint("RIGHT", anchor, "LEFT", -S.unit - 2, 0)
    b.key = bo.key
    f.extra[#f.extra + 1] = b
    anchor = b
  end
  -- body and footer
  f.body = CreateFrame("Frame", nil, f)
  f.body:SetPoint("TOPLEFT", 2, -f.headH)
  Fill(f.body, C.panel)
  if opts.footer then
    f.footer = CreateFrame("Frame", nil, f)
    f.footer:SetPoint("BOTTOMLEFT", 2, 2)
    f.footer:SetPoint("BOTTOMRIGHT", -2, 2)
    f.footer:SetHeight(S.footer - 2)
    Fill(f.footer, C.panel)
    local line = Tex(f.footer, "ARTWORK", C.divider)
    line:SetPoint("TOPLEFT") line:SetPoint("TOPRIGHT") line:SetHeight(1)
    f.status = Text(f.footer, "sub", C.muted)
    f.status:SetPoint("LEFT", S.pad, 0)
  end
  -- grip (bottom right)
  f.grip = CreateFrame("Button", nil, f)
  f.grip:SetSize(16, 16)
  f.grip:SetPoint("BOTTOMRIGHT", -3, 3)
  Call(f.grip, "SetFrameLevel", (select(2, Call(f, "GetFrameLevel")) or 1) + 10)
  f.grip.tex = f.grip:CreateTexture(nil, "OVERLAY")
  f.grip.tex:SetAllPoints()
  f.grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  SetCol(f.grip.tex, C.gold)
  f.grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  f.grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() f:ClampSize() f:Save() end)
  f.grip:SetScript("OnEnter", function(self) SetCol(self.tex, C.goldBright) end)
  f.grip:SetScript("OnLeave", function(self) SetCol(self.tex, C.gold) end)

  function f:AddTab(key, text)
    local tab = Kit.Tab(self.header, text, function() self:SelectTab(key) end)
    tab.key = key
    tab.h = self.tabH
    tab:SetHeight(self.tabH)
    self.tabs[#self.tabs + 1] = tab
    self:Layout()
    return tab
  end
  function f:SelectTab(key)
    self.tab = key
    for _, t in ipairs(self.tabs) do t:SetSelected(t.key == key) end
    Safe("window tab", self.opts.onTab, key, self)
  end
  function f:SetSubtitle(text)
    self.subtitle:SetText(text and text ~= "" and Upper(text) or "")
    self:Layout()
  end
  -- (minor 22) onClick(win): the footer text takes a click (hover: title colour); tooltip = { title, lines, hint }
  function f:SetStatus(text, onClick, tooltip)
    if not self.status then return end
    self.status:SetText(text or "")
    Kit.Fit(self.status, (self._w or 400) - 40)
    if type(onClick) == "function" and not self.statusHit then
      local b = CreateFrame("Button", nil, self.footer)
      b:SetPoint("TOPLEFT", self.status, "TOPLEFT", -4, 4)
      b:SetPoint("BOTTOMRIGHT", self.status, "BOTTOMRIGHT", 4, -4)
      b:SetScript("OnEnter", function(hit)
        TextColor(self.status, C.title)
        local t = hit.tip
        if t then Kit.Tooltip(hit, t[1], t[2], t[3]) end
      end)
      b:SetScript("OnLeave", function(hit) TextColor(self.status, C.muted) Kit.HideTooltip(hit) end)
      b:SetScript("OnClick", function(hit) if hit.fn then Safe("status click", hit.fn, self) end end)
      self.statusHit = b
    end
    local b = self.statusHit
    if b then
      b.fn, b.tip = type(onClick) == "function" and onClick or nil, type(tooltip) == "table" and tooltip or nil
      if b.fn then b:Show() else b:Hide() TextColor(self.status, C.muted) end
    end
  end
  function f:ClampSize()
    local w, h = self:GetWidth() or minW, self:GetHeight() or minH
    local cw, ch = Clamp(w, minW, maxW), Clamp(h, minH, maxH)
    if abs(cw - w) > 0.5 or abs(ch - h) > 0.5 then self:SetSize(cw, ch) return true end
  end
  function f:Save()
    local st = self.opts.store
    if type(st) ~= "table" then return end
    local ok, point, _, rel, x, y = Call(self, "GetPoint", 1)
    if ok and point then st.point, st.relPoint, st.x, st.y = point, rel, x, y end
    st.w, st.h = floor((self:GetWidth() or 0) + 0.5), floor((self:GetHeight() or 0) + 0.5)
  end
  function f:Layout()
    local w, h = self:GetWidth() or minW, self:GetHeight() or minH
    self._w = w
    local mode = Kit.Mode(w)
    self.mode = mode
    -- tabs right, before the close button; not enough room: tabs share it and cut their texts
    local right = w - 4 - S.pad - S.buttonSmall - S.gap - (self.gear and (S.buttonSmall + S.unit) or 0)
      - #self.extra * (S.buttonSmall + S.unit)
    local need = 0
    for i, t in ipairs(self.tabs) do need = need + t.natural + (i > 1 and S.unit or 0) end
    local titleX = self.logo and (S.pad + self.logoS + S.gap) or S.pad
    local titleMin = min(160, TextW(self.title))
    local room = right - titleX - titleMin - S.pad
    local scale = (need > room and need > 0) and max(0.4, room / need) or 1
    local x = right - min(need, need * scale)
    local titleRoom = x - titleX - S.pad
    for _, t in ipairs(self.tabs) do
      local tw = floor(t.natural * scale)
      t:Layout(tw)
      t:ClearAllPoints()
      t:SetPoint("BOTTOMLEFT", self.header, "BOTTOMLEFT", x, 0)
      x = x + tw + S.unit
    end
    Kit.Fit(self.title, max(40, titleRoom))
    -- the subtitle gets what the title leaves; under 40 px it goes
    local subRoom = titleRoom - min(TextW(self.title), titleRoom) - S.gap
    subRoom = subRoom - 3 - S.gap
    if self.subtitle:GetText() ~= "" and subRoom >= 40 then Kit.Fit(self.subtitle, subRoom) self.subtitle:Show() self.subDot:Show()
    else self.subtitle:Hide() self.subDot:Hide() end
    local bodyH = h - self.headH - (self.footer and S.footer or 0) - 2
    self.body:SetSize(w - 4, bodyH)
    if self.status then Kit.Fit(self.status, w - 40) end
    Safe("window layout", self.opts.onLayout, self, w - 4, bodyH, mode)
  end
  function f:Toggle() if self:IsShown() then self:Hide() else self:Show() end end

  f:SetScript("OnSizeChanged", function(self)
    if self:ClampSize() then return end
    self:Layout()
  end)
  -- (minor 13) the window's own factor on top of Kit.scale (Dropdon's size option)
  function f:SetOwnScale(v)
    self._ownScale = tonumber(v) or 1
    ApplyScale(self, true)
  end
  if name and type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = name end
  Kit.Scaled(f)
  local st = type(opts.store) == "table" and opts.store or {}
  f:SetSize(Clamp(st.w or opts.width or 980, minW, maxW), Clamp(st.h or opts.height or 640, minH, maxH))
  f:ClearAllPoints()
  if st.point then f:SetPoint(st.point, UIParent, st.relPoint or st.point, st.x or 0, st.y or 0)
  else f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  f:Layout()
  return f
end

---------------------------------------------------------------------------
-- (minor 3) Hero: the head of a page (a zone, a dungeon): a gold kicker line, a big title, on the right a fixed column
-- with a number, a word and a bar. Every text one line (cut, whole text in the tooltip), nothing wraps or jumps.
-- h:SetData({ kicker, title, value, label, progress = 0..1, progressColor }); h.art: a frame behind the texts for an
-- addon's own picture (a zone map), dimmed by a veil from the left; h:Layout(width); h._tipFn(h) for its tooltip
---------------------------------------------------------------------------
function Kit.Hero(parent, opts)
  opts = opts or {}
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(opts.height or 72)
  h.bg = Fill(h, C.panel)
  h.art = CreateFrame("Frame", nil, h)
  h.art:SetAllPoints(h)
  Call(h.art, "SetClipsChildren", true)
  h.veil = CreateFrame("Frame", nil, h)
  h.veil:SetAllPoints(h)
  h.veil.tex = Fill(h.veil, C.panel)
  h.veil.tex:SetAlpha(0.55)
  local okG = h.veil.tex.SetGradient and CreateColor and pcall(h.veil.tex.SetGradient, h.veil.tex, "HORIZONTAL",
    CreateColor(C.panel[1], C.panel[2], C.panel[3], 0.95), CreateColor(C.panel[1], C.panel[2], C.panel[3], 0.35))
  if okG then h.veil.tex:SetAlpha(1) end
  h.line = Tex(h.veil, "ARTWORK", C.divider)
  h.line:SetPoint("BOTTOMLEFT") h.line:SetPoint("BOTTOMRIGHT") h.line:SetHeight(1)
  h.kicker = Text(h.veil, "sub", C.txGold)
  h.title = Text(h.veil, "hero", C.hero)
  h.value = Text(h.veil, "hero", C.txGold, "RIGHT")
  h.label = Text(h.veil, "sub", C.muted, "RIGHT")
  h.bar = Kit.ProgressBar(h.veil)
  h.bar:SetHeight(4)
  h.colW = opts.column or 132
  function h:SetData(d)
    d = d or {}
    self.data = d
    self.kicker:SetText(d.kicker and Upper(d.kicker) or "")
    -- (minor 4) d.plainCase: the title as it is (money with coins, names); d.valueColor: the right value's colour
    self.title:SetText(d.title and (d.plainCase and tostring(d.title) or Upper(d.title)) or "")
    self.value:SetText(d.value ~= nil and tostring(d.value) or "")
    TextColor(self.value, d.valueColor or C.txGold)
    self.label:SetText(d.label or "")
    if d.progress then self.bar:SetColor(d.progressColor or (d.progress >= 1 and "green") or nil) self.bar:Show() else self.bar:Hide() end
    self:Layout(self._w or self:GetWidth())
    if d.progress then self.bar:SetValue(d.progress) end
  end
  function h:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    self:SetWidth(w)
    local hh = self:GetHeight() or 72
    local right = self.value:GetText() ~= "" or self.label:GetText() ~= ""
    local col = right and self.colW or 0
    local textW = max(40, w - 2 * S.pad - (right and col + S.gap or 0))
    local hasKick = self.kicker:GetText() ~= ""
    self.kicker:ClearAllPoints() self.title:ClearAllPoints()
    if hasKick then
      self.kicker:SetPoint("TOPLEFT", S.pad, -floor(hh / 2) + 16)
      self.title:SetPoint("TOPLEFT", S.pad, -floor(hh / 2) + 1)
    else
      self.title:SetPoint("LEFT", S.pad, 0)
    end
    Kit.Fit(self.kicker, textW)
    Kit.Fit(self.title, textW)
    self.value:ClearAllPoints() self.label:ClearAllPoints() self.bar:ClearAllPoints()
    self.value:SetPoint("TOPRIGHT", -S.pad, -floor(hh / 2) + 20)
    self.label:SetPoint("TOPRIGHT", -S.pad, -floor(hh / 2) - 2)
    self.bar:SetPoint("TOPRIGHT", -S.pad, -floor(hh / 2) - 18)
    Kit.Fit(self.value, max(1, col))
    Kit.Fit(self.label, max(1, col))
    self.bar:Layout(max(1, col))
  end
  h._cutTexts = { h.kicker, h.title, h.value, h.label }
  Call(h, "EnableMouse", true)
  h:SetScript("OnEnter", function(self)
    if type(self._tipFn) == "function" then
      local ok, t, lines, hint = pcall(self._tipFn, self)
      if ok and t then Kit.Tooltip(self, t, lines, hint) return end
    end
    CutTip(self, nil, nil, self._cutTexts)
  end)
  h:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return h
end

---------------------------------------------------------------------------
-- (minor 3) Columns: small bars side by side (the last seven days); c:SetValues({ v, ... }, { label, ... }), the last
-- one bright gold, the others muted gold; the mouse over a column shows its label and value
---------------------------------------------------------------------------
function Kit.Columns(parent, n)
  local c = CreateFrame("Frame", nil, parent)
  c.cols, c.n = {}, n or 7
  for i = 1, c.n do
    local b = CreateFrame("Frame", nil, c)
    b.track = Fill(b, C.input)
    b.fill = Tex(b, "ARTWORK", C.gold)
    b.fill:SetPoint("BOTTOMLEFT") b.fill:SetPoint("BOTTOMRIGHT")
    Call(b, "EnableMouse", true)
    b:SetScript("OnEnter", function(self) if self.tip then Kit.Tooltip(self, self.tip[1], { self.tip[2] }) end end)
    b:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
    c.cols[i] = b
  end
  function c:SetValues(values, labels)
    self.values, self.labels = values or {}, labels or {}
    self:Layout(self._w or self:GetWidth(), self._h or self:GetHeight())
  end
  function c:Layout(w, h)
    w, h = tonumber(w) or 0, tonumber(h) or 0
    self._w, self._h = w, h
    self:SetSize(max(1, w), max(1, h))
    local top = 0
    for i = 1, self.n do top = max(top, tonumber(self.values and self.values[i]) or 0) end
    local gap = 3
    local cw = max(2, (w - gap * (self.n - 1)) / self.n)
    for i, b in ipairs(self.cols) do
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * (cw + gap), 0)
      b:SetSize(cw, max(1, h))
      local v = tonumber(self.values and self.values[i]) or 0
      local fh = top > 0 and max(v > 0 and 2 or 0, floor(h * v / top)) or 0
      if fh > 0 then b.fill:SetHeight(fh) b.fill:Show() else b.fill:Hide() end
      SetCol(b.fill, i == self.n and C.goldBright or C.gold)
      local lab = self.labels and self.labels[i]
      b.tip = lab and { lab, self.values and self.values[i] ~= nil and tostring(self.values[i]) or nil } or nil
    end
  end
  return c
end

---------------------------------------------------------------------------
-- (minor 3) Detail: the focus card on the right of a list (or over it under 960 px). Head 44: level badge or icon,
-- title, close; a meta line (with a pill) and action buttons below; then a scrolling body made of sections.
--   d:SetHead({ level, levelStatus, icon, title, titleColor, meta, pill = { text, kind } })
--   d:SetActions({ { text = , onClick = , kind = "primary", tooltip = { title, lines, hint } }, ... })
--   d:Begin()  d:Section(title, right)  d:Line(text, color, right, rightColor)  d:Para(text, color)
--   d:Progress(text, have, need, done)  d:Block(frame, height)  d:Space(px)  d:End()
--   opts.onClose(d); d:Layout(width, height)
-- Lines are one line (cut, tooltip); a paragraph wraps (story texts), the only place where text wraps.
---------------------------------------------------------------------------
-- (minor 4) opts.actionsBottom: the buttons sit at the bottom of the card (the first one takes the room, the others their
-- natural width), the body scrolls between meta and buttons
function Kit.Detail(parent, opts)
  opts = opts or {}
  local d = CreateFrame("Frame", nil, parent)
  Call(d, "EnableMouse", true)
  d.bg = Fill(d, C.card)
  d.bd = Border(d, C.gold)
  d.head = CreateFrame("Frame", nil, d)
  d.head:SetPoint("TOPLEFT", 1, -1) d.head:SetPoint("TOPRIGHT", -1, -1)
  d.head:SetHeight(S.head)
  Fill(d.head, C.panel)
  d.headLine = Tex(d.head, "ARTWORK", C.goldMuted)
  d.headLine:SetPoint("BOTTOMLEFT") d.headLine:SetPoint("BOTTOMRIGHT") d.headLine:SetHeight(1)
  d.badge = Kit.LevelBadge(d.head)
  d.badge:SetPoint("LEFT", S.pad, 0)
  d.iconBox = CreateFrame("Frame", nil, d.head)
  d.iconBox:SetSize(S.iconMid, S.iconMid)
  d.iconBox:SetPoint("LEFT", S.pad, 0)
  Fill(d.iconBox, C.input)
  Border(d.iconBox, C.goldMuted)
  d.icon = d.iconBox:CreateTexture(nil, "ARTWORK")
  d.icon:SetPoint("TOPLEFT", 1, -1) d.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  d.iconBox:Hide()
  d.title = Text(d.head, "title", C.hero)
  d.close = Kit.IconButton(d.head, "close", { size = S.buttonSmall - 4, onClick = function()
    if opts.onClose then Safe("detail close", opts.onClose, d) else d:Hide() end
  end })
  d.close:SetPoint("RIGHT", -S.gap, 0)
  d.meta = Text(d, "sub", C.txGold)
  d.pill = Kit.Pill(d)
  d.pill:Hide()
  d.actions = {}
  d.area = Kit.ScrollArea(d)
  d.pool = { text = {}, para = {}, bar = {}, sec = {}, item = {} }
  d.used = { text = 0, para = 0, bar = 0, sec = 0, item = 0 }
  d.blocks, d.lines = {}, {}
  d.y = 0
  local function TakeText(kind, role, color, justify)
    d.used[kind] = d.used[kind] + 1
    local fs = d.pool[kind][d.used[kind]]
    if not fs then fs = Text(d.area.content, role, color, justify) d.pool[kind][d.used[kind]] = fs end
    if kind == "text" then Call(fs, "SetJustifyH", justify or "LEFT") end -- (a pooled text was a right column before)
    TextColor(fs, color)
    fs:ClearAllPoints()
    fs:Show()
    return fs
  end
  local function Width() return max(40, (d._w or 320) - 2 * S.pad - 6) end
  function d:SetHead(hd)
    hd = hd or {}
    self.headData = hd
    if hd.icon then
      self.badge:Hide() self.iconBox:Show()
      Call(self.icon, "SetTexture", hd.icon)
      Call(self.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
    else
      self.iconBox:Hide()
      if hd.level ~= nil then
        self.badge:SetLevel(hd.level, hd.levelStatus or (tonumber(hd.level) and Kit.QuestDifficulty(hd.level)) or "grey")
        self.badge:Show()
      else
        self.badge:Hide()
      end
    end
    self.title:SetText(hd.title or "")
    TextColor(self.title, hd.titleColor or C.hero)
    self.meta:SetText(hd.meta or "")
    if hd.pill then self.pill:SetPill(hd.pill[1], hd.pill[2]) self.pill:Show() else self.pill:Hide() end
    self:Layout(self._w, self._h)
  end
  function d:SetActions(list)
    for _, b in ipairs(self.actions) do b:Hide() end
    for i, a in ipairs(list or {}) do
      local b = self.actions[i]
      if not b then
        b = Kit.Button(self, "", { small = not opts.actionsBottom })
        self.actions[i] = b
      end
      b:SetText(a.text or "")
      b._onClick = a.onClick
      if a.tooltip then b:SetTooltip(a.tooltip[1], a.tooltip[2], a.tooltip[3]) else b._tip = nil end
      if b.SetKind then b:SetKind(a.kind or "secondary") end
      b:SetDisabled(a.disabled)
      -- (minor 4) a.selected: a button that switches something on shows it ("Wanted")
      b:SetSelected(a.selected and true or false)
      b:Show()
    end
    self.nActions = #(list or {})
    self:Layout(self._w, self._h)
  end
  function d:Begin()
    for kind, pool in pairs(self.pool) do
      for _, x in ipairs(pool) do x:Hide() end
      self.used[kind] = 0
    end
    for _, b in ipairs(self.blocks) do b:Hide() end
    self.blocks, self.lines = {}, {}
    self.y = S.gap
  end
  function d:Section(title, right)
    if self.y > S.gap then self.y = self.y + S.gap end
    local fs = TakeText("sec", "group", C.txGold)
    fs:SetText(Upper(title))
    fs:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad, -self.y)
    local r
    if right and right ~= "" then
      r = TakeText("text", "sub", C.muted, "RIGHT")
      r:SetText(right)
      r:SetPoint("TOPRIGHT", self.area.content, "TOPRIGHT", -S.pad - 6, -self.y)
    end
    self.lines[#self.lines + 1] = { fs, r }
    self.y = self.y + 18
    return fs
  end
  -- (minor 4) lo = { onClick = function(button), tooltip = { title, lines, hint } }: the line takes the mouse (hover colour,
  -- tooltip, click; Guildon Crafts: a crafter in the recipe card is whispered)
  function d:Line(text, color, right, rightColor, lo)
    local fs = TakeText("text", "row", color or C.body)
    fs:SetText(text or "")
    fs:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad, -self.y)
    local r
    if right ~= nil and right ~= "" then
      r = TakeText("text", "sub", rightColor or C.muted, "RIGHT")
      r:SetText(tostring(right))
      r:SetPoint("TOPRIGHT", self.area.content, "TOPRIGHT", -S.pad - 6, -self.y - 1)
    end
    if type(lo) == "table" and (lo.onClick or lo.tooltip) then
      self.used.hit = (self.used.hit or 0) + 1
      self.pool.hit = self.pool.hit or {}
      local h = self.pool.hit[self.used.hit]
      if not h then
        h = CreateFrame("Button", nil, self.area.content)
        -- a gold line under the text while the mouse is on it (a fill would lie over the text: the button is above the card)
        h.bg = Tex(h, "ARTWORK", C.gold)
        h.bg:SetPoint("BOTTOMLEFT", 4, 0) h.bg:SetPoint("BOTTOMRIGHT", 0, 0) h.bg:SetHeight(1)
        h.bg:SetAlpha(0)
        Clickable(h, function(btn, button) if btn.lo and btn.lo.onClick then Safe("detail line", btn.lo.onClick, btn, button) end end)
        Stateful(h, function(btn, st) btn.bg:SetAlpha(st == "hover" and 1 or 0) end)
        self.pool.hit[self.used.hit] = h
      end
      h.lo = lo
      h._tip = lo.tooltip and { lo.tooltip[1], lo.tooltip[2], lo.tooltip[3] } or nil
      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad - 4, -self.y + 1)
      h:SetPoint("TOPRIGHT", self.area.content, "TOPRIGHT", -S.pad, -self.y + 1)
      h:SetHeight(18)
      h:Show()
    end
    self.lines[#self.lines + 1] = { fs, r }
    self.y = self.y + 18
    return fs
  end
  function d:Para(text, color)
    local fs = TakeText("para", "row", color or C.body)
    fs._kitPara = true -- the one text of the kit that wraps
    Call(fs, "SetMaxLines", 0)
    Call(fs, "SetWordWrap", true)
    fs:SetWidth(Width())
    fs:SetText(text or "")
    fs:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad, -self.y)
    local ok, fh = Call(fs, "GetStringHeight")
    fh = ok and tonumber(fh) or 14
    self.lines[#self.lines + 1] = { fs, para = true }
    self.y = self.y + max(14, ceil(fh)) + 4
    return fs
  end
  function d:Progress(text, have, need, done)
    have, need = tonumber(have), tonumber(need)
    local fs = self:Line(text, done and C.green or C.body, (have and need) and (have .. " / " .. need) or nil, done and C.green or C.muted)
    if have and need and need > 0 then
      self.used.bar = self.used.bar + 1
      local b = self.pool.bar[self.used.bar]
      if not b then b = Kit.ProgressBar(self.area.content) b:SetHeight(3) self.pool.bar[self.used.bar] = b end
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad, -self.y + 1)
      b:Layout(Width())
      b:SetColor(done and "green" or "yellow")
      b:SetValue(have / need)
      b:Show()
      self.y = self.y + 5
    end
    return fs
  end
  -- (minor 4) a line with an item symbol (16 px, quality edge, game tooltip, Shift-click links it) before the text
  function d:Item(item, text, color, right, rightColor, onClick)
    self.used.item = self.used.item + 1
    local ic = self.pool.item[self.used.item]
    if not ic then ic = Kit.ItemIcon(self.area.content, S.icon) self.pool.item[self.used.item] = ic end
    ic:SetItem(item)
    ic._onClick = onClick
    ic:ClearAllPoints()
    ic:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad, -self.y)
    ic:Show()
    local fs = TakeText("text", "row", color or C.body)
    fs:SetText(text or "")
    fs:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad + S.icon + 6, -self.y - 1)
    local r
    if right ~= nil and right ~= "" then
      r = TakeText("text", "sub", rightColor or C.muted, "RIGHT")
      r:SetText(tostring(right))
      r:SetPoint("TOPRIGHT", self.area.content, "TOPRIGHT", -S.pad - 6, -self.y - 2)
    end
    self.lines[#self.lines + 1] = { fs, r, inset = S.icon + 6 }
    self.y = self.y + 20
    return fs, ic
  end
  function d:Block(frame, height)
    frame:SetParent(self.area.content)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", S.pad, -self.y)
    if frame.Layout then Safe("detail block", frame.Layout, frame, Width(), height) else frame:SetSize(Width(), height or 1) end
    frame:Show()
    self.blocks[#self.blocks + 1] = frame
    self.y = self.y + (height or frame:GetHeight() or 0) + 4
    return frame
  end
  function d:Space(px) self.y = self.y + (px or S.gap) end
  function d:End() self.area:SetContentHeight(self.y + S.gap) self:FitLines() end
  function d:FitLines()
    local w = Width()
    for _, l in ipairs(self.lines or {}) do
      if l.para then l[1]:SetWidth(w)
      else
        local rw = 0
        if l[2] then Kit.Fit(l[2], floor(w * 0.45)) rw = TextW(l[2]) + S.gap end
        Kit.Fit(l[1], w - rw - (l.inset or 0))
      end
    end
  end
  function d:Layout(w, h)
    w, h = tonumber(w) or d._w or 320, tonumber(h) or d._h or 400
    self._w, self._h = w, h
    self:SetSize(w, h)
    local x = S.pad + ((self.badge:IsShown() and S.badgeW + S.gap) or (self.iconBox:IsShown() and S.iconMid + S.gap) or 0)
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", self.head, "LEFT", x, 0)
    Kit.Fit(self.title, w - x - S.buttonSmall - 2 * S.gap)
    local y = S.head + 4
    self.meta:ClearAllPoints() self.pill:ClearAllPoints()
    if self.meta:GetText() ~= "" or self.pill:IsShown() then
      local mx = S.pad
      if self.pill:IsShown() then self.pill:SetPoint("TOPLEFT", self, "TOPLEFT", S.pad, -y - 2) mx = mx + self.pill:GetWidth() + S.gap end
      self.meta:SetPoint("TOPLEFT", self, "TOPLEFT", mx, -y - 4)
      Kit.Fit(self.meta, w - mx - S.pad)
      y = y + 24
    end
    local n = self.nActions or 0
    local bottom = 0
    if n > 0 and opts.actionsBottom then
      bottom = S.button + 2 * S.gap
      local rest = 0
      for i = 2, n do rest = rest + min(self.actions[i].natural or 60, 120) + S.unit end
      local bx = S.pad
      for i = 1, n do
        local b = self.actions[i]
        local bw = i == 1 and max(40, w - 2 * S.pad - rest) or min(b.natural or 60, 120)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", bx, S.gap)
        if b.Layout then b:Layout(bw) else b:SetWidth(bw) end
        bx = bx + bw + S.unit
      end
      n = 0
    end
    if n > 0 then
      local bx, room = S.pad, w - 2 * S.pad
      local each = floor((room - (n - 1) * S.unit) / n)
      for i = 1, n do
        local b = self.actions[i]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", bx, -y)
        local bw = min(b.natural or each, each)
        if b.Layout then b:Layout(bw) else b:SetWidth(bw) end
        bx = bx + bw + S.unit
      end
      y = y + S.buttonSmall + S.gap
    end
    self.area:ClearAllPoints()
    self.area:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -y)
    self.area:Resize(w - 2, max(1, h - y - 1 - bottom))
    self:FitLines()
  end
  d._cutTexts = { d.title, d.meta }
  Call(d.head, "EnableMouse", true)
  -- (02.11.2026) SetHead({ itemID, tipLines }): the head shows the game's item tooltip, Shift-click links the item
  d.head:SetScript("OnEnter", function(self)
    local hd = d.headData
    if hd and hd.itemID and Kit.ItemTooltip(self, hd.itemID, hd.tipLines, hd.tipHint) then return end
    CutTip(self, nil, nil, d._cutTexts)
  end)
  d.head:SetScript("OnMouseUp", function()
    local hd = d.headData
    if hd and hd.itemID then Kit.LinkItem(hd.itemID) end
  end)
  d.head:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return d
end

---------------------------------------------------------------------------
-- (minor 4, 02.11.2026, StyleKit 2 step 4 with Guildon, docs/layout_2026-11-02/guildon/BAUSTEINE.md) blocks that several
-- addons need: class colour and icon, table head with sortable columns and its rows, item icon, edit box, dialog, copy
-- box, segmented choice, bar list.
---------------------------------------------------------------------------
-- class colours: the game's RAID_CLASS_COLORS (CUSTOM_CLASS_COLORS first, as other addons expect), these values if missing
local CLASS_FALLBACK = {
  WARRIOR = "C69B6D", PALADIN = "F48CBA", HUNTER = "AAD372", ROGUE = "FFF468", PRIEST = "FFFFFF", SHAMAN = "0070DD",
  MAGE = "3FC7EB", WARLOCK = "8788EE", DRUID = "FF7C0A", DEATHKNIGHT = "C41E3A", MONK = "00FF98", DEMONHUNTER = "A330C9",
  EVOKER = "33937F",
}
-- Kit.ClassColor("MAGE") -> { r, g, b, hex = "ff3fc7eb" }; an unknown class: the muted grey
-- (02.11.2026) the fixed modern colours come before the game's RAID_CLASS_COLORS: Classic Era gives the shaman the paladin's
-- pink there (Guildon's ns.CLASS_RGB, Daniel 25.10.: "eindeutige Blizzard-Klassenfarben"); CUSTOM_CLASS_COLORS (an addon
-- the player chose) still wins
function Kit.ClassColor(class)
  local key = type(class) == "string" and class:upper() or ""
  local src = (type(CUSTOM_CLASS_COLORS) == "table" and CUSTOM_CLASS_COLORS[key])
    or (not CLASS_FALLBACK[key] and type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS[key])
  if type(src) == "table" and tonumber(src.r) then
    return { src.r, src.g, src.b, hex = ("ff%02x%02x%02x"):format(floor(src.r * 255 + 0.5), floor(src.g * 255 + 0.5), floor(src.b * 255 + 0.5)) }
  end
  if CLASS_FALLBACK[key] then return Hex(CLASS_FALLBACK[key]) end
  return { C.muted[1], C.muted[2], C.muted[3], hex = C.muted.hex }
end
-- "|cff3fc7ebName|r"
function Kit.ClassText(class, text) return "|c" .. Kit.ClassColor(class).hex .. tostring(text or "") .. "|r" end

-- the class symbol from the game's class sheet (Interface\WorldStateFrame\Icons-Classes, CLASS_ICON_TCOORDS); a texture
-- with :SetClass(class) (unknown: hidden)
local CLASS_SHEET = "Interface\\WorldStateFrame\\Icons-Classes"
local CLASS_TC = {
  WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
  DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
Kit.CLASS_SHEET = CLASS_SHEET
function Kit.ClassCoords(class)
  local key = type(class) == "string" and class:upper() or ""
  local tc = type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[key] or CLASS_TC[key]
  return tc
end
function Kit.ClassIcon(parent, class, size)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size or S.icon, size or S.icon)
  function t:SetClass(cl)
    self.class = cl
    local tc = Kit.ClassCoords(cl)
    if tc then
      self:SetTexture(CLASS_SHEET)
      Call(self, "SetTexCoord", tc[1], tc[2], tc[3], tc[4])
      self:Show()
    else
      self:Hide()
    end
  end
  t:SetClass(class)
  return t
end

---------------------------------------------------------------------------
-- TableHead and TableRow: column heads over a Kit.List with the same widths as the rows; a click on a sortable head
-- sorts (gold text and an arrow), a second click turns the order. One column grows (grow = true), the others are fixed.
--   local head = Kit.TableHead(parent, { columns = { { key = "name", text = "Name", width = 140, grow = true, sort = true },
--     { key = "level", text = "Lvl", width = 36, justify = "RIGHT", sort = true }, ... }, onSort = function(key, desc) end,
--     icon = true (room for a class or item icon left of the first column) })
--   head:Layout(width)  head:SetSort(key, desc)  head:Bind(list) (the list's "table" rows take the head's columns)
-- Rows: list kind "table" (item.cells = { "text" or { text, color } or { bar = 0..1, text, color } }, item.class (class
-- icon), item.icon (texture), item.markColor, item.status, item.titleColor (first cell), item.tooltipFn, item.dim).
-- Kit.TableCols(columns, width, icon) gives each column its x and width (used by both).
---------------------------------------------------------------------------
local TABLE_ICON = S.icon + 6
function Kit.TableCols(columns, w, icon)
  local x0 = S.markBar + 8 + (icon and TABLE_ICON or 0)
  local fixed, grow, n = 0, nil, #columns
  for i, c in ipairs(columns) do
    if c.grow and not grow then grow = i else fixed = fixed + (c.width or 60) end
  end
  local room = w - x0 - S.pad - (n - 1) * S.gap
  local out, x = {}, x0
  for i, c in ipairs(columns) do
    local cw = c.width or 60
    if i == grow then cw = max(c.width or 40, room - fixed) end
    out[i] = { x = x, w = max(1, cw) }
    x = x + cw + S.gap
  end
  return out, x0
end

function Kit.TableHead(parent, opts)
  opts = opts or {}
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(S.chip)
  h.bg = Fill(h, C.group)
  h.line = Tex(h, "ARTWORK", C.goldMuted)
  h.line:SetPoint("BOTTOMLEFT") h.line:SetPoint("BOTTOMRIGHT") h.line:SetHeight(1)
  h.columns, h.cells = opts.columns or {}, {}
  for i, col in ipairs(h.columns) do
    local b = CreateFrame("Button", nil, h)
    b:SetHeight(S.chip)
    b.text = Text(b, "group", C.muted, col.justify or "LEFT")
    b.arrow = Text(b, "badge", C.txGold, "CENTER")
    b.col = col
    b._cutTexts = { b.text }
    Clickable(b, function(self)
      if not self.col.sort then return end
      local desc = h.sortKey == self.col.key and not h.desc or (h.sortKey ~= self.col.key and self.col.desc) or false
      h:SetSort(self.col.key, desc)
      Safe("table sort", opts.onSort, self.col.key, desc, h)
    end)
    Stateful(b, function(self, st)
      local on = h.sortKey == self.col.key
      TextColor(self.text, on and C.txGold or (st == "hover" and self.col.sort) and C.title or C.muted)
    end)
    if col.tooltip then b:SetTooltip(col.tooltip[1] or col.text, col.tooltip[2]) end
    h.cells[i] = b
  end
  function h:SetSort(key, desc)
    self.sortKey, self.desc = key, desc and true or false
    for _, b in ipairs(self.cells) do
      b.arrow:SetText(b.col.key == key and (self.desc and "v" or "^") or "")
      Refresh(b)
    end
    if self._w then self:Layout(self._w) end
  end
  function h:Cols(w) return Kit.TableCols(self.columns, w or self._w or 400, opts.icon) end
  function h:Layout(w)
    self._w = w
    self:SetWidth(w)
    local cols = self:Cols(w)
    for i, b in ipairs(self.cells) do
      local c = cols[i]
      b:ClearAllPoints()
      b:SetPoint("LEFT", self, "LEFT", c.x, 0)
      b:SetWidth(c.w)
      b.text:SetText(Upper(b.col.text or ""))
      local aw = b.arrow:GetText() ~= "" and 10 or 0
      b.text:ClearAllPoints() b.arrow:ClearAllPoints()
      if (b.col.justify or "LEFT") == "RIGHT" then
        b.text:SetPoint("RIGHT", b, "RIGHT", 0, 0)
        b.arrow:SetPoint("RIGHT", b, "RIGHT", -min(TextW(b.text), c.w - aw) - 2, 0)
      else
        b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
        b.arrow:SetPoint("LEFT", b, "LEFT", min(TextW(b.text), c.w - aw) + 2, 0)
      end
      Kit.Fit(b.text, max(1, c.w - aw))
    end
    if self.list then self.list.columns, self.list.tableIcon = self.columns, opts.icon end
  end
  function h:Bind(list) self.list = list list.columns, list.tableIcon = self.columns, opts.icon end
  if opts.sortKey then h:SetSort(opts.sortKey, opts.desc) end
  return h
end

function Kit.TableRow(parent)
  local r = RowBase(parent, S.sub, C.row)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(S.icon, S.icon)
  r.icon:Hide()
  r.cells, r.bars = {}, {}
  function r:Cell(i)
    local fs = self.cells[i]
    if not fs then fs = Text(self, i == 1 and "row" or "sub", C.body) self.cells[i] = fs end
    return fs
  end
  function r:SetItem(it, index, list)
    self.item, self._alt, self.list = it, index and index % 2 == 0, list or self.list
    if it.class then
      local tc = Kit.ClassCoords(it.class)
      if tc then self.icon:SetTexture(CLASS_SHEET) Call(self.icon, "SetTexCoord", tc[1], tc[2], tc[3], tc[4]) self.icon:Show() else self.icon:Hide() end
    elseif it.icon then
      Call(self.icon, "SetTexture", it.icon) Call(self.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93) self.icon:Show()
    else
      self.icon:Hide()
    end
    local cells = it.cells or {}
    for i = 1, max(#cells, #self.cells) do
      local v = cells[i]
      local fs = self:Cell(i)
      local text, color = v, nil
      if type(v) == "table" then text, color = v.text or v[1], v.color or v[2] end
      fs:SetText(text ~= nil and tostring(text) or "")
      -- (02.11.2026, Daniel: "rarity farben von wow hinterlegen") item.quality: the first cell in the game's item quality colour
      if i == 1 and it.quality then color = Kit.QualityColor(it.quality) end
      TextColor(fs, color or (i == 1 and (it.titleColor or C.title)) or C.muted)
      if v == nil then fs:Hide() else fs:Show() end
    end
    self._tip = type(it.tooltip) == "table" and { it.tooltip[1], it.tooltip[2], it.tooltip[3] } or nil
    -- (02.11.2026) item.itemID: the game's item tooltip with item.tipLines / item.tipHint below (Kit.ItemTipFn)
    self._tipFn, self._onHover = it.tooltipFn or (not self._tip and it.itemID and Kit.ItemTipFn) or nil, it.onHover
    self._dim = it.dim and true or nil
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    self._w = w
    local list = self.list or {}
    local columns = list.columns or {}
    local cols, x0 = Kit.TableCols(columns, w, list.tableIcon)
    self.icon:ClearAllPoints()
    self.icon:SetPoint("LEFT", S.markBar + 8, 0)
    local cells = self.item and self.item.cells or {}
    for i, fs in ipairs(self.cells) do
      local c = cols[i] or { x = x0, w = 40 }
      local col = columns[i] or {}
      local v = cells[i]
      local bar = type(v) == "table" and v.bar
      fs:ClearAllPoints()
      Call(fs, "SetJustifyH", col.justify or "LEFT")
      if bar then
        -- a cell with a bar: the bar fills the cell, the text ("285/300") right of it in 48 px
        local b = self.bars[i]
        if not b then b = Kit.ProgressBar(self) self.bars[i] = b end
        local tw = min(48, floor(c.w * 0.4))
        b:ClearAllPoints()
        b:SetPoint("LEFT", self, "LEFT", c.x, 0)
        b:Layout(max(4, c.w - tw - 4))
        b:SetColor(v.barColor or (tonumber(bar) and bar >= 1 and "green") or nil)
        b:SetValue(tonumber(bar) or 0)
        b:Show()
        fs:SetPoint("RIGHT", self, "LEFT", c.x + c.w, 0)
        Kit.Fit(fs, tw)
      else
        if self.bars[i] then self.bars[i]:Hide() end
        if (col.justify or "LEFT") == "RIGHT" then fs:SetPoint("RIGHT", self, "LEFT", c.x + c.w, 0)
        else fs:SetPoint("LEFT", self, "LEFT", c.x, 0) end
        Kit.Fit(fs, c.w)
      end
    end
  end
  r._cutTexts = r.cells
  Stateful(r, function(self, st)
    local sel = st == "selected" or (self.item and self.item.active)
    local it = self.item
    SetCol(self.bg, sel and C.rowSel or st == "hover" and C.rowHover or self._alt and C.rowAlt or C.row)
    local mc = sel and C.goldBright or (it and it.markColor) or MarkColor(it and it.status)
    if mc then SetCol(self.mark, mc) self.mark:Show() else self.mark:Hide() end
    SetCol(self.lineB, sel and C.gold or C.divider)
    if sel then self.lineT:Show() else self.lineT:Hide() end
    PlainBg(self, sel or st == "hover")
  end)
  return r
end
KIND_H.table = S.sub
ROW_MAKER.table = Kit.TableRow

---------------------------------------------------------------------------
-- ItemIcon: an item's symbol (16, 28 or 36 px) with an edge in its quality colour, the count bottom right, the game's
-- item tooltip under the mouse, Shift-click puts the link into the chat. i:SetItem(itemID or link, count, quality)
---------------------------------------------------------------------------
local QUALITY = { [0] = "9D9D9D", "FFFFFF", "1EFF00", "0070DD", "A335EE", "FF8000", "E6CC80", "00CCFF" }
function Kit.QualityColor(q)
  local src = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[tonumber(q) or -1]
  if type(src) == "table" and tonumber(src.r) then return { src.r, src.g, src.b } end
  return QUALITY[tonumber(q) or -1] and Hex(QUALITY[tonumber(q)]) or C.goldMuted
end
local function ItemData(item)
  local id = tonumber(item) or (type(item) == "string" and tonumber(item:match("item:(%d+)")))
  local icon, quality, link
  if C_Item and C_Item.GetItemIconByID and id then local ok, v = pcall(C_Item.GetItemIconByID, id) if ok then icon = v end end
  if not icon and type(GetItemIcon) == "function" and id then local ok, v = pcall(GetItemIcon, id) if ok then icon = v end end
  local getInfo = (C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo")
  if type(getInfo) == "function" and item then
    local ok, _, l, q, _, _, _, _, _, _, tex = pcall(getInfo, item)
    if ok then link, quality, icon = l, q, icon or tex end
  end
  if type(item) == "string" and item:find("|H") then link = item end
  return id, icon, quality, link
end
Kit.ItemData = ItemData
function Kit.ItemIcon(parent, size)
  size = size or S.iconMid
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  Fill(b, C.input)
  b.bd = Border(b, C.goldMuted)
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetPoint("TOPLEFT", 1, -1) b.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  Call(b.tex, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
  b.count = Text(b, "mono", C.hero, "RIGHT")
  b.count:SetPoint("BOTTOMRIGHT", -1, 1)
  function b:SetItem(item, count, quality)
    local id, icon, q, link = ItemData(item)
    self.itemID, self.link, self.quality = id, link, quality or q
    Call(self.tex, "SetTexture", icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.bd:SetColor(self.quality and Kit.QualityColor(self.quality) or C.goldMuted)
    count = tonumber(count)
    self.count:SetText((count and count > 1) and tostring(count) or "")
  end
  -- (minor 10) red symbol like Blizzard's items you cannot use
  function b:SetUnusable(on)
    self.unusable = on and true or nil
    if on then Call(self.tex, "SetVertexColor", 0.9, 0.15, 0.15) else Call(self.tex, "SetVertexColor", 1, 1, 1) end
  end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and self.link then
      local ins = rawget(_G, "ChatEdit_InsertLink")
      if type(ins) == "function" then pcall(ins, self.link) return end
    end
    if self._onClick then Safe("item click", self._onClick, self, button) end
  end)
  b:SetScript("OnEnter", function(self)
    local tt = GameTooltip
    if not tt or not pcall(tt.SetOwner, tt, self, "ANCHOR_RIGHT") then return end
    local me = self
    local waits = Kit.ItemWait(self, self.itemID, function() local f = me:GetScript("OnEnter") if f then f(me) end end) -- (minor 19)
    local shown = waits and Kit.ItemFallbackTip(tt, self.tipFallback) or false
    if not shown and self.link and tt.SetHyperlink then shown = pcall(tt.SetHyperlink, tt, self.link) end
    if not shown and self.itemID and tt.SetItemByID then shown = pcall(tt.SetItemByID, tt, self.itemID) end
    if self.extraTip then for _, l in ipairs(self.extraTip) do pcall(tt.AddLine, tt, tostring(l), C.muted[1], C.muted[2], C.muted[3], true) end end
    if type(self.reason) == "string" then pcall(tt.AddLine, tt, self.reason, C.red[1], C.red[2], C.red[3], true) end
    pcall(tt.Show, tt)
  end)
  b:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return b
end

---------------------------------------------------------------------------
-- (minor 10) ItemGrid: item symbols (Kit.ItemIcon) in rows, as many per row as the width takes; nothing scrolls, the
-- caller gives the room. opts.size (default 28), opts.gap (4), opts.onClick(icon, button, entry).
-- g:SetItems({ { itemID, quality, count, unusable (true or a reason text), tipFallback (minor 19) }, ... }) or plain item ids,
-- g:Layout(w) returns the height (0 without items), g.icons
---------------------------------------------------------------------------
function Kit.ItemGrid(parent, opts)
  opts = opts or {}
  local size, gap = opts.size or 28, opts.gap or S.unit
  local g = CreateFrame("Frame", nil, parent)
  g.icons, g.entries = {}, {}
  function g:SetItems(list)
    self.entries = type(list) == "table" and list or {}
    for i, e in ipairs(self.entries) do
      local b = self.icons[i]
      if not b then
        b = Kit.ItemIcon(self, size)
        b._onClick = function(icon, button) Safe("item grid", opts.onClick, icon, button, icon.entry) end
        self.icons[i] = b
      end
      local en = type(e) == "table" and e or { itemID = e }
      b.entry = en
      b:SetItem(en.itemID, en.count, en.quality)
      b:SetUnusable(en.unusable)
      b.reason = type(en.unusable) == "string" and en.unusable or nil
      b.tipFallback = en.tipFallback -- (minor 19)
      b:Show()
    end
    for i = #self.entries + 1, #self.icons do self.icons[i]:Hide() self.icons[i].entry = nil end
    self:Layout(self._w or self:GetWidth() or 200)
  end
  function g:Layout(w)
    w = tonumber(w) or 200
    self._w = w
    local cols = max(1, floor((w + gap) / (size + gap)))
    local n = #self.entries
    for i = 1, n do
      local b = self.icons[i]
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", ((i - 1) % cols) * (size + gap), -floor((i - 1) / cols) * (size + gap))
    end
    local h = n > 0 and (ceil(n / cols) * (size + gap) - gap) or 0
    self:SetSize(w, max(1, h))
    return h
  end
  return g
end

---------------------------------------------------------------------------
-- EditBox 28 high in the Don style for text and numbers: opts.placeholder, opts.numeric (whole numbers, opts.min/max
-- clamp on leaving), opts.maxLetters, opts.onChange(text, box) on typing, opts.onEnter(box), (minor 21) opts.onLeave(box)
-- when it loses the focus, opts.clear (a small x),
-- Tab goes to box.nextBox (box:SetNext(other)). e:GetValue() (a number when numeric), e:SetValue(v), e:Layout(w)
---------------------------------------------------------------------------
function Kit.EditBox(parent, opts)
  opts = opts or {}
  local e = CreateFrame("EditBox", nil, parent)
  e:SetHeight(S.button)
  Call(e, "SetAutoFocus", false)
  local fo = Kit.Font("row")
  if fo then Call(e, "SetFontObject", fo) end
  Call(e, "SetTextColor", C.body[1], C.body[2], C.body[3], 1)
  Call(e, "SetTextInsets", opts.numeric and 4 or 8, opts.clear and 24 or (opts.numeric and 4 or 8), 0, 0)
  Call(e, "SetMaxLetters", opts.maxLetters or (opts.numeric and 9) or 120)
  -- (02.11.2026, Daniel: "text gerne mittig setzen") a number box shows its number and placeholder in the middle
  if opts.numeric then Call(e, "SetNumeric", true) Call(e, "SetJustifyH", "CENTER") end
  e.bg = Fill(e, C.input)
  e.bd = Border(e, C.mid)
  e.hint = Text(e, "row", C.quiet, opts.numeric and "CENTER" or "LEFT")
  if opts.numeric then e.hint:SetPoint("CENTER", 0, 0) else e.hint:SetPoint("LEFT", 8, 0) end
  e.hint:SetText(opts.placeholder or "")
  if opts.clear then
    e.clear = CreateFrame("Button", nil, e)
    e.clear:SetSize(16, 16)
    e.clear:SetPoint("RIGHT", -6, 0)
    e.clear.text = Text(e.clear, "badge", C.muted, "CENTER")
    e.clear.text:SetPoint("CENTER", 0, 0)
    e.clear.text:SetText("x")
  end
  local function Changed(self, user)
    local t = self:GetText() or ""
    if t == "" then self.hint:Show() else self.hint:Hide() end
    if self.clear then if t == "" then self.clear:Hide() else self.clear:Show() end end
    if user then Safe("edit", opts.onChange, t, self) end
  end
  if e.clear then e.clear:SetScript("OnClick", function() e:SetText("") e:ClearFocus() Changed(e, true) end) end
  function e:GetValue()
    local t = self:GetText() or ""
    if opts.numeric then
      local n = tonumber(t)
      if n and opts.min then n = max(opts.min, n) end
      if n and opts.max then n = min(opts.max, n) end
      return n
    end
    return t
  end
  function e:SetValue(v) self:SetText(v ~= nil and tostring(v) or "") Changed(self, false) end
  function e:SetNext(other) self.nextBox = other end
  e:SetScript("OnTextChanged", Changed)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() Safe("edit enter", opts.onEnter, self) end)
  e:SetScript("OnTabPressed", function(self) if self.nextBox and self.nextBox.SetFocus then self.nextBox:SetFocus() else self:ClearFocus() end end)
  -- (04.11.2026, Era-Test, Daniel: "wenn ich hier reinklicke, soll direkt die ganze zahl markiert sein, damit ich
  -- überschreiben kann ohne zu löschen") number and money boxes select their whole text on focus; the click places the
  -- cursor after OnEditFocusGained, so once more on the next frame
  local selectAll = opts.selectAll or (opts.selectAll == nil and opts.numeric)
  e:SetScript("OnEditFocusGained", function(self)
    self._focus = true Refresh(self)
    if selectAll then
      Call(self, "HighlightText")
      if C_Timer and C_Timer.After then C_Timer.After(0, function() if self._focus then Call(self, "HighlightText") end end) end
    end
  end)
  e:SetScript("OnEditFocusLost", function(self)
    self._focus = nil
    if opts.numeric and (self:GetText() or "") ~= "" then
      local n = self:GetValue()
      if n and tostring(n) ~= self:GetText() then self:SetText(tostring(n)) Safe("edit", opts.onChange, tostring(n), self) end
    end
    if opts.onLeave then Safe("edit leave", opts.onLeave, self) end
    Refresh(self)
  end)
  function e:Layout(w) self._w = w self:SetWidth(w) Kit.Fit(self.hint, max(1, w - 16 - (self.clear and 16 or 0))) end
  Stateful(e, function(self, st)
    self.bd:SetColor(self._focus and C.gold or st == "hover" and C.goldMuted or C.mid)
  end)
  e._onDisabled = function(self, off) Call(self, "EnableMouse", not off) if off then self:ClearFocus() end end
  e:Layout(opts.width or 120)
  if opts.value ~= nil then e:SetValue(opts.value) else Changed(e, false) end
  return e
end

---------------------------------------------------------------------------
-- Segmented: two to four fields side by side, one picked (instead of radio buttons). opts.items = { { value, text, tip } },
-- opts.get(), opts.set(value). s:Update(), s:Layout(width): the fields share it, texts are cut (whole text in the tooltip)
---------------------------------------------------------------------------
function Kit.Segmented(parent, opts)
  opts = opts or {}
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(S.button)
  s.fields = {}
  for i, it in ipairs(opts.items or {}) do
    local b = CreateFrame("Button", nil, s)
    b:SetHeight(S.button)
    b.bg = Fill(b, C.input)
    b.bd = Border(b, C.mid)
    b.text = Text(b, "button", C.muted, "CENTER")
    b.text:SetPoint("CENTER", 0, 0)
    b.text:SetText(it.text or tostring(it.value))
    b.value = it.value
    b._cutTexts = { b.text }
    Clickable(b, function(self)
      s.value = self.value
      s:Paint()
      Safe("segmented", opts.set, self.value, s)
    end)
    Stateful(b, function(self, st)
      local on = st == "selected"
      SetCol(self.bg, on and C.chipActive or st == "hover" and C.rowHover or C.input)
      self.bd:SetColor(on and C.gold or st == "hover" and C.goldMuted or C.mid)
      TextColor(self.text, on and C.hero or st == "hover" and C.title or C.muted)
    end)
    if it.tip then b:SetTooltip(it.text, { it.tip }) end
    s.fields[i] = b
  end
  function s:Paint() for _, b in ipairs(self.fields) do b:SetSelected(b.value == self.value) end end
  function s:Update(v)
    if v == nil then v = Safe("segmented get", opts.get) end
    self.value = v
    self:Paint()
  end
  function s:Layout(w)
    self._w = w
    self:SetWidth(w)
    local n = max(1, #self.fields)
    local each = floor((w - (n - 1) * 2) / n)
    for i, b in ipairs(self.fields) do
      b:ClearAllPoints()
      b:SetPoint("LEFT", self, "LEFT", (i - 1) * (each + 2), 0)
      b:SetWidth(each)
      Kit.Fit(b.text, max(1, each - 8))
    end
  end
  s:Layout(opts.width or 240)
  s:Update()
  return s
end

---------------------------------------------------------------------------
-- BarList: one bar per entry (class census, income per source): symbol, name, a bar with a second bright share (online
-- of all), the number on the right. Click and tooltip per entry.
--   b:SetEntries({ { key, text, class (class symbol and colour) or icon, color, value, value2, right, tooltip = { title,
--     lines, hint } }, ... }, maxValue)   b:Layout(width) -> height   opts.onClick(entry), opts.rowH (18)
---------------------------------------------------------------------------
function Kit.BarList(parent, opts)
  opts = opts or {}
  local rowH = opts.rowH or 18
  local bl = CreateFrame("Frame", nil, parent)
  bl.rows, bl.entries = {}, {}
  local function Row(i)
    local r = bl.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, bl)
    r:SetHeight(rowH)
    r.hover = Fill(r, C.rowHover)
    r.hover:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(rowH - 4, rowH - 4)
    r.icon:SetPoint("LEFT", 0, 0)
    r.name = Text(r, "sub", C.body)
    r.track = Tex(r, "BACKGROUND", C.input, 1)
    r.track:SetHeight(6)
    r.fill = Tex(r, "ARTWORK", C.gold)
    r.fill:SetHeight(6)
    r.fill2 = Tex(r, "OVERLAY", C.goldBright)
    r.fill2:SetHeight(6)
    r.num = Text(r, "mono", C.title, "RIGHT")
    r.num:SetPoint("RIGHT", 0, 0)
    r._cutTexts = { r.name }
    Clickable(r, function(self) if self.entry then Safe("barlist click", opts.onClick, self.entry, bl) end end)
    Stateful(r, function(self, st) if st == "hover" then self.hover:Show() else self.hover:Hide() end end)
    bl.rows[i] = r
    return r
  end
  function bl:SetEntries(list, top)
    self.entries = list or {}
    local m = tonumber(top) or 0
    for _, e in ipairs(self.entries) do m = max(m, tonumber(e.value) or 0) end
    self.top = m
    for i, e in ipairs(self.entries) do
      local r = Row(i)
      r.entry = e
      local col = e.class and Kit.ClassColor(e.class) or Col(e.color or C.gold)
      if e.class and Kit.ClassCoords(e.class) then
        local tc = Kit.ClassCoords(e.class)
        r.icon:SetTexture(CLASS_SHEET) Call(r.icon, "SetTexCoord", tc[1], tc[2], tc[3], tc[4]) r.icon:Show()
      elseif e.icon then
        Call(r.icon, "SetTexture", e.icon) Call(r.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93) r.icon:Show()
      else
        r.icon:Hide()
      end
      r.name:SetText(e.text or "")
      TextColor(r.name, e.class and col or C.body)
      SetCol(r.fill, col, 0.45)
      SetCol(r.fill2, col)
      r.num:SetText(e.right or (e.value ~= nil and tostring(e.value)) or "")
      r._tip = e.tooltip and { e.tooltip[1], e.tooltip[2], e.tooltip[3] } or nil
      r:Show()
    end
    for i = #self.entries + 1, #self.rows do self.rows[i]:Hide() self.rows[i].entry = nil end
    if self._w then self:Layout(self._w) end
  end
  function bl:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    local nameW = min(110, floor(w * 0.36))
    local numW = 40
    for i, e in ipairs(self.entries) do
      local r = self.rows[i]
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(i - 1) * rowH)
      r:SetWidth(w)
      local x = r.icon:IsShown() and rowH or 0
      r.name:ClearAllPoints()
      r.name:SetPoint("LEFT", x, 0)
      Kit.Fit(r.name, max(1, nameW - x))
      Kit.Fit(r.num, numW)
      local bx = nameW + 4
      local bw = max(4, w - bx - numW - 6)
      r.track:ClearAllPoints() r.track:SetPoint("LEFT", bx, 0) r.track:SetWidth(bw)
      local top = max(1, self.top or 1)
      local v, v2 = tonumber(e.value) or 0, tonumber(e.value2)
      local fw = floor(bw * v / top)
      if fw > 0 then r.fill:ClearAllPoints() r.fill:SetPoint("LEFT", bx, 0) r.fill:SetWidth(fw) r.fill:Show() else r.fill:Hide() end
      local fw2 = v2 and floor(bw * min(v2, v) / top) or 0
      if fw2 > 0 then r.fill2:ClearAllPoints() r.fill2:SetPoint("LEFT", bx, 0) r.fill2:SetWidth(fw2) r.fill2:Show() else r.fill2:Hide() end
    end
    local h = max(1, #self.entries * rowH)
    self:SetSize(max(1, w), h)
    return h
  end
  return bl
end

---------------------------------------------------------------------------
-- Dialog: a small window in the middle of the screen (wish form, questions): head with symbol, title and close, a body
-- d.body for the caller's parts, a row of buttons bottom right; Esc closes, the head drags it.
--   local d = Kit.Dialog("MyDialog", { title, icon, width = 420, height = 300, onClose(d) })
--   d:SetButtons({ { text, kind = "primary", onClick(d) , tooltip }, ... })  d:SetTitle(text, icon)  d:Layout()
--   d.body: width d:BodyWidth(), height d:BodyHeight()
---------------------------------------------------------------------------
function Kit.Dialog(name, opts)
  opts = opts or {}
  local d = CreateFrame("Frame", name, UIParent)
  d.opts = opts
  Call(d, "SetFrameStrata", "DIALOG")
  Call(d, "SetToplevel", true)
  Call(d, "SetClampedToScreen", true)
  Call(d, "SetMovable", true)
  Call(d, "EnableMouse", true)
  d:SetSize(opts.width or 420, opts.height or 300)
  d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  Kit.Scaled(d) -- (minor 13)
  -- (minor 16, 04.11.2026, Era-Test, Daniel on Luredon's question: "schon seeehr groß") a dialog always shows at Kit.scale
  -- times its own factor: Luredon set SetScale(1.5) before Show, which replaced the 0.8 and made the dialog 1.875 times
  -- the Kit windows. Show puts the Kit scale back; a dialog that should be larger asks for it with d:SetOwnScale(f).
  function d:SetOwnScale(v)
    self._ownScale = tonumber(v) or 1
    ApplyScale(self, false)
  end
  local show = d.Show
  function d:Show(...)
    ApplyScale(self, false)
    return show(self, ...)
  end
  Fill(d, C.window)
  Border(d, C.outer, 0)
  Border(d, C.gold, 1)
  d.head = CreateFrame("Frame", nil, d)
  d.head:SetPoint("TOPLEFT", 2, -2) d.head:SetPoint("TOPRIGHT", -2, -2)
  d.head:SetHeight(S.head - 8)
  Fill(d.head, C.panel)
  local hl = Tex(d.head, "ARTWORK", C.gold)
  hl:SetPoint("BOTTOMLEFT") hl:SetPoint("BOTTOMRIGHT") hl:SetHeight(1)
  Call(d.head, "EnableMouse", true)
  Call(d.head, "RegisterForDrag", "LeftButton")
  d.head:SetScript("OnDragStart", function() d:StartMoving() end)
  d.head:SetScript("OnDragStop", function() d:StopMovingOrSizing() end)
  d.iconBox = CreateFrame("Frame", nil, d.head)
  d.iconBox:SetSize(S.iconMid - 2, S.iconMid - 2)
  d.iconBox:SetPoint("LEFT", S.pad, 0)
  Fill(d.iconBox, C.input)
  Border(d.iconBox, C.goldMuted)
  d.icon = d.iconBox:CreateTexture(nil, "ARTWORK")
  d.icon:SetPoint("TOPLEFT", 1, -1) d.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  Call(d.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
  d.title = Text(d.head, "title", C.hero)
  d.close = Kit.IconButton(d.head, "close", { size = S.buttonSmall - 4, onClick = function() d:Hide() end })
  d.close:SetPoint("RIGHT", -S.gap, 0)
  d.body = CreateFrame("Frame", nil, d)
  d.body:SetPoint("TOPLEFT", S.pad, -(S.head - 8 + 2 + S.pad))
  d.buttons = {}
  function d:SetTitle(text, icon)
    self.title:SetText(text or "")
    if icon then Call(self.icon, "SetTexture", icon) self.iconBox:Show() else self.iconBox:Hide() end
    self:Layout()
  end
  function d:SetButtons(list)
    for _, b in ipairs(self.buttons) do b:Hide() end
    for i, a in ipairs(list or {}) do
      local b = self.buttons[i]
      if not b then b = Kit.Button(self, "") self.buttons[i] = b end
      b:SetText(a.text or "")
      b._onClick = function() Safe("dialog button", a.onClick, self) end
      b:SetKind(a.kind or "secondary")
      if a.tooltip then b:SetTooltip(a.tooltip[1], a.tooltip[2], a.tooltip[3]) else b._tip = nil end
      b:SetDisabled(a.disabled)
      b:Show()
    end
    self.nButtons = #(list or {})
    self:Layout()
  end
  function d:BodyWidth() return (self:GetWidth() or 420) - 2 * S.pad end
  function d:BodyHeight() return (self:GetHeight() or 300) - (S.head - 8 + 2 + S.pad) - S.pad - ((self.nButtons or 0) > 0 and S.button + S.pad or 0) end
  function d:Layout()
    local w = self:GetWidth() or 420
    local x = S.pad + (self.iconBox:IsShown() and S.iconMid + S.gap - 2 or 0)
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", self.head, "LEFT", x, 0)
    Kit.Fit(self.title, max(40, w - x - S.buttonSmall - 2 * S.gap))
    self.body:SetSize(self:BodyWidth(), max(1, self:BodyHeight()))
    local n = self.nButtons or 0
    local rx = S.pad
    local each = floor((w - 2 * S.pad - (n - 1) * S.gap) / max(1, n))
    for i = n, 1, -1 do
      local b = self.buttons[i]
      local bw = min(b.natural or each, each)
      b:ClearAllPoints()
      b:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -rx, S.pad)
      b:Layout(bw)
      rx = rx + bw + S.gap
    end
    Safe("dialog layout", self.opts.onLayout, self, self:BodyWidth(), self:BodyHeight())
  end
  function d:SetBodySize(w, h)
    self:SetSize(w + 2 * S.pad, h + (S.head - 8 + 2 + S.pad) + S.pad + ((self.nButtons or 0) > 0 and S.button + S.pad or 0))
    self:Layout()
  end
  d:SetScript("OnHide", function(self)
    if Kit._menu and Kit._menu:IsShown() then Kit._menu:Hide() end
    Safe("dialog close", self.opts.onClose, self)
  end)
  if name and type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = name end
  d:SetTitle(opts.title, opts.icon)
  d:Hide()
  return d
end

---------------------------------------------------------------------------
-- CopyBox: one shared dialog to copy a text (export lines, reports, shopping lists): title, a hint line, the text marked,
-- "Select all" and "Close". Kit.ShowCopy(title, hint, text, words) with words = { selectAll = "...", close = "..." } (the
-- addon's translation; English otherwise). Returns the dialog (d.edit is the edit box).
---------------------------------------------------------------------------
function Kit.ShowCopy(title, hint, text, words)
  words = words or {}
  local d = Kit._copy
  if not d then
    d = Kit.Dialog("DonKitCopyBox", { width = 560, height = 340, icon = nil, onLayout = function(self, w, h)
      if not self.hint then return end
      self.hint:ClearAllPoints()
      self.hint:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
      -- (04.11.2026, Era-Test) the hint wraps (long hints like Questdon's export with its address were cut to one line)
      Call(self.hint, "SetWidth", w)
      Call(self.hint, "SetWordWrap", true)
      Call(self.hint, "SetJustifyH", "LEFT")
      local ok, sh = Call(self.hint, "GetStringHeight")
      local top = (self.hint:GetText() or "") == "" and 0 or max(14, ok and tonumber(sh) or 14) + 8
      self.scroll:ClearAllPoints()
      self.scroll:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -top)
      self.scroll:SetSize(w, max(20, h - top))
      self.edit:SetWidth(max(20, w - 16))
    end })
    d.hint = Text(d.body, "sub", C.muted)
    d.scroll = CreateFrame("ScrollFrame", nil, d.body)
    Fill(d.scroll, C.input)
    Border(d.scroll, C.mid)
    Call(d.scroll, "EnableMouseWheel", true)
    d.edit = CreateFrame("EditBox", nil, d.scroll)
    Call(d.edit, "SetMultiLine", true)
    Call(d.edit, "SetAutoFocus", false)
    local fo = Kit.Font("sub")
    if fo then Call(d.edit, "SetFontObject", fo) end
    Call(d.edit, "SetTextColor", C.body[1], C.body[2], C.body[3], 1)
    Call(d.edit, "SetTextInsets", 6, 6, 6, 6)
    d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
    -- the text stays what was given: typing does not change it
    d.edit:SetScript("OnTextChanged", function(self, user) if user and d.text then self:SetText(d.text) self:HighlightText() end end)
    Call(d.scroll, "SetScrollChild", d.edit)
    d.scroll:SetScript("OnMouseWheel", function(self, delta)
      local ok, cur = Call(self, "GetVerticalScroll")
      local okR, range = Call(self, "GetVerticalScrollRange")
      cur, range = ok and tonumber(cur) or 0, okR and tonumber(range) or 0
      Call(self, "SetVerticalScroll", Clamp(cur - delta * 40, 0, range))
    end)
    Kit._copy = d
  end
  d.text = text or ""
  d:SetTitle(title or "", nil)
  d:SetButtons({
    { text = words.selectAll or "Select all", onClick = function(dd) dd.edit:SetFocus() dd.edit:HighlightText() end },
    { text = words.close or "Close", kind = "primary", onClick = function(dd) dd:Hide() end },
  })
  d.hint:SetText(hint or "")
  d.edit:SetText(d.text)
  d:Show()
  d:Layout()
  d.edit:SetFocus()
  Call(d.edit, "HighlightText")
  return d
end

---------------------------------------------------------------------------
-- (minor 4, StyleKit 2 step 4 with Golddon, BAUSTEINE.md "Fehlt im Kit") money, items, table, segment, inputs, action
-- bar, line chart, box, note rows (Guildon's minor 4 brings ItemIcon, QualityColor, EditBox, Segmented, BarList). Everything one line, cut with the whole text in the tooltip.
---------------------------------------------------------------------------
-- Money: copper as a text with the game's coin symbols. opts.sign: "+" before gains, the digits green (gain) or red
-- (loss); opts.color: the digits' colour (Kit.C key or rgb); opts.full: every unit (12g 34s 56c), else at most the two
-- biggest (1.284g 37s, 72s 20c) and from 1000 gold only gold; opts.short: only the biggest (+120g); opts.letters: g s c instead of the coins (input fields).
-- Thousands with the client's separator (LARGE_NUMBER_SEPERATOR: "." in German).
Kit.COINS = { "Interface\\MoneyFrame\\UI-GoldIcon", "Interface\\MoneyFrame\\UI-SilverIcon", "Interface\\MoneyFrame\\UI-CopperIcon" }
function Kit.Thousands(n)
  local s = tostring(floor(tonumber(n) or 0))
  local sep = type(LARGE_NUMBER_SEPERATOR) == "string" and LARGE_NUMBER_SEPERATOR or ","
  if #s <= 3 or sep == "" then return s end
  local head = #s % 3
  local out = head > 0 and s:sub(1, head) or ""
  for i = head + 1, #s, 3 do out = out .. (out ~= "" and sep or "") .. s:sub(i, i + 2) end
  return out
end

local function Hexa(c) c = Col(c) return c.hex or ("ff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) end
Kit.HexColor = Hexa

-- (minor 16, 04.11.2026, Era-Test) a count of a total, "16 / 17": a plain space on each side of the slash, so the digits
-- (the narrow 1 above all) do not stick to it. A hair space (U+200A) is not in Friz Quadrata and Arial Narrow of the
-- client (it shows as a box), the plain space is the narrowest one every Kit font has.
function Kit.Fraction(a, b)
  return tostring(a == nil and "" or a) .. " / " .. tostring(b == nil and "" or b)
end

function Kit.Money(copper, opts)
  opts = opts or {}
  local c = floor((tonumber(copper) or 0) + 0.5)
  local neg = c < 0
  if neg then c = -c end
  local parts = { floor(c / 10000), floor(c / 100) % 100, c % 100 }
  local color = opts.color
  if opts.sign then color = neg and C.red or (c > 0 and C.green or C.muted) end
  local first
  for i = 1, 3 do if parts[i] > 0 then first = i break end end
  first = first or 3
  local last = opts.full and 3 or opts.short and first or min(3, first + 1)
  if first == 1 and parts[1] >= 1000 and not opts.full then last = 1 end
  local out, letters = {}, { "g", "s", "c" }
  for i = first, last do
    if parts[i] > 0 or i == first then
      local num = i == 1 and Kit.Thousands(parts[i]) or tostring(parts[i])
      local unit = opts.letters and letters[i] or ("|T" .. Kit.COINS[i] .. ":0:0:1:0|t")
      out[#out + 1] = num .. unit
    end
  end
  local s = table.concat(out, " ")
  local pre = neg and "-" or (opts.sign and c > 0 and "+" or "")
  if color then
    -- the digits in the colour, the coins stay as they are
    local hx = Hexa(color)
    s = ("|c%s%s|r"):format(hx, pre .. s:gsub("|T(.-)|t", "|r|T%1|t|c" .. hx))
    return s
  end
  return pre .. s
end

-- "1,5" or "1.5" gold, or "1g 50s 20c" -> copper; nil when nothing readable
function Kit.ParseMoney(t)
  t = tostring(t or ""):lower():gsub(",", ".")
  if t:find("[gsc]") then
    local total, any = 0, false
    for n, u in t:gmatch("([%d%.]+)%s*([gsc])") do
      local v = tonumber(n)
      if v then any = true total = total + v * (u == "g" and 10000 or u == "s" and 100 or 1) end
    end
    return any and floor(total + 0.5) or nil
  end
  local g = tonumber(t)
  return g and g >= 0 and floor(g * 10000 + 0.5) or nil
end

-- (minor 19) an item the game does not know yet: ask for it, and build the shown tooltip again when it comes
local itemWait = {}
local function ItemKnown(id)
  local GI = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not GI then return true end
  local ok, name = pcall(GI, id)
  return ok and name ~= nil
end
local function ItemAsk(id)
  local req = C_Item and C_Item.RequestLoadItemDataByID
  if type(req) == "function" then pcall(req, id) end
  if not itemWait.frame then
    itemWait.frame = CreateFrame("Frame")
    pcall(itemWait.frame.RegisterEvent, itemWait.frame, "GET_ITEM_INFO_RECEIVED")
    itemWait.frame:SetScript("OnEvent", function(_, _, got)
      local w = itemWait.tip
      if not (w and tonumber(got) == tonumber(w.id)) then return end
      itemWait.tip = nil
      local tt = GameTooltip
      local okO, owned = pcall(tt.IsOwned, tt, w.owner)
      local okS, shown = pcall(tt.IsShown, tt)
      if okO and owned and okS and shown then pcall(w.redo) end
    end)
  end
end
Kit.ItemWaitFrame = function() return itemWait.frame, itemWait.tip end -- (tests)
-- the tooltip of owner shows item id: when the game does not know it yet, ask and call redo() once it comes
-- true while it waits (the game does not know the item)
function Kit.ItemWait(owner, id, redo)
  if not id or ItemKnown(id) then itemWait.tip = nil return false end
  itemWait.tip = { owner = owner, id = id, redo = redo }
  ItemAsk(id)
  return true
end
-- the stand-in for an item the game does not know: fb = { name, quality, lines = { text or { label, value } } }
function Kit.ItemFallbackTip(tt, fb)
  if not (type(fb) == "table" and type(fb[1]) == "string" and fb[1] ~= "") then return false end
  local q = Kit.QualityColor(fb[2])
  pcall(tt.AddLine, tt, fb[1], q[1], q[2], q[3], true)
  for _, l in ipairs(type(fb.lines) == "table" and fb.lines or {}) do
    if type(l) == "table" and l[2] ~= nil then
      pcall(tt.AddDoubleLine, tt, tostring(l[1] or ""), tostring(l[2]), C.muted[1], C.muted[2], C.muted[3], C.body[1], C.body[2], C.body[3])
    elseif l ~= nil and l ~= "" then
      pcall(tt.AddLine, tt, tostring(l), C.body[1], C.body[2], C.body[3], true)
    end
  end
  return true
end

-- the game's item tooltip at owner (lines: more lines below, as Kit.Tooltip); false when the game has no such call
-- (minor 19) at the mouse for a wide owner (Kit.TipAnchor); an unknown item is asked for and the tooltip built again
-- fb: the stand-in while the game does not know the item (Kit.ItemFallbackTip)
function Kit.ItemTooltip(owner, id, lines, hint, fb)
  local tt = GameTooltip
  if not (tt and owner and id) then return false end
  if not TipOwner(tt, owner) then return false end
  local waits = Kit.ItemWait(owner, id, function() Kit.ItemTooltip(owner, id, lines, hint, fb) end)
  local ok = waits and Kit.ItemFallbackTip(tt, fb)
  if not ok then ok = tt.SetItemByID and pcall(tt.SetItemByID, tt, id) end
  if not ok then ok = tt.SetHyperlink and pcall(tt.SetHyperlink, tt, "item:" .. tostring(id)) end
  for _, l in ipairs(type(lines) == "table" and lines or {}) do
    if type(l) == "table" and l[2] ~= nil then
      local v = Col(l[3] or C.body)
      pcall(tt.AddDoubleLine, tt, tostring(l[1] or ""), tostring(l[2]), C.muted[1], C.muted[2], C.muted[3], v[1], v[2], v[3])
    elseif l ~= nil then
      local c = Col(type(l) == "table" and l.color or C.body) -- (minor 10) { text, color = ... }
      pcall(tt.AddLine, tt, tostring(type(l) == "table" and (l[1] or "") or l), c[1], c[2], c[3], true)
    end
  end
  if hint and hint ~= "" then pcall(tt.AddLine, tt, tostring(hint), C.quiet[1], C.quiet[2], C.quiet[3], true) end
  pcall(tt.Show, tt)
  return true
end
-- a row's tooltip function for item rows (row.item.itemID, row.item.tipLines)
-- (minor 10) item.unusable (a reason text): the reason in red under the lines
function Kit.ItemTipFn(row)
  local it = row.item
  if not (it and it.itemID) then return end
  local lines = it.tipLines
  if type(it.unusable) == "string" then
    lines = {}
    for _, l in ipairs(type(it.tipLines) == "table" and it.tipLines or {}) do lines[#lines + 1] = l end
    lines[#lines + 1] = { it.unusable, color = C.red }
  end
  Kit.ItemTooltip(row, it.itemID, lines, it.tipHint, it.tipFallback)
end

-- shift-click: the item's link into the open chat line (true when it did)
function Kit.LinkItem(id)
  if not (type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) then return false end
  local GI = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local ok, _, link = false, nil, nil
  if GI then ok, _, link = pcall(GI, id) end
  if type(link) ~= "string" then return false end
  if type(HandleModifiedItemClick) == "function" and pcall(HandleModifiedItemClick, link) then return true end
  if type(ChatEdit_InsertLink) == "function" then return pcall(ChatEdit_InsertLink, link) end
  return false
end

---------------------------------------------------------------------------
-- Table: a head of column titles (24 px, sortable ones with an arrow) over a virtual list of item rows (36 px): mark,
-- symbol, title and sub line growing, fixed columns on the right. The addon sorts; a click on a head calls
-- opts.onSort(key) and t:SetSort(key, ascending) shows the arrow.
--   cols = { { key = "title", title = "Item" }, { key = "cost", title = "Cost", width = 90, sort = true,
--            minWidth = 820 (under this list width the column goes), fold = "Cost" (then its value joins the sub line
--            with this word), color = "txGold" (the head's colour) }, ... }; the first column is the title.
--   item: kind = "trow" (default in a table), title, sub, icon, quality, itemID, markColor, cells = { [key] = text },
--   active; other kinds (group, note) mix in. opts.onClick(item, button, list), opts.kinds, opts.empty
-- t:SetColumns(cols), t:SetItems(items, reset), t:Layout(w, h), t.list (the Kit.List)
-- (Kit.TableHead / TableRow: one-line 28 px cells for plain tables such as a member list; Kit.Table: item lists with a
-- symbol and a sub line, numbers right-aligned from the edge, rows Kit.ItemRow)
---------------------------------------------------------------------------
local function VisibleCols(cols, w)
  local out = {}
  for i, c in ipairs(cols or {}) do
    if i > 1 and not (c.minWidth and w < c.minWidth) then out[#out + 1] = c end
  end
  return out
end

function Kit.ItemRow(parent)
  local r = RowBase(parent, S.row, C.row)
  r.iconBox = Kit.ItemIcon(r, S.iconMid)
  Call(r.iconBox, "EnableMouse", false) -- the row shows the tooltip and takes the click
  r.title = Text(r, "row", C.title)
  r.sub = Text(r, "sub", C.muted)
  r.cells = {}
  function r:Cell(i)
    local fs = self.cells[i]
    if not fs then fs = Text(self, "row", C.body, "RIGHT") self.cells[i] = fs end
    return fs
  end
  function r:SetItem(it, index, list)
    self.item, self._alt, self.tlist = it, index and index % 2 == 0, list
    if it.icon or it.itemID then
      self.iconBox:SetItem(it.itemID, nil, it.quality)
      if it.icon then Call(self.iconBox.tex, "SetTexture", it.icon) end
      self.iconBox:SetUnusable(it.unusable)
      self.iconBox:Show()
    else self.iconBox:Hide() end
    self.title:SetText(it.title or "")
    TextColor(self.sub, it.subColor or C.muted)
    self._tip = type(it.tooltip) == "table" and { it.tooltip[1], it.tooltip[2] } or nil
    self._tipFn = it.tooltipFn or (not self._tip and it.itemID and Kit.ItemTipFn) or nil
    self._dim = (it.done or it.unusable) and true or nil
    self._active = it.active and true or nil
    -- (07.11.2026, Profitdon: "oben ein X für das löschen") item.onRemove(item): a small X, (minor 21) left of the symbol,
    -- item.removeTip its tooltip
    if it.onRemove then
      if not self.x then
        self.x = Kit.IconButton(self, "close", { size = S.buttonSmall - 4, onClick = function()
          local cur = self.item
          if cur and cur.onRemove then Safe("row remove", cur.onRemove, cur) end
        end })
      end
      if self.x.SetTooltip then self.x:SetTooltip(it.removeTip or "") end
      Call(self.x, "SetFrameLevel", (self:GetFrameLevel() or 1) + 3)
      self.x:Show()
    elseif self.x then self.x:Hide() end
    -- (minor 21) item.edit = { key, value, onCommit(item, n), tip }: a number box in the column key
    if it.edit then
      if not self.edit then
        local function Commit(box)
          local cur = self.item
          local ed = cur and cur.edit
          local n = box:GetValue()
          if ed and n and n ~= ed.value and ed.onCommit then ed.value = n Safe("row edit", ed.onCommit, cur, n) end
        end
        self.edit = Kit.EditBox(self, { numeric = true, min = 1, width = 56, onEnter = Commit, onLeave = Commit })
      end
      self.edit:SetValue(it.edit.value)
      if self.edit.SetTooltip and it.edit.tip then self.edit:SetTooltip(it.edit.tip) end
      Call(self.edit, "SetFrameLevel", (self:GetFrameLevel() or 1) + 3)
      self.edit:Show()
    elseif self.edit then self.edit:Hide() end
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    local it = self.item
    if not it then return end
    local cols = (self.tlist and self.tlist.columns) or {}
    local vis = VisibleCols(cols, w)
    local x = S.markBar + 8 + (tonumber(it.indent) or 0)
    if self.x and it.onRemove then
      self.x:ClearAllPoints()
      self.x:SetPoint("LEFT", x - 2, 0)
      x = x + (S.buttonSmall - 4) + S.gap - 2
    end
    self.iconBox:ClearAllPoints()
    self.iconBox:SetPoint("LEFT", x, 0)
    if self.iconBox:IsShown() then x = x + S.iconMid + S.gap end
    -- fixed columns from the right edge
    local rx = S.pad
    local cells = it.cells or {}
    local used = 0
    for i = #vis, 1, -1 do
      local c = vis[i]
      local fs = self:Cell(i)
      local edit = it.edit and it.edit.key == c.key and self.edit
      fs:SetText((cells[c.key] ~= nil and not edit) and tostring(cells[c.key]) or "")
      if edit then
        edit:ClearAllPoints()
        edit:SetPoint("RIGHT", -rx, 0)
        edit:SetHeight(S.button - 4)
        edit:Layout(max(36, min(64, (c.width or 80) - S.gap)))
      end
      TextColor(fs, (it.cellColors and it.cellColors[c.key]) or C.body)
      fs:SetJustifyH(c.align or "RIGHT")
      fs:ClearAllPoints()
      fs:SetPoint("RIGHT", -rx, 0)
      Kit.Fit(fs, (c.width or 80) - S.gap)
      fs:Show()
      rx = rx + (c.width or 80)
      used = i
    end
    for i = used + 1, #self.cells do if i > #vis then self.cells[i]:Hide() end end
    -- the values of columns that went join the sub line
    local sub = it.sub or ""
    for i = 2, #cols do
      local c = cols[i]
      if c.fold and c.minWidth and w < c.minWidth and cells[c.key] ~= nil and cells[c.key] ~= "" then
        sub = sub .. (sub ~= "" and "  " or "") .. (c.fold ~= true and (c.fold .. " ") or "") .. tostring(cells[c.key])
      end
    end
    self.sub:SetText(sub)
    local budget = max(20, w - x - rx - S.gap)
    self.title:ClearAllPoints() self.sub:ClearAllPoints()
    if sub ~= "" then
      self.title:SetPoint("TOPLEFT", x, -5)
      self.sub:SetPoint("TOPLEFT", x, -20)
    else
      self.title:SetPoint("LEFT", x, 0)
    end
    Kit.Fit(self.title, budget)
    Kit.Fit(self.sub, budget)
  end
  r._cutTexts = { r.title, r.sub }
  Stateful(r, function(self, st)
    local sel = st == "selected" or self._active
    local it = self.item
    SetCol(self.bg, sel and C.rowSel or st == "hover" and C.rowHover or self._alt and C.rowAlt or C.row)
    local mc = sel and C.goldBright or (it and it.markColor) or MarkColor(it and it.status)
    if mc then SetCol(self.mark, mc) self.mark:Show() else self.mark:Hide() end
    SetCol(self.lineB, sel and C.gold or C.divider)
    if sel then self.lineT:Show() else self.lineT:Hide() end
    TextColor(self.title, (it and it.titleColor) or (it and it.quality and Kit.QualityColor(it.quality)) or (sel and C.hero or C.title))
    PlainBg(self, sel or st == "hover")
  end)
  return r
end

-- note row 28: one line of text (item.text, item.color); item.warn: red ground and edge with a "!" (WarnRow);
-- item.right: a short text on the right (a link word "show")
function Kit.NoteRow(parent)
  local r = RowBase(parent, S.sub, C.row)
  r.mark:Hide()
  r.bang = Text(r, "group", C.red, "CENTER")
  r.bang:SetPoint("LEFT", S.pad, 0)
  r.bang:SetText("!")
  r.text = Text(r, "sub", C.muted)
  r.right = Text(r, "sub", C.txGold, "RIGHT")
  r.right:SetPoint("RIGHT", -S.pad, 0)
  r.bd = Border(r, C.redBd)
  function r:SetItem(it)
    self.item = it
    self.text:SetText(it.text or "")
    self.right:SetText(it.right or "")
    if it.warn then
      self.bang:Show() self.bd:SetColor(C.redBd)
      TextColor(self.text, it.color or C.red)
    else
      self.bang:Hide() self.bd:SetColor(C.redBd, 0)
      TextColor(self.text, it.color or C.muted)
    end
    self._tipFn = it.tooltipFn
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    local x = (self.item and self.item.warn) and S.pad + 16 or S.pad
    self.text:ClearAllPoints()
    self.text:SetPoint("LEFT", x, 0)
    local rw = self.right:GetText() ~= "" and min(TextW(self.right), 120) + S.gap or 0
    Kit.Fit(self.right, 120)
    Kit.Fit(self.text, max(20, w - x - S.pad - rw))
  end
  r._cutTexts = { r.text }
  Stateful(r, function(self, st)
    local it = self.item
    local warn = it and it.warn
    SetCol(self.bg, warn and C.redBg or (st == "hover" and it and (it.onClick or it.clickable)) and C.rowHover or C.row)
    SetCol(self.lineB, warn and C.redBd or C.divider)
    PlainBg(self, warn or st == "hover")
  end)
  return r
end

-- the red warning line on its own (outside a list): w:SetText(text), w:Layout(width)
function Kit.WarnRow(parent)
  local r = Kit.NoteRow(parent)
  r:SetItem({ warn = true, text = "" })
  function r:SetText(t) self:SetItem({ warn = true, text = t, tooltipFn = self.item and self.item.tooltipFn }) end
  return r
end

KIND_H.trow, KIND_H.note = S.row, S.sub
ROW_MAKER.trow, ROW_MAKER.note = Kit.ItemRow, Kit.NoteRow

-- the head of a table: titles over the columns, a click on a sortable one calls onSort(key)
local function ItemTableHead(parent, onSort)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(24)
  Fill(h, C.group)
  h.line = Tex(h, "ARTWORK", C.divider)
  h.line:SetPoint("BOTTOMLEFT") h.line:SetPoint("BOTTOMRIGHT") h.line:SetHeight(1)
  h.btns = {}
  local function Btn(i)
    local b = h.btns[i]
    if b then return b end
    b = CreateFrame("Button", nil, h)
    b:SetHeight(24)
    b.text = Text(b, "badge", C.muted, "RIGHT")
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(9, 8)
    Call(b.arrow, "SetTexture", "Interface\\Buttons\\UI-SortArrow")
    b.arrow:Hide()
    Clickable(b, function(self) if self.col and self.col.sort then Safe("table sort", onSort, self.col.key) end end)
    Stateful(b, function(self, st)
      local on = self.col and h.sortKey == self.col.key
      TextColor(self.text, (on or (st == "hover" and self.col and self.col.sort)) and C.txGold or (self.col and self.col.color) or C.muted)
    end)
    h.btns[i] = b
    return b
  end
  function h:Layout(w, cols)
    self._w, self.cols = w, cols or self.cols or {}
    self:SetWidth(w)
    local vis = VisibleCols(self.cols, w)
    local rx = S.pad
    local n = 0
    for i = #vis, 1, -1 do
      local c = vis[i]
      n = n + 1
      local b = Btn(n)
      b.col = c
      local cw = c.width or 80
      b:ClearAllPoints()
      b:SetPoint("RIGHT", self, "RIGHT", -rx, 0)
      b:SetWidth(cw)
      local on = self.sortKey == c.key
      b.text:SetText(Upper(c.title or ""))
      b.text:ClearAllPoints()
      b.text:SetPoint("RIGHT", on and -12 or 0, 0)
      Kit.Fit(b.text, cw - S.gap - (on and 12 or 0))
      b.arrow:ClearAllPoints()
      b.arrow:SetPoint("RIGHT", 0, 0)
      if on then
        b.arrow:Show()
        if self.sortAsc then Call(b.arrow, "SetTexCoord", 0, 0.5625, 1, 0) else Call(b.arrow, "SetTexCoord", 0, 0.5625, 0, 1) end
      else b.arrow:Hide() end
      Kit.Refresh(b)
      b:Show()
      rx = rx + cw
    end
    -- the title column
    n = n + 1
    local b = Btn(n)
    b.col = self.cols[1]
    b:ClearAllPoints()
    b:SetPoint("LEFT", self, "LEFT", S.markBar + 8, 0)
    b:SetWidth(max(20, w - rx - S.markBar - 8 - S.gap))
    b.text:SetJustifyH("LEFT")
    b.text:SetText(Upper(self.cols[1] and self.cols[1].title or ""))
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", 0, 0)
    Kit.Fit(b.text, b:GetWidth() or 100)
    b.arrow:Hide()
    Kit.Refresh(b)
    b:Show()
    for i = n + 1, #self.btns do self.btns[i]:Hide() end
  end
  return h
end

function Kit.Table(parent, opts)
  opts = opts or {}
  local t = CreateFrame("Frame", nil, parent)
  t.head = ItemTableHead(t, function(key) Safe("table sort", opts.onSort, key, t) end)
  t.head:SetPoint("TOPLEFT", 0, 0)
  t.list = Kit.List(t, { kinds = opts.kinds, onClick = opts.onClick, onToggle = opts.onToggle, zebra = opts.zebra })
  t.list:SetPoint("TOPLEFT", 0, -24)
  t.list.columns = opts.columns or {}
  if opts.empty then t.list:SetEmpty(opts.empty) end
  function t:SetColumns(cols)
    self.list.columns = cols or {}
    self.head:Layout(self._w or 0, self.list.columns)
    self.list:Draw()
  end
  function t:SetSort(key, asc)
    self.head.sortKey, self.head.sortAsc = key, asc and true or nil
    self.head:Layout(self._w or 0, self.list.columns)
  end
  function t:SetItems(items, reset)
    for _, it in ipairs(items or {}) do if it.kind == nil then it.kind = "trow" end end
    self.list:SetItems(items, reset)
  end
  function t:SetEmpty(text) self.list:SetEmpty(text) end
  function t:Layout(w, h)
    self._w, self._h = w, h
    self:SetSize(w, h)
    self.head:Layout(w, self.list.columns)
    self.list:Resize(w, max(1, h - 24))
  end
  return t
end

-- MoneyBox: Kit.EditBox for money, typed as "12g 50s" or "12,5" (gold); shown as "12g 50s" when not typing.
-- m:GetValue() copper (nil when unreadable), m:SetValue(copper); opts.onChange(copper, box), opts.placeholder
function Kit.MoneyBox(parent, opts)
  opts = opts or {}
  local m
  m = Kit.EditBox(parent, { placeholder = opts.placeholder, maxLetters = 24, selectAll = opts.selectAll ~= false,
    onChange = function(t) Safe("money", opts.onChange, Kit.ParseMoney(t), m) end,
    onEnter = function() Safe("money enter", opts.onEnter, Kit.ParseMoney(m:GetText()), m) end })
  function m:GetValue() return Kit.ParseMoney(self:GetText()) end
  function m:SetValue(c)
    c = tonumber(c)
    self:SetText(c and Kit.Money(c, { letters = true, full = true }) or "")
    local cb = self:GetScript("OnTextChanged")
    if cb then cb(self, false) end
  end
  local lost = m:GetScript("OnEditFocusLost")
  m:SetScript("OnEditFocusLost", function(self, ...)
    if lost then lost(self, ...) end
    local c = Kit.ParseMoney(self:GetText())
    if c then self:SetValue(c) end
  end)
  return m
end

-- (minor 20, 05.11.2026, Daniel: "felder für g / s / c nicht alles in einem") CoinBox: money in three number boxes, gold,
-- silver, copper, each with its coin symbol; silver and copper at most 99. The same calls as MoneyBox: m:GetValue() copper
-- (nil when all three are empty), m:SetValue(copper), m:GetText() ("1g 2s 3c", for Kit.ParseMoney), m:SetNext(other),
-- m:SetFocus(), m:Layout(w) (gold takes what silver and copper leave); opts.onChange(copper, m), opts.onEnter(copper, m)
function Kit.CoinBox(parent, opts)
  opts = opts or {}
  local m = CreateFrame("Frame", nil, parent)
  m:SetHeight(S.button)
  m.boxes, m.coins = {}, {}
  local function changed() Safe("coins", opts.onChange, m:GetValue(), m) end
  local function enter() Safe("coins enter", opts.onEnter, m:GetValue(), m) end
  for i = 1, 3 do
    local b = Kit.EditBox(m, { numeric = true, maxLetters = i == 1 and 7 or 2, min = 0, max = i > 1 and 99 or nil,
      onChange = changed, onEnter = enter })
    m.boxes[i] = b
    m.coins[i] = m:CreateTexture(nil, "ARTWORK")
    m.coins[i]:SetTexture(Kit.COINS[i])
    m.coins[i]:SetSize(12, 12)
  end
  m.boxes[1]:SetNext(m.boxes[2]) m.boxes[2]:SetNext(m.boxes[3])
  function m:GetValue()
    local any, total = false, 0
    for i, b in ipairs(self.boxes) do
      local n = tonumber(b:GetText() or "")
      if n then any = true total = total + n * (i == 1 and 10000 or i == 2 and 100 or 1) end
    end
    return any and total or nil
  end
  function m:GetText()
    local c = self:GetValue()
    return c and ("%dg %ds %dc"):format(floor(c / 10000), floor(c / 100) % 100, c % 100) or ""
  end
  function m:SetValue(c)
    c = tonumber(c)
    if not c then for _, b in ipairs(self.boxes) do b:SetValue("") end return end
    c = floor(c + 0.5)
    self.boxes[1]:SetValue(floor(c / 10000)) self.boxes[2]:SetValue(floor(c / 100) % 100) self.boxes[3]:SetValue(c % 100)
  end
  function m:SetText(t) self:SetValue(Kit.ParseMoney(t)) end
  function m:SetNext(other) self.boxes[3]:SetNext(other) end
  function m:SetFocus() self.boxes[1]:SetFocus() end
  function m:ClearFocus() for _, b in ipairs(self.boxes) do b:ClearFocus() end end
  function m:Layout(w)
    w = tonumber(w) or 140
    self._w = w
    self:SetWidth(w)
    local coin, gap, small = 12, 2, 26
    local gold = max(24, w - 2 * small - 3 * (coin + gap) - 2 * S.gap)
    local x = 0
    for i, b in ipairs(self.boxes) do
      local bw = i == 1 and gold or small
      b:ClearAllPoints() b:SetPoint("LEFT", self, "LEFT", x, 0) b:Layout(bw)
      self.coins[i]:ClearAllPoints() self.coins[i]:SetPoint("LEFT", self, "LEFT", x + bw + gap, 0)
      x = x + bw + gap + coin + S.gap
    end
  end
  m:Layout(opts.width or 140)
  if opts.value ~= nil then m:SetValue(opts.value) end
  return m
end

---------------------------------------------------------------------------
-- ActionBar 44 under a list (in place of the focus card when the window is narrow): item symbol, title and a second
-- line, buttons on the right. a:SetData({ icon, quality, itemID, title, titleColor, sub, subColor });
-- a:SetActions({ { text, onClick, kind, disabled, tooltip = { title, lines } } }) (like Kit.Detail); a:Layout(width)
---------------------------------------------------------------------------
function Kit.ActionBar(parent)
  local a = CreateFrame("Frame", nil, parent)
  a:SetHeight(S.head)
  Fill(a, C.card)
  a.line = Tex(a, "ARTWORK", C.gold)
  a.line:SetPoint("TOPLEFT") a.line:SetPoint("TOPRIGHT") a.line:SetHeight(1)
  a.icon = Kit.ItemIcon(a, S.iconMid)
  a.icon:SetPoint("LEFT", S.pad, 0)
  a.title = Text(a, "row", C.hero)
  a.sub = Text(a, "sub", C.muted)
  a.actions = {}
  function a:SetData(d)
    d = d or {}
    self.data = d
    if d.icon or d.itemID then
      self.icon:SetItem(d.itemID, nil, d.quality)
      if d.icon then Call(self.icon.tex, "SetTexture", d.icon) end
      self.icon:Show()
    else self.icon:Hide() end
    self.title:SetText(d.title or "")
    TextColor(self.title, d.titleColor or (d.quality and Kit.QualityColor(d.quality)) or C.hero)
    self.sub:SetText(d.sub or "")
    TextColor(self.sub, d.subColor or C.muted)
    self:Layout(self._w or self:GetWidth())
  end
  function a:SetActions(list)
    for _, b in ipairs(self.actions) do b:Hide() end
    for i, x in ipairs(list or {}) do
      local b = self.actions[i]
      if not b then b = Kit.Button(self, "", {}) self.actions[i] = b end
      b:SetText(x.text or "")
      b._onClick = x.onClick
      if x.tooltip then b:SetTooltip(x.tooltip[1], x.tooltip[2], x.tooltip[3]) else b._tip = nil end
      b:SetKind(x.kind or "secondary")
      b:SetDisabled(x.disabled)
      b:Show()
    end
    self.nActions = #(list or {})
    self:Layout(self._w or self:GetWidth())
  end
  -- (minor 23) a:Input(opts): one Kit.EditBox left of the buttons (an amount to buy, a count to craft), made on the
  -- first call (opts as Kit.EditBox, opts.width 60); a.input:Show() / :Hide() / :SetShown(on), then a:Layout(). It only
  -- takes room while shown and while the bar has a button
  function a:Input(opts)
    if not self.input then
      opts = opts or {}
      self.inputW = tonumber(opts.width) or 60
      self.input = Kit.EditBox(self, opts)
      self.input:Hide()
    end
    return self.input
  end
  function a:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    self:SetWidth(w)
    local rx = S.pad
    for i = self.nActions or 0, 1, -1 do
      local b = self.actions[i]
      local bw = min(b.natural or 80, max(60, floor(w * 0.3)))
      b:ClearAllPoints()
      b:SetPoint("RIGHT", self, "RIGHT", -rx, 0)
      b:Layout(bw)
      rx = rx + bw + S.unit
    end
    local inp = self.input
    if inp and inp:IsShown() and (self.nActions or 0) > 0 then
      inp:ClearAllPoints()
      inp:SetPoint("RIGHT", self, "RIGHT", -(rx - S.unit + S.gap), 0)
      inp:Layout(self.inputW)
      rx = rx - S.unit + S.gap + self.inputW + S.unit
    end
    local x = S.pad + (self.icon:IsShown() and S.iconMid + S.gap or 0)
    self.title:ClearAllPoints() self.sub:ClearAllPoints()
    if self.sub:GetText() ~= "" then
      self.title:SetPoint("TOPLEFT", x, -6)
      self.sub:SetPoint("TOPLEFT", x, -23)
    else
      self.title:SetPoint("LEFT", x, 0)
    end
    local room = max(20, w - x - rx - S.gap)
    Kit.Fit(self.title, room)
    Kit.Fit(self.sub, room)
  end
  a._cutTexts = { a.title, a.sub }
  Call(a, "EnableMouse", true)
  a:SetScript("OnEnter", function(self) CutTip(self, nil, nil, self._cutTexts) end)
  a:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return a
end

---------------------------------------------------------------------------
-- (minor 23) PlaceRight: a row of controls from the right edge of a frame, as over a list (buttons, dropdowns, a number
-- box). list = { { frame, width, show }, ... }, the first stands at the edge; show == false (or nil frame) hides the
-- control and it takes no room. opts.x (S.pad), opts.y (-6), opts.gap (S.gap), opts.point ("TOPRIGHT").
-- Returns the width taken from the edge, the room left of the row starts there.
---------------------------------------------------------------------------
function Kit.PlaceRight(parent, list, opts)
  opts = opts or {}
  local rx, y, gap, point = tonumber(opts.x) or S.pad, tonumber(opts.y) or -6, tonumber(opts.gap) or S.gap, opts.point or "TOPRIGHT"
  for _, e in ipairs(list or {}) do
    local f, w = e[1], tonumber(e[2]) or 80
    if f then
      if e[3] == false then Call(f, "Hide")
      else
        Call(f, "Show")
        f:ClearAllPoints()
        f:SetPoint(point, parent, point, -rx, y)
        if f.Layout then f:Layout(w) else Call(f, "SetWidth", w) end
        rx = rx + w + gap
      end
    end
  end
  return rx
end

---------------------------------------------------------------------------
-- (minor 23) SecureButton: a protected action button (SecureActionButtonTemplate: a macro, a spell, an item on click) in
-- the look of a primary Kit.Button. Kit.Button itself is no secure template, so an addon styled its own. The caller sets
-- the attributes and its own scripts (PreClick, OnEnter); it must hang on UIParent or another unprotected frame it only
-- anchors to (a protected child makes its parent protected) and is left alone in combat.
-- b.text, b:SetLabel(text) (cut to the width), opts.width (200), opts.height (24), opts.clicks (default: key down or up
-- as the client's action buttons)
---------------------------------------------------------------------------
function Kit.SecureButton(name, parent, opts)
  opts = opts or {}
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:SetHeight(tonumber(opts.height) or 24)
  b:SetWidth(tonumber(opts.width) or 200)
  local down = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown")
  Call(b, "RegisterForClicks", opts.clicks or (down and "AnyDown" or "AnyUp"))
  Fill(b, C.primary)
  b.bd = Border(b, C.gold)
  b.text = Text(b, "row", C.txGold, "CENTER")
  b.text:SetPoint("CENTER", 0, 0)
  function b:SetLabel(text)
    self.text:SetText(text or "")
    Kit.Fit(self.text, (self:GetWidth() or 200) - 12)
  end
  if opts.text then b:SetLabel(opts.text) end
  return b
end

---------------------------------------------------------------------------
-- (minor 25, 12.11.2026, Questdon's item buttons in the quest list) ItemButton: a protected button that uses an item on
-- click (SecureActionButtonTemplate), as a symbol: the item's icon on a dark flat backing with a 1 px line, the count
-- bottom right, the cooldown over it, a small watch top right while a change waits for the end of a fight.
-- Same rules as SecureButton: it hangs on UIParent (never on a frame that moves in combat, and never anchored to one:
-- a frame a protected frame is anchored to may not move in combat either), and its attributes, place, size and
-- Show/Hide only change out of combat. What may change in combat: icon, count, cooldown, watch, dimming.
-- opts.size (36), opts.clicks, opts.frame = false (no backing: the caller draws its own).
-- b.icon, b.count, b.cooldown, b.wait, b.bg, b.bd, b.itemID
-- b:SetItem(itemID) -> true when set (false in combat: nothing changed); nil takes the item off (the caller hides it)
-- b:SetCount(n) (shown from 2 on), b:UpdateCooldown(), b:SetWaiting(on), b:SetFar(on) (grey and half clear)
---------------------------------------------------------------------------
local function InFight() return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false end
function Kit.ItemButton(name, parent, opts)
  opts = opts or {}
  local size = tonumber(opts.size) or 36
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  b:SetSize(size, size)
  -- both, as the client's own action buttons: the template itself takes the one the player's key-down setting asks for
  if opts.clicks then Call(b, "RegisterForClicks", opts.clicks) else Call(b, "RegisterForClicks", "AnyUp", "AnyDown") end
  if opts.frame ~= false then
    b.bg = Tex(b, "BACKGROUND", C.input)
    b.bg:SetPoint("TOPLEFT", -1, 1) b.bg:SetPoint("BOTTOMRIGHT", 1, -1)
    b.bd = Border(b, C.goldMuted, -1)
  end
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  Call(b.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
  b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.count:SetPoint("BOTTOMRIGHT", -2, 2)
  b.wait = b:CreateTexture(nil, "OVERLAY")
  local ws = max(10, floor(size * 0.4 + 0.5))
  b.wait:SetSize(ws, ws)
  b.wait:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
  b.wait:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
  b.wait:Hide()
  b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cooldown:SetAllPoints()
  Call(b, "SetHighlightTexture", "Interface\\Buttons\\ButtonHilight-Square", "ADD")
  Call(b, "SetPushedTexture", "Interface\\Buttons\\UI-Quickslot-Depress")
  function b:SetItem(itemID)
    if InFight() then return false end
    itemID = tonumber(itemID)
    self.itemID = itemID
    if not itemID then
      self:SetAttribute("type", nil)
      self:SetAttribute("item", nil)
      return true
    end
    self:SetAttribute("type", "item")
    self:SetAttribute("item", "item:" .. itemID)
    local icon
    if type(C_Item) == "table" and type(C_Item.GetItemIconByID) == "function" then
      local ok, tex = pcall(C_Item.GetItemIconByID, itemID)
      icon = ok and tex or nil
    end
    self.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    self.far = nil
    Call(self.icon, "SetDesaturated", false)
    self.icon:SetAlpha(1)
    self:UpdateCooldown()
    return true
  end
  function b:SetCount(n)
    n = tonumber(n)
    self.count:SetText(n and n > 1 and n or "")
  end
  function b:UpdateCooldown()
    if not self.itemID then return end
    local get = type(C_Container) == "table" and C_Container.GetItemCooldown
    if type(get) ~= "function" then return end
    local ok, start, duration = pcall(get, self.itemID)
    -- SetCooldown takes secret values: no arithmetic here
    if ok and start then self.cooldown:SetCooldown(start, duration) end
  end
  function b:SetWaiting(on)
    on = on and true or false
    if self.waiting == on then return end
    self.waiting = on
    if on then self.wait:Show() else self.wait:Hide() end
  end
  function b:SetFar(far)
    far = far and true or false
    if self.far == far then return end
    self.far = far
    Call(self.icon, "SetDesaturated", far)
    self.icon:SetAlpha(far and 0.55 or 1)
  end
  return b
end

---------------------------------------------------------------------------
-- Box: a framed part of a page with a gold title line (28): b.head (put controls there, right side), b.body below,
-- b:SetTitle(text), b:SetRight(text) (a quiet word right in the head), b:Layout(w, h) -> body width, body height;
-- opts.onLayout(b, bodyW, bodyH)
---------------------------------------------------------------------------
function Kit.Box(parent, title, opts)
  opts = opts or {}
  local b = CreateFrame("Frame", nil, parent)
  b.bg = Fill(b, C.card)
  b.bd = Border(b, C.divider)
  b.head = CreateFrame("Frame", nil, b)
  b.head:SetPoint("TOPLEFT", 1, -1) b.head:SetPoint("TOPRIGHT", -1, -1)
  b.head:SetHeight(S.sub)
  b.headLine = Tex(b.head, "ARTWORK", C.divider)
  b.headLine:SetPoint("BOTTOMLEFT") b.headLine:SetPoint("BOTTOMRIGHT") b.headLine:SetHeight(1)
  b.title = Text(b.head, "group", C.txGold)
  b.title:SetPoint("LEFT", S.pad, 0)
  b.right = Text(b.head, "sub", C.muted, "RIGHT")
  b.right:SetPoint("RIGHT", -S.pad, 0)
  b.body = CreateFrame("Frame", nil, b)
  b.body:SetPoint("TOPLEFT", 1, -S.sub - 1)
  function b:SetTitle(t) self.title:SetText(Upper(t or "")) end
  function b:SetRight(t) self.right:SetText(t or "") end
  b.headRoom = 0 -- room the caller keeps for its own controls in the head (right)
  function b:Layout(w, h)
    w, h = tonumber(w) or 0, tonumber(h) or 0
    self:SetSize(w, h)
    local rw = self.right:GetText() ~= "" and min(TextW(self.right), floor(w * 0.4)) or 0
    self.right:ClearAllPoints()
    self.right:SetPoint("RIGHT", -S.pad - self.headRoom, 0)
    Kit.Fit(self.right, max(1, rw))
    Kit.Fit(self.title, max(20, w - 2 * S.pad - self.headRoom - (rw > 0 and rw + S.gap or 0)))
    local bw, bh = max(1, w - 2), max(1, h - S.sub - 2)
    self.body:SetSize(bw, bh)
    Safe("box layout", opts.onLayout, self, bw, bh)
    return bw, bh
  end
  b._cutTexts = { b.title, b.right }
  b:SetTitle(title)
  return b
end

---------------------------------------------------------------------------
-- LineChart: 1 to 3 lines over x (time), a grid of 3 lines, the y axis with 3 values (opts.formatY, e.g. Kit.Money),
-- x from the first to the last value (opts.formatX); the mouse shows the values at its place; opts.empty: a text when
-- there are fewer than 2 points.
--   c:SetSeries({ { points = { { x, y }, ... }, color = rgb or Kit.C key, label = "Gold" }, ... }); c:Layout(w, h)
-- Lines with CreateLine (modern clients and Era 1.15); without it bars of the first series.
---------------------------------------------------------------------------
function Kit.LineChart(parent, opts)
  opts = opts or {}
  local c = CreateFrame("Frame", nil, parent)
  c.plot = CreateFrame("Frame", nil, c)
  c.grid, c.ylab, c.lines, c.bars = {}, {}, {}, {}
  for i = 1, 3 do
    c.grid[i] = Tex(c.plot, "BORDER", C.divider)
    c.grid[i]:SetHeight(1)
    c.ylab[i] = Text(c, "mono", C.quiet, "RIGHT")
  end
  c.xl = Text(c, "mono", C.quiet, "LEFT")
  c.xr = Text(c, "mono", C.quiet, "RIGHT")
  c.empty = Text(c, "sub", C.quiet, "CENTER")
  c.empty:SetPoint("CENTER", c.plot, "CENTER", 0, 0)
  c.legend = Text(c, "mono", C.quiet, "LEFT") -- (minor 24)
  c.legend:Hide()
  c.dot = Tex(c.plot, "OVERLAY", C.hero)
  c.dot:SetSize(5, 5)
  c.dot:Hide()
  c.series = {}
  function c:SetSeries(series) self.series = series or {} self:Draw() end
  function c:Layout(w, h)
    self._w, self._h = tonumber(w) or 0, tonumber(h) or 0
    self:SetSize(max(1, self._w), max(1, self._h))
    self:Draw()
  end
  local function Seg(n, x1, y1, x2, y2, col)
    local l = c.lines[n]
    if not l then
      if not c.plot.CreateLine then return false end
      local ok, made = pcall(c.plot.CreateLine, c.plot, nil, "ARTWORK")
      if not ok or type(made) ~= "table" then c.noLines = true return false end
      l = made
      Call(l, "SetThickness", 2)
      c.lines[n] = l
    end
    col = Col(col)
    Call(l, "SetColorTexture", col[1], col[2], col[3], 1)
    Call(l, "SetStartPoint", "BOTTOMLEFT", c.plot, x1, y1)
    Call(l, "SetEndPoint", "BOTTOMLEFT", c.plot, x2, y2)
    l:Show()
    return true
  end
  function c:Draw()
    local w, h = self._w or 0, self._h or 0
    local left, bottom = 52, 16
    local pw, ph = max(10, w - left - 4), max(10, h - bottom - 6)
    self.pw, self.ph, self.left, self.bottom = pw, ph, left, bottom
    self.plot:ClearAllPoints()
    self.plot:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", left, bottom)
    self.plot:SetSize(pw, ph)
    for _, l in ipairs(self.lines) do l:Hide() end
    for _, b in ipairs(self.bars) do b:Hide() end
    -- range over all series
    local x0, x1, lo, hi = math.huge, -math.huge, math.huge, -math.huge
    local n = 0
    for _, s in ipairs(self.series) do
      for _, p in ipairs(s.points or {}) do
        n = n + 1
        x0, x1 = min(x0, p[1]), max(x1, p[1])
        lo, hi = min(lo, p[2]), max(hi, p[2])
      end
    end
    local enough = n >= 2 and x1 > x0
    for i = 1, 3 do
      self.grid[i]:ClearAllPoints()
      self.grid[i]:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", 0, floor(ph * (i - 1) / 2))
      self.grid[i]:SetWidth(pw)
    end
    if not enough then
      for i = 1, 3 do self.ylab[i]:SetText("") end
      self.xl:SetText("") self.xr:SetText("")
      self.empty:SetText(opts.empty or "")
      Kit.Fit(self.empty, max(20, pw - 16))
      self.empty:Show()
      self.range = nil
      self.clipped = nil
      self.legend:Hide()
      return
    end
    self.empty:Hide()
    -- (minor 24) one peak far above the rest: the axis ends a little over the 90 % value, the peak is cut at the top
    self.clipped = nil
    local cp = tonumber(opts.clipPeak)
    if cp and cp > 1 and n >= 10 then
      local ys = {}
      for _, s in ipairs(self.series) do for _, p in ipairs(s.points or {}) do ys[#ys + 1] = p[2] end end
      table.sort(ys)
      local q = ys[max(1, floor(#ys * 0.9))]
      if q > lo and hi > lo + (q - lo) * cp then self.clipped = hi hi = lo + (q - lo) * 1.15 end
    end
    if opts.legend then
      local bits = {}
      for si, s in ipairs(self.series) do
        if s.label then bits[#bits + 1] = "|c" .. Hexa(s.color or (si == 1 and C.goldBright or C.blue)) .. s.label .. "|r" end
      end
      if self.clipped and opts.clipText then bits[#bits + 1] = tostring(opts.clipText(self.clipped) or "") end
      self.legend:SetText(table.concat(bits, "   "))
      self.legend:ClearAllPoints()
      self.legend:SetPoint("TOPLEFT", self.plot, "TOPLEFT", 6, -2)
      Kit.Fit(self.legend, max(20, pw - 12))
      self.legend:Show()
    else self.legend:Hide() end
    if hi - lo <= 0 then lo, hi = lo - 1, hi + 1 end
    local pad = (hi - lo) * 0.08
    lo, hi = lo - pad, hi + pad
    if lo < 0 and (opts.floorZero ~= false) and lo + pad >= 0 then lo = 0 end
    self.range = { x0, x1, lo, hi }
    local fy = opts.formatY or function(v) return tostring(floor(v + 0.5)) end
    for i = 1, 3 do
      local v = lo + (hi - lo) * (i - 1) / 2
      self.ylab[i]:SetText(fy(v))
      self.ylab[i]:ClearAllPoints()
      self.ylab[i]:SetPoint("RIGHT", self.plot, "BOTTOMLEFT", -4, floor(ph * (i - 1) / 2))
      Kit.Fit(self.ylab[i], left - 6)
    end
    local fx = opts.formatX or tostring
    self.xl:SetText(fx(x0)) self.xr:SetText(fx(x1))
    self.xl:ClearAllPoints() self.xl:SetPoint("TOPLEFT", self.plot, "BOTTOMLEFT", 0, -3)
    self.xr:ClearAllPoints() self.xr:SetPoint("TOPRIGHT", self.plot, "BOTTOMRIGHT", 0, -3)
    Kit.Fit(self.xl, floor(pw / 2) - 4) Kit.Fit(self.xr, floor(pw / 2) - 4)
    local function X(x) return (x - x0) / (x1 - x0) * pw end
    local function Y(y) return min(ph, (y - lo) / (hi - lo) * ph) end
    local k, lines = 0, not self.noLines and self.plot.CreateLine ~= nil
    for si, s in ipairs(self.series) do
      local pts = s.points or {}
      for i = 2, #pts do
        if lines then
          k = k + 1
          lines = Seg(k, X(pts[i - 1][1]), Y(pts[i - 1][2]), X(pts[i][1]), Y(pts[i][2]), s.color or (si == 1 and C.goldBright or C.blue))
        end
      end
    end
    if not lines then
      local pts = (self.series[1] or {}).points or {}
      local bw = max(2, pw / max(1, #pts) - 1)
      for i, p in ipairs(pts) do
        local b = self.bars[i]
        if not b then b = Tex(self.plot, "ARTWORK", C.gold) self.bars[i] = b end
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self.plot, "BOTTOMLEFT", max(0, X(p[1]) - bw), 0)
        b:SetSize(bw, max(1, Y(p[2])))
        b:Show()
      end
    end
  end
  -- the mouse: values of every series at the nearest point
  function c:ShowAt(px)
    local r = self.range
    if not r then return end
    local x = r[1] + (r[2] - r[1]) * Clamp(px / max(1, self.pw), 0, 1)
    local lines, title = {}, nil
    local fy = opts.formatY or function(v) return tostring(floor(v + 0.5)) end
    for si, s in ipairs(self.series) do
      local best
      for _, p in ipairs(s.points or {}) do if not best or abs(p[1] - x) < abs(best[1] - x) then best = p end end
      if best then
        if si == 1 then
          title = (opts.formatX or tostring)(best[1])
          self.dot:ClearAllPoints()
          self.dot:SetPoint("CENTER", self.plot, "BOTTOMLEFT", (best[1] - r[1]) / (r[2] - r[1]) * self.pw, min(self.ph, (best[2] - r[3]) / (r[4] - r[3]) * self.ph))
          self.dot:Show()
        end
        lines[#lines + 1] = { s.label or ("#" .. si), fy(best[2]), s.color or (si == 1 and C.goldBright or C.blue) }
      end
    end
    if title then Kit.Tooltip(self, title, lines) end
  end
  Call(c, "EnableMouse", true)
  c:SetScript("OnEnter", function(self)
    self:SetScript("OnUpdate", function(me)
      local ok, cx = pcall(GetCursorPosition)
      local okS, scale = Call(me, "GetEffectiveScale")
      local okL, l = Call(me.plot, "GetLeft")
      if ok and okL and tonumber(cx) and tonumber(l) then me:ShowAt(cx / ((okS and tonumber(scale)) or 1) - l) end
    end)
  end)
  c:SetScript("OnLeave", function(self) self:SetScript("OnUpdate", nil) self.dot:Hide() Kit.HideTooltip(self) end)
  return c
end

---------------------------------------------------------------------------
-- (minor 5, 02.11.2026, StyleKit 2 step 4 with Leveldon, docs/layout_2026-11-02/leveldon/BAUSTEINE.md) blocks that several
-- addons need: Hint (one line with a mark: warning, good, accent, text, red; Golddon's warn row is the kind "red"),
-- SegmentBar (a bar with ticks and a gold plan mark), Divider (a 20 px line: diamond, text, number; list kind "divider"),
-- DoneRow (a finished step, 22 px, a green tick; list kind "done"), Spark (small columns), FocusCard (the step or quest you
-- are on), Kit.Menu (a menu at the cursor), Radio, TextBox (several lines); ListRow item.badgeRight, item.radio, item.tags.
---------------------------------------------------------------------------
S.hint, S.divider, S.done = 18, 20, 22

-- a small diamond (a square turned by 45 degrees; a square where the client cannot turn textures)
local function Diamond(parent, size, color, layer)
  local t = Tex(parent, layer or "ARTWORK", color)
  t:SetSize(size, size)
  Call(t, "SetRotation", pi / 4)
  return t
end
Kit.Diamond = Diamond

-- the tick of something done: the symbol "check" of Style.ICONS (atlas or file), green
local function Tick(parent, size)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetSize(size or 12, size or 12)
  local St = StyleKit()
  if St and St.SetIcon then St.SetIcon(t, "check") else t:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready") end
  return t
end

---------------------------------------------------------------------------
-- Hint: one line, a mark on the left: kind "warn" (yellow "!"), "red" (red "!"), "good" (green diamond), "accent" (gold
-- diamond), "text" (muted diamond, muted text). h:SetHint(text, kind); h:Layout(width) -> S.hint. Cut, the whole text in
-- the tooltip.
---------------------------------------------------------------------------
local HINT_KIND = {
  warn = { "!", C.yellow, C.yellow }, red = { "!", C.red, C.red }, good = { nil, C.green, C.green },
  accent = { nil, C.goldBright, C.txGold }, text = { nil, C.quiet, C.muted },
}
Kit.HINT_KINDS = HINT_KIND
function Kit.Hint(parent)
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(S.hint)
  h.bang = Text(h, "row", C.yellow, "CENTER")
  h.bang:SetPoint("CENTER", h, "LEFT", 5, 0)
  h.bang:SetText("!")
  h.dia = Diamond(h, 5, C.goldBright)
  h.dia:SetPoint("CENTER", h, "LEFT", 5, 0)
  h.text = Text(h, "sub", C.body)
  h.text:SetPoint("LEFT", 14, 0)
  function h:SetHint(text, kind)
    local k = HINT_KIND[kind] or HINT_KIND.text
    self.kind = HINT_KIND[kind] and kind or "text"
    if k[1] then self.bang:Show() self.dia:Hide() TextColor(self.bang, k[2])
    else self.bang:Hide() self.dia:Show() SetCol(self.dia, k[2]) end
    self.text:SetText(text or "")
    TextColor(self.text, k[3])
    if self._w then Kit.Fit(self.text, max(10, self._w - 14)) end
  end
  function h:Layout(w)
    self._w = w
    self:SetWidth(w)
    Kit.Fit(self.text, max(10, w - 14))
    return S.hint
  end
  Call(h, "EnableMouse", true)
  h:SetScript("OnEnter", function(self) CutTip(self, nil, nil, { self.text }) end)
  h:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return h
end

---------------------------------------------------------------------------
-- SegmentBar: a 6 px bar with ticks (opts.ticks parts, default 4, 1: none) and a gold mark 12 px high (the plan's place).
-- b:SetValue(0..1), b:SetMark(0..1 or nil), b:SetColor(c), b:Layout(width)
---------------------------------------------------------------------------
function Kit.SegmentBar(parent, opts)
  opts = opts or {}
  local b = Kit.ProgressBar(parent, opts.color)
  b.parts = max(1, floor(tonumber(opts.ticks) or 4))
  b.ticks = {}
  for i = 1, b.parts - 1 do b.ticks[i] = Tex(b, "OVERLAY", C.window) b.ticks[i]:SetWidth(1) end
  b.markTex = Tex(b, "OVERLAY", C.hero)
  b.markTex:SetSize(2, 12)
  b.markTex:Hide()
  local bar = b.Layout
  function b:SetMark(v)
    self.mark = v ~= nil and Clamp(v, 0, 1) or nil
    local w = (self._w or self:GetWidth() or 0)
    if not self.mark or w <= 2 then self.markTex:Hide() return end
    self.markTex:ClearAllPoints()
    self.markTex:SetPoint("CENTER", self, "LEFT", floor(1 + (w - 2) * self.mark + 0.5), 0)
    self.markTex:Show()
  end
  function b:Layout(w)
    bar(self, w)
    for i, t in ipairs(self.ticks) do
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", self, "TOPLEFT", floor(w * i / self.parts + 0.5), -1)
      t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", floor(w * i / self.parts + 0.5), 1)
    end
    self:SetMark(self.mark)
  end
  return b
end

---------------------------------------------------------------------------
-- Divider 20: a gold diamond, a text in gold capitals, a quiet text on the right ("Plan 1:16"), a fine line below.
-- d:SetData(text, right) or as list kind "divider" (item.text, item.right); d:Layout(width)
---------------------------------------------------------------------------
function Kit.Divider(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetHeight(S.divider)
  d.bg = Fill(d, C.group)
  d.dia = Diamond(d, 6, C.goldBright)
  d.dia:SetPoint("CENTER", d, "LEFT", S.markBar + 10, 0)
  d.text = Text(d, "group", C.txGold)
  d.text:SetPoint("LEFT", S.markBar + 20, 0)
  d.right = Text(d, "sub", C.muted, "RIGHT")
  d.right:SetPoint("RIGHT", -S.pad, 0)
  d.line = Tex(d, "ARTWORK", C.divider)
  d.line:SetPoint("BOTTOMLEFT") d.line:SetPoint("BOTTOMRIGHT") d.line:SetHeight(1)
  function d:SetData(text, right)
    self.text:SetText(Upper(text or ""))
    self.right:SetText(right or "")
    if self._w then self:Layout(self._w) end
  end
  function d:SetItem(it) self.item = it self:SetData(it.text, it.right) end
  function d:Layout(w)
    self._w = w
    local rw = min(TextW(self.right), floor(w * 0.4))
    Kit.Fit(self.right, max(1, rw))
    Kit.Fit(self.text, max(10, w - (S.markBar + 20) - rw - S.pad - S.gap))
    if self.plain then self.bg:Hide() else self.bg:Show() end
    return S.divider
  end
  Call(d, "EnableMouse", true)
  d:SetScript("OnEnter", function(self) CutTip(self, nil, nil, { self.text, self.right }) end)
  d:SetScript("OnLeave", function(self) Kit.HideTooltip(self) end)
  return d
end

---------------------------------------------------------------------------
-- DoneRow 22: something finished, dimmed: a green tick, the text muted (list kind "done": item.title, item.tooltipFn)
---------------------------------------------------------------------------
function Kit.DoneRow(parent)
  local r = RowBase(parent, S.done, C.sub)
  r.mark:Hide()
  r.tick = Tick(r, 12)
  r.tick:SetPoint("LEFT", S.markBar + 14, 0)
  r.title = Text(r, "sub", C.quiet)
  r.title:SetPoint("LEFT", S.markBar + 36, 0)
  function r:SetItem(it)
    self.item = it
    self.title:SetText(it.title or "")
    self._tipFn = it.tooltipFn
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function r:Layout(w)
    self._w = w
    Kit.Fit(self.title, max(10, (w or 0) - (S.markBar + 36) - S.pad))
  end
  r._cutTexts = { r.title }
  Stateful(r, function(self, st)
    SetCol(self.bg, st == "hover" and C.rowHover or C.sub)
    PlainBg(self, st == "hover")
  end)
  return r
end

KIND_H.divider, KIND_H.done = S.divider, S.done
ROW_MAKER.divider, ROW_MAKER.done = Kit.Divider, Kit.DoneRow

---------------------------------------------------------------------------
-- Spark: small columns 4 px wide, 2 px apart, growing from the bottom (the last level-ups, takings per hour):
-- s:SetValues({ v, ... }, colors) (v >= 0; colors: a list of colours per column, else muted gold with the last bright);
-- height opts.h (default 12); s:Width() the width the columns need
---------------------------------------------------------------------------
function Kit.Spark(parent, opts)
  opts = opts or {}
  local s = CreateFrame("Frame", nil, parent)
  s.h = tonumber(opts.h) or 12
  s:SetSize(1, s.h)
  s.cols = {}
  s.n = 0
  function s:SetValues(values, colors)
    values = values or {}
    local top = 0
    for _, v in ipairs(values) do top = max(top, tonumber(v) or 0) end
    for i, v in ipairs(values) do
      local t = self.cols[i]
      if not t then t = Tex(self, "ARTWORK", C.gold) t:SetWidth(4) self.cols[i] = t end
      t:ClearAllPoints()
      t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * 6, 0)
      t:SetHeight(max(2, top > 0 and floor(self.h * (tonumber(v) or 0) / top + 0.5) or 2))
      SetCol(t, (colors and colors[i]) or (i == #values and C.goldBright or C.gold))
      t:Show()
    end
    for i = #values + 1, #self.cols do self.cols[i]:Hide() end
    self.n = #values
    self:SetWidth(max(1, self:Width()))
  end
  function s:Width() return self.n > 0 and self.n * 6 - 2 or 0 end
  return s
end

---------------------------------------------------------------------------
-- FocusCard: the step or quest you are on (Leveldon's current step; for Questdon's focus, Luredon's catch, Golddon's flip):
-- a framed symbol (24) on the left, a gold kicker line, the title, then lines that grow downwards: objectives (text, the
-- count on the right, a bar under an open one), the way (an arrow, the place and the distance), lines with a "+" mark and a
-- count (what else is to do here), hints (Kit.Hint). Every line one line high, cut, the whole text in the tooltip.
--   local c = Kit.FocusCard(parent, { side = 64 (room on the right for an own block: c.side, e.g. a compass) })
--   c:SetData({ icon, iconCoords, kicker, title, titleColor, objectives = { { text, have, need, done } }, way = text,
--     subs = { { text, right } }, hints = { { text, kind } }, onClick(card, button), tooltipFn(card) })
--   c:Layout(width) -> height; c:SetSide(on) shows or hides the side block; c:SetWay(text) only the way line (no layout);
--   c:SetPlain(on) without fill (the mark and the lines stay)
---------------------------------------------------------------------------
local FC = { pad = 8, kicker = 14, title = 18, obj = 18, bar = 8, line = 16, gap = 4 }
Kit.FOCUS = FC
function Kit.FocusCard(parent, opts)
  opts = opts or {}
  local c = CreateFrame("Button", nil, parent)
  c.opts = opts
  c.bg = Fill(c, C.card)
  c.markL = Tex(c, "ARTWORK", C.goldBright)
  c.markL:SetPoint("TOPLEFT") c.markL:SetPoint("BOTTOMLEFT") c.markL:SetWidth(S.markBar)
  c.lineB = Tex(c, "ARTWORK", C.gold)
  c.lineB:SetPoint("BOTTOMLEFT") c.lineB:SetPoint("BOTTOMRIGHT") c.lineB:SetHeight(1)
  c.iconBox = CreateFrame("Frame", nil, c)
  c.iconBox:SetSize(S.iconMid, S.iconMid)
  c.iconBox:SetPoint("TOPLEFT", S.markBar + FC.pad, -FC.pad)
  c.iconBox.bg = Fill(c.iconBox, C.input)
  c.iconBox.bd = Border(c.iconBox, C.goldMuted)
  c.icon = c.iconBox:CreateTexture(nil, "ARTWORK")
  c.icon:SetPoint("TOPLEFT", 1, -1) c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  c.kicker = Text(c, "mono", C.txGold)
  c.title = Text(c, "row", C.hero)
  c.wayDia = Tex(c, "ARTWORK", C.txGold)
  c.wayDia:SetSize(6, 8)
  c.way = Text(c, "sub", C.txGold)
  c.objs, c.subs, c.hints = {}, {}, {}
  c.sideW = tonumber(opts.side) or 0
  if c.sideW > 0 then
    c.side = CreateFrame("Frame", nil, c)
    c.side:SetSize(c.sideW, c.sideW + 14)
    c.side:SetPoint("TOPRIGHT", -FC.pad, -FC.pad)
  end
  c.sideOn = c.side ~= nil
  c.data = {}
  local function Obj(i)
    local o = c.objs[i]
    if not o then
      o = { text = Text(c, "sub", C.body), count = Text(c, "sub", C.muted, "RIGHT"), bar = Kit.ProgressBar(c, C.goldBright) }
      o.bar:SetHeight(4)
      c.objs[i] = o
    end
    return o
  end
  local function Sub(i)
    local s = c.subs[i]
    if not s then
      s = { box = CreateFrame("Frame", nil, c), text = Text(c, "sub", C.muted), right = Text(c, "sub", C.muted, "RIGHT") }
      s.box:SetSize(12, 12)
      Fill(s.box, C.input)
      Border(s.box, C.goldMuted)
      s.plus = Text(s.box, "mono", C.txGold, "CENTER")
      s.plus:SetPoint("CENTER", 0, 0)
      s.plus:SetText("+")
      c.subs[i] = s
    end
    return s
  end
  local function HintAt(i)
    local h = c.hints[i]
    if not h then h = Kit.Hint(c) c.hints[i] = h end
    return h
  end
  function c:SetData(d)
    self.data = d or {}
    d = self.data
    if d.icon then
      Call(self.icon, "SetTexture", d.icon)
      if d.iconCoords then Call(self.icon, "SetTexCoord", unpack(d.iconCoords)) else Call(self.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93) end
      self.iconBox:Show()
    elseif d.iconKind and StyleKit() then
      StyleKit().SetIcon(self.icon, d.iconKind)
      self.iconBox:Show()
    else
      self.iconBox:Hide()
    end
    self.kicker:SetText(Upper(d.kicker or ""))
    self.title:SetText(d.title or "")
    TextColor(self.title, d.titleColor or C.hero)
    self._tipFn = d.tooltipFn
    self._onClick = d.onClick
  end
  function c:SetSide(on) self.sideOn = (on and self.side) and true or false if self.side then if self.sideOn then self.side:Show() else self.side:Hide() end end end
  function c:SetWay(text)
    self.way:SetText(text or "")
    if self._wayW then Kit.Fit(self.way, self._wayW) end
  end
  -- (minor 15, 03.11.2026, Daniel: "das schwert links hat noch einen schwarzen kasten im hintergrund") plain: the symbol's
  -- box goes too (fill hidden, frame at 0), the symbol stays
  function c:SetPlain(on)
    self.plain = on and true or nil
    if self.plain then self.bg:Hide() self.iconBox.bg:Hide() self.iconBox.bd:SetColor(C.goldMuted, 0)
    else self.bg:Show() self.iconBox.bg:Show() self.iconBox.bd:SetColor(C.goldMuted) end
  end
  function c:Layout(w)
    self._w = w
    self:SetWidth(w)
    local d = self.data or {}
    local x = S.markBar + FC.pad + (self.iconBox:IsShown() and S.iconMid + S.gap or 0)
    local right = FC.pad + (self.sideOn and self.sideW + S.gap or 0)
    local tw = max(20, w - x - right)
    local y = FC.pad
    local cut = {}
    self.kicker:ClearAllPoints() self.kicker:SetPoint("TOPLEFT", x, -y)
    Kit.Fit(self.kicker, tw)
    if (self.kicker:GetText() or "") ~= "" then y = y + FC.kicker end
    self.title:ClearAllPoints() self.title:SetPoint("TOPLEFT", x, -y)
    Kit.Fit(self.title, tw)
    y = y + FC.title + 2
    cut[#cut + 1] = self.title
    -- objectives: the text and the count; an open one with more than one to get has a bar below
    local n = 0
    for i, ob in ipairs(d.objectives or {}) do
      n = i
      local o = Obj(i)
      local need, have = tonumber(ob.need), tonumber(ob.have)
      local done = ob.done and true or false
      o.count:SetText((need and need > 1) and (("%d/%d"):format(min(have or 0, need), need)) or "")
      local cw = min(TextW(o.count), 48)
      o.text:SetText(ob.text or "")
      TextColor(o.text, done and C.green or C.body)
      TextColor(o.count, done and C.green or C.muted)
      o.text:ClearAllPoints() o.text:SetPoint("TOPLEFT", x, -y)
      Kit.Fit(o.text, max(10, tw - (cw > 0 and cw + S.gap or 0)))
      o.count:ClearAllPoints() o.count:SetPoint("TOPRIGHT", self, "TOPRIGHT", -right, -y)
      Kit.Fit(o.count, max(1, cw))
      o.text:Show() o.count:Show()
      cut[#cut + 1] = o.text
      y = y + FC.obj - 2
      if need and need > 1 and not done then
        o.bar:ClearAllPoints() o.bar:SetPoint("TOPLEFT", x, -y)
        o.bar:Layout(tw)
        o.bar:SetValue((have or 0) / need)
        o.bar:Show()
        y = y + FC.bar
      else
        o.bar:Hide()
        y = y + 2
      end
    end
    for i = n + 1, #self.objs do local o = self.objs[i] o.text:Hide() o.count:Hide() o.bar:Hide() end
    -- the way: a gold arrow, place and distance
    local wayText = d.way
    if wayText and wayText ~= "" then
      y = y + 2
      self.wayDia:ClearAllPoints() self.wayDia:SetPoint("TOPLEFT", x, -(y + 4))
      self.way:ClearAllPoints() self.way:SetPoint("TOPLEFT", x + 10, -y)
      self._wayW = max(10, tw - 10)
      self.way:SetText(wayText)
      Kit.Fit(self.way, self._wayW)
      self.way:Show() self.wayDia:Show()
      cut[#cut + 1] = self.way
      y = y + FC.line
    else
      self._wayW = nil
      self.way:Hide() self.wayDia:Hide()
    end
    -- what else is to do here: a "+" box, the text, a count
    n = 0
    for i, sd in ipairs(d.subs or {}) do
      n = i
      local s = Sub(i)
      s.right:SetText(sd.right or "")
      local rw = min(TextW(s.right), 48)
      s.box:ClearAllPoints() s.box:SetPoint("TOPLEFT", x, -(y + 1))
      s.text:SetText(sd.text or "")
      s.text:ClearAllPoints() s.text:SetPoint("TOPLEFT", x + 18, -y)
      Kit.Fit(s.text, max(10, tw - 18 - (rw > 0 and rw + S.gap or 0)))
      s.right:ClearAllPoints() s.right:SetPoint("TOPRIGHT", self, "TOPRIGHT", -right, -y)
      Kit.Fit(s.right, max(1, rw))
      s.box:Show() s.text:Show() s.right:Show()
      cut[#cut + 1] = s.text
      y = y + FC.line
    end
    for i = n + 1, #self.subs do local s = self.subs[i] s.box:Hide() s.text:Hide() s.right:Hide() end
    -- hints
    n = 0
    for i, hd in ipairs(d.hints or {}) do
      n = i
      local h = HintAt(i)
      if i == 1 then y = y + 2 end
      h:SetHint(hd.text or hd[1], hd.kind or hd[2])
      h:ClearAllPoints() h:SetPoint("TOPLEFT", x, -y)
      h:Layout(tw)
      h:Show()
      y = y + FC.line
    end
    for i = n + 1, #self.hints do self.hints[i]:Hide() end
    y = y + FC.pad
    if self.sideOn then y = max(y, self.sideW + 14 + 2 * FC.pad) end
    y = max(y, S.iconMid + 2 * FC.pad)
    self._cutTexts = cut
    self:SetHeight(y)
    self.height = y
    return y
  end
  Clickable(c)
  Stateful(c, function(self, st)
    SetCol(self.bg, st == "hover" and C.rowSel or C.card)
    if self.plain then if st == "hover" then self.bg:Show() else self.bg:Hide() end end
  end)
  return c
end

---------------------------------------------------------------------------
-- Kit.Menu(title, items, anchor): a small menu (right click on a row): a title line, entries { text, onClick, disabled,
-- tooltip = { title, lines } }; a click on an entry runs it and closes the menu, a click anywhere else, Esc or
-- Kit.Menu.Hide() closes it. At the cursor unless anchor (a frame: below it). Returns the menu frame (DonKitContextMenu).
---------------------------------------------------------------------------
local ctx
local function ContextMenu()
  if ctx then return ctx end
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  Call(catcher, "SetFrameStrata", "FULLSCREEN_DIALOG")
  Call(catcher, "RegisterForClicks", "AnyUp")
  catcher:SetScript("OnClick", function() if ctx then ctx:Hide() end end)
  catcher:Hide()
  local m = CreateFrame("Frame", "DonKitContextMenu", UIParent)
  m.catcher = catcher
  Call(m, "SetFrameStrata", "FULLSCREEN_DIALOG")
  Call(m, "SetFrameLevel", (tonumber(select(2, Call(catcher, "GetFrameLevel"))) or 1) + 10)
  Call(m, "SetClampedToScreen", true)
  Call(m, "EnableMouse", true)
  Fill(m, C.card)
  Border(m, C.gold)
  m.head = Text(m, "sub", C.txGold)
  m.head:SetPoint("TOPLEFT", 10, -6)
  m.headLine = Tex(m, "ARTWORK", C.divider)
  m.headLine:SetHeight(1)
  m.rows = {}
  m:Hide()
  m:SetScript("OnHide", function(self) self.catcher:Hide() end)
  if type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = "DonKitContextMenu" end
  Kit.Scaled(m) -- (minor 13)
  ctx = m
  return m
end

Kit.Menu = setmetatable({}, { __call = function(self, title, items, anchor)
  local m = ContextMenu()
  items = items or {}
  local w = 180
  m.head:SetText(title or "")
  w = max(w, min(320, TextW(m.head) + 20))
  local headH = (title and title ~= "") and 24 or 0
  if headH > 0 then
    m.head:Show()
    m.headLine:ClearAllPoints()
    m.headLine:SetPoint("TOPLEFT", 1, -headH) m.headLine:SetPoint("TOPRIGHT", -1, -headH)
    m.headLine:Show()
  else
    m.head:Hide() m.headLine:Hide()
  end
  for i, it in ipairs(items) do
    local r = m.rows[i]
    if not r then
      r = CreateFrame("Button", nil, m)
      r:SetHeight(S.menuRow)
      r.bg = Fill(r, C.card)
      r.text = Text(r, "row", C.body)
      r.text:SetPoint("LEFT", 10, 0)
      Clickable(r, function(row)
        local item = row.item
        m:Hide()
        if item then Safe("menu", item.onClick, item) end
      end)
      Stateful(r, function(row, st) SetCol(row.bg, st == "hover" and C.rowHover or C.card) TextColor(row.text, st == "hover" and C.hero or C.body) end)
      r._cutTexts = { r.text }
      m.rows[i] = r
    end
    r.item = it
    r.text:SetText(it.text or "")
    w = max(w, min(320, TextW(r.text) + 24))
    r._tip = type(it.tooltip) == "table" and { it.tooltip[1], it.tooltip[2] } or nil
    r:SetDisabled(it.disabled)
    r:Show()
  end
  for i = #items + 1, #m.rows do m.rows[i]:Hide() end
  for i = 1, #items do
    local r = m.rows[i]
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 1, -(headH + 1 + (i - 1) * S.menuRow))
    r:SetWidth(w - 2)
    Kit.Fit(r.text, w - 20)
  end
  Kit.Fit(m.head, w - 20)
  m:SetSize(w, headH + #items * S.menuRow + 2)
  m:ClearAllPoints()
  if anchor then
    m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  else
    local x, y = 0, 0
    if type(GetCursorPosition) == "function" then x, y = GetCursorPosition() end
    -- (minor 13) the menu's own effective scale (Kit.scale on top of UIParent's)
    local okS, sc = Call(m, "GetEffectiveScale")
    sc = okS and tonumber(sc) or 1
    if not sc or sc <= 0 then sc = 1 end
    m:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (tonumber(x) or 0) / sc - 8, (tonumber(y) or 0) / sc + 8)
  end
  if GameTooltip and GameTooltip.Hide then pcall(GameTooltip.Hide, GameTooltip) end
  m.catcher:Show()
  m:Show()
  return m
end })
function Kit.Menu.Hide() if ctx then ctx:Hide() end end
function Kit.Menu.Frame() return ctx end

---------------------------------------------------------------------------
-- Radio: a point for exactly one choice (16 px, gold when picked). r:SetChecked(on), r:GetChecked(); opts.onClick(r)
---------------------------------------------------------------------------
function Kit.Radio(parent, opts)
  opts = opts or {}
  local r = CreateFrame("Button", nil, parent)
  r:SetSize(16, 16)
  r.ring = r:CreateTexture(nil, "ARTWORK")
  r.ring:SetAllPoints(r)
  r.ring:SetTexture("Interface\\Buttons\\UI-RadioButton")
  Call(r.ring, "SetTexCoord", 0, 0.25, 0, 1)
  Call(r.ring, "SetDesaturated", true)
  r.dot = r:CreateTexture(nil, "OVERLAY")
  r.dot:SetAllPoints(r)
  r.dot:SetTexture("Interface\\Buttons\\UI-RadioButton")
  Call(r.dot, "SetTexCoord", 0.25, 0.5, 0, 1)
  Call(r.dot, "SetDesaturated", true)
  function r:SetChecked(on) self.checked = on and true or false Refresh(self) end
  function r:GetChecked() return self.checked == true end
  Clickable(r, opts.onClick)
  Stateful(r, function(self, st)
    SetCol(self.ring, (self.checked or st == "hover") and C.goldBright or C.muted)
    SetCol(self.dot, C.goldBright)
    if self.checked then self.dot:Show() else self.dot:Hide() end
  end)
  r:SetChecked(opts.checked)
  return r
end

---------------------------------------------------------------------------
-- TextBox: an input of several lines in a frame, with a placeholder (a note, a remark). opts.placeholder, opts.maxLetters,
-- opts.onChange(text, box). t:GetText(), t:SetText(text), t:Layout(width, height), t.edit (the edit box); a click into the
-- frame puts the cursor there, Esc takes it out.
---------------------------------------------------------------------------
function Kit.TextBox(parent, opts)
  opts = opts or {}
  local t = CreateFrame("Frame", nil, parent)
  t.bg = Fill(t, C.input)
  t.bd = Border(t, C.mid)
  local e = CreateFrame("EditBox", nil, t)
  Call(e, "SetMultiLine", true)
  Call(e, "SetAutoFocus", false)
  Call(e, "SetMaxLetters", opts.maxLetters or 400)
  local fo = Kit.Font("row")
  if fo then Call(e, "SetFontObject", fo) end
  Call(e, "SetTextColor", C.body[1], C.body[2], C.body[3], 1)
  e:SetPoint("TOPLEFT", 8, -6)
  e:SetPoint("BOTTOMRIGHT", -8, 6)
  t.edit = e
  t.hint = Text(t, "row", C.quiet)
  t.hint:SetPoint("TOPLEFT", 8, -7)
  t.hint:SetText(opts.placeholder or "")
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnTextChanged", function(self, user)
    local s = self:GetText() or ""
    if s == "" then t.hint:Show() else t.hint:Hide() end
    if user then Safe("textbox", opts.onChange, s, t) end
  end)
  e:SetScript("OnEditFocusGained", function() t.bd:SetColor(C.gold) end)
  e:SetScript("OnEditFocusLost", function() t.bd:SetColor(C.mid) end)
  Call(t, "EnableMouse", true)
  t:SetScript("OnMouseDown", function() Call(e, "SetFocus") end)
  function t:GetText() return self.edit:GetText() or "" end
  function t:SetText(s)
    self.edit:SetText(s or "")
    if (s or "") == "" then self.hint:Show() else self.hint:Hide() end
  end
  function t:Layout(w, h)
    self:SetSize(w, h or 64)
    Kit.Fit(self.hint, max(10, w - 16))
  end
  return t
end

---------------------------------------------------------------------------
-- (minor 11, Luredon step 4: the fish atlas) ItemCard: a compact card of S.itemCard (64) for one item: a 3 px mark on the
-- left, the symbol 36 px with the quality edge, name (quality colour unless titleColor) and a line below, a number on
-- the right. The mouse shows the game's item tooltip (itemID, tipLines, tipHint) unless tooltip / tooltipFn; shift-click
-- links the item, a click calls d.onClick(card, button, d).
--   c:SetData({ itemID, icon, quality, title, titleColor, sub, right, rightColor, markColor ({ r, g, b }) or status
--     ("green" ...), selected, dim, onClick, tooltip = { title, lines, hint }, tooltipFn(card) })   c:Layout(width)
-- ItemCardRow: a row of item cards for Kit.List (kind "itemcards": item.cards = { data, ... }, item.cols; height
-- S.itemCard + S.gap). Kit.ItemCardCols(width, minWidth) says how many fit (default minWidth 200); the caller splits.
---------------------------------------------------------------------------
function Kit.ItemCard(parent)
  local c = CreateFrame("Button", nil, parent)
  c:SetHeight(S.itemCard)
  c.bg = Fill(c, C.card)
  c.bd = Border(c, C.divider)
  c.mark = Tex(c, "OVERLAY", C.greyBd)
  c.mark:SetPoint("TOPLEFT") c.mark:SetPoint("BOTTOMLEFT") c.mark:SetWidth(S.markBar)
  c.iconBox = CreateFrame("Frame", nil, c)
  c.iconBox:SetSize(S.iconBig, S.iconBig)
  c.iconBox:SetPoint("LEFT", S.markBar + 8, 0)
  Fill(c.iconBox, C.input)
  c.iconBox.bd = Border(c.iconBox, C.goldMuted)
  c.icon = c.iconBox:CreateTexture(nil, "ARTWORK")
  c.icon:SetPoint("TOPLEFT", 1, -1) c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  Call(c.icon, "SetTexCoord", 0.07, 0.93, 0.07, 0.93)
  c.title = Text(c, "row", C.title)
  c.sub = Text(c, "sub", C.muted)
  c.right = Text(c, "title", C.title, "RIGHT")
  c.right:SetPoint("RIGHT", -S.pad, 0)
  Clickable(c, function(self, button)
    local d = self.item
    if not d then return end
    if d.itemID and Kit.LinkItem(d.itemID) then return end
    Safe("item card", d.onClick, self, button, d)
  end)
  function c:SetData(d)
    d = d or {}
    self.item = d
    local tex = d.icon
    if not tex and d.itemID then
      local GI = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
      if GI then local ok, t = pcall(GI, d.itemID) if ok then tex = t end end
    end
    Call(self.icon, "SetTexture", tex or 134400)
    self.iconBox.bd:SetColor(d.quality and Kit.QualityColor(d.quality) or C.goldMuted)
    self.title:SetText(d.title or "")
    TextColor(self.title, d.titleColor or (d.quality and d.quality ~= 1 and Kit.QualityColor(d.quality)) or C.title)
    self.sub:SetText(d.sub or "")
    self.right:SetText(d.right ~= nil and tostring(d.right) or "")
    TextColor(self.right, d.rightColor or C.title)
    self._markColor = d.markColor or MarkColor(d.status)
    self._tip = type(d.tooltip) == "table" and { d.tooltip[1], d.tooltip[2], d.tooltip[3] } or nil
    self._tipFn = d.tooltipFn or (not self._tip and d.itemID and Kit.ItemTipFn) or nil
    self._selected = d.selected and true or nil
    self._dim = d.dim and true or nil
    self:Layout(self._w or self:GetWidth())
    Refresh(self)
  end
  function c:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    self:SetWidth(w)
    local tx = S.markBar + 8 + S.iconBig + S.gap
    local rw = 0
    if self.right:GetText() ~= "" then
      Kit.Fit(self.right, 56)
      rw = min(56, TextW(self.right)) + S.gap
    end
    local room = max(1, w - tx - S.pad - rw)
    self.title:ClearAllPoints() self.sub:ClearAllPoints()
    if self.sub:GetText() ~= "" then
      self.title:SetPoint("TOPLEFT", tx, -14)
      self.sub:SetPoint("TOPLEFT", tx, -33)
    else
      self.title:SetPoint("LEFT", tx, 0)
    end
    Kit.Fit(self.title, room)
    Kit.Fit(self.sub, room)
  end
  c._cutTexts = { c.title, c.sub }
  Stateful(c, function(self, st)
    SetCol(self.bg, st == "selected" and C.rowSel or st == "hover" and C.rowHover or C.card)
    self.bd:SetColor(st == "selected" and C.gold or st == "hover" and C.goldMuted or C.divider)
    SetCol(self.mark, st == "selected" and C.goldBright or self._markColor or C.greyBd)
  end)
  return c
end

function Kit.ItemCardCols(w, minWidth)
  minWidth = tonumber(minWidth) or 200
  w = tonumber(w) or 0
  return max(1, floor((w - S.gap) / (minWidth + S.gap)))
end

function Kit.ItemCardRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r.cards = {}
  function r:SetItem(it)
    self.item = it
    local list = it.cards or {}
    for i, d in ipairs(list) do
      local c = self.cards[i]
      if not c then c = Kit.ItemCard(self) self.cards[i] = c end
      c:Show()
      c:SetData(d)
    end
    for i = #list + 1, #self.cards do self.cards[i]:Hide() self.cards[i].item = nil end
    self:Layout(self._w or self:GetWidth())
  end
  function r:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    local cols = max(1, tonumber(self.item and self.item.cols) or Kit.ItemCardCols(w))
    local each = floor((w - 2 * S.gap - (cols - 1) * S.gap) / cols)
    for i, c in ipairs(self.cards) do
      if c:IsShown() then
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self, "TOPLEFT", S.gap + ((i - 1) % cols) * (each + S.gap), 0)
        c:Layout(max(1, each))
      end
    end
  end
  return r
end
KIND_H.itemcards = S.itemCard + S.gap
ROW_MAKER.itemcards = Kit.ItemCardRow

---------------------------------------------------------------------------
-- Sample page: /doncore kit (every block, and a window to drag between 720x420 and 1300x900)
---------------------------------------------------------------------------
local Sample = {}
Kit.Sample = Sample

local ZONES = {
  { "Elwynn Forest", 1, 10 }, { "Westfall", 10, 20 }, { "Redridge Mountains", 15, 25 }, { "Duskwood", 18, 30 },
  { "Loch Modan", 10, 20 }, { "Wetlands", 20, 30 }, { "Arathi Highlands", 30, 40 }, { "Stranglethorn Vale", 30, 45 },
  { "Darkshore", 10, 20 }, { "Ashenvale", 18, 30 }, { "Stonetalon Mountains", 15, 27 }, { "Desolace", 30, 40 },
  { "Dustwallow Marsh", 35, 45 }, { "Tanaris", 40, 50 }, { "Feralas", 40, 50 }, { "Un'Goro Crater", 48, 55 },
  { "Winterspring", 53, 60 }, { "Eastern Plaguelands", 53, 60 }, { "Burning Steppes", 50, 58 },
  { "Die Sümpfe des Elends am Rand der verwüsteten Lande", 35, 45 },
}
local TITLES = {
  "The Defias Brotherhood", "Red Leather Bandanas", "Die Bruderschaft der Defias, Teil 3: Botengang nach Sturmwind",
  "Wanted: Hogger", "Goretusk Liver Pie", "The Jasperlode Mine", "Patrolling Westfall", "Report to Gryan Stoutmantle",
  "Les Fondeboues : une longue route jusqu'aux mines de Jangolode", "Collecting Kelp", "The Forgotten Heirloom",
  "Keeper of the Flame",
}
local GIVERS = { "Marshal Gryan Stoutmantle", "Farmer Saldean", "Verwalter Folsom", "Captain Grayson", "Salma Saldean" }
local GROUPS = {
  { key = "yellow", text = "In log" }, { key = "blue", text = "Available" }, { key = "grey", text = "Later" },
  { key = "green", text = "Done" },
}

local function SampleQuests(z)
  local zone = ZONES[z]
  local list = {}
  for i = 1, 90 do
    local st = i % 7 == 0 and "green" or i % 5 == 0 and "yellow" or i % 3 == 0 and "grey" or "blue"
    local lvl = zone[2] + (i * 7) % (zone[3] - zone[2] + 1)
    local base = TITLES[(i + z) % #TITLES + 1]
    local q = {
      kind = "row", id = i, status = st, level = lvl, done = st == "green",
      levelStatus = Kit.QuestDifficulty(lvl, floor((zone[2] + zone[3]) / 2)),
      title = i > #TITLES and (base .. " " .. ceil(i / #TITLES)) or base,
      sub = "Quest giver: " .. GIVERS[i % #GIVERS + 1] .. " · " .. (40 + (i * 37) % 900) .. " yards",
      right = (40 + (i * 37) % 900) .. " yd",
    }
    if st == "yellow" and i % 10 == 0 then q.pill = { "Ready", "ready" } end
    if i % 17 == 0 then q.pill = { "Group 2+", "elite" } end
    if i % 9 == 0 then
      q.chainSteps = { { "4a", "next" }, { "4b", "later" } }
      q.dots = { "green", "green", "yellow", "blue", "grey", "grey" }
      q.right = "3/6"
    end
    list[#list + 1] = q
  end
  return list
end

function Sample:Items()
  local st = self.state
  local quests = self.quests[st.zone]
  if not quests then quests = SampleQuests(st.zone) self.quests[st.zone] = quests end
  local q = (st.search or ""):lower()
  local items, shown, total = {}, 0, #quests
  for _, g in ipairs(GROUPS) do
    if st.filter == "all" or st.filter == g.key then
      local rows = {}
      for _, it in ipairs(quests) do
        if it.status == g.key and (q == "" or it.title:lower():find(q, 1, true)) then rows[#rows + 1] = it end
      end
      if #rows > 0 then
        local head = self.groups[g.key] or { kind = "group", key = g.key }
        self.groups[g.key] = head
        head.text, head.count = g.text, #rows
        items[#items + 1] = head
        if not head.collapsed then
          for _, it in ipairs(rows) do
            items[#items + 1] = it
            shown = shown + 1
            for k, step in ipairs(it.chainSteps or {}) do
              items[#items + 1] = { kind = "sub", chain = step[1], status = step[2], parent = it,
                title = it.title .. ": step " .. step[1], right = k == 1 and "next" or "" }
            end
          end
        end
      end
    end
  end
  return items, shown, total
end

function Sample:ZoneItems()
  local q = (self.state.zoneSearch or ""):lower()
  local items = {}
  for i, z in ipairs(ZONES) do
    if q == "" or z[1]:lower():find(q, 1, true) then
      local it = self.zoneItems[i] or { kind = "zone", index = i }
      self.zoneItems[i] = it
      it.text, it.count, it.short = z[1], z[2] .. "-" .. z[3], tostring(z[2])
      it.status = i == self.state.zone and "yellow" or nil
      items[#items + 1] = it
    end
  end
  return items
end

function Sample:Refill()
  local items, shown, total = self:Items()
  self.list:SetItems(items)
  self.shown, self.totalQuests = shown, total
  local zl = self.sidebar.list
  zl:SetItems(self:ZoneItems())
  zl.selected = self.zoneItems[self.state.zone]
  zl:Draw()
  self:Status()
end

function Sample:Status()
  local w = self.win
  if not w then return end
  w:SetStatus(("%d x %d  ·  %s  ·  rows drawn %d of %d  ·  quests %d of %d"):format(floor(w:GetWidth() + 0.5),
    floor(w:GetHeight() + 0.5), w.mode or "?", self.list.drawn or 0, #self.list.items, self.shown or 0, self.totalQuests or 0))
end

-- detail card (quest focus): right column at full width, over the list under 960 px
function Sample:BuildDetail(parent)
  local d = CreateFrame("Frame", nil, parent)
  Fill(d, C.card)
  Border(d, C.gold)
  d.badge = Kit.LevelBadge(d)
  d.badge:SetPoint("TOPLEFT", S.pad, -S.pad)
  d.title = Text(d, "title", C.hero)
  d.title:SetPoint("TOPLEFT", S.pad + S.badgeW + S.gap, -S.pad - 3)
  d.sub = Text(d, "sub", C.muted)
  d.sub:SetPoint("TOPLEFT", S.pad, -S.pad - S.badgeH - S.gap)
  d.close = Kit.IconButton(d, "close", { size = S.buttonSmall - 4, onClick = function() self.list:Select(nil) self:Layout() end })
  d.close:SetPoint("TOPRIGHT", -S.unit * 2, -S.unit * 2)
  d.kv = {}
  for i = 1, 3 do
    local k, v = Text(d, "sub", C.muted), Text(d, "sub", C.body, "RIGHT")
    k:SetPoint("TOPLEFT", S.pad, -76 - (i - 1) * 18)
    v:SetPoint("TOPRIGHT", -S.pad, -76 - (i - 1) * 18)
    d.kv[i] = { k, v }
  end
  d.bar = Kit.ProgressBar(d)
  d.bar:SetPoint("TOPLEFT", S.pad, -138)
  d.ring = Kit.Ring(d, S.iconBig)
  d.ring:SetPoint("TOPRIGHT", -S.pad, -150)
  d.ringText = Text(d, "sub", C.muted)
  d.ringText:SetPoint("TOPLEFT", S.pad, -160)
  d.go = Kit.Button(d, "Set waypoint", { kind = "primary" })
  d.go:SetPoint("BOTTOMLEFT", S.pad, S.pad)
  d.share = Kit.Button(d, "Share", {})
  d.share:SetPoint("LEFT", d.go, "RIGHT", S.gap, 0)
  function d:Fill(it, w)
    self.badge:SetLevel(it.level, it.levelStatus)
    self.title:SetText(it.title)
    self.sub:SetText(it.sub)
    local rows = { { "Status", it.status }, { "Level", tostring(it.level) }, { "Distance", it.right } }
    for i, kv in ipairs(self.kv) do kv[1]:SetText(rows[i][1]) kv[2]:SetText(rows[i][2]) Kit.Fit(kv[2], w / 2) end
    self.bar:Layout(w - 2 * S.pad)
    self.bar:SetValue(it.dots and 0.5 or (it.status == "green" and 1 or 0.25))
    self.bar:SetColor(it.status == "green" and "green" or nil)
    self.ring:SetValue(it.dots and 3 or (it.status == "green" and 6 or 1), 6)
    self.ringText:SetText(it.dots and "Chain: step 3 of 6" or "Objectives")
    Kit.Fit(self.title, w - S.pad * 2 - S.badgeW - S.gap - S.buttonSmall - S.unit)
    Kit.Fit(self.sub, w - 2 * S.pad)
    Kit.Fit(self.ringText, w - 2 * S.pad - S.iconBig - S.gap)
  end
  d._cutTexts = { d.title, d.sub }
  return d
end

function Sample:BuildListPage(page)
  self.state = { zone = 2, filter = "all", search = "", zoneSearch = "" }
  self.quests, self.groups, self.zoneItems = {}, {}, {}
  self.sidebar = Kit.Sidebar(page, {
    search = "Find zone...",
    onSearch = function(t) self.state.zoneSearch = t self:Refill() end,
    onClick = function(it) self.state.zone = it.index self.list:Select(nil) self.list:SetOffset(0) self:Refill() self:Layout() end,
  })
  self.sidebar:SetPoint("TOPLEFT", 0, 0)
  self.main = CreateFrame("Frame", nil, page)
  self.chips = Kit.ChipBar(self.main, { onChange = function(key) self.state.filter = key self.list:SetOffset(0) self:Refill() end })
  self.chips:SetPoint("TOPLEFT", S.gap, -S.gap)
  for _, c in ipairs({ { "all", "All" }, { "yellow", "In log" }, { "blue", "Available" }, { "grey", "Later" },
    { "green", "Done" }, { "elite", "Elite" }, { "chains", "Chains" }, { "dungeon", "Dungeons" }, { "group", "Group 2+" },
    { "raid", "Raids" }, { "rep", "Reputation" } }) do
    self.chips:Add(c[1], c[2])
  end
  self.chips:SetActive("all")
  self.search = Kit.SearchBox(self.main, { placeholder = "Search quests...", onChange = function(t) self.state.search = t self:Refill() end })
  self.list = Kit.List(self.main, {
    onClick = function(it) self.list:Select(it.parent or it) self:Layout() end,
    onToggle = function() self:Refill() end,
  })
  self.detail = self:BuildDetail(page)
end

function Sample:LayoutListPage(w, h, mode)
  local rail = mode == "rail"
  self.sidebar:Layout(h, rail)
  local sw = self.sidebar:Width()
  local overlay = mode ~= "full"
  local dw = 300
  local sel = self.list.selected
  local mw = w - sw - ((not overlay) and dw or 0)
  self.main:ClearAllPoints()
  self.main:SetPoint("TOPLEFT", sw, 0)
  self.main:SetSize(mw, h)
  local top = S.gap + S.chip + S.gap
  local searchW = min(220, floor(mw * 0.35))
  self.chips:Layout(mw - 3 * S.gap - searchW)
  self.search:ClearAllPoints()
  self.search:SetPoint("TOPRIGHT", self.main, "TOPRIGHT", -S.gap, -S.gap + 2)
  self.search:Layout(searchW)
  self.list:ClearAllPoints()
  self.list:SetPoint("TOPLEFT", 0, -top)
  self.list:Resize(mw, h - top)
  -- detail: own column at full width, over the list (right edge) under 960 px, shown when a quest is chosen
  local d = self.detail
  d:ClearAllPoints()
  if overlay then
    Call(d, "SetFrameLevel", (select(2, Call(self.main, "GetFrameLevel")) or 1) + 20)
    d:SetPoint("TOPRIGHT", self.main, "TOPRIGHT", -S.gap, -top - S.unit)
    d:SetSize(dw, max(200, min(h - top - 2 * S.gap, 320)))
    if sel then d:Show() else d:Hide() end
    d.close:Show()
  else
    d:SetPoint("TOPLEFT", sw + mw, 0)
    d:SetSize(dw, h)
    d:Show()
    d.close:Hide()
  end
  local it = sel
  if not it then for _, x in ipairs(self.list.items) do if x.kind == "row" then it = x break end end end
  if it then d:Fill(it, dw) end
  self:Status()
end

-- section title on the parts page
local function Section(parent, text)
  local h = Kit.GroupHeader(parent)
  h:SetItem({ kind = "group", text = text, static = true })
  return h
end

function Sample:BuildPartsPage(page)
  local area = Kit.ScrollArea(page)
  area:SetAllPoints(page)
  self.parts = area
  local c = area.content
  local P = { blocks = {} }
  self.p = P
  local function Add(group, f) P.blocks[#P.blocks + 1] = { group = group, f = f } return f end
  -- 1 colours
  P.s1 = Section(c, "1 · Colour tokens and status colours")
  for _, k in ipairs({ "window", "panel", "card", "gold", "goldBright", "green", "yellow", "blue", "grey", "red", "hero", "body", "muted" }) do
    local sw = CreateFrame("Frame", nil, c)
    sw:SetSize(168, 36)
    Fill(sw, C.card)
    Border(sw, C.divider)
    local box = Tex(sw, "ARTWORK", C[k])
    box:SetSize(24, 24) box:SetPoint("LEFT", 6, 0)
    local n = Text(sw, "row", C.title) n:SetPoint("TOPLEFT", 36, -4) n:SetText(k) Kit.Fit(n, 126)
    local hx = Text(sw, "mono", C.muted) hx:SetPoint("BOTTOMLEFT", 36, 5) hx:SetText("#" .. C[k].hex:sub(3):upper())
    Add("colours", sw)
  end
  -- 2 type
  P.s2 = Section(c, "2 · Type scale and 4 px grid")
  P.type = {}
  for _, t in ipairs({ { "hero", "Westfall: The Deadmines", C.hero }, { "title", "Questdon · The Defias Brotherhood", C.hero },
    { "row", "Die Bruderschaft der Defias, Teil 3: Botengang nach Sturmwind (one line, cut)", C.title },
    { "sub", "Quest giver: Marshal Gryan Stoutmantle · 340 yards south-west", C.muted } }) do
    local fs = Text(c, t[1], t[3]) fs:SetText(t[2])
    P.type[#P.type + 1] = fs
  end
  -- 3 buttons, tabs
  P.s3 = Section(c, "3 · Buttons and book tabs (normal, hover, selected, disabled)")
  Add("buttons", Kit.Button(c, "Primary (gold)", { kind = "primary", tooltip = "Primary button" }))
  Add("buttons", Kit.Button(c, "Secondary (navy)", {}))
  Add("buttons", Kit.Button(c, "Compact 24", { small = true }))
  Add("buttons", Kit.Button(c, "o", { kind = "icon" }))
  Add("buttons", Kit.Button(c, "Selected", {})):SetSelected(true)
  Add("buttons", Kit.Button(c, "Disabled", {})):SetDisabled(true)
  for _, t in ipairs({ { "Normal" }, { "Selected", "sel" }, { "Disabled", "off" } }) do
    local tab = Add("tabs", Kit.Tab(c, t[1]))
    if t[2] == "sel" then tab:SetSelected(true) elseif t[2] == "off" then tab:SetDisabled(true) end
  end
  -- 4 chips and marks
  P.s4 = Section(c, "4 · Chips (scroll, never wrap), marks, level badges in Blizzard's quest colours, ring, pills")
  P.chipBar = Kit.ChipBar(c, { multi = true })
  for i, t in ipairs({ "Filter on (14)", "Filter off (72)", "Elite", "Chains", "Dungeons", "Group 2+", "Raids",
    "Reputation", "Professions", "Seasonal", "PvP", "Holidays" }) do
    P.chipBar:Add(i, t)
  end
  P.chipBar:SetActive(1)
  Add("marks", Kit.ChainMark(c, "4a"))
  Add("marks", Kit.ChainMark(c, "4b"))
  Add("marks", Kit.ChainMark(c, "3/6"))
  Add("marks", (function() local d = Kit.Dots(c) d:SetDots({ "green", "green", "yellow", "blue", "grey", "grey" }) return d end)())
  Add("marks", Kit.Pill(c, "Ready", "ready"))
  Add("marks", Kit.Pill(c, "Group 2+", "elite"))
  for _, b in ipairs({ { 10, "trivial" }, { 14, "standard" }, { 18, "difficult" }, { 20, "verydifficult" }, { 22, "impossible" } }) do
    Add("marks", Kit.LevelBadge(c, b[1], b[2]))
  end
  Add("marks", (function() local r = Kit.Ring(c) r:SetValue(3, 6) return r end)())
  Add("marks", (function() local r = Kit.Ring(c) r:SetValue(6, 6) return r end)())
  -- 5 rows
  P.s5 = Section(c, "5 · Rows 36, group header 28, chain step 28")
  P.rows = {}
  local demo = {
    { "group", { kind = "group", text = "In log", count = 3 } },
    { "row", { kind = "row", status = "blue", level = 14, levelStatus = "standard", title = "Normal row (36 px, 3 px mark on the left)", sub = "Quest giver: Verwalter Folsom · 280 yards", right = "280 yd" } },
    { "row", { kind = "row", status = "yellow", level = 16, levelStatus = "difficult", title = "Row with an exception pill", sub = "Quest giver: Captain Grayson · 620 yards", right = "620 yd", pill = { "Ready", "ready" } } },
    { "row", { kind = "row", status = "yellow", level = 18, levelStatus = "verydifficult", title = "Selected row / chain head with dots and counter", sub = "Quest giver: Marshal Gryan Stoutmantle · 340 yards", right = "3/6", dots = { "green", "green", "yellow", "blue", "grey", "grey" } }, true },
    { "sub", { kind = "sub", chain = "4a", status = "current", title = "Indented chain step (28 px, mark 4a before the title, no wrap)" } },
    { "sub", { kind = "sub", chain = "4b", status = "later", title = "Later chain step" } },
    { "row", { kind = "row", status = "green", level = 11, levelStatus = "trivial", done = true, title = "Dimmed row / done (72 % alpha, green mark)", sub = "Done today at 13:34" } },
  }
  for i, d in ipairs(demo) do
    local r = ROW_MAKER[d[1]](c)
    r._selected = d[3] or nil
    r:SetItem(d[2], i)
    P.rows[#P.rows + 1] = r
  end
  -- 6 controls
  P.s6 = Section(c, "6 · Toggle, slider, dropdown, search box, progress bars")
  P.opt = { on = true, alpha = 82, sort = "level" }
  Add("controls", Kit.Toggle(c, { label = "On", get = function() return P.opt.on end, set = function(v) P.opt.on = v end }))
  Add("controls", Kit.Toggle(c, { label = "Off", value = false }))
  Add("controls", Kit.Slider(c, { min = 60, max = 100, step = 1, width = 180, get = function() return P.opt.alpha end,
    set = function(v) P.opt.alpha = v end, format = function(v) return v .. " %" end }))
  Add("controls", Kit.Dropdown(c, { width = 150, items = { { value = "level", text = "Level" }, { value = "dist", text = "Distance" },
    { value = "name", text = "Name" } }, get = function() return P.opt.sort end, set = function(v) P.opt.sort = v end }))
  Add("controls", Kit.SearchBox(c, { placeholder = "Zone, journal entry, quest or NPC...", width = 240 }))
  P.bars = {}
  for i, col in ipairs({ "goldBright", "green", "yellow", "blue" }) do
    local b = Kit.ProgressBar(c, C[col])
    b.value = i / 5
    P.bars[i] = b
  end
  -- 7 tiles
  P.s7 = Section(c, "7 · Tiles (cards with a gold top edge)")
  P.tiles = {
    Kit.Tile(c, { label = "Quests done", value = "142", line = "of 310 in this zone band" }),
    Kit.Tile(c, { label = "Gold per hour", value = "38g 12s", line = "last 30 minutes", color = C.txGold }),
    Kit.Tile(c, { label = "Dungeon progress", value = "3/6", line = "The Deadmines", color = C.green }),
  }
end

function Sample:LayoutPartsPage(w, h)
  local P, c = self.p, self.parts.content
  self.parts:Resize(w, h)
  local inner = w - 2 * S.pad - 6
  local y = S.pad
  local function Head(sec)
    sec:ClearAllPoints()
    sec:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad, -y)
    sec:SetSize(inner, S.sub)
    sec:Layout(inner)
    y = y + S.sub + S.gap
  end
  local function Flow(group, lineH)
    local x = 0
    for _, b in ipairs(P.blocks) do
      if b.group == group then
        local fw = b.f:GetWidth() or 0
        if x > 0 and x + fw > inner then x = 0 y = y + lineH + S.gap end
        b.f:ClearAllPoints()
        b.f:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad + x, -y - floor((lineH - (b.f:GetHeight() or lineH)) / 2))
        x = x + fw + S.gap
      end
    end
    y = y + lineH + S.pad
  end
  Head(P.s1) Flow("colours", 36)
  Head(P.s2)
  for _, fs in ipairs(P.type) do
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad, -y)
    Kit.Fit(fs, inner)
    y = y + (fs == P.type[1] and 28 or 22)
  end
  y = y + S.unit
  Head(P.s3) Flow("buttons", S.button) Flow("tabs", S.tab + 2)
  Head(P.s4)
  P.chipBar:ClearAllPoints()
  P.chipBar:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad, -y)
  P.chipBar:Layout(min(inner, 520))
  y = y + S.chip + S.gap
  Flow("marks", S.iconBig)
  Head(P.s5)
  for _, r in ipairs(P.rows) do
    local rh = KIND_H[r.item.kind]
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad, -y)
    r:SetSize(inner, rh)
    r:Layout(inner)
    y = y + rh
  end
  y = y + S.pad
  Head(P.s6) Flow("controls", S.button)
  local bw = floor((inner - 3 * S.gap) / 4)
  for i, b in ipairs(P.bars) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad + (i - 1) * (bw + S.gap), -y)
    b:Layout(bw)
  end
  y = y + S.bar + S.pad
  Head(P.s7)
  local tw = floor((inner - 2 * S.gap) / 3)
  for i, t in ipairs(P.tiles) do
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad + (i - 1) * (tw + S.gap), -y)
    t:Layout(tw)
  end
  y = y + 72 + S.pad
  self.parts:SetContentHeight(y)
end

function Sample:BuildOptionsPage(page)
  local area = Kit.ScrollArea(page)
  area:SetAllPoints(page)
  self.optArea = area
  local c = area.content
  local o = { arrow = true, done = false, auto = true, alpha = 82, scale = 100, sort = "level" }
  self.o = o
  self.optRows = {}
  local function Row(opts) local r = Kit.OptionRow(c, opts) self.optRows[#self.optRows + 1] = r return r end
  self.optHead = Section(c, "Questdon · Quest log")
  local sub
  Row({ label = "Show the arrow", desc = "Points to the next objective of the chosen quest",
    control = Kit.Toggle(c, { get = function() return o.arrow end, set = function(v) o.arrow = v sub:SetDisabled(not v) end }) })
  sub = Row({ indent = true, label = "Only in the open world", desc = "Sub-option: greyed out while the arrow is off",
    control = Kit.Toggle(c, { get = function() return o.done end, set = function(v) o.done = v end }) })
  Row({ label = "Automatische Zielführung beim Annehmen einer Quest einschalten, auch für Gruppenquests, Ketten, Dungeons und Schlachtzüge in allen Gebieten",
    desc = "A long German label: one line, cut with ..., the whole text in the tooltip",
    control = Kit.Toggle(c, { get = function() return o.auto end, set = function(v) o.auto = v end }) })
  Row({ label = "Window alpha", desc = "60 to 100 %",
    control = Kit.Slider(c, { min = 60, max = 100, step = 1, width = 200, get = function() return o.alpha end,
      set = function(v) o.alpha = v if self.win then self.win:SetAlpha(v / 100) end end, format = function(v) return v .. " %" end }) })
  Row({ label = "Scale", desc = "80 to 125 %",
    control = Kit.Slider(c, { min = 80, max = 125, step = 5, width = 200, get = function() return o.scale end,
      set = function(v) o.scale = v end, format = function(v) return v .. " %" end }) })
  Row({ label = "Sort quests by", desc = "Dropdown with its own list",
    control = Kit.Dropdown(c, { width = 160, items = { { value = "level", text = "Level" }, { value = "dist", text = "Distance" },
      { value = "name", text = "Name" }, { value = "zone", text = "Zone, then level" } },
      get = function() return o.sort end, set = function(v) o.sort = v end }) })
  Row({ label = "Reset this tab", desc = "Secondary button in an option row",
    control = Kit.Button(c, "Reset tab", { small = true, onClick = function() o.alpha, o.scale = 82, 100 self:LayoutOptionsPage(self.optW, self.optH) end }) })
  local off = Row({ label = "Disabled row", desc = "SetDisabled(true) on the row greys the row and its control",
    control = Kit.Toggle(c, { value = true }) })
  off:SetDisabled(true)
end

function Sample:LayoutOptionsPage(w, h)
  self.optW, self.optH = w, h
  self.optArea:Resize(w, h)
  local c = self.optArea.content
  local inner = min(w - 2 * S.pad - 6, 760)
  local y = S.pad
  self.optHead:ClearAllPoints()
  self.optHead:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad, -y)
  self.optHead:SetSize(inner, S.sub)
  self.optHead:Layout(inner)
  y = y + S.sub
  for _, r in ipairs(self.optRows) do
    if r.control and r.control.Update then r.control:Update() end
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", c, "TOPLEFT", S.pad, -y)
    r:Layout(inner)
    y = y + S.row
  end
  self.optArea:SetContentHeight(y + S.pad)
end

function Sample:Layout()
  local win = self.win
  if not win then return end
  local w, h, mode = win._bodyW, win._bodyH, win.mode
  if not w then return end
  for key, page in pairs(self.pages) do
    if key == win.tab then page:Show() else page:Hide() end
    page:SetSize(w, h)
  end
  if win.tab == "parts" then self:LayoutPartsPage(w, h)
  elseif win.tab == "list" then self:LayoutListPage(w, h, mode)
  else self:LayoutOptionsPage(w, h) end
  self:Status()
end

function Sample:Build()
  local win = Kit.Window("DonCoreKitSample", {
    title = "DonCore Kit · Don style", width = 980, height = 640, footer = true, store = Kit.sampleStore,
    onLayout = function(w, bw, bh) w._bodyW, w._bodyH = bw, bh if self.pages then self:Layout() end end,
    onTab = function() self:Layout() end,
  })
  self.win = win
  self.pages = {}
  for _, key in ipairs({ "parts", "list", "options" }) do
    local p = CreateFrame("Frame", nil, win.body)
    p:SetPoint("TOPLEFT", 0, 0)
    self.pages[key] = p
  end
  self:BuildPartsPage(self.pages.parts)
  self:BuildListPage(self.pages.list)
  self:BuildOptionsPage(self.pages.options)
  win:AddTab("parts", "Parts")
  win:AddTab("list", "List")
  win:AddTab("options", "Options")
  self:Refill()
  win:SelectTab("parts")
  win:Layout()
  return win
end

-- /doncore kit: opens (or closes) the sample window; Kit.sampleStore (a plain table, not saved) keeps its place
-- for the session
Kit.sampleStore = Kit.sampleStore or {}
function Kit.ShowSample()
  if not Sample.win then Sample:Build() Sample.win:Show() return Sample.win end
  Sample.win:Toggle()
  return Sample.win
end

---------------------------------------------------------------------------
-- /doncore: one slash command for all DonCore modules; Core.slash[word] = function(rest)
---------------------------------------------------------------------------
Core.slash = Core.slash or {}
Core.slash.kit = function() Kit.ShowSample() end
if type(SlashCmdList) == "table" and not SlashCmdList.DONCORE then
  SLASH_DONCORE1 = "/doncore"
  SlashCmdList.DONCORE = function(msg)
    local cmd, rest = tostring(msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local fn = Core.slash[(cmd or ""):lower()]
    if fn then fn(rest) return end
    local words = {}
    for k in pairs(Core.slash) do words[#words + 1] = k end
    table.sort(words)
    print("DonCore: /doncore " .. table.concat(words, " | "))
  end
end

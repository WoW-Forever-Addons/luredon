local Bz = LibStub("DonCore-1.0"):NewModule("Blizz", 11)
if not Bz then return end

---------------------------------------------------------------------------
-- DonCore module "Blizz" (minor 1, 15.11.2026, Daniel: "Das Blizzard layout von profitdon gefällt mir so gut, dass ich
-- es optional über alle addons ausrollen möchte"): the Kit's building blocks a second time, built from the game's own
-- templates (ButtonFrameTemplate, PanelTabButtonTemplate, UIPanelButtonTemplate, UICheckButtonTemplate,
-- SearchBoxTemplate, InputBoxTemplate, WowScrollBoxList with MinimalScrollBar, ColumnDisplayButtonNoScriptsTemplate).
-- Lifted from Profitdon/Blizz.lua and BlizzKit.lua (15.11.2026), freed from Profitdon's namespace.
--   local Bz = LibStub("DonCore-1.0"):Get("Blizz", 1)
--   local UI = (myOption and Bz and Bz.Kit()) or Kit      -- nil when the client lacks a template: the Kit builds
--   UI.Window(...), UI.List(...), UI.Tile(...)            -- the same calls and methods as the Kit's blocks
-- Bz.kit answers every name it does not build itself with the Kit's (colours, sizes, Money, Fit, parts without a
-- counterpart in the game), so a window may take all its blocks from UI. An addon builds inside a pcall and falls
-- back to the Kit when the build fails (the option stays, a diag line says why).
-- Bz.light = false: the templates as they come, without the lighter tones and the grounds with structure.
-- (minor 2, 16.11.2026, learned in Profitdon after the copy, handover/doncore.md "16.11.2026 Gelernt in Profitdon")
-- Bz.Settle and Bz.ClampScroll after every new list (a list set in the frame its window opens in stayed empty until
-- the wheel; a kept scroll place could lie past the end of a shorter list), Tab leaves an EditBox as in the Kit.
-- (minor 5, 16.11.2026, Daniel: Blizzard look as the default for all Don addons) every block the windows of Finddon,
-- Vitaldon, Geardon, Dropdon, Guildon, Guildon_Crafts, Golddon, Questdon (quest book, dialogs) and Profitdon take from
-- the Kit has a counterpart here with the same calls: ListRow, GroupHeader, SubRow, ZoneRow, OptionRow, Card, CardRow,
-- ItemRow, DoneRow, WarnRow, Sidebar, Box, ScrollArea, MoneyBox, CoinBox, Columns, ProgressBar, Pill, ChainMark,
-- Radio, Chip, ItemIcon, ItemGrid, ItemButton, SecureButton, Menu, TextBox. The List knows the Kit's kinds sub, zone,
-- cards, trow, done and an addon's own kinds (opts.kinds = { name = { make, h } }), l:ScrollTo; row items carry
-- radio, chain, pill, dots, ring and badgeRight as in the Kit. The Table folds groups (onToggle) and scrolls (ScrollTo).
-- Rows the Kit builds keep their logic and get the game's look (fonts, quest log highlight, tooltip edge).
-- Bz.ROW_H and Bz.K as in Profitdon's own copy.
-- Also in minor 5, from the rollout (doncore_nachtrag): ChipBar as the Kit's (active table, multi, Add with count and
-- copts, Paint, Place, ContentWidth, offset and wheel, onChange(key, on, bar, button)), Chip:SetCount(text, colour),
-- Dropdown (Update, Choose, SetTooltip over the template's, headers not to choose, right texts, SetDisabled), Detail
-- (actions, Item returning text and symbol, Progress, FitLines, the level in the head), Window (mode by width as
-- Kit.Mode at the Kit's scale: Bz.Mode; opts.buttons -> f.extra; SetOwnScale; SetLocked and the Kit's lock by the
-- header's mouse; the status on the left of the strip), Hint, TableHead (head.cells made at once, a hidden head stays
-- hidden), Button.blizz.
---------------------------------------------------------------------------
local Kit = LibStub("DonCore-1.0"):Get("Kit", 25)
-- (minor 11, 21.11.2026, Profitdon: gear "of the ..." without its stats) item rows show item.itemLink / item.itemKey,
-- the variant itself (Kit.SetItemTip, Kit 33); an older Kit: the plain item ID as before
local function SetItem(tt, it)
  if Kit and Kit.SetItemTip then return Kit.SetItemTip(tt, it.itemID, it.itemLink, it.itemKey) end
  return tt.SetItemByID and pcall(tt.SetItemByID, tt, it.itemID)
end
local K = setmetatable({}, { __index = Kit or {} })
Bz.kit = K
Bz.K = K -- (Profitdon's name for the kit)
K.blizzLook = true -- a caller can tell the two kits apart
Bz.VERSION = 11
Bz.ROW_H = 24 -- the row height of Bz.List without opts.rowHeight (Profitdon's craft and sell lists)
if Bz.light == nil then Bz.light = true end

local function Try(f, ...)
  if type(f) ~= "function" then return end
  local ok, err = pcall(f, ...)
  if not ok then
    local h = type(geterrorhandler) == "function" and geterrorhandler()
    if type(h) == "function" then pcall(h, err) end
  end
end
local function pass(ok, ...) if ok then return ... end return nil end
local function Call(f, ...)
  if type(f) ~= "function" then return nil end
  return pass(pcall(f, ...))
end
local function After(s, f)
  if type(C_Timer) == "table" and C_Timer.After then C_Timer.After(s, f) end
end
local function Icon(id)
  return Call((C_Item and C_Item.GetItemIconByID) or rawget(_G, "GetItemIcon"), id) or 134400
end
Bz.Try, Bz.Call, Bz.Icon = Try, Call, Icon

Bz.TEMPLATES = { "ButtonFrameTemplate", "UIPanelButtonTemplate", "PanelResizeButtonTemplate", "WowScrollBoxList", "MinimalScrollBar" }
Bz.FUNCS = { "CreateScrollBoxListLinearView", "CreateDataProvider", "ButtonFrameTemplate_HideButtonBar" }
-- nil when everything is there, else what is missing (for an addon's diag line)
function Bz.Missing()
  local X = rawget(_G, "C_XMLUtil")
  if not (type(X) == "table" and type(X.GetTemplateInfo) == "function") then return "C_XMLUtil.GetTemplateInfo" end
  for _, t in ipairs(Bz.TEMPLATES) do
    local ok, info = pcall(X.GetTemplateInfo, t)
    if not (ok and info) then return "template " .. t end
  end
  for _, f in ipairs(Bz.FUNCS) do if type(rawget(_G, f)) ~= "function" then return f end end
  local SU = rawget(_G, "ScrollUtil")
  if not (type(SU) == "table" and type(SU.InitScrollBoxListWithScrollBar) == "function") then return "ScrollUtil" end
  return nil
end
function Bz.Ready()
  local miss = Bz.Missing()
  return miss == nil, miss
end

local function Part(f, key) local p = f and f[key] return type(p) == "table" and p or nil end

-- (Daniel 15.11.2026, Bild neben dem Auktionshaus: "wie es aussieht mit den etwas helleren farben (siehe auktionshaus
-- fenster)") the frame template's own ground is nearly black; the auction house beside it is a warm brown with
-- charcoal lists. A wash of colour over the frame's and the inset's ground (their stone still shows through) brings
-- Profitdon's windows to those tones, read off Daniel's picture. Option blizzLight (on), off: the template as it comes.
Bz.TONE = { frame = { 0.23, 0.19, 0.15, 0.78 }, inset = { 0.14, 0.13, 0.12, 0.70 } }
local function Wash(owner, over, tone)
  if not (owner and owner.CreateTexture) then return nil end
  local t = owner:CreateTexture(nil, "BACKGROUND", nil, 7)
  if type(over) == "table" and over.GetObjectType then t:SetAllPoints(over) else t:SetAllPoints(owner) end
  t:SetColorTexture(tone[1], tone[2], tone[3], tone[4])
  return t
end
-- (Daniel 15.11.2026, four pictures: "würde die spalte gerne so sehen, mit bisschen struktur ... dann die restlichen
-- spalten auch mit struktur", "und das durchgängig über das addon") a list stands on ground with structure, in two tones:
-- the item column on a warm brown, the number columns on charcoal. Structure comes from the game's own tiled grounds
-- (Interface\FrameGeneral\UI-Background-Marble of InsetFrameTemplate, UI-Background-Rock of the frame templates, both
-- in SharedUIPanelTemplates.xml), the tone from a thin wash over them so the stone still shows. Bz.Ground(owner, kind)
-- returns the pair { tex, wash } with :Place(left, right, top, bottom) in pixels from the owner's edges.
Bz.GROUND = {
  item = { file = "Interface\\FrameGeneral\\UI-Background-Marble", tint = { 1, 0.9, 0.78 }, wash = { 0.26, 0.2, 0.14, 0.5 } },
  cells = { file = "Interface\\FrameGeneral\\UI-Background-Rock", tint = { 1, 1, 1 }, wash = { 0.17, 0.16, 0.15, 0.4 } },
}
function Bz.Ground(owner, kind)
  local def = Bz.GROUND[kind] or Bz.GROUND.cells
  local g = { kind = kind }
  g.tex = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
  g.tex:SetTexture(def.file, "REPEAT", "REPEAT")
  if g.tex.SetHorizTile then g.tex:SetHorizTile(true) end
  if g.tex.SetVertTile then g.tex:SetVertTile(true) end
  g.tex:SetVertexColor(def.tint[1], def.tint[2], def.tint[3])
  g.wash = owner:CreateTexture(nil, "BACKGROUND", nil, 2)
  g.wash:SetColorTexture(def.wash[1], def.wash[2], def.wash[3], def.wash[4])
  function g:Place(left, right, top, bottom)
    self.left, self.right = left, right
    for _, t in ipairs({ self.tex, self.wash }) do
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", owner, "TOPLEFT", left or 0, -(top or 0))
      t:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -(right or 0), bottom or 0)
    end
  end
  function g:SetShown(on) self.tex:SetShown(on) self.wash:SetShown(on) end
  g:Place(0, 0, 0, 0)
  if Bz.light == false then g:SetShown(false) end
  return g
end

function Bz.Lighten(f)
  if Bz.light == false then return false end
  f.washFrame = Wash(f, Part(f, "Bg"), Bz.TONE.frame)
  local inset = Part(f, "Inset")
  if inset then f.washInset = Wash(inset, Part(inset, "Bg"), Bz.TONE.inset) end
  return true
end

---------------------------------------------------------------------------
-- A window like the profession window: Blizzard's frame with portrait, title, red X and inset; moved at the title,
-- sized at the grip bottom right; place and size kept in store.bz. opts: title, icon, store, width, height, min, max,
-- onLayout(win, w, h) (after a size change), onHide
---------------------------------------------------------------------------
-- A list set again keeps its scroll place in pixels (RetainScrollPosition); was it longer before, the place lies past
-- the end and the box shows nothing until the wheel: brought back into range after every new list (Bz.ClampScroll).
-- A list set in the frame its window opens in has no height yet and lays out no row: one frame later, with its size
-- known, it is drawn once more (Bz.Settle), at most once per frame.
function Bz.ClampScroll(box)
  if type(box) ~= "table" or type(box.GetScrollPercentage) ~= "function" then return end
  local p = tonumber((box:GetScrollPercentage()))
  if not p then return end
  local can = type(box.HasScrollableExtent) ~= "function" or box:HasScrollableExtent()
  local nope = type(ScrollBoxConstants) == "table" and ScrollBoxConstants.NoScrollInterpolation or true
  if not can or p < 0 then if p ~= 0 then box:ScrollToBegin(nope) end
  elseif p > 1 then box:ScrollToEnd(nope) end
end
-- (minor 5) the Kit's mode of a window by its width (Kit.Mode: overlay under 960, rail under 800 at the Kit's scale).
-- The game's frame shows at 100 %, a Kit window at Kit.scale (0.8): the same room on screen is width / scale in the
-- Kit's units, so the frame is measured as the Kit would measure a window of its size on screen.
function Bz.Mode(w)
  local sc = (Kit and Kit.GetScale and tonumber(Kit.GetScale())) or 0.8
  if sc <= 0 then sc = 0.8 end
  w = (tonumber(w) or 0) / sc
  if Kit and Kit.Mode then return Kit.Mode(w) end
  return w < 800 and "rail" or w < 960 and "overlay" or "full"
end
-- (minor 5) the Kit's l:ScrollTo(item or index, top) on the game's scroll box: the item into view (nearest edge), top =
-- true puts it at the top; true when found
function Bz.ScrollTo(box, items, it, top)
  if type(box) ~= "table" or type(items) ~= "table" then return false end
  local index
  for i, x in ipairs(items) do if x == it or i == it then index = i break end end
  if not index then return false end
  local SBC = type(ScrollBoxConstants) == "table" and ScrollBoxConstants or {}
  local align = top and SBC.AlignBegin or SBC.AlignNearest
  local nope = SBC.NoScrollInterpolation or true
  if type(box.ScrollToElementDataIndex) == "function" then pcall(box.ScrollToElementDataIndex, box, index, align, nope) end
  box.scrolledTo = index -- (tests)
  return true
end
function Bz.Settle(box)
  if type(box) ~= "table" or box.settling or type(box.FullUpdate) ~= "function" then return end
  box.settling = true
  After(0, function()
    box.settling = nil
    local now = type(ScrollBoxConstants) == "table" and ScrollBoxConstants.UpdateImmediately or true
    pcall(box.FullUpdate, box, now)
    Bz.ClampScroll(box)
  end)
end

function Bz.Window(name, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
  f.opts = opts
  if not opts.keepBar then ButtonFrameTemplate_HideButtonBar(f) end -- keepBar: the strip under the inset stays (a status line)
  local store = type(opts.store) == "table" and opts.store or {}
  store.bz = type(store.bz) == "table" and store.bz or {}
  local st = store.bz
  -- (Daniel 15.11.2026, /profit diag: "Reiter stehen 55 px über, von Hand verschoben" on a window he had only resized)
  -- until then the grip kept the place too: places kept before are dropped once
  if st.v ~= 2 then st.point, st.rel, st.x, st.y, st.v = nil, nil, nil, nil, 2 end
  f.bz = st
  local minW, minH = (opts.min or { 300, 200 })[1], (opts.min or { 300, 200 })[2]
  local maxW, maxH = (opts.max or { 900, 1000 })[1], (opts.max or { 900, 1000 })[2]
  f:SetSize(math.max(minW, math.min(maxW, tonumber(st.w) or opts.width or 384)), math.max(minH, math.min(maxH, tonumber(st.h) or opts.height or 460)))
  if f.SetTitle then f:SetTitle(opts.title or "") end
  if f.SetPortraitToAsset then f:SetPortraitToAsset(opts.icon or "Interface\\Icons\\INV_Enchant_Disenchant") end
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  -- sizeOnly (the grip): the place is only kept when the window was moved, a new size does not pin it
  function f:Save(sizeOnly)
    if not sizeOnly then
      local p, _, rp, x, y = self:GetPoint(1)
      if p then st.point, st.rel, st.x, st.y = p, rp, x, y end
    end
    st.w, st.h = self:GetWidth(), self:GetHeight()
  end
  -- true when the place was kept from an earlier session (moved by hand)
  function f:Restore()
    if not st.point then return false end
    self:ClearAllPoints()
    self:SetPoint(st.point, UIParent, st.rel or st.point, st.x or 0, st.y or 0)
    return true
  end
  local function drag(h)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    -- (minor 5) not while locked: f:SetLocked(on), or the Kit's way, the header (title strip) without the mouse
    h:SetScript("OnDragStart", function()
      if f._locked then return end
      local hd = f.header
      if hd and hd ~= f and hd.IsMouseEnabled and not hd:IsMouseEnabled() then return end
      f:StartMoving()
    end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing() f:Save() end)
  end
  drag(f)
  function f:SetLocked(on) self._locked = on and true or nil return self end
  function f:IsLocked() return self._locked == true end
  local tc = Part(f, "TitleContainer")
  if tc then drag(tc) end
  local close = Part(f, "CloseButton")
  if close then close:SetScript("OnClick", function() f:Hide() end) end
  f.inset = Part(f, "Inset") or f
  Bz.Lighten(f)
  function f:Layout()
    if opts.onLayout then Try(opts.onLayout, self, self:GetWidth() or 0, self:GetHeight() or 0) end
  end
  f:SetScript("OnSizeChanged", function(self) self:Layout() end)
  f:SetScript("OnHide", function(self) if opts.onHide then Try(opts.onHide, self) end end)
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(minW, minH, maxW, maxH) end
  local grip = CreateFrame("Button", nil, f, "PanelResizeButtonTemplate")
  grip:SetPoint("BOTTOMRIGHT", -5, 5)
  grip:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
  if grip.Init then grip:Init(f, minW, minH, maxW, maxH) end
  if grip.HookScript then grip:HookScript("OnMouseUp", function() f:Save(true) end) end
  f.grip = grip
  -- Escape shuts it like the game's own windows
  if name and type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end
  return f
end

-- Blizzard's red button; the width follows the text
function Bz.Button(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetHeight(20)
  function b:Label(t)
    self:SetText(t or "")
    local w = self.GetTextWidth and tonumber((self:GetTextWidth())) or nil
    self:SetWidth(math.max(40, (w or 100) + 22))
  end
  b:Label(text)
  b:SetScript("OnClick", function(self) if onClick then Try(onClick, self) end end)
  return b
end

---------------------------------------------------------------------------
-- A list like the game's lists: WowScrollBoxList with the slim scroll bar; rows of one height.
-- opts.init(row, data): fills a row frame (made by the game, reused); l:SetRows(rows) shows them, the scroll place stays
---------------------------------------------------------------------------
function Bz.List(parent, opts)
  opts = opts or {}
  local l = {}
  l.box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
  l.bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(opts.rowHeight or Bz.ROW_H)
  view:SetElementFactory(function(factory)
    factory("Frame", function(row, data) Try(opts.init, row, data) end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(l.box, l.bar, view)
  l.view = view
  l.ground = Bz.Ground(parent, "item")
  function l:Place(anchor, left, top, right, bottom)
    self.ground:Place((left or 6) - 2, (right or 22) - 2, (top or 6) - 2, (bottom or 6) - 2)
    self.box:ClearAllPoints()
    self.box:SetPoint("TOPLEFT", anchor, "TOPLEFT", left or 6, -(top or 6))
    self.box:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -(right or 22), bottom or 6)
    self.bar:ClearAllPoints()
    self.bar:SetPoint("TOPLEFT", self.box, "TOPRIGHT", 5, -2)
    self.bar:SetPoint("BOTTOMLEFT", self.box, "BOTTOMRIGHT", 5, 2)
  end
  function l:SetRows(rows)
    self.rows = rows or {}
    local keep = type(ScrollBoxConstants) == "table" and ScrollBoxConstants.RetainScrollPosition or nil
    self.box:SetDataProvider(CreateDataProvider(self.rows), keep)
    Bz.ClampScroll(self.box)
    Bz.Settle(self.box)
  end
  return l
end

-- (Daniel 15.11.2026, Bild: two "Equipped" tooltips beside a row of Entzaubern: "die waffenvergleiche mit den angelegten
-- items stören natürlich bei profitdon, kann man sie da explizit ausstellen?") the game compares an item with the worn one
-- by itself when its option "always compare" is on (TooltipUtil.ShouldDoItemComparison: not
-- tooltip.suppressAutomaticCompareItem and the CVar). Blizzard's own switch for one tooltip is that flag, set after
-- SetOwner and before the item; the game clears it again when the tooltip hides. Shift still compares.
function Bz.NoCompare(tt)
  if type(tt) ~= "table" then return end
  local f = rawget(_G, "GameTooltip_SuppressAutomaticCompareItem")
  if type(f) == "function" then pcall(f, tt) else tt.suppressAutomaticCompareItem = true end
end

-- the colour of an item quality as the game writes it (r, g, b), white without one
function Bz.QualityRGB(q)
  local t = type(ITEM_QUALITY_COLORS) == "table" and q and ITEM_QUALITY_COLORS[q]
  if type(t) == "table" and t.r then return t.r, t.g, t.b end
  return 1, 1, 1
end

Bz.MAIN_TEMPLATES = { "PanelTabButtonTemplate", "UICheckButtonTemplate", "SearchBoxTemplate", "InputBoxTemplate" }
Bz.MAIN_FUNCS = { "PanelTemplates_SetNumTabs", "PanelTemplates_SetTab", "PanelTemplates_TabResize" }
function Bz.MissingMain()
  local miss = Bz.Missing()
  if miss then return miss end
  local X = C_XMLUtil
  for _, t in ipairs(Bz.MAIN_TEMPLATES) do
    local ok, info = pcall(X.GetTemplateInfo, t)
    if not (ok and info) then return "template " .. t end
  end
  for _, f in ipairs(Bz.MAIN_FUNCS) do if type(rawget(_G, f)) ~= "function" then return f end end
  return nil
end
-- the builder set for a window, nil when the kit has to do it
-- second value: what is missing (for the addon's diag line)
function Bz.Kit()
  if not Kit then return nil, "DonCore Kit" end
  local miss = Bz.MissingMain()
  if miss then return nil, miss end
  return K
end

local GOLD = { 1, 0.82, 0 }
local WHITE = { 1, 1, 1 }
local GREY = { 0.6, 0.6, 0.6 }
local Col3 -- (minor 5) declared here for the blocks above its body (Dropdown)
local function RGB(c, d)
  if type(c) == "table" and tonumber(c[1]) then return c[1], c[2], c[3] end
  d = d or WHITE
  return d[1], d[2], d[3]
end
local function Has(template)
  local ok, info = pcall(C_XMLUtil.GetTemplateInfo, template)
  return ok and info and true or false
end
local function Width(fs) return fs and fs.GetStringWidth and tonumber((fs:GetStringWidth())) or 0 end

-- a tooltip in the game's own style: title, then lines ("text", { left, right } or { text, color = })
local function Tip(owner, title, lines, anchor)
  local tt = GameTooltip
  if not (tt and tt.SetOwner) then return end
  tt:SetOwner(owner, anchor or "ANCHOR_RIGHT")
  if title and title ~= "" then tt:SetText(tostring(title), 1, 0.82, 0) end
  for _, l in ipairs(type(lines) == "table" and lines or {}) do
    if type(l) == "table" and l[2] ~= nil then tt:AddDoubleLine(tostring(l[1] or ""), tostring(l[2]), 0.7, 0.7, 0.7, 1, 1, 1)
    elseif type(l) == "table" then local r, g, b = RGB(l.color) tt:AddLine(tostring(l[1] or ""), r, g, b, true)
    elseif l then tt:AddLine(tostring(l), 1, 1, 1, true) end
  end
  tt:Show()
end
local function HideTip() if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end end
Bz.Tip = Tip
local function WithTip(f)
  function f:SetTooltip(title, lines) self._tip = (title and title ~= "") and { title, lines } or nil return self end
  f:HookScript("OnEnter", function(self) if self._tip then Tip(self, self._tip[1], self._tip[2]) end end)
  f:HookScript("OnLeave", HideTip)
  return f
end

---------------------------------------------------------------------------
-- Button: Blizzard's red button. opts.small, onClick, tooltip, tooltipLines, confirm (the first click asks "Sicher?")
---------------------------------------------------------------------------
function K.Button(parent, text, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetHeight(22)
  b.blizz = true -- (minor 5) a caller can tell it from the Kit's button
  b._onClick = opts.onClick
  local plain = b.SetText
  function b:SetText(t)
    self._label = t or ""
    plain(self, self._label)
    local w = self.GetTextWidth and tonumber((self:GetTextWidth())) or nil
    self.natural = math.max(48, (w or (#self._label * 7)) + 30)
    if not self._fixed then self:SetWidth(self.natural) end
  end
  function b:Layout(w) self._fixed = w self:SetWidth(w) end
  function b:SetDisabled(off) self._disabled = off and true or nil self:SetEnabled(not off) return self end
  function b:IsDisabled() return self._disabled == true end
  function b:SetKind() end
  -- (minor 5) held down while selected (a chip, an active choice), as the Kit's SetSelected
  function b:SetSelected(on)
    self._selected = on and true or nil
    if on then self:LockHighlight() else self:UnlockHighlight() end
    return self
  end
  function b:IsSelected() return self._selected == true end
  WithTip(b)
  if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  b:SetScript("OnClick", function(self, button)
    if self._disabled then return end
    if opts.confirm and not self._armed then
      self._armed, self._plain = true, self._label
      plain(self, type(opts.confirm) == "string" and opts.confirm or (Kit.SureWord and Kit.SureWord()) or "Sure?")
      After(3, function() if self._armed then self._armed = nil plain(self, self._plain or "") end end)
      return
    end
    if self._armed then self._armed = nil plain(self, self._plain or "") end
    if self._onClick then Try(self._onClick, self, button) end
  end)
  b:SetText(text)
  if opts.tooltip then b:SetTooltip(opts.tooltip, opts.tooltipLines) end
  return b
end

---------------------------------------------------------------------------
-- Toggle: the game's check box with its label. opts.label, get(), set(value); t:Update(), t.w by the caller
---------------------------------------------------------------------------
function K.Toggle(parent, opts)
  opts = opts or {}
  local t = CreateFrame("Frame", nil, parent)
  t:SetHeight(22)
  t.check = CreateFrame("CheckButton", nil, t, "UICheckButtonTemplate")
  t.check:SetSize(24, 24)
  t.check:SetPoint("LEFT", -2, 0)
  t.label = t:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  t.label:SetPoint("LEFT", t.check, "RIGHT", 0, 1)
  t.label:SetText(opts.label or "")
  t:SetWidth(24 + Width(t.label) + 4)
  function t:SetValue(v) self.value = v and true or false self.check:SetChecked(self.value) end
  function t:GetValue() return self.value end
  function t:Update() if opts.get then self:SetValue(opts.get()) end end
  t.check:SetScript("OnClick", function(c)
    t.value = c:GetChecked() and true or false
    if opts.set then Try(opts.set, t.value, t) end
  end)
  WithTip(t.check)
  function t:SetTooltip(title, lines) self.check:SetTooltip(title, lines) return self end
  t:Update()
  return t
end

---------------------------------------------------------------------------
-- SearchBox: the game's search field. opts.placeholder, width, onChange(text)
---------------------------------------------------------------------------
function K.SearchBox(parent, opts)
  opts = opts or {}
  local e = CreateFrame("EditBox", nil, parent, "SearchBoxTemplate")
  e:SetSize(opts.width or 150, 20)
  e:SetAutoFocus(false)
  if opts.placeholder and type(e.Instructions) == "table" and e.Instructions.SetText then e.Instructions:SetText(opts.placeholder) end
  e:HookScript("OnTextChanged", function(self) if opts.onChange then Try(opts.onChange, self:GetText() or "") end end)
  function e:Layout(w) self:SetWidth(w) end
  return e
end

-- a number or text box of the game (InputBoxTemplate) with the kit's calls: SetValue, GetValue, Layout, _focus
-- (minor 9, Daniel 20.11.2026: "mit Enter oder mit der Tab-Taste bestätigen ... wenn ich mit einem Linksklick irgendwo
-- auf dem Bildschirm das quasi auch erneuert wird") a click anywhere outside a Don edit box takes its focus: the box's
-- focus-lost handler commits what was typed, as Enter does. One watcher for all Don addons (frame DonCoreFocusWatch);
-- only boxes marked _donFocusOut are touched, never the chat or other addons' boxes.
local function WatchFocusOut(e)
  e._donFocusOut = true
  if _G.DonCoreFocusWatch or not CreateFrame then return end
  local w = CreateFrame("Frame", "DonCoreFocusWatch", UIParent)
  if not pcall(w.RegisterEvent, w, "GLOBAL_MOUSE_DOWN") then return end
  w:SetScript("OnEvent", function()
    local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if f and f._donFocusOut and f.ClearFocus and not (f.IsMouseOver and f:IsMouseOver()) then f:ClearFocus() end
  end)
end
function K.EditBox(parent, opts)
  opts = opts or {}
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  WatchFocusOut(e)
  e:SetSize(opts.width or 60, 20)
  e:SetAutoFocus(false)
  if opts.numeric then e:SetNumeric(true) e:SetJustifyH("CENTER") e:SetMaxLetters(opts.maxLetters or 7)
  elseif opts.maxLetters then e:SetMaxLetters(opts.maxLetters) end
  -- (minor 5) the Kit's placeholder: a quiet text while the box is empty
  e.hint = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  e.hint:SetPoint("LEFT", 2, 0)
  if e.hint.SetWordWrap then e.hint:SetWordWrap(false) end
  e.hint:SetText(opts.placeholder or "")
  -- (minor 10) opts.clear as in the Kit: a small x at the right while there is text; opts.onClear after it emptied the box
  if opts.clear then
    e.clear = CreateFrame("Button", nil, e)
    e.clear:SetSize(14, 14)
    e.clear:SetPoint("RIGHT", -3, 0)
    local t = e.clear:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    t:SetAlpha(0.6)
    e.clear.tex = t
    e.clear:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
    e.clear:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.6) end)
    e.clear:Hide()
    if e.SetTextInsets then e:SetTextInsets(0, 18, 0, 0) end
  end
  local function Hint(self)
    if (self:GetText() or "") == "" and (opts.placeholder or "") ~= "" and not self._focus then self.hint:Show() else self.hint:Hide() end
    if self.clear then if (self:GetText() or "") == "" then self.clear:Hide() else self.clear:Show() end end
  end
  if e.clear then
    e.clear:SetScript("OnClick", function()
      e:SetValue(nil)
      e:ClearFocus()
      if opts.onChange then Try(opts.onChange, "", e) end
      if opts.onClear then Try(opts.onClear, e) end
    end)
  end
  function e:SetValue(v)
    self._setting = true
    self:SetText(v ~= nil and tostring(v) or "")
    self._setting = nil
    if self.SetCursorPosition then self:SetCursorPosition(0) end
    Hint(self)
  end
  function e:GetValue() local t = self:GetText() if opts.numeric then return tonumber(t) end return t end
  function e:Layout(w) self:SetWidth(w) if self.hint.SetWidth then self.hint:SetWidth(math.max(4, w - 6)) end end
  function e:SetTooltip(title) self._tip = title and title ~= "" and { title } or nil end
  -- (minor 5) as the Kit: Tab goes on to this box
  function e:SetNext(other) self.nextBox = other return self end
  -- (minor 5) the Kit's states: greyed and shut while disabled; selection means nothing for a box
  function e:SetDisabled(off)
    self._disabled = off and true or nil
    if self.SetEnabled then self:SetEnabled(not off) end
    self:SetAlpha(off and 0.5 or 1)
    return self
  end
  function e:IsDisabled() return self._disabled == true end
  function e:SetSelected(on) self._selected = on and true or nil return self end
  function e:IsSelected() return self._selected == true end
  e:SetScript("OnEnter", function(self) if self._tip then Tip(self, self._tip[1]) end end)
  e:SetScript("OnLeave", HideTip)
  e:SetScript("OnTextChanged", function(self, user)
    Hint(self)
    if self._setting or user == false then return end
    if opts.onChange then Try(opts.onChange, self:GetText() or "", self) end
  end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() if opts.onEnter then Try(opts.onEnter, self) end end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- Tab leaves the box as in the Kit: the next box when one is set, else out of it; leaving commits (OnEditFocusLost)
  e:SetScript("OnTabPressed", function(self) if self.nextBox and self.nextBox.SetFocus then self.nextBox:SetFocus() else self:ClearFocus() end end)
  e:SetScript("OnEditFocusGained", function(self)
    self._focus = true
    self.hint:Hide()
    if self.HighlightText and opts.selectAll ~= false then self:HighlightText() end
  end)
  e:SetScript("OnEditFocusLost", function(self)
    self._focus = nil
    if self.HighlightText then self:HighlightText(0, 0) end
    -- (minor 5) a number is held between opts.min and opts.max when the box is left, as in the Kit
    if opts.numeric and (opts.min or opts.max) then
      local n = tonumber(self:GetText())
      if n then
        local c = math.max(tonumber(opts.min) or n, math.min(tonumber(opts.max) or n, n))
        if c ~= n then self:SetValue(c) end
      end
    end
    Hint(self)
    if opts.onLeave then Try(opts.onLeave, self) end
  end)
  Hint(e)
  return e
end

---------------------------------------------------------------------------
-- Dropdown: the game's dropdown button with a radio menu. opts.items (list or function), get(), set(value, d).
-- The template comes from Blizzard_Menu; where the client lacks it the kit's dropdown stands in.
-- (minor 5) the Kit's calls: d:Update(v) (the shown value; nil asks opts.get), d:Choose(v), d.value, d:Layout(w),
-- d:SetTooltip(title, lines) (the template's own SetTooltip takes a function: overwritten here), d:SetDisabled(off);
-- items { header = true, text } are a title, not to choose; item.right (item.rightColor) stands after the text
---------------------------------------------------------------------------
function K.Dropdown(parent, opts)
  opts = opts or {}
  if not Has("WowStyle1DropdownTemplate") then
    return Kit.Dropdown(parent, opts)
  end
  local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  d:SetHeight(22)
  d.blizz = true
  local function Items()
    local list = opts.items
    if type(list) == "function" then
      local ok, got = pcall(list)
      list = ok and got or nil
    end
    return type(list) == "table" and list or {}
  end
  local function Label(it)
    local t = it.text or tostring(it.value)
    if it.right ~= nil and it.right ~= "" then
      local r, g, b = Col3(it.rightColor, GREY)
      t = t .. ("   |cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), tostring(it.right))
    end
    return t
  end
  local function build(_, root)
    for _, it in ipairs(Items()) do
      if it.header then
        if root.CreateTitle then root:CreateTitle(it.text or "") end
      else
        root:CreateRadio(Label(it), function() return d.value == it.value end, function() d:Choose(it.value) end)
      end
    end
  end
  if d.SetupMenu then d:SetupMenu(build) end
  d.menuBuild = build -- (tests)
  function d:Update(v)
    if v == nil and opts.get then
      local ok, got = pcall(opts.get)
      if ok then v = got end
    end
    self.value = v
    local text = ""
    for _, it in ipairs(Items()) do if not it.header and it.value == v then text = it.text or tostring(v) end end
    self.shownText = text
    if self.OverrideText then pcall(self.OverrideText, self, text)
    elseif self.GenerateMenu then pcall(self.GenerateMenu, self) end
  end
  function d:Choose(v)
    self:Update(v)
    if opts.set then Try(opts.set, v, self) end
  end
  -- the caller lays it out on every draw: the shown value follows
  function d:Layout(w)
    self._w = w
    self:SetWidth(w)
    self:Update(self.value)
  end
  function d:SetDisabled(off) self._disabled = off and true or nil if self.SetEnabled then self:SetEnabled(not off) end return self end
  function d:IsDisabled() return self._disabled == true end
  WithTip(d) -- d:SetTooltip(title, lines) as the Kit's, over the template's own
  d:Layout(opts.width or 160)
  return d
end

---------------------------------------------------------------------------
-- ChipBar: a row of the game's small buttons, the active ones held down with white text. The Kit's calls (minor 5):
-- bar:Add(key, text, count, copts) (copts.onClick: a chip of its own without selection, copts.add), bar.active =
-- { [key] = true } (opts.multi: several), bar:SetActive(key, on), bar:Paint(), bar:Place() (a hidden chip takes no
-- room), bar:ContentWidth(), bar:Chip(key), bar:Layout(w), bar.offset (the wheel scrolls the chips sideways);
-- opts.onChange(key, on, bar, button)
---------------------------------------------------------------------------
function K.ChipBar(parent, opts)
  opts = opts or {}
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(24)
  if bar.SetClipsChildren then bar:SetClipsChildren(true) end
  if bar.EnableMouseWheel then bar:EnableMouseWheel(true) end
  bar.chips, bar.offset, bar.active, bar.blizz = {}, 0, {}, true
  function bar:Add(key, text, count, copts)
    copts = copts or {}
    local chip = K.Chip(self, text, function(c, button)
      if copts.onClick then Try(copts.onClick, c, button) return end
      if opts.multi then self.active[key] = not self.active[key] or nil
      else self.active = { [key] = true } end
      self:Paint()
      if opts.onChange then Try(opts.onChange, key, self.active[key] == true, self, button) end
    end, copts)
    if count ~= nil then chip:SetCount(count) end
    chip.key = key
    self.chips[#self.chips + 1] = chip
    chip:SetSelected(self.active[key])
    self:Place()
    return chip
  end
  function bar:SetActive(key, on)
    if not opts.multi then self.active = {} end
    if key ~= nil then self.active[key] = on ~= false or nil end
    self:Paint()
  end
  function bar:Paint() for _, c in ipairs(self.chips) do c:SetSelected(type(self.active) == "table" and self.active[c.key]) end end
  function bar:ContentWidth()
    local w, n = 0, 0
    for _, c in ipairs(self.chips) do
      if c:IsShown() then w = w + (tonumber(c:GetWidth()) or 0) + (n > 0 and 4 or 0) n = n + 1 end
    end
    return w
  end
  function bar:Place()
    local room = self._w or tonumber(self:GetWidth()) or 0
    self.offset = math.max(0, math.min(tonumber(self.offset) or 0, math.max(0, self:ContentWidth() - room)))
    local x = -self.offset
    for _, c in ipairs(self.chips) do
      c:ClearAllPoints()
      c:SetPoint("LEFT", self, "LEFT", x, 0)
      if c:IsShown() then x = x + (tonumber(c:GetWidth()) or 0) + 4 end
    end
  end
  function bar:Chip(key) for _, c in ipairs(self.chips) do if c.key == key then return c end end end
  function bar:Layout(w) self._w = w self:SetWidth(w) self:Place() end
  bar:SetScript("OnMouseWheel", function(self, d) self.offset = (self.offset or 0) - d * 40 self:Place() end)
  return bar
end

-- a row of controls from the right edge (the kit's PlaceRight): list = { { frame, width, show }, ... }
function K.PlaceRight(parent, list, opts)
  opts = opts or {}
  local rx, y, gap = tonumber(opts.x) or 8, tonumber(opts.y) or -6, tonumber(opts.gap) or 6
  for _, e in ipairs(list or {}) do
    local f, w = e[1], tonumber(e[2]) or 80
    if f then
      if e[3] == false then f:Hide()
      else
        f:Show()
        f:ClearAllPoints()
        f:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rx, y)
        if f.Layout then f:Layout(w) else f:SetWidth(w) end
        rx = rx + w + gap
      end
    end
  end
  return rx
end

---------------------------------------------------------------------------
-- Table: column heads (gold, a click sorts) over the game's scroll list. Items as the kit's table takes them:
-- kind "trow" (title, sub, icon, quality, itemID, cells[key], cellColors, titleColor, subColor, markColor, indent,
-- active, onRemove, edit = { key, value, onCommit, tip }, tipLines, tooltip) and "note" (text, color, warn).
---------------------------------------------------------------------------
local ROW, NOTE, HEAD = 36, 22, 24
-- the List's sizes and the parts of its rows (filled below the List); MAKER: kinds whose rows the Kit builds and this
-- module dresses (minor 5: sub, zone, cards, trow, done), filled at the end of the file
local LIST_BAR = 20
local KIND_H = { row = 36, group = 28, divider = 20, note = 28, table = 28, itemcards = 72,
  sub = 28, zone = 28, cards = 132, trow = 36, done = 22 }
local PART, MAKER = {}, {}
local function Visible(cols, w)
  local out = {}
  for i, c in ipairs(cols or {}) do if i > 1 and not (c.minWidth and w < c.minWidth) then out[#out + 1] = c end end
  return out
end

local function RowTip(r)
  local it = r.item
  if not it then return end
  if type(it.tooltip) == "table" then Tip(r, it.tooltip[1], it.tooltip[2]) return end
  local tt = GameTooltip
  if not (tt and tt.SetOwner) then return end
  tt:SetOwner(r, "ANCHOR_RIGHT")
  Bz.NoCompare(tt)
  if not (it.itemID and SetItem(tt, it)) then tt:SetText(tostring(it.title or ""), 1, 0.82, 0) end
  for _, l in ipairs(type(it.tipLines) == "table" and it.tipLines or {}) do
    if type(l) == "table" and l[2] ~= nil then tt:AddDoubleLine(tostring(l[1] or ""), tostring(l[2]), 0.7, 0.7, 0.7, 1, 1, 1)
    elseif type(l) == "table" then local cr, cg, cb = RGB(l.color) tt:AddLine(tostring(l[1] or ""), cr, cg, cb, true)
    elseif l then tt:AddLine(tostring(l), 1, 1, 1, true) end
  end
  tt:Show()
end

local function FillRow(tbl, r, it)
  if not r.built then
    r.built = true
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.sel:SetBlendMode("ADD")
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.hl:SetBlendMode("ADD")
    r.hl:SetAlpha(0.5)
    -- (Daniel 15.11.2026, Bild: "vielleicht auch je zeile einen feinen weißen trenner?") a fine light line under every row
    r.rule = r:CreateTexture(nil, "BORDER")
    r.rule:SetColorTexture(1, 1, 1, 0.07) -- (Daniel 15.11.2026: "Bisschen schwächer", it was 0.12)
    r.rule:SetHeight(1)
    r.rule:SetPoint("BOTTOMLEFT", 0, 0) r.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetWidth(3)
    r.mark:SetPoint("TOPLEFT", 0, -1) r.mark:SetPoint("BOTTOMLEFT", 0, 1)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.title = r:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    r.title:SetJustifyH("LEFT") r.title:SetWordWrap(false)
    r.sub = r:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    r.sub:SetJustifyH("LEFT") r.sub:SetWordWrap(false)
    r.cells = {}
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      local cur = self.item
      if not cur then return end
      -- (minor 5, Golddon's zones) a group folds as in the List: opts.onToggle(item, table)
      if cur.kind == "group" and not cur.static and not cur.onClick then
        cur.collapsed = not cur.collapsed
        if tbl.opts.onToggle then Try(tbl.opts.onToggle, cur, tbl) end
        return
      end
      if cur.kind ~= "trow" and cur.kind ~= "note" and cur.kind ~= nil and not tbl.opts.onClick then
        if cur.onClick then Try(cur.onClick, self, button) end
        return
      end
      if cur.itemID and type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK") and type(ChatEdit_InsertLink) == "function" then
        local _, link = Call(C_Item and C_Item.GetItemInfo or GetItemInfo, cur.itemID)
        if link and ChatEdit_InsertLink(link) then return end
      end
      if tbl.opts.onClick then Try(tbl.opts.onClick, cur, button, tbl) end
    end)
    r:SetScript("OnEnter", RowTip)
    r:SetScript("OnLeave", HideTip)
  end
  r.item = it
  local w = (tbl._w or 400) - 24
  -- (minor 5) other kinds of the List in a table (a group over its rows): drawn by the List's part, the row's own
  -- texts hidden
  r.parts = r.parts or {}
  local other = it.kind ~= nil and it.kind ~= "trow" and it.kind ~= "note" and PART[it.kind] and it.kind or nil
  for k, p in pairs(r.parts) do if k ~= other then p:Hide() end end
  if other then
    r.icon:Hide() r.sub:Hide() r.title:Hide() r.sel:Hide() r.mark:Hide() r.rule:Hide()
    for _, fs in ipairs(r.cells) do fs:Hide() end
    if r.x then r.x:Hide() end
    if r.edit then r.edit:Hide() end
    r.hl:SetAlpha((other == "group" and not it.static) and 0.5 or 0)
    local p = r.parts[other]
    if not p then
      p = CreateFrame("Frame", nil, r)
      p:SetAllPoints()
      PART[other].build(p)
      r.parts[other] = p
    end
    p:Show()
    PART[other].fill(p, it, w + 4, it.h or KIND_H[other] or ROW, tbl)
    return
  end
  r.title:Show()
  if it.kind == "note" then
    r.icon:Hide() r.sub:Hide() r.sel:Hide() r.mark:Hide() r.rule:Hide()
    for _, fs in ipairs(r.cells) do fs:Hide() end
    if r.x then r.x:Hide() end
    if r.edit then r.edit:Hide() end
    r.hl:SetAlpha(0)
    r.title:SetFontObject("GameFontHighlightSmall")
    r.title:SetText(it.text or "")
    if it.warn then r.title:SetTextColor(1, 0.1, 0.1) else r.title:SetTextColor(RGB(it.color, GREY)) end
    r.title:ClearAllPoints()
    r.title:SetPoint("LEFT", 8, 0)
    r.title:SetWidth(math.max(20, w - 12))
    return
  end
  r.hl:SetAlpha(0.5)
  r.rule:Show()
  r.sel:SetShown(it.active and true or false)
  if it.markColor then r.mark:SetColorTexture(RGB(it.markColor)) r.mark:Show() else r.mark:Hide() end
  local x = 6 + (tonumber(it.indent) or 0)
  if it.onRemove then
    if not r.x then
      r.x = K.Button(r, "x", { onClick = function() local cur = r.item if cur and cur.onRemove then Try(cur.onRemove, cur) end end })
      r.x:Layout(22)
    end
    r.x:SetTooltip(it.removeTip or "")
    r.x:ClearAllPoints() r.x:SetPoint("LEFT", x, 0)
    r.x:Show()
    x = x + 22 + 4
  elseif r.x then r.x:Hide() end
  if it.icon or it.itemID then
    r.icon:SetTexture(it.icon or Icon(it.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
    if it.unusable then r.icon:SetVertexColor(0.9, 0.15, 0.15) else r.icon:SetVertexColor(1, 1, 1) end
    r.icon:ClearAllPoints() r.icon:SetPoint("LEFT", x, 0)
    r.icon:Show()
    x = x + 28 + 6
  else r.icon:Hide() end
  r.title:SetFontObject("GameFontNormal")
  r.title:SetText(it.title or "")
  if it.titleColor then r.title:SetTextColor(RGB(it.titleColor))
  elseif it.quality then r.title:SetTextColor(Bz.QualityRGB(it.quality))
  else r.title:SetTextColor(1, 0.82, 0) end
  -- the fixed columns from the right edge
  local cols = tbl.columns or {}
  local vis = Visible(cols, tbl._w or 400)
  local cells = it.cells or {}
  local rx = 8
  for i = #vis, 1, -1 do
    local c = vis[i]
    local fs = r.cells[i]
    if not fs then
      fs = r:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      fs:SetWordWrap(false)
      r.cells[i] = fs
    end
    local cw = c.width or 80
    local edit = it.edit and it.edit.key == c.key
    fs:SetText((cells[c.key] ~= nil and not edit) and tostring(cells[c.key]) or "")
    fs:SetTextColor(RGB(it.cellColors and it.cellColors[c.key]))
    fs:SetJustifyH(c.align or "RIGHT")
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", -rx, 0)
    fs:SetWidth(cw - 6)
    fs:Show()
    if edit then
      if not r.edit then
        local function commit(box)
          local cur = r.item
          local ed = cur and cur.edit
          local n = box:GetValue()
          if ed and n and n >= 1 and n ~= ed.value and ed.onCommit then ed.value = n Try(ed.onCommit, cur, n) end
        end
        r.edit = K.EditBox(r, { numeric = true, width = 52, onEnter = commit, onLeave = commit })
      end
      r.edit:SetValue(it.edit.value)
      r.edit:SetTooltip(it.edit.tip)
      r.edit:ClearAllPoints()
      r.edit:SetPoint("RIGHT", -rx, 0)
      r.edit:Layout(math.max(36, math.min(60, cw - 8)))
      r.edit:Show()
    end
    rx = rx + cw
  end
  for i = #vis + 1, #r.cells do r.cells[i]:Hide() end
  if r.edit and not it.edit then r.edit:Hide() end
  -- the values of columns that went join the sub line
  local sub = it.sub or ""
  for i = 2, #cols do
    local c = cols[i]
    if c.fold and c.minWidth and (tbl._w or 400) < c.minWidth and cells[c.key] ~= nil and cells[c.key] ~= "" then
      sub = sub .. (sub ~= "" and "  " or "") .. (c.fold ~= true and (c.fold .. " ") or "") .. tostring(cells[c.key])
    end
  end
  r.sub:SetText(sub)
  r.sub:SetTextColor(RGB(it.subColor, GREY))
  local room = math.max(20, w - x - rx)
  r.title:ClearAllPoints() r.sub:ClearAllPoints()
  if sub ~= "" then
    r.title:SetPoint("TOPLEFT", x, -5)
    r.sub:SetPoint("TOPLEFT", x, -20)
    r.sub:SetWidth(room)
    r.sub:Show()
  else
    r.title:SetPoint("LEFT", x, 0)
    r.sub:Hide()
  end
  r.title:SetWidth(room)
end
Bz.FillRow = FillRow -- (tests)

function K.Table(parent, opts)
  opts = opts or {}
  local t = CreateFrame("Frame", nil, parent)
  t.opts, t.columns, t.items = opts, opts.columns or {}, {}
  t.head = CreateFrame("Frame", nil, t)
  t.head:SetHeight(HEAD)
  t.head:SetPoint("TOPLEFT") t.head:SetPoint("TOPRIGHT")
  t.head.line = t.head:CreateTexture(nil, "ARTWORK")
  t.head.line:SetColorTexture(1, 0.82, 0, 0.3)
  t.head.line:SetHeight(1)
  t.head.line:SetPoint("BOTTOMLEFT", 4, 0) t.head.line:SetPoint("BOTTOMRIGHT", -4, 0)
  t.head.btns = {}
  t.box = CreateFrame("Frame", nil, t, "WowScrollBoxList")
  t.bar = CreateFrame("EventFrame", nil, t, "MinimalScrollBar")
  t.box:SetPoint("TOPLEFT", 0, -HEAD)
  t.box:SetPoint("BOTTOMRIGHT", -20, 0)
  t.bar:SetPoint("TOPLEFT", t.box, "TOPRIGHT", 5, -2)
  t.bar:SetPoint("BOTTOMLEFT", t.box, "BOTTOMRIGHT", 5, 2)
  local view = CreateScrollBoxListLinearView()
  if view.SetElementExtentCalculator then
    view:SetElementExtentCalculator(function(_, it)
      return it.h or (it.kind == "note" and NOTE) or (it.kind ~= "trow" and it.kind ~= nil and PART[it.kind] and KIND_H[it.kind]) or ROW
    end)
  else view:SetElementExtent(ROW) end
  view:SetElementFactory(function(factory)
    factory("Button", function(row, it) Try(FillRow, t, row, it) end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(t.box, t.bar, view)
  t.view = view
  -- (Daniel 15.11.2026) the item column on brown ground with structure, the number columns on charcoal (Bz.Ground)
  t.groundItem, t.groundCells = Bz.Ground(t, "item"), Bz.Ground(t, "cells")
  t.empty = t:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  t.empty:SetPoint("TOP", 0, -HEAD - 24)
  t.empty:Hide()
  -- (Daniel 15.11.2026, Bild der Kopfzeile im Auktionshaus "Price | Name | Available": "zeilenbeschriftung gerne wie hier")
  -- the heads are the game's own column head buttons (ColumnDisplayButtonNoScriptsTemplate, SharedUIPanelTemplates.xml:
  -- the tab art of Interface\FriendsFrame\WhoFrame-ColumnTabs, 24 high), side by side over their columns, the text white
  -- and left, the sort arrow beside it. Without the template a plain button stands in.
  local headTpl = Has("ColumnDisplayButtonNoScriptsTemplate") and "ColumnDisplayButtonNoScriptsTemplate" or nil
  t.headTemplate = headTpl
  local function HeadBtn(i)
    local b = t.head.btns[i]
    if b then return b end
    b = CreateFrame("Button", nil, t.head, headTpl)
    b:SetHeight(HEAD)
    b.text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    b.text:SetWordWrap(false)
    b.text:SetJustifyH("LEFT")
    b.text:SetPoint("LEFT", 8, 0)
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(9, 8)
    b.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    b.arrow:SetVertexColor(1, 0.82, 0)
    b.arrow:SetPoint("LEFT", b.text, "RIGHT", 3, 0)
    -- (minor 8, Kit 30: Kit.HeadDrag) opts.onMove(fromKey, toKey, t): a head dragged onto another moves its column; a right
    -- click calls onMove(nil, nil, t), the list's own order back. The click that ends a drag does not sort.
    if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    b:SetScript("OnClick", function(self, button)
      if Kit.HeadDragged and Kit.HeadDragged(self) then return end
      if button == "RightButton" then if opts.onMove then Try(opts.onMove, nil, nil, t) end return end
      if self.col and self.col.sort and opts.onSort then Try(opts.onSort, self.col.key, t) end
    end)
    if opts.onMove and Kit.HeadDrag then
      Kit.HeadDrag(b, t.head, function() return t.columns[1] end, function(a, c) Try(opts.onMove, a, c, t) end)
    end
    t.head.btns[i] = b
    return b
  end
  -- (Daniel 15.11.2026: "und vielleicht auch der feine weiße rand mit eckigen kanten als spaltentrenner") a fine light
  -- line, straight and one pixel wide, down the list at the left edge of every number column
  t.seps = {}
  local function Sep(i)
    local l = t.seps[i]
    if not l then
      l = t:CreateTexture(nil, "BORDER")
      l:SetColorTexture(1, 1, 1, 0.16)
      l:SetWidth(1)
      t.seps[i] = l
    end
    return l
  end
  -- the left edge of every number column, counted from the table's right edge: the scroll bar (20), then the cells as
  -- the rows place them (8 from the row's edge, each c.width wide), 3 px of air before the next column's numbers
  function t:Edges()
    local w = self._w or 400
    local vis = Visible(self.columns, w)
    local edges, rx = {}, 8
    for i = #vis, 1, -1 do
      rx = rx + (vis[i].width or 80)
      edges[i] = 20 + rx - 3
    end
    return edges, vis
  end
  function t:DrawHead()
    local w = self._w or 400
    local edges, vis = self:Edges()
    local n = 0
    local function put(c, fromRight, width)
      n = n + 1
      local b = HeadBtn(n)
      b.col = c
      b:ClearAllPoints()
      b:SetPoint("RIGHT", self.head, "RIGHT", -fromRight, 0)
      b:SetWidth(math.max(20, width))
      local on = self.sortKey == c.key
      b.text:SetText(c.title or "")
      b.text:SetWidth(0)
      local room = math.max(10, width - 14 - (on and 12 or 0))
      if Width(b.text) > room then b.text:SetWidth(room) end
      if on then
        b.arrow:Show()
        if self.sortAsc then b.arrow:SetTexCoord(0, 0.5625, 1, 0) else b.arrow:SetTexCoord(0, 0.5625, 0, 1) end
      else b.arrow:Hide() end
      b:Show()
    end
    local right = 20
    for i = #vis, 1, -1 do
      put(vis[i], right, edges[i] - right)
      right = edges[i]
    end
    if self.columns[1] then put(self.columns[1], right, w - right) end
    for i = n + 1, #self.head.btns do self.head.btns[i]:Hide() end
    -- the lines between the columns, and the two grounds: they meet where the number columns begin; a table without
    -- number columns is all item ground
    for i = 1, #vis do
      local l = Sep(i)
      l:ClearAllPoints()
      l:SetPoint("TOP", self, "TOPRIGHT", -edges[i], -HEAD)
      l:SetPoint("BOTTOM", self, "BOTTOMRIGHT", -edges[i], 0)
      l:Show()
    end
    for i = #vis + 1, #self.seps do self.seps[i]:Hide() end
    local split = edges[1] or 20
    self.groundItem:Place(0, split, HEAD, 0)
    self.groundCells:Place(math.max(0, w - split), 20, HEAD, 0)
    self.groundCells:SetShown(#vis > 0 and Bz.light ~= false)
  end
  function t:Show0()
    local keep = type(ScrollBoxConstants) == "table" and ScrollBoxConstants.RetainScrollPosition or nil
    self.box:SetDataProvider(CreateDataProvider(self.items), keep)
    Bz.ClampScroll(self.box)
    Bz.Settle(self.box)
    if #self.items == 0 and self.emptyText and self.emptyText ~= "" then
      self.empty:SetText(self.emptyText)
      self.empty:SetWidth(math.max(40, (self._w or 400) - 40))
      self.empty:Show()
    else self.empty:Hide() end
  end
  function t:SetColumns(cols) self.columns = cols or {} self:DrawHead() end
  function t:SetSort(key, asc) self.sortKey, self.sortAsc = key, asc and true or nil self:DrawHead() end
  function t:SetItems(items)
    self.items = items or {}
    for _, it in ipairs(self.items) do if it.kind == nil then it.kind = "trow" end end
    self:Show0()
  end
  function t:SetEmpty(text) if self.emptyText ~= text then self.emptyText = text self:Show0() end end
  -- (minor 5) as the Kit's list: the item (or its index) into view, top = true at the top
  function t:ScrollTo(it, top) return Bz.ScrollTo(self.box, self.items, it, top) end
  function t:Layout(w, h)
    local changed = self._w ~= w
    self._w, self._h = w, h
    self:SetSize(w, h)
    self:DrawHead()
    if changed then self:Show0() end -- the columns that fit depend on the width
  end
  -- the kit's table keeps its rows in t.list: the same name for callers that look there
  t.list = t
  return t
end

---------------------------------------------------------------------------
-- ActionBar: symbol, title and a second line, the game's buttons on the right, a number box left of them
---------------------------------------------------------------------------
function K.ActionBar(parent)
  local a = CreateFrame("Frame", nil, parent)
  a:SetHeight(44)
  a.line = a:CreateTexture(nil, "ARTWORK")
  a.line:SetColorTexture(1, 0.82, 0, 0.3)
  a.line:SetHeight(1)
  a.line:SetPoint("TOPLEFT", 4, 0) a.line:SetPoint("TOPRIGHT", -4, 0)
  a.icon = a:CreateTexture(nil, "ARTWORK")
  a.icon:SetSize(30, 30)
  a.icon:SetPoint("LEFT", 8, 0)
  a.title = a:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  a.title:SetJustifyH("LEFT") a.title:SetWordWrap(false)
  a.sub = a:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  a.sub:SetJustifyH("LEFT") a.sub:SetWordWrap(false)
  a.actions, a.nActions = {}, 0
  function a:SetData(d)
    d = d or {}
    self.data = d
    if d.icon or d.itemID then
      self.icon:SetTexture(d.icon or Icon(d.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
      self.icon:Show()
    else self.icon:Hide() end
    self.title:SetText(d.title or "")
    if d.titleColor then self.title:SetTextColor(RGB(d.titleColor))
    elseif d.quality then self.title:SetTextColor(Bz.QualityRGB(d.quality))
    else self.title:SetTextColor(1, 0.82, 0) end
    self.sub:SetText(d.sub or "")
    self.sub:SetTextColor(RGB(d.subColor, GREY))
    self:Layout(self._w or self:GetWidth())
  end
  function a:SetActions(list)
    for _, b in ipairs(self.actions) do b:Hide() end
    for i, x in ipairs(list or {}) do
      local b = self.actions[i]
      if not b then b = K.Button(self, "", {}) self.actions[i] = b end
      b._fixed = nil
      b:SetText(x.text or "")
      b._onClick = x.onClick
      if x.tooltip then b:SetTooltip(x.tooltip[1], x.tooltip[2]) else b._tip = nil end
      b:SetDisabled(x.disabled)
      b:Show()
    end
    self.nActions = #(list or {})
    self:Layout(self._w or self:GetWidth())
  end
  function a:Input(opts)
    if not self.input then
      opts = opts or {}
      self.inputW = tonumber(opts.width) or 60
      self.input = K.EditBox(self, opts)
      self.input:Hide()
    end
    return self.input
  end
  function a:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    self:SetWidth(w)
    local rx = 8
    for i = self.nActions or 0, 1, -1 do
      local b = self.actions[i]
      local bw = math.min(b.natural or 80, math.max(60, math.floor(w * 0.6))) -- (Daniel 15.11.2026, Bild: "Kaufen: 760 für ..." ran over the edge at a third)
      b:ClearAllPoints()
      b:SetPoint("RIGHT", self, "RIGHT", -rx, 0)
      b:Layout(bw)
      rx = rx + bw + 4
    end
    local inp = self.input
    if inp and inp:IsShown() and (self.nActions or 0) > 0 then
      inp:ClearAllPoints()
      inp:SetPoint("RIGHT", self, "RIGHT", -(rx + 4), 0)
      inp:Layout(self.inputW)
      rx = rx + 4 + self.inputW + 6
    end
    local x = 8 + (self.icon:IsShown() and 36 or 0)
    self.title:ClearAllPoints() self.sub:ClearAllPoints()
    if (self.sub:GetText() or "") ~= "" then
      self.title:SetPoint("TOPLEFT", x, -7)
      self.sub:SetPoint("TOPLEFT", x, -24)
    else
      self.title:SetPoint("LEFT", x, 0)
    end
    local room = math.max(20, w - x - rx - 6)
    self.title:SetWidth(room)
    self.sub:SetWidth(room)
  end
  a:EnableMouse(true)
  a:SetScript("OnEnter", function(self)
    local d = self.data
    if d and (d.sub or "") ~= "" then Tip(self, d.title, { d.sub }, "ANCHOR_TOP") end
  end)
  a:SetScript("OnLeave", HideTip)
  return a
end

---------------------------------------------------------------------------
-- Window: Blizzard's frame (Blizz.lua Bz.Window) with the kit window's calls: w.body, w:AddTab(key, text), w.tabs,
-- w:SelectTab(key), w:SetStatus(text), w:Layout(), opts.onLayout(win, bodyWidth, bodyHeight, mode), onTab, onClose.
-- opts.attic (the main window): the body starts under the title, so its first row (the lists and controls) stands in
-- the strip beside the portrait and the list below fills the inset; w.atticX is where that row may start.
-- opts.footer: a status line in the strip under the inset. Tabs hang below the frame as at the auction house.
---------------------------------------------------------------------------
function K.Window(name, opts)
  opts = opts or {}
  local attic, footer = opts.attic and true or false, opts.footer and true or false
  local f
  local title = opts.title or ""
  if opts.subtitle and opts.subtitle ~= "" then title = title .. "  \194\183  " .. opts.subtitle end
  f = Bz.Window(name, { title = title, icon = opts.logo, store = opts.store, width = opts.width, height = opts.height,
    min = opts.min or { 520, 320 }, max = opts.max or { 1400, 1100 }, keepBar = footer,
    onHide = function() if opts.onClose then opts.onClose(f) end end,
    onLayout = function(win)
      if not win.body then return end -- a size change while the frame is still being made
      local w, h = win:GetWidth() or 0, win:GetHeight() or 0
      local bw, bh
      if attic then bw, bh = w - 18, h - 24 - (footer and 30 or 8)
      else bw, bh = w - 22, h - 64 - (footer and 30 or 10) end
      win.body:SetSize(math.max(10, bw), math.max(10, bh))
      win._w = w
      -- (minor 5) the Kit's mode by width (full, overlay, rail), the width taken at the Kit's scale (Bz.Mode)
      win.mode = Bz.Mode(w)
      if win.status then win.status:SetWidth(math.max(20, math.floor((w - 40) * (win.statusShare or 0.6)))) end
      if opts.onLayout then opts.onLayout(win, math.max(10, bw), math.max(10, bh), win.mode) end
    end })
  f.opts, f.tabs, f.blizz = opts, {}, true
  -- (minor 5, Daniel 16.11.2026: Gildenwappen "einbauen") f.logo as in the Kit: a frame over the round portrait with
  -- f.logo.tex (the addon's mark, an emblem) and f.logo.mask (the portrait's round mask, for textures the addon adds)
  if opts.logo then
    local pc = type(f.PortraitContainer) == "table" and f.PortraitContainer or nil
    local portrait = (pc and pc.portrait) or f.portrait
    local lg = CreateFrame("Frame", nil, pc or f)
    if type(portrait) == "table" and portrait.GetPoint then lg:SetAllPoints(portrait)
    else lg:SetSize(60, 60) lg:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 7) end
    if lg.SetFrameLevel and (pc or f).GetFrameLevel then lg:SetFrameLevel(((pc or f):GetFrameLevel() or 1) + 1) end
    lg.tex = lg:CreateTexture(nil, "ARTWORK")
    lg.tex:SetAllPoints()
    lg.tex:SetTexture(opts.logo)
    if type(lg.CreateMaskTexture) == "function" then
      local m = lg:CreateMaskTexture()
      if type(m) == "table" then
        m:SetAllPoints()
        m:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if lg.tex.AddMaskTexture then lg.tex:AddMaskTexture(m) end
        lg.mask = m
      end
    end
    f.logo = lg
  end
  f.atticX = attic and 56 or 0
  f.body = CreateFrame("Frame", nil, f)
  if attic then f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24) else f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -64) end
  if footer then
    -- (minor 5, Geardon) f.footer as in the Kit: a frame over the strip under the inset for the addon's own texts
    f.footer = CreateFrame("Frame", nil, f)
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 3)
    f.footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 3)
    f.footer:SetHeight(24)
    -- (minor 5, Vitaldon) the status on the left (f.statusShare of the strip, default 0.6), the right part of the
    -- strip stays free for the footer's own texts
    f.status = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.status:SetJustifyH("LEFT") f.status:SetWordWrap(false)
    f.status:SetPoint("BOTTOMLEFT", 12, 9)
    f.statusShare = 0.6
  end
  -- the Kit window's names: header (the strip to drag), close, gear (the cog of DonCore's options window)
  f.header = type(f.TitleContainer) == "table" and f.TitleContainer or f
  f.close = type(f.CloseButton) == "table" and f.CloseButton or nil
  if opts.options and Kit.IconButton then
    local O = LibStub("DonCore-1.0"):Get("Options", 1)
    if O and O.Open then
      f.gear = K.Button(f, O.Label and O.Label("Options") or "Options", { onClick = function() O.Open(opts.options) end })
      f.gear.donOptionsId = opts.options -- (minor 5) the Kit cog's field
      f.gear:SetHeight(20)
      f.gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, attic and -1 or -30)
      if opts.hint then f.gear:SetTooltip(O.Label and O.Label("Options") or "Options", { opts.hint }) end
    end
  end
  -- (minor 5, Dropdon) opts.buttons = { { kind (Style.ICONS), key, tooltip, hint, onClick(win) }, ... }: more symbols
  -- left of the cog, f.extra as in the Kit
  f.extra = {}
  local anchor = f.gear
  for _, bo in ipairs(opts.buttons or {}) do
    local b = Kit.IconButton(f, bo.kind, { size = 20, tooltip = bo.tooltip, hint = bo.hint,
      onClick = function() if bo.onClick then Try(bo.onClick, f) end end })
    b:ClearAllPoints()
    if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -4, 0)
    else b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, attic and -1 or -30) end
    b.key = bo.key
    f.extra[#f.extra + 1] = b
    anchor = b
  end
  -- (minor 5, Dropdon's size option) the window's own factor; the game's frame stands at 100 % beside the game's
  -- windows, so the factor is the scale itself
  function f:SetOwnScale(v)
    self._ownScale = tonumber(v) or 1
    self:SetScale(self._ownScale)
  end
  function f:SetSubtitle(text)
    if self.SetTitle then self:SetTitle((opts.title or "") .. ((text and text ~= "") and ("  \194\183  " .. text) or "")) end
  end
  -- text, and as the Kit's: a click on it and a tooltip
  function f:SetStatus(text, onClick, tooltip)
    if not self.status then return end
    self.status:SetText(text or "")
    if onClick and not self.statusBtn then
      self.statusBtn = CreateFrame("Button", nil, self)
      self.statusBtn:SetAllPoints(self.status)
      WithTip(self.statusBtn)
      self.statusBtn:SetScript("OnClick", function(b) if b._onClick then Try(b._onClick, self) end end)
    end
    if self.statusBtn then
      self.statusBtn._onClick = onClick
      self.statusBtn:SetShown(onClick and true or false)
      self.statusBtn:SetTooltip(tooltip)
    end
  end
  function f:AddTab(key, text)
    local i = #self.tabs + 1
    local tab = CreateFrame("Button", name and (name .. "Tab" .. i) or nil, self, "PanelTabButtonTemplate")
    tab.key, tab.name = key, text
    tab:SetID(i)
    tab:SetText(text)
    if i == 1 then tab:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 11, 2) else tab:SetPoint("TOPLEFT", self.tabs[i - 1], "TOPRIGHT", 3, 0) end
    tab:SetScript("OnClick", function() self:SelectTab(key) end)
    -- a mark where something waits in another tab
    function tab:SetSelected(on) if on then pcall(PanelTemplates_SetTab, f, i) end return self end
    function tab:SetAlert(on)
      on = on and true or false
      if self._alert == on then return end
      self._alert = on
      self:SetText(on and (self.name .. " |cff20ff20!|r") or self.name)
      pcall(PanelTemplates_TabResize, self, 0)
    end
    self.tabs[i] = tab
    pcall(PanelTemplates_SetNumTabs, self, i)
    pcall(PanelTemplates_TabResize, tab, 0)
    return tab
  end
  function f:SelectTab(key)
    self.tab = key
    for i, t in ipairs(self.tabs) do if t.key == key then pcall(PanelTemplates_SetTab, self, i) end end
    if opts.onTab then Try(opts.onTab, key, self) end
  end
  if not f:Restore() then f:ClearAllPoints() f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
  f:Layout()
  return f
end

---------------------------------------------------------------------------
-- The Kit's content blocks in the game's look (15.11.2026, Luredon's fishing book as the pilot): Text, Fit, Tile, List
-- (kinds row, group, divider, note, table, itemcards), TableHead, Hero, Detail, Segmented, BarList. The calls, methods
-- and fields are the Kit's (DonCore/Kit.lua), the drawing is the game's: its fonts (GameFontNormal gold,
-- GameFontHighlight white), the tooltip border around a box, the quest log's highlight on a row, the plus and minus
-- buttons at a group, the status bar texture in a bar, GameTooltip for every tooltip.
-- (minor 5) the parts and kinds missing here at first (pill, dots, ring, chain, radio; sub, zone, cards, trow, done)
-- are built now, see the end of the file.
---------------------------------------------------------------------------
local S = Kit and Kit.SIZE or {}
local HILITE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local BARTEX = "Interface\\TargetingFrame\\UI-StatusBar"

-- a colour as the Kit takes it: a key of Kit.C or Kit.STATUS, or { r, g, b }
function Col3(c, d)
  if type(c) == "string" and Kit then
    local k = (Kit.C and Kit.C[c]) or (Kit.STATUS and Kit.STATUS[c] and Kit.STATUS[c].fg)
    if type(k) == "table" then c = k end
  end
  if type(c) == "table" and tonumber(c[1]) then return c[1], c[2], c[3] end
  d = d or WHITE
  return d[1], d[2], d[3]
end
Bz.Col3 = Col3

-- the game's fonts for the Kit's roles
Bz.FONTS = { hero = "GameFontNormalHuge", title = "GameFontNormalLarge", tab = "GameFontNormal", group = "GameFontNormalSmall",
  row = "GameFontHighlight", button = "GameFontNormal", sub = "GameFontHighlightSmall", mono = "GameFontHighlightSmall",
  badge = "GameFontHighlightSmall" }
local function FS(parent, role, color, layer)
  local fs = parent:CreateFontString(nil, layer or "ARTWORK", Bz.FONTS[role] or "GameFontHighlight")
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  if color then fs:SetTextColor(Col3(color)) end
  return fs
end
function K.Text(parent, role, color, justify)
  local fs = FS(parent, role, color)
  if justify and fs.SetJustifyH then fs:SetJustifyH(justify) end
  return fs
end
-- one line cut by the game ("...") at the width
function K.Fit(fs, width)
  if not (fs and fs.SetWidth) then return end
  fs:SetWidth(math.max(4, tonumber(width) or 4))
end
-- (minor 5) the game's fonts on the texts of a block the Kit built: map = { field = "GameFontNormal", ... }; the Kit's
-- fitting starts again from the new font
local function BlizzFonts(o, map)
  if type(o) ~= "table" then return o end
  for k, font in pairs(map) do
    local fs = o[k]
    if type(fs) == "table" and fs.SetFontObject then
      pcall(fs.SetFontObject, fs, font)
      fs._fitBase, fs._fitSize = nil, nil
    end
  end
  return o
end
Bz.BlizzFonts = BlizzFonts

-- a box with the game's tooltip border on a dark ground; without the backdrop template a plain dark ground
local BOX = { bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }
local function BoxFrame(kind, parent)
  local f = CreateFrame(kind or "Frame", nil, parent, Has("BackdropTemplate") and "BackdropTemplate" or nil)
  if f.SetBackdrop and f.SetBackdropColor then
    f:SetBackdrop(BOX)
    f:SetBackdropColor(0.09, 0.08, 0.07, 0.85)
    f:SetBackdropBorderColor(0.6, 0.55, 0.45, 1)
    f.boxed = true
  else
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.09, 0.08, 0.07, 0.85)
  end
  function f:SetEdge(r, g, b) if self.boxed then self:SetBackdropBorderColor(r, g, b, 1) end end
  return f
end
Bz.Box = BoxFrame

-- a bar from the game's status bar texture: b:SetValue01(0..1), b:SetColor(key or rgb), b:Layout(w), b.value
local function Bar(parent, h)
  local b = CreateFrame("StatusBar", nil, parent)
  b:SetHeight(h or 6)
  if b.SetStatusBarTexture then b:SetStatusBarTexture(BARTEX) end
  if b.SetMinMaxValues then b:SetMinMaxValues(0, 1) end
  b.back = b:CreateTexture(nil, "BACKGROUND")
  b.back:SetAllPoints()
  b.back:SetColorTexture(0, 0, 0, 0.5)
  function b:SetValue01(v)
    self.value = math.max(0, math.min(1, tonumber(v) or 0))
    if self.SetValue then self:SetValue(self.value) end
  end
  function b:SetColor(c)
    local r, g, bl = Col3(c, GOLD)
    if self.SetStatusBarColor then self:SetStatusBarColor(r, g, bl) end
  end
  function b:Layout(w) self:SetWidth(math.max(1, w)) end
  b:SetColor(nil)
  b:SetValue01(0)
  return b
end
Bz.Bar = Bar

-- the Kit's tooltip arguments in the game's tooltip: title (text or { text, sub = }), lines ("text", { label, value,
-- color }, { header = }), hint (grey, last)
local function KitTip(owner, title, lines, hint, anchor)
  local tt = GameTooltip
  if not (tt and tt.SetOwner) or title == nil then return false end
  local sub
  if type(title) == "table" then title, sub = title.text or title[1], title.sub end
  tt:SetOwner(owner, anchor or "ANCHOR_RIGHT")
  tt:SetText(tostring(title or ""), 1, 0.82, 0)
  if sub and sub ~= "" then tt:AddLine(tostring(sub), 0.7, 0.7, 0.7, true) end
  for _, l in ipairs(type(lines) == "table" and lines or {}) do
    if type(l) == "table" and l.header then tt:AddLine(tostring(l.header), 1, 0.82, 0)
    elseif type(l) == "table" and l[2] ~= nil then
      local r, g, b = Col3(l[3])
      tt:AddDoubleLine(tostring(l[1] or ""), tostring(l[2]), 0.7, 0.7, 0.7, r, g, b)
    elseif type(l) == "table" then tt:AddLine(tostring(l[1] or ""), 1, 1, 1, true)
    elseif l then tt:AddLine(tostring(l), 1, 1, 1, true) end
  end
  if hint and hint ~= "" then tt:AddLine(tostring(hint), 0.5, 0.5, 0.5, true) end
  tt:Show()
  return true
end
Bz.KitTip = KitTip

-- the tooltip of a row, card, tile or hero: tooltipFn(owner) -> title, lines, hint; else item.tooltip; else the item
local function ShowTipOf(owner, it, tipFn)
  if type(tipFn) == "function" then
    local ok, title, lines, hint = pcall(tipFn, owner)
    if ok and title and KitTip(owner, title, lines, hint) then return end
  end
  if type(it) == "table" and type(it.tooltip) == "table" then KitTip(owner, it.tooltip[1], it.tooltip[2], it.tooltip[3]) return end
  if type(it) == "table" and it.itemID and GameTooltip and GameTooltip.SetItemByID then
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    Bz.NoCompare(GameTooltip)
    SetItem(GameTooltip, it)
    for _, l in ipairs(type(it.tipLines) == "table" and it.tipLines or {}) do
      if type(l) == "table" and l[2] ~= nil then GameTooltip:AddDoubleLine(tostring(l[1] or ""), tostring(l[2]), 0.7, 0.7, 0.7, 1, 1, 1)
      elseif l then GameTooltip:AddLine(tostring(type(l) == "table" and l[1] or l), 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end
end

-- shift-click on an item puts its link into the chat line
local function LinkItem(id)
  if not (id and type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK") and type(ChatEdit_InsertLink) == "function") then return false end
  local _, link = Call((C_Item and C_Item.GetItemInfo) or rawget(_G, "GetItemInfo"), id)
  return link and ChatEdit_InsertLink(link) and true or false
end

local function SetIcon(tex, it)
  if it.iconKind then
    local Style = LibStub("DonCore-1.0"):Get("Style", 3)
    if Style and Style.SetIcon and pcall(Style.SetIcon, tex, it.iconKind) then return true end
  end
  local file = it.icon or (it.itemID and Icon(it.itemID))
  if not file then return false end
  tex:SetTexture(file)
  if tex.SetTexCoord then
    local c = it.iconCoords
    if type(c) == "table" then tex:SetTexCoord(c[1], c[2], c[3], c[4]) else tex:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
  end
  return true
end

---------------------------------------------------------------------------
-- Tile: a box with a small gold label, a big value and a line below; opts.height, art, side, onClick
---------------------------------------------------------------------------
function K.Tile(parent, opts)
  opts = opts or {}
  local t = BoxFrame("Button", parent)
  t:SetHeight(opts.height or 72)
  t.artSize, t.sideW = tonumber(opts.art) or 0, tonumber(opts.side) or 0
  t.hl = t:CreateTexture(nil, "HIGHLIGHT")
  t.hl:SetPoint("TOPLEFT", 4, -4) t.hl:SetPoint("BOTTOMRIGHT", -4, 4)
  t.hl:SetTexture(HILITE)
  if t.hl.SetBlendMode then t.hl:SetBlendMode("ADD") end
  t.hl:SetAlpha(opts.onClick and 0.35 or 0)
  t.label = FS(t, "group", GOLD)
  t.value = FS(t, "hero", WHITE)
  t.line = FS(t, "sub", GREY)
  t.bar = Bar(t, 5)
  t.bar:Hide()
  if t.artSize > 0 then
    t.art = CreateFrame("Frame", nil, t)
    t.art:SetSize(t.artSize, t.artSize)
    t.art:SetPoint("LEFT", 10, 0)
  end
  if t.sideW > 0 then
    t.side = CreateFrame("Frame", nil, t)
    t.side:SetPoint("TOPRIGHT", -10, -10) t.side:SetPoint("BOTTOMRIGHT", -10, 10)
    t.side:SetWidth(t.sideW)
  end
  t._cutTexts = { t.label, t.value, t.line }
  function t:SetData(label, value, line, color)
    self.label:SetText(label or "")
    self.value:SetText(value ~= nil and tostring(value) or "")
    self.value:SetTextColor(Col3(color, WHITE))
    self.line:SetText(line or "")
    if self._w then self:Layout(self._w) end
  end
  function t:SetProgress(frac, color)
    if frac == nil then self.bar:Hide() self._bar = nil
    else
      self._bar = true
      self.bar:SetColor(color)
      self.bar:SetValue01(frac)
      self.bar:Show()
    end
    if self._w then self:Layout(self._w) end
  end
  function t:Layout(w)
    self._w = w
    self:SetWidth(w)
    local x = 10 + (self.artSize > 0 and (self.artSize + 8) or 0)
    local room = math.max(10, w - x - 10 - (self.sideW > 0 and (self.sideW + 8) or 0))
    self.label:ClearAllPoints() self.value:ClearAllPoints() self.line:ClearAllPoints() self.bar:ClearAllPoints()
    self.label:SetPoint("TOPLEFT", x, -10)
    self.value:SetPoint("LEFT", x, 0)
    self.line:SetPoint("BOTTOMLEFT", x, self._bar and 17 or 9)
    self.bar:SetPoint("BOTTOMLEFT", x, 9)
    self.bar:Layout(room)
    K.Fit(self.label, room) K.Fit(self.value, room) K.Fit(self.line, room)
  end
  function t:SetSelected(on)
    self._selected = on and true or nil
    if on then self:SetEdge(1, 0.82, 0) else self:SetEdge(0.6, 0.55, 0.45) end
    return self
  end
  function t:SetTooltip(title, lines, hint) self._tip = title and { title, lines, hint } or nil return self end
  if t.RegisterForClicks then t:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  t:SetScript("OnClick", function(self, button) if opts.onClick then Try(opts.onClick, self, button) end end)
  t:SetScript("OnEnter", function(self) ShowTipOf(self, self._tip and { tooltip = self._tip } or nil, self._tipFn) end)
  t:SetScript("OnLeave", HideTip)
  if opts.label or opts.value then t:SetData(opts.label, opts.value, opts.line, opts.color) end
  return t
end

---------------------------------------------------------------------------
-- List: the game's scroll list with the slim scroll bar, one row frame for every kind of item (the game reuses the
-- frames, so a row holds a part per kind and shows the one its item needs).
-- l:SetItems(items, reset), l:SetEmpty(text), l:Resize(w, h), l:Rows(), l:Select(item), l.items, l.columns (TableHead)
---------------------------------------------------------------------------
-- (LIST_BAR, KIND_H, PART and MAKER are declared before the Table, which draws groups with the List's parts)

-- kind "row": mark, lead, icon or level, title and sub line, one or two texts on the right
PART.row = {
  build = function(p)
    p.lead = FS(p, "sub", GREY)
    p.lead:SetJustifyH("RIGHT")
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetSize(24, 24)
    p.level = FS(p, "sub", WHITE)
    p.title = FS(p, "tab", GOLD)
    p.sub = FS(p, "sub", GREY)
    p.right = FS(p, "row", WHITE)
    p.right:SetJustifyH("RIGHT")
    p.right2 = FS(p, "sub", GREY)
    p.right2:SetJustifyH("RIGHT")
  end,
  fill = function(p, it, w, h)
    local x = 3 + 8 + (tonumber(it.indent) or 0)
    p.lead:ClearAllPoints()
    if it.lead and it.lead ~= "" then
      p.lead:SetText(it.lead)
      p.lead:SetTextColor(Col3(it.leadColor, GREY))
      p.lead:SetPoint("LEFT", x, 0)
      p.lead:SetWidth(S.lead or 42)
      p.lead:Show()
      x = x + (S.lead or 42) + 8
    else p.lead:Hide() end
    -- (minor 5) item.radio (true / false): the game's choice point on the left, as in the Kit
    if it.radio ~= nil then
      if not p.radio then p.radio = K.Radio(p) if p.radio.EnableMouse then p.radio:EnableMouse(false) end end
      p.radio:SetChecked(it.radio)
      p.radio:ClearAllPoints()
      p.radio:SetPoint("LEFT", x, 0)
      p.radio:Show()
      x = x + 16 + 8
    elseif p.radio then p.radio:Hide() end
    p.icon:ClearAllPoints() p.level:ClearAllPoints()
    local lvColor = it.levelStatus or (tonumber(it.level) and Kit.QuestDifficulty and Kit.QuestDifficulty(it.level)) or it.status
    local levelRight = false
    if (it.icon or it.iconKind) and SetIcon(p.icon, it) then
      local s = it.iconPlain and 16 or 24
      p.icon:SetSize(s, s)
      p.icon:SetPoint("LEFT", x, 0)
      p.icon:Show() p.level:Hide()
      x = x + s + 8
      levelRight = it.badgeRight and it.level ~= nil -- (minor 5) the level in the right column, the symbol on the left
    elseif it.level ~= nil and it.radio == nil then
      p.icon:Hide()
      p.level:SetText("[" .. tostring(it.level) .. "]")
      p.level:SetTextColor(Col3(lvColor, GREY))
      p.level:SetPoint("LEFT", x, 0)
      p.level:SetWidth(30)
      p.level:Show()
      x = x + 30 + 6
    else p.icon:Hide() p.level:Hide() end
    -- (minor 5) a chain mark ("4a", or item.mark) after the level, green with a tick when the part is done
    local m = it.chain ~= nil and it.chain or it.mark
    local ch = (type(m) == "string" or type(m) == "number") and tostring(m) or nil
    if ch then
      if not p.chain then p.chain = K.ChainMark(p, "") end
      p.chain:SetText(ch)
      p.chain:SetDone(it.chainDone)
      p.chain:ClearAllPoints()
      p.chain:SetPoint("LEFT", x, 0)
      p.chain:Show()
      x = x + (tonumber(p.chain.width or (p.chain.GetWidth and p.chain:GetWidth())) or 26) + 6
    elseif p.chain then p.chain:Hide() end
    local colW = tonumber(it.rightWidth) or ((it.right or it.right2) and 96 or 0)
    p.right:ClearAllPoints() p.right2:ClearAllPoints()
    p.right:SetText(it.right or "")
    p.right:SetTextColor(Col3(it.rightColor, WHITE))
    p.right2:SetText(it.right2 or "")
    p.right2:SetTextColor(Col3(it.right2Color, GREY))
    if it.right2 and it.right2 ~= "" then
      p.right:SetPoint("TOPRIGHT", -12, -math.max(3, math.floor((h - 36) / 2) + 5))
      p.right2:SetPoint("TOPRIGHT", -12, -math.max(3, math.floor((h - 36) / 2) + 5) - 15)
    else p.right:SetPoint("RIGHT", -12, 0) end
    p.right:SetWidth(math.max(4, colW)) p.right2:SetWidth(math.max(4, colW))
    -- (minor 5) a ring "3/6", a pill or the dots of a chain left of the right column; the level there with badgeRight
    local rx = 12 + colW + (colW > 0 and 6 or 0)
    local part
    if type(it.ring) == "table" then
      if not p.ring then p.ring = Kit.Ring(p, 28) BlizzFonts(p.ring, { text = "GameFontHighlightSmall" }) end
      p.ring:SetValue(it.ring[1], it.ring[2])
      part = p.ring
    elseif p.ring then p.ring:Hide() end
    if not part and type(it.pill) == "table" then
      if not p.pill then p.pill = K.Pill(p) end
      p.pill:SetPill(it.pill[1], it.pill[2])
      part = p.pill
    elseif p.pill then p.pill:Hide() end
    if not part and it.dots then
      if not p.dots then p.dots = Kit.Dots(p) end
      p.dots:SetDots(it.dots)
      part = p.dots
    elseif p.dots then p.dots:Hide() end
    if part then
      part:ClearAllPoints()
      part:SetPoint("RIGHT", -rx, 0)
      part:Show()
      rx = rx + (tonumber(part.width or (part.GetWidth and part:GetWidth())) or 28) + 6
    end
    if levelRight then
      p.level:SetText("[" .. tostring(it.level) .. "]")
      p.level:SetTextColor(Col3(lvColor, GREY))
      p.level:SetJustifyH("RIGHT")
      p.level:SetPoint("RIGHT", -rx, 0)
      p.level:SetWidth(30)
      p.level:Show()
      rx = rx + 36
    else p.level:SetJustifyH("LEFT") end
    colW = math.max(colW, rx - 12 - 6)
    p.title:SetText(it.title or "")
    if it.titleColor then p.title:SetTextColor(Col3(it.titleColor))
    elseif it.quality then p.title:SetTextColor(Bz.QualityRGB(it.quality))
    elseif it.active then p.title:SetTextColor(1, 1, 1)
    else p.title:SetTextColor(1, 0.82, 0) end
    local sub = it.sub or ""
    p.sub:SetText(sub)
    p.sub:SetTextColor(Col3(it.subColor, GREY))
    local room = math.max(20, w - x - 12 - colW - 8)
    p.title:ClearAllPoints() p.sub:ClearAllPoints()
    if sub ~= "" then
      local top = math.max(3, math.floor((h - 36) / 2) + 5)
      p.title:SetPoint("TOPLEFT", x, -top)
      p.sub:SetPoint("TOPLEFT", x, -top - 15)
      p.sub:SetWidth(room)
      p.sub:Show()
    else
      p.title:SetPoint("LEFT", x, 0)
      p.sub:Hide()
    end
    p.title:SetWidth(room)
    p:SetAlpha(it.done and 0.72 or 1)
  end,
}

-- kind "group": the game's plus or minus button, gold text, a number on the right
-- (minor 7) it.indent: pixels the button and the text move right (a sub group, Profitdon writs: zones under continents)
PART.group = {
  build = function(p)
    p.band = p:CreateTexture(nil, "BACKGROUND")
    p.band:SetPoint("TOPLEFT", 0, -1) p.band:SetPoint("BOTTOMRIGHT", 0, 1)
    p.band:SetColorTexture(1, 0.82, 0, 0.07)
    p.arrow = p:CreateTexture(nil, "ARTWORK")
    p.arrow:SetSize(14, 14)
    p.arrow:SetPoint("LEFT", 8, 0)
    p.text = FS(p, "tab", GOLD)
    p.count = FS(p, "sub", GREY)
    p.count:SetJustifyH("RIGHT")
    p.count:SetPoint("RIGHT", -12, 0)
  end,
  fill = function(p, it, w)
    local ind = tonumber(it.indent) or 0
    p.arrow:ClearAllPoints()
    p.arrow:SetPoint("LEFT", 8 + ind, 0)
    if it.static then p.arrow:Hide()
    else
      p.arrow:SetTexture(it.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
      p.arrow:Show()
    end
    p.text:SetText(it.text or "")
    p.text:SetTextColor(Col3(it.color, GOLD))
    p.text:ClearAllPoints()
    p.text:SetPoint("LEFT", (it.static and 12 or 28) + ind, 0)
    -- the Kit writes right and count side by side; a caller that gives the same number twice gets it once
    local right = it.right ~= nil and tostring(it.right) or ""
    if it.count ~= nil and tostring(it.count) ~= right then right = right .. (right ~= "" and "  " or "") .. tostring(it.count) end
    -- (minor 4) the right text takes the room it needs ("Zones: 23"), the title the rest
    p.count:SetText(right)
    local cw = right ~= "" and math.max(24, math.min(math.floor(w * 0.45), Width(p.count) + 4)) or 0
    p.text:SetWidth(math.max(20, w - (it.static and 12 or 28) - ind - cw - 20))
  end,
}

-- kind "divider": a quiet gold line of text over a rule (a day in a log)
PART.divider = {
  build = function(p)
    p.text = FS(p, "group", GOLD)
    p.text:SetPoint("LEFT", 12, 0)
    p.right = FS(p, "sub", GREY)
    p.right:SetJustifyH("RIGHT")
    p.right:SetPoint("RIGHT", -12, 0)
    p.rule = p:CreateTexture(nil, "BORDER")
    p.rule:SetColorTexture(1, 0.82, 0, 0.3)
    p.rule:SetHeight(1)
    p.rule:SetPoint("BOTTOMLEFT", 8, 0) p.rule:SetPoint("BOTTOMRIGHT", -8, 0)
  end,
  fill = function(p, it, w)
    p.text:SetText(it.text or "")
    p.right:SetText(it.right or "")
    p.right:SetWidth(math.max(20, math.floor(w * 0.4)))
    p.text:SetWidth(math.max(20, math.floor(w * 0.55)))
  end,
}

-- kind "note": one small line (red when it warns)
PART.note = {
  build = function(p)
    p.text = FS(p, "sub", GREY)
    p.text:SetPoint("LEFT", 12, 0)
    p.right = FS(p, "sub", GOLD)
    p.right:SetJustifyH("RIGHT")
    p.right:SetPoint("RIGHT", -12, 0)
  end,
  fill = function(p, it, w)
    p.text:SetText(it.text or "")
    if it.warn then p.text:SetTextColor(1, 0.1, 0.1) else p.text:SetTextColor(Col3(it.color, GREY)) end
    p.right:SetText(it.right or "")
    p.right:SetWidth(it.right and 120 or 4)
    p.text:SetWidth(math.max(20, w - 24 - (it.right and 124 or 0)))
  end,
}

-- kind "table": cells under the columns of the bound TableHead; a cell is a text, { text, color } or { bar =, text = }
PART.table = {
  build = function(p)
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetSize(16, 16)
    p.icon:SetPoint("LEFT", 11, 0)
    p.cells, p.bars = {}, {}
  end,
  fill = function(p, it, w, _, list)
    local columns = list.columns or {}
    local cols = Kit.TableCols(columns, w, list.tableIcon)
    if list.tableIcon and (it.icon or it.itemID) and SetIcon(p.icon, it) then p.icon:Show() else p.icon:Hide() end
    for i, c in ipairs(cols) do
      local def = columns[i] or {}
      local v = type(it.cells) == "table" and it.cells[i] or nil
      local fs = p.cells[i]
      if not fs then fs = FS(p, i == 1 and "row" or "sub", WHITE) p.cells[i] = fs end
      local text, color, bar = v, nil, nil
      if type(v) == "table" then text, color, bar = v.text or v[1], v.color or v[2], v.bar end
      local x, cw = c.x or c[1] or 0, c.w or c[2] or 60
      local slot = bar ~= nil and math.min(48, math.floor(cw * 0.4)) or cw
      fs:SetText(text ~= nil and tostring(text) or "")
      if color then fs:SetTextColor(Col3(color))
      elseif i == 1 and it.quality then fs:SetTextColor(Bz.QualityRGB(it.quality))
      elseif i == 1 then fs:SetTextColor(Col3(it.titleColor, GOLD))
      else fs:SetTextColor(0.8, 0.8, 0.8) end
      fs:ClearAllPoints()
      if bar ~= nil or def.justify == "RIGHT" then
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", p, "LEFT", x + cw, 0)
      else
        fs:SetJustifyH("LEFT")
        fs:SetPoint("LEFT", x, 0)
      end
      fs:SetWidth(math.max(4, slot))
      fs:Show()
      local b = p.bars[i]
      if bar ~= nil then
        if not b then b = Bar(p, 8) p.bars[i] = b end
        b:SetColor(v.barColor or (bar >= 1 and "green" or nil))
        b:SetValue01(bar)
        b:ClearAllPoints()
        b:SetPoint("LEFT", x, 0)
        b:Layout(math.max(4, cw - slot - 6))
        b:Show()
      elseif b then b:Hide() end
    end
    for i = #cols + 1, #p.cells do p.cells[i]:Hide() if p.bars[i] then p.bars[i]:Hide() end end
    p:SetAlpha(it.dim and 0.6 or 1)
  end,
}

-- a card of an item: symbol, name in the quality colour, a line below, a number on the right
local function ItemCard(parent)
  local c = BoxFrame("Button", parent)
  c:SetHeight(S.itemCard or 64)
  c.hl = c:CreateTexture(nil, "HIGHLIGHT")
  c.hl:SetPoint("TOPLEFT", 4, -4) c.hl:SetPoint("BOTTOMRIGHT", -4, 4)
  c.hl:SetTexture(HILITE)
  if c.hl.SetBlendMode then c.hl:SetBlendMode("ADD") end
  c.hl:SetAlpha(0.4)
  c.sel = c:CreateTexture(nil, "BORDER")
  c.sel:SetPoint("TOPLEFT", 4, -4) c.sel:SetPoint("BOTTOMRIGHT", -4, 4)
  c.sel:SetTexture(HILITE)
  if c.sel.SetBlendMode then c.sel:SetBlendMode("ADD") end
  c.sel:Hide()
  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(36, 36)
  c.icon:SetPoint("LEFT", 11, 0)
  c.title = FS(c, "tab", GOLD)
  c.sub = FS(c, "sub", GREY)
  c.right = FS(c, "title", WHITE)
  c.right:SetJustifyH("RIGHT")
  c.right:SetPoint("RIGHT", -12, 0)
  function c:SetData(d)
    self.data = d or {}
    d = self.data
    SetIcon(self.icon, { icon = d.icon, itemID = d.itemID })
    self.title:SetText(d.title or "")
    if d.titleColor then self.title:SetTextColor(Col3(d.titleColor))
    elseif d.quality and d.quality ~= 1 then self.title:SetTextColor(Bz.QualityRGB(d.quality))
    else self.title:SetTextColor(1, 1, 1) end
    self.sub:SetText(d.sub or "")
    self.right:SetText(d.right ~= nil and tostring(d.right) or "")
    self.right:SetTextColor(Col3(d.rightColor, WHITE))
    self.sel:SetShown(d.selected and true or false)
    if d.selected then self:SetEdge(1, 0.82, 0)
    elseif d.markColor or d.status then self:SetEdge(Col3(d.markColor or d.status))
    else self:SetEdge(0.6, 0.55, 0.45) end
    self:SetAlpha(d.dim and 0.6 or 1)
  end
  function c:Layout(w)
    self._w = w
    self:SetWidth(w)
    local tx = 11 + 36 + 8
    local rw = (self.right:GetText() or "") ~= "" and 56 or 0
    local room = math.max(10, w - tx - 12 - rw)
    self.right:SetWidth(math.max(4, rw))
    self.title:ClearAllPoints() self.sub:ClearAllPoints()
    if (self.sub:GetText() or "") ~= "" then
      self.title:SetPoint("TOPLEFT", tx, -14)
      self.sub:SetPoint("TOPLEFT", tx, -33)
      self.sub:SetWidth(room)
      self.sub:Show()
    else
      self.title:SetPoint("LEFT", tx, 0)
      self.sub:Hide()
    end
    self.title:SetWidth(room)
  end
  if c.RegisterForClicks then c:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  c:SetScript("OnClick", function(self, button)
    local d = self.data
    if not d then return end
    if d.itemID and LinkItem(d.itemID) then return end
    if d.onClick then Try(d.onClick, self, button, d) end
  end)
  c:SetScript("OnEnter", function(self) local d = self.data if d then ShowTipOf(self, d, d.tooltipFn) end end)
  c:SetScript("OnLeave", HideTip)
  return c
end
K.ItemCard = ItemCard

-- kind "itemcards": item.cards side by side in item.cols columns
PART.itemcards = {
  build = function(p) p.cards = {} end,
  fill = function(p, it, w)
    local cards = type(it.cards) == "table" and it.cards or {}
    local cols = tonumber(it.cols) or Kit.ItemCardCols(w)
    local each = math.floor((w - 16 - (cols - 1) * 8) / cols)
    for i, d in ipairs(cards) do
      local c = p.cards[i]
      if not c then c = ItemCard(p) p.cards[i] = c end
      c:SetData(d)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", 8 + ((i - 1) % cols) * (each + 8), 0)
      c:Layout(each)
      c:Show()
    end
    for i = #cards + 1, #p.cards do p.cards[i]:Hide() end
  end,
}

local CLICKS = { row = true, group = true, note = true, table = true }

-- (minor 5) a row the Kit's way: made by opts.kinds[kind].make(list) (an addon's own kind) or by MAKER (the Kit's
-- kinds sub, zone, cards, trow, done in the game's look), kept in the game's row frame as its part for that kind.
-- The made row has SetItem(item, index, list) and Layout(w) and takes its own clicks as in the Kit's list.
local function MadeClick(l)
  return function(self, button)
    if self._disabled then return end
    if self._onClick then Try(self._onClick, self, button) return end
    local it = self.item
    if not it then return end
    if it.itemID and LinkItem(it.itemID) then return end
    if it.kind == "group" and not it.static and not it.onClick then
      it.collapsed = not it.collapsed
      if l.opts.onToggle then Try(l.opts.onToggle, it, l) end
    elseif l.opts.onClick then Try(l.opts.onClick, it, button, l)
    elseif type(it.onClick) == "function" then Try(it.onClick, self, button) end
  end
end
local function FillMade(l, r, it, key, make, w, h)
  local m = r.parts[key]
  if not m then
    m = make(l)
    if m.SetParent then m:SetParent(r) end
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    m.list = l
    if m.RegisterForClicks then
      m:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      m:SetScript("OnClick", MadeClick(l))
    end
    r.parts[key] = m
    l.made = (l.made or 0) + 1
  end
  m:SetSize(w, h)
  m._w, m.plain = w, nil
  m._selected = (l.selected ~= nil and l.selected == it) or nil
  m.onClick = it.onClick
  m:Show()
  Try(m.SetItem, m, it, l.index and l.index[it] or nil, l)
  return m
end
local function FillListRow(l, r, it)
  if not r.built then
    r.built, r.parts = true, {}
    r.sel = r:CreateTexture(nil, "BACKGROUND")
    r.sel:SetAllPoints()
    r.sel:SetTexture(HILITE)
    if r.sel.SetBlendMode then r.sel:SetBlendMode("ADD") end
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetTexture(HILITE)
    if r.hl.SetBlendMode then r.hl:SetBlendMode("ADD") end
    r.rule = r:CreateTexture(nil, "BORDER")
    r.rule:SetColorTexture(1, 1, 1, 0.07)
    r.rule:SetHeight(1)
    r.rule:SetPoint("BOTTOMLEFT", 0, 0) r.rule:SetPoint("BOTTOMRIGHT", 0, 0)
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetWidth(3)
    r.mark:SetPoint("TOPLEFT", 0, -1) r.mark:SetPoint("BOTTOMLEFT", 0, 1)
    if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r:SetScript("OnClick", function(self, button)
      local cur, list = self.item, self.list
      if not (cur and list and CLICKS[self.kind]) then return end
      if cur.itemID and LinkItem(cur.itemID) then return end
      if cur.kind == "group" and not cur.static and not cur.onClick then
        cur.collapsed = not cur.collapsed
        if list.opts.onToggle then Try(list.opts.onToggle, cur, list) end
        return
      end
      if list.opts.onClick then Try(list.opts.onClick, cur, button, list)
      elseif cur.onClick then Try(cur.onClick, self, button) end
    end)
    r:SetScript("OnEnter", function(self)
      local cur = self.item
      if not cur then return end
      if cur.onHover then Try(cur.onHover, self, true) end
      if CLICKS[self.kind] then ShowTipOf(self, cur, cur.tooltipFn) end
    end)
    r:SetScript("OnLeave", function(self)
      local cur = self.item
      if cur and cur.onHover then Try(cur.onHover, self, false) end
      HideTip()
    end)
  end
  local own = l.opts.kinds and l.opts.kinds[it.kind]
  local make = (own and own.make) or (not PART[it.kind] and MAKER[it.kind]) or nil
  local kind = make and ("made:" .. tostring(it.kind)) or (PART[it.kind] and it.kind) or "row"
  local w, h = math.max(10, (l.w or 400) - LIST_BAR), l:ItemHeight(it)
  r.item, r.kind, r.list, r.onClick, r._w = it, kind, l, it.onClick, w
  if make then
    for k, p in pairs(r.parts) do if k ~= kind then p:Hide() end end
    r.sel:Hide() r.hl:SetAlpha(0) r.rule:Hide() r.mark:Hide()
    r.cards = nil
    r.made = FillMade(l, r, it, kind, make, w, h)
    l.drawnRows[#l.drawnRows + 1] = r
    return
  end
  r.made = nil
  for k, p in pairs(r.parts) do if k ~= kind then p:Hide() end end
  local p = r.parts[kind]
  if not p then
    p = CreateFrame("Frame", nil, r)
    p:SetAllPoints()
    PART[kind].build(p)
    r.parts[kind] = p
  end
  p:Show()
  PART[kind].fill(p, it, w, h, l)
  r.cards = kind == "itemcards" and p.cards or nil
  -- the row's own dress: selection, hover, the rule below, the mark on the left
  local rowish = kind == "row" or kind == "table"
  local on = rowish and (it.active or l.selected == it) and true or false
  r.sel:SetShown(on)
  r.hl:SetAlpha((rowish or (kind == "group" and not it.static) or (kind == "note" and (it.onClick or it.clickable))) and 0.5 or 0)
  r.rule:SetShown(rowish)
  local mark = rowish and (on and GOLD or it.markColor or it.status) or nil
  if mark then r.mark:SetColorTexture(Col3(mark)) r.mark:Show() else r.mark:Hide() end
  l.drawnRows[#l.drawnRows + 1] = r
end

function K.List(parent, opts)
  opts = opts or {}
  local l = CreateFrame("Frame", nil, parent)
  l.opts, l.items, l.drawnRows, l.w, l.h, l.blizz = opts, {}, {}, 400, 200, true
  l.box = CreateFrame("Frame", nil, l, "WowScrollBoxList")
  l.bar = CreateFrame("EventFrame", nil, l, "MinimalScrollBar")
  l.box:SetPoint("TOPLEFT", 0, 0)
  l.box:SetPoint("BOTTOMRIGHT", -LIST_BAR, 0)
  l.bar:SetPoint("TOPLEFT", l.box, "TOPRIGHT", 5, -2)
  l.bar:SetPoint("BOTTOMLEFT", l.box, "BOTTOMRIGHT", 5, 2)
  function l:ItemHeight(it)
    return tonumber(it.h) or (opts.kinds and opts.kinds[it.kind] and opts.kinds[it.kind].h) or KIND_H[it.kind] or 36
  end
  local view = CreateScrollBoxListLinearView()
  if view.SetElementExtentCalculator then view:SetElementExtentCalculator(function(_, it) return l:ItemHeight(it) end)
  else view:SetElementExtent(36) end
  view:SetElementFactory(function(factory)
    factory("Button", function(row, it) Try(FillListRow, l, row, it) end)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(l.box, l.bar, view)
  l.view = view
  l.ground = Bz.Ground(l, "item")
  l.ground:Place(0, LIST_BAR, 0, 0)
  l.empty = FS(l, "row", GREY)
  if l.empty.SetWordWrap then l.empty:SetWordWrap(true) end
  l.empty:SetJustifyH("CENTER")
  l.empty:SetPoint("TOP", 0, -24)
  l.empty:Hide()
  function l:Draw(reset)
    self.drawnRows = {}
    -- (minor 5) the index of every item, for rows that ask (SetItem(item, index, list))
    self.index = {}
    for i, it in ipairs(self.items) do self.index[it] = i end
    local keep = (not reset) and type(ScrollBoxConstants) == "table" and ScrollBoxConstants.RetainScrollPosition or nil
    self.box:SetDataProvider(CreateDataProvider(self.items), keep)
    Bz.ClampScroll(self.box)
    Bz.Settle(self.box)
    if #self.items == 0 and self.emptyText and self.emptyText ~= "" then
      self.empty:SetText(self.emptyText)
      self.empty:SetWidth(math.max(40, self.w - 24 - LIST_BAR))
      self.empty:Show()
    else self.empty:Hide() end
  end
  function l:SetItems(items, reset) self.items = items or {} self:Draw(reset) end
  function l:SetEmpty(text) self.emptyText = text if #self.items == 0 then self:Draw() end end
  function l:Resize(w, h)
    local changed = self.w ~= w
    self.w, self.h = w, h
    self:SetSize(w, h)
    if changed then self:Draw() end -- the rows are laid out for the width
  end
  -- the rows on screen: the game's own list of them where it has one
  -- (minor 5) a row the Kit's way (own kinds, sub, zone ...) stands for its frame, as in the Kit's list
  function l:Rows()
    local frames = self.drawnRows
    if type(self.box.GetFrames) == "function" then
      local ok, f = pcall(self.box.GetFrames, self.box)
      if ok and type(f) == "table" then frames = f end
    end
    local out = {}
    for i, f in ipairs(frames) do out[i] = (f.made and f.made.item == f.item) and f.made or f end
    return out
  end
  function l:Select(item) self.selected = item self:Draw() end
  function l:SetPlain() end
  function l:SetRail(on) self.rail = on and true or nil self:Draw() end
  -- (minor 5) as the Kit: the item (or its index) into view, top = true at the top
  function l:ScrollTo(it, top) return Bz.ScrollTo(self.box, self.items, it, top) end
  return l
end

---------------------------------------------------------------------------
-- TableHead: the game's column head buttons over a list of kind "table"; head:Bind(list), head:Layout(w)
---------------------------------------------------------------------------
function K.TableHead(parent, opts)
  opts = opts or {}
  local head = CreateFrame("Frame", nil, parent)
  head:SetHeight(S.chip or 24)
  head.columns, head.icon, head.sortKey, head.desc, head.btns = opts.columns or {}, opts.icon and true or false, opts.sortKey, opts.desc, {}
  head.blizz = true
  local tpl = Has("ColumnDisplayButtonNoScriptsTemplate") and "ColumnDisplayButtonNoScriptsTemplate" or nil
  -- (minor 5, Guildon) one head button per column made at once, head.cells as in the Kit (b.col, b.text, b.arrow);
  -- a head the caller hides stays hidden at the next layout
  local function Btn(i)
    local b = head.btns[i]
    if b then return b end
    b = CreateFrame("Button", nil, head, tpl)
    b:SetHeight(S.chip or 24)
    b.text = FS(b, "sub", WHITE)
    b.arrow = FS(b, "sub", GOLD) -- the Kit's field; the sort mark stands in the text ("^" / "v")
    b.arrow:Hide()
    b:SetScript("OnClick", function(btn)
      local d = btn.def
      if not (d and d.sort) then return end
      local desc = head.sortKey == d.key and not head.desc or (head.sortKey ~= d.key and d.desc) or false
      head:SetSort(d.key, desc)
      if opts.onSort then Try(opts.onSort, d.key, desc, head) end
    end)
    b:SetScript("OnEnter", function(btn)
      local d = btn.def
      if d and type(d.tooltip) == "table" then Tip(btn, d.tooltip[1] or d.text, d.tooltip[2]) end
    end)
    b:SetScript("OnLeave", HideTip)
    head.btns[i] = b
    return b
  end
  for i, col in ipairs(head.columns) do local b = Btn(i) b.def, b.col = col, col end
  head.cells = head.btns
  function head:Cols(w) return Kit.TableCols(self.columns, w, self.icon) end
  function head:Bind(list) self.list = list list._tableHead = self list.columns, list.tableIcon = self.columns, self.icon end
  function head:SetSort(key, desc) self.sortKey, self.desc = key, desc and true or false if self._w then self:Layout(self._w) end end
  function head:Layout(w)
    self._w = w
    self:SetWidth(w)
    if self.list and (self.list._tableHead == nil or self.list._tableHead == self) then
      self.list.columns, self.list.tableIcon = self.columns, self.icon
    end
    local cols = self:Cols(math.max(10, w - LIST_BAR))
    for i, c in ipairs(cols) do
      local def = self.columns[i]
      local b = Btn(i)
      b.def, b.col = def, def
      local x, cw = c.x or c[1] or 0, c.w or c[2] or 60
      -- the first head starts at the list's left edge (over the symbol), each one reaches to the next
      local left = i == 1 and 0 or (x - 4)
      local nx = cols[i + 1] and ((cols[i + 1].x or cols[i + 1][1]) - 4) or w
      b:ClearAllPoints()
      b:SetPoint("LEFT", left, 0)
      b:SetWidth(math.max(10, nx - left))
      local arrow = self.sortKey == def.key and (self.desc and " v" or " ^") or ""
      b.text:SetText((def.text or "") .. arrow)
      b.text:ClearAllPoints()
      if def.justify == "RIGHT" then
        b.text:SetJustifyH("RIGHT")
        b.text:SetPoint("RIGHT", b, "LEFT", x + cw - left, 0)
      else
        b.text:SetJustifyH("LEFT")
        b.text:SetPoint("LEFT", math.max(8, x - left), 0)
      end
      b.text:SetWidth(math.max(4, cw))
      if b._layoutHidden then b._layoutHidden = nil b:Show() end
    end
    for i = #cols + 1, #self.btns do
      local b = self.btns[i]
      if b:IsShown() then b:Hide() b._layoutHidden = true end
    end
  end
  return head
end

---------------------------------------------------------------------------
-- Hero: a wide box with a picture behind (h.art), a small line and a big title left, a value with label and bar right
---------------------------------------------------------------------------
function K.Hero(parent, opts)
  opts = opts or {}
  local h = BoxFrame("Frame", parent)
  local hh = opts.height or 72
  h:SetHeight(hh)
  h.colW = opts.column or 132
  h.art = CreateFrame("Frame", nil, h)
  h.art:SetPoint("TOPLEFT", 4, -4) h.art:SetPoint("BOTTOMRIGHT", -4, 4)
  if h.art.SetClipsChildren then h.art:SetClipsChildren(true) end
  h.veil = CreateFrame("Frame", nil, h)
  h.veil:SetAllPoints(h.art)
  h.veil.tex = h.veil:CreateTexture(nil, "BACKGROUND")
  h.veil.tex:SetAllPoints()
  h.veil.tex:SetColorTexture(0, 0, 0, 0.55)
  -- the picture's own frames (a caller's map tiles are children of h.art) stay under the veil and the texts
  if h.veil.SetFrameLevel and h.art.GetFrameLevel then h.veil:SetFrameLevel((tonumber((h.art:GetFrameLevel())) or 1) + 10) end
  local over = CreateFrame("Frame", nil, h.veil)
  over:SetAllPoints(h)
  h.kicker = FS(over, "group", GOLD)
  h.title = FS(over, "hero", WHITE)
  h.value = FS(over, "hero", WHITE)
  h.value:SetJustifyH("RIGHT")
  h.label = FS(over, "sub", GREY)
  h.label:SetJustifyH("RIGHT")
  h.bar = Bar(over, 5)
  h.bar:Hide()
  h._cutTexts = { h.kicker, h.title, h.value, h.label }
  function h:SetData(d)
    d = d or {}
    self.data = d
    self.kicker:SetText(d.kicker or "")
    self.title:SetText(d.title or "")
    self.value:SetText(d.value ~= nil and tostring(d.value) or "")
    self.value:SetTextColor(Col3(d.valueColor, WHITE))
    self.label:SetText(d.label or "")
    if d.progress ~= nil then
      self.bar:SetColor(d.progressColor or (d.progress >= 1 and "green" or nil))
      self.bar:SetValue01(d.progress)
      self.bar:Show()
    else self.bar:Hide() end
    if self._w then self:Layout(self._w) end
  end
  function h:Layout(w)
    self._w = w
    self:SetWidth(w)
    local d = self.data or {}
    local right = (d.value ~= nil and tostring(d.value) ~= "") or (d.label or "") ~= ""
    local textW = math.max(40, w - 24 - (right and (self.colW + 8) or 0))
    self.kicker:ClearAllPoints() self.title:ClearAllPoints()
    if (d.kicker or "") ~= "" then
      self.kicker:SetPoint("TOPLEFT", 12, -hh / 2 + 18)
      self.title:SetPoint("TOPLEFT", 12, -hh / 2 + 2)
    else self.title:SetPoint("LEFT", 12, 0) end
    self.kicker:SetWidth(textW) self.title:SetWidth(textW)
    self.value:ClearAllPoints() self.label:ClearAllPoints() self.bar:ClearAllPoints()
    self.value:SetPoint("TOPRIGHT", -12, -hh / 2 + 22)
    self.label:SetPoint("TOPRIGHT", -12, -hh / 2 - 2)
    self.bar:SetPoint("TOPRIGHT", -12, -hh / 2 - 18)
    self.value:SetWidth(self.colW) self.label:SetWidth(self.colW)
    self.bar:Layout(self.colW)
    self.value:SetShown(right) self.label:SetShown(right)
  end
  h:EnableMouse(true)
  h:SetScript("OnEnter", function(self) ShowTipOf(self, nil, self._tipFn) end)
  h:SetScript("OnLeave", HideTip)
  return h
end

---------------------------------------------------------------------------
-- Detail: a box beside a list: head (symbol, title, a line below, a number), then sections and lines that scroll.
-- d:SetHead{...}, d:Begin(), d:Section(title, right), d:Line(text, color, right, rightColor, lo), d:Para(text, color),
-- d:Block(frame, h), d:Space(px), d:End(), d:Layout(w, h), d.close, d.area.content
---------------------------------------------------------------------------
function K.Detail(parent, opts)
  opts = opts or {}
  local d = BoxFrame("Frame", parent)
  d:EnableMouse(true)
  d.head = CreateFrame("Frame", nil, d)
  d.head:SetPoint("TOPLEFT", 4, -4) d.head:SetPoint("TOPRIGHT", -4, -4)
  d.head:SetHeight(44)
  d.head.rule = d.head:CreateTexture(nil, "ARTWORK")
  d.head.rule:SetColorTexture(1, 0.82, 0, 0.3)
  d.head.rule:SetHeight(1)
  d.head.rule:SetPoint("BOTTOMLEFT", 4, 0) d.head.rule:SetPoint("BOTTOMRIGHT", -4, 0)
  d.icon = d.head:CreateTexture(nil, "ARTWORK")
  d.icon:SetSize(28, 28)
  d.icon:SetPoint("LEFT", 8, 0)
  -- (minor 5) the level as the quest log writes it ("[12]" in the quest's colour) when the head has no symbol
  d.badge = FS(d.head, "tab", WHITE)
  d.badge:SetPoint("LEFT", 10, 0)
  d.badge:Hide()
  d.title = FS(d.head, "tab", GOLD)
  d.meta = FS(d, "sub", GREY)
  d.pill = FS(d, "sub", WHITE)
  d.pill:SetJustifyH("RIGHT")
  d.close = CreateFrame("Button", nil, d.head, Has("UIPanelCloseButton") and "UIPanelCloseButton" or nil)
  d.close:SetSize(24, 24)
  d.close:SetPoint("RIGHT", 0, 0)
  d.close:SetScript("OnClick", function() if opts.onClose then Try(opts.onClose, d) else d:Hide() end end)
  d.area = CreateFrame("ScrollFrame", nil, d)
  d.area.content = CreateFrame("Frame", nil, d.area)
  d.area.content:SetSize(10, 10)
  if d.area.SetScrollChild then d.area:SetScrollChild(d.area.content) end
  if d.area.EnableMouseWheel then d.area:EnableMouseWheel(true) end
  d.area:SetScript("OnMouseWheel", function(a, delta)
    if not a.GetVerticalScroll then return end
    local max = math.max(0, (a.contentH or 0) - (a:GetHeight() or 0))
    a:SetVerticalScroll(math.max(0, math.min(max, (a:GetVerticalScroll() or 0) - delta * 36)))
  end)
  function d.area:SetContentHeight(h) self.contentH = h self.content:SetHeight(math.max(1, h)) end
  d.lines, d.nLines, d.blocks, d.y, d.actions = {}, 0, {}, 8, {}
  local function Width() return math.max(40, (d._w or 320) - 24 - 6) end
  -- a line's text and right column: the right takes what it needs up to 45 %, the text the rest
  local function FitLine(ln)
    local W = Width() - (ln.inset or 0)
    local r = ln.right:GetText() or ""
    local tw = ln.right.GetStringWidth and tonumber((ln.right:GetStringWidth())) or 0
    local rw = r ~= "" and math.min(tw + 4, math.floor(W * 0.45)) or 0
    if r ~= "" and rw < 24 then rw = math.min(math.floor(W * 0.45), 60) end
    ln.right:SetWidth(math.max(4, rw))
    ln.text:SetWidth(math.max(20, W - rw - (rw > 0 and 8 or 0)))
  end
  local function NewLine()
    d.nLines = d.nLines + 1
    local ln = d.lines[d.nLines]
    if not ln then
      ln = CreateFrame("Button", nil, d.area.content)
      ln.text = FS(ln, "row", WHITE)
      ln.text:SetPoint("LEFT", 0, 0)
      ln.right = FS(ln, "sub", WHITE)
      ln.right:SetJustifyH("RIGHT")
      ln.right:SetPoint("RIGHT", 0, 0)
      ln:SetScript("OnClick", function(self, button) if self.lo and self.lo.onClick then Try(self.lo.onClick, button) end end)
      ln:SetScript("OnEnter", function(self) local t = self.lo and self.lo.tooltip if t then KitTip(self, t[1], t[2], t[3]) end end)
      ln:SetScript("OnLeave", HideTip)
      d.lines[d.nLines] = ln
    end
    ln.lo, ln.para, ln.inset = nil, nil, 0
    if ln.ic then ln.ic:Hide() end
    if ln.bar then ln.bar:Hide() end
    ln.text:ClearAllPoints()
    ln.text:SetPoint("LEFT", 0, 0)
    if ln.text.SetWordWrap then ln.text:SetWordWrap(false) end
    ln:ClearAllPoints()
    ln:SetPoint("TOPLEFT", 12, -d.y)
    ln:SetSize(Width(), 18)
    ln:Show()
    return ln
  end
  function d:SetHead(hd)
    hd = hd or {}
    self.headData = hd
    if (hd.icon or hd.itemID) and SetIcon(self.icon, hd) then self.icon:Show() self.badge:Hide()
    else
      self.icon:Hide()
      if hd.level ~= nil then
        local st = hd.levelStatus or (tonumber(hd.level) and Kit.QuestDifficulty and Kit.QuestDifficulty(hd.level)) or "grey"
        self.badge:SetText("[" .. tostring(hd.level) .. "]")
        self.badge:SetTextColor(Col3(st, GREY))
        self.badge:Show()
      else self.badge:Hide() end
    end
    self.title:SetText(hd.title or "")
    self.title:SetTextColor(Col3(hd.titleColor, GOLD))
    self.meta:SetText(hd.meta or "")
    local pill = type(hd.pill) == "table" and hd.pill or nil
    self.pill:SetText(pill and tostring(pill[1] or pill.text or "") or "")
    self.pill:SetTextColor(Col3(pill and (pill[2] or pill.kind), WHITE))
    if self._w then self:Layout(self._w, self._h) end
  end
  -- (minor 5) the Kit's action buttons, the game's buttons: under the meta line, or at the bottom (opts.actionsBottom,
  -- the first takes the room); { text, onClick, kind, tooltip = { title, lines }, disabled, selected }
  function d:SetActions(list)
    self.actionList = list or {}
    for _, b in ipairs(self.actions) do b:Hide() end
    for i, a in ipairs(self.actionList) do
      local b = self.actions[i]
      if not b then b = K.Button(self, "", {}) self.actions[i] = b end
      b:SetText(a.text or "")
      b._onClick = a.onClick
      if a.tooltip then b:SetTooltip(a.tooltip[1], a.tooltip[2]) else b._tip = nil end
      b:SetDisabled(a.disabled)
      b:SetSelected(a.selected and true or false)
      b:Show()
    end
    self.nActions = #self.actionList
    if self._w then self:Layout(self._w, self._h) end
  end
  function d:Begin()
    for _, ln in ipairs(self.lines) do ln:Hide() if ln.ic then ln.ic:Hide() end if ln.bar then ln.bar:Hide() end end
    for _, b in ipairs(self.blocks) do b:Hide() end
    self.nLines, self.blocks, self.y = 0, {}, 8
  end
  function d:Section(title, right)
    if self.y > 8 then self.y = self.y + 8 end
    local ln = NewLine()
    ln.text:SetFontObject(Bz.FONTS.group)
    ln.text:SetText(title or "")
    ln.text:SetTextColor(1, 0.82, 0)
    ln.text:SetWidth(Width())
    ln.right:SetText(right ~= nil and tostring(right) or "")
    ln.right:SetTextColor(0.6, 0.6, 0.6)
    self.y = self.y + 18
    return ln.text
  end
  function d:Line(text, color, right, rightColor, lo)
    local ln = NewLine()
    ln.lo = lo
    ln.text:SetFontObject(Bz.FONTS.row)
    ln.text:SetText(text or "")
    ln.text:SetTextColor(Col3(color, { 0.85, 0.85, 0.85 }))
    local r = (right ~= nil and tostring(right) ~= "") and tostring(right) or ""
    ln.right:SetText(r)
    ln.right:SetTextColor(Col3(rightColor, WHITE))
    FitLine(ln)
    self.y = self.y + 18
    return ln.text
  end
  -- (minor 5) the Kit's Progress: a line with "have / need" and a thin bar under it (green when done)
  function d:Progress(text, have, need, done)
    have, need = tonumber(have), tonumber(need)
    local fs = self:Line(text, done and "green" or nil, (have and need) and (have .. " / " .. need) or nil, done and "green" or GREY)
    local ln = self.lines[self.nLines]
    if have and need and need > 0 then
      if not ln.bar then ln.bar = K.ProgressBar(self.area.content) ln.bar:SetHeight(3) end
      ln.bar:ClearAllPoints()
      ln.bar:SetPoint("TOPLEFT", self.area.content, "TOPLEFT", 12, -self.y + 1)
      ln.bar:Layout(Width())
      ln.bar:SetColor(done and "green" or "yellow")
      ln.bar:SetValue(have / need)
      ln.bar:Show()
      self.y = self.y + 5
    end
    return fs
  end
  -- (minor 5) the Kit's Item: a line with the item's symbol (16 px, the game's tooltip, Shift-click links it); returns
  -- the text and the symbol (K.ItemIcon: SetItem, _onClick, extraTip, bd) as the Kit
  function d:Item(item, text, color, right, rightColor, onClick)
    local ln = NewLine()
    if not ln.ic then ln.ic = K.ItemIcon(ln, 16) ln.ic:SetPoint("LEFT", 0, 0) end
    ln.ic:SetItem(item)
    ln.ic._onClick = onClick
    ln.ic:Show()
    ln.inset = 22
    ln.text:ClearAllPoints()
    ln.text:SetPoint("LEFT", 22, 0)
    ln.text:SetFontObject(Bz.FONTS.row)
    ln.text:SetText(text or "")
    ln.text:SetTextColor(Col3(color, { 0.85, 0.85, 0.85 }))
    local r = (right ~= nil and tostring(right) ~= "") and tostring(right) or ""
    ln.right:SetText(r)
    ln.right:SetTextColor(Col3(rightColor, GREY))
    FitLine(ln)
    ln:SetHeight(20)
    self.y = self.y + 20
    return ln.text, ln.ic
  end
  -- (minor 5) the lines to the width again (after a new size), as the Kit's FitLines
  function d:FitLines()
    for i = 1, self.nLines do
      local ln = self.lines[i]
      ln:SetWidth(Width())
      if ln.para then ln.text:SetWidth(Width()) else FitLine(ln) end
    end
  end
  function d:Para(text, color)
    local ln = NewLine()
    ln.text:SetFontObject(Bz.FONTS.sub)
    if ln.text.SetWordWrap then ln.text:SetWordWrap(true) end
    ln.text:SetText(text or "")
    ln.text:SetTextColor(Col3(color, { 0.85, 0.85, 0.85 }))
    ln.text:SetWidth(Width())
    ln.para = true
    ln.right:SetText("")
    local h = math.max(14, ln.text.GetStringHeight and tonumber((ln.text:GetStringHeight())) or 14)
    ln:SetHeight(h)
    self.y = self.y + h + 4
    return ln.text
  end
  function d:Block(frame, h)
    if not frame then return end
    frame:SetParent(self.area.content)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", 12, -self.y)
    if frame.Layout then frame:Layout(Width(), h) else frame:SetSize(Width(), h or 1) end
    frame:Show()
    self.blocks[#self.blocks + 1] = frame
    self.y = self.y + (h or frame:GetHeight() or 0) + 4
  end
  function d:Space(px) self.y = self.y + (px or 8) end
  function d:End() self.area:SetContentHeight(self.y + 8) self:FitLines() end
  function d:Layout(w, h)
    self._w, self._h = w, h
    self:SetSize(w, h or 100)
    local hd = self.headData or {}
    local x = self.icon:IsShown() and 44 or self.badge:IsShown() and 46 or 10
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", x, 0)
    self.title:SetWidth(math.max(20, w - x - 8 - 30))
    if self.badge:IsShown() then self.badge:SetWidth(34) end
    local y = 44 + 8
    local pill = (self.pill:GetText() or "") ~= ""
    if (hd.meta or "") ~= "" or pill then
      self.meta:ClearAllPoints() self.pill:ClearAllPoints()
      self.meta:SetPoint("TOPLEFT", 14, -y - 2)
      self.pill:SetPoint("TOPRIGHT", -14, -y - 2)
      self.pill:SetWidth(pill and 60 or 4)
      self.meta:SetWidth(math.max(20, w - 28 - (pill and 64 or 0)))
      self.meta:Show() self.pill:Show()
      y = y + 20
    else self.meta:Hide() self.pill:Hide() end
    -- (minor 5) the action buttons: in a row under the meta line, or at the bottom with opts.actionsBottom
    local n, bottom = self.nActions or 0, 0
    if n > 0 and opts.actionsBottom then
      bottom = 22 + 2 * 8
      local rest = 0
      for i = 2, n do rest = rest + math.min(self.actions[i].natural or 60, 120) + 4 end
      local bx = 12
      for i = 1, n do
        local b = self.actions[i]
        local bw = i == 1 and math.max(40, w - 24 - rest) or math.min(b.natural or 60, 120)
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", bx, 10)
        b:Layout(bw)
        bx = bx + bw + 4
      end
    elseif n > 0 then
      local each = math.floor((w - 24 - (n - 1) * 4) / n)
      local bx = 12
      for i = 1, n do
        local b = self.actions[i]
        local bw = math.min(b.natural or each, each)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self, "TOPLEFT", bx, -y)
        b:Layout(bw)
        bx = bx + bw + 4
      end
      y = y + 22 + 8
    end
    self.area:ClearAllPoints()
    self.area:SetPoint("TOPLEFT", 4, -y)
    self.area:SetSize(math.max(10, w - 8), math.max(10, (h or 100) - y - 6 - bottom))
    self.area.content:SetWidth(math.max(10, w - 8))
    self:FitLines()
  end
  d:Begin()
  return d
end

---------------------------------------------------------------------------
-- Segmented: two or more of the game's buttons side by side, the picked one held down with white text
---------------------------------------------------------------------------
function K.Segmented(parent, opts)
  opts = opts or {}
  local s = CreateFrame("Frame", nil, parent)
  s:SetHeight(S.button or 28)
  s.fields = {}
  function s:Paint()
    for _, b in ipairs(self.fields) do
      local on = b.value == self.value
      if b.LockHighlight then if on then b:LockHighlight() else b:UnlockHighlight() end end
      if b.text and b.text.SetTextColor then if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(1, 0.82, 0) end end
    end
  end
  function s:Update(v)
    if v == nil and opts.get then v = opts.get() end
    self.value = v
    self:Paint()
  end
  for i, it in ipairs(opts.items or {}) do
    local b = CreateFrame("Button", nil, s, "UIPanelButtonTemplate")
    b:SetHeight(22)
    b.value = it.value
    b:SetText(it.text or "")
    local fs = b.GetFontString and b:GetFontString()
    b.text = type(fs) == "table" and fs or FS(b, "button", GOLD)
    if b.text ~= fs then b.text:SetPoint("CENTER") b.text:SetText(it.text or "") end
    WithTip(b)
    if it.tip then b:SetTooltip(it.text, { it.tip }) end
    b:SetScript("OnClick", function()
      s.value = it.value
      s:Paint()
      if opts.set then Try(opts.set, it.value, s) end
    end)
    s.fields[i] = b
  end
  function s:Layout(w)
    self._w = w
    self:SetWidth(w)
    local n = math.max(1, #self.fields)
    local each = math.floor((w - (n - 1) * 2) / n)
    for i, b in ipairs(self.fields) do
      b:ClearAllPoints()
      b:SetPoint("LEFT", (i - 1) * (each + 2), 0)
      b:SetWidth(each)
    end
  end
  s:Layout(opts.width or 240)
  s:Update()
  return s
end

---------------------------------------------------------------------------
-- BarList: names with a bar and a number each; bl:SetEntries(list, maxValue), bl:Layout(w) -> height
---------------------------------------------------------------------------
function K.BarList(parent, opts)
  opts = opts or {}
  local bl = CreateFrame("Frame", nil, parent)
  bl.rows, bl.entries, bl.rowH, bl.top = {}, {}, opts.rowH or 18, 1
  function bl:SetEntries(list, maxValue)
    self.entries = list or {}
    local top = tonumber(maxValue) or 0
    for _, e in ipairs(self.entries) do top = math.max(top, tonumber(e.value) or 0) end
    self.top = top > 0 and top or 1
    if self._w then self:Layout(self._w) end
  end
  function bl:Layout(w)
    self._w = w
    local nameW = math.min(110, math.floor(w * 0.36))
    for i, e in ipairs(self.entries) do
      local r = self.rows[i]
      if not r then
        r = CreateFrame("Button", nil, self)
        r:SetHeight(self.rowH)
        r.name = FS(r, "sub", WHITE)
        r.name:SetPoint("LEFT", 0, 0)
        r.num = FS(r, "sub", WHITE)
        r.num:SetJustifyH("RIGHT")
        r.num:SetPoint("RIGHT", 0, 0)
        r.bar = Bar(r, 8)
        r:SetScript("OnClick", function(self2) if opts.onClick and self2.entry then Try(opts.onClick, self2.entry, bl) end end)
        r:SetScript("OnEnter", function(self2) local t = self2.entry and self2.entry.tooltip if t then KitTip(self2, t[1], t[2], t[3]) end end)
        r:SetScript("OnLeave", HideTip)
        self.rows[i] = r
      end
      r.entry = e
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", 0, -(i - 1) * self.rowH)
      r:SetWidth(w)
      r.name:SetText(e.text or "")
      r.name:SetWidth(nameW)
      r.num:SetText(e.right ~= nil and tostring(e.right) or tostring(e.value or ""))
      r.num:SetWidth(40)
      r.bar:ClearAllPoints()
      r.bar:SetPoint("LEFT", nameW + 4, 0)
      r.bar:Layout(math.max(4, w - nameW - 4 - 40 - 6))
      r.bar:SetColor(e.color)
      r.bar:SetValue01((tonumber(e.value) or 0) / self.top)
      r:Show()
    end
    for i = #self.entries + 1, #self.rows do self.rows[i]:Hide() end
    local h = math.max(1, #self.entries * self.rowH)
    self:SetSize(w, h)
    return h
  end
  return bl
end
---------------------------------------------------------------------------
-- (minor 3, 16.11.2026, Daniel on Luredon's pilot: the small fishing window, the dialogs and the options "bitte auch
-- noch anpassen. das ist doch genau das was man fast durchgängig sieht")
-- Dialog: a small window of the game in the middle of the screen (ButtonFrameTemplate without portrait and button
-- bar): title, red X, a body d.body, the game's buttons bottom right; Esc closes, the title drags it. The Kit's calls:
--   d:SetTitle(text, icon)  d:SetButtons({ { text, onClick(d), tooltip, disabled }, ... })  d:Layout()
--   d:BodyWidth()  d:BodyHeight()  d:SetBodySize(w, h)  d:SetOwnScale(f)  opts: title, width, height, onClose, onLayout
---------------------------------------------------------------------------
local D_TOP, D_SIDE, D_BOTTOM, D_BTN = 34, 16, 14, 22
function K.Dialog(name, opts)
  opts = opts or {}
  local d = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
  d.opts, d.blizz = opts, true
  ButtonFrameTemplate_HideButtonBar(d)
  local hidePortrait = rawget(_G, "ButtonFrameTemplate_HidePortrait")
  if type(hidePortrait) == "function" then pcall(hidePortrait, d) end
  d:SetFrameStrata("DIALOG")
  d:SetToplevel(true)
  d:SetClampedToScreen(true)
  d:SetMovable(true)
  d:EnableMouse(true)
  d:SetSize(opts.width or 420, opts.height or 300)
  d:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  Bz.Lighten(d)
  local function drag(h)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() d:StartMoving() end)
    h:SetScript("OnDragStop", function() d:StopMovingOrSizing() end)
  end
  drag(d)
  if type(d.TitleContainer) == "table" then drag(d.TitleContainer) end
  d.head = type(d.TitleContainer) == "table" and d.TitleContainer or d
  d.close = type(d.CloseButton) == "table" and d.CloseButton or nil
  if d.close then d.close:SetScript("OnClick", function() d:Hide() end) end
  d.body = CreateFrame("Frame", nil, d)
  d.body:SetPoint("TOPLEFT", D_SIDE, -D_TOP)
  d.buttons = {}
  function d:SetOwnScale() end -- the game's windows keep the game's scale
  local setTitle = d.SetTitle -- the template's own (text); the Kit's call has an icon too, a dialog of the game shows none
  function d:SetTitle(text)
    self.titleText = text or ""
    if type(setTitle) == "function" then pcall(setTitle, self, self.titleText) end
  end
  function d:SetButtons(list)
    for _, b in ipairs(self.buttons) do b:Hide() end
    for i, a in ipairs(list or {}) do
      local b = self.buttons[i]
      if not b then b = K.Button(self, "", {}) self.buttons[i] = b end
      b._fixed = nil
      b:SetText(a.text or "")
      b._onClick = function() Try(a.onClick, self) end
      if a.tooltip then b:SetTooltip(a.tooltip[1], a.tooltip[2]) else b._tip = nil end
      b:SetDisabled(a.disabled)
      b:Show()
    end
    self.nButtons = #(list or {})
    self:Layout()
  end
  local function Foot() return (d.nButtons or 0) > 0 and (D_BTN + 10) or 0 end
  function d:BodyWidth() return (self:GetWidth() or 420) - 2 * D_SIDE end
  function d:BodyHeight() return (self:GetHeight() or 300) - D_TOP - D_BOTTOM - Foot() end
  function d:Layout()
    local w = self:GetWidth() or 420
    self.body:SetSize(math.max(1, self:BodyWidth()), math.max(1, self:BodyHeight()))
    local n = self.nButtons or 0
    local rx = D_SIDE
    local each = math.floor((w - 2 * D_SIDE - (n - 1) * 6) / math.max(1, n))
    for i = n, 1, -1 do
      local b = self.buttons[i]
      local bw = math.min(b.natural or each, each)
      b:ClearAllPoints()
      b:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -rx, D_BOTTOM - 2)
      b:Layout(bw)
      rx = rx + bw + 6
    end
    -- the inset frames the body, the buttons stand under it
    local inset = type(self.Inset) == "table" and self.Inset or nil
    if inset and inset.ClearAllPoints then
      inset:ClearAllPoints()
      inset:SetPoint("TOPLEFT", self, "TOPLEFT", 6, -(D_TOP - 10))
      inset:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -6, D_BOTTOM - 8 + Foot())
    end
    if opts.onLayout then Try(opts.onLayout, self, self:BodyWidth(), self:BodyHeight()) end
  end
  function d:SetBodySize(w, h)
    self:SetSize(w + 2 * D_SIDE, h + D_TOP + D_BOTTOM + Foot())
    self:Layout()
  end
  d:SetScript("OnHide", function(self) if opts.onClose then Try(opts.onClose, self) end end)
  if name and type(UISpecialFrames) == "table" then UISpecialFrames[#UISpecialFrames + 1] = name end
  d:SetTitle(opts.title)
  d:Layout()
  d:Hide()
  return d
end

---------------------------------------------------------------------------
-- ShowCopy: one shared dialog of the game to copy a text; the Kit's call (title, hint, text, words)
---------------------------------------------------------------------------
function K.ShowCopy(title, hint, text, words)
  words = words or {}
  local d = Bz._copy
  if not d then
    d = K.Dialog("DonBlizzCopyBox", { width = 560, height = 360, onLayout = function(self, w, h)
      if not self.hint then return end
      self.hint:ClearAllPoints()
      self.hint:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, 0)
      self.hint:SetWidth(w)
      local sh = self.hint.GetStringHeight and tonumber((self.hint:GetStringHeight())) or 14
      local top = (self.hint:GetText() or "") == "" and 0 or math.max(14, sh) + 8
      self.scroll:ClearAllPoints()
      self.scroll:SetPoint("TOPLEFT", self.body, "TOPLEFT", 0, -top)
      self.scroll:SetSize(w, math.max(20, h - top))
      self.edit:SetWidth(math.max(20, w - 16))
    end })
    d.hint = FS(d.body, "sub", GREY)
    if d.hint.SetWordWrap then d.hint:SetWordWrap(true) end
    d.scroll = CreateFrame("ScrollFrame", nil, d.body)
    if d.scroll.EnableMouseWheel then d.scroll:EnableMouseWheel(true) end
    d.edit = CreateFrame("EditBox", nil, d.scroll)
    d.edit:SetMultiLine(true)
    d.edit:SetAutoFocus(false)
    d.edit:SetFontObject("ChatFontNormal")
    if d.edit.SetTextInsets then d.edit:SetTextInsets(6, 6, 6, 6) end
    d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
    d.edit:SetScript("OnTextChanged", function(self, user) if user and d.text then self:SetText(d.text) self:HighlightText() end end)
    if d.scroll.SetScrollChild then d.scroll:SetScrollChild(d.edit) end
    d.scroll:SetScript("OnMouseWheel", function(self, delta)
      local cur = self.GetVerticalScroll and tonumber((self:GetVerticalScroll())) or 0
      local range = self.GetVerticalScrollRange and tonumber((self:GetVerticalScrollRange())) or 0
      if self.SetVerticalScroll then self:SetVerticalScroll(math.max(0, math.min(range, cur - delta * 40))) end
    end)
    Bz._copy = d
  end
  d.text = text or ""
  d:SetTitle(title or "")
  d:SetButtons({
    { text = words.selectAll or "Select all", onClick = function(dd) dd.edit:SetFocus() dd.edit:HighlightText() end },
    { text = words.close or "Close", onClick = function(dd) dd:Hide() end },
  })
  d.hint:SetText(hint or "")
  d.edit:SetText(d.text)
  d:Show()
  d:Layout()
  d.edit:SetFocus()
  if d.edit.HighlightText then d.edit:HighlightText() end
  return d
end

---------------------------------------------------------------------------
-- PanelLook: a small panel of DonCore's Style (Style.Panel: Luredon's fishing window, Dropdon's small window) in the
-- game's look: Style's own game look (minor 16: the game's gold title, the game's text shadow, no Don ground and
-- frame) on a box with the game's tooltip border. Bz.PanelLook(panel, on); off puts the Don look back.
-- The box follows the panel's background opacity (panel:SetBackgroundAlpha) and its size (collapsed: the title bar).
---------------------------------------------------------------------------
function Bz.PanelLook(panel, on)
  if type(panel) ~= "table" then return false end
  on = on and true or false
  if on and not panel.bzBox then
    local box = BoxFrame("Frame", panel)
    box:SetPoint("TOPLEFT", -3, 3)
    box:SetPoint("BOTTOMRIGHT", 3, -3)
    if box.SetFrameLevel and panel.GetFrameLevel then box:SetFrameLevel(math.max(0, (tonumber((panel:GetFrameLevel())) or 1) - 1)) end
    if box.EnableMouse then box:EnableMouse(false) end
    panel.bzBox = box
    -- the panel's own background opacity moves the box (the Don ground is hidden in the game look)
    local setAlpha = panel.SetBackgroundAlpha
    if type(setAlpha) == "function" then
      function panel:SetBackgroundAlpha(a, ...)
        self.bzAlpha = tonumber(a) or 1
        if self.bzBox then self.bzBox:SetAlpha(self.bzAlpha) end
        return setAlpha(self, a, ...)
      end
    end
  end
  if panel.bzBox then
    if on then panel.bzBox:Show() else panel.bzBox:Hide() end
    panel.bzBox:SetAlpha(panel.bzAlpha or 1)
  end
  if type(panel.SetGameLook) == "function" then panel:SetGameLook(on) end
  panel.blizzLook = on or nil
  return true
end

---------------------------------------------------------------------------
-- (minor 5, 16.11.2026, Daniel: the Blizzard look as the default for all Don addons) the Kit's other blocks in the game's
-- look, with the Kit's calls, methods and fields. Rows the Kit builds keep their logic (SetItem, Layout, the cut texts,
-- the tooltip) and are dressed here: the game's fonts, the quest log's highlight for hover and selection, the fine light
-- line under a row, the mark on the left; boxes on the game's tooltip edge; bars from the game's status bar texture.
-- Kept in the Kit's look on purpose: LineChart (no counterpart in the game, as in Profitdon), RoundIcon (already the
-- minimap button art of the game), IconButton (Style's symbols, the game's own atlases), Ring and Dots (status colours),
-- the helpers without a look of their own (Stateful, IconText, Money, Fill, Tex ...).
---------------------------------------------------------------------------
local EDGE = { 0.6, 0.55, 0.45 }
local EDGE_HOT = { 0.85, 0.75, 0.5 }
local RED = { 1, 0.1, 0.1 }
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"
local function Status(st) local c = Kit.STATUS and st and Kit.STATUS[st] return c and c.fg or nil end

-- a Kit fill turned into the quest log's highlight (hidden until hover or selection)
local function Hilite(tex)
  if not tex then return end
  tex:SetTexture(HILITE)
  if tex.SetBlendMode then tex:SetBlendMode("ADD") end
  tex:SetVertexColor(1, 1, 1, 1)
  tex:Hide()
end
-- a row from the Kit's RowBase (bg, mark, lineB, lineT) in the game's look
local function RowSkin(r)
  Hilite(r.bg)
  if r.lineB then r.lineB:SetVertexColor(1, 1, 1, 0.07) end
  if r.lineT then r.lineT:Hide() end
  r.blizz = true
  return r
end
-- hover at half strength, selection (or item.active) at full; true when selected
local function RowLight(r, st, hover)
  local sel = st == "selected" or r._active
  if sel then r.bg:SetAlpha(1) r.bg:Show()
  elseif st == "hover" and hover ~= false then r.bg:SetAlpha(0.5) r.bg:Show()
  else r.bg:Hide() end
  return sel and true or false
end
local function Mark(r, c)
  if not r.mark then return end
  if c then local cr, cg, cb = Col3(c) r.mark:SetVertexColor(cr, cg, cb, 1) r.mark:Show() else r.mark:Hide() end
end
-- the block paints itself with paint(self, state) from now on (Kit.Stateful's states)
local function Repaint(w, paint)
  w._paint = paint
  if Kit.Refresh then Kit.Refresh(w) end
  return w
end
local function TitleColor(fs, it, sel)
  if it and it.titleColor then fs:SetTextColor(Col3(it.titleColor))
  elseif it and it.quality then fs:SetTextColor(Bz.QualityRGB(it.quality))
  elseif sel then fs:SetTextColor(1, 1, 1)
  else fs:SetTextColor(1, 0.82, 0) end
end
-- the textures of a frame (the Kit's fills without a name), for a new tone
local function Regions(f, fn)
  if not (f and f.GetRegions) then return end
  local list = { f:GetRegions() }
  for _, t in ipairs(list) do if type(t) == "table" and t.GetObjectType and t:GetObjectType() == "Texture" then fn(t) end end
end
-- the game's tooltip edge on a frame the Kit built (Mixin of the backdrop template); false where the client cannot
local function Backdrop(f)
  local M = rawget(_G, "BackdropTemplateMixin")
  if not f.SetBackdrop and type(M) == "table" and type(rawget(_G, "Mixin")) == "function" then
    Mixin(f, M)
    if f.GetScript and f.SetScript and not f:GetScript("OnSizeChanged") and f.OnBackdropSizeChanged then
      f:SetScript("OnSizeChanged", f.OnBackdropSizeChanged)
    end
  end
  if not (f.SetBackdrop and f.SetBackdropColor and f.SetBackdropBorderColor) then return false end
  if not pcall(f.SetBackdrop, f, BOX) then return false end
  f:SetBackdropColor(0.09, 0.08, 0.07, 0.85)
  f:SetBackdropBorderColor(EDGE[1], EDGE[2], EDGE[3], 1)
  f.boxed = true
  return true
end
local function Edge(f, c)
  local r, g, b = Col3(c, EDGE)
  if f.boxed then f:SetBackdropBorderColor(r, g, b, 1) elseif f.bd and f.bd.SetColor then f.bd:SetColor({ r, g, b }) end
end
-- a Kit box (bg, bd) on the tooltip edge, or at least in its tones
local function BoxSkin(f)
  if Backdrop(f) then
    if f.bg then f.bg:Hide() end
    if f.bd and f.bd.SetColor then f.bd:SetColor(EDGE, 0) end
  else
    if f.bg then f.bg:SetVertexColor(0.09, 0.08, 0.07, 0.85) end
    if f.bd and f.bd.SetColor then f.bd:SetColor(EDGE) end
  end
  return f
end
Bz.BoxSkin = BoxSkin

---------------------------------------------------------------------------
-- small marks: ChainMark (a dark box on the tooltip edge, gold), Pill (status colour on a dark ground), Radio (the
-- game's radio button as it comes)
---------------------------------------------------------------------------
local function SkinChain(ch)
  if type(ch) ~= "table" or ch.blizz then return ch end
  ch.blizz = true
  BlizzFonts(ch, { text = "GameFontNormalSmall" })
  local function plain(self) self.bg:SetVertexColor(0, 0, 0, 0.45) self.bd:SetColor(EDGE) end
  plain(ch)
  local done = ch.SetDone
  function ch:SetDone(on) done(self, on) if not on then plain(self) end end
  return ch
end
function K.ChainMark(parent, text) return SkinChain(Kit.ChainMark(parent, text)) end

local function SkinPill(p)
  if type(p) ~= "table" or p.blizz then return p end
  p.blizz = true
  BlizzFonts(p, { text = "GameFontHighlightSmall" })
  local set = p.SetPill
  function p:SetPill(t, k)
    set(self, t, k)
    self.bg:SetVertexColor(0, 0, 0, 0.55)
  end
  p:SetPill(p.text and p.text:GetText() or "", nil)
  return p
end
function K.Pill(parent, text, kind)
  local p = SkinPill(Kit.Pill(parent, text, kind))
  p:SetPill(text, kind)
  return p
end

local function SkinRadio(r)
  if type(r) ~= "table" or r.blizz then return r end
  r.blizz = true
  return Repaint(r, function(self, st)
    for _, t in ipairs({ self.ring, self.dot }) do
      if t.SetDesaturated then t:SetDesaturated(false) end
      t:SetVertexColor(1, 1, 1, 1)
    end
    if self.ring.SetTexCoord then
      if st == "hover" then self.ring:SetTexCoord(0.5, 0.75, 0, 1) else self.ring:SetTexCoord(0, 0.25, 0, 1) end
    end
    if self.checked then self.dot:Show() else self.dot:Hide() end
  end)
end
function K.Radio(parent, opts) return SkinRadio(Kit.Radio(parent, opts)) end

---------------------------------------------------------------------------
-- ItemIcon: the symbol on a dark slot, the game's icon frame in the quality colour from green up, the count in the
-- game's number font, the square highlight of the action buttons. ItemGrid: those symbols in rows (the Kit's calls).
---------------------------------------------------------------------------
local function SkinItemIcon(b)
  if type(b) ~= "table" or b.blizz then return b end
  b.blizz = true
  if b.bd then b.bd:SetColor(EDGE, 0) end
  b.qframe = b:CreateTexture(nil, "OVERLAY")
  b.qframe:SetTexture("Interface\\Common\\WhiteIconFrame")
  b.qframe:SetAllPoints(b)
  b.qframe:Hide()
  BlizzFonts(b, { count = "NumberFontNormalSmall" })
  if b.SetHighlightTexture then pcall(b.SetHighlightTexture, b, "Interface\\Buttons\\ButtonHilight-Square", "ADD") end
  local set = b.SetItem
  function b:SetItem(...)
    set(self, ...)
    if self.bd then self.bd:SetColor(EDGE, 0) end
    local q = tonumber(self.quality)
    if q and q >= 2 then self.qframe:SetVertexColor(Bz.QualityRGB(q)) self.qframe:Show() else self.qframe:Hide() end
  end
  return b
end
function K.ItemIcon(parent, size) return SkinItemIcon(Kit.ItemIcon(parent, size)) end

function K.ItemGrid(parent, opts)
  opts = opts or {}
  local size, gap = opts.size or 28, opts.gap or 4
  local g = CreateFrame("Frame", nil, parent)
  g.icons, g.entries, g.blizz = {}, {}, true
  function g:SetItems(list)
    self.entries = type(list) == "table" and list or {}
    for i, e in ipairs(self.entries) do
      local b = self.icons[i]
      if not b then
        b = K.ItemIcon(self, size)
        b._onClick = function(icon, button) if opts.onClick then Try(opts.onClick, icon, button, icon.entry) end end
        self.icons[i] = b
      end
      local en = type(e) == "table" and e or { itemID = e }
      b.entry = en
      b:SetItem(en.itemID, en.count, en.quality)
      b:SetUnusable(en.unusable)
      b.reason = type(en.unusable) == "string" and en.unusable or nil
      b.tipFallback = en.tipFallback
      -- (minor 6, as Kit 27) faded, picked (the game's square highlight kept on), grey lines under the tooltip
      b.extraTip = en.tipLines
      if b.SetAlpha then b:SetAlpha(en.dim and 0.45 or 1) end
      if b.LockHighlight then if en.selected then b:LockHighlight() else b:UnlockHighlight() end end
      b:Show()
    end
    for i = #self.entries + 1, #self.icons do self.icons[i]:Hide() self.icons[i].entry = nil end
    self:Layout(self._w or tonumber(self.GetWidth and self:GetWidth()) or 200)
  end
  function g:Layout(w)
    w = tonumber(w) or 200
    self._w = w
    local cols = math.max(1, math.floor((w + gap) / (size + gap)))
    local n = #self.entries
    for i = 1, n do
      local b = self.icons[i]
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", ((i - 1) % cols) * (size + gap), -math.floor((i - 1) / cols) * (size + gap))
    end
    local h = n > 0 and (math.ceil(n / cols) * (size + gap) - gap) or 0
    self:SetSize(w, math.max(1, h))
    return h
  end
  return g
end

---------------------------------------------------------------------------
-- Rows of the List the Kit's way: ListRow, GroupHeader, SubRow, ZoneRow, OptionRow, ItemRow, NoteRow, DoneRow, the
-- WarnRow on its own; the same fields (title, sub, right, right2, iconBox, badge, chain, pill, dots, ring, text, count,
-- arrow ...) and methods (SetItem, Layout, SetSelected ...)
---------------------------------------------------------------------------
local function ListPaint(self, st)
  local it = self.item
  local sel = RowLight(self, st)
  Mark(self, sel and GOLD or (it and it.markColor) or Status(it and it.status))
  TitleColor(self.title, it, sel)
end

function K.ListRow(parent)
  local r = RowSkin(Kit.ListRow(parent))
  BlizzFonts(r, { title = "GameFontNormal", sub = "GameFontHighlightSmall", right = "GameFontHighlightSmall", right2 = "GameFontHighlightSmall" })
  BlizzFonts(r.badge, { text = "GameFontHighlightSmall" })
  BlizzFonts(r.ring, { text = "GameFontHighlightSmall" })
  SkinChain(r.chain)
  SkinPill(r.pill)
  if r.iconBox and r.iconBox.bg then r.iconBox.bg:Hide() end
  local base = r.SetItem
  function r:SetItem(it, ...)
    base(self, it, ...)
    -- the symbol without the Kit's box; an edge only in the item's quality colour from green up
    if self.iconBox then
      if self.iconBox.bg then self.iconBox.bg:Hide() end
      if not (it and tonumber(it.quality) and it.quality >= 2) and self.iconBox.bd then self.iconBox.bd:SetColor(EDGE, 0) end
    end
    if self.lead and not self.lead.blizz then
      self.lead.blizz = true
      BlizzFonts(self, { lead = "GameFontHighlightSmall" })
      self.lead:SetTextColor(Col3(it and it.leadColor, GREY))
    end
    if self.radio then SkinRadio(self.radio) end
  end
  return Repaint(r, ListPaint)
end

-- the head of a group: a light gold band, the game's plus and minus, gold text, the count on the right. r.arrow keeps
-- the Kit's calls (SetText "+", "-" or ""), it shows the game's buttons.
function K.GroupHeader(parent)
  local r = RowSkin(Kit.GroupHeader(parent))
  BlizzFonts(r, { text = "GameFontNormal", count = "GameFontHighlightSmall" })
  r.count:SetTextColor(Col3(GREY))
  r.band = r:CreateTexture(nil, "BACKGROUND")
  r.band:SetPoint("TOPLEFT", 0, -1) r.band:SetPoint("BOTTOMRIGHT", 0, 1)
  r.band:SetColorTexture(1, 0.82, 0, 0.07)
  r.pm = r:CreateTexture(nil, "ARTWORK")
  r.pm:SetSize(14, 14)
  r.pm:SetPoint("LEFT", 6, 0)
  r.pm:Hide()
  local setText = r.arrow.SetText
  r.arrow.SetText = function(fs, t)
    setText(fs, "")
    fs.sign = t
    if t == "+" or t == "-" then r.pm:SetTexture(t == "+" and PLUS or MINUS) r.pm:Show() else r.pm:Hide() end
  end
  r.arrow:SetText(r.arrow.sign or "")
  local base = r.SetItem
  function r:SetItem(it, ...)
    base(self, it, ...)
    if it and not it.color then self.text:SetTextColor(1, 0.82, 0) end
  end
  return Repaint(r, function(self, st) RowLight(self, st, not (self.item and self.item.static)) end)
end

-- a chain step under its quest: the chain mark, the title white while it is the current one
function K.SubRow(parent)
  local r = RowSkin(Kit.SubRow(parent))
  BlizzFonts(r, { title = "GameFontHighlight", right = "GameFontHighlightSmall" })
  SkinChain(r.chain)
  return Repaint(r, function(self, st)
    local s = self.item and self.item.status
    local cur = s == "current"
    if st == "selected" then self.bg:SetAlpha(1) self.bg:Show()
    elseif st == "hover" then self.bg:SetAlpha(0.5) self.bg:Show()
    elseif cur then self.bg:SetAlpha(0.3) self.bg:Show()
    else self.bg:Hide() end
    Mark(self, st == "selected" and GOLD or Status(s) or GREY)
    if cur or st == "selected" then self.title:SetTextColor(1, 1, 1)
    elseif s == "next" then self.title:SetTextColor(1, 0.82, 0)
    else self.title:SetTextColor(Col3(GREY)) end
  end)
end

-- a zone in a sidebar: gold name, range or count on the right, the progress on the game's bar texture
function K.ZoneRow(parent)
  local r = RowSkin(Kit.ZoneRow(parent))
  BlizzFonts(r, { text = "GameFontNormal", count = "GameFontHighlightSmall", short = "GameFontNormalSmall", num = "GameFontDisableSmall" })
  r.track:SetVertexColor(0, 0, 0, 0.5)
  r.fill:SetTexture(BARTEX)
  return Repaint(r, function(self, st)
    local it = self.item
    local sel = RowLight(self, st)
    Mark(self, sel and GOLD or Status(it and it.status))
    local c = sel and WHITE or (it and it.quiet) and GREY or GOLD
    self.text:SetTextColor(Col3(c))
    self.short:SetTextColor(Col3(c))
  end)
end

-- an option: label, a quiet line below, the control on the right
function K.OptionRow(parent, opts)
  local r = RowSkin(Kit.OptionRow(parent, opts))
  BlizzFonts(r, { label = "GameFontHighlight", desc = "GameFontDisableSmall" })
  return Repaint(r, function(self, st) RowLight(self, st == "hover" and "hover" or "normal") end)
end

-- a row of a table in a List (kind "trow"): the item's symbol, gold or quality title, the cells under list.columns
function K.ItemRow(parent)
  local r = RowSkin(Kit.ItemRow(parent))
  BlizzFonts(r, { title = "GameFontNormal", sub = "GameFontHighlightSmall" })
  SkinItemIcon(r.iconBox)
  local cell = r.Cell
  function r:Cell(i)
    local fs = cell(self, i)
    if not fs.blizz then fs.blizz = true BlizzFonts({ fs = fs }, { fs = "GameFontHighlight" }) end
    return fs
  end
  return Repaint(r, ListPaint)
end

-- one line of text; item.warn: red text with a "!" on the tooltip box with a red edge
function K.NoteRow(parent)
  local r = RowSkin(Kit.NoteRow(parent))
  BlizzFonts(r, { text = "GameFontHighlightSmall", right = "GameFontNormalSmall", bang = "GameFontNormal" })
  r.bang:SetTextColor(Col3(RED))
  local boxed = Backdrop(r)
  if r.bd and r.bd.SetColor then r.bd:SetColor(EDGE, 0) end
  local base = r.SetItem
  function r:SetItem(it, ...)
    base(self, it, ...)
    local warn = it and it.warn
    if r.bd and r.bd.SetColor then r.bd:SetColor(EDGE, 0) end
    if boxed then
      if warn then self:SetBackdropColor(0.22, 0.03, 0.03, 0.75) self:SetBackdropBorderColor(RED[1], RED[2], RED[3], 1)
      else self:SetBackdropColor(0, 0, 0, 0) self:SetBackdropBorderColor(0, 0, 0, 0) end
    end
    if warn and not it.color then self.text:SetTextColor(Col3(RED))
    elseif not it.color then self.text:SetTextColor(Col3(GREY)) end
  end
  return Repaint(r, function(self, st)
    local it = self.item
    RowLight(self, st, it and (it.onClick or it.clickable) and true or false)
    if self.lineB then if it and it.warn then self.lineB:Hide() else self.lineB:Show() end end
  end)
end

-- the red warning line on its own (outside a list): w:SetText(text), w:Layout(width)
function K.WarnRow(parent)
  local r = K.NoteRow(parent)
  r:SetItem({ warn = true, text = "" })
  function r:SetText(t) self:SetItem({ warn = true, text = t, tooltipFn = self.item and self.item.tooltipFn }) end
  return r
end

-- something finished: the tick, the text quiet
function K.DoneRow(parent)
  local r = RowSkin(Kit.DoneRow(parent))
  BlizzFonts(r, { title = "GameFontDisableSmall" })
  return Repaint(r, function(self, st) RowLight(self, st) end)
end

---------------------------------------------------------------------------
-- Card: the Kit's index card on the game's tooltip box, the game's buttons; CardRow: cards side by side (kind "cards")
---------------------------------------------------------------------------
function K.Card(parent)
  local c = Kit.Card(parent)
  c.blizz = true
  c.top:Hide()
  BoxSkin(c)
  -- (17.11.2026, Daniel's picture of Questdon's dungeon cards: "RUINS OF LORDAE...") the game writes a card's title as it
  -- is, not in capitals, and in its normal size: the long names fit
  BlizzFonts(c, { title = "GameFontNormal", sub = "GameFontHighlightSmall", status = "GameFontHighlightSmall" })
  local setData = c.SetData
  function c:SetData(d, ...)
    local r = setData(self, d, ...)
    if type(d) == "table" and d.title then
      self.title:SetText(tostring(d.title))
      if self.Layout then self:Layout(self._w or tonumber(self.GetWidth and self:GetWidth()) or 0) end
    end
    return r
  end
  BlizzFonts(c.ring, { text = "GameFontHighlightSmall" })
  if c.art and c.art.bd then c.art.bd:SetColor(EDGE) end
  Regions(c.art, function(t) if t ~= c.art.icon then t:SetVertexColor(0, 0, 0, 0.5) end end)
  if c.line then
    Regions(c.line, function(t) if t ~= c.line.mark then t:SetVertexColor(1, 1, 1, 0.05) end end)
  end
  for i, old in ipairs(c.buttons) do
    old:Hide()
    local b = K.Button(c, "", { small = true })
    b:Hide()
    c.buttons[i] = b
  end
  return Repaint(c, function(self, st)
    Edge(self, st == "selected" and GOLD or st == "hover" and EDGE_HOT or EDGE)
  end)
end

function K.CardRow(parent)
  local r = CreateFrame("Frame", nil, parent)
  r.cards, r.blizz = {}, true
  function r:SetItem(it)
    self.item = it
    local list = it.cards or {}
    for i, d in ipairs(list) do
      local c = self.cards[i]
      if not c then c = K.Card(self) self.cards[i] = c end
      c:Show()
      c:SetData(d)
    end
    for i = #list + 1, #self.cards do self.cards[i]:Hide() end
    self:Layout(self._w or tonumber(self.GetWidth and self:GetWidth()) or 0)
  end
  function r:Layout(w)
    w = tonumber(w) or 0
    self._w = w
    local gap = S.gap or 8
    local cols = math.max(1, tonumber(self.item and self.item.cols) or 3)
    local each = math.floor((w - 2 * gap - (cols - 1) * gap) / cols)
    for i, c in ipairs(self.cards) do
      if c:IsShown() then
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self, "TOPLEFT", gap + (i - 1) * (each + gap), 0)
        c:Layout(math.max(1, each))
      end
    end
  end
  return r
end

MAKER.sub, MAKER.zone, MAKER.cards, MAKER.trow, MAKER.done = K.SubRow, K.ZoneRow, K.CardRow, K.ItemRow, K.DoneRow

---------------------------------------------------------------------------
-- Sidebar 220 (icon rail 48): the game's search box on top, the List below on the marble ground; s.list holds ZoneRow
-- items (or opts.kinds), s:Width(), s:Layout(h, rail), the list knows list.rail
---------------------------------------------------------------------------
function K.Sidebar(parent, opts)
  opts = opts or {}
  local s = CreateFrame("Frame", nil, parent)
  s.blizz = true
  s.line = s:CreateTexture(nil, "ARTWORK")
  s.line:SetColorTexture(1, 1, 1, 0.16)
  s.line:SetWidth(1)
  s.line:SetPoint("TOPRIGHT") s.line:SetPoint("BOTTOMRIGHT")
  if opts.search then
    s.search = K.SearchBox(s, { placeholder = opts.search, onChange = opts.onSearch })
    s.search:SetPoint("TOPLEFT", (S.gap or 8) + 6, -(S.gap or 8))
  end
  s.list = K.List(s, { onClick = opts.onClick, zebra = false, kinds = opts.kinds, onToggle = opts.onToggle })
  function s:Width() return self.rail and (S.rail or 48) or (S.sidebar or 220) end
  function s:Layout(h, rail)
    self.rail = rail and true or nil
    local w = self:Width()
    self:SetSize(w, h)
    local top = 0
    if self.search then
      if self.rail then self.search:Hide()
      else
        self.search:Show()
        self.search:Layout(w - 2 * (S.gap or 8) - 6)
        top = 22 + 2 * (S.gap or 8)
      end
    end
    self.list:ClearAllPoints()
    self.list:SetPoint("TOPLEFT", 0, -top)
    self.list.rail = self.rail
    self.list:Resize(w - 1, h - top)
  end
  return s
end

---------------------------------------------------------------------------
-- Box: a part of a page on the game's tooltip box with a gold title over a fine gold line: b.head (controls on its
-- right, b.headRoom keeps room for them), b.body, b:SetTitle(t), b:SetRight(t), b:Layout(w, h) -> body width, height;
-- opts.onLayout(b, bodyW, bodyH)
---------------------------------------------------------------------------
function K.Box(parent, title, opts)
  opts = opts or {}
  local HEAD_H = S.sub or 28
  local b = BoxFrame("Frame", parent)
  b.blizz = true
  b.head = CreateFrame("Frame", nil, b)
  b.head:SetPoint("TOPLEFT", 4, -4) b.head:SetPoint("TOPRIGHT", -4, -4)
  b.head:SetHeight(HEAD_H)
  b.headLine = b.head:CreateTexture(nil, "ARTWORK")
  b.headLine:SetColorTexture(1, 0.82, 0, 0.3)
  b.headLine:SetHeight(1)
  b.headLine:SetPoint("BOTTOMLEFT") b.headLine:SetPoint("BOTTOMRIGHT")
  b.title = FS(b.head, "tab", GOLD)
  b.title:SetPoint("LEFT", 8, 0)
  b.right = FS(b.head, "sub", GREY)
  b.right:SetJustifyH("RIGHT")
  b.right:SetPoint("RIGHT", -8, 0)
  b.body = CreateFrame("Frame", nil, b)
  b.body:SetPoint("TOPLEFT", 4, -HEAD_H - 4)
  function b:SetTitle(t) self.title:SetText(t or "") end
  function b:SetRight(t) self.right:SetText(t or "") end
  b.headRoom = 0
  function b:Layout(w, h)
    w, h = tonumber(w) or 0, tonumber(h) or 0
    self:SetSize(w, h)
    local rw = (self.right:GetText() or "") ~= "" and math.min(Width(self.right) + 4, math.floor(w * 0.4)) or 0
    self.right:ClearAllPoints()
    self.right:SetPoint("RIGHT", -8 - self.headRoom, 0)
    self.right:SetWidth(math.max(1, rw))
    self.title:SetWidth(math.max(20, w - 24 - self.headRoom - (rw > 0 and rw + 8 or 0)))
    local bw, bh = math.max(1, w - 8), math.max(1, h - HEAD_H - 8)
    self.body:SetSize(bw, bh)
    if opts.onLayout then Try(opts.onLayout, self, bw, bh) end
    return bw, bh
  end
  b:SetTitle(title)
  return b
end

-- ScrollArea: the Kit's (a.content, SetContentHeight, Resize, SetOffset; the wheel scrolls), the thumb in the tone of
-- the game's slim scroll bar
function K.ScrollArea(parent)
  local a = Kit.ScrollArea(parent)
  a.blizz = true
  if a.thumb then a.thumb:SetVertexColor(0.85, 0.7, 0.35, 0.9) a.thumb:SetWidth(4) end
  return a
end

---------------------------------------------------------------------------
-- Money: MoneyBox (one of the game's input boxes, "12g 50s" or "12,5"), CoinBox (three of them with the coins); the
-- Kit's calls: GetValue() copper, SetValue(copper), GetText, SetNext, SetFocus, Layout(w); opts.onChange(copper, box),
-- opts.onEnter(copper, box), opts.placeholder
---------------------------------------------------------------------------
function K.MoneyBox(parent, opts)
  opts = opts or {}
  local m
  m = K.EditBox(parent, { placeholder = opts.placeholder, maxLetters = 24, selectAll = opts.selectAll ~= false, width = opts.width or 100,
    onChange = function(t) if opts.onChange then Try(opts.onChange, Kit.ParseMoney(t), m) end end,
    onEnter = function() if opts.onEnter then Try(opts.onEnter, Kit.ParseMoney(m:GetText()), m) end end,
    onLeave = function(self) local c = Kit.ParseMoney(self:GetText()) if c then self:SetValue(c) end end })
  m.blizz = true
  local setRaw = m.SetValue
  function m:GetValue() return Kit.ParseMoney(self:GetText()) end
  function m:SetValue(c)
    c = tonumber(c)
    setRaw(self, c and Kit.Money(c, { letters = true, full = true }) or "")
  end
  return m
end

function K.CoinBox(parent, opts)
  opts = opts or {}
  local m = CreateFrame("Frame", nil, parent)
  m:SetHeight(22)
  m.boxes, m.coins, m.blizz = {}, {}, true
  local function changed() if opts.onChange then Try(opts.onChange, m:GetValue(), m) end end
  local function enter() if opts.onEnter then Try(opts.onEnter, m:GetValue(), m) end end
  for i = 1, 3 do
    local b = K.EditBox(m, { numeric = true, maxLetters = i == 1 and 7 or 2, min = 0, max = i > 1 and 99 or nil,
      onChange = changed, onEnter = enter, width = i == 1 and 60 or 26 })
    m.boxes[i] = b
    m.coins[i] = m:CreateTexture(nil, "ARTWORK")
    m.coins[i]:SetTexture(Kit.COINS and Kit.COINS[i])
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
    return c and ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100) or ""
  end
  function m:SetValue(c)
    c = tonumber(c)
    if not c then for _, b in ipairs(self.boxes) do b:SetValue("") end return end
    c = math.floor(c + 0.5)
    self.boxes[1]:SetValue(math.floor(c / 10000)) self.boxes[2]:SetValue(math.floor(c / 100) % 100) self.boxes[3]:SetValue(c % 100)
  end
  function m:SetText(t) self:SetValue(Kit.ParseMoney(t)) end
  function m:SetNext(other) self.boxes[3]:SetNext(other) end
  function m:SetFocus() self.boxes[1]:SetFocus() end
  function m:ClearFocus() for _, b in ipairs(self.boxes) do b:ClearFocus() end end
  -- the input box's art reaches 5 px left of it: the first box starts there
  function m:Layout(w)
    w = tonumber(w) or 140
    self._w = w
    self:SetWidth(w)
    local coin, gap, small, x = 12, 2, 24, 6
    local gold = math.max(24, w - x - 2 * small - 3 * (coin + gap) - 2 * 10)
    for i, b in ipairs(self.boxes) do
      local bw = i == 1 and gold or small
      b:ClearAllPoints() b:SetPoint("LEFT", self, "LEFT", x, 0) b:Layout(bw)
      self.coins[i]:ClearAllPoints() self.coins[i]:SetPoint("LEFT", self, "LEFT", x + bw + gap, 0)
      x = x + bw + gap + coin + 10
    end
  end
  m:Layout(opts.width or 140)
  if opts.value ~= nil then m:SetValue(opts.value) end
  return m
end

---------------------------------------------------------------------------
-- Columns (small bars side by side: c:SetValues(values, labels), c:Layout(w, h)) and ProgressBar (SetValue(0..1),
-- SetColor, Layout(w), value) on the game's status bar texture over a dark track
---------------------------------------------------------------------------
function K.Columns(parent, n)
  local c = CreateFrame("Frame", nil, parent)
  c.cols, c.n, c.blizz = {}, n or 7, true
  for i = 1, c.n do
    local b = CreateFrame("Frame", nil, c)
    b.track = b:CreateTexture(nil, "BACKGROUND")
    b.track:SetAllPoints()
    b.track:SetColorTexture(0, 0, 0, 0.45)
    b.fill = b:CreateTexture(nil, "ARTWORK")
    b.fill:SetTexture(BARTEX)
    b.fill:SetPoint("BOTTOMLEFT") b.fill:SetPoint("BOTTOMRIGHT")
    if b.EnableMouse then b:EnableMouse(true) end
    b:SetScript("OnEnter", function(self) if self.tip then KitTip(self, self.tip[1], { self.tip[2] }) end end)
    b:SetScript("OnLeave", HideTip)
    c.cols[i] = b
  end
  function c:SetValues(values, labels)
    self.values, self.labels = values or {}, labels or {}
    self:Layout(self._w or tonumber(self.GetWidth and self:GetWidth()) or 0, self._h or tonumber(self.GetHeight and self:GetHeight()) or 0)
  end
  function c:Layout(w, h)
    w, h = tonumber(w) or 0, tonumber(h) or 0
    self._w, self._h = w, h
    self:SetSize(math.max(1, w), math.max(1, h))
    local top = 0
    for i = 1, self.n do top = math.max(top, tonumber(self.values and self.values[i]) or 0) end
    local gap = 3
    local cw = math.max(2, (w - gap * (self.n - 1)) / self.n)
    for i, b in ipairs(self.cols) do
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", (i - 1) * (cw + gap), 0)
      b:SetSize(cw, math.max(1, h))
      local v = tonumber(self.values and self.values[i]) or 0
      local fh = top > 0 and math.max(v > 0 and 2 or 0, math.floor(h * v / top)) or 0
      if fh > 0 then b.fill:SetHeight(fh) b.fill:Show() else b.fill:Hide() end
      if i == self.n then b.fill:SetVertexColor(1, 0.82, 0, 1) else b.fill:SetVertexColor(0.78, 0.6, 0.12, 1) end
      local lab = self.labels and self.labels[i]
      b.tip = lab and { lab, self.values and self.values[i] ~= nil and tostring(self.values[i]) or nil } or nil
    end
  end
  return c
end

function K.ProgressBar(parent, color)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(S.bar or 6)
  f.blizz = true
  f.track = f:CreateTexture(nil, "BACKGROUND")
  f.track:SetAllPoints()
  f.track:SetColorTexture(0, 0, 0, 0.5)
  f.fill = f:CreateTexture(nil, "ARTWORK")
  f.fill:SetTexture(BARTEX)
  f.fill:SetPoint("TOPLEFT") f.fill:SetPoint("BOTTOMLEFT")
  f.value = 0
  function f:SetColor(c) local r, g, b = Col3(c, GOLD) self.fill:SetVertexColor(r, g, b, 1) end
  function f:SetValue(v)
    self.value = math.max(0, math.min(1, tonumber(v) or 0))
    local w = self._w or tonumber(self.GetWidth and self:GetWidth()) or 0
    if self.value <= 0 or w <= 0 then self.fill:Hide() return end
    self.fill:SetWidth(math.max(1, w * self.value))
    self.fill:Show()
  end
  function f:Layout(w) self._w = w self:SetWidth(w) self:SetValue(self.value) end
  f:SetColor(color)
  return f
end

---------------------------------------------------------------------------
-- Chip: one of the game's small buttons, held down while selected; c:SetText, c:SetCount(n), c:SetSelected(on),
-- c:SetTooltip; opts.add (the chip that adds something) a little fainter
---------------------------------------------------------------------------
function K.Chip(parent, text, onClick, opts)
  opts = opts or {}
  local c = K.Button(parent, text or "", { small = true, onClick = onClick })
  c.name, c.add, c.chip = text or "", opts.add and true or nil, true
  local setText, setSel = c.SetText, c.SetSelected
  local function Label(self) setText(self, self._count and (self.name .. "  " .. self._count) or self.name) end
  function c:SetText(t) self.name = t or "" Label(self) end
  -- as the Kit: a number or a short text ("3 undercut"), in a colour (a Kit.C or STATUS key or rgb; default gold)
  function c:SetCount(n, color)
    if n == nil or n == "" then self._count = nil
    else
      local r, g, b = Col3(color, { 1, 0.82, 0 })
      self._count = ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), tostring(n))
      self.countText = tostring(n)
    end
    Label(self)
  end
  function c:SetSelected(on)
    setSel(self, on)
    local fs = self.GetFontString and self:GetFontString()
    if type(fs) == "table" and fs.SetTextColor then if on then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(1, 0.82, 0) end end
    return self
  end
  if c.add then c:SetAlpha(0.8) end
  return c
end

---------------------------------------------------------------------------
-- Buttons that act protected: SecureButton (the game's red button with the secure template; b:SetLabel(text), b.text)
-- and ItemButton (the Kit's, on the action buttons' slot art); the Kit's where the client lacks the template
---------------------------------------------------------------------------
function K.SecureButton(name, parent, opts)
  opts = opts or {}
  if not Has("UIPanelButtonTemplate") then return Kit.SecureButton(name, parent, opts) end
  local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  b.blizz = true
  b:SetHeight(tonumber(opts.height) or 24)
  b:SetWidth(tonumber(opts.width) or 200)
  local down = type(GetCVarBool) == "function" and GetCVarBool("ActionButtonUseKeyDown")
  if b.RegisterForClicks then b:RegisterForClicks(opts.clicks or (down and "AnyDown" or "AnyUp")) end
  b.text = Part(b, "Text") or (b.GetFontString and b:GetFontString()) or nil
  function b:SetLabel(text)
    self:SetText(text or "")
    if not self.text and self.GetFontString then self.text = self:GetFontString() end
  end
  if opts.text then b:SetLabel(opts.text) end
  return b
end

function K.ItemButton(name, parent, opts)
  opts = opts or {}
  local b = Kit.ItemButton(name, parent, opts)
  b.blizz = true
  if b.bd and b.bd.SetColor then b.bd:SetColor(EDGE, 0) end
  if b.bg then b.bg:SetVertexColor(0, 0, 0, 0.6) end
  if opts.frame ~= false then
    local s = math.floor((tonumber(opts.size) or 36) * 66 / 36 + 0.5)
    b.slot = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.slot:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    b.slot:SetSize(s, s)
    b.slot:SetPoint("CENTER", 0, 0)
  end
  return b
end

---------------------------------------------------------------------------
-- Menu: the game's context menu (MenuUtil, Blizzard_Menu) with the Kit's call K.Menu(title, items, anchor):
-- items = { { text, onClick(item), disabled, tooltip = { title, lines } }, ... }; K.Menu.Hide(), K.Menu.Frame().
-- Where the client has no MenuUtil the Kit's menu opens.
---------------------------------------------------------------------------
local menuFrame
K.Menu = setmetatable({}, { __call = function(_, title, items, anchor)
  local MU = rawget(_G, "MenuUtil")
  if not (type(MU) == "table" and type(MU.CreateContextMenu) == "function") then
    menuFrame = nil
    return Kit.Menu(title, items, anchor)
  end
  local ok, m = pcall(MU.CreateContextMenu, anchor or UIParent, function(_, root)
    if title and title ~= "" and root.CreateTitle then root:CreateTitle(title) end
    for _, it in ipairs(items or {}) do
      local e = root:CreateButton(tostring(it.text or ""), function() Try(it.onClick, it) end)
      if e and it.disabled and e.SetEnabled then e:SetEnabled(false) end
      if e and type(it.tooltip) == "table" and e.SetTooltip then
        e:SetTooltip(function(tt)
          if tt and tt.SetText then tt:SetText(tostring(it.tooltip[1] or ""), 1, 0.82, 0) end
          for _, l in ipairs(type(it.tooltip[2]) == "table" and it.tooltip[2] or {}) do
            if tt and tt.AddLine then tt:AddLine(tostring(type(l) == "table" and (l[1] or "") or l), 1, 1, 1, true) end
          end
        end)
      end
    end
  end)
  if ok then menuFrame = m return m end
  menuFrame = nil
  return Kit.Menu(title, items, anchor)
end })
function K.Menu.Hide()
  if menuFrame and menuFrame.Close then pcall(menuFrame.Close, menuFrame) end
  menuFrame = nil
  if Kit.Menu and Kit.Menu.Hide then Kit.Menu.Hide() end
end
function K.Menu.Frame() return menuFrame or (Kit.Menu and Kit.Menu.Frame and Kit.Menu.Frame()) end

---------------------------------------------------------------------------
-- TextBox: several lines on the game's tooltip box (gold edge while typing), a quiet placeholder; the Kit's calls:
-- t:GetText(), t:SetText(s), t:Layout(w, h), t.edit; opts.placeholder, opts.maxLetters, opts.onChange(text, box)
---------------------------------------------------------------------------
function K.TextBox(parent, opts)
  opts = opts or {}
  local t = BoxFrame("Frame", parent)
  t.blizz = true
  local e = CreateFrame("EditBox", nil, t)
  if e.SetMultiLine then e:SetMultiLine(true) end
  if e.SetAutoFocus then e:SetAutoFocus(false) end
  if e.SetMaxLetters then e:SetMaxLetters(opts.maxLetters or 400) end
  if e.SetFontObject then pcall(e.SetFontObject, e, "GameFontHighlight") end
  e:SetPoint("TOPLEFT", 8, -7)
  e:SetPoint("BOTTOMRIGHT", -8, 7)
  t.edit = e
  t.hint = t:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  t.hint:SetPoint("TOPLEFT", 8, -8)
  if t.hint.SetJustifyH then t.hint:SetJustifyH("LEFT") end
  t.hint:SetText(opts.placeholder or "")
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e:SetScript("OnTextChanged", function(self, user)
    local s = self:GetText() or ""
    if s == "" then t.hint:Show() else t.hint:Hide() end
    if user and opts.onChange then Try(opts.onChange, s, t) end
  end)
  e:SetScript("OnEditFocusGained", function() t:SetEdge(1, 0.82, 0) end)
  e:SetScript("OnEditFocusLost", function() t:SetEdge(EDGE[1], EDGE[2], EDGE[3]) end)
  if t.EnableMouse then t:EnableMouse(true) end
  t:SetScript("OnMouseDown", function() if e.SetFocus then e:SetFocus() end end)
  function t:GetText() return self.edit:GetText() or "" end
  function t:SetText(s)
    self.edit:SetText(s or "")
    if (s or "") == "" then self.hint:Show() else self.hint:Hide() end
  end
  function t:Layout(w, h)
    self:SetSize(w, h or 64)
    if self.hint.SetWidth then self.hint:SetWidth(math.max(10, (tonumber(w) or 0) - 16)) end
  end
  return t
end

---------------------------------------------------------------------------
-- (minor 5, Vitaldon) Hint: one line with a mark, the Kit's (h:SetHint(text, kind) warn / red / good / accent / text,
-- h:Layout(w) -> its height, h.kind, h.text), in the game's fonts
---------------------------------------------------------------------------
function K.Hint(parent)
  local h = Kit.Hint(parent)
  h.blizz = true
  BlizzFonts(h, { bang = "GameFontNormal", text = "GameFontHighlightSmall" })
  return h
end

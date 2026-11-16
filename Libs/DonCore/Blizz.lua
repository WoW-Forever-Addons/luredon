local Bz = LibStub("DonCore-1.0"):NewModule("Blizz", 4)
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
---------------------------------------------------------------------------
local Kit = LibStub("DonCore-1.0"):Get("Kit", 25)
local K = setmetatable({}, { __index = Kit or {} })
Bz.kit = K
K.blizzLook = true -- a caller can tell the two kits apart
Bz.VERSION = 4
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
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing() f:Save() end)
  end
  drag(f)
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
  function b:SetKind() end
  WithTip(b)
  b:SetScript("OnClick", function(self)
    if self._disabled then return end
    if opts.confirm and not self._armed then
      self._armed, self._plain = true, self._label
      plain(self, type(opts.confirm) == "string" and opts.confirm or (Kit.SureWord and Kit.SureWord()) or "Sure?")
      After(3, function() if self._armed then self._armed = nil plain(self, self._plain or "") end end)
      return
    end
    if self._armed then self._armed = nil plain(self, self._plain or "") end
    if self._onClick then Try(self._onClick, self) end
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
function K.EditBox(parent, opts)
  opts = opts or {}
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(opts.width or 60, 20)
  e:SetAutoFocus(false)
  if opts.numeric then e:SetNumeric(true) e:SetJustifyH("CENTER") e:SetMaxLetters(opts.maxLetters or 7) end
  function e:SetValue(v)
    self._setting = true
    self:SetText(v ~= nil and tostring(v) or "")
    self._setting = nil
    if self.SetCursorPosition then self:SetCursorPosition(0) end
  end
  function e:GetValue() local t = self:GetText() if opts.numeric then return tonumber(t) end return t end
  function e:Layout(w) self:SetWidth(w) end
  function e:SetTooltip(title) self._tip = title and title ~= "" and { title } or nil end
  e:SetScript("OnEnter", function(self) if self._tip then Tip(self, self._tip[1]) end end)
  e:SetScript("OnLeave", HideTip)
  e:SetScript("OnTextChanged", function(self, user)
    if self._setting or user == false then return end
    if opts.onChange then Try(opts.onChange, self:GetText() or "", self) end
  end)
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() if opts.onEnter then Try(opts.onEnter, self) end end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  -- Tab leaves the box as in the Kit: the next box when one is set, else out of it; leaving commits (OnEditFocusLost)
  e:SetScript("OnTabPressed", function(self) if self.nextBox and self.nextBox.SetFocus then self.nextBox:SetFocus() else self:ClearFocus() end end)
  e:SetScript("OnEditFocusGained", function(self) self._focus = true if self.HighlightText then self:HighlightText() end end)
  e:SetScript("OnEditFocusLost", function(self)
    self._focus = nil
    if self.HighlightText then self:HighlightText(0, 0) end
    if opts.onLeave then Try(opts.onLeave, self) end
  end)
  return e
end

---------------------------------------------------------------------------
-- Dropdown: the game's dropdown button with a radio menu. opts.items (list or function), get(), set(value).
-- The template comes from Blizzard_Menu; where the client lacks it the kit's dropdown stands in.
---------------------------------------------------------------------------
function K.Dropdown(parent, opts)
  opts = opts or {}
  if not Has("WowStyle1DropdownTemplate") then
    return Kit.Dropdown(parent, opts)
  end
  local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  d:SetHeight(22)
  local function build(_, root)
    local items = type(opts.items) == "function" and opts.items() or opts.items or {}
    for _, it in ipairs(items) do
      root:CreateRadio(it.text or tostring(it.value), function() return opts.get and opts.get() == it.value end,
        function() if opts.set then Try(opts.set, it.value) end end)
    end
  end
  if d.SetupMenu then d:SetupMenu(build) end
  -- the caller lays it out on every draw: the shown value follows
  function d:Layout(w)
    self:SetWidth(w)
    if self.GenerateMenu then pcall(self.GenerateMenu, self) end
  end
  return d
end

---------------------------------------------------------------------------
-- ChipBar: the lists of one tab as a row of the game's buttons, the active one gold and held down
---------------------------------------------------------------------------
function K.ChipBar(parent, opts)
  opts = opts or {}
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetHeight(22)
  bar.chips = {}
  function bar:Add(key, text)
    local chip = K.Button(self, text, { onClick = function()
      self:SetActive(key)
      if opts.onChange then Try(opts.onChange, key, true, self) end
    end })
    chip.key, chip.name = key, text
    function chip:SetCount(n) self:SetText(n and ("%s (%d)"):format(self.name, n) or self.name) end
    self.chips[#self.chips + 1] = chip
    return chip
  end
  function bar:SetActive(key)
    self.active = key
    for _, c in ipairs(self.chips) do
      local on = c.key == key
      if on then c:LockHighlight() else c:UnlockHighlight() end
      local fs = c.GetFontString and c:GetFontString()
      if type(fs) == "table" and fs.SetTextColor then if on then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(1, 0.82, 0) end end
    end
  end
  function bar:Chip(key) for _, c in ipairs(self.chips) do if c.key == key then return c end end end
  function bar:Layout(w)
    self._w = w
    self:SetWidth(w)
    local x = 0
    for _, c in ipairs(self.chips) do
      c:ClearAllPoints()
      c:SetPoint("LEFT", self, "LEFT", x, 0)
      if c:IsShown() then x = x + (c:GetWidth() or 60) + 4 end
    end
  end
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
  if it.itemID and tt.SetItemByID then Call(tt.SetItemByID, tt, it.itemID) else tt:SetText(tostring(it.title or ""), 1, 0.82, 0) end
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
    view:SetElementExtentCalculator(function(_, it) return it.h or (it.kind == "note" and NOTE or ROW) end)
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
    b:SetScript("OnClick", function(self) if self.col and self.col.sort and opts.onSort then Try(opts.onSort, self.col.key, t) end end)
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
      if opts.onLayout then opts.onLayout(win, math.max(10, bw), math.max(10, bh), "full") end
    end })
  f.opts, f.tabs, f.blizz = opts, {}, true
  f.atticX = attic and 56 or 0
  f.body = CreateFrame("Frame", nil, f)
  if attic then f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -24) else f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -64) end
  if footer then
    f.status = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.status:SetJustifyH("LEFT") f.status:SetWordWrap(false)
    f.status:SetPoint("BOTTOMLEFT", 12, 9)
    f.status:SetPoint("BOTTOMRIGHT", -28, 9)
  end
  -- the Kit window's names: header (the strip to drag), close, gear (the cog of DonCore's options window)
  f.header = type(f.TitleContainer) == "table" and f.TitleContainer or f
  f.close = type(f.CloseButton) == "table" and f.CloseButton or nil
  if opts.options and Kit.IconButton then
    local O = LibStub("DonCore-1.0"):Get("Options", 1)
    if O and O.Open then
      f.gear = K.Button(f, O.Label and O.Label("Options") or "Options", { onClick = function() O.Open(opts.options) end })
      f.gear:SetHeight(20)
      f.gear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, attic and -1 or -30)
      if opts.hint then f.gear:SetTooltip(O.Label and O.Label("Options") or "Options", { opts.hint }) end
    end
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
-- Not built (a row with them still shows, without that part): pill, dots, ring, chain and radio of a list row; the
-- list kinds sub, zone, cards, trow and done fall back to the plain row. A window that needs those keeps the Kit's list.
---------------------------------------------------------------------------
local S = Kit and Kit.SIZE or {}
local HILITE = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local BARTEX = "Interface\\TargetingFrame\\UI-StatusBar"

-- a colour as the Kit takes it: a key of Kit.C or Kit.STATUS, or { r, g, b }
local function Col3(c, d)
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
    Call(GameTooltip.SetItemByID, GameTooltip, it.itemID)
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
local LIST_BAR = 20
local KIND_H = { row = 36, group = 28, divider = 20, note = 28, table = 28, itemcards = 72 }
local PART = {}

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
    p.icon:ClearAllPoints() p.level:ClearAllPoints()
    if (it.icon or it.iconKind) and SetIcon(p.icon, it) then
      local s = it.iconPlain and 16 or 24
      p.icon:SetSize(s, s)
      p.icon:SetPoint("LEFT", x, 0)
      p.icon:Show() p.level:Hide()
      x = x + s + 8
    elseif it.level ~= nil then
      p.icon:Hide()
      p.level:SetText("[" .. tostring(it.level) .. "]")
      p.level:SetTextColor(Col3(it.levelStatus, GREY))
      p.level:SetPoint("LEFT", x, 0)
      p.level:SetWidth(30)
      p.level:Show()
      x = x + 30 + 6
    else p.icon:Hide() p.level:Hide() end
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
    if it.static then p.arrow:Hide()
    else
      p.arrow:SetTexture(it.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
      p.arrow:Show()
    end
    p.text:SetText(it.text or "")
    p.text:SetTextColor(Col3(it.color, GOLD))
    p.text:ClearAllPoints()
    p.text:SetPoint("LEFT", it.static and 12 or 28, 0)
    -- the Kit writes right and count side by side; a caller that gives the same number twice gets it once
    local right = it.right ~= nil and tostring(it.right) or ""
    if it.count ~= nil and tostring(it.count) ~= right then right = right .. (right ~= "" and "  " or "") .. tostring(it.count) end
    -- (minor 4) the right text takes the room it needs ("Zones: 23"), the title the rest
    p.count:SetText(right)
    local cw = right ~= "" and math.max(24, math.min(math.floor(w * 0.45), Width(p.count) + 4)) or 0
    p.text:SetWidth(math.max(20, w - (it.static and 12 or 28) - cw - 20))
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
  local kind = PART[it.kind] and it.kind or "row"
  local w, h = math.max(10, (l.w or 400) - LIST_BAR), l:ItemHeight(it)
  r.item, r.kind, r.list, r.onClick, r._w = it, kind, l, it.onClick, w
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
  function l:Rows()
    if type(self.box.GetFrames) == "function" then
      local ok, frames = pcall(self.box.GetFrames, self.box)
      if ok and type(frames) == "table" then return frames end
    end
    return self.drawnRows
  end
  function l:Select(item) self.selected = item self:Draw() end
  function l:SetPlain() end
  function l:SetRail() end
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
  local tpl = Has("ColumnDisplayButtonNoScriptsTemplate") and "ColumnDisplayButtonNoScriptsTemplate" or nil
  function head:Cols(w) return Kit.TableCols(self.columns, w, self.icon) end
  function head:Bind(list) self.list = list list.columns, list.tableIcon = self.columns, self.icon end
  function head:SetSort(key, desc) self.sortKey, self.desc = key, desc if self._w then self:Layout(self._w) end end
  function head:Layout(w)
    self._w = w
    self:SetWidth(w)
    if self.list then self.list.columns, self.list.tableIcon = self.columns, self.icon end
    local cols = self:Cols(math.max(10, w - LIST_BAR))
    for i, c in ipairs(cols) do
      local def = self.columns[i]
      local b = self.btns[i]
      if not b then
        b = CreateFrame("Button", nil, self, tpl)
        b:SetHeight(S.chip or 24)
        b.text = FS(b, "sub", WHITE)
        b:SetScript("OnClick", function(btn)
          local d = btn.def
          if d and d.sort and opts.onSort then Try(opts.onSort, d.key, self.sortKey == d.key and not self.desc, self) end
        end)
        self.btns[i] = b
      end
      b.def = def
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
      b:Show()
    end
    for i = #cols + 1, #self.btns do self.btns[i]:Hide() end
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
    ln.lo = nil
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
    if (hd.icon or hd.itemID) and SetIcon(self.icon, hd) then self.icon:Show() else self.icon:Hide() end
    self.title:SetText(hd.title or "")
    self.title:SetTextColor(Col3(hd.titleColor, GOLD))
    self.meta:SetText(hd.meta or "")
    local pill = type(hd.pill) == "table" and hd.pill or nil
    self.pill:SetText(pill and tostring(pill[1] or pill.text or "") or "")
    self.pill:SetTextColor(Col3(pill and (pill[2] or pill.kind), WHITE))
    if self._w then self:Layout(self._w, self._h) end
  end
  function d:SetActions(list) self.actionList = list or {} end
  function d:Begin()
    for _, ln in ipairs(self.lines) do ln:Hide() end
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
    ln.right:SetWidth(r ~= "" and math.floor(Width() * 0.6) or 4)
    ln.text:SetWidth(r ~= "" and math.floor(Width() * 0.4) or Width())
    self.y = self.y + 18
    return ln.text
  end
  function d:Para(text, color)
    local ln = NewLine()
    ln.text:SetFontObject(Bz.FONTS.sub)
    if ln.text.SetWordWrap then ln.text:SetWordWrap(true) end
    ln.text:SetText(text or "")
    ln.text:SetTextColor(Col3(color, { 0.85, 0.85, 0.85 }))
    ln.text:SetWidth(Width())
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
  function d:End() self.area:SetContentHeight(self.y + 8) end
  function d:Layout(w, h)
    self._w, self._h = w, h
    self:SetSize(w, h or 100)
    local hd = self.headData or {}
    local x = self.icon:IsShown() and 44 or 10
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", x, 0)
    self.title:SetWidth(math.max(20, w - x - 8 - 30))
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
    self.area:ClearAllPoints()
    self.area:SetPoint("TOPLEFT", 4, -y)
    self.area:SetSize(math.max(10, w - 8), math.max(10, (h or 100) - y - 6))
    self.area.content:SetWidth(math.max(10, w - 8))
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

local M = LibStub("DonCore-1.0"):NewModule("MinimapButton", 4)
if not M then return end

---------------------------------------------------------------------------
-- (minor 3, 04.11.2026, Era-Test, Daniel: "jeder minimap button sollte doch einen goldenen ring bekommen. Dann sollte der
-- Minimap knopf so aussehen wie das Bild aus curseforge"; decided 04.11.: gold ring plus the CurseForge logo for every Don
-- button, each addon its own button, each one can be switched off, DonCore itself has none)
-- * the gold ring is back on every button (Blizzard's MiniMap-TrackingBorder, the dark disc under the symbol), laid out
--   like the other minimap buttons of the game (31 px button, symbol 17 px, round)
-- * opts.icon: the addon's own picture file, "Interface\\AddOns\\<Addon>\\Media\\minimap" (TGA or BLP, square, 64 x 64,
--   no extension needed), shown whole and round; a path under Interface\Icons keeps its border cut off as before.
--   opts.iconCoords = { l, r, t, b } overrides that.
-- * the switch "Show minimap button": Attach also puts ns.MinimapOption(o) on ns, an option item for the addon's options
--   (one line in its pages, see "Option" below). The saved switch is ns.db[opts.enabledKey or "minimapButton"]; nil
--   counts as on (opts.defaultOn = false: off) and is written once the button is refreshed, so the switch shows it.
--   opts.addon = plain addon name for the option's tooltip (default: opts.name without "MinimapButton").
-- Option: ns.MinimapOption() returns { key = "minimapButton", name = "Show minimap button", tip = "...", onChange = refresh,
--   donCommon = true } in the game's language. An addon with ns.BuildSettings puts it into a page's items; an addon with
--   its own Options.Register puts it into pages() and its key into a tab's main list (Options minor 5 runs onChange of a
--   donCommon item itself, the addon's changed() needs nothing). o = { name, tip, parent } overrides the fields.
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- DonCore module "MinimapButton" (minor 1, 30.10.2026, DONCORE_PLAN.md step 3; minor 2, 02.11.2026, Daniel: "das
-- Questdonsymbol in klein nehmen, ohne den goldenen rand (das gilt für alle addons)": every button is the addon's
-- symbol alone, small and round, without a ring or a border; opts.ring and opts.mask are no longer used).
-- One source for the minimap buttons of Dropdon, Guildon and Questdon: a round
-- button on the edge of the minimap, left and right click, a tooltip, dragging
-- around the minimap (angle saved in ns.db), square minimaps, and optionally
-- Questdon's small menu on right click.
-- Own frames only: one button on the minimap, one menu frame. The minimap
-- itself is not changed, no hooks.
--
-- Each addon attaches once with its own button (own frame name, own saved angle):
--   LibStub("DonCore-1.0"):Get("MinimapButton", 1):Attach(ns, opts)
-- Attach puts on ns: RefreshMinimapButton(), MinimapButton() and, with a menu,
-- ShowMinimapMenu(), HideMinimapMenu(), MinimapMenuShown(). It reads ns.db,
-- ns.Style, ns.L and ns.Guard (or ns.Safe) only when they are called; the addon
-- calls ns.RefreshMinimapButton() itself once ns.db is there (ns.OnInit).
--
-- opts = {
--   name = "DropdonMinimapButton",     global frame name
--   icon = "Interface\\AddOns\\Dropdon\\Media\\minimap",   (minor 3) the addon's own file; Interface\\Icons\\... works too
--   iconCoords = { 0, 1, 0, 1 },        (minor 3) optional
--   addon = "Dropdon",                  (minor 3) plain name for the option's tooltip
--   angleKey = "minimapAngle", defaultAngle = 160,
--   enabledKey = "minimapButton", defaultOn = true,       (minor 3) the saved switch in ns.db, nil counts as defaultOn
--   enabled = function() return ns.db.minimapButton end,  (default: ns.db[enabledKey])
--   title = "|cff..Drop|rdon" or function, lines = function() return { { left, right, tone }, ... } end,
--   hint = "Left click: ..." (localized already) or function,
--   onLeft = function(), onRight = function(),
--   ring, mask: not used (minor 2: no ring; minor 3: the gold ring on every button, always round),
--   menu = { name = "QuestdonMinimapMenu", title = text, width = 250, items = { item, ... } or function },
-- }
-- With a menu, right click opens it (onRight is not used).
-- menu item = { text, onClick }              closes the menu, then onClick
--           | { text, onClick, isOn = fn }   check row, the menu stays open
--           | { line = true }                a thin line
-- (minor 4, 04.11.2026, Era-Test, Daniel: "bei jedem meiner addons soll mit rechtsklick und dem menü auch eine option sein,
-- dass man direkt dort den minimap knopf ausschalten kann") every menu ends with a line and "Hide minimap button"
-- (menu.noHide = true leaves it out). It writes ns.db[enabledKey] = false, or calls opts.setEnabled(false) when the
-- addon keeps the switch elsewhere, hides the button and says in the chat where to bring it back.
---------------------------------------------------------------------------

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  if issecretvalue then
    local ok2, secret = pcall(issecretvalue, v)
    if not ok2 or secret then return nil end
  end
  return v
end

local function Num(v) return type(v) == "number" and v or nil end
local function Get(v) if type(v) == "function" then return Call(v) end return v end

-- (minor 3) the option's words in the game's languages (the languages of DonCore's Options window); English is the key
local SHOW, TIP = "Show minimap button", "%s's button on the edge of the minimap. Drag it to move it around the minimap."
local HIDE, BACK = "Hide minimap button", "%s: minimap button hidden. Options bring it back (Show minimap button)."
local WORDS = {
  deDE = { [SHOW] = "Minimap-Knopf zeigen", [TIP] = "Der Knopf von %s am Rand der Minimap. Zum Verschieben um die Minimap ziehen.",
    [HIDE] = "Minimap-Knopf ausblenden", [BACK] = "%s: Minimap-Knopf ausgeblendet. In den Optionen wieder einschalten (Minimap-Knopf zeigen)." },
  esES = { [SHOW] = "Mostrar botón del minimapa", [TIP] = "El botón de %s en el borde del minimapa. Arrástralo para moverlo alrededor del minimapa.",
    [HIDE] = "Ocultar botón del minimapa", [BACK] = "%s: botón del minimapa oculto. Vuelve a activarlo en las opciones (Mostrar botón del minimapa)." },
  esMX = { [SHOW] = "Mostrar botón del minimapa", [TIP] = "El botón de %s en el borde del minimapa. Arrástralo para moverlo alrededor del minimapa.",
    [HIDE] = "Ocultar botón del minimapa", [BACK] = "%s: botón del minimapa oculto. Vuelve a activarlo en las opciones (Mostrar botón del minimapa)." },
  frFR = { [SHOW] = "Afficher le bouton de la minicarte", [TIP] = "Le bouton de %s au bord de la minicarte. Faites-le glisser pour le déplacer autour de la minicarte.",
    [HIDE] = "Masquer le bouton de la minicarte", [BACK] = "%s : bouton de la minicarte masqué. Réactivez-le dans les options (Afficher le bouton de la minicarte)." },
  koKR = { [SHOW] = "미니맵 버튼 표시", [TIP] = "미니맵 가장자리에 있는 %s 버튼입니다. 끌어서 미니맵 주위로 옮길 수 있습니다.",
    [HIDE] = "미니맵 버튼 숨기기", [BACK] = "%s: 미니맵 버튼을 숨겼습니다. 설정에서 다시 켤 수 있습니다(미니맵 버튼 표시)." },
  ptBR = { [SHOW] = "Mostrar botão do minimapa", [TIP] = "O botão do %s na borda do minimapa. Arraste para movê-lo ao redor do minimapa.",
    [HIDE] = "Ocultar botão do minimapa", [BACK] = "%s: botão do minimapa oculto. Ative-o de novo nas opções (Mostrar botão do minimapa)." },
  ruRU = { [SHOW] = "Показывать кнопку у миникарты", [TIP] = "Кнопка %s на краю миникарты. Перетащите, чтобы передвинуть её вокруг миникарты.",
    [HIDE] = "Скрыть кнопку у миникарты", [BACK] = "%s: кнопка у миникарты скрыта. Включить снова можно в настройках (Показывать кнопку у миникарты)." },
  zhTW = { [SHOW] = "顯示小地圖按鈕", [TIP] = "%s 在小地圖邊緣的按鈕。拖曳即可沿小地圖移動。",
    [HIDE] = "隱藏小地圖按鈕", [BACK] = "%s：已隱藏小地圖按鈕。可在選項中重新開啟（顯示小地圖按鈕）。" },
  zhCN = { [SHOW] = "显示小地图按钮", [TIP] = "%s 在小地图边缘的按钮。拖动即可沿小地图移动。",
    [HIDE] = "隐藏小地图按钮", [BACK] = "%s：已隐藏小地图按钮。可在选项中重新开启（显示小地图按钮）。" },
}
function M.Word(text)
  local loc = Call(GetLocale)
  local t = type(loc) == "string" and WORDS[loc]
  return t and t[text] or text
end

function M:Attach(ns, opts)
  assert(type(ns) == "table" and type(opts) == "table" and type(opts.name) == "string",
    "DonCore MinimapButton:Attach(ns, { name = ... })")
  local angleKey = opts.angleKey or "minimapAngle"
  local button, menu, catcher

  -- Questdon, Dropdon, Guildon have ns.Guard; Luredon has ns.Safe (same shape)
  local function Guard(context, fn)
    local g = ns.Guard or ns.Safe
    return g and g(context, fn) or fn
  end
  local function Style() return ns.Style end
  local function HideTip(f) local S = Style() if S and S.HideTooltip then S.HideTooltip(f) end end

  local enabledKey = opts.enabledKey or "minimapButton"
  local function Enabled()
    if opts.enabled then return Call(opts.enabled) and true or false end
    return ns.db and ns.db[enabledKey] and true or false
  end
  -- (minor 3) a switch never set counts as on (opts.defaultOn = false: off) and is written, so the option shows it
  local function Default()
    if type(ns.db) == "table" and ns.db[enabledKey] == nil then ns.db[enabledKey] = opts.defaultOn ~= false end
  end

  local function Shape()
    local s = Call(GetMinimapShape)
    return type(s) == "string" and s or "ROUND"
  end

  -- on the edge of the minimap at the saved angle (degrees, 0 = right, counter-clockwise)
  local function Place()
    if not button or not Minimap then return end
    local angle = math.rad(tonumber(ns.db and ns.db[angleKey]) or opts.defaultAngle or 200)
    local w = (Num(Call(Minimap.GetWidth, Minimap)) or 140) / 2 + 8
    local h = (Num(Call(Minimap.GetHeight, Minimap)) or 140) / 2 + 8
    local x, y = math.cos(angle), math.sin(angle)
    if Shape() == "SQUARE" then
      local m = math.max(math.abs(x), math.abs(y))
      if m > 0 then x, y = x / m, y / m end
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
  end

  -------------------------------------------------------------------------
  -- Menu (Questdon's, items from the addon)
  -------------------------------------------------------------------------
  local function HideMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
  end

  local function Edge(f, r, g, b, a)
    local function Line(p1, p2, horiz)
      local t = f:CreateTexture(nil, "BORDER")
      t:SetColorTexture(r, g, b, a)
      t:SetPoint(p1, f, p1) t:SetPoint(p2, f, p2)
      if horiz then t:SetHeight(1) else t:SetWidth(1) end
    end
    Line("TOPLEFT", "TOPRIGHT", true) Line("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Line("TOPLEFT", "BOTTOMLEFT") Line("TOPRIGHT", "BOTTOMRIGHT")
  end

  local function UpdateMenu()
    if not menu then return end
    for _, r in ipairs(menu.checkRows) do
      if Call(r.item.isOn) then r.tick:Show() else r.tick:Hide() end
    end
  end

  local function Row(parent, y, item)
    local check = item.isOn ~= nil
    local r = CreateFrame("Button", nil, parent)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -y)
    r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -y)
    r:SetHeight(24)
    r.hover = r:CreateTexture(nil, "BACKGROUND")
    r.hover:SetAllPoints(r)
    r.hover:SetColorTexture(1, 1, 1, 0.07)
    r.hover:Hide()
    if check then
      r.box = r:CreateTexture(nil, "ARTWORK")
      r.box:SetSize(20, 20)
      r.box:SetPoint("LEFT", r, "LEFT", 2, 0)
      r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
      r.tick = r:CreateTexture(nil, "OVERLAY")
      r.tick:SetSize(20, 20)
      r.tick:SetPoint("CENTER", r.box, "CENTER", 0, 0)
      r.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    end
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", r, "LEFT", check and 28 or 8, 0)
    r.text:SetPoint("RIGHT", r, "RIGHT", -4, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    r.text:SetText(Get(item.text) or "")
    r.item = item
    r:SetScript("OnEnter", function(self) self.hover:Show() end)
    r:SetScript("OnLeave", function(self) self.hover:Hide() end)
    r:SetScript("OnClick", Guard("minimap menu", function()
      if not check then HideMenu() end
      if item.onClick then item.onClick() end
      UpdateMenu()
    end))
    return r
  end

  local function CreateMenu()
    local mo, S = opts.menu, Style()
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:RegisterForClicks("AnyUp")
    catcher:SetScript("OnClick", HideMenu)
    catcher:Hide()
    menu = CreateFrame("Frame", mo.name, UIParent)
    menu:SetFrameStrata("DIALOG")
    local lvl = Num(Call(catcher.GetFrameLevel, catcher))
    if lvl and menu.SetFrameLevel then menu:SetFrameLevel(lvl + 10) end
    menu:SetWidth(mo.width or 250)
    menu:EnableMouse(true)
    menu:SetClampedToScreen(true)
    menu:Hide()
    local bg = menu:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(menu)
    bg:SetColorTexture(1, 1, 1, 1)
    if bg.SetGradient and CreateColor then
      pcall(bg.SetGradient, bg, "VERTICAL", CreateColor(0.15, 0.10, 0.25, 0.97), CreateColor(0.10, 0.11, 0.22, 0.97))
    else
      bg:SetColorTexture(0.10, 0.11, 0.22, 0.97)
    end
    local G = S and S.BOOK and S.BOOK.gold or { 0.85, 0.7, 0.35 } -- the book's gold from the kit
    Edge(menu, G[1], G[2], G[3], 0.9)
    local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", menu, "TOPLEFT", 14, -10)
    title:SetText(Get(mo.title) or Get(opts.title) or "")
    local y = 32
    menu.checkRows = {}
    local items = type(mo.items) == "function" and (Call(mo.items) or {}) or mo.items or {}
    if not mo.noHide then
      local all = {}
      for i, it in ipairs(items) do all[i] = it end
      all[#all + 1] = { line = true }
      all[#all + 1] = { text = M.Word(HIDE), onClick = function() ns.HideMinimapButtonByMenu() end }
      items = all
    end
    for _, item in ipairs(items) do
      if item.line then
        local line = menu:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(G[1], G[2], G[3], 0.35)
        line:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -y - 2)
        line:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -12, -y - 2)
        line:SetHeight(1)
        y = y + 6
      else
        local r = Row(menu, y, item)
        if r.tick then menu.checkRows[#menu.checkRows + 1] = r y = y + 24 else y = y + 26 end
      end
    end
    menu:SetHeight(y + 8)
    if mo.name and type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, mo.name) end
    menu:SetScript("OnHide", function() if catcher then catcher:Hide() end end)
  end

  local function ShowMenu()
    if not opts.menu or not button then return end
    if not menu then CreateMenu() end
    UpdateMenu()
    menu:ClearAllPoints()
    -- open towards the middle of the screen
    local _, by = button:GetCenter()
    local _, sy = UIParent:GetCenter()
    if (Num(by) or 0) > (Num(sy) or 0) then
      menu:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", 4, 4)
    else
      menu:SetPoint("BOTTOMRIGHT", button, "TOPLEFT", 4, -4)
    end
    catcher:Show()
    menu:Show()
  end

  -------------------------------------------------------------------------
  -- Button
  -------------------------------------------------------------------------
  local function Create()
    if button or not Minimap then return end
    button = CreateFrame("Button", opts.name, Minimap)
    button:SetFrameStrata("MEDIUM")
    local lvl = Num(Call(Minimap.GetFrameLevel, Minimap))
    if lvl and button.SetFrameLevel then button:SetFrameLevel(lvl + 8) end
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    -- (minor 3) the gold ring is back: the dark disc, the round symbol and Blizzard's tracking border on top, placed like
    -- the other minimap buttons of the game (31 px button, ring 53 px from the top left corner, symbol 17 px)
    button:SetSize(31, 31)
    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    local file = opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    icon:SetTexture(file)
    -- an icon of the game has a dark border to cut off; the addon's own picture is shown whole
    local tc = opts.iconCoords
    if type(tc) ~= "table" then
      tc = (type(file) ~= "string" or file:lower():find("^interface[\\/]icons[\\/]")) and { 0.08, 0.92, 0.08, 0.92 } or { 0, 1, 0, 1 }
    end
    if icon.SetTexCoord then icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4]) end
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.bg, button.ring = bg, ring
    if button.CreateMaskTexture then
      local ok, mask = pcall(button.CreateMaskTexture, button)
      if ok and mask then
        pcall(mask.SetTexture, mask, "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        if icon.AddMaskTexture then pcall(icon.AddMaskTexture, icon, mask) end
      end
    end
    local hl = button:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(button)
    hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    if hl.SetBlendMode then hl:SetBlendMode("ADD") end
    button.icon = icon

    button:SetScript("OnClick", Guard("minimap button", function(self, which)
      HideTip(self)
      if which == "RightButton" then
        if opts.menu then
          if menu and menu:IsShown() then HideMenu() else ShowMenu() end
        elseif opts.onRight then
          opts.onRight()
        end
      else
        HideMenu()
        if opts.onLeft then opts.onLeft() end
      end
    end))
    button:SetScript("OnEnter", Guard("minimap button", function(self)
      if menu and menu:IsShown() then return end
      local S = Style()
      if S and S.Tooltip then S.Tooltip(self, Get(opts.title), Get(opts.lines), Get(opts.hint), "ANCHOR_LEFT") end
    end))
    button:SetScript("OnLeave", function(self) HideTip(self) end)
    -- dragging: the button follows the cursor around the minimap
    button:SetScript("OnDragStart", function(self)
      HideTip(self)
      self:SetScript("OnUpdate", Guard("minimap button", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Num(Call(Minimap.GetEffectiveScale, Minimap)) or 1
        if not (mx and cx) then return end
        local dy, dx = cy / scale - my, cx / scale - mx
        local a = math.deg(math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx))
        ns.db[angleKey] = math.floor((a % 360) + 0.5)
        Place()
      end))
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    Place()
  end

  function ns.RefreshMinimapButton()
    Default()
    if not Enabled() then
      if button then button:Hide() end
      HideMenu()
      return
    end
    if not button then Create() end
    if button then Place() button:Show() end
  end
  function ns.MinimapButton() return button end -- (tests)
  -- (minor 4) the menu's last row: switch off, hide, say where it comes back
  function ns.HideMinimapButtonByMenu()
    if opts.setEnabled then Call(opts.setEnabled, false)
    elseif type(ns.db) == "table" then ns.db[enabledKey] = false end
    ns.RefreshMinimapButton()
    if ns.RefreshOptions then Call(ns.RefreshOptions) end
    local name = opts.addon or opts.name
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage(M.Word(BACK):format(name))
    end
  end
  -- (minor 3) the switch for the addon's options: one line in its pages (see the head of the file)
  function ns.MinimapOption(o)
    o = type(o) == "table" and o or {}
    local addon = opts.addon or (opts.name:gsub("MinimapButton$", ""))
    return { key = enabledKey, parent = o.parent, donCommon = true,
      name = o.name or M.Word("Show minimap button"),
      tip = o.tip or M.Word("%s's button on the edge of the minimap. Drag it to move it around the minimap."):format(addon),
      onChange = function() ns.RefreshMinimapButton() end }
  end
  if opts.menu then
    ns.ShowMinimapMenu = ShowMenu
    ns.HideMinimapMenu = HideMenu
    function ns.MinimapMenuShown() return menu ~= nil and menu:IsShown() end
  end
end

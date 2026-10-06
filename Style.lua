local _, ns = ...

---------------------------------------------------------------------------
-- Style kit (ns.Style). Identical copy in every addon, see DESIGN.md.
-- Only own frames: no hooks, no scripts on Blizzard frames, no Blizzard UI
-- helper functions. GameTooltip is used directly (SetOwner/AddLine/Show/Hide).
-- The kit owns no SavedVariables: panels read and write their state through
-- the get/set callbacks the caller passes in.
---------------------------------------------------------------------------
local Style = ns.Style or {}
ns.Style = Style
Style.VERSION = 2
-- Style.onError = function(where, err) ... end (set by the addon). Called when
-- a protected addon callback fails. nil (default): errors stay silent as in v1.

local WHITE = "Interface\\Buttons\\WHITE8x8"
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local pairs, ipairs, type, tostring, tonumber, pcall = pairs, ipairs, type, tostring, tonumber, pcall

---------------------------------------------------------------------------
-- Tokens
---------------------------------------------------------------------------
local COLORS = {
  background    = { 0.06, 0.07, 0.09 },
  header        = { 0.09, 0.10, 0.13 },
  border        = { 1, 1, 1, 0.08 },
  divider       = { 1, 1, 1, 0.06 },
  textPrimary   = { 0.92, 0.92, 0.92 },
  textSecondary = { 0.62, 0.64, 0.68 },
  textHint      = { 0.45, 0.47, 0.50 },
  accent        = { 0.25, 0.66, 0.96, hex = "ff3fa9f5" },
  good          = { 0.40, 0.80, 0.45 },
  warning       = { 0.95, 0.75, 0.25 },
  critical      = { 0.92, 0.35, 0.32 },
  rowHover      = { 1, 1, 1, 0.05 },
  rowActive     = { 0.25, 0.66, 0.96, 0.12 },
  barBackground = { 1, 1, 1, 0.06 },
  barBorder     = { 1, 1, 1, 0.08 },
}
for _, c in pairs(COLORS) do
  if not c.hex then
    c.hex = string.format("ff%02x%02x%02x", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
  end
end
Style.COLORS = COLORS

local S = {
  unit = 4,
  padX = 8, padY = 6,
  header = 20, titleX = 8, button = 14, buttonGap = 4, buttonRight = 4,
  rowGap = 2, section = 8,
  icon = 14, iconGap = 4,
  valueGap = 8,
  bar = 6,
  minWidth = 220,
  activeBar = 2,
}
Style.SPACING = S

Style.DEFAULT_ALPHA = 0.82
Style.COMBAT_ALPHA = 0.40
Style.FADE_TIME = 0.15
Style.SCALE_MIN, Style.SCALE_MAX = 0.6, 1.6
local MAX_RETRIES = 20

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Call(obj, method, ...)
  if obj and type(obj[method]) == "function" then return pcall(obj[method], obj, ...) end
  return false
end

-- Forward a failed pcall to Style.onError (if the addon set one).
local function Report(where, err)
  local fn = Style.onError
  if type(fn) == "function" then pcall(fn, where, err) end
end

-- pcall that reports failures; returns ok and up to three results.
local function Try(where, fn, ...)
  local ok, a, b, c = pcall(fn, ...)
  if not ok then Report(where, a) end
  return ok, a, b, c
end

local function Clamp(v, lo, hi)
  v = tonumber(v)
  if not v or v ~= v then return lo end
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function Color(c, fallback)
  if type(c) == "string" then c = COLORS[c] end
  if type(c) ~= "table" then c = fallback or COLORS.textPrimary end
  return c
end

-- Flat texture (WHITE8x8 tinted), never a gradient.
local function Flat(parent, layer, color, alpha, sub)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
  t:SetTexture(WHITE)
  color = Color(color)
  t:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
  return t
end

local function Tint(tex, color, alpha)
  color = Color(color)
  tex:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
end

local function NewFont(parent, template, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", template)
  if not fs:GetFontObject() and _G[template] then Call(fs, "SetFontObject", _G[template]) end
  color = Color(color)
  fs:SetTextColor(color[1], color[2], color[3], 1)
  fs:SetJustifyH("LEFT")
  Call(fs, "SetJustifyV", "TOP")
  Call(fs, "SetWordWrap", true)
  Call(fs, "SetNonSpaceWrap", true)
  return fs
end

local function FontSize(fs)
  local ok, _, size = Call(fs, "GetFont")
  size = ok and tonumber(size)
  if size and size > 0 then return size end
  return 12
end

local function HasText(fs)
  local t = fs:GetText()
  return t ~= nil and t ~= ""
end

-- Height of a FontString's text. Second return false: not measurable yet
-- (fonts not rendered); the first value is then an estimate.
local function TextHeight(fs)
  if not HasText(fs) then return 0, true end
  local ok, h = Call(fs, "GetStringHeight")
  if ok and type(h) == "number" and h == h and h > 0 then return ceil(h), true end
  return ceil(FontSize(fs) + 2), false
end

local function TextWidth(fs)
  if not HasText(fs) then return 0, true end
  local ok, w = Call(fs, "GetStringWidth")
  if ok and type(w) == "number" and w == w and w > 0 then return ceil(w), true end
  local plain = tostring(fs:GetText()):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return ceil(#plain * FontSize(fs) * 0.55), false
end

---------------------------------------------------------------------------
-- (i18n) Text that has to fit a width. Other languages are often longer than
-- English, so a text first gets up to FIT_SHRINK points smaller (never under
-- FIT_MIN). Only if that is not enough:
--   mode "cut" (default): one line, cut with "..." by the game; the whole text
--     stays in Style.FullText(fs) for a tooltip;
--   mode "wrap": back to the normal size, the caller lets it wrap as before.
-- A text that fits gets its own width (at most the budget), so frames anchored
-- to its right edge stay where they belong. Every cut or wrap is noted in
-- Style.TextCuts (text -> width, budget, mode) for /diag and the tests.
---------------------------------------------------------------------------
Style.FIT_SHRINK, Style.FIT_MIN = 2, 9
Style.TextCuts = {}

local function BaseFont(fs)
  local base = fs._fitBase
  if not base then
    local ok, path, size, flags = Call(fs, "GetFont")
    size = ok and tonumber(size)
    if not (ok and type(path) == "string" and size and size > 0) then return nil end
    base = { path, size, flags }
    fs._fitBase = base
  end
  return base
end

local function SetSize(fs, base, size)
  if fs._fitSize ~= size then
    Call(fs, "SetFont", base[1], size, base[3])
    fs._fitSize = size
  end
end

-- Width of the whole text on one line (even when it is cut on screen).
local function NaturalWidth(fs)
  local ok, w = Call(fs, "GetUnboundedStringWidth")
  if ok and type(w) == "number" and w == w and w > 0 then return w end
  ok, w = Call(fs, "GetStringWidth")
  if ok and type(w) == "number" and w == w and w > 0 then return w end
  return nil
end

function Style.FitText(fs, budget, mode)
  budget = tonumber(budget)
  if not fs or not budget or budget <= 0 or budget ~= budget then return true end
  local wrap = mode == "wrap"
  local text0 = fs.GetText and fs:GetText()
  if type(text0) == "string" and text0:find("\n", 1, true) then return true end -- several lines on purpose
  -- same text, same space, same mode as last time: nothing to do (relayouts are frequent)
  local key = tostring(text0) .. "\0" .. budget .. (wrap and "w" or "c")
  if fs._fitKey == key and fs._fitDone ~= nil then return fs._fitDone end
  local result = Style._Fit(fs, budget, wrap)
  fs._fitKey, fs._fitDone = key, result
  return result
end

function Style._Fit(fs, budget, wrap)
  local base = BaseFont(fs)
  if base then SetSize(fs, base, base[2]) end
  if not wrap then
    Call(fs, "SetWordWrap", false)
    Call(fs, "SetWidth", 0)
  end
  local w = NaturalWidth(fs)
  if not w then fs._fitFull = nil return true end -- nothing to show or not measurable yet
  local size = base and base[2]
  local low0 = base and max(Style.FIT_MIN, base[2] - Style.FIT_SHRINK)
  local hopeless = wrap and base and w * low0 / base[2] > budget * 1.02
  if base and w > budget and not hopeless then
    local low = max(Style.FIT_MIN, base[2] - Style.FIT_SHRINK)
    while w > budget and size > low do
      size = size - 1
      SetSize(fs, base, size)
      w = NaturalWidth(fs) or w * size / (size + 1)
    end
  end
  if w <= budget + 0.5 then
    fs._fitFull = nil
    if not wrap then Call(fs, "SetWidth", min(budget, ceil(w) + 1)) end
    return true
  end
  local text = fs:GetText()
  if type(text) == "string" and text ~= "" then
    Style.TextCuts[text] = { width = ceil(w), budget = floor(budget), mode = wrap and "wrap" or "cut", size = size }
  end
  if wrap then
    if base then SetSize(fs, base, base[2]) end -- wrapped at the normal size reads better
    fs._fitFull = nil
  else
    Call(fs, "SetWidth", budget)
    fs._fitFull = text
  end
  return false
end

-- The whole text of a cut FontString (nil when nothing was cut).
function Style.FullText(fs) return fs and fs._fitFull end

-- Number of texts cut or wrapped so far (diag).
function Style.TextCutCount()
  local n = 0
  for _ in pairs(Style.TextCuts) do n = n + 1 end
  return n
end

-- Size of one physical screen pixel in the frame's coordinates.
local function Pixel(frame)
  local ok, _, h = pcall(GetPhysicalScreenSize)
  local okS, scale = Call(frame, "GetEffectiveScale")
  h, scale = ok and tonumber(h), okS and tonumber(scale)
  if h and h > 0 and scale and scale > 0 then return 768 / h / scale end
  return 1
end

function Style.Hex(color) return Color(color).hex end
function Style.Colorize(text, color) return "|c" .. Color(color).hex .. tostring(text) .. "|r" end
function Style.Wordmark(accentPart, rest)
  return "|c" .. COLORS.accent.hex .. tostring(accentPart or "") .. "|r" .. tostring(rest or "")
end

function Style.Number(n)
  n = tonumber(n)
  if not n then return "" end
  if type(BreakUpLargeNumbers) == "function" then
    local ok, s = pcall(BreakUpLargeNumbers, n)
    if ok and s then return s end
  end
  local s = tostring(floor(n + 0.5))
  local k
  repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2") until k == 0
  return s
end

function Style.Percent(fraction, decimals)
  fraction = tonumber(fraction) or 0
  if fraction ~= fraction then fraction = 0 end
  return string.format("%." .. (tonumber(decimals) or 0) .. "f %%", fraction * 100)
end

---------------------------------------------------------------------------
-- Next-frame execution: C_Timer.After(0) when present, own OnUpdate otherwise
---------------------------------------------------------------------------
local deferFrame = CreateFrame("Frame")
local deferQueue = {}
local function RunDeferred(self)
  self:SetScript("OnUpdate", nil)
  local q = deferQueue
  deferQueue = {}
  for _, fn in ipairs(q) do Try("deferred", fn) end
end
local function After0(fn)
  if C_Timer and type(C_Timer.After) == "function" and pcall(C_Timer.After, 0, fn) then return end
  deferQueue[#deferQueue + 1] = fn
  deferFrame:SetScript("OnUpdate", RunDeferred)
end

---------------------------------------------------------------------------
-- Fades: one own animator frame, OnUpdate only while a fade runs
---------------------------------------------------------------------------
local animator = CreateFrame("Frame")
local fades = {}

local function AnimUpdate(self, elapsed)
  local finished
  for frame, st in pairs(fades) do
    st.t = st.t + (tonumber(elapsed) or 0)
    local k = st.dur > 0 and min(1, st.t / st.dur) or 1
    frame:SetAlpha(st.from + (st.to - st.from) * k)
    if k >= 1 then
      finished = finished or {}
      finished[#finished + 1] = { frame, st }
    end
  end
  if finished then
    for _, f in ipairs(finished) do
      if fades[f[1]] == f[2] then fades[f[1]] = nil end
      if f[2].done then Try("fade", f[2].done, f[1]) end
    end
  end
  if not next(fades) then self:SetScript("OnUpdate", nil) end
end

local function FadeTo(frame, to, done, hiding)
  local from = frame:GetAlpha() or 1
  if from == to then
    fades[frame] = nil
    frame:SetAlpha(to)
    if done then Try("fade", done, frame) end
    return
  end
  fades[frame] = { from = from, to = to, t = 0, dur = Style.FADE_TIME, done = done, hiding = hiding }
  animator:SetScript("OnUpdate", AnimUpdate)
end

---------------------------------------------------------------------------
-- Kit event frame: UI scale, display size, combat
---------------------------------------------------------------------------
local panels = {}
local inCombat = false
do
  local ok, v = pcall(InCombatLockdown)
  inCombat = ok and v and true or false
end

local function TargetAlpha(p)
  if p._combatFade and inCombat then return Style.COMBAT_ALPHA end
  return 1
end

local function ApplyCombatAlpha(p)
  local st = fades[p]
  if st and st.hiding then return end
  if p:IsShown() then FadeTo(p, TargetAlpha(p)) else p:SetAlpha(TargetAlpha(p)) end
end

-- Any other own frame (arrow, XP strip, ...): dimmed to 40 % of its own alpha
-- in combat, its own alpha restored afterwards. Weak keys: no leak.
local fadeFrames = setmetatable({}, { __mode = "k" })

local function SetOrFade(frame, to)
  local okV, visible = Call(frame, "IsVisible")
  if okV and not visible then
    fades[frame] = nil
    frame:SetAlpha(to)
  else
    FadeTo(frame, to)
  end
end

local function ApplyFrameCombat(frame)
  local st = fadeFrames[frame]
  if not st then return end
  if inCombat and st.enabled then
    if not st.dimmed then
      local run = fades[frame]
      st.base = run and run.to or tonumber(frame:GetAlpha()) or 1
      st.dimmed = true
      SetOrFade(frame, st.base * Style.COMBAT_ALPHA)
    end
  elseif st.dimmed then
    st.dimmed = false
    SetOrFade(frame, st.base or 1)
  end
  if not st.enabled and not st.dimmed then fadeFrames[frame] = nil end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    inCombat = event == "PLAYER_REGEN_DISABLED"
    for _, p in ipairs(panels) do
      if p._combatFade then ApplyCombatAlpha(p) end
    end
    local list
    for f in pairs(fadeFrames) do list = list or {}; list[#list + 1] = f end
    if list then for _, f in ipairs(list) do ApplyFrameCombat(f) end end
  else
    for _, p in ipairs(panels) do
      p._retries = 0
      Style.RequestRelayout(p)
    end
  end
end)

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
-- "auto": the side of the screen with more room next to the owner.
-- Falls back to ANCHOR_RIGHT when positions or the screen size are unknown.
local function AutoAnchor(owner)
  local okL, l = Call(owner, "GetLeft")
  local okR, r = Call(owner, "GetRight")
  local okS, s = Call(owner, "GetEffectiveScale")
  local okW, w = Call(UIParent, "GetWidth")
  local okU, us = Call(UIParent, "GetEffectiveScale")
  l, r, s = okL and tonumber(l), okR and tonumber(r), okS and tonumber(s)
  w, us = okW and tonumber(w), okU and tonumber(us)
  if not (l and r and s and w and us) or w <= 0 or s <= 0 or us <= 0 then return "ANCHOR_RIGHT" end
  local screen = w * us
  if l * s > screen - r * s then return "ANCHOR_LEFT" end
  return "ANCHOR_RIGHT"
end
Style.AutoAnchor = AutoAnchor

-- lines: array of strings (wrapped, secondary), { label, value [, color] }
-- (label left in secondary, value right in primary or the given colour) or
-- { header = "Text" } (sub-heading in secondary, blank line before it).
-- anchor: nil = "ANCHOR_RIGHT" (v1), "auto" = side with more room.
function Style.Tooltip(owner, title, lines, hint, anchor)
  local tt = GameTooltip
  if not tt or not owner then return end
  if anchor == "auto" then anchor = AutoAnchor(owner) end
  if not pcall(tt.SetOwner, tt, owner, anchor or "ANCHOR_RIGHT") then return end
  local P, K, H = COLORS.textPrimary, COLORS.textSecondary, COLORS.textHint
  if title and title ~= "" then pcall(tt.AddLine, tt, tostring(title), P[1], P[2], P[3], true) end
  if type(lines) == "table" and #lines > 0 then
    pcall(tt.AddLine, tt, " ")
    for i, line in ipairs(lines) do
      if type(line) == "table" then
        if line.header ~= nil then
          if i > 1 then pcall(tt.AddLine, tt, " ") end
          pcall(tt.AddLine, tt, tostring(line.header), K[1], K[2], K[3], true)
        elseif line[2] ~= nil then
          local vc = Color(line[3], P)
          pcall(tt.AddDoubleLine, tt, tostring(line[1] or ""), tostring(line[2]), K[1], K[2], K[3], vc[1], vc[2], vc[3])
        else
          pcall(tt.AddLine, tt, tostring(line[1] or ""), K[1], K[2], K[3], true)
        end
      elseif line ~= nil then
        pcall(tt.AddLine, tt, tostring(line), K[1], K[2], K[3], true)
      end
    end
  end
  if hint and hint ~= "" then pcall(tt.AddLine, tt, tostring(hint), H[1], H[2], H[3], true) end
  pcall(tt.Show, tt)
end

function Style.HideTooltip(owner)
  local tt = GameTooltip
  if not tt then return end
  local ok, owned = pcall(tt.IsOwned, tt, owner)
  if ok and owned then pcall(tt.Hide, tt) end
end

---------------------------------------------------------------------------
-- Icons: Blizzard atlas when the client knows it, texture file otherwise
---------------------------------------------------------------------------
local ICONS = {
  close    = { atlas = { "uitools-icon-close" },        file = "Interface\\Buttons\\UI-StopButton" },
  collapse = { atlas = { "uitools-icon-minimize" },     file = "Interface\\Buttons\\UI-MinusButton-Up" },
  expand   = { atlas = { "uitools-icon-plus" },         file = "Interface\\Buttons\\UI-PlusButton-Up" },
  options  = { atlas = { "QuestLog-icon-setting" },    file = "Interface\\Buttons\\UI-OptionsButton" },
  back     = { atlas = { "common-icon-backarrow" },     file = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" },
  forward  = { atlas = { "common-icon-forwardarrow" },  file = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
}
Style.ICONS = ICONS

local function AtlasKnown(name)
  if C_Texture and type(C_Texture.GetAtlasInfo) == "function" then
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
  end
  return nil -- unknown: try SetAtlas and check
end

local function SetAtlasOrFile(tex, atlases, file)
  if type(tex.SetAtlas) == "function" then
    for _, name in ipairs(atlases or {}) do
      local known = AtlasKnown(name)
      if known ~= false then
        local ok, res = pcall(tex.SetAtlas, tex, name, false)
        if ok and res ~= false then
          local okG, cur = Call(tex, "GetAtlas")
          if known or not okG or cur == name then return "atlas", name end
        end
      end
    end
  end
  tex:SetTexture(file)
  Call(tex, "SetTexCoord", 0, 1, 0, 1)
  return "file", file
end

---------------------------------------------------------------------------
-- IconButton
---------------------------------------------------------------------------
local function IconButtonSetKind(b, kind)
  local def = ICONS[kind] or ICONS.close
  b.kind = ICONS[kind] and kind or "close"
  b.iconSource, b.iconName = SetAtlasOrFile(b.icon, def.atlas, def.file)
  Call(b.icon, "SetDesaturated", true)
  Tint(b.icon, (b._hover and not b._disabled) and "textPrimary" or "textSecondary")
end

Style.DISABLED_ALPHA = 0.35

-- Disabled: alpha 0.35, no hover tint, no click. The tooltip stays available.
local function IconButtonSetEnabled(b, enabled)
  enabled = enabled and true or false
  b._disabled = not enabled
  if b._nativeSetEnabled then pcall(b._nativeSetEnabled, b, enabled) end
  b:SetAlpha(enabled and 1 or Style.DISABLED_ALPHA)
  Tint(b.icon, (enabled and b._hover) and "textPrimary" or "textSecondary")
  return b
end

-- title may be a table { title, lines, hint } (or named fields).
local function IconButtonSetTooltip(b, title, lines, hint)
  if type(title) == "table" then
    local t = title
    title, lines, hint = t.title or t[1], t.lines or t[2], t.hint or t[3]
  end
  b._ttTitle, b._ttLines, b._ttHint = title, lines, hint
  return b
end

function Style.IconButton(parent, kind)
  local b = CreateFrame("Button", nil, parent)
  b._isStyleIconButton = true
  b:SetSize(S.button, S.button)
  Call(b, "SetHitRectInsets", -2, -2, -2, -2)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints(b)
  b.SetKind = IconButtonSetKind
  b:SetKind(kind)
  Call(b, "RegisterForClicks", "LeftButtonUp", "RightButtonUp")
  b:SetScript("OnEnter", function(self)
    self._hover = true
    if not self._disabled then Tint(self.icon, "textPrimary") end
    if self._ttTitle then Style.Tooltip(self, self._ttTitle, self._ttLines, self._ttHint, self._ttAnchor) end
  end)
  b:SetScript("OnLeave", function(self)
    self._hover = false
    Tint(self.icon, "textSecondary")
    Style.HideTooltip(self)
  end)
  b:SetScript("OnClick", function(self, ...)
    if self._disabled or not self._onClick then return end
    self._onClick(self, ...)
  end)
  function b:SetOnClick(fn) self._onClick = type(fn) == "function" and fn or nil; return self end
  b.SetTooltip = IconButtonSetTooltip
  function b:SetTooltipAnchor(anchor) self._ttAnchor = anchor; return self end
  -- Disabled buttons keep OnEnter/OnLeave (tooltip, hover reset).
  Call(b, "SetMotionScriptsWhileDisabled", true)
  b._nativeSetEnabled = type(b.SetEnabled) == "function" and b.SetEnabled or nil
  b.SetEnabled = IconButtonSetEnabled
  function b:Enable() return self:SetEnabled(true) end
  function b:Disable() return self:SetEnabled(false) end
  function b:IsEnabled() return not self._disabled end
  return b
end

---------------------------------------------------------------------------
-- Items in a panel (rows, headers, bars) and relayout
---------------------------------------------------------------------------
-- Visibility of panel items. The kit replaces Show/Hide/SetShown on its own
-- item frames (rows, headers, panel bars, content holders) so that a
-- visibility change requests a relayout. Kit-internal changes use the
-- original methods (RawShow/RawHide) and never request one.
-- _collapseHidden: hidden only because the panel is collapsed with kept
-- items; logically the item is still shown.
local function RawShow(item) if item._rawShow then item._rawShow(item) else item:Show() end end
local function RawHide(item) if item._rawHide then item._rawHide(item) else item:Hide() end end
local function LogicallyShown(item) return item._collapseHidden or item:IsShown() end

local function Changed(item)
  local p = item._panel
  if p then p._retries = 0; Style.RequestRelayout(p) end
end

local function ItemShow(self)
  if self._collapseHidden then return end
  local was = self:IsShown()
  RawShow(self)
  if self._inUse and not was then Changed(self) end
end

local function ItemHide(self)
  local flagged = self._collapseHidden
  self._collapseHidden = nil
  local was = self:IsShown()
  RawHide(self)
  if self._inUse and (was or flagged) then Changed(self) end
end

local function ItemSetShown(self, shown)
  if shown then self:Show() else self:Hide() end
end

-- Keep this item visible while the panel is collapsed.
local function ItemSetKeep(self, keep)
  keep = keep and true or false
  if (self._keep or false) == keep then return self end
  self._keep = keep
  if keep and self._collapseHidden then
    self._collapseHidden = nil
    RawShow(self)
  end
  if self._panel and self._panel._collapsed then Changed(self) end
  return self
end

-- Called once the item is in use and appended to panel._order: show it, or
-- keep it hidden when the panel is collapsed with kept items and this one is
-- not among the first collapseKeep entries.
local function EnterItem(panel, item)
  if panel._collapsed and panel._keepMode then
    local n, kept = tonumber(panel._collapseKeep) or 0, false
    if n > 0 then
      local vis = 0
      for _, it in ipairs(panel._order) do
        if it._inUse and (it == item or LogicallyShown(it)) then vis = vis + 1 end
      end
      kept = vis <= n
    end
    if not kept then
      item._collapseHidden = true
      if item:IsShown() then RawHide(item) end
      return
    end
  end
  item._collapseHidden = nil
  if not item:IsShown() then RawShow(item) end
end

local function Acquire(panel, kind)
  for _, item in ipairs(panel._items) do
    if item._kind == kind and not item._inUse then
      item._inUse = true
      panel._order[#panel._order + 1] = item
      EnterItem(panel, item)
      return item, true
    end
  end
  return nil
end

local function Track(panel, item, kind)
  item._kind, item._inUse, item._panel = kind, true, panel
  item._rawShow, item._rawHide = item.Show, item.Hide
  item.Show, item.Hide, item.SetShown = ItemShow, ItemHide, ItemSetShown
  item.SetKeepWhenCollapsed = ItemSetKeep
  panel._items[#panel._items + 1] = item
  panel._order[#panel._order + 1] = item
  EnterItem(panel, item)
end

local function Release(item)
  local p = item._panel
  item._inUse = false
  item:Hide()
  if p then
    for i = #p._order, 1, -1 do if p._order[i] == item then table.remove(p._order, i) end end
    Style.RequestRelayout(p)
  end
end

function Style.RequestRelayout(panel)
  if not panel or not panel._isStylePanel then return end
  if panel._relayoutQueued then return end
  local token = (panel._relayoutToken or 0) + 1
  panel._relayoutToken, panel._relayoutQueued = token, true
  After0(function()
    if panel._relayoutQueued and panel._relayoutToken == token then Style.Relayout(panel) end
  end)
end

-- Bar geometry for a known width
local function BarUpdate(bar, width)
  width = tonumber(width) or 0
  local px = bar._px or 1
  local h = (bar._height or S.bar) - 2 * px
  local inner = width - 2 * px
  if inner <= 0 or h <= 0 then
    for _, seg in ipairs(bar._segs) do seg.tex:Hide() end
    return false
  end
  local cum = 0
  for i, seg in ipairs(bar._segs) do
    local v = Clamp(bar._values[i], 0, 1)
    local start = bar._stacked and cum or 0
    local len = min(v, 1 - start)
    if len < 0 then len = 0 end
    seg.start, seg.len = start, len
    if i <= bar._count and len * inner >= 0.5 then
      seg.tex:ClearAllPoints()
      seg.tex:SetPoint("TOPLEFT", bar, "TOPLEFT", px + start * inner, -px)
      seg.tex:SetSize(len * inner, h)
      seg.tex:Show()
    else
      seg.tex:Hide()
    end
    if bar._stacked then cum = start + len end
  end
  return true
end

local function BarBorder(bar, px)
  local b = bar._border
  b[1]:ClearAllPoints(); b[1]:SetPoint("TOPLEFT", bar, "TOPLEFT"); b[1]:SetPoint("TOPRIGHT", bar, "TOPRIGHT"); b[1]:SetHeight(px)
  b[2]:ClearAllPoints(); b[2]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT"); b[2]:SetHeight(px)
  b[3]:ClearAllPoints(); b[3]:SetPoint("TOPLEFT", bar, "TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT"); b[3]:SetWidth(px)
  b[4]:ClearAllPoints(); b[4]:SetPoint("TOPRIGHT", bar, "TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT"); b[4]:SetWidth(px)
end

local function RowLayout(row, width)
  local ok = true
  local left = S.padX + (row._indent or 0)
  local right = S.padX
  local textY = 0
  local size = FontSize(row.text)
  if row._iconSet then
    row.icon:ClearAllPoints()
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", left, 0)
    row.icon:Show()
    if S.icon > size then textY = floor((S.icon - size) / 2 + 0.5) end
    left = left + S.icon + S.iconGap
  else
    row.icon:Hide()
  end
  local inner = max(16, width - left - right)
  local vw, vh = 0, 0
  if HasText(row.value) then
    local maxV
    local spec = row._valueMax
    if spec then
      maxV = spec <= 1 and floor(inner * spec) or floor(spec)
      maxV = max(1, min(maxV, inner - 16 - S.valueGap))
    else
      maxV = floor(inner * 0.5)
      -- (i18n) a short label leaves the rest of the line to the value (longer languages)
      if HasText(row.text) then
        local lw, okL = TextWidth(row.text)
        if okL and lw < inner * 0.5 then maxV = max(maxV, floor(inner - lw - S.valueGap)) end
      end
    end
    -- (i18n) a little smaller before it wraps (longer languages)
    Style.FitText(row.value, maxV, "wrap")
    local w, okW = TextWidth(row.value)
    if not okW then ok = false end
    if spec then
      vw = row._valueFixed and maxV or min(w, maxV)
    else
      vw = min(w, maxV)
    end
    row.value:SetWidth(vw)
    local h, okH = TextHeight(row.value)
    if not okH then ok = false end
    vh = h + textY
    row.value:ClearAllPoints()
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", -right, -textY)
    row.value:Show()
  else
    row.value:Hide()
  end
  local tw = max(16, inner - (vw > 0 and (vw + S.valueGap) or 0))
  Style.FitText(row.text, tw, "wrap")
  row.text:SetWidth(tw)
  row.text:ClearAllPoints()
  row.text:SetPoint("TOPLEFT", row, "TOPLEFT", left, -textY)
  local th, okT = TextHeight(row.text)
  if not okT then ok = false end
  local h = max(th + textY, vh, row._iconSet and S.icon or 0)
  if row.bar and row.bar._inUse then
    local bar = row.bar
    bar._px = row._panel and row._panel._px or 1
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", left, -(h + S.rowGap))
    bar:SetSize(inner, bar._height)
    BarBorder(bar, bar._px)
    BarUpdate(bar, inner)
    bar:Show()
    h = h + S.rowGap + bar._height
  elseif row.bar then
    row.bar:Hide()
  end
  row._textWidth, row._valueWidth, row._left = tw, vw, left
  return max(h, 1), ok
end

local function HeaderLayout(hdr, width)
  hdr.text:SetWidth(width)
  hdr.text:ClearAllPoints()
  hdr.text:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, 0)
  local h, ok = TextHeight(hdr.text)
  return max(h, 1), ok
end

local function BarItemLayout(bar, width)
  bar._px = bar._panel and bar._panel._px or 1
  BarBorder(bar, bar._px)
  BarUpdate(bar, width)
  return bar._height, true
end

local function ContentLayout(c, width)
  return max(1, tonumber(c._height) or 1), true
end

local RowTooltip, RowUpdateMouse -- defined with the rows

-- After ClearRows a row under the mouse keeps its hover; once the content is
-- rebuilt, show hover and tooltip again (or drop them).
local function ResolveHover(row)
  row._hoverPending = nil
  RowUpdateMouse(row)
  local okM, over = Call(row, "IsMouseOver")
  local okV, visible = Call(row, "IsVisible")
  if (row._onClick or row._tooltip) and okM and over and (not okV or visible) then
    row.hover:Show()
    if row._tooltip then RowTooltip(row) else Style.HideTooltip(row) end
  else
    row.hover:Hide()
    Style.HideTooltip(row)
  end
end

local function FinishHover(panel)
  if not panel._hoverPending then return end
  panel._hoverPending = nil
  for _, item in ipairs(panel._order) do
    if item._hoverPending then ResolveHover(item) end
  end
end

-- Collapsed panel: mark the items that stay visible. Returns true if any.
local function MarkKept(panel)
  local n, vis, any = tonumber(panel._collapseKeep) or 0, 0, false
  for _, item in ipairs(panel._order) do
    item._keptNow = nil
    if item._inUse and LogicallyShown(item) then
      vis = vis + 1
      if item._keep or vis <= n then item._keptNow, any = true, true end
    end
  end
  return any
end

local function RestoreCollapsed(panel)
  for _, item in ipairs(panel._order) do
    if item._collapseHidden then
      item._collapseHidden = nil
      RawShow(item)
    end
  end
end

function Style.Relayout(panel)
  if not panel or not panel._isStylePanel then return end
  panel._relayoutQueued = false
  -- Items left over from ClearRows are hidden here (not in ClearRows), so a
  -- reused row under the mouse never gets OnLeave/OnEnter in between.
  for _, item in ipairs(panel._items) do
    if not item._inUse then
      item._collapseHidden = nil
      if item:IsShown() then
        RawHide(item)
        if item._isStyleRow then
          item._hoverPending = nil
          item.hover:Hide()
          Style.HideTooltip(item)
        end
      end
    end
  end
  local px = Pixel(panel)
  panel._px = px
  if panel._applyPixel then panel._applyPixel(px) end
  local width = max(S.minWidth, floor(tonumber(panel._width) or S.minWidth))
  panel:SetWidth(width)
  if panel._collapsed then
    if not MarkKept(panel) then
      panel._keepMode = false
      RestoreCollapsed(panel)
      panel._body:Hide()
      panel:SetHeight(S.header)
      panel._contentHeight = 0
      FinishHover(panel)
      return true
    end
    panel._keepMode = true
    for _, item in ipairs(panel._order) do
      if item._inUse and LogicallyShown(item) then
        if item._keptNow then
          if item._collapseHidden then item._collapseHidden = nil; RawShow(item) end
        elseif not item._collapseHidden then
          item._collapseHidden = true
          RawHide(item)
        end
      end
    end
  elseif panel._keepMode then
    panel._keepMode = false
    RestoreCollapsed(panel)
  end
  panel._body:Show()
  local y, first, allOk = S.padY, true, true
  for _, item in ipairs(panel._order) do
    if item._inUse and item:IsShown() then
      local gap = item._gapBefore
      if gap == nil then gap = first and 0 or (item._kind == "header" and S.section or S.rowGap) end
      y = y + gap
      local x, w = 0, width
      if item._inset then x, w = S.padX, width - 2 * S.padX end
      local h, ok = item._layout(item, w)
      if not ok then allOk = false end
      item:ClearAllPoints()
      item:SetPoint("TOPLEFT", panel._body, "TOPLEFT", x, -y)
      item:SetSize(w, h)
      item._y, item._h = y, h
      y = y + h
      first = false
    end
  end
  y = y + S.padY
  panel._contentHeight = y
  panel._body:SetHeight(y)
  panel:SetHeight(S.header + y)
  FinishHover(panel)
  if allOk then
    panel._retries = 0
  else
    panel._retries = (panel._retries or 0) + 1
    if panel._retries <= MAX_RETRIES then Style.RequestRelayout(panel) end
  end
  return allOk
end

---------------------------------------------------------------------------
-- Row
---------------------------------------------------------------------------
local RowMethods = {}

-- Setters skip work (and the relayout) when nothing changed: 1 s tickers
-- call them constantly.
function RowMethods:SetText(text, color)
  local s = text ~= nil and tostring(text) or ""
  if (self.text:GetText() or "") ~= s then
    self.text:SetText(s)
    Changed(self)
  end
  if color and color ~= self._textColor then
    local c = Color(color)
    self.text:SetTextColor(c[1], c[2], c[3], 1)
    self._textColor = color
  end
  return self
end

function RowMethods:SetValue(text, color)
  local s = text ~= nil and tostring(text) or ""
  if (self.value:GetText() or "") ~= s then
    self.value:SetText(s)
    Changed(self)
  end
  color = color or "textPrimary"
  if color ~= self._valueColor then
    local c = Color(color)
    self.value:SetTextColor(c[1], c[2], c[3], 1)
    self._valueColor = color
  end
  return self
end

function RowMethods:SetTextColor(color)
  local c = Color(color)
  self.text:SetTextColor(c[1], c[2], c[3], 1)
  self._textColor = color
  return self
end

local function SameTexCoord(a, b)
  if a == b then return true end
  if type(a) == "table" and type(b) == "table" then
    return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
  end
  return false
end

function RowMethods:SetIcon(icon, isAtlas, texCoord)
  if icon == nil or icon == "" then
    if not self._iconSet then return self end
    self._iconSet = false
    self._iconKey, self._iconAtlas, self._iconTC = nil, nil, nil
    self.icon:Hide()
  else
    isAtlas = isAtlas and true or false
    if self._iconSet and self._iconKey == icon and self._iconAtlas == isAtlas and SameTexCoord(self._iconTC, texCoord) then
      return self
    end
    self._iconSet = true
    self._iconKey, self._iconAtlas = icon, isAtlas
    self._iconTC = type(texCoord) == "table" and { texCoord[1], texCoord[2], texCoord[3], texCoord[4] } or texCoord
    local done = false
    if isAtlas then done = SetAtlasOrFile(self.icon, { icon }, "Interface\\Icons\\INV_Misc_QuestionMark") == "atlas" end
    if not done and not isAtlas then
      self.icon:SetTexture(icon)
      if texCoord == true then texCoord = { 0.08, 0.92, 0.08, 0.92 } end
      if type(texCoord) == "table" then
        Call(self.icon, "SetTexCoord", texCoord[1], texCoord[2], texCoord[3], texCoord[4])
      else
        Call(self.icon, "SetTexCoord", 0, 1, 0, 1)
      end
    end
    self.icon:Show()
  end
  Changed(self)
  return self
end

function RowMethods:SetMain(main)
  main = main and true or false
  if self._main == main then return self end
  self._main = main
  local t = main and "GameFontHighlight" or "GameFontHighlightSmall"
  if _G[t] then
    Call(self.text, "SetFontObject", _G[t])
    Call(self.value, "SetFontObject", _G[t])
  end
  Changed(self)
  return self
end

function RowMethods:SetActive(active)
  active = active and true or false
  if self._active == active then return self end
  self._active = active
  if active then self.activeBg:Show(); self.activeBar:Show() else self.activeBg:Hide(); self.activeBar:Hide() end
  return self
end

RowUpdateMouse = function(row)
  local interactive = row._onClick ~= nil or row._tooltip ~= nil
  row:EnableMouse(interactive)
  if not interactive then row.hover:Hide() end
end

-- Effective tooltip anchor: row, then panel option, then "auto".
local function RowAnchor(row)
  if row._ttAnchor then return row._ttAnchor end
  local p = row._panel
  local a = p and (p._tooltipAnchor or (p._opts and p._opts.tooltipAnchor))
  return a or "auto"
end

RowTooltip = function(row)
  if not row._tooltip then return end
  local ok, title, lines, hint = Try("row.tooltip", row._tooltip, row)
  if ok and title then Style.Tooltip(row, title, lines, hint, RowAnchor(row)) end
end

function RowMethods:SetOnClick(fn)
  self._onClick = type(fn) == "function" and fn or nil
  RowUpdateMouse(self)
  return self
end

-- fn(row) returns title, lines, hint (rendered with Style.Tooltip) or
-- shows its own tooltip and returns nothing.
function RowMethods:SetTooltip(fn)
  self._tooltip = type(fn) == "function" and fn or nil
  RowUpdateMouse(self)
  return self
end

-- "auto" (default), "ANCHOR_RIGHT", "ANCHOR_LEFT", ... ; nil = panel default.
function RowMethods:SetTooltipAnchor(anchor)
  self._ttAnchor = anchor
  return self
end

-- Maximum width of the right value: fraction of the inner width (0 < v <= 1)
-- or pixels (> 1). fixed = true reserves exactly that width. nil: half (v1).
function RowMethods:SetValueWidth(v, fixed)
  v = tonumber(v)
  if v and (v ~= v or v <= 0) then v = nil end
  fixed = (v and fixed) and true or false
  if v == self._valueMax and fixed == (self._valueFixed or false) then return self end
  self._valueMax, self._valueFixed = v, fixed
  Changed(self)
  return self
end

function RowMethods:SetIndent(px)
  px = tonumber(px) or 0
  if px == (self._indent or 0) then return self end
  self._indent = px
  Changed(self)
  return self
end

function RowMethods:SetGapBefore(px)
  px = tonumber(px)
  if px == self._gapBefore then return self end
  self._gapBefore = px
  Changed(self)
  return self
end

function RowMethods:Release() Release(self) end

local function RowReset(row)
  row.text:SetText("")
  row.value:SetText("")
  local c = COLORS.textPrimary
  row.text:SetTextColor(c[1], c[2], c[3], 1)
  row.value:SetTextColor(c[1], c[2], c[3], 1)
  row._textColor, row._valueColor = nil, "textPrimary"
  row._iconSet = false; row.icon:Hide()
  row._iconKey, row._iconAtlas, row._iconTC = nil, nil, nil
  row._indent, row._gapBefore = 0, nil
  row._kv, row._keep, row._ttAnchor = nil, nil, nil
  row._valueMax, row._valueFixed = nil, nil
  row:SetMain(false)
  row:SetActive(false)
  local wasInteractive = row._onClick ~= nil or row._tooltip ~= nil
  row._onClick, row._tooltip = nil, nil
  if row.bar then row.bar._inUse = false; row.bar:Hide() end
  -- Row still under the mouse (reused after ClearRows): keep hover and mouse
  -- until the rebuilt content is laid out, then ResolveHover decides.
  local okM, over = Call(row, "IsMouseOver")
  if wasInteractive and okM and over and row.hover:IsShown() then
    row._hoverPending = true
    if row._panel then row._panel._hoverPending = true end
  else
    row._hoverPending = nil
    RowUpdateMouse(row)
    row.hover:Hide()
  end
end

function Style.Row(panel)
  if not panel or not panel._isStylePanel then return nil end
  local row = Acquire(panel, "row")
  if row then
    RowReset(row)
    Style.RequestRelayout(panel)
    return row
  end
  row = CreateFrame("Button", nil, panel._body)
  row._isStyleRow = true
  Track(panel, row, "row")
  row._layout = RowLayout
  row.hover = Flat(row, "BACKGROUND", "rowHover", nil, 1)
  row.hover:SetAllPoints(row)
  row.hover:Hide()
  row.activeBg = Flat(row, "BACKGROUND", "rowActive", nil, 2)
  row.activeBg:SetAllPoints(row)
  row.activeBg:Hide()
  row.activeBar = Flat(row, "ARTWORK", "accent", 1)
  row.activeBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  row.activeBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.activeBar:SetWidth(S.activeBar)
  row.activeBar:Hide()
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(S.icon, S.icon)
  row.icon:Hide()
  row.text = NewFont(row, "GameFontHighlightSmall", "textPrimary")
  row.value = NewFont(row, "GameFontHighlightSmall", "textPrimary")
  row.value:SetJustifyH("RIGHT")
  for k, fn in pairs(RowMethods) do row[k] = fn end
  Call(row, "RegisterForClicks", "LeftButtonUp", "RightButtonUp")
  row:SetScript("OnEnter", function(self)
    if not (self._onClick or self._tooltip) then return end
    self.hover:Show()
    RowTooltip(self)
  end)
  row:SetScript("OnLeave", function(self)
    self._hoverPending = nil
    self.hover:Hide()
    Style.HideTooltip(self)
  end)
  row:SetScript("OnClick", function(self, button)
    if self._onClick then Try("row.onClick", self._onClick, self, button) end
  end)
  RowReset(row)
  Style.RequestRelayout(panel)
  return row
end

-- Key/value line: label left (secondary), value right (primary).
-- First argument may be a row or a panel (a new row is created).
function Style.KeyValue(row, label, value, valueColor)
  if row and row._isStylePanel then row = Style.Row(row) end
  if not row or not row._isStyleRow then return nil end
  row._kv = true
  row:SetText(label, "textSecondary")
  row:SetValue(value, valueColor or "textPrimary")
  return row
end

---------------------------------------------------------------------------
-- Header (section heading)
---------------------------------------------------------------------------
function Style.Header(panel, text)
  if not panel or not panel._isStylePanel then return nil end
  local hdr = Acquire(panel, "header")
  if not hdr then
    hdr = CreateFrame("Frame", nil, panel._body)
    Track(panel, hdr, "header")
    hdr._inset = true
    hdr._layout = HeaderLayout
    hdr.text = NewFont(hdr, "GameFontNormalSmall", "textSecondary")
    function hdr:SetText(t)
      t = t ~= nil and tostring(t) or ""
      if (self.text:GetText() or "") ~= t then self.text:SetText(t); Changed(self) end
      return self
    end
    function hdr:SetGapBefore(px)
      px = tonumber(px)
      if px ~= self._gapBefore then self._gapBefore = px; Changed(self) end
      return self
    end
    function hdr:Release() Release(self) end
  end
  hdr._gapBefore, hdr._keep = nil, nil
  local c = COLORS.textSecondary
  hdr.text:SetTextColor(c[1], c[2], c[3], 1)
  hdr:SetText(text)
  Style.RequestRelayout(panel)
  return hdr
end

---------------------------------------------------------------------------
-- Bar
---------------------------------------------------------------------------
local BarMethods = {}

-- Segment values 0..1. Stacked: each segment starts where the previous ended
-- (EP, then quest EP, then rested EP); the total is clamped to 1.
function BarMethods:SetValues(values)
  values = type(values) == "table" and values or {}
  local changed = false
  for i, seg in ipairs(self._segs) do
    local v = values[i]
    if v == nil and seg.key then v = values[seg.key] end
    v = Clamp(v, 0, 1)
    if self._values[i] ~= v then self._values[i] = v; changed = true end
  end
  if changed then self:Refresh() end
  return self
end

function BarMethods:SetValue(v, index)
  index = index or 1
  if not self._segs[index] then return self end
  v = Clamp(v, 0, 1)
  if self._values[index] == v then return self end
  self._values[index] = v
  self:Refresh()
  return self
end

function BarMethods:SetSegmentColor(index, color, alpha)
  local seg = self._segs[index]
  if seg then Tint(seg.tex, color, alpha) end
  return self
end

function BarMethods:Refresh()
  if self._host == "row" or self._host == "panel" then
    if self._panel then
      -- Width known: values never change the height, redraw in place.
      local w = tonumber(self:GetWidth()) or 0
      if w > 0 and BarUpdate(self, w) then return end
      self._panel._retries = 0
      Style.RequestRelayout(self._panel)
    end
    return
  end
  BarBorder(self, Pixel(self))
  self._px = Pixel(self)
  if not BarUpdate(self, self:GetWidth() or 0) and (self._retries or 0) < MAX_RETRIES then
    self._retries = (self._retries or 0) + 1
    After0(function() self:Refresh() end)
  else
    self._retries = 0
  end
end

function BarMethods:Configure(opts)
  opts = opts or {}
  self._height = max(2, tonumber(opts.height) or S.bar)
  self._stacked = opts.stacked ~= false
  local segs = opts.segments
  if type(segs) ~= "table" or #segs == 0 then segs = { { key = "value", color = "accent" } } end
  self._count = #segs
  for i, def in ipairs(segs) do
    local seg = self._segs[i]
    if not seg then
      seg = { tex = Flat(self, "ARTWORK", "accent", 1, i) }
      self._segs[i] = seg
    end
    seg.key = def.key
    Tint(seg.tex, def.color or "accent", def.alpha or 1)
    self._values[i] = Clamp(def.value, 0, 1)
  end
  for i = #segs + 1, #self._segs do self._segs[i].tex:Hide(); self._values[i] = 0 end
  if self._host ~= "row" and self._host ~= "panel" then self:SetHeight(self._height) end
  return self
end

function BarMethods:GetSegment(i)
  local seg = self._segs[i]
  if seg then return seg.start or 0, seg.len or 0, seg.tex end
end

function BarMethods:Release()
  if self._host == "row" then
    self._inUse = false; self:Hide()
    if self._panel then Style.RequestRelayout(self._panel) end
  elseif self._host == "panel" then
    Release(self)
  else
    self:Hide()
  end
end

local function NewBar(host)
  local bar = CreateFrame("Frame", nil, host)
  bar._isStyleBar = true
  bar._segs, bar._values = {}, {}
  bar.bg = Flat(bar, "BACKGROUND", "barBackground")
  bar.bg:SetAllPoints(bar)
  bar._border = {}
  for i = 1, 4 do bar._border[i] = Flat(bar, "BORDER", "barBorder") end
  for k, fn in pairs(BarMethods) do bar[k] = fn end
  return bar
end

-- parent: a Style panel (stacked as its own line), a Style row (drawn under
-- the row text) or any own frame (free bar, e.g. an XP strip; caller sizes it).
function Style.Bar(parent, opts)
  if not parent then return nil end
  local bar
  if parent._isStylePanel then
    bar = Acquire(parent, "bar")
    if not bar then
      bar = NewBar(parent._body)
      Track(parent, bar, "bar")
      bar._inset = true
      bar._layout = BarItemLayout
    end
    bar._host = "panel"
    bar._gapBefore = opts and opts.gapBefore
  elseif parent._isStyleRow then
    bar = parent.bar
    if not bar then
      bar = NewBar(parent)
      parent.bar = bar
    end
    bar._host, bar._panel, bar._inUse = "row", parent._panel, true
  else
    bar = NewBar(parent)
    bar._host = "free"
    bar:SetScript("OnSizeChanged", function(self) self:Refresh() end)
  end
  if bar._host == "panel" then bar._keep = nil end
  bar:Configure(opts)
  bar:Show()
  bar:Refresh()
  if bar._panel then
    bar._panel._retries = 0
    Style.RequestRelayout(bar._panel)
  end
  return bar
end

---------------------------------------------------------------------------
-- Content: free own frame of fixed height (ScrollFrame, EditBox, ...)
---------------------------------------------------------------------------
local ContentMethods = {}

function ContentMethods:SetContentHeight(h)
  h = max(1, tonumber(h) or 1)
  if h ~= self._height then self._height = h; Changed(self) end
  return self
end

function ContentMethods:SetGapBefore(px)
  px = tonumber(px)
  if px ~= self._gapBefore then self._gapBefore = px; Changed(self) end
  return self
end

-- true (default): 8 px padding left and right like headers and bars.
function ContentMethods:SetInset(inset)
  inset = inset ~= false
  if inset ~= self._inset then self._inset = inset; Changed(self) end
  return self
end

function ContentMethods:GetFrame() return self.frame end
function ContentMethods:Release() Release(self) end

-- frame: an own frame of the addon. It is reparented to a kit holder in the
-- panel body and fills it (SetAllPoints); the holder is stacked like a row.
-- opts: inset (default true), gapBefore.
function Style.Content(panel, frame, height, opts)
  if not panel or not panel._isStylePanel or type(frame) ~= "table" then return nil end
  local holder
  for _, item in ipairs(panel._items) do
    if item._kind == "content" and item.frame == frame then holder = item; break end
  end
  if holder and holder._inUse then
    if height ~= nil then holder:SetContentHeight(height) end
    return holder
  end
  if holder then
    holder._inUse = true
    panel._order[#panel._order + 1] = holder
    EnterItem(panel, holder)
  else
    holder = CreateFrame("Frame", nil, panel._body)
    holder.frame = frame
    Track(panel, holder, "content")
    holder._layout = ContentLayout
    for k, fn in pairs(ContentMethods) do holder[k] = fn end
  end
  holder._inset = not (type(opts) == "table" and opts.inset == false)
  holder._gapBefore = type(opts) == "table" and tonumber(opts.gapBefore) or nil
  holder._keep = nil
  holder._height = max(1, tonumber(height) or tonumber(holder._height) or 1)
  if not Call(frame, "GetParent") or frame:GetParent() ~= holder then Call(frame, "SetParent", holder) end
  Call(frame, "ClearAllPoints")
  Call(frame, "SetAllPoints", holder)
  Call(frame, "Show")
  panel._retries = 0
  Style.RequestRelayout(panel)
  return holder
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local PanelMethods = {}

local function Get(p, key)
  local fn = p._opts.get
  if type(fn) ~= "function" then return nil end
  local ok, v = Try("panel.get", fn, key)
  if ok then return v end
end

local function Put(p, key, value)
  local fn = p._opts.set
  if type(fn) == "function" then Try("panel.set", fn, key, value) end
end

local function ApplyPosition(p)
  local pos = Get(p, "pos")
  p:ClearAllPoints()
  if type(pos) == "table" and type(pos[1]) == "string" then
    if pcall(p.SetPoint, p, pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0) then return end
    p:ClearAllPoints()
  end
  local d = p._opts.defaultPoint or { "CENTER", "CENTER", 0, 0 }
  p:SetPoint(d[1], UIParent, d[2] or d[1], d[3] or 0, d[4] or 0)
end

local function SavePosition(p)
  local ok, point, _, relPoint, x, y = Call(p, "GetPoint", 1)
  if not ok or not point then return end
  x, y = floor((tonumber(x) or 0) + 0.5), floor((tonumber(y) or 0) + 0.5)
  Call(p, "SetUserPlaced", false)
  Put(p, "pos", { point, relPoint or point, x, y })
end

function PanelMethods:SetTitle(text)
  self._title:SetText(text ~= nil and tostring(text) or "")
  return self
end

function PanelMethods:SetLocked(locked, silent)
  self._locked = locked and true or false
  if not silent then Put(self, "locked", self._locked) end
  return self
end
function PanelMethods:IsLocked() return self._locked end

function PanelMethods:SetPanelScale(scale, silent)
  scale = Clamp(scale or 1, Style.SCALE_MIN, Style.SCALE_MAX)
  self._scale = scale
  self:SetScale(scale)
  if not silent then Put(self, "scale", scale) end
  self._retries = 0
  Style.RequestRelayout(self)
  return self
end

function PanelMethods:SetBackgroundAlpha(alpha, silent)
  alpha = Clamp(alpha == nil and Style.DEFAULT_ALPHA or alpha, 0, 1)
  self._bgAlpha = alpha
  local bg, hd = COLORS.background, COLORS.header
  local borderA = COLORS.border[4] * min(1, alpha / Style.DEFAULT_ALPHA)
  if self._backdrop then
    Call(self, "SetBackdropColor", bg[1], bg[2], bg[3], alpha)
    Call(self, "SetBackdropBorderColor", 1, 1, 1, borderA)
  else
    Tint(self._bg, "background", alpha)
    for _, t in ipairs(self._border) do Tint(t, "border", borderA) end
  end
  Tint(self._headerBg, "header", alpha)
  Tint(self._divider, "divider", COLORS.divider[4] * min(1, alpha / Style.DEFAULT_ALPHA))
  if not silent then Put(self, "alpha", alpha) end
  return self
end

function PanelMethods:SetPanelWidth(width)
  self._width = max(S.minWidth, floor(tonumber(width) or S.minWidth))
  self._retries = 0
  Style.Relayout(self)
  return self
end

function PanelMethods:SetCollapsed(collapsed, silent)
  self._collapsed = collapsed and true or false
  if self._collapseButton then self._collapseButton:SetKind(self._collapsed and "expand" or "collapse") end
  if not silent then Put(self, "collapsed", self._collapsed) end
  Style.Relayout(self)
  return self
end
function PanelMethods:IsCollapsed() return self._collapsed end

function PanelMethods:ResetPosition()
  Put(self, "pos", nil)
  ApplyPosition(self)
  return self
end

-- Re-read everything from the get callback (after option changes or reset).
function PanelMethods:ApplySettings()
  ApplyPosition(self)
  self:SetLocked(Get(self, "locked"), true)
  self:SetPanelScale(Get(self, "scale") or 1, true)
  self:SetBackgroundAlpha(Get(self, "alpha"), true)
  self._combatFade = Get(self, "combatFade") and true or false
  self:SetCollapsed(Get(self, "collapsed"), true)
  ApplyCombatAlpha(self)
  return self
end

function PanelMethods:FadeIn()
  if not self:IsShown() then
    self:SetAlpha(0)
    self:Show()
  end
  FadeTo(self, TargetAlpha(self))
  return self
end

function PanelMethods:FadeOut()
  if not self:IsShown() then return self end
  FadeTo(self, 0, function(f)
    f:Hide()
    f:SetAlpha(TargetAlpha(f))
  end, true)
  return self
end

function PanelMethods:SetShownFaded(shown)
  if shown then self:FadeIn() else self:FadeOut() end
  return self
end

-- Hide all rows, headers and bars and keep them for reuse; then build the
-- content again in order with Style.Row/Header/Bar.
-- Items not reused are hidden by the next relayout (same frame as the
-- rebuild), so a row under the mouse keeps hover and tooltip.
function PanelMethods:ClearRows()
  for _, item in ipairs(self._items) do
    item._inUse = false
    item._collapseHidden = nil
  end
  self._order = {}
  self._retries = 0
  Style.RequestRelayout(self)
  return self
end

-- Header button by key: "close", "collapse", the key of an opts.buttons
-- entry, or its position (1 = rightmost).
function PanelMethods:GetButton(key)
  if key == nil then return nil end
  if key == "close" then return self._closeButton end
  if key == "collapse" then return self._collapseButton end
  if type(key) == "number" then return self._buttons and self._buttons[key] end
  return self["_button_" .. tostring(key)]
end

-- Number of leading entries that stay visible while collapsed (0 = none).
function PanelMethods:SetCollapseKeep(n)
  n = max(0, floor(tonumber(n) or 0))
  if n == (self._collapseKeep or 0) then return self end
  self._collapseKeep = n
  if self._collapsed then Style.Relayout(self) end
  return self
end

-- Default tooltip anchor of the rows ("auto", "ANCHOR_RIGHT", ...).
function PanelMethods:SetTooltipAnchor(anchor)
  self._tooltipAnchor = anchor
  return self
end

function PanelMethods:Relayout() return Style.Relayout(self) end

-- opts: title, width, get(key), set(key, value), close (bool), collapse (bool),
-- onClose(panel), onCollapse(panel, collapsed), buttons ({ kind, onClick, tooltip, hint }),
-- defaultPoint ({ point, relPoint, x, y }), strata.
-- v2: collapseKeep (n), tooltipAnchor ("auto" default for rows); closeTooltip,
-- collapseTooltip and buttons[].tooltip may be { title, lines, hint }.
-- Keys used with get/set: "pos", "locked", "scale", "alpha", "collapsed", "combatFade", "shown".
function Style.Panel(name, parent, opts)
  opts = opts or {}
  local template = BackdropTemplateMixin and "BackdropTemplate" or nil
  local p = CreateFrame("Frame", name, parent or UIParent, template)
  p._isStylePanel = true
  p._opts = opts
  p._items, p._order = {}, {}
  p._collapseKeep = max(0, floor(tonumber(opts.collapseKeep) or 0))
  p._width = max(S.minWidth, floor(tonumber(opts.width) or S.minWidth))
  p:SetWidth(p._width)
  p:SetHeight(S.header + 2 * S.padY)
  Call(p, "SetFrameStrata", opts.strata or "MEDIUM")
  p:SetMovable(true)
  p:EnableMouse(false)
  Call(p, "SetClampedToScreen", true)
  Call(p, "SetDontSavePosition", true)

  -- Background and 1 px border
  if template and type(p.SetBackdrop) == "function" then
    p._backdrop = pcall(p.SetBackdrop, p, { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  end
  if not p._backdrop then
    p._bg = Flat(p, "BACKGROUND", "background", Style.DEFAULT_ALPHA)
    p._bg:SetAllPoints(p)
    p._border = {}
    for i = 1, 4 do p._border[i] = Flat(p, "BORDER", "border") end
  end

  -- Header: only place that drags
  local header = CreateFrame("Frame", nil, p)
  p._header, p.header = header, header
  header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
  header:SetHeight(S.header)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  p._headerBg = Flat(header, "BACKGROUND", "header", Style.DEFAULT_ALPHA, 1)
  p._headerBg:SetAllPoints(header)
  p._divider = Flat(header, "BORDER", "divider")
  p._divider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  p._divider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

  header:SetScript("OnDragStart", function()
    if p._locked then return end
    p._moving = pcall(p.StartMoving, p)
  end)
  header:SetScript("OnDragStop", function()
    if not p._moving then return end
    p._moving = false
    Call(p, "StopMovingOrSizing")
    SavePosition(p)
  end)
  p:SetScript("OnHide", function(self)
    if self._moving then
      self._moving = false
      Call(self, "StopMovingOrSizing")
      SavePosition(self)
    end
  end)
  p:SetScript("OnShow", function(self)
    self._retries = 0
    Style.RequestRelayout(self)
  end)

  -- Header buttons, right to left
  local anchor, buttons = nil, {}
  local function AddButton(kind, onClick, tooltip, hint)
    local b = Style.IconButton(header, kind)
    if anchor then
      b:SetPoint("RIGHT", anchor, "LEFT", -S.buttonGap, 0)
    else
      b:SetPoint("RIGHT", header, "RIGHT", -S.buttonRight, 0)
    end
    anchor = b
    if onClick then b:SetOnClick(onClick) end
    if type(tooltip) == "table" then
      b:SetTooltip(tooltip)
    elseif tooltip then
      b:SetTooltip(tooltip, nil, hint)
    end
    if opts.tooltipAnchor then b:SetTooltipAnchor(opts.tooltipAnchor) end
    buttons[#buttons + 1] = b
    return b
  end
  if opts.close then
    p._closeButton = AddButton("close", function()
      if type(opts.onClose) == "function" then
        Try("panel.onClose", opts.onClose, p)
      else
        Put(p, "shown", false)
        p:FadeOut()
      end
    end, opts.closeTooltip)
  end
  if opts.collapse then
    p._collapseButton = AddButton("collapse", function()
      p:SetCollapsed(not p._collapsed)
      if type(opts.onCollapse) == "function" then Try("panel.onCollapse", opts.onCollapse, p, p._collapsed) end
    end, opts.collapseTooltip)
  end
  for _, def in ipairs(type(opts.buttons) == "table" and opts.buttons or {}) do
    local b = AddButton(def.kind or def[1], def.onClick, def.tooltip, def.hint)
    if def.key then p["_button_" .. def.key] = b end
  end
  p._buttons = buttons

  local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  if not title:GetFontObject() and GameFontNormal then Call(title, "SetFontObject", GameFontNormal) end
  local tc = COLORS.textPrimary
  title:SetTextColor(tc[1], tc[2], tc[3], 1)
  title:SetJustifyH("LEFT")
  Call(title, "SetWordWrap", false)
  title:SetPoint("LEFT", header, "LEFT", S.titleX, 0)
  if anchor then
    title:SetPoint("RIGHT", anchor, "LEFT", -S.buttonGap, 0)
  else
    title:SetPoint("RIGHT", header, "RIGHT", -S.titleX, 0)
  end
  p._title = title

  local body = CreateFrame("Frame", nil, p)
  p._body, p.body = body, body
  body:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -S.header)
  body:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -S.header)
  body:SetHeight(1)
  body:EnableMouse(false)

  p._applyPixel = function(px)
    if p._backdrop then
      if p._lastEdge ~= px then
        p._lastEdge = px
        pcall(p.SetBackdrop, p, { bgFile = WHITE, edgeFile = WHITE, edgeSize = px })
        p:SetBackgroundAlpha(p._bgAlpha, true)
      end
    else
      local b = p._border
      for i = 1, 4 do b[i]:ClearAllPoints() end
      b[1]:SetPoint("TOPLEFT", p, "TOPLEFT"); b[1]:SetPoint("TOPRIGHT", p, "TOPRIGHT"); b[1]:SetHeight(px)
      b[2]:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT"); b[2]:SetHeight(px)
      b[3]:SetPoint("TOPLEFT", p, "TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT"); b[3]:SetWidth(px)
      b[4]:SetPoint("TOPRIGHT", p, "TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT"); b[4]:SetWidth(px)
    end
    p._divider:SetHeight(px)
  end

  for k, fn in pairs(PanelMethods) do p[k] = fn end
  p:SetTitle(opts.title)
  p:Hide()
  p:ApplySettings()
  panels[#panels + 1] = p
  Style.RequestRelayout(p)
  return p
end

-- Combat dimming to 40 % (whole window), 0.15 s fade.
-- Any other own frame: dimmed to 40 % of its own alpha in combat, its own
-- alpha restored afterwards.
function Style.CombatFade(panel, enabled)
  if type(panel) ~= "table" then return end
  if panel._isStylePanel then
    panel._combatFade = enabled and true or false
    Put(panel, "combatFade", panel._combatFade)
    ApplyCombatAlpha(panel)
    return
  end
  if type(panel.SetAlpha) ~= "function" or type(panel.GetAlpha) ~= "function" then return end
  local st = fadeFrames[panel]
  if enabled then
    if not st then st = {}; fadeFrames[panel] = st end
    st.enabled = true
  elseif st then
    st.enabled = false
  else
    return
  end
  ApplyFrameCombat(panel)
end

function Style.InCombat() return inCombat end

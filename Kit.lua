local _, ns = ...
local Style = ns.Style

---------------------------------------------------------------------------
-- (1.5.0) The family look of Guildon (Guildon/Theme.lua, Kit.lua; Daniel 26.10.2026: "das dunklere UI ... es ist wichtig,
-- dass alles die gleiche Style hat", 28.10.: "die Knöpfe sind ... nicht ganz so sichtbar, wie sie sein sollten beim
-- Auswählen"). Loaded right after Style.lua: the book colours are made darker in place (Style.lua stays the StyleKit),
-- Style.PAL holds the button colours, ns.UI the shared painters. Every button has three looks:
-- normal (a visible line round a dark fill), hot (gold line, lighter fill), chosen (blue fill, blue line, bright text).
---------------------------------------------------------------------------
local B = Style.BOOK
local function Hex(c)
  c.hex = string.format("ff%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
  return c
end
local function Dark(key, r, g, b)
  local c = B[key]
  c[1], c[2], c[3] = r, g, b
  Hex(c)
end
-- the same values as Guildon/Theme.lua
Dark("background", 0.062, 0.078, 0.092)
Dark("backgroundLow", 0.045, 0.056, 0.082)
Dark("header", 0.048, 0.074, 0.128)
Dark("card", 0.115, 0.132, 0.172)
Dark("cardLow", 0.082, 0.094, 0.125)
Dark("textHint", 0.60, 0.62, 0.68)

local G, GL = B.gold, B.goldLight
Style.PAL = {
  blue    = { 0.25, 0.66, 0.96 },
  edge    = { G[1], G[2], G[3], 0.38 },     -- line round buttons, chips, boxes
  edgeHot = { GL[1], GL[2], GL[3], 0.85 },  -- the same under the mouse
  well    = { 0.030, 0.040, 0.055, 0.62 },  -- dark inset: search field, lists
  btn     = { 0.118, 0.133, 0.172, 0.97 },  -- button fill
  btnHot  = { 0.180, 0.205, 0.265, 0.98 },
  off     = { 0.55, 0.56, 0.60 },           -- text of a tab that is not open (Daniel 28.10. in Golddon: "den Rest ausgrauen")
}
for _, c in pairs(Style.PAL) do Hex(c) end
local PAL = Style.PAL
-- the chosen row is blue everywhere
B.rowActive[1], B.rowActive[2], B.rowActive[3], B.rowActive[4] = PAL.blue[1], PAL.blue[2], PAL.blue[3], 0.34
Hex(B.rowActive)
-- a line under the mouse is a little clearer than the StyleKit's 5 %
local C = Style.COLORS
if C and C.rowHover then C.rowHover[4] = 0.09 end
B.rowHover[4] = 0.09

ns.UI = ns.UI or {}
local UI = ns.UI

function UI.Tint(tex, c, alpha)
  if not tex then return end
  local a = alpha or c[4] or 1
  if tex.SetColorTexture then tex:SetColorTexture(c[1], c[2], c[3], a)
  else tex:SetTexture("Interface\\Buttons\\WHITE8x8") tex:SetVertexColor(c[1], c[2], c[3], a) end
end
local Tint = UI.Tint

-- A line and a fill as textures of the frame itself, so its own texts stay above them.
function UI.Skin(f)
  f.edge = f:CreateTexture(nil, "BACKGROUND")
  f.edge:SetAllPoints(f)
  f.fill = f:CreateTexture(nil, "BORDER")
  f.fill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  f.fill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  return f
end

-- The look of a button from its state: f.look ("normal" or "active") and f.hot (mouse over).
-- Returns the text colour (a table) so the caller can paint its label. f._paint keeps what was painted (tests).
function UI.Paint(f)
  if f.hot and f.IsMouseOver and f:IsMouseOver() == false then f.hot = false end
  local active, hot = f.look == "active", f.hot
  local edge, edgeA, fill, fillA, text
  if active then
    edge, edgeA, fill, fillA, text = PAL.blue, hot and 1 or 0.9, PAL.blue, hot and 0.50 or 0.40, B.textPrimary
  else
    edge = hot and PAL.edgeHot or PAL.edge
    edgeA = edge[4]
    fill = hot and PAL.btnHot or PAL.btn
    fillA = fill[4]
    text = hot and GL or B.textSecondary
  end
  Tint(f.edge, edge, edgeA)
  Tint(f.fill, fill, fillA)
  f._paint = { edge = edge, fill = fill, fillA = fillA, text = text }
  return text
end

-- A Style.Row of a window becomes a button of the family: line, fill, gold under the mouse.
-- The row keeps its own mouse scripts (hover, tooltip); look "active" paints it blue.
function UI.ButtonRow(row, look)
  if not row or row.edge then return row end
  UI.Skin(row)
  row.look = look or "normal"
  UI.Paint(row)
  local enter, leave = row:GetScript("OnEnter"), row:GetScript("OnLeave")
  row:SetScript("OnEnter", function(self) self.hot = true UI.Paint(self) if enter then enter(self) end end)
  row:SetScript("OnLeave", function(self) self.hot = false UI.Paint(self) if leave then leave(self) end end)
  return row
end

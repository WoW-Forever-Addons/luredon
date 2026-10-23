local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Window with text to copy (Ctrl+A, Ctrl+C): catch export and /ld diag.
-- Built with the Style kit; the text field is an own frame stacked with
-- Style.Content (flat background and 1 px frame in the kit's bar colours).
---------------------------------------------------------------------------
local WIDTH, FIELD_H, FIELD_PAD = 460, 280, 4
local frame, field, edit, scroll
local state = {} -- window state for this session only (position, collapsed)

local function ScrollBy(delta)
  local range = scroll:GetVerticalScrollRange() or 0
  local pos = (scroll:GetVerticalScroll() or 0) - delta * 40
  scroll:SetVerticalScroll(math.max(0, math.min(range, pos)))
end

-- 1 px frame of the text field in physical pixels (sharp at any UI scale).
local function PixelEdges()
  local px = 1
  local ok, _, h = pcall(GetPhysicalScreenSize)
  local okS, scale = pcall(field.GetEffectiveScale, field)
  h, scale = ok and tonumber(h), okS and tonumber(scale)
  if h and h > 0 and scale and scale > 0 then px = 768 / h / scale end
  local e = field.edges
  e[1]:SetHeight(px); e[2]:SetHeight(px); e[3]:SetWidth(px); e[4]:SetWidth(px)
end

local function Close()
  if edit then edit:ClearFocus() end
  frame:FadeOut()
end

local function Create()
  local Style = ns.Style
  local S = Style.SPACING
  frame = Style.Panel("LuredonExportFrame", UIParent, {
    title = Style.Wordmark("Lure", "don"),
    width = WIDTH,
    close = true,
    strata = "DIALOG",
    get = function(key) return state[key] end,
    set = function(key, value) state[key] = value end,
    closeTooltip = { L["Close"], nil, L["Esc closes it too."] },
    onClose = Close,
  })
  ns.exportFrame = frame
  frame.hint = Style.Row(frame):SetText(L["Copy with Ctrl+A and Ctrl+C. Contains no character or realm names."], "textHint")
  -- Left clicks stay in the window, the right button reaches the world (camera turning).
  -- A double right-click on it still never casts (Cast.lua checks the pointer).
  ns.RightClickThrough(frame, { frame._header, frame.hint })

  -- Text field: flat background, 1 px frame (same look as a kit bar).
  field = CreateFrame("Frame", nil, frame)
  local function Flat(layer, key)
    local t = field:CreateTexture(nil, layer)
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    local c = Style.COLORS[key]
    t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    return t
  end
  Flat("BACKGROUND", "barBackground"):SetAllPoints(field)
  local edges = {}
  for i = 1, 4 do edges[i] = Flat("BORDER", "barBorder") end
  edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT")
  edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
  edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT")
  edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT")
  field.edges = edges
  PixelEdges()
  frame.field = Style.Content(frame, field, FIELD_H)

  scroll = CreateFrame("ScrollFrame", "LuredonExportScroll", field)
  scroll:SetPoint("TOPLEFT", field, "TOPLEFT", FIELD_PAD, -FIELD_PAD)
  scroll:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", -FIELD_PAD, FIELD_PAD)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)

  edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
  local c = Style.COLORS.textPrimary
  edit:SetTextColor(c[1], c[2], c[3], 1)
  edit:SetWidth(WIDTH - 2 * S.padX - 2 * FIELD_PAD)
  edit:SetScript("OnEscapePressed", Close)
  -- Read only: typing puts the text back.
  edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput then self:SetText(frame.text or "") self:HighlightText() end
  end)
  -- Keep the cursor visible when it moves with the keyboard.
  edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
    local top = scroll:GetVerticalScroll() or 0
    local height = scroll:GetHeight() or 0
    y = -(tonumber(y) or 0)
    h = tonumber(h) or 0
    if y < top then
      scroll:SetVerticalScroll(y)
    elseif height > 0 and y + h > top + height then
      scroll:SetVerticalScroll(y + h - height)
    end
  end)
  scroll:SetScrollChild(edit)
  frame.edit = edit
end

function ns.ShowText(title, text)
  if not frame then Create() end
  local Style = ns.Style
  frame:SetTitle(Style.Wordmark("Lure", "don") .. "  " .. Style.Colorize(title, "textSecondary"))
  frame.text = text
  edit:SetText(text)
  scroll:SetVerticalScroll(0)
  PixelEdges()
  frame:FadeIn()
  edit:SetFocus()
  edit:HighlightText()
end

function ns.ShowExport()
  ns.ShowText(L["Catch data export"], ns.ExportText())
end

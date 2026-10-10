local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (1.4.1) Bobber pointer. Daniel 09.10.: while the mouse is on the bobber, a
-- small red and white bobber with a golden rim sits at the pointer (Gemini
-- design "3 + 4"; Daniel 09.10.: without the two water rings).
--
-- The game sets its own pointer (the gear) over world objects; an addon
-- cannot replace it there (Daniel's test 09.10.: SetCursor only made the gear
-- flicker). So the bobber is our own frame next to the gear, on WorldFrame
-- like the catch ticker, so it stays when Luredon hides the interface.
-- "/ld cursortest" prints what the pointer sees.
--
-- The bite itself is invisible to addons (no event, only a sound). The colour
-- shows what Luredon does know:
--   normal   a faint silver blue glow
--   ending   amber: the last seconds before the line comes in by itself
--   caught   green: the loot window opened after the click
--   missed   red: the fish got away or nothing was on the hook
-- Changes fade in 0.15 s, nothing blinks. In combat the pointer hides.
-- The bobber is found by the world tooltip under the mouse while the line is
-- out (read only; no hook on Blizzard's tooltip).
-- (1.4.1 review) The update only runs with the option on and while the line is
-- out (plus the short result fade); the tooltip is read about 20 times a
-- second, the pointer follows the mouse every frame.
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Luredon\\Media\\"
local ICON = 40            -- pointer bobber, px (09.10.: bigger, right of the gear)
local ENDING = 5           -- seconds before the line comes in: amber
local RESULT_TIME = 1.2    -- green or red, then fade out
local FADE = 0.15
local READ_EVERY = 0.05    -- (1.4.1) tooltip read about 20 times a second

local COLORS = {
  normal = { 0.75, 0.85, 1.00 },
  ending = { 0.95, 0.75, 0.25 },
  caught = { 0.40, 0.80, 0.45 },
  missed = { 0.92, 0.35, 0.32 },
}

-- Words for the bobber in the client languages (the world tooltip's first line).
local BOBBER_WORDS = { "bobber", "schwimmer", "flotteur", "corcho", "boya", "boia", "flutuador", "поплав", "Поплав", "찌", "浮標" }

local frame, icon, glow
local lineOut, lineEndsAt = false, nil
local overSince, lastOver = nil, 0
local result, resultAt = nil, 0
local shown, alpha = false, 0
local color = { unpack(COLORS.normal) }
local testCursor = false
local testReported = false
local readWait, overCached = READ_EVERY, false

local function Now() return GetTime and GetTime() or 0 end

local function TooltipText()
  if not (GameTooltip and GameTooltip.IsShown) then return nil end
  local ok, vis = pcall(GameTooltip.IsShown, GameTooltip)
  if not ok or not vis then return nil end
  -- (09.10.) only while the tooltip is fully there: it fades out after the mouse left the bobber,
  -- the game's gear is gone by then
  local okA, a = pcall(GameTooltip.GetAlpha, GameTooltip)
  if okA and type(a) == "number" and a < 0.95 then return nil end
  local line = _G and _G.GameTooltipTextLeft1
  if not (line and line.GetText) then return nil end
  local ok2, text = pcall(line.GetText, line)
  if not ok2 or not ns.Usable(text) or type(text) ~= "string" then return nil end
  return text
end

-- Is the mouse on the bobber? Only while the line is out and over the world.
local function OverBobber()
  if not lineOut then return false end
  if IsMouselooking and IsMouselooking() then return false end
  local text = TooltipText()
  if not text or text == "" then return false end
  local lower = text:lower()
  for _, w in ipairs(BOBBER_WORDS) do
    if lower:find(w, 1, true) then return true end
  end
  if ns.db and ns.db.bobberName and text == ns.db.bobberName then return true end
  return false
end

local function Build()
  if frame then return end
  -- (09.10.) on WorldFrame: with "Hide the interface while fishing" UIParent is hidden
  frame = CreateFrame("Frame", "LuredonBobberPointer", WorldFrame)
  frame:SetFrameStrata("TOOLTIP")
  frame:SetSize(1, 1)
  frame:EnableMouse(false)
  frame:Hide()
  glow = frame:CreateTexture(nil, "BORDER")
  glow:SetTexture(MEDIA .. "CursorBobberGlow")
  glow:SetBlendMode("ADD")
  glow:SetSize(ICON * 2, ICON * 2)
  icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(MEDIA .. "CursorBobber")
  icon:SetSize(ICON, ICON)
  -- (09.10.) right of the game's gear (the gear spans about 32 px right and down from the hotspot)
  icon:SetPoint("LEFT", frame, "CENTER", 34, -14)
  glow:SetPoint("CENTER", icon, "CENTER")
end

local function Follow()
  if not GetCursorPosition then return end
  local x, y = GetCursorPosition()
  -- WorldFrame is not scaled with the interface: our frame takes the UI scale (as HideUI.lua does)
  local ui = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  local world = WorldFrame.GetEffectiveScale and WorldFrame:GetEffectiveScale() or 1
  if world > 0 then frame:SetScale(ui / world) end
  local scale = frame:GetEffectiveScale()
  if not (x and y and scale and scale > 0) then return end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", WorldFrame, "BOTTOMLEFT", x / scale, y / scale)
end

local function Target()
  local now = Now()
  if result and now - resultAt < RESULT_TIME then return COLORS[result] end
  if lineEndsAt and lineEndsAt - now <= ENDING then return COLORS.ending end
  return COLORS.normal
end

local ticker -- the update frame (below)

local function HideAll()
  if ticker then ticker:Hide() end
  if frame then frame:Hide() end
  alpha, shown, overCached = 0, false, false
end

local function Step(elapsed)
  if not (ns.db and frame) then return end
  -- (1.4.1) switched off while ticking: stop right away
  if not ns.db.bobberCursor then HideAll() return end
  local now = Now()
  elapsed = tonumber(elapsed) or 0
  readWait = readWait + elapsed
  if readWait >= READ_EVERY then
    readWait = 0
    overCached = not InCombatLockdown() and OverBobber() or false
  end
  local over = overCached
  if over then lastOver = now; overSince = overSince or now else overSince = nil end
  -- after the click the line is in: the result stays at the last spot for a moment
  local want = over or (result and now - resultAt < RESULT_TIME and now - lastOver < RESULT_TIME + 0.5)
  alpha = want and math.min(1, alpha + elapsed / FADE) or math.max(0, alpha - elapsed / FADE)
  if alpha <= 0 then
    frame:Hide()
    shown = false
    return
  end
  if over then Follow() end
  local t = Target()
  local k = math.min(1, elapsed / FADE)
  for i = 1, 3 do color[i] = color[i] + (t[i] - color[i]) * k end
  frame:SetAlpha(alpha)
  icon:SetAlpha(1)
  glow:SetVertexColor(color[1], color[2], color[3])
  glow:SetAlpha(t == COLORS.normal and 0.25 or 0.75)
  if not shown then frame:Show() shown = true end
  if testCursor and over and not testReported then
    testReported = true
    ns.Print(("Cursor test: on the bobber (tooltip %q), pointer shown %s, at %s."):format(tostring(TooltipText()),
      frame:IsShown() and "yes" or "no", ("%.0f, %.0f"):format(frame:GetCenter() or 0, select(2, frame:GetCenter()) or 0)))
  end
end

ticker = CreateFrame("Frame")
ticker:Hide()
ticker:SetScript("OnUpdate", function(_, elapsed) ns.Call("bobber pointer", Step, elapsed) end)
function ns.BobberPointerTick(elapsed) ns.Call("bobber pointer", Step, elapsed) end -- (tests)

local function Wake()
  -- (1.4.1) nothing ticks with the option off
  if not (ns.db and ns.db.bobberCursor) then return end
  Build()
  if lineOut or (result and Now() - resultAt < RESULT_TIME) or alpha > 0 then
    if not ticker:IsShown() then readWait = READ_EVERY end -- the first frame reads the tooltip
    ticker:Show()
  end
end

-- Still channeling Fishing (a recast whose start came before the old stop): the line stays out.
local function ChannelingFishing()
  if not UnitChannelInfo then return false end
  local ok, _, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
  return ok and ns.IsFishingSpell(spellID) or false
end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if not ns.IsFishingSpell(spellID) then return end
  lineOut, result = true, nil
  local ok, _, _, _, _, endMS = pcall(UnitChannelInfo, "player")
  lineEndsAt = ok and ns.Usable(endMS) and type(endMS) == "number" and endMS / 1000 or nil
  Wake()
end)

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  -- (1.4.1) another channel ending leaves the pointer alone; an unreadable ID counts like the end
  -- of ours (as in Sound.lua and Panel.lua), unless Fishing is still channeling
  if ns.Usable(spellID) and not ns.IsFishingSpell(spellID) then return end
  if ChannelingFishing() then return end
  lineOut, lineEndsAt = false, nil
  -- keep ticking for the result and the fade
  C_Timer.After(RESULT_TIME + 1, ns.Safe("bobber pointer stop", function()
    if not lineOut then HideAll() end
  end))
end)

-- (1.4.1) a loading screen ends the line: nothing keeps ticking
local function WorldChanged()
  lineOut, lineEndsAt, result = false, nil, nil
  HideAll()
end
ns.On("PLAYER_LEAVING_WORLD", WorldChanged)
ns.On("PLAYER_ENTERING_WORLD", WorldChanged)

local function Result(kind)
  if Now() - lastOver > 2 then return end -- only when the pointer was on the bobber just now
  result, resultAt = kind, Now()
  Wake()
end

ns.On("LOOT_OPENED", function()
  if lineOut or Now() - lastOver < 2 then Result("caught") end
end)

ns.On("UI_ERROR_MESSAGE", function(_, _, message)
  if not ns.Usable(message) then return end
  if (ERR_FISH_ESCAPED and message == ERR_FISH_ESCAPED) or (ERR_FISH_NOT_HOOKED and message == ERR_FISH_NOT_HOOKED) then
    Result("missed")
  end
end)

ns.On("PLAYER_REGEN_DISABLED", function() if frame then frame:Hide() alpha, shown, overCached = 0, false, false end end)

-- /ld cursortest: one chat line when the mouse is on the bobber (what the pointer sees)
function ns.ToggleCursorTest()
  testCursor = not testCursor
  testReported = false
  ns.Print(testCursor and "Cursor test on: cast and move the mouse onto the bobber. /ld cursortest again switches it off."
    or "Cursor test off.")
  if testCursor and ns.db and not ns.db.bobberCursor then ns.Print("The bobber pointer is switched off in the options (Sound and hooking).") end
end

-- For the tests and /ld diag.
function ns.BobberPointerState()
  return { lineOut = lineOut, shown = shown, alpha = alpha, result = result, over = OverBobber(),
    ticking = ticker:IsShown() and true or false }
end

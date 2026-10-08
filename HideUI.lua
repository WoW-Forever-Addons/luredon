local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- (1.4) Daniel 08.10.: fish with the whole interface hidden, like Alt+Z.
--
-- Option hideUI (off by default; Luredon asks once, see Ask below): when the line
-- goes out, the game's interface is hidden with SetUIVisibility(false), the same
-- call the game's own "Toggle UI" key binding (Alt+Z) makes. Nothing of
-- Blizzard's is hooked or changed. It comes back with SetUIVisibility(true) as
-- soon as you move, a fight starts, you die, change the target, get a whisper,
-- the loot window opens while auto loot is off, the pole leaves the hand, or
-- on a loading screen / logout. Between casts it stays hidden (double
-- right-click casting works on the world, which stays visible).
--
-- While hidden, the catch ticker shows what you caught: up to three lines at
-- the top centre of the screen, "+1 Firefin Snapper (12)" in the item's quality
-- colour, each fading out after a few seconds. It is our own frame parented to
-- WorldFrame, the one part of the screen that stays when the interface is hidden.
---------------------------------------------------------------------------
local TICKER_LINES, TICKER_HOLD, TICKER_FADE = 3, 4, 1.2
local ASK_SCALE = 1.5 -- the question asked once: large enough to read at a glance

local hidden = false
local stats = { hides = 0, shows = 0, failed = 0, lines = 0, lastReason = "-" }
ns.hideUIStats = stats

local function Visibility(show)
  if type(SetUIVisibility) ~= "function" then return false end
  local ok = pcall(SetUIVisibility, show and true or false)
  if not ok then stats.failed = stats.failed + 1 end
  return ok
end

local ticker
local function TickerHide()
  if not ticker then return end
  for _, line in ipairs(ticker.lines) do line.until_ = 0 line:SetAlpha(0) line:Hide() end
  ticker.skill.until_ = 0
  ticker.skill:Hide()
  ticker.warn.until_ = 0
  ticker.warn:Hide()
  ticker:Hide()
end

-- Back to the normal interface (reason for /ld diag).
function ns.ShowInterface(reason)
  if not hidden then return end
  hidden = false
  stats.shows, stats.lastReason = stats.shows + 1, reason or "?"
  Visibility(true)
  TickerHide()
end

function ns.InterfaceHidden() return hidden end

local function CanHide()
  if not (ns.db and ns.db.hideUI) then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  return true
end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if hidden or not ns.IsFishingSpell(spellID) or not CanHide() then return end
  if Visibility(false) then
    hidden = true
    stats.hides = stats.hides + 1
  end
end)

for event, reason in pairs({
  PLAYER_STARTED_MOVING = "moving", PLAYER_REGEN_DISABLED = "combat", PLAYER_DEAD = "dead",
  PLAYER_TARGET_CHANGED = "target", CHAT_MSG_WHISPER = "whisper", CHAT_MSG_BN_WHISPER = "whisper",
  PLAYER_LEAVING_WORLD = "loading", PLAYER_LOGOUT = "logout", PLAYER_CONTROL_LOST = "control",
  PLAYER_MOUNT_DISPLAY_CHANGED = "mount",
}) do
  ns.On(event, function() ns.ShowInterface(reason) end)
end
ns.On("PLAYER_EQUIPMENT_CHANGED", function() if not ns.HasPole() then ns.ShowInterface("pole") end end)
-- auto loot off: the loot window needs the interface
ns.On("LOOT_OPENED", function(_, autoLoot)
  if hidden and not (autoLoot == true or autoLoot == 1) then ns.ShowInterface("loot window") end
end)
-- the option switched off while hidden
function ns.ApplyHideUI() if not (ns.db and ns.db.hideUI) then ns.ShowInterface("option off") end end

---------------------------------------------------------------------------
-- Catch ticker
---------------------------------------------------------------------------
local function CreateTicker()
  ticker = CreateFrame("Frame", "LuredonCatchTicker", WorldFrame)
  ticker:SetFrameStrata("HIGH")
  ticker:SetSize(520, TICKER_LINES * 26 + 70)
  ticker:SetPoint("TOP", WorldFrame, "TOP", 0, -90)
  ticker.lines = {}
  for i = 1, TICKER_LINES do
    local fs = ticker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    if not fs:GetFontObject() and GameFontNormalLarge then fs:SetFontObject(GameFontNormalLarge) end
    local font, size = fs:GetFont()
    if font then pcall(fs.SetFont, fs, font, (size or 16) + 2, "OUTLINE") end
    fs:SetPoint("TOP", ticker, "TOP", 0, -(i - 1) * 26)
    fs:SetJustifyH("CENTER")
    fs:Hide()
    ticker.lines[i] = fs
  end
  -- (Daniel 08.10.) a skill point: one line under the catches, in the skill-up blue
  local sk = ticker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if not sk:GetFontObject() and GameFontNormalLarge then sk:SetFontObject(GameFontNormalLarge) end
  local f2, s2 = sk:GetFont()
  if f2 then pcall(sk.SetFont, sk, f2, (s2 or 16) + 2, "OUTLINE") end
  sk:SetPoint("TOP", ticker, "TOP", 0, -TICKER_LINES * 26 - 6)
  sk:SetJustifyH("CENTER")
  sk:SetTextColor(0.40, 0.70, 1.00)
  sk:Hide()
  ticker.skill = sk
  -- (Daniel 08.10.) warnings (bags full, no lure): the game's red error line is hidden too
  local wn = ticker:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  if not wn:GetFontObject() and GameFontNormalLarge then wn:SetFontObject(GameFontNormalLarge) end
  local f3, s3 = wn:GetFont()
  if f3 then pcall(wn.SetFont, wn, f3, (s3 or 16) + 4, "OUTLINE") end
  wn:SetPoint("TOP", sk, "BOTTOM", 0, -8)
  wn:SetJustifyH("CENTER")
  wn:SetTextColor(1, 0.25, 0.2)
  wn:Hide()
  ticker.warn = wn
  ticker:SetScript("OnUpdate", function(self)
    local now, any = GetTime(), false
    local all = { self.skill, self.warn }
    for _, fs in ipairs(self.lines) do all[#all + 1] = fs end
    for _, fs in ipairs(all) do
      local left = (fs.until_ or 0) - now
      if left > 0 then
        any = true
        fs:SetAlpha(left < TICKER_FADE and left / TICKER_FADE or 1)
      elseif fs:IsShown() then
        fs:Hide()
      end
    end
    if not any then self:Hide() end
  end)
  ticker:Hide()
end

-- The interface scale: WorldFrame is not scaled with the UI, our lines are.
local function Scale()
  local ui = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  local world = WorldFrame.GetEffectiveScale and WorldFrame:GetEffectiveScale() or 1
  if ui and world and world > 0 then ticker:SetScale(ui / world) end
end

local function QualityColor(quality)
  local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c and c.hex then return c.hex end
  if c and c.r then return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255) end
  return "|cffffffff"
end

-- A catch while the interface is hidden: newest line on top.
function ns.TickerCatch(id, quantity, quality, total)
  if not hidden or not id then return end
  if not ticker then CreateTicker() end
  Scale()
  local name, _, q, _, _, _, _, _, _, icon = ns.GetItemInfo(id)
  if not (ns.Usable(name) and type(name) == "string") then name = "item " .. tostring(id) end
  quality = quality or (ns.Usable(q) and q) or 1
  local text = ("+%d %s%s|r"):format(quantity or 1, QualityColor(quality), name)
  if total and total > 0 then text = text .. ("  |cffc0c0c0(%d)|r"):format(total) end
  if ns.Usable(icon) and icon then text = ("|T%s:20:20:0:0|t "):format(tostring(icon)) .. text end
  for i = TICKER_LINES, 2, -1 do
    local a, b = ticker.lines[i], ticker.lines[i - 1]
    a:SetText(b:GetText() or "")
    a.until_ = b.until_
    if b:IsShown() then a:Show() a:SetAlpha(b:GetAlpha()) else a:Hide() end
  end
  local top = ticker.lines[1]
  top:SetText(text)
  top.until_ = GetTime() + TICKER_HOLD + TICKER_FADE
  top:SetAlpha(1)
  top:Show()
  ticker:Show()
  stats.lines = stats.lines + 1
end

-- A warning while the interface is hidden (ns.Warn sends it here): red, longer.
function ns.TickerWarn(msg)
  if not hidden or not msg then return end
  if not ticker then CreateTicker() end
  Scale()
  ticker.warn:SetText(msg)
  ticker.warn.until_ = GetTime() + TICKER_HOLD + 4 + TICKER_FADE
  ticker.warn:SetAlpha(1)
  ticker.warn:Show()
  ticker:Show()
  stats.warnings = (stats.warnings or 0) + 1
end

-- Bags full while the catch is looted: the game says so in its hidden error line.
ns.On("UI_ERROR_MESSAGE", function(_, _, message)
  if not hidden or not ns.Usable(message) then return end
  if (ERR_INV_FULL and message == ERR_INV_FULL) or (ERR_LOOT_INV_FULL and message == ERR_LOOT_INV_FULL) then
    ns.TickerWarn(L["Bags full: the catch stays behind!"])
  end
end)

-- A skill point while the interface is hidden: "Fishing skill 126 / 150 (+1)".
function ns.TickerSkill(rank, maxRank, gain)
  if not hidden or not rank then return end
  if not ticker then CreateTicker() end
  Scale()
  local text = (maxRank and maxRank > 0) and L["Fishing skill %d / %d"]:format(rank, maxRank) or L["Fishing skill %d"]:format(rank)
  text = text .. ("  (+%d)"):format(gain or 1)
  ticker.skill:SetText(text)
  ticker.skill.until_ = GetTime() + TICKER_HOLD + 2 + TICKER_FADE
  ticker.skill:SetAlpha(1)
  ticker.skill:Show()
  ticker:Show()
  stats.skillLines = (stats.skillLines or 0) + 1
end

---------------------------------------------------------------------------
-- (1.4) Asked once (Daniel): hide the interface while fishing, yes or no.
-- Comes the first time a pole is in the hand out of combat; the options can
-- change it any time.
---------------------------------------------------------------------------
local askPanel
local function Answer(yes)
  ns.db.hideUI = yes and true or false
  ns.db.askedHideUI = true
  if askPanel then askPanel:Hide() end
  ns.Print(yes and L["The interface hides while your line is out. Change it under /ld options."]
    or L["The interface stays while you fish. You can switch hiding on under /ld options."])
end
ns.AnswerHideUI = Answer -- (tests)

function ns.MaybeAskHideUI()
  if not ns.db or ns.db.askedHideUI or ns.db.hideUI then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  if not (Style and Style.Panel and Style.Row) then return false end
  if not askPanel then
    askPanel = Style.Panel("LuredonAskHideUI", UIParent, {
      title = Style.Wordmark and Style.Wordmark("Lure", "don") or "Luredon",
      width = 380, close = true, strata = "DIALOG",
      defaultPoint = { "CENTER", "CENTER", 0, 60 },
      get = function() return nil end, set = function() end,
      onClose = function() Answer(false) end,
    })
    for i, line in ipairs({ { L["Hide the interface while fishing?"], "textPrimary" },
        { L["Your catches show at the top of the screen."], "textSecondary" },
        { L["Moving or a fight brings it back."], "textSecondary" } }) do
      local r = Style.Row(askPanel)
      r:SetText(line[1], line[2])
      if i == 1 then r:SetGapBefore(0) end
    end
    local yes = Style.Row(askPanel)
    yes:SetText(L["Yes, hide it while fishing"], "accent")
    yes:SetOnClick(function() Answer(true) end)
    local no = Style.Row(askPanel)
    no:SetText(L["No, keep the interface"], "textSecondary")
    no:SetOnClick(function() Answer(false) end)
  end
  -- (Daniel 08.10.: "hardly readable") a question asked once may be large
  if askPanel.SetPanelScale then askPanel:SetPanelScale(ASK_SCALE, true) end
  askPanel:Show()
  if Style.Relayout then Style.Relayout(askPanel) end
  return true
end

ns.On("PLAYER_EQUIPMENT_CHANGED", function()
  if ns.HasPole() then ns.Call("ask hide ui", ns.MaybeAskHideUI) end
end)
ns.On("PLAYER_ENTERING_WORLD", function()
  if C_Timer and C_Timer.After then
    C_Timer.After(3, ns.Safe("ask hide ui", function() if ns.HasPole() then ns.MaybeAskHideUI() end end))
  end
end)

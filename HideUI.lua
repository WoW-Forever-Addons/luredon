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
local hiddenAt = 0 -- (1.4.1) when Luredon hid the interface (GetTime)
local stats = { hides = 0, shows = 0, failed = 0, lines = 0, lastReason = "-" }
ns.hideUIStats = stats

local function Visibility(show)
  if type(SetUIVisibility) ~= "function" then return false end
  local ok = pcall(SetUIVisibility, show and true or false)
  if not ok then stats.failed = stats.failed + 1 end
  return ok
end

-- (1.4.1, Daniel 09.10.) Is the game's interface shown right now? An unreadable answer counts as shown.
local function UIShown()
  if not (UIParent and UIParent.IsShown) then return true end
  local ok, v = pcall(UIParent.IsShown, UIParent)
  if not ok or v == nil or not ns.Usable(v) then return true end
  return v and true or false
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

local castbar -- (1.4.1) our own channel bar while the interface is hidden (below)
local CastStart
local watch   -- (1.4.1) small check while hidden: Alt+Z and typing (below)

local function OverlaysHide()
  TickerHide()
  if ns.ChatFeedHide then ns.ChatFeedHide() end
  if castbar then castbar:Hide() end
  if watch then watch:Hide() end
end

-- Back to the normal interface (reason for /ld diag).
function ns.ShowInterface(reason)
  if not hidden then return end
  hidden = false
  stats.shows, stats.lastReason = stats.shows + 1, reason or "?"
  Visibility(true)
  OverlaysHide()
end

-- (1.4.1, Daniel 09.10.) The player brought the interface back himself (Alt+Z): Luredon lets go
-- of it, hides its own lines and does not show the interface again on moving. A short grace time
-- after our own hide, in case the game reports the change a moment later.
local OWN_GRACE = 0.5
local function Sync()
  if hidden and GetTime() - hiddenAt > OWN_GRACE and UIShown() then
    hidden = false
    stats.released = (stats.released or 0) + 1
    stats.lastReason = "player"
    OverlaysHide()
  end
end

function ns.InterfaceHidden() Sync() return hidden end

local function CanHide()
  if not (ns.db and ns.db.hideUI) then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return false end
  return true
end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if not ns.IsFishingSpell(spellID) then return end
  Sync()
  if not hidden then
    if not CanHide() then return end
    -- (1.4.1) the player hid the interface himself (Alt+Z): it stays his, no overlays and no
    -- interface on moving
    if not UIShown() then stats.playerHidden = (stats.playerHidden or 0) + 1 return end
    if Visibility(false) then
      hidden = true
      hiddenAt = GetTime()
      stats.hides = stats.hides + 1
      if watch then watch:Show() end
    end
  end
  if hidden then CastStart() end
end)
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function() if castbar then castbar:Hide() end end)

for event, reason in pairs({
  PLAYER_STARTED_MOVING = "moving", PLAYER_REGEN_DISABLED = "combat", PLAYER_DEAD = "dead",
  PLAYER_TARGET_CHANGED = "target", CHAT_MSG_WHISPER = "whisper", CHAT_MSG_BN_WHISPER = "whisper",
  PLAYER_LEAVING_WORLD = "loading", PLAYER_LOGOUT = "logout", PLAYER_CONTROL_LOST = "control",
  PLAYER_MOUNT_DISPLAY_CHANGED = "mount",
  -- (1.4.1, Daniel 09.10.) invitations, requests and windows that need an answer: their dialogs
  -- belong to the hidden interface, so it comes back (events the client lacks are skipped by ns.On)
  PARTY_INVITE_REQUEST = "invite", GUILD_INVITE_REQUEST = "invite", DUEL_REQUESTED = "duel",
  CONFIRM_SUMMON = "summon", RESURRECT_REQUEST = "resurrect", READY_CHECK = "ready check",
  TRADE_SHOW = "trade", PETITION_SHOW = "petition", START_LOOT_ROLL = "loot roll",
  QUEST_ACCEPT_CONFIRM = "quest", QUEST_DETAIL = "quest", LFG_PROPOSAL_SHOW = "group finder",
  LFG_ROLE_CHECK_SHOW = "group finder", GOSSIP_SHOW = "window", MERCHANT_SHOW = "window",
  MAIL_SHOW = "window", BANKFRAME_OPENED = "window", CONFIRM_BINDER = "window",
}) do
  ns.On(event, function()
    -- (1.4.1) with the chat feed on, a whisper shows up there and the interface stays hidden
    if reason == "whisper" and ns.db and (ns.db.chatFeed or "private") ~= "off" then return end
    ns.ShowInterface(reason)
  end)
end
ns.On("PLAYER_EQUIPMENT_CHANGED", function() if not ns.HasPole() then ns.ShowInterface("pole") end end)

-- (1.4.1, Daniel 09.10.) Auto loot off: every catch opens the loot window, which brings the interface
-- back. Said once, while the interface is visible. Luredon never loots by itself.
local function AutoLootOff()
  if type(GetCVar) ~= "function" then return false end
  local ok, v = pcall(GetCVar, "autoLootDefault")
  return ok and ns.Usable(v) and v == "0" or false
end
function ns.MaybeAutoLootHint()
  if not (ns.db and ns.db.hideUI) or ns.db.autoLootHinted or hidden or not AutoLootOff() then return false end
  ns.db.autoLootHinted = true
  ns.Print(L["Tip: with Auto Loot off, every catch opens the loot window and the interface comes back. Turn on Auto Loot in the game's options (Controls), or hold Shift when you click the bobber."])
  return true
end

-- auto loot off: the loot window needs the interface
ns.On("LOOT_OPENED", function(_, autoLoot)
  if hidden and not (autoLoot == true or autoLoot == 1) then
    ns.ShowInterface("loot window")
    ns.MaybeAutoLootHint()
  end
end)
-- the option switched off while hidden; switched on: the auto loot tip
function ns.ApplyHideUI()
  if not (ns.db and ns.db.hideUI) then ns.ShowInterface("option off") return end
  ns.MaybeAutoLootHint()
end

-- (1.4.1, Daniel 09.10.) While hidden, a few times a second: the player showed the interface himself
-- (Alt+Z), or started typing (the chat box belongs to the hidden interface): then it comes back.
-- Runs only while Luredon keeps the interface hidden.
local WATCH_EVERY = 0.25
local watchWait = 0
local function Watch()
  if not hidden then if watch then watch:Hide() end return end
  Sync()
  if not hidden then return end
  if type(GetCurrentKeyBoardFocus) == "function" then
    local ok, focus = pcall(GetCurrentKeyBoardFocus)
    if ok and focus ~= nil then ns.ShowInterface("typing") end
  end
end
ns.HideWatchTick = Watch -- (tests)
watch = CreateFrame("Frame")
watch:Hide()
watch:SetScript("OnUpdate", function(_, elapsed)
  watchWait = watchWait + (tonumber(elapsed) or 0)
  if watchWait < WATCH_EVERY then return end
  watchWait = 0
  ns.Call("hide watch", Watch)
end)
function ns.HideWatchRunning() return watch:IsShown() and true or false end

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
  -- (1.4.1) one list for the update, not a new table every frame
  ticker.all = { ticker.skill, ticker.warn }
  for _, fs in ipairs(ticker.lines) do ticker.all[#ticker.all + 1] = fs end
  ticker:SetScript("OnUpdate", function(self)
    local now, any = GetTime(), false
    for _, fs in ipairs(self.all) do
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
  if not ns.InterfaceHidden() or not id then return end
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
  if not ns.InterfaceHidden() or not msg then return end
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
  if not ns.InterfaceHidden() or not rank then return end
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
-- (1.4.1) Daniel 08.10.: the cast bar stays visible while the interface is
-- hidden. The game's bar belongs to the hidden interface, so Luredon draws its
-- own for the fishing channel: our frame on WorldFrame, where the game's bar
-- usually is (bottom centre), draining like a channel, with the time left.
-- It reads UnitChannelInfo("player") only; nothing of the game's bar is used.
---------------------------------------------------------------------------
local CAST_W, CAST_H = 220, 14
local function CreateCastbar()
  castbar = CreateFrame("Frame", "LuredonCastBar", WorldFrame)
  castbar:SetFrameStrata("HIGH")
  castbar:SetSize(CAST_W + 4, CAST_H + 4)
  castbar:SetPoint("BOTTOM", WorldFrame, "BOTTOM", 0, 190)
  local edge = castbar:CreateTexture(nil, "BACKGROUND")
  edge:SetAllPoints(castbar)
  edge:SetColorTexture(0, 0, 0, 0.75)
  local track = castbar:CreateTexture(nil, "BORDER")
  track:SetPoint("TOPLEFT", castbar, "TOPLEFT", 2, -2)
  track:SetPoint("BOTTOMRIGHT", castbar, "BOTTOMRIGHT", -2, 2)
  track:SetColorTexture(0.12, 0.12, 0.12, 0.9)
  local fill = castbar:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
  fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)
  fill:SetWidth(CAST_W)
  if fill:SetTexture("Interface\\TargetingFrame\\UI-StatusBar") == false then fill:SetColorTexture(1, 1, 1, 1) end
  fill:SetVertexColor(0.0, 0.85, 0.25) -- the game's channel green
  castbar.fill = fill
  local name = castbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("CENTER", castbar, "CENTER", 0, 0)
  castbar.name = name
  local left = castbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  left:SetPoint("RIGHT", castbar, "RIGHT", -6, 0)
  castbar.left = left
  castbar:SetScript("OnUpdate", function(self)
    local now = GetTime() * 1000
    local s0, e0 = self.startMS, self.endMS
    if not (s0 and e0) or e0 <= s0 or now >= e0 or not hidden then self:Hide() return end
    local frac = (e0 - now) / (e0 - s0)
    if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
    self.fill:SetWidth(math.max(1, CAST_W * frac))
    self.left:SetText(ns.CastSeconds((e0 - now) / 1000))
  end)
  castbar:Hide()
end

-- (1.4.1) Time left as "6,6s": one decimal with the game's decimal separator.
function ns.CastSeconds(sec)
  local sep = _G.DECIMAL_SEPERATOR or _G.DECIMAL_SEPARATOR
  local text = ("%.1f"):format(math.max(0, tonumber(sec) or 0))
  if type(sep) == "string" and sep ~= "" and sep ~= "." then text = text:gsub("%.", sep) end
  return L["%ss"]:format(text)
end

-- A fishing channel started while the interface is hidden: show our bar.
function CastStart()
  if not castbar then CreateCastbar() end
  local ok, name, _, _, startMS, endMS = pcall(UnitChannelInfo, "player")
  if not ok or not ns.Usable(startMS) or not ns.Usable(endMS) or type(startMS) ~= "number" or type(endMS) ~= "number" then
    castbar:Hide()
    return
  end
  local ui = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  local world = WorldFrame.GetEffectiveScale and WorldFrame:GetEffectiveScale() or 1
  if ui and world and world > 0 then castbar:SetScale(ui / world) end
  castbar.startMS, castbar.endMS = startMS, endMS
  castbar.name:SetText(ns.Usable(name) and type(name) == "string" and name or "")
  castbar:Show()
  stats.castbars = (stats.castbars or 0) + 1
end
function ns.LuredonCastbar() return castbar end -- (tests)

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
  if yes then ns.MaybeAutoLootHint() end
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

---------------------------------------------------------------------------
-- (1.4.1) Daniel 09.10.: chat while the interface is hidden. The game's chat
-- belongs to the hidden interface, so Luredon shows new messages in its own
-- lines on WorldFrame, bottom left where the chat usually is. Option chatFeed:
-- "private" (default: whispers, guild, group and raid), "all" (also say, yell,
-- emotes and channels) or "off". Each line fades out after 20 seconds. With
-- the feed on, a whisper no longer brings the interface back.
---------------------------------------------------------------------------
local FEED_LINES, FEED_HOLD, FEED_FADE = 6, 20, 2
local FEED_PRIVATE = {
  CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER", CHAT_MSG_GUILD = "GUILD",
  CHAT_MSG_OFFICER = "OFFICER", CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
  CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER", CHAT_MSG_RAID_WARNING = "RAID_WARNING",
}
local FEED_ALL = {
  CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL", CHAT_MSG_EMOTE = "EMOTE", CHAT_MSG_TEXT_EMOTE = "TEXT_EMOTE",
  CHAT_MSG_CHANNEL = "CHANNEL",
}
-- the game's own (localised) prefixes, e.g. "%s whispers: ", "[Guild] %s: "
local FEED_FORMAT = {
  WHISPER = "CHAT_WHISPER_GET", BN_WHISPER = "CHAT_BN_WHISPER_GET", GUILD = "CHAT_GUILD_GET",
  OFFICER = "CHAT_OFFICER_GET", PARTY = "CHAT_PARTY_GET", PARTY_LEADER = "CHAT_PARTY_LEADER_GET",
  RAID = "CHAT_RAID_GET", RAID_LEADER = "CHAT_RAID_LEADER_GET", RAID_WARNING = "CHAT_RAID_WARNING_GET",
  SAY = "CHAT_SAY_GET", YELL = "CHAT_YELL_GET", EMOTE = "CHAT_EMOTE_GET",
}

local feed
local function CreateFeed()
  feed = CreateFrame("Frame", "LuredonChatFeed", WorldFrame)
  feed:SetFrameStrata("HIGH")
  feed:SetSize(460, FEED_LINES * 20)
  feed:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", 24, 210)
  feed.lines = {}
  for i = 1, FEED_LINES do
    local fs = feed:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    if not fs:GetFontObject() and ChatFontNormal then fs:SetFontObject(ChatFontNormal) end
    local font, size = fs:GetFont()
    if font then pcall(fs.SetFont, fs, font, size or 14, "OUTLINE") end
    fs:SetPoint("BOTTOMLEFT", feed, "BOTTOMLEFT", 0, (i - 1) * 20)
    fs:SetWidth(460)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:Hide()
    feed.lines[i] = fs
  end
  feed:SetScript("OnUpdate", function(self)
    local now, any = GetTime(), false
    for _, fs in ipairs(self.lines) do
      local left = (fs.until_ or 0) - now
      if left > 0 then
        any = true
        fs:SetAlpha(left < FEED_FADE and left / FEED_FADE or 1)
      elseif fs:IsShown() then
        fs:Hide()
      end
    end
    if not any then self:Hide() end
  end)
  feed:Hide()
end

function ns.ChatFeedHide()
  if not feed then return end
  for _, fs in ipairs(feed.lines) do fs.until_ = 0 fs:Hide() end
  feed:Hide()
end

local function FeedColor(kind)
  local info = ChatTypeInfo and ChatTypeInfo[kind]
  if info and info.r then return ("|cff%02x%02x%02x"):format(info.r * 255, info.g * 255, info.b * 255) end
  return "|cffffffff"
end

local function Short(name)
  if type(name) ~= "string" then return "?" end
  if Ambiguate then
    local ok, short = pcall(Ambiguate, name, "short")
    if ok and type(short) == "string" then return short end
  end
  return (name:gsub("%-.*$", ""))
end

-- One chat message as a feed line (newest at the bottom, as in the chat).
function ns.ChatFeedAdd(kind, message, sender, channelName)
  if not ns.InterfaceHidden() or not ns.Usable(message) or not ns.Usable(sender) or type(message) ~= "string" then return end
  if not feed then CreateFeed() end
  local ui = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  local world = WorldFrame.GetEffectiveScale and WorldFrame:GetEffectiveScale() or 1
  if world > 0 then feed:SetScale(ui / world) end
  local who = Short(sender)
  local text
  if kind == "TEXT_EMOTE" then
    text = message
  elseif kind == "CHANNEL" then
    text = ("[%s] %s: %s"):format(type(channelName) == "string" and channelName ~= "" and channelName or "?", who, message)
  else
    local fmt = FEED_FORMAT[kind] and _G[FEED_FORMAT[kind]]
    if type(fmt) == "string" and fmt:find("%%s") then
      local ok, prefix = pcall(string.format, fmt, who)
      text = (ok and prefix or (who .. ": ")) .. message
    else
      text = who .. ": " .. message
    end
  end
  local color = FeedColor(kind == "CHANNEL" and "CHANNEL" or kind)
  for i = FEED_LINES, 2, -1 do
    local a, b = feed.lines[i], feed.lines[i - 1]
    a:SetText(b:GetText() or "")
    a.until_ = b.until_
    if b:IsShown() then a:Show() a:SetAlpha(b:GetAlpha()) else a:Hide() end
  end
  local line = feed.lines[1]
  line:SetText(color .. text .. "|r")
  line.until_ = GetTime() + FEED_HOLD + FEED_FADE
  line:SetAlpha(1)
  line:Show()
  feed:Show()
  stats.chatLines = (stats.chatLines or 0) + 1
end

for event, kind in pairs(FEED_PRIVATE) do
  ns.On(event, function(_, message, sender)
    if hidden and ns.db and (ns.db.chatFeed or "private") ~= "off" then ns.ChatFeedAdd(kind, message, sender) end
  end)
end
for event, kind in pairs(FEED_ALL) do
  ns.On(event, function(_, message, sender, _, _, _, _, _, _, channelBaseName)
    if hidden and ns.db and ns.db.chatFeed == "all" then ns.ChatFeedAdd(kind, message, sender, channelBaseName) end
  end)
end

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
-- (04.11.2026, Era-Test, Daniel: "schon seeehr groß") the question has the size of every Kit window: ASK_SCALE 1.5 is gone

local hidden = false
local hiddenAt = 0 -- (1.4.1) when Luredon hid the interface (GetTime)

-- (Leistungsprüfung D23, 31.10.2026) the events that only matter while Luredon has the interface hidden (chat feed,
-- reasons to bring it back, among them every chat line and every step) are registered only while it is hidden
local gate = CreateFrame("Frame")
local gated, gateOn = {}, false
local function OnHidden(event, fn)
  if not gated[event] then
    -- an event the client lacks throws: tried once here, then left out
    if not pcall(gate.RegisterEvent, gate, event) then return false end
    gate:UnregisterEvent(event)
    gated[event] = {}
  end
  table.insert(gated[event], fn)
  return true
end
gate:SetScript("OnEvent", function(_, event, ...)
  if not ns.db then return end
  local list = gated[event]
  if not list then return end
  for i = 1, #list do ns.Call(event, list[i], event, ...) end
end)
local function SetHidden(v)
  hidden = v
  if v == gateOn then return end
  gateOn = v
  for event in pairs(gated) do
    if v then gate:RegisterEvent(event) else gate:UnregisterEvent(event) end
  end
end
function ns.HiddenEvents() local n = 0 if gateOn then for _ in pairs(gated) do n = n + 1 end end return n end
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

-- 1.6.3 (Daniel 07.11.2026: "man sieht den chat dann zwar ... aber man kann nicht schreiben"): the chat box belongs
-- to the hidden interface, so Enter, / and the reply keys reached nothing. While Luredon keeps the interface hidden
-- (out of combat, set right after hiding) these keys click a button of ours: it brings the interface back and opens
-- the chat box as the key would have. Released whenever the interface comes back (combat brings it back first).
local CHAT_KEYS = { "OPENCHAT", "OPENCHATSLASH", "REPLY", "REPLY2" }
local chatKeyOwner, chatKeysOn
local chatKeyButtons = {}
local function ChatAction(action, text)
  local util = ChatFrameUtil
  if action == "OPENCHAT" or action == "OPENCHATSLASH" then
    local open = ChatFrame_OpenChat or (util and util.OpenChat)
    if open then pcall(open, text or (action == "OPENCHATSLASH" and "/" or "")) end
  elseif action == "REPLY" then
    local reply = ChatFrame_ReplyTell or (util and util.ReplyTell)
    if reply then pcall(reply) end
  else
    local reply = ChatFrame_ReplyTell2 or (util and util.ReplyTell2)
    if reply then pcall(reply) end
  end
end
local function ChatKeysRelease()
  if not chatKeysOn or not chatKeyOwner then return end
  if InCombatLockdown and InCombatLockdown() then return end
  ClearOverrideBindings(chatKeyOwner)
  chatKeysOn = false
end
local function ChatKeysSet()
  if chatKeysOn or type(GetBindingKey) ~= "function" or type(SetOverrideBindingClick) ~= "function" then return end
  if InCombatLockdown and InCombatLockdown() then return end
  if not chatKeyOwner then chatKeyOwner = CreateFrame("Frame", "LuredonChatKeyOwner", UIParent) end
  for _, action in ipairs(CHAT_KEYS) do
    local okKeys, k1, k2 = pcall(GetBindingKey, action)
    if okKeys and (k1 or k2) then
      local b = chatKeyButtons[action]
      if not b then
        b = CreateFrame("Button", "LuredonChatKey" .. action, UIParent)
        b:SetScript("OnClick", function()
          ns.Call("chat key", function()
            -- (1.6.3, Daniel: "ohne dass das ganze ui wieder kommt") Luredon's own input line under the feed
            if ns.ChatInputOpen and ns.ChatInputOpen(action) then return end
            if ns.ShowInterface then ns.ShowInterface("chat") end
            ChatAction(action)
          end)
        end)
        chatKeyButtons[action] = b
      end
      for _, k in ipairs({ k1, k2 }) do
        if type(k) == "string" and k ~= "" then
          SetOverrideBindingClick(chatKeyOwner, true, k, b:GetName())
          chatKeysOn = true
        end
      end
    end
  end
end
ns.ChatKeysOn = function() return chatKeysOn and true or false end -- (tests, /ld diag)

local function OverlaysHide()
  -- (1.6.3) a half typed line moves on into the game's chat box (the interface is back here)
  local carry = ns.ChatInputClose and ns.ChatInputClose()
  ChatKeysRelease()
  TickerHide()
  if ns.ChatFeedHide then ns.ChatFeedHide() end
  if castbar then castbar:Hide() end
  if watch then watch:Hide() end
  if type(carry) == "string" and carry ~= "" then ChatAction("OPENCHAT", carry) end
end
ns.ChatAction = ChatAction -- (1.6.3) for the input line: commands it cannot send go to the game's chat box

-- Back to the normal interface (reason for /ld diag).
function ns.ShowInterface(reason)
  if not hidden then return end
  SetHidden(false)
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
    SetHidden(false)
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
      SetHidden(true)
      hiddenAt = GetTime()
      stats.hides = stats.hides + 1
      if watch then watch:Show() end
      ChatKeysSet()
    end
  end
  if hidden then CastStart() end
end)
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function() if castbar then castbar:Hide() end end)
-- 1.6.3: chat keys the lockdown kept bound go back to the game after the fight
ns.On("PLAYER_REGEN_ENABLED", function() if not hidden then ChatKeysRelease() end end)

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
  OnHidden(event, function()
    -- (1.4.1) with the chat feed on, a whisper shows up there and the interface stays hidden
    if reason == "whisper" and ns.db and (ns.db.chatFeed or "private") ~= "off" then return end
    ns.ShowInterface(reason)
  end)
end
OnHidden("PLAYER_EQUIPMENT_CHANGED", function() if not ns.HasPole() then ns.ShowInterface("pole") end end)

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
    -- (1.6.3) typing in Luredon's own input line keeps the interface hidden
    if ok and focus ~= nil and focus ~= ns.chatInput then ns.ShowInterface("typing") end
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
local answered -- the question got its answer while shown (closing it then is no second answer)
local function Answer(yes)
  answered = true
  ns.db.hideUI = yes and true or false
  ns.db.askedHideUI = true
  if askPanel and askPanel:IsShown() then askPanel:Hide() end
  ns.Print(yes and L["The interface hides while your line is out. Change it under /ld options."]
    or L["The interface stays while you fish. You can switch hiding on under /ld options."])
  if yes then ns.MaybeAutoLootHint() end
end
ns.AnswerHideUI = Answer -- (tests)

-- (02.11.2026, StyleKit 2 step 4) the question is a dialog of DonCore's Kit: three lines, the two answers as buttons one
-- under the other over the whole width (long languages fit), "yes" the gold one; Esc or the close button answer "no".
local ASK_W = 380
function ns.MaybeAskHideUI()
  if not ns.db or ns.db.askedHideUI or ns.db.hideUI then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  local Kit = LibStub("DonCore-1.0"):Get("Kit", 11)
  if not Kit then return false end
  if not askPanel then
    local KC, S = Kit.C, Kit.SIZE
    askPanel = Kit.Dialog("LuredonAskHideUI", { title = "Luredon", icon = "Interface\\Icons\\Trade_Fishing", width = ASK_W,
      onClose = function() if not answered then Answer(false) end end })
    local body = askPanel.body
    local bw = ASK_W - 2 * S.pad
    askPanel.lines = {}
    local y = 0
    for i, line in ipairs({ { L["Hide the interface while fishing?"], KC.title, "row" },
        { L["Your catches show at the top of the screen."], KC.muted, "sub" },
        { L["Moving or a fight brings it back."], KC.muted, "sub" } }) do
      local fs = Kit.Text(body, line[3], line[2])
      fs:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
      fs:SetText(line[1])
      Kit.Fit(fs, bw)
      askPanel.lines[i] = fs
      y = y + (i == 1 and 22 or 18)
    end
    y = y + S.gap
    local yes = Kit.Button(body, L["Yes, hide it while fishing"], { kind = "primary", onClick = function() Answer(true) end })
    yes:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    yes:Layout(bw)
    y = y + S.button + S.unit
    local no = Kit.Button(body, L["No, keep the interface"], { onClick = function() Answer(false) end })
    no:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    no:Layout(bw)
    y = y + S.button
    askPanel:SetBodySize(bw, y)
    askPanel.yes, askPanel.no = yes, no -- (tests)
  end
  answered = false
  askPanel:Show()
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
local FEED_LINES, FEED_HOLD, FEED_FADE = 6, 20, 2 -- (1.6.3) FEED_LINES only sizes the history now
local FEED_PRIVATE = {
  CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_BN_WHISPER = "BN_WHISPER", CHAT_MSG_GUILD = "GUILD",
  CHAT_MSG_OFFICER = "OFFICER", CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
  CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER", CHAT_MSG_RAID_WARNING = "RAID_WARNING",
  CHAT_MSG_WHISPER_INFORM = "WHISPER_INFORM", CHAT_MSG_BN_WHISPER_INFORM = "BN_WHISPER_INFORM", -- (1.6.3) own whispers
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
  WHISPER_INFORM = "CHAT_WHISPER_INFORM_GET", BN_WHISPER_INFORM = "CHAT_BN_WHISPER_INFORM_GET", -- (1.6.3)
}

-- 1.6.3 (Daniel 07.11.2026: "man sieht den chat dann zwar ... aber anders", Wahl: "Wie der echte Chat"): the feed is a
-- scrolling message frame on the real chat window's place and size, with its font, font size and background, lines
-- wrap and fade like in the chat, names in brackets as the chat writes them.
local feed, feedBg
local feedLastAt = 0
local function Num(method, o)
  if type(o) ~= "table" or type(o[method]) ~= "function" then return nil end
  local ok, v = pcall(o[method], o)
  if ok and type(v) == "number" and ns.Usable(v) then return v end
end
local function ChatWindow()
  local cf = DEFAULT_CHAT_FRAME or ChatFrame1
  return type(cf) == "table" and cf or nil
end
local function FeedLayout()
  local cf = ChatWindow()
  local world = Num("GetEffectiveScale", WorldFrame) or 1
  local scale = Num("GetEffectiveScale", cf) or Num("GetEffectiveScale", UIParent) or 1
  if world > 0 and scale > 0 then feed:SetScale(scale / world) end
  local left, bottom = Num("GetLeft", cf), Num("GetBottom", cf)
  local width, height = Num("GetWidth", cf), Num("GetHeight", cf)
  if not (left and bottom and width and height and width > 50 and height > 30) then
    left, bottom, width, height = 32, 95, 430, 120 -- the default chat window
  end
  feed:ClearAllPoints()
  feed:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", left, bottom)
  feed:SetSize(width, height)
  -- font and background from the chat window's own settings
  local font, size, flags
  if cf and type(cf.GetFont) == "function" then
    local ok, f, s, fl = pcall(cf.GetFont, cf)
    if ok then font, size, flags = f, s, fl end
  end
  if not font and ChatFontNormal and ChatFontNormal.GetFont then
    local ok, f, s, fl = pcall(ChatFontNormal.GetFont, ChatFontNormal)
    if ok then font, size, flags = f, s, fl end
  end
  local r, g, b, a
  if type(GetChatWindowInfo) == "function" then
    local id = Num("GetID", cf) or 1
    local ok, _, infoSize, ir, ig, ib, ia = pcall(GetChatWindowInfo, id)
    if ok then
      if type(infoSize) == "number" and infoSize > 0 then size = infoSize end
      if type(ir) == "number" then r, g, b, a = ir, ig, ib, ia end
    end
  end
  if font then pcall(feed.SetFont, feed, font, size or 14, flags or "") end
  feedBg:SetColorTexture(r or 0, g or 0, b or 0, math.max(type(a) == "number" and a or 0, DEFAULT_CHATFRAME_ALPHA or 0.25))
end
local function CreateFeed()
  feed = CreateFrame("ScrollingMessageFrame", "LuredonChatFeed", WorldFrame)
  feed:SetFrameStrata("HIGH")
  feed:EnableMouse(false)
  feed:SetJustifyH("LEFT")
  feed:SetMaxLines(FEED_LINES * 4)
  feed:SetFading(true)
  feed:SetTimeVisible(FEED_HOLD)
  feed:SetFadeDuration(FEED_FADE)
  if feed.SetInsertMode then pcall(feed.SetInsertMode, feed, SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM or "BOTTOM") end
  feed:SetShadowColor(0, 0, 0, 1)
  feed:SetShadowOffset(1, -1)
  feedBg = feed:CreateTexture(nil, "BACKGROUND")
  feedBg:SetPoint("TOPLEFT", feed, "TOPLEFT", -2, 3)
  feedBg:SetPoint("BOTTOMRIGHT", feed, "BOTTOMRIGHT", 2, -6)
  -- the background goes with the last line
  feed:SetScript("OnUpdate", function(self)
    if GetTime() - feedLastAt > FEED_HOLD + FEED_FADE and not (ns.chatInput and ns.chatInput:IsShown()) then self:Hide() end
  end)
  feed:Hide()
end

function ns.ChatFeedHide()
  if not feed then return end
  if feed.Clear then feed:Clear() end
  feedLastAt = 0
  feed:Hide()
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
function ns.ChatFeedAdd(kind, message, sender, channelName, channelIndex)
  if not ns.InterfaceHidden() or not ns.Usable(message) or not ns.Usable(sender) or type(message) ~= "string" then return end
  if not feed then CreateFeed() end
  if not feed:IsShown() then FeedLayout() end
  local name = Short(sender)
  local who = (kind == "EMOTE") and name or ("[" .. name .. "]")
  local text
  if kind == "TEXT_EMOTE" then
    text = message
  elseif kind == "CHANNEL" then
    local channel = type(channelName) == "string" and channelName ~= "" and channelName or "?"
    if type(channelIndex) == "number" and channelIndex > 0 then channel = channelIndex .. ". " .. channel end
    text = ("[%s] %s: %s"):format(channel, who, message)
  else
    local fmt = FEED_FORMAT[kind] and _G[FEED_FORMAT[kind]]
    if type(fmt) == "string" and fmt:find("%%s") then
      local ok, prefix = pcall(string.format, fmt, who)
      text = (ok and prefix or (who .. ": ")) .. message
    else
      text = who .. ": " .. message
    end
  end
  local info = ChatTypeInfo and ChatTypeInfo[kind]
  local r, g, b = 1, 1, 1
  if type(info) == "table" and type(info.r) == "number" then r, g, b = info.r, info.g, info.b end
  feed:AddMessage(text, r, g, b)
  feedLastAt = GetTime()
  feed:Show()
  stats.chatLines = (stats.chatLines or 0) + 1
end

for event, kind in pairs(FEED_PRIVATE) do
  OnHidden(event, function(_, message, sender)
    if hidden and ns.db and (ns.db.chatFeed or "private") ~= "off" then ns.ChatFeedAdd(kind, message, sender) end
  end)
end
for event, kind in pairs(FEED_ALL) do
  OnHidden(event, function(_, message, sender, _, _, _, _, _, channelIndex, channelBaseName)
    if hidden and ns.db and ns.db.chatFeed == "all" then ns.ChatFeedAdd(kind, message, sender, channelBaseName, channelIndex) end
  end)
end

---------------------------------------------------------------------------
-- (1.6.3) Daniel 07.11.2026: "kann der chat nicht einfach so bleiben und ich schreibe nur darin, ohne dass das ganze ui
-- wieder kommt?" (Wahl: eigene Eingabezeile). The game's chat box belongs to the hidden interface, so Enter, / and the
-- reply keys open Luredon's own line under the feed. It sends plain chat itself (say, yell, guild, officer, party, raid,
-- raid warning, emote, whisper, reply, numbered channels; the type sticks as in the chat). Any other command (/cast,
-- macros, other addons) is protected or unknown here: the interface comes back and the line goes into the game's chat
-- box, one more Enter sends it. Esc closes the line. Combat, moving and the rest bring the interface back as before, a
-- half typed line moves on into the game's chat box.
---------------------------------------------------------------------------
local INPUT_SLASH = {
  s = "SAY", say = "SAY", y = "YELL", yell = "YELL", sh = "YELL", shout = "YELL",
  g = "GUILD", guild = "GUILD", o = "OFFICER", officer = "OFFICER",
  p = "PARTY", party = "PARTY", ra = "RAID", raid = "RAID", rw = "RAID_WARNING",
  e = "EMOTE", em = "EMOTE", me = "EMOTE", emote = "EMOTE",
  w = "WHISPER", whisper = "WHISPER", t = "WHISPER", tell = "WHISPER", msg = "WHISPER", send = "WHISPER",
  r = "REPLY", reply = "REPLY",
}
local INPUT_HEADER = {
  SAY = "CHAT_SAY_SEND", YELL = "CHAT_YELL_SEND", GUILD = "CHAT_GUILD_SEND", OFFICER = "CHAT_OFFICER_SEND",
  PARTY = "CHAT_PARTY_SEND", RAID = "CHAT_RAID_SEND", RAID_WARNING = "CHAT_RAID_WARNING_SEND", EMOTE = "CHAT_EMOTE_SEND",
}
local input
local inputType, inputTarget = "SAY", nil -- the sticky chat type (and whisper name or channel number)

local function LastTell(told)
  local fn
  if told then
    fn = ChatEdit_GetLastToldTarget or (ChatFrameUtil and ChatFrameUtil.GetLastToldTarget)
  else
    fn = ChatEdit_GetLastTellTarget or (ChatFrameUtil and ChatFrameUtil.GetLastTellTarget)
  end
  if not fn then return nil end
  local ok, name = pcall(fn)
  return ok and type(name) == "string" and name ~= "" and name or nil
end

local function Header()
  local kind = inputType
  if kind == "WHISPER" then
    local fmt = type(CHAT_WHISPER_SEND) == "string" and CHAT_WHISPER_SEND or "Tell %s: "
    local ok, s = pcall(string.format, fmt, inputTarget or "?")
    return ok and s or ("Tell " .. tostring(inputTarget) .. ": ")
  elseif kind == "CHANNEL" then
    local name
    if GetChannelName then
      local ok, _, n = pcall(GetChannelName, inputTarget)
      if ok and type(n) == "string" then name = n end
    end
    return ("[%s. %s] "):format(tostring(inputTarget), name or "?")
  end
  local s = _G[INPUT_HEADER[kind] or ""]
  if type(s) == "string" and s ~= "" and not s:find("%%") then return s end
  return kind:sub(1, 1) .. kind:sub(2):lower() .. ": "
end

local function InputColor()
  local key = inputType == "CHANNEL" and ("CHANNEL" .. tostring(inputTarget)) or inputType
  local info = ChatTypeInfo and ChatTypeInfo[key]
  if type(info) == "table" and type(info.r) == "number" then return info.r, info.g, info.b end
  return 1, 1, 1
end

local function InputRefresh()
  if not input then return end
  local r, g, b = InputColor()
  input.header:SetText(Header())
  input.header:SetTextColor(r, g, b)
  input:SetTextColor(r, g, b)
  local w = input.header.GetStringWidth and input.header:GetStringWidth() or 0
  input:SetTextInsets((type(w) == "number" and w or 0) + 6, 6, 0, 0)
end

local function Send(kind, target, message)
  message = message:sub(1, 255)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not send then return false end
  local ok
  if kind == "CHANNEL" or kind == "WHISPER" then
    ok = pcall(send, message, kind, nil, target)
  else
    ok = pcall(send, message, kind)
  end
  stats.inputSent = (stats.inputSent or 0) + (ok and 1 or 0)
  return ok
end

local function InputHide()
  if not input then return end
  input:SetText("")
  input:ClearFocus()
  input:Hide()
end

-- Hand the line over to the game's chat box: the interface comes back.
local function HandOver(text)
  InputHide()
  stats.inputHandedOver = (stats.inputHandedOver or 0) + 1
  if ns.ShowInterface then ns.ShowInterface("chat command") end
  if ns.ChatAction then ns.ChatAction("OPENCHAT", text) end
end

-- What the line says: send it, switch the sticky type, or hand it over. Returns true when the line stays open.
local function InputEnter(text)
  if type(text) ~= "string" then text = "" end
  text = text:gsub("^%s+", "")
  if text == "" then InputHide() return false end
  if text:sub(1, 1) ~= "/" then
    if inputType == "WHISPER" and not inputTarget then HandOver(text) return false end
    if input then input:AddHistoryLine(text) end
    Send(inputType, inputTarget, text)
    InputHide()
    return false
  end
  local cmd, rest = text:match("^/(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower()
  local kind = cmd and (tonumber(cmd) and "CHANNEL" or INPUT_SLASH[cmd])
  if not kind then HandOver(text) return false end
  local target
  if kind == "CHANNEL" then
    target = tonumber(cmd)
  elseif kind == "WHISPER" then
    target, rest = rest:match("^(%S+)%s*(.*)$")
    if not target then HandOver(text) return false end
  elseif kind == "REPLY" then
    kind, target = "WHISPER", LastTell(false)
    if not target then HandOver(text) return false end
  end
  inputType, inputTarget = kind, target
  if rest == "" then
    -- only the command: the line stays open with the new type, as in the chat
    if input then input:SetText("") end
    InputRefresh()
    return true
  end
  if input then input:AddHistoryLine(text) end
  Send(kind, target, rest)
  InputHide()
  return false
end
ns.ChatInputEnter = InputEnter -- (tests)

local function CreateInput()
  input = CreateFrame("EditBox", "LuredonChatInput", WorldFrame)
  ns.chatInput = input
  input:SetFrameStrata("DIALOG")
  input:SetAutoFocus(false)
  input:SetMaxLetters(255)
  input:SetHistoryLines(32)
  if input.SetAltArrowKeyMode then input:SetAltArrowKeyMode(false) end
  input:SetHeight(26)
  local bg = input:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(input)
  bg:SetColorTexture(0, 0, 0, 0.6)
  local line = input:CreateTexture(nil, "BORDER")
  line:SetPoint("TOPLEFT", input, "TOPLEFT", 0, 0)
  line:SetPoint("TOPRIGHT", input, "TOPRIGHT", 0, 0)
  line:SetHeight(1)
  line:SetColorTexture(1, 0.82, 0, 0.5)
  input.header = input:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
  input.header:SetPoint("LEFT", input, "LEFT", 6, 0)
  input:SetScript("OnEnterPressed", function(self)
    ns.Call("chat input", function() InputEnter(self:GetText()) end)
  end)
  input:SetScript("OnEscapePressed", function() InputHide() end)
  input:SetScript("OnSpacePressed", function(self)
    -- "/g " switches the type at once, as in the chat (not for whispers: the name follows)
    ns.Call("chat input space", function()
      local t = self:GetText()
      if type(t) == "string" and t:match("^/%S+ $") then
        local cmd = t:match("^/(%S+)"):lower()
        local kind = INPUT_SLASH[cmd]
        if tonumber(cmd) or (kind and kind ~= "WHISPER") then InputEnter(t) end
      end
    end)
  end)
  input:Hide()
end

-- Opens the line for a chat key; false: not possible (the caller brings the interface back).
function ns.ChatInputOpen(action)
  if not ns.InterfaceHidden() then return false end
  if not feed then CreateFeed() end
  if not input then CreateInput() end
  FeedLayout()
  feedLastAt = GetTime()
  feed:Show()
  local ok, font, size, flags = pcall(feed.GetFont, feed)
  if ok and font then
    pcall(input.SetFont, input, font, size or 14, flags or "")
    pcall(input.header.SetFont, input.header, font, size or 14, flags or "")
  end
  input:SetScale(feed:GetScale() or 1)
  input:ClearAllPoints()
  input:SetPoint("TOPLEFT", feed, "BOTTOMLEFT", -2, -8)
  input:SetPoint("TOPRIGHT", feed, "BOTTOMRIGHT", 2, -8)
  local text = ""
  if action == "OPENCHATSLASH" then
    text = "/"
  elseif action == "REPLY" or action == "REPLY2" then
    local name = LastTell(action == "REPLY2")
    if name then inputType, inputTarget = "WHISPER", name end
  end
  if inputType == "WHISPER" and not inputTarget then inputType = "SAY" end
  InputRefresh()
  input:Show()
  input:SetText(text)
  input:SetFocus()
  stats.inputOpened = (stats.inputOpened or 0) + 1
  return true
end

-- Closes the line (the interface came back); returns what was typed so far.
function ns.ChatInputClose()
  if not input or not input:IsShown() then return nil end
  local text = input:GetText()
  InputHide()
  if type(text) == "string" and text ~= "" and text ~= "/" then return text end
end

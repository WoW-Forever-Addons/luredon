local _, ns = ...
local L = ns.L

local INVSLOT_MAIN = INVSLOT_MAINHAND or 16
local DOUBLE_CLICK_MAX, DOUBLE_CLICK_MIN = 0.4, 0.05
local ARM_TIMEOUT = 2   -- seconds the right mouse button may stay bound to our button
local LURE_RENEW = 20   -- renew a lure (same kind only) that would run out during the next cast
local LURE_PENDING = 3  -- seconds after using a lure in which no second lure is used
local LURE_SETTLE = 1.5 -- after the lure cast ends: time for the enchant to show up
local LURE_LEARN = 15   -- a lure that shows up this soon after our click is ours
local UNIT_QUIET = 1    -- 1.16: after a right-click on a unit, world clicks this soon count for nothing
local HOLD_MAX = 0.3    -- 1.17: a right button held longer than this was camera turning, not a click
local CONFLICTS = { "FishingBuddy", "FishingAce", "BetterFishing" }

BINDING_HEADER_LUREDON = "Luredon"
_G["BINDING_NAME_CLICK LuredonCastButton:LeftButton"] = L["Cast / apply lure"]
BINDING_NAME_LUREDON_GEAR = L["Toggle fishing gear"]
BINDING_NAME_LUREDON_PANEL = L["Show / hide panel"]

local button
ns.nextAction = "cast" -- "cast", "lure" or "wait" (lure is being applied)
ns.nextLure = nil
-- The weapon enchant shows up only after the server applied the lure. A click in
-- between would use a second lure (wasted) or interrupt the first one.
local lurePendingUntil, lureClickAt = 0, nil
local lurePole    -- pole (item ID) the lure click was meant for
local lureCasting -- the lure cast is running (from the cast events, UnitCastingInfo may be secret)
local appliedLure -- lure item Luredon put on the pole (nil once it is gone or another lure showed up)
local appliedPole -- the pole appliedLure belongs to
local hadLure
local trackedPole -- pole whose lure TrackLure followed last
local overrideActive = false

function ns.ConflictingAddon()
  for _, name in ipairs(CONFLICTS) do
    if ns.IsAddOnLoaded(name) then return name end
  end
end

-- Calls a state query; true only for a readable true value (nil, errors and secrets count as false).
local function Flag(fn, ...)
  if not fn then return false end
  local ok, v = pcall(fn, ...)
  return ok and ns.Usable(v) and v and true or false
end

-- Applying a lure is a cast of a few seconds.
local function PlayerCasting()
  if not UnitCastingInfo then return false end
  local ok, name = pcall(UnitCastingInfo, "player")
  return ok and ns.Usable(name) and true or false
end

-- A lure click only counts for the pole it was meant for: after a gear swap the
-- lure on the other pole is not ours (its enchant ID or remaining time must not be learned).
local function LureClickRecent()
  return lureClickAt ~= nil and GetTime() - lureClickAt < LURE_LEARN and ns.PoleItemID() == lurePole
end

-- Forgets a running lure click (pole swapped, loading screen).
local function ForgetLureClick()
  lureClickAt, lurePole, lureCasting = nil, nil, nil
  lurePendingUntil = 0
end

-- Follows the lure on the pole: which one Luredon applied, its enchant ID, and
-- whether the client reports the remaining time in seconds instead of milliseconds.
local function TrackLure(has, raw, enchantID)
  if has == nil then return end
  -- Another pole: its lure state starts fresh (otherwise a lure already on it would look new).
  local pole = ns.PoleItemID()
  if pole ~= trackedPole then
    trackedPole = pole
    hadLure = nil
  end
  local ours = LureClickRecent()
  -- What Luredon knows about its lure only changes on the pole it was put on.
  local onApplied = pole == appliedPole
  if not has then
    if not ours and onApplied then appliedLure = nil end
  elseif not hadLure then
    if not ours then
      if onApplied then appliedLure = nil end -- put on by hand (or before a reload): kind unknown
    elseif raw and raw >= 1 and raw <= 7200 and not ns.lureSeconds then
      -- A fresh lure lasts minutes: 7200 ms would be 7 seconds, so these are seconds.
      ns.lureSeconds = true
      ns.Decide("lure-unit-s", nil, tostring(raw))
    end
  end
  if has and ours and appliedLure and enchantID then ns.db.lureEnchants[appliedLure] = enchantID end
  hadLure = has
end

-- Renewing a lure of another kind would make the client ask "replace the enchant?".
-- So a running lure is only renewed early if it is certainly the same kind.
local function SameLure(lure, enchantID)
  local learned = ns.db.lureEnchants[lure.item]
  if enchantID and learned then return learned == enchantID end
  return appliedLure == lure.item and ns.PoleItemID() == appliedPole
end

-- 1.15: an attribute is only written when its value changes (the cast ticker asks every 3 s,
-- and every write runs the secure template's attribute handler).
local attrs, written = {}, {}
local function SetAttr(key, value)
  if written[key] and attrs[key] == value then return end
  button:SetAttribute(key, value)
  attrs[key], written[key] = value, true
end

-- 1.16: the 3 s lure check only runs with a pole in hand, Fishing learned and "Apply lure
-- first" on; it is the only thing that changes by itself (lures expire silently).
local lureTicker
local function UpdateLureTicker()
  local active = ns.db.autoLure and ns.HasPole() and ns.KnowsFishing() and true or false
  if lureTicker then lureTicker:SetActive(active) end
  return active
end
function ns.LureTicking() return lureTicker ~= nil and lureTicker:IsActive() end

-- Decide what the next click does and put it on the secure button.
-- Secure attributes can only change out of combat.
local function Prepare()
  local lureCheck = UpdateLureTicker() -- the same test decides whether a lure is wanted
  if not button or InCombatLockdown() then return end
  local lure, waiting
  ns.lureRenewSkipped = nil
  if lureCheck then
    local has, left, enchantID, raw = ns.GetLure()
    TrackLure(has, raw, enchantID)
    if raw then left = raw / (ns.lureSeconds and 1 or 1000) end -- the unit may just have been detected
    local wanted
    if has == false then
      wanted = ns.BestLure()
    elseif has and left and left < LURE_RENEW then
      wanted = ns.BestLure()
      if wanted and not SameLure(wanted, enchantID) then
        ns.lureRenewSkipped = true -- applied once the running lure is gone
        wanted = nil
      end
    end
    if wanted then
      if GetTime() < lurePendingUntil or (LureClickRecent() and (lureCasting or PlayerCasting())) then
        waiting = true
      else
        lure = wanted
      end
    end
  end
  ns.nextAction = waiting and "wait" or lure and "lure" or "cast"
  ns.nextLure = lure and lure.item or nil
  -- While waiting the button does nothing (also for the key binding).
  local actionType = lure and "item" or "spell"
  if waiting then actionType = nil end
  SetAttr("type", actionType)
  SetAttr("item", lure and ("item:" .. lure.item) or nil)
  SetAttr("target-slot", lure and INVSLOT_MAIN or nil)
  -- Localized name, or the spell ID when the client gives no readable name (1.14).
  SetAttr("spell", ns.FishingCastSpell())
end

local queued = false
local function QueuePrepare()
  if queued then return end
  queued = true
  C_Timer.After(0.2, function()
    queued = false
    ns.Call("prepare", Prepare)
  end)
end
ns.QueuePrepare = QueuePrepare

-- Luredon's own windows. The right button passes through them to the world (camera turning
-- keeps working), so the mouse focus may report the world there: this check keeps a double
-- right-click on them from casting.
local ownWindows = {}
local function OverOwnWindow()
  ownWindows[1], ownWindows[2], ownWindows[3] = ns.panel or false, ns.exportFrame or false, ns.logPanel or false
  for i = 1, 3 do
    local f = ownWindows[i]
    if f then
      local okV, visible = pcall(f.IsVisible, f)
      local okM, over = pcall(f.IsMouseOver, f)
      if okV and visible and okM and over == true then return true end
    end
  end
  return false
end

local function IsWorldUnderMouse()
  if OverOwnWindow() then return false end
  local getFoci, getFocus = GetMouseFoci, GetMouseFocus
  local ok, focus
  if getFoci then
    local foci
    ok, foci = pcall(getFoci)
    focus = ok and type(foci) == "table" and foci[1] or nil
  elseif getFocus then
    ok, focus = pcall(getFocus)
    if not ok then focus = nil end
  else
    return true
  end
  return focus == nil or focus == WorldFrame
end

-- Right-clicking a unit (mob, NPC, player) must keep its normal meaning.
-- A secret answer counts as "no unit" (logged in /ld diag via the mouseover probe).
local function IsUnitUnderMouse()
  return Flag(UnitExists, "mouseover")
end

-- States in which Fishing cannot be cast anyway: leave the right mouse button alone.
local function PauseReason()
  if InCombatLockdown() then return "combat" end
  if Flag(IsMounted) then return "mounted" end
  if Flag(IsSwimming) then return "swimming" end
  if Flag(IsFlying) then return "flying" end
  if Flag(UnitOnTaxi, "player") then return "taxi" end
  if Flag(UnitIsDeadOrGhost, "player") then return "dead" end
end
local function BlockReason()
  local reason = PauseReason()
  if reason then return reason end
  if not ns.HasPole() then return "no-pole" end
  if not ns.KnowsFishing() then return "not-known" end
end
-- For /ld diag: why a double-click would do nothing right now (nil = it would act).
function ns.CastBlockReason()
  local ok, reason = pcall(BlockReason)
  return ok and reason or nil
end
-- For the window, which checks pole and Fishing itself (1.15): only the passing states.
function ns.CastPauseReason()
  local ok, reason = pcall(PauseReason)
  return ok and reason or nil
end

-- The override must never outlive the click: PostClick clears it, combat start
-- clears it, and as a last resort a timer does.
local armed = 0
local function Disarm()
  armed = armed + 1
  if button and not InCombatLockdown() then
    ClearOverrideBindings(button)
    overrideActive = false
  end
end

-- When the line came in (bobber clicked, fish got away, cast ended).
local lineInAt = 0
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  if ns.IsFishingSpell(spellID) then lineInAt = GetTime() end
end)

local lastClick, lastAnyClick
local lastUnitClick -- 1.16: last right-click on a unit (NPC, mob, corpse, player)
local downAt -- 1.17: when the right button went down (for the hold time)
local function ForgetClicks() lastClick, lastAnyClick, lastUnitClick, downAt = nil, nil, nil, nil end
local function Gap(from, now) return from and math.floor((now - from) * 1000 + 0.5) or nil end

local function OnMouseDown(_, mouseButton)
  if mouseButton ~= "RightButton" then return end
  local now = GetTime()
  downAt = now
  local previous = lastAnyClick
  lastAnyClick = now
  -- Only clicks into the world count, so a click on a frame plus one into the world is no double-click.
  local world = IsWorldUnderMouse()
  local unit = world and IsUnitUnderMouse()
  if not world or unit then
    -- Logged only as the second click of a would-be double-click.
    if previous and now - previous < DOUBLE_CLICK_MAX then ns.Decide(unit and "unit" or "ui", Gap(previous, now)) end
    if unit then lastUnitClick = now end
    lastClick = nil
    return
  end
  -- 1.16: right after a click on a unit the pointer may already be over the world (the NPC
  -- turned away, the corpse was looted and vanished, a gossip window closed). Clicks in this
  -- short time never start or finish a double-click, so talking or looting never ends in a cast.
  if lastUnitClick and now - lastUnitClick < UNIT_QUIET then
    if previous and now - previous < DOUBLE_CLICK_MAX then ns.Decide("unit-quiet", Gap(previous, now)) end
    lastClick = nil
    return
  end
  local gap = Gap(lastClick, now)
  local within = lastClick and (now - lastClick) < DOUBLE_CLICK_MAX
  local double = within and (now - lastClick) > DOUBLE_CLICK_MIN
  if within and not double then ns.Decide("too-fast", gap) end
  -- The first click hooked the bobber (the line came in between both clicks): a
  -- double-click on the bobber must not throw the line out again right away.
  if double and lineInAt > lastClick then
    double = false
    ns.Decide("bobber", gap)
  end
  lastClick = (not double) and now or nil
  if not double then return end
  if not ns.db.easyCast then ns.Decide("off", gap) return end
  if ns.conflict then ns.Decide("conflict", gap) return end
  local blocked = BlockReason()
  if blocked then ns.Decide(blocked, gap) return end

  -- Decide with fresh bag data (the window and the ticker use a cached best lure).
  if ns.InvalidateLureCache then ns.InvalidateLureCache() end
  Prepare()
  -- A lure is still being applied: leave the right mouse button alone.
  if ns.nextAction == "wait" then ns.Decide("lure-wait", gap) return end
  -- The first press started camera turning; stop it or it never ends.
  if Flag(IsMouselooking) and MouselookStop then MouselookStop() end
  -- For exactly one press the right mouse button clicks our secure button.
  -- Forever has no secure snippets, so PostClick removes the binding again.
  SetOverrideBindingClick(button, true, "BUTTON2", button:GetName())
  overrideActive = true
  armed = armed + 1
  local token = armed
  C_Timer.After(ARM_TIMEOUT, ns.Safe("disarm timer", function()
    if armed == token then
      if overrideActive then ns.Decide("disarm-timeout") end
      Disarm()
    end
  end))
  ns.Decide(ns.nextAction, gap, ns.nextLure and ("item:" .. ns.nextLure) or nil)
end

-- Click registration and attributes of a secure button are locked in combat. After a /reload
-- in combat the setup waits for the end of the fight (1.15).
local buttonReady = false
local function SetupButton()
  if buttonReady or not button or InCombatLockdown() then return end
  button:RegisterForClicks("AnyDown", "AnyUp")
  button:SetAttribute("useOnKeyDown", false)
  buttonReady = true
end

ns.OnInit(function()
  button = CreateFrame("Button", "LuredonCastButton", UIParent, "SecureActionButtonTemplate")
  SetupButton()
  button:SetScript("PostClick", function(self, _, down)
    if not down and not InCombatLockdown() then
      ns.Call("postclick", function()
        if ns.nextAction == "lure" then
          lurePendingUntil = GetTime() + LURE_PENDING
          lureClickAt = GetTime()
          lurePole = ns.PoleItemID()
          appliedLure = ns.nextLure
          appliedPole = lurePole
          C_Timer.After(LURE_PENDING + 0.1, QueuePrepare)
        end
        ns.Decide("clicked", nil, ns.nextAction)
      end)
      -- The binding is always removed, even if the bookkeeping above failed.
      ns.Call("postclick disarm", Disarm)
      ns.Call("postclick prepare", QueuePrepare)
    end
  end)

  ns.conflict = ns.ConflictingAddon()
  if ns.conflict then
    ns.Print(L["%s is loaded: double-click casting and sounds are left to it."]:format(ns.conflict))
  end
  Prepare()
end)

ns.On("GLOBAL_MOUSE_DOWN", OnMouseDown)

-- 1.17: turning the camera with a short right-button drag used to count as the first click of a
-- double-click when the next press followed within 0.4 s. A press held longer than HOLD_MAX
-- (a real click is over in a fraction of a second) is forgotten when the button comes up.
ns.On("GLOBAL_MOUSE_UP", function(_, mouseButton)
  if mouseButton ~= "RightButton" or not downAt then return end
  local held = GetTime() - downAt
  downAt = nil
  if lastClick and held > HOLD_MAX then
    lastClick = nil
    ns.Decide("hold", math.floor(held * 1000 + 0.5))
  end
end)

-- PLAYER_REGEN_DISABLED fires just before the lockdown starts, so the override can
-- still be removed; otherwise every right-click in combat would cast Fishing.
-- /ld diag shows "combat-locked" if the lockdown had already started.
ns.On("PLAYER_REGEN_DISABLED", function()
  if overrideActive then ns.Decide(InCombatLockdown() and "combat-locked" or "combat-disarm") end
  Disarm()
end)
-- Fallback in case combat started anyway between press and release.
ns.On("PLAYER_REGEN_ENABLED", function()
  Disarm()
  SetupButton()
  QueuePrepare()
end)

-- The lure cast started: wait for it (also if UnitCastingInfo answers with a secret).
-- The lure cast starts right after the click, so only a start within the wait time counts.
ns.OnPlayer("UNIT_SPELLCAST_START", function()
  if LureClickRecent() and GetTime() < lurePendingUntil then lureCasting = true end
end)

-- The lure cast ended: give the enchant a moment to show up, then decide again.
local function LureCastEnded()
  if not LureClickRecent() then return end
  lureCasting = nil
  lurePendingUntil = math.max(lurePendingUntil, GetTime() + LURE_SETTLE)
  C_Timer.After(LURE_SETTLE + 0.1, QueuePrepare)
end
for _, event in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
  ns.OnPlayer(event, LureCastEnded)
end

-- Loading screen (zone change, instance, /reload): the override must not survive it, a
-- click before it and one after it are no double-click, and a lure cast is cancelled by it.
local function WorldChanged(event)
  if overrideActive then ns.Decide("loading-disarm", nil, event) end
  Disarm()
  ForgetClicks()
  if lureClickAt then ForgetLureClick() end
  QueuePrepare()
end
ns.On("PLAYER_ENTERING_WORLD", WorldChanged)
ns.On("LOADING_SCREEN_ENABLED", WorldChanged)
ns.On("PLAYER_LEAVING_WORLD", WorldChanged)

-- Pole swapped (gear set, by hand) during or right after the lure click: the click no
-- longer belongs to the pole in hand, so its wait time and learning stop.
ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
  if slot == INVSLOT_MAIN and lureClickAt and ns.PoleItemID() ~= lurePole then
    ns.Decide("pole-swapped")
    ForgetLureClick()
  end
  QueuePrepare()
end)
ns.On("BAG_UPDATE_DELAYED", QueuePrepare)
ns.On("SKILL_LINES_CHANGED", QueuePrepare)
ns.OnPlayer("UNIT_INVENTORY_CHANGED", QueuePrepare)

-- State for /ld diag.
function ns.CastState()
  local now = GetTime()
  return {
    override = overrideActive,
    nextAction = ns.nextAction,
    nextLure = ns.nextLure,
    lureWait = math.max(0, lurePendingUntil - now),
    lureCasting = lureCasting and true or false,
    appliedLure = appliedLure,
    appliedPole = appliedPole,
    renewSkipped = ns.lureRenewSkipped,
    lineInAgo = lineInAt > 0 and now - lineInAt or nil,
  }
end

-- Lures expire silently: re-check every few seconds while a pole is in hand (1.16: the
-- ticker stops without pole, without Fishing or with "Apply lure first" off).
ns.OnInit(function()
  lureTicker = ns.GatedTicker("lure ticker", 3, function()
    if ns.HasPole() then Prepare() else UpdateLureTicker() end
  end)
  UpdateLureTicker()
end)

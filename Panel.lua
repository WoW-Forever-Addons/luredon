local _, ns = ...
local L = ns.L
local Style = ns.Style

---------------------------------------------------------------------------
-- Fishing window, built with the shared Style kit (see DESIGN.md).
-- Rows are created once in a fixed order; each update only changes texts,
-- colours and which rows are visible, so tooltips and hover stay steady.
---------------------------------------------------------------------------
local WIDTH = 240
local DEFAULT_POINT = { "RIGHT", "RIGHT", -60, 60 }
local LURE_LOW = 60   -- seconds: the lure is about to run out (warning colour)
local BAGS_LOW = 2    -- free bag slots: almost full (same limit as the cast warning)

local panel
local forced -- shown with /ld even without a pole
local hiding -- a fade-out was started (FadeIn only when hidden or hiding)
local rows, headers, bars = {}, {}, {}

-- Window state lives in LuredonDB under the existing keys (1.10 values stay valid).
local KEYS = {
  pos = "panelPos", locked = "panelLocked", scale = "panelScale", alpha = "panelAlpha",
  collapsed = "panelCollapsed", combatFade = "combatFade", shown = "showPanel",
}
local function Get(key) local k = KEYS[key]; if k and ns.db then return ns.db[k] end end
local function Set(key, value) local k = KEYS[key]; if k and ns.db then ns.db[k] = value end end

---------------------------------------------------------------------------
-- Small helpers. Kit v2 setters and Show/Hide do nothing when nothing changed
-- and schedule the relayout themselves, so the 1 s ticker can call them freely.
---------------------------------------------------------------------------
local function Line(row, text, color)
  row:SetText(text, color or "textPrimary")
  row:SetValue("")
end

local function KV(row, label, value, color)
  Style.KeyValue(row, label, value, color or "textPrimary")
end

local function Visible(item, on)
  item:SetShown(on and true or false)
end

local function SetBar(bar, value, color)
  bar:SetValue(tonumber(value) or 0)
  -- Colour changes are not tracked by the kit: tint only when it changed.
  if bar._color ~= color then bar._color = color; bar:SetSegmentColor(1, color) end
end

local function ItemText(id)
  local name, link = ns.GetItemInfo(id)
  return link or name or ("item:" .. id)
end

---------------------------------------------------------------------------
-- Tooltips (Style.Tooltip: title, key/value lines, hint)
---------------------------------------------------------------------------
local function ZoneName(mapID) return ns.MapName(mapID) end

local function IsRare(id)
  local q = ns.ItemQuality(id)
  return q and q >= ns.RARE_QUALITY
end

local RARE_LIST = 5 -- rare catches listed in the zone tooltip
local ZONE_FISH_LIST = 8 -- (1.2) kinds listed from the zone's fish list

-- (1.2) "Fish in this zone" lines from the bundled list: name, share; caught ones
-- (onlyNew = false) with a mark. Returns the number of lines added.
local function ZoneFishLines(lines, list, onlyNew)
  local n = 0
  for _, e in ipairs(list) do
    if e.data and (not onlyNew or e.caught == 0) then
      if n >= ZONE_FISH_LIST then break end
      n = n + 1
      local left = ItemText(e.id)
      if e.kind == "c" then left = left .. " " .. Style.Colorize(L["(container)"], "textHint")
      elseif IsRare(e.id) then left = left .. " " .. Style.Colorize(L["(rare)"], "warning") end
      local right = e.share and ("~" .. Style.Percent(e.share)) or ""
      lines[#lines + 1] = { left, right, "textSecondary" }
    end
  end
  return n
end

local function ZoneTooltip()
  local mapID, need, partsNeed = ns.ZoneRequirement()
  if not mapID then return L["Zone"], { L["Zone unknown here."] } end
  local title = ZoneName(mapID) or L["Zone"]
  local lines = {}
  local rank, _, modifier = ns.GetSkill()
  if need then
    lines[#lines + 1] = { L["Skill needed (no getaways)"], need }
    if partsNeed then lines[#lines + 1] = { L["Parts of the zone"], partsNeed } end
    lines[#lines + 1] = { L["Your skill with bonus"], rank + modifier, (rank + modifier) >= need and "good" or "critical" }
    -- Too low here: point to the zones that fit (1.14).
    if rank + modifier < need then lines[#lines + 1] = L["/ld zones lists zones for your skill."] end
  else
    -- (1.0.1) measured by other players (guild and group)
    local sneed, who
    if ns.SharedZoneSkill then sneed, who = ns.SharedZoneSkill(mapID) end
    if sneed then
      lines[#lines + 1] = { L["Skill needed (reported)"], L["%d (%d players)"]:format(sneed, who) }
      lines[#lines + 1] = { L["Your skill with bonus"], rank + modifier, (rank + modifier) >= sneed and "good" or "critical" }
    elseif ns.IsNewForeverZone(mapID) then
      lines[#lines + 1] = L["New Forever zone: skill needed not published yet."]
    else
      lines[#lines + 1] = L["Requirement unknown for this zone."]
    end
  end
  local top = ns.ZoneTopCatches(mapID, 8)
  local z = ns.db.zones[mapID]
  local fishList, kinds, caughtKinds
  if ns.ZoneFishList then fishList, kinds, caughtKinds = ns.ZoneFishList(mapID) end
  if #top == 0 or not z then
    -- (1.2) never fished here: what the zone has (bundled list)
    local listed = 0
    if fishList and #fishList > 0 then
      lines[#lines + 1] = { header = L["Fish in this zone"] }
      listed = ZoneFishLines(lines, fishList, false)
    elseif fishList then
      lines[#lines + 1] = L["No fishing waters known in this zone."]
    end
    -- (1.0.1) never fished here: what other players caught
    local others, total, who = {}, 0, 0
    if ns.SharedZoneCatches then others, total, who = ns.SharedZoneCatches(mapID, 8) end
    if #others == 0 then
      if listed > 0 then return title, lines, L["Shares according to Wowhead. You have no catches here yet."] end
      if not fishList then lines[#lines + 1] = L["No data yet."] end
      return title, lines
    end
    lines[#lines + 1] = { header = L["Fish (reported by others)"] }
    for _, e in ipairs(others) do
      local left = ItemText(e.id)
      if IsRare(e.id) then left = left .. " " .. Style.Colorize(L["(rare)"], "warning") end
      lines[#lines + 1] = { left, Style.Percent(e.share) }
    end
    lines[#lines + 1] = { L["Catches reported"], L["%s by %d players"]:format(Style.Number(total), who) }
    return title, lines, L["You have no catches here yet. Shared by Luredon players in your guild and group."]
  end
  -- Fish: the most frequent catches with their share.
  lines[#lines + 1] = { header = L["Fish"] }
  for _, e in ipairs(top) do
    local left = ItemText(e.id)
    if IsRare(e.id) then left = left .. " " .. Style.Colorize(L["(rare)"], "warning") end
    lines[#lines + 1] = { left, ("%s  (%d)"):format(Style.Percent(e.share), e.count) }
  end
  -- All catches of the zone, also those below the top list.
  local total, rare, rareList = 0, 0, {}
  for id, n in pairs(z.fish) do
    total = total + n
    if IsRare(id) then
      rare = rare + n
      rareList[#rareList + 1] = { id = id, count = n }
    end
  end
  lines[#lines + 1] = { L["Catches recorded"], Style.Number(total) }
  if (z.casts or 0) > 0 then lines[#lines + 1] = { L["Got away"], Style.Percent((z.getaways or 0) / z.casts) } end
  -- Rare: uncommon or better, also those outside the top list.
  if rare > 0 then
    table.sort(rareList, function(x, y) if x.count ~= y.count then return x.count > y.count end return x.id < y.id end)
    lines[#lines + 1] = { header = L["Rare"] }
    for i = 1, math.min(#rareList, RARE_LIST) do
      lines[#lines + 1] = { ItemText(rareList[i].id), rareList[i].count }
    end
    lines[#lines + 1] = { L["Rare (uncommon or better)"], Style.Percent(rare / total) }
  end
  -- (1.2) what the zone still has for you
  if fishList and kinds > 0 then
    lines[#lines + 1] = { L["Kinds caught here"], ("%d / %d"):format(caughtKinds, kinds), caughtKinds >= kinds and "good" or nil }
    local header = #lines + 1
    lines[header] = { header = L["Not caught here yet"] }
    if ZoneFishLines(lines, fishList, true) == 0 then table.remove(lines, header) end
  end
  return title, lines, L["From all your sessions in this zone."]
end

ns.ZoneTooltipLines = ZoneTooltip -- (1.0.1) for tests: title, lines, hint

local function SessionTooltip()
  local s = ns.session
  local lines = {}
  local top = ns.SessionTopCatches(10)
  if #top == 0 then lines[#lines + 1] = L["No data yet."] end
  for _, e in ipairs(top) do lines[#lines + 1] = { ItemText(e.id), e.count } end
  lines[#lines + 1] = " "
  lines[#lines + 1] = { L["Casts"], s.casts }
  lines[#lines + 1] = { L["Got away"], s.getaways }
  if s.junk > 0 then lines[#lines + 1] = { L["Junk"], s.junk } end
  if s.casts > 0 then lines[#lines + 1] = { L["Catch rate"], Style.Percent(s.catches / s.casts) } end
  if s.missed > 0 then lines[#lines + 1] = { L["Clicked too early"], s.missed } end
  local goldH = ns.PerHour(ns.SessionValue())
  if goldH then lines[#lines + 1] = { L["Gold/h"], ns.Money(goldH) } end
  -- (1.0) auction prices (Auctionator)
  if ns.AuctionPricesOn() then
    local ah, priced, missing = ns.SessionValueAH()
    if priced > 0 then
      lines[#lines + 1] = { L["Auction value"], ns.Money(ah) }
      local ahH = ns.PerHour(ah)
      if ahH then lines[#lines + 1] = { L["Auction gold/h"], ns.Money(ahH) } end
    end
    if missing > 0 then lines[#lines + 1] = { L["Items without auction price"], missing } end
    if priced == 0 then lines[#lines + 1] = L["Scan the auction house for prices."] end
  end
  return L["Catches this session"], lines, L["Click: catch log. /ld reset starts a new session."]
end

local function SkillTooltip()
  local rank, maxRank = ns.GetSkill()
  local list = ns.SkillUpEstimates(rank, maxRank)
  local lines = {}
  if #list == 0 then
    lines[#lines + 1] = L["Needs %d recorded skill-ups first (now %d)."]:format(
      ns.SKILL_ESTIMATE_MIN_SAMPLES, #ns.SkillData().history)
  end
  local labels = { zone = L["Next zone tier"], camp = L["Next camp object"], max = L["Skill cap"] }
  for _, e in ipairs(list) do
    lines[#lines + 1] = { L["%s (skill %d)"]:format(labels[e.kind], e.skill), L["~%d casts"]:format(e.casts) }
  end
  local hint
  if #list > 0 then
    hint = L["From your last %d skill-ups; zone tiers need lure and gear bonus on top."]:format(#ns.SkillData().history)
  end
  return L["Skill-up estimate"], lines, hint
end

local WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

-- 1.16: where the contest time comes from.
local function DerbyTooltip()
  local weekday, startHour, endHour, custom = ns.DerbySchedule()
  local lines = {
    { L["Time (realm time)"], ("%s %d:00-%d:00"):format(L[WEEKDAYS[weekday]], startHour, endHour % 24) },
    { L["Source"], custom and L["set with /ld derby"] or L["game data (as in Classic)"] },
  }
  if not custom and not ns.DERBY.announced then lines[#lines + 1] = L["Blizzard has not announced the Forever time yet."] end
  return L["Fishing Extravaganza"], lines, L["/ld derby <day> <hour> sets another time."]
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Create()
  panel = Style.Panel("LuredonPanel", UIParent, {
    title = Style.Wordmark("Lure", "don"),
    width = WIDTH,
    close = true,
    collapse = true,
    get = Get,
    set = Set,
    defaultPoint = DEFAULT_POINT,
    closeTooltip = { L["Hide window"], nil, L["/ld shows it again."] },
    collapseTooltip = { L["Collapse / expand"], nil, L["Collapsed, only the title bar stays."] },
    onClose = function() ns.TogglePanel(false) end,
    -- Collapsed rows are not updated; expanding shows the current values at once.
    onCollapse = function(_, collapsed) if not collapsed then ns.UpdatePanel() end end,
    buttons = { { kind = "options", key = "options", tooltip = { L["Options"], nil, L["Opens the Luredon options."] },
      onClick = function() ns.OpenOptions() end } },
  })

  rows.notLearned = Style.Row(panel)

  headers.fishing = Style.Header(panel, L["Fishing"])
  rows.skill = Style.Row(panel)
  bars.skill = Style.Bar(rows.skill)
  rows.perPoint = Style.Row(panel):SetTooltip(SkillTooltip)
  rows.lure = Style.Row(panel)
  rows.bags = Style.Row(panel)
  rows.milestone = Style.Row(panel)

  headers.session = Style.Header(panel, L["Session"])
  rows.sessionEmpty = Style.Row(panel)
  rows.catches = Style.Row(panel):SetTooltip(SessionTooltip)
  rows.rate = Style.Row(panel):SetTooltip(SessionTooltip)
  rows.fishH = Style.Row(panel):SetTooltip(SessionTooltip)
  rows.value = Style.Row(panel):SetTooltip(SessionTooltip)
  rows.valueAH = Style.Row(panel):SetTooltip(SessionTooltip) -- (1.0) only with Auctionator
  -- 1.17: a click on the session numbers opens the catch log.
  for _, r in ipairs({ rows.catches, rows.rate, rows.fishH, rows.value, rows.valueAH }) do
    r:SetOnClick(function(_, button)
      if button == nil or button == "LeftButton" then ns.ToggleLog() end
    end)
  end
  rows.goal = Style.Row(panel)
  bars.goal = Style.Bar(rows.goal)

  headers.zone = Style.Header(panel, L["Zone"])
  rows.zone = Style.Row(panel):SetTooltip(ZoneTooltip)
  rows.zoneParts = Style.Row(panel):SetTooltip(ZoneTooltip)
  rows.zoneGetaways = Style.Row(panel):SetTooltip(ZoneTooltip)

  headers.camp = Style.Header(panel, L["Camp"])
  rows.camp = {}
  for i = 1, 3 do rows.camp[i] = Style.Row(panel) end
  rows.campNext = Style.Row(panel)

  headers.derby = Style.Header(panel, L["Contest"])
  rows.derby = Style.Row(panel):SetTooltip(DerbyTooltip)
  rows.derbySource = Style.Row(panel):SetTooltip(DerbyTooltip)
  rows.tasty = Style.Row(panel)
  bars.tasty = Style.Bar(rows.tasty)

  -- Next click: quiet hint at the bottom, separated like a section.
  rows.next = Style.Row(panel):SetGapBefore(Style.SPACING.section)

  -- Left clicks stay in the window, the right button reaches the world (camera turning).
  -- A double right-click on the window still never casts (Cast.lua checks the pointer).
  -- Rows with a tooltip and the title bar let the right button through as well; the
  -- small header buttons keep it.
  local parts = { panel._header }
  for _, item in ipairs(panel._items or {}) do
    if item._kind == "row" then parts[#parts + 1] = item end
  end
  ns.RightClickThrough(panel, parts)

  Style.CombatFade(panel, ns.db.combatFade)
  ns.panel = panel
end

---------------------------------------------------------------------------
-- Content
---------------------------------------------------------------------------
local function UpdateFishing()
  local rank, maxRank, modifier, _, listed = ns.GetSkill()
  local known = listed or ns.KnowsFishing()

  -- 1.16: without Fishing one quiet line (no warning colour): the window has nothing else to say.
  Visible(rows.notLearned, not known)
  if not known then Line(rows.notLearned, L["Fishing not learned yet. Visit a fishing trainer."], "textSecondary") end

  -- Skill with bar (base skill against the current cap)
  Visible(rows.skill, known)
  if known and maxRank <= 0 then
    -- The client gave no skill (yet): no "0 / 0" with an empty bar.
    KV(rows.skill, L["Skill"], L["unknown"], "textHint")
    SetBar(bars.skill, 0, "accent")
  elseif known then
    local value = ("%d / %d"):format(rank, maxRank)
    if modifier > 0 then value = value .. " " .. Style.Colorize(("+%d"):format(modifier), "good") end
    local atCap = maxRank > 0 and rank >= maxRank
    local milestone = ns.MILESTONES[maxRank]
    local color = atCap and (milestone and "warning" or "good") or "textPrimary"
    KV(rows.skill, L["Skill"], value, color)
    SetBar(bars.skill, maxRank > 0 and rank / maxRank or 0, atCap and color or "accent")
  end

  -- Casts per skill point (tooltip: estimates)
  local avg = known and maxRank > 0 and rank < maxRank and ns.CastsPerPoint()
  Visible(rows.perPoint, avg and true or false)
  if avg then
    KV(rows.perPoint, L["Casts per skill point"], L["%s (now %d)"]:format(ns.Decimal(avg, 1), ns.SkillData().sinceUp))
  end

  -- Lure, with the number of lures left in the bags (best one the skill allows)
  local hasPole = ns.HasPole()
  local has, left = ns.GetLure()
  local stock = ""
  if hasPole and known then
    local _, count = ns.LureStock(rank)
    stock = ", " .. (count > 0 and L["%d in bags"]:format(count) or L["none in bags"])
  end
  if not hasPole then
    KV(rows.lure, L["Lure"], L["No pole"], "textHint")
  elseif has and left then
    KV(rows.lure, L["Lure"], L["%s left"]:format(ns.Duration(left)) .. stock, left < LURE_LOW and "warning" or "textPrimary")
  elseif has then
    KV(rows.lure, L["Lure"], L["active"] .. stock, "textPrimary")
  elseif has == false then
    KV(rows.lure, L["Lure"], L["none"] .. stock, "critical")
  else
    KV(rows.lure, L["Lure"], L["unknown"] .. stock, "textHint")
  end
  -- Without a pole the hint at the bottom says so; no second "no pole" line here.
  Visible(rows.lure, known and hasPole)

  -- Bags: only when (almost) full
  local free = ns.FreeBagSlots()
  local low = hasPole and free and free <= BAGS_LOW
  Visible(rows.bags, low and true or false)
  if low then
    KV(rows.bags, L["Bags"], free == 0 and L["full"] or L["%d free"]:format(free), free == 0 and "critical" or "warning")
  end

  -- Next trainer milestone
  local m = known and ns.MILESTONES[maxRank]
  local showM = m and rank >= m.from and true or false
  Visible(rows.milestone, showM)
  if showM then Line(rows.milestone, L[m.text], "warning") end

  Visible(headers.fishing, known)
  return rank, modifier, known, hasPole
end

-- 1.16: sections that mean nothing without Fishing learned stay hidden.
local function HideAll(list)
  for _, item in ipairs(list) do Visible(item, false) end
end

local function UpdateSession(known)
  local s = ns.session
  -- Nothing cast yet: one quiet line instead of zeros.
  local empty = s.casts == 0 and s.catches == 0
  -- 1.16: without Fishing learned there is no session to talk about.
  if not known and empty then
    HideAll({ headers.session, rows.sessionEmpty, rows.catches, rows.rate, rows.fishH, rows.value, rows.valueAH, rows.goal })
    return
  end
  Visible(headers.session, true)
  Visible(rows.sessionEmpty, empty)
  if empty then Line(rows.sessionEmpty, L["No casts yet in this session."], "textHint") end
  Visible(rows.catches, not empty)
  Visible(rows.value, not empty)
  KV(rows.catches, L["Catches"], Style.Number(s.catches))
  Visible(rows.rate, s.casts > 0)
  if s.casts > 0 then KV(rows.rate, L["Catch rate"], Style.Percent(s.catches / s.casts)) end
  local fishH = ns.PerHour(s.fish)
  Visible(rows.fishH, fishH and true or false)
  if fishH then KV(rows.fishH, L["Fish/h"], Style.Number(fishH)) end
  KV(rows.value, L["Value"], ns.Money(ns.SessionValue()))
  -- (1.0) auction value: only with Auctionator; the items without a price are said, not counted as zero
  local showAH = false
  if not empty and ns.AuctionPricesOn() then
    local ah, priced, missing = ns.SessionValueAH()
    if priced > 0 then
      showAH = true
      local text = ns.Money(ah)
      if missing > 0 then text = text .. " " .. Style.Colorize(L["(%d without price)"]:format(missing), "textHint") end
      KV(rows.valueAH, L["Auction value"], text)
    elseif missing > 0 then
      showAH = true
      KV(rows.valueAH, L["Auction value"], L["no prices yet"], "textHint")
    end
  end
  Visible(rows.valueAH, showAH)

  -- Catch goal with bar
  local progress, goal, goalItem = ns.GoalProgress()
  Visible(rows.goal, progress and true or false)
  if progress then
    local what = goalItem and L["%s in bags"]:format(ns.GetItemInfo(goalItem) or ("item:" .. goalItem)) or L["fish"]
    local done = progress >= goal
    KV(rows.goal, L["Goal"], ("%d / %d %s"):format(math.min(progress, goal), goal, what), done and "good" or "textPrimary")
    SetBar(bars.goal, progress / goal, done and "good" or "accent")
  end
end

local function UpdateZone(rank, modifier, known)
  if not known then
    HideAll({ headers.zone, rows.zone, rows.zoneParts, rows.zoneGetaways })
    return
  end
  Visible(headers.zone, true)
  Visible(rows.zone, true)
  local total = rank + modifier
  local mapID, need, partsNeed = ns.ZoneRequirement()
  local zoneName = ZoneName(mapID) or L["Zone"]
  if need then
    KV(rows.zone, zoneName, L["min. skill %d"]:format(need), total >= need and "good" or "critical")
  else
    local sneed = ns.SharedZoneSkill and ns.SharedZoneSkill(mapID) -- (1.0.1) reported by other players
    if sneed then
      KV(rows.zone, zoneName, L["min. skill %d (reported)"]:format(sneed), total >= sneed and "good" or "critical")
    else
      KV(rows.zone, zoneName, L["unknown"], "textHint")
    end
  end
  local parts = need and partsNeed and total < partsNeed
  Visible(rows.zoneParts, parts and true or false)
  if parts then KV(rows.zoneParts, L["Parts of the zone"], L["min. skill %d"]:format(partsNeed), "warning") end
  local z = mapID and ns.db.zones[mapID]
  local showAway = z and (z.casts or 0) >= 10
  Visible(rows.zoneGetaways, showAway and true or false)
  if showAway then KV(rows.zoneGetaways, L["Got away"], Style.Percent((z.getaways or 0) / z.casts)) end
end

local function UpdateCamp(rank, known)
  local timers = ns.CampTimers()
  local any = false
  for i, row in ipairs(rows.camp) do
    local t = timers[i]
    Visible(row, t and true or false)
    if t then
      any = true
      KV(row, t.label, ns.Duration(t.left), t.left < LURE_LOW and "warning" or "textPrimary")
    end
  end
  -- Next camp object (base skill counts, not the lure bonus)
  local label, skill
  if known then label, skill = ns.NextCampUnlock(rank) end
  Visible(rows.campNext, label and true or false)
  if label then
    any = true
    KV(rows.campNext, L["Next: %s"]:format(L[label]), L["from skill %d"]:format(skill), "textHint")
  end
  Visible(headers.camp, any)
end

local function UpdateDerby(known)
  local state, seconds
  if ns.db.derby and known then state, seconds = ns.DerbyState() end
  local running = state == "running"
  local soon = state == "upcoming" and seconds < 86400
  Visible(rows.derby, running or soon)
  Visible(rows.tasty, running)
  Visible(headers.derby, running or soon)
  -- 1.16: the time comes from the client data (same as Classic); Blizzard has not announced it.
  -- A time set with /ld derby is the player's own and needs no hint.
  local _, _, _, custom = ns.DerbySchedule()
  local unconfirmed = (running or soon) and not custom and not ns.DERBY.announced
  Visible(rows.derbySource, unconfirmed)
  if unconfirmed then Line(rows.derbySource, L["Time from the game data, not confirmed for Forever."], "textHint") end
  if running then
    KV(rows.derby, L["Ends in"], ns.Duration(seconds))
    local tasty, needed = ns.ItemCount(ns.DERBY.fish), ns.DERBY.needed
    local color = tasty >= needed and "good" or "warning"
    KV(rows.tasty, L["Tastyfish"], ("%d / %d"):format(tasty, needed), color)
    SetBar(bars.tasty, tasty / needed, color)
  elseif soon then
    KV(rows.derby, L["Starts in"], ns.Duration(seconds))
  end
end

-- Why the double-click rests right now (1.14). Without a pole the line above says so.
local PAUSED = { combat = L["in combat"], mounted = L["mounted"], swimming = L["swimming"], flying = L["flying"], taxi = L["flying"], dead = L["dead"] }

local function UpdateNext(known, hasPole)
  local text
  local paused
  if known and hasPole and not ns.conflict and ns.db.easyCast then
    paused = PAUSED[ns.CastPauseReason() or ""]
  end
  if not known then
    text = nil
  elseif not hasPole then
    text = L["No fishing pole equipped."]
  elseif ns.conflict then
    text = L["%s handles the double-click."]:format(ns.conflict)
  elseif not ns.db.easyCast then
    text = L["Double right-click is off (options)."]
  elseif paused then
    text = L["Double-click paused: %s"]:format(paused)
  elseif ns.nextAction == "wait" then
    text = L["Applying lure..."]
  elseif ns.nextAction == "lure" and ns.nextLure then
    text = L["Next click: apply %s"]:format(ns.GetItemInfo(ns.nextLure) or ("item:" .. ns.nextLure))
  elseif ns.lureRenewSkipped then
    -- Another kind of lure runs out: renewing it early would ask to replace the enchant.
    text = L["Next click: cast (new lure once the current one is gone)"]
  else
    text = L["Next click: cast"]
  end
  Visible(rows.next, text and true or false)
  if text then Line(rows.next, text, "textHint") end
end

-- Returns true when the window has something that changes by itself (a ticker is worth it).
local function Refresh()
  local rank, modifier, known, hasPole = UpdateFishing()
  UpdateSession(known)
  UpdateZone(rank, modifier, known)
  UpdateCamp(rank, known)
  UpdateDerby(known)
  UpdateNext(known, hasPole)
  return known or hasPole
end

local function FadeOut()
  if panel:IsShown() and not hiding then
    hiding = true
    panel:FadeOut()
  end
end

-- 1.16: the 1 s update only runs while the window is shown, expanded and has something that
-- changes by itself (Fishing learned or a pole in hand). Otherwise events update it.
local ticker
local busy = true -- last refresh found Fishing learned or a pole
local function SetTicking(on)
  if ticker then ticker:SetActive(on) end
end
function ns.PanelTicking() return ticker ~= nil and ticker:IsActive() end

function ns.UpdatePanel()
  if not panel then return end
  local want = ns.db.showPanel and (forced or not ns.db.panelOnlyWithPole or ns.HasPole())
  if not want then
    FadeOut()
    SetTicking(false)
    return
  end
  -- Collapsed: only the title bar is visible, nothing to update. The same while the whole
  -- interface is hidden (Alt+Z); the next tick after it comes back fills in the values (1.15).
  local hiddenUI = panel:IsShown() and not hiding and panel.IsVisible and panel:IsVisible() == false
  local collapsed = panel:IsCollapsed()
  if not collapsed and not hiddenUI then busy = Refresh() and true or false end
  SetTicking(not collapsed and (busy or hiddenUI))
  if hiding or not panel:IsShown() then
    hiding = false
    panel:FadeIn()
  end
end

-- Option "Show window" changed (1.15): the options decide again, a window shown with /ld
-- no longer ignores "Only with fishing pole".
function ns.PanelOptionChanged()
  forced = false
  ns.UpdatePanel()
end

-- show: nil toggles, true/false sets.
function ns.TogglePanel(show)
  if show == nil then show = not (panel and panel:IsShown() and not hiding and ns.db.showPanel) end
  if show then
    forced = true
    ns.db.showPanel = true
    ns.UpdatePanel()
  else
    -- Remember the choice; otherwise the 1 s update shows the panel again right away.
    forced = false
    ns.db.showPanel = false
    if panel then FadeOut() end
  end
end
Luredon_TogglePanel = function() ns.Call("panel toggle", ns.TogglePanel) end

function ns.ResetPanelPosition()
  if panel then panel:ResetPosition() else ns.db.panelPos = nil end
end

---------------------------------------------------------------------------
-- 1.17: fishing view (option, off). While the line is out the windows of Luredon itself get
-- smaller ("compact": title bar only) or lose their background ("faded"). Only own frames,
-- through the kit's silent setters (nothing is saved, the player's own settings stay).
-- Not in combat: the combat dimming of the kit does its own thing there. A recast within
-- VIEW_HOLD seconds keeps the view, so the window does not jump with every cast.
---------------------------------------------------------------------------
local VIEW_HOLD = 4
local viewLine = false -- the line is out (or was a moment ago)
local viewToken = 0

local function ViewMode()
  local mode = ns.db and ns.db.fishingView
  if mode == "compact" or mode == "faded" then return mode end
  return "off"
end

function ns.FishingViewActive()
  return viewLine and ViewMode() ~= "off" and not (InCombatLockdown and InCombatLockdown()) or false
end

-- Puts one of Luredon's windows into the view that fits the state now (or back to the
-- player's own settings).
function ns.ApplyFishingView(p)
  if not p then return end
  local mode = ns.FishingViewActive() and ViewMode() or "off"
  local own
  if p == panel then own = ns.db.panelCollapsed else own = ns.db.logCollapsed end
  p:SetCollapsed(mode == "compact" or (own and true or false), true)
  p:SetBackgroundAlpha(mode == "faded" and 0 or ns.db.panelAlpha, true)
end

local function ApplyViewAll()
  ns.ApplyFishingView(panel)
  ns.ApplyFishingView(ns.logPanel)
  ns.UpdatePanel()
end

local function SetViewLine(on)
  if viewLine == on then return end
  viewLine = on
  if ViewMode() ~= "off" then ns.Call("fishing view", ApplyViewAll) end
end
function ns.FishingViewChanged() ns.Call("fishing view", ApplyViewAll) end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if not ns.IsFishingSpell(spellID) then return end
  viewToken = viewToken + 1
  SetViewLine(true)
end)
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  -- Another channel ending leaves the view alone; an unreadable ID counts like the end of ours.
  if ns.Usable(spellID) and not ns.IsFishingSpell(spellID) then return end
  viewToken = viewToken + 1
  local token = viewToken
  C_Timer.After(VIEW_HOLD, ns.Safe("fishing view end", function()
    if token == viewToken then SetViewLine(false) end
  end))
end)
local function ViewEnd()
  viewToken = viewToken + 1
  SetViewLine(false)
end
ns.On("PLAYER_REGEN_DISABLED", ViewEnd)
ns.On("PLAYER_ENTERING_WORLD", ViewEnd)
ns.On("PLAYER_EQUIPMENT_CHANGED", function() if not ns.HasPole() then ViewEnd() end end)
-- The fight is over: the view may only come back with the next cast.
ns.On("PLAYER_REGEN_ENABLED", function() if viewLine then ns.Call("fishing view", ApplyViewAll) end end)

-- Options of the "Appearance" page
function ns.ApplyPanelSettings()
  if not panel then return end
  panel:SetLocked(ns.db.panelLocked, true)
  panel:SetPanelScale(ns.db.panelScale or 1, true)
  panel:SetBackgroundAlpha(ns.db.panelAlpha, true)
  Style.CombatFade(panel, ns.db.combatFade)
  if ns.ApplyLogSettings then ns.ApplyLogSettings() end
  -- A fishing view that is on right now stays on (the options only change the player's own values).
  if ns.FishingViewActive() then ns.ApplyFishingView(panel) ns.ApplyFishingView(ns.logPanel) end
  ns.UpdatePanel()
end

-- Events that can change what the window shows while it does not tick (1.16): pole in or
-- out of the hand, Fishing learned, loading screen, bags. Several in a row cause one update.
local queued = false
local function QueueUpdate()
  -- While the 1 s update runs it picks the change up anyway.
  if queued or not panel or ns.PanelTicking() then return end
  queued = true
  C_Timer.After(0.1, function()
    queued = false
    ns.Call("panel event", ns.UpdatePanel)
  end)
end
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
    "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED" }) do
  ns.On(event, QueueUpdate)
end
ns.OnPlayer("UNIT_INVENTORY_CHANGED", QueueUpdate)

ns.OnInit(function()
  Create()
  ticker = ns.GatedTicker("panel", 1, ns.UpdatePanel)
  ns.UpdatePanel()
end)

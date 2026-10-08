local addonName, ns = ...
local L = ns.L

local category

local function UpdatePanel() if ns.UpdatePanel then ns.UpdatePanel() end end
local function ApplyPanel() if ns.ApplyPanelSettings then ns.ApplyPanelSettings() end end
local function OtherFishingAddon() return ns.conflict end
local function PanelOption() if ns.PanelOptionChanged then ns.PanelOptionChanged() end end

local function QualityOptions()
  return { { "2", L["Uncommon"] }, { "3", L["Rare"] }, { "4", L["Epic"] } }
end

local function GoalLabel(v)
  v = math.floor((v or 0) + 0.5)
  return v <= 0 and L["Off"] or tostring(v)
end

-- 1.17: fishing view; "off" first, it is the default.
local function ViewOptions()
  return { { "off", L["No change"] }, { "compact", L["Compact"] }, { "faded", L["Without background"] } }
end

local function SetOptions()
  local list = { { "", L["None"] } }
  for _, name in ipairs(ns.GetEquipmentSetNames()) do list[#list + 1] = { name, name } end
  return list
end

local PAGES = {
  { title = "Casting and lures", tip = "Double-click casting, automatic lures and warnings.", items = {
    { header = "Casting" },
    { key = "easyCast", name = "Double right-click to fish", tip = "With a fishing pole equipped, double right-click into the world to cast. Also available as a key binding (Key Bindings > AddOns). Pauses in combat, while mounted, swimming or flying.", blockedBy = OtherFishingAddon },
    { key = "autoLure", name = "Apply lure first", tip = "If the pole has no lure, the click or key binding applies the best lure your skill allows. A lure of the same kind is renewed when it runs out within 20 seconds. The next click casts.", onChange = function()
      if ns.QueuePrepare then ns.QueuePrepare() end
    end },
    { header = "Window" },
    { key = "fishingView", kind = "dropdown", name = "Windows while fishing", tip = "While the line is out, Luredon's own windows shrink to the title bar (Compact) or lose their background (Without background). They return a few seconds after the line comes in and in combat. Only Luredon's windows are touched, never the game's interface.", options = ViewOptions, onChange = function()
      if ns.FishingViewChanged then ns.FishingViewChanged() end
    end },
    { key = "hideUI", name = "Hide the interface while fishing", tip = "When the line goes out, the whole game interface hides, like Alt+Z. Your catches show at the top of the screen. It comes back when you move, a fight starts, you change the target, get a whisper or the loot window opens.", onChange = function()
      if ns.ApplyHideUI then ns.ApplyHideUI() end
    end },
    { header = "Warnings" },
    { key = "lureWarning", name = "Warn when casting without lure", tip = "Shows a warning on the first two casts without a lure in a row, so fishing without one on purpose stays quiet." },
    { key = "bagWarning", name = "Warn when bags are full", tip = "Shows a warning when you cast with full or almost full bags (2 free slots or less)." },
  } },
  { title = "Splash", tip = "Louder splashes and interact range.", items = {
    { header = "Sound" },
    { key = "sounds", name = "Louder splashes", tip = "While a pole is equipped, sound effects play at full volume and music and ambience are muted. Your settings come back afterwards.", blockedBy = OtherFishingAddon, onChange = function() if ns.UpdateSounds then ns.UpdateSounds() end end },
    { key = "bgSound", name = "Also in the background", tip = "While a pole is equipped, the game keeps playing sound when another window has the focus, so you hear the splash while you are tabbed out. Your setting comes back afterwards.", parent = "sounds", blockedBy = OtherFishingAddon, onChange = function() if ns.RefreshSounds then ns.RefreshSounds() end end },
    { header = "Hooking" },
    { key = "softInteract", name = "Longer interact range while fishing", tip = "Raises the soft interact range while the line is out, so the interact key can hook the bobber. The range may be capped by the client." },
  } },
  { title = "Gear and tracking", tip = "Equipment sets and Find Fish.", items = {
    { header = "Equipment sets" },
    { key = "fishingSet", kind = "dropdown", name = "Fishing equipment set", tip = "Equipment set with your fishing gear.", options = SetOptions },
    { key = "normalSet", kind = "dropdown", name = "Normal equipment set", tip = "Equipment set you switch back to.", options = SetOptions },
    { header = "Tracking" },
    { key = "findFish", name = "Track fish automatically", tip = "Switches on Find Fish minimap tracking when you equip a pole (if you know it).", onChange = function()
      if ns.db.findFish and ns.HasPole() then ns.EnableFindFish() end
    end },
  } },
  -- 1.14: the rare catch alert moved here from "Splash" (it is about catches, not about sound).
  { title = "Session and goal", tip = "Session summary, rare catch alert, catch goal and the Fishing Extravaganza timer.", items = {
    { header = "Chat" },
    { key = "sessionSummary", name = "Session summary in chat", tip = "When you take off your fishing pole, a short summary of the session appears in chat (casts, catches, getaways, value)." },
    { key = "auctionPrices", name = "Auction prices (Auctionator)", tip = "With Auctionator installed, the session shows the value at auction prices next to the vendor value (per hour in the tooltip), the catch log shows the price of each fish and the chat summary adds it. Only items with a scanned price are counted. Without Auctionator this does nothing.", onChange = function() ns.UpdatePanel() end },
    { header = "Alerts" },
    { key = "shareData", name = "Share fishing data with guild and group", tip = "Sends your catches per zone, casts and getaways by skill and casts per skill point (only numbers, no names) to Luredon players in your guild and group. With their data the zone window shows catches where you have not fished yet and the skill a new zone needs. Shared data is used also when this is off." },
    { key = "rareAlert", name = "Alert for rare catches", tip = "Chat line and a sound when you catch an item of the chosen quality or better (for example camp fish, chests, pets)." },
    { key = "rareQuality", kind = "dropdown", name = "Alert from quality", tip = "Lowest item quality for the rare catch alert.", parent = "rareAlert", options = QualityOptions },
    { header = "Goal" },
    { key = "goalCount", kind = "slider", name = "Catch goal", tip = "Number of fish for this session (junk does not count); the panel shows the progress, and a sound plays when you reach it. 0 switches the goal off. For one item in the bags: /ld goal <number> <item link>.", min = 0, max = 500, step = 5, format = GoalLabel, onChange = function()
      ns.db.goalItem = 0
      if ns.ResetGoalBaseline then ns.ResetGoalBaseline() end
      UpdatePanel()
    end },
    { header = "Events" },
    { key = "derby", name = "Fishing Extravaganza timer", tip = "Countdown to the Stranglethorn Fishing Extravaganza (Sunday 14-16 realm time as in Classic and in the game data, not confirmed for Forever; change it with /ld derby <day> <hour>), Tastyfish counter and an alert once you have 40.", onChange = UpdatePanel },
  } },
  -- Same page, same names in every addon with a window (DESIGN.md).
  { title = "Appearance", tip = "Window: show, lock, size, background opacity, dim in combat.", items = {
    { header = "Window" },
    { key = "showPanel", name = "Show window", tip = "Skill, lure, session, zone check, camp and contest timers. Drag the title bar to move it. Hover over a session or zone line for details.", onChange = PanelOption },
    { key = "panelOnlyWithPole", name = "Only with fishing pole", tip = "Shows the window only while a fishing pole is equipped.", parent = "showPanel", onChange = PanelOption },
    { key = "panelLocked", name = "Lock window", tip = "The window can no longer be dragged.", onChange = ApplyPanel },
    { key = "panelScale", kind = "slider", name = "Size", tip = "Size of the window.", min = 0.6, max = 1.6, step = 0.05, onChange = ApplyPanel },
    { key = "panelAlpha", kind = "slider", name = "Background opacity", tip = "How opaque the window background is. Text stays fully visible.", min = 0, max = 1, step = 0.05, onChange = ApplyPanel },
    { key = "combatFade", name = "Dim in combat", tip = "Dims the whole window to 40 % while you are in combat.", onChange = ApplyPanel },
    -- 1.15: same place as in the other addons (DESIGN.md); the start page keeps its tool.
    { kind = "button", name = "Reset position", button = "Reset", tip = "Puts the window back to its default place.", onClick = function()
      if ns.ResetPanelPosition then ns.ResetPanelPosition() end
    end },
  } },
}

local function Status()
  local lines = {}
  local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
  if version then lines[#lines + 1] = L["Version %s"]:format(version) end
  local life = ns.db.lifetime or {}
  -- Built once per login (Blizzard's settings list has no refresh for these lines), so it says so.
  lines[#lines + 1] = L["All time at login: %d casts, %d fish, %d got away"]:format(life.casts or 0, life.fish or 0, life.getaways or 0)
  if ns.conflict then
    lines[#lines + 1] = L["%s is loaded: double-click casting and sounds are left to it."]:format(ns.conflict)
  end
  lines[#lines + 1] = L["/ld help lists the chat commands."]
  return lines
end

local TOOLS = {
  { "Toggle fishing gear", "Switch", function() ns.ToggleGear() end, "Switches between your fishing set and your normal set." },
  { "Reset session", "Reset", function() ns.ResetSession() UpdatePanel() end, "Starts the session statistics from zero." },
  { "Reset position", "Reset", function() ns.ResetPanelPosition() end, "Puts the window back to its default place." },
  { "Zones for your skill", "Show", function() ns.PrintBestZones() end, "Lists in chat the zones where nothing gets away with your skill (incl. lure and gear) and the next tier." },
  { "Fishing book", "Show", function() ns.OpenBook("log") end, "Opens the fishing book: your sessions, every kind of fish (caught and still missing) and every zone with the skill it needs. /ld book" },
  { "Export catch log", "Show", function() ns.ShowLogExport() end, "Shows the catch log as text to copy. Contains no character or realm names." },
  { "Delete catch log", "Delete", function()
      if ns.Confirm("log", L["Click again within 5 seconds to delete the catch log."]) then
        if ns.LogReset() then ns.Print(L["Catch log deleted."]) else ns.Print(L["The log comes from a newer Luredon version and stays unchanged."]) end
      end
    end, "Deletes the catch log (kinds, counts, records). The fishing statistics stay." },
  { "Export catch data", "Show", function() ns.ShowExport() end, "Shows your catches per zone as text to copy, for example to share fishing data. Contains no character or realm names." },
  { "Diagnostics", "Show", function() ns.ShowDiag() end, "Shows a technical report to copy (versions, API checks, recent decisions and errors) for troubleshooting. Contains no character or realm names." },
  { "Delete fishing statistics", "Delete", function()
      if ns.Confirm("stats", L["Click again within 5 seconds to delete all fishing statistics."]) then
        wipe(ns.db.zones) wipe(ns.db.catches)
        ns.db.lifetime = { casts = 0, fish = 0, getaways = 0 }
        ns.ResetSkillData()
        if type(ns.db.tempo) == "table" then wipe(ns.db.tempo) end
        if ns.ResetShared then ns.ResetShared() end
        ns.Print(L["Fishing statistics deleted."])
      end
    end, "Deletes catches per zone, all-time numbers and skill-up history." },
}

-- 1.14: option changes and tools run protected; an error lands in /ld diag, not in Blizzard's settings code.
for _, page in ipairs(PAGES) do
  for _, item in ipairs(page.items) do
    if item.onChange then item.onChange = ns.Safe("option " .. item.key, item.onChange) end
  end
end
for _, t in ipairs(TOOLS) do t[3] = ns.Safe("tool " .. t[1], t[3]) end

local function Build()
  category = ns.BuildSettings({ name = "Luredon", status = Status, tools = TOOLS, pages = PAGES })
end

-- 1.14: /ld help, one short line per command.
local HELP = {
  { "/ld", L["show / hide the window"] },
  { "/ld options", L["options"] },
  { "/ld zones", L["zones for your skill"] },
  { L["/ld goal <number> [item] | off"], L["catch goal"] },
  { "/ld gear", L["switch fishing gear"] },
  { L["/ld set fishing|normal <set>"], L["choose the equipment sets"] },
  { "/ld reset", L["new session"] },
  { "/ld resetpos", L["window back to its place"] },
  { "/ld camp rack|hut", L["start a camp timer by hand"] },
  { L["/ld derby <day> <hour> | reset"], L["Fishing Extravaganza start (realm time)"] },
  { "/ld book", L["fishing book (logbook, fish atlas, waters)"] },
  { L["/ld log [export]"], L["fish atlas, catch log export"] },
  { "/ld export", L["catch data to copy"] },
  { "/ld diag", L["report for troubleshooting"] },
}
function ns.PrintHelp()
  ns.Report(L["Commands"], "")
  for _, h in ipairs(HELP) do
    ns.Print(("|cffffffff%s|r  |cff9ea3ad%s|r"):format(h[1], h[2]))
  end
end

function ns.OpenOptions()
  if InCombatLockdown() then ns.Print(L["Not possible in combat."]) return end
  if category and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  else
    ns.PrintHelp()
  end
end

ns.OnInit(Build)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_LUREDON1 = "/ld"
SLASH_LUREDON2 = "/luredon"
-- /ld goal 100 | /ld goal 20 [Item link] | /ld goal 20 12345 | /ld goal off
local function SlashGoal(rest)
  local count, itemText = rest:match("^(%d+)%s*(.-)$")
  if rest:lower() == "off" or count == "0" then
    ns.SetGoal(0)
    ns.Print(L["Catch goal off."])
  elseif count then
    local item
    if itemText ~= "" then
      item = ns.ItemID(itemText:match("|H(item:[%d:%-]+)") or itemText) or tonumber(itemText)
      if not item then ns.Print(L["Usage: /ld goal <number> [item link], /ld goal off"]) return end
    end
    ns.SetGoal(tonumber(count), item)
    local what = item and (select(2, ns.GetItemInfo(item)) or ("item:" .. item)) or L["fish"]
    ns.Print(L["Catch goal: %d %s"]:format(ns.db.goalCount, what))
  else
    local progress, goal, goalItem = ns.GoalProgress()
    if progress then
      local what = goalItem and (select(2, ns.GetItemInfo(goalItem)) or ("item:" .. goalItem)) or L["fish"]
      ns.Print(L["Goal: %d/%d %s"]:format(math.min(progress, goal), goal, what))
    end
    ns.Print(L["Usage: /ld goal <number> [item link], /ld goal off"])
  end
  UpdatePanel()
end

local WEEKDAYS = { L["Sunday"], L["Monday"], L["Tuesday"], L["Wednesday"], L["Thursday"], L["Friday"], L["Saturday"] }

-- /ld derby sun 14 | /ld derby 1 14 | /ld derby reset
local function SlashDerby(rest)
  local dayText, hourText = rest:match("^(%S+)%s+(%d+)$")
  local day, hour = ns.ParseWeekday(dayText), tonumber(hourText)
  if rest:lower() == "reset" then
    ns.db.derbyDay = 0
  elseif day and hour and hour >= 0 and hour <= 23 then
    ns.db.derbyDay, ns.db.derbyHour = day, hour
  else
    ns.Print(L["Usage: /ld derby <day> <hour> (realm time, e.g. /ld derby sun 14), /ld derby reset"])
    return
  end
  local weekday, startHour, endHour, custom = ns.DerbySchedule()
  ns.Print(L["Fishing Extravaganza: %s %d:00-%d:00 realm time%s"]:format(WEEKDAYS[weekday],
    startHour, endHour % 24, custom and "" or (" " .. L["(game data, unconfirmed)"])))
  UpdatePanel()
end

local function Slash(msg)
  msg = strtrim(msg or "")
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    ns.TogglePanel()
  elseif cmd == "options" or cmd == "config" then
    ns.OpenOptions()
  elseif cmd == "gear" then
    ns.ToggleGear()
  elseif cmd == "reset" then
    ns.ResetSession()
    ns.Print(L["Session reset."])
  elseif cmd == "resetpos" then
    ns.ResetPanelPosition()
    ns.Print(L["Panel position reset."])
  elseif cmd == "set" then
    local which, name = rest:match("^(%S+)%s*(.-)$")
    which = which and which:lower()
    if which == "fishing" or which == "normal" then
      ns.db[which .. "Set"] = name or ""
      local label = which == "fishing" and L["Fishing equipment set"] or L["Normal equipment set"]
      ns.Print(("%s: %s"):format(label, name ~= "" and name or L["None"]))
    else
      ns.Print(L["Usage: /ld set fishing|normal <equipment set>"])
    end
  elseif cmd == "goal" then
    SlashGoal(rest)
  elseif cmd == "derby" then
    SlashDerby(rest)
  elseif cmd == "book" then
    ns.ToggleBook()
  elseif cmd == "atlas" then
    ns.ToggleBook("atlas")
  elseif cmd == "waters" then
    ns.ToggleBook("waters")
  elseif cmd == "log" then
    if rest:lower() == "export" then ns.ShowLogExport() else ns.ToggleLog() end
  elseif cmd == "export" then
    ns.ShowExport()
  elseif cmd == "diag" then
    ns.ShowDiag()
  elseif cmd == "debug" then
    ns.ToggleDebug()
  elseif cmd == "camp" then
    if ns.CAMP[rest:lower()] then
      ns.StartCampTimer(rest:lower())
      ns.UpdatePanel()
    else
      ns.Print(L["Usage: /ld camp rack|hut"])
    end
  elseif cmd == "zones" or cmd == "zone" then
    ns.PrintBestZones()
  elseif cmd == "help" or cmd == "?" then
    ns.PrintHelp()
  else
    ns.Print(L["Unknown command. /ld help lists the commands."])
  end
end
SlashCmdList.LUREDON = function(msg) ns.Call("slash", Slash, msg) end

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (04.11.2026, Era-Test, Daniel: "jeder minimap button sollte doch einen goldenen ring bekommen"; decided 04.11. "Alle mit
-- Fenster": Luredon gets its own button too, the fishing book behind it, switched off in the options like every Don button)
--   Left click   fishing book
--   Right click  a small menu like Questdon's (04.11.2026, Era-Test, Daniel: "bei questdon kommt mit rechtsklick so ein menü,
--                das hätte ich bei den anderen auch gerne"): fishing book, small window, a line, the most used switches as
--                check rows, a line, all options; DonCore adds a line and "Hide minimap button" at the end (minor 4)
--   Drag         moves the button around the minimap (angle saved in ns.db.minimapAngle, default 150)
--   Mouse over   the fishing skill
-- The button, its gold ring, the menu frame and the option come from DonCore (Libs\DonCore\MinimapButton.lua, minor 4); here
-- only what is Luredon's: the symbol, the tooltip line, the clicks and the menu's rows. No ticker, no events: the tooltip
-- reads the skill when shown, the menu its switches when it opens or a row is clicked.
---------------------------------------------------------------------------

local function SkillLines()
  local ok, rank, maxRank = pcall(ns.GetSkill)
  if not ok or type(rank) ~= "number" or rank <= 0 then return nil end
  if type(maxRank) == "number" and maxRank > 0 then
    return { { L["Fishing skill %d / %d"]:format(rank, maxRank) } }
  end
  return { { L["Fishing skill %d"]:format(rank) } }
end

-- (04.11.2026, Era-Test) the switches of the menu: real on/off options of Options.lua with an effect right away. A click
-- does what the options window does: flips ns.db[key], runs the option's onChange (ns.OptionItem, Options.lua) and
-- refreshes the settings. An option locked by another fishing addon (blockedBy) stays as it is and says why.
local function Label(key)
  if key == "interactCast" then return L["Interact key casts"] end
  if key == "softInteract" then return L["Longer interact range while fishing"] end
  if key == "hideUI" then return L["Hide the interface while fishing"] end
  if key == "sounds" then return L["Louder splashes"] end
  if key == "combatFade" then return L["Dim the window in combat"] end
  return key
end
local SWITCHES = { "interactCast", "softInteract", "hideUI", "sounds", "combatFade" }
ns.MINIMAP_SWITCHES = SWITCHES -- (tests)

local function Item(key) return ns.OptionItem and ns.OptionItem(key) end

local function Toggle(key)
  if type(ns.db) ~= "table" then return end
  local item = Item(key)
  if item and item.blockedBy and item.blockedBy() then
    if ns.conflict then ns.Print(L["%s is loaded: double-click casting and sounds are left to it."]:format(ns.conflict)) end
    return
  end
  ns.db[key] = not ns.db[key]
  if item and item.onChange then item.onChange(ns.db[key]) end -- already behind ns.Safe (Options.lua)
  if ns.RefreshSettingsUI then ns.Call("minimap menu", ns.RefreshSettingsUI) end
end
ns.MinimapMenuToggle = function(i) local key = SWITCHES[i] if key then Toggle(key) end end -- (tests)

-- the menu's rows: fishing book, small window, a line, the switches (check rows), a line, all options
local function MenuItems()
  local items = {
    { text = L["Fishing book"], onClick = function() if ns.ToggleBook then ns.ToggleBook() end end },
    { text = L["Small window"], onClick = function() if ns.TogglePanel then ns.TogglePanel() end end },
    { line = true },
  }
  for _, key in ipairs(SWITCHES) do
    items[#items + 1] = { text = Label(key), onClick = function() Toggle(key) end,
      isOn = function() return ns.db and ns.db[key] and true or false end }
  end
  items[#items + 1] = { line = true }
  items[#items + 1] = { text = L["All options"], onClick = function() if ns.OpenOptions then ns.OpenOptions() end end }
  return items
end

LibStub("DonCore-1.0"):Get("MinimapButton", 4):Attach(ns, {
  name = "LuredonMinimapButton",
  icon = "Interface\\AddOns\\Luredon\\Media\\minimap",
  addon = "Luredon",
  angleKey = "minimapAngle",
  defaultAngle = 150,
  title = "|cff3fa9f5Lure|rdon",
  lines = SkillLines,
  hint = function() return L["Left click: fishing book. Right click: menu. Drag: move the button."] end,
  onLeft = function() if ns.ToggleBook then ns.ToggleBook() end end,
  menu = { name = "LuredonMinimapMenu", width = 290, items = MenuItems },
})

ns.OnInit(function() ns.Call("minimap button", ns.RefreshMinimapButton) end)

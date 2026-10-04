local _, ns = ...
local L = ns.L

local function FindSet(name)
  if not (name and name ~= "" and C_EquipmentSet) then return nil end
  if C_EquipmentSet.GetEquipmentSetID then
    local ok, id = pcall(C_EquipmentSet.GetEquipmentSetID, name)
    if ok and ns.Usable(id) then return id end
  end
end

function ns.GetEquipmentSetNames()
  local names = {}
  if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetInfo then
    local ok, ids = pcall(C_EquipmentSet.GetEquipmentSetIDs)
    if ok and ns.Usable(ids) and type(ids) == "table" then
      for _, id in ipairs(ids) do
        local okN, name = pcall(C_EquipmentSet.GetEquipmentSetInfo, id)
        if okN and ns.Usable(name) and type(name) == "string" and name ~= "" then names[#names + 1] = name end
      end
    end
  end
  table.sort(names)
  return names
end

function ns.ToggleGear()
  if InCombatLockdown() then
    ns.Print(L["Not possible in combat."])
    return
  end
  local target = ns.HasPole() and ns.db.normalSet or ns.db.fishingSet
  local id = FindSet(target)
  if not id then
    ns.Print(L["Choose your equipment sets in the options first (/ld options)."])
    return
  end
  C_EquipmentSet.UseEquipmentSet(id)
end
Luredon_ToggleGear = function() ns.Call("gear", ns.ToggleGear) end

---------------------------------------------------------------------------
-- Find Fish tracking: switch it on when a pole is equipped
---------------------------------------------------------------------------
-- Secret parts come back as nil (name, spellID) or false (active), so comparisons stay safe.
local function TrackingInfo(i)
  local ok, a, b, c, d, e, f = pcall(C_Minimap.GetTrackingInfo, i)
  if not ok or not ns.Usable(a) then return nil end
  local name, active, spellID
  if type(a) == "table" then
    name, active, spellID = a.name, a.active, a.spellID
  else
    -- older multi-value form: name, texture, active, category, nested, spellID
    name, active, spellID = a, c, f
  end
  if not (ns.Usable(name) and type(name) == "string") then name = nil end
  if not (ns.Usable(spellID) and type(spellID) == "number") then spellID = nil end
  active = ns.Usable(active) and active and true or false
  return name, active, spellID
end

local function TrackingCount()
  local ok, n = pcall(C_Minimap.GetNumTrackingTypes)
  return ok and ns.Usable(n) and type(n) == "number" and n or 0
end

-- Identifies a tracking type independent of its list position: spell ID, else name.
local function TrackingKey(name, spellID)
  if ns.Usable(spellID) and type(spellID) == "number" and spellID > 0 then return "spell:" .. spellID end
  if ns.Usable(name) and type(name) == "string" then return "name:" .. name end
end

local function ActiveTracking()
  local list = {}
  for i = 1, TrackingCount() do
    local name, active, spellID = TrackingInfo(i)
    if ns.Usable(active) and active then
      local key = TrackingKey(name, spellID)
      if key then list[key] = i end
    end
  end
  return list
end

local findFishPending -- pole put on in combat: switch Find Fish on afterwards

-- Classic allows one "Find ..." tracking at a time: switching Find Fish on turns off e.g. Find
-- Herbs. Luredon remembers what went off and switches it back on when the pole is put away.
function ns.EnableFindFish()
  if not (ns.db.findFish and C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.SetTracking) then return end
  if InCombatLockdown() then findFishPending = true return end
  findFishPending = nil
  local wanted = ns.SpellName(ns.FIND_FISH_SPELL)
  if not (ns.Usable(wanted) and type(wanted) == "string") then wanted = nil end
  for i = 1, TrackingCount() do
    local name, active, spellID = TrackingInfo(i)
    if spellID == ns.FIND_FISH_SPELL or (wanted and name == wanted) then
      if not active then
        local before = ActiveTracking()
        if not pcall(C_Minimap.SetTracking, i, true) then return false end
        local after = ActiveTracking()
        local lost = {}
        for key in pairs(before) do if not after[key] then lost[#lost + 1] = key end end
        if #lost > 0 then
          table.sort(lost)
          ns.db.savedTracking = lost
        end
      end
      return true
    end
  end
  return false
end

-- Pole put away: the tracking that Find Fish replaced comes back (once; then it is forgotten).
function ns.RestoreTracking()
  local saved = ns.db.savedTracking
  if not saved or InCombatLockdown() or not (C_Minimap and C_Minimap.SetTracking) then return end
  ns.db.savedTracking = nil
  -- Changed the tracking by hand meanwhile (Find Fish is off): leave the choice alone.
  local fishName = ns.SpellName(ns.FIND_FISH_SPELL)
  if not (ns.Usable(fishName) and type(fishName) == "string") then fishName = nil end
  local fishActive = false
  for i = 1, TrackingCount() do
    local name, active, spellID = TrackingInfo(i)
    if (spellID == ns.FIND_FISH_SPELL or (fishName and name == fishName)) and ns.Usable(active) and active then
      fishActive = true
    end
  end
  if not fishActive then return end
  local wanted = {}
  for _, key in ipairs(saved) do wanted[key] = true end
  for i = 1, TrackingCount() do
    local name, active, spellID = TrackingInfo(i)
    local key = TrackingKey(name, spellID)
    if key and wanted[key] and not active then
      pcall(C_Minimap.SetTracking, i, true)
      return true -- one find tracking at a time
    end
  end
end

ns.On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
  if slot ~= (INVSLOT_MAINHAND or 16) then return end
  if ns.HasPole() then
    ns.EnableFindFish()
  else
    ns.RestoreTracking()
  end
end)
-- Pole put away in combat: restore once combat is over (if the pole is still away).
ns.On("PLAYER_REGEN_ENABLED", function()
  if ns.HasPole() then
    if findFishPending then ns.EnableFindFish() end
  else
    findFishPending = nil
    if ns.db.savedTracking then ns.RestoreTracking() end
  end
end)

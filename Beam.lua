local _, ns = ...

---------------------------------------------------------------------------
-- (26.11.2026) Light beam on the bobber. Daniel 26.11.: a light beam above
-- the bobber, as in a fishing video. The bite itself gives addons no event
-- (see Cursor.lua), so the beam marks the bobber while the line is out.
--
-- An addon cannot draw in the 3D world. It hangs its textures on a frame the
-- game places there: the name plate of the soft interact target. Found with
-- "/ld beamtest" in five rounds on 26.11. (Daniel's tests in Tanaris):
--   - the plate needs SoftTargetNameplateInteract and SoftTargetIconGameObject,
--     the target itself SoftTargetIconInteract; while the line is out Luredon
--     sets the three and puts the player's values back when it comes in (the
--     copy lives in LuredonDB.savedBeam like savedSoft in Sound.lua, so a
--     /reload or logout with the line out restores them at the next login);
--   - the game's gear icon sits on that plate (SoftTargetFrame.Icon, texture
--     Cursor\Crosshair_Interact_64); Luredon gives it alpha 0 while the beam
--     stands and its alpha back afterwards (Daniel: "das Rad mittendrin
--     wegmachen");
--   - the plate also comes for NPCs: the beam only stands on the bobber;
--   - look: soft textures (Media/BeamGlow.tga, BeamBase.tga from
--     tools/luredon_beam_tga.py), a thin core in a golden halo, a glow at the
--     foot 45 UI units below the plate's centre, fade in; softer after
--     "noch ein bisschen zu grell";
--   - Cursor.lua leaves its pointer bobber out while the beam stands.
-- Option "Light beam on the bobber" (Sound and hooking), on from the start
-- (Daniel 26.11.: "Ja, ab Werk an").
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Luredon\\Media\\"
local CVARS = {
  SoftTargetNameplateInteract = "1",
  SoftTargetIconInteract = "1",
  SoftTargetIconGameObject = "1",
}
ns.BEAM_CVARS = CVARS -- (tests)
local HEIGHT = 320
local DROP = 45 -- foot of the beam below the plate's centre (Daniel 26.11.: fits)
local LAYERS = { -- width, r, g, b, alpha (BeamGlow is soft across, so the visible line is narrower)
  { 110, 1.00, 0.75, 0.30, 0.10 }, -- haze
  { 36, 1.00, 0.82, 0.40, 0.30 },  -- golden halo
  { 8, 1.00, 0.95, 0.80, 0.60 },   -- bright core
}
local FADE_IN = 0.25
local GEAR_HINTS = { "softtarget", "crosshair_interact" }

local beam, shownAt
local hidden = {} -- gear texture -> its alpha before

---------------------------------------------------------------------------
-- CVars while the line is out
---------------------------------------------------------------------------
local function SetCVars()
  if ns.db.savedBeam then return end
  local saved = {}
  for cvar, value in pairs(CVARS) do
    local current = GetCVar and GetCVar(cvar)
    if current ~= nil and pcall(SetCVar, cvar, value) then saved[cvar] = current end
  end
  ns.db.savedBeam = saved
end

local function RestoreCVars()
  local saved = ns.db and ns.db.savedBeam
  if not saved then return end
  for cvar, value in pairs(saved) do pcall(SetCVar, cvar, value) end
  ns.db.savedBeam = nil
end

---------------------------------------------------------------------------
-- The beam
---------------------------------------------------------------------------
local function Glow(file, layer, sub, w, h, r, g, b, a)
  local t = beam:CreateTexture(nil, layer, nil, sub)
  t:SetTexture(MEDIA .. file)
  t:SetBlendMode("ADD")
  t:SetSize(w, h)
  t:SetVertexColor(r, g, b, a)
  return t
end

local function Build()
  if beam then return end
  beam = CreateFrame("Frame", "LuredonBeam", WorldFrame)
  beam:SetSize(LAYERS[1][1], HEIGHT)
  beam:SetFrameStrata("BACKGROUND")
  for i, l in ipairs(LAYERS) do
    Glow("BeamGlow", "ARTWORK", i, l[1], HEIGHT, l[2], l[3], l[4], l[5]):SetPoint("BOTTOM")
  end
  -- the foot: a wide golden glow and a small bright one on the bobber
  Glow("BeamBase", "OVERLAY", 1, 70, 34, 1.00, 0.78, 0.35, 0.40):SetPoint("CENTER", beam, "BOTTOM", 0, 4)
  Glow("BeamBase", "OVERLAY", 2, 20, 12, 1.00, 0.95, 0.85, 0.55):SetPoint("CENTER", beam, "BOTTOM", 0, 4)
  beam:Hide()
  -- the fade in runs every frame while the beam shows
  beam:SetScript("OnUpdate", function(self)
    if not shownAt then return end
    local a = (GetTime() - shownAt) / FADE_IN
    if a >= 1 then self:SetAlpha(1) shownAt = nil else self:SetAlpha(a) end
  end)
end

---------------------------------------------------------------------------
-- The game's gear on the plate (read and alpha only, no hook)
---------------------------------------------------------------------------
local function Speaks(s)
  if type(s) ~= "string" then return false end
  s = s:lower()
  for _, h in ipairs(GEAR_HINTS) do if s:find(h, 1, true) then return true end end
  return false
end

local function KeyIn(parent, obj)
  if type(parent) ~= "table" then return nil end
  for k, v in pairs(parent) do if v == obj and type(k) == "string" then return k end end
  return nil
end

local function Scan(obj, depth, seen)
  if depth > 5 or seen[obj] then return end
  seen[obj] = true
  local objKey = KeyIn(obj.GetParent and obj:GetParent(), obj) or (obj.GetName and obj:GetName())
  local regions = obj.GetRegions and { obj:GetRegions() } or {}
  for _, r in ipairs(regions) do
    if r.GetObjectType and r:GetObjectType() == "Texture" then
      local tex = r.GetTexture and r:GetTexture()
      if Speaks(objKey) or Speaks(KeyIn(obj, r)) or Speaks(tostring(tex)) then
        if hidden[r] == nil then hidden[r] = r:GetAlpha() end
        r:SetAlpha(0)
      end
    end
  end
  local kids = obj.GetChildren and { obj:GetChildren() } or {}
  for _, c in ipairs(kids) do Scan(c, depth + 1, seen) end
end

local function ShowGear()
  for r, a in pairs(hidden) do pcall(r.SetAlpha, r, a) end
  hidden = {}
end

---------------------------------------------------------------------------
-- Update while the line is out
---------------------------------------------------------------------------
local function Hide()
  if beam then beam:Hide() end
  shownAt = nil
  ShowGear()
end

local function Step()
  local plate
  if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, "softinteract")
    plate = ok and p or nil
  end
  local name = plate and UnitName and UnitName("softinteract")
  if not (plate and ns.LineOut() and ns.IsBobberName(name)) then Hide() return end
  pcall(Scan, plate, 1, {})
  Build()
  beam:ClearAllPoints()
  beam:SetPoint("BOTTOM", plate, "CENTER", 0, -DROP)
  if not beam:IsShown() then shownAt = GetTime() beam:SetAlpha(0) beam:Show() end
end

local ticker = ns.GatedTicker("bobber beam", 0.1, Step)

local function Stop()
  ticker:SetActive(false)
  Hide()
  RestoreCVars()
end

local function Start()
  if not (ns.db and ns.db.bobberBeam) then return end
  SetCVars()
  ticker:SetActive(true)
end

-- Still channeling Fishing (a recast whose start came before the old stop): the line stays out.
local function ChannelingFishing()
  if not UnitChannelInfo then return false end
  local ok, _, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
  return ok and ns.IsFishingSpell(spellID) or false
end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if ns.IsFishingSpell(spellID) then Start() end
end)

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  if ns.Usable(spellID) and not ns.IsFishingSpell(spellID) then return end
  if ChannelingFishing() then return end
  Stop()
end)

ns.On("PLAYER_ENTERING_WORLD", Stop)
-- SavedVariables are written after PLAYER_LOGOUT, so restored values stay restored.
ns.On("PLAYER_LOGOUT", Stop)

-- The option changed: off ends it at once, on starts with the next cast.
function ns.UpdateBeam()
  if not (ns.db and ns.db.bobberBeam) then Stop() end
end

-- Cursor.lua hides its pointer bobber while the beam stands
function ns.BeamShown() return beam ~= nil and beam:IsShown() end

function ns.BeamTick() ns.Call("bobber beam", Step) end -- (tests)

-- For the tests and /ld diag.
function ns.BeamState()
  return { active = ticker:IsActive(), shown = ns.BeamShown(), saved = ns.db and ns.db.savedBeam ~= nil }
end

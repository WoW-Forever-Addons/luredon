local _, ns = ...

-- While a pole is equipped: effects loud, music and ambience silent.
local SOUNDS = {
  Sound_EnableAllSound = "1",
  Sound_EnableSFX = "1",
  Sound_SFXVolume = "1",
  Sound_MusicVolume = "0",
  Sound_AmbienceVolume = "0",
}
-- Option "also in the background": the client keeps playing sound while another window has the focus.
local BACKGROUND = { Sound_EnableSoundWhenGameIsInBG = "1" }
-- While the line is out: soft interact reaches farther bobbers.
local SOFT = { SoftTargetInteractArc = "2", SoftTargetInteractRange = "30" }
-- For /ld diag.
ns.SOUND_CVARS = { "Sound_EnableAllSound", "Sound_EnableSFX", "Sound_SFXVolume", "Sound_MusicVolume",
  "Sound_AmbienceVolume", "Sound_EnableSoundWhenGameIsInBG", "SoftTargetInteractArc", "SoftTargetInteractRange" }

local function Save(values)
  local saved = {}
  for cvar, value in pairs(values) do
    local current = GetCVar(cvar)
    if current ~= nil and pcall(SetCVar, cvar, value) then saved[cvar] = current end
  end
  return saved
end

local function Restore(key)
  local saved = ns.db[key]
  if not saved then return end
  for cvar, value in pairs(saved) do pcall(SetCVar, cvar, value) end
  ns.db[key] = nil
end

-- The saved copy lives in SavedVariables: after a /reload or logout with the pole still in hand
-- the next login restores it. SavedVariables are only written on a clean logout or /reload, so
-- after a client crash the copy may be missing (then the volumes stay as Luredon set them).
function ns.UpdateSounds()
  local active = ns.db.sounds and not ns.conflict and ns.HasPole()
  if not active then
    Restore("savedSounds")
  elseif not ns.db.savedSounds then
    local wanted = {}
    for cvar, value in pairs(SOUNDS) do wanted[cvar] = value end
    if ns.db.bgSound then
      for cvar, value in pairs(BACKGROUND) do wanted[cvar] = value end
    end
    ns.db.savedSounds = Save(wanted)
  end
end

-- An option changed while the pole is in hand: put the old values back, then apply the new set.
function ns.RefreshSounds()
  Restore("savedSounds")
  ns.UpdateSounds()
end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", function(_, _, _, spellID)
  if ns.db.softInteract and not ns.db.savedSoft and ns.IsFishingSpell(spellID) then
    ns.db.savedSoft = Save(SOFT)
  end
end)

-- Still channeling Fishing (a recast whose START came before the old STOP): keep the range.
local function ChannelingFishing()
  if not UnitChannelInfo then return false end
  local ok, _, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
  return ok and ns.IsFishingSpell(spellID) or false
end

ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", function(_, _, _, spellID)
  -- Another channel ending (or a secret spell ID) while the line is out leaves the range alone.
  if ns.Usable(spellID) and not ns.IsFishingSpell(spellID) then return end
  if ChannelingFishing() then return end
  Restore("savedSoft")
end)

ns.On("PLAYER_EQUIPMENT_CHANGED", function() ns.UpdateSounds() end)
ns.On("PLAYER_ENTERING_WORLD", function()
  Restore("savedSoft")
  ns.UpdateSounds()
end)
-- SavedVariables are written after PLAYER_LOGOUT, so restored values stay restored.
ns.On("PLAYER_LOGOUT", function()
  Restore("savedSounds")
  Restore("savedSoft")
end)

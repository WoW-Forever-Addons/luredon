---------------------------------------------------------------------------
-- DonCore: the shared base of the Don addons (DONCORE_PLAN.md).
-- Every addon embeds a copy under Libs\DonCore\ (tools/sync_core.sh copies it
-- from the workshop's DonCore/ folder). LibStub keeps one DonCore table for all
-- copies; each module is kept once, the copy with the highest minor wins.
--
--   local Core = LibStub("DonCore-1.0")
--   ns.Style = Core:Get("Style", 3)          -- nil if no copy has minor 3 or newer
--
-- A module file starts with
--   local M = LibStub("DonCore-1.0"):NewModule("Name", minor)
--   if not M then return end                 -- same or newer minor already loaded
-- Minors only add, never change (an older addon may get a newer module).
---------------------------------------------------------------------------
local MAJOR, MINOR = "DonCore-1.0", 1
local Core = LibStub:NewLibrary(MAJOR, MINOR)
if not Core then return end

Core.modules = Core.modules or {}  -- name -> module table (kept across upgrades)
Core.minors = Core.minors or {}    -- name -> minor of the module in use

-- Returns the module table to fill, or nil when a copy with the same or a newer
-- minor is loaded already. An upgrade reuses the old table, so addons that took
-- it earlier see the new functions.
function Core:NewModule(name, minor)
  assert(type(name) == "string", "DonCore:NewModule: name expected")
  minor = assert(tonumber(minor), "DonCore:NewModule: number expected for minor")
  local old = self.minors[name]
  if old and old >= minor then return nil end
  self.minors[name] = minor
  self.modules[name] = self.modules[name] or {}
  return self.modules[name], old
end

-- Returns the module and its minor, or nil when it is missing or older than minMinor.
function Core:Get(name, minMinor)
  local m, minor = self.modules[name], self.minors[name]
  if not m or (minMinor and minor < minMinor) then return nil end
  return m, minor
end

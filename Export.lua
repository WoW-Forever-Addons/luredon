local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Text to copy (Ctrl+A, Ctrl+C): catch export, catch log export and /ld diag.
-- (02.11.2026, StyleKit 2 step 4) the one copy window of every Don addon (DonCore's Kit.ShowCopy: title, hint, the text
-- marked, "Select all" and "Close", Esc closes); Luredon's own window with its text field is gone.
---------------------------------------------------------------------------
function ns.ShowText(title, text)
  local Kit = LibStub("DonCore-1.0"):Get("Kit", 11)
  if not Kit then return end
  local d = Kit.ShowCopy("Luredon  ·  " .. tostring(title or ""), L["Copy with Ctrl+A and Ctrl+C. Contains no character or realm names."],
    text or "", { selectAll = L["Select all"], close = L["Close"] })
  ns.exportFrame = d
  return d
end

function ns.ShowExport()
  ns.ShowText(L["Catch data export"], ns.ExportText())
end

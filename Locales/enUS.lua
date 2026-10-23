local _, ns = ...
-- Keys are the English texts; missing translations fall back to the key.
ns.L = setmetatable({}, { __index = function(_, k) return k end })
-- (i18n) one English word, two meanings in other languages
ns.L["Rare (catches)"] = "Rare"
ns.L["Rare (badge)"] = "Rare"
ns.L["Fish (kind)"] = "Fish"

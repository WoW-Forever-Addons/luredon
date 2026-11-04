local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- (04.11.2026, Era-Test) Introduction at the first cast (Daniel: "vielleicht dazu noch eine einführung bei luredon, mit
-- der erklärung des interact keys"; image scratch/dirigent_1104/luredon/einfuehrung.png, Daniel: "Ja, so einbauen").
-- A Kit.Dialog in the Don look, once per account (LuredonDB.introShown), the first time the line goes out with the
-- interface visible (with "Hide the interface while fishing" the next time the line comes in). It replaces the chat
-- line of the first login (ns.MaybeWelcome). Three steps: cast (double right-click or the interact key, lure first),
-- bite (the interact key again, the longer range), where the key keeps its meaning. Without a bound interact key a
-- yellow note with a button to the key bindings. Buttons "Options" and "Got it". Shown again from the options
-- (Casting and lures, "Introduction").
---------------------------------------------------------------------------
local W = 360        -- dialog width (Kit units; the Kit scale applies, no own scale)
local NUM = 18       -- the step number box
local dialog

local function Kit() return LibStub("DonCore-1.0"):Get("Kit", 11) end

-- The interact key as the game names it ("F", "Mouse Button 4"), nil when none is bound.
function ns.InteractKeyText()
  local key = ns.InteractKeyName and ns.InteractKeyName()
  if not key then return nil end
  if GetBindingText then
    local ok, text = pcall(GetBindingText, key)
    if ok and ns.Usable(text) and type(text) == "string" and text ~= "" then return text end
  end
  return key
end

-- Height of a wrapped text (the client measures it; without an answer an estimate of about 6 units per letter).
local function TextHeight(fs, text, width)
  local ok, h = pcall(fs.GetStringHeight, fs)
  h = ok and tonumber(h) or nil
  if h and h > 0 then return math.ceil(h) end
  local lines = math.max(1, math.ceil(#(text or "") * 6 / math.max(40, width)))
  return lines * 15
end

local function WrapText(parent, color)
  local K = Kit()
  local fs = K.Text(parent, "row", color)
  pcall(fs.SetMaxLines, fs, 0)
  pcall(fs.SetWordWrap, fs, true)
  pcall(fs.SetJustifyV, fs, "TOP")
  return fs
end

local function OpenKeyBindings()
  if InCombatLockdown and InCombatLockdown() then ns.Print(L["Not possible in combat."]) return end
  -- Forever (Settings with a key binding category) or Era 1.15 (the same Settings panel); older: KeyBindingFrame
  if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
    if pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID) then return end
  end
  if KeyBindingFrame_LoadUI then pcall(KeyBindingFrame_LoadUI) end
  if KeyBindingFrame and ShowUIPanel then pcall(ShowUIPanel, KeyBindingFrame) end
end

local function Build()
  local K = Kit()
  if not K then return nil end
  local C, S = K.C, K.SIZE
  dialog = K.Dialog("LuredonIntro", { title = L["Fishing with Luredon"], icon = "Interface\\Icons\\Trade_Fishing", width = W })
  local body = dialog.body
  dialog.steps = {}
  for i = 1, 3 do
    local box = CreateFrame("Frame", nil, body)
    box:SetSize(NUM, NUM)
    K.Border(box, C.gold)
    box.num = K.Text(box, "sub", C.txGold, "CENTER")
    box.num:SetPoint("CENTER", 0, 0)
    box.num:SetText(tostring(i))
    local fs = WrapText(body, i == 3 and C.muted or C.body)
    dialog.steps[i] = { box = box, text = fs }
  end
  -- no key bound: yellow note with a button to the key bindings
  dialog.warn = CreateFrame("Frame", nil, body)
  K.Fill(dialog.warn, C.yellowBg)
  K.Border(dialog.warn, C.yellowBd)
  dialog.warn.text = WrapText(dialog.warn, C.yellow)
  dialog.warn.button = K.Button(dialog.warn, L["Key Bindings"], { small = true, onClick = OpenKeyBindings })
  dialog.foot = WrapText(body, C.quiet)
  dialog:SetButtons({
    { text = L["Options"], onClick = function(d) d:Hide() if ns.OpenOptions then ns.OpenOptions("casting") end end },
    { text = L["Got it"], kind = "primary", onClick = function(d) d:Hide() end },
  })
  return dialog
end

-- Texts and layout for the key bound right now.
local function Fill()
  local K = Kit()
  local S = K.SIZE
  local key = ns.InteractKeyText()
  local gold = K.HexColor and K.HexColor(K.C.txGold) or "ffd4af5a"
  local function Key() return key and ("|c" .. gold .. "[" .. key .. "]|r") or "" end
  local function Bold(s) return "|c" .. (K.HexColor and K.HexColor(K.C.title) or "ffefe5cf") .. s .. "|r" end
  local texts
  if key then
    texts = {
      Bold(L["Cast:"]) .. " " .. L["double right-click into the world, or press your interact key %s. If the pole has no lure, Luredon puts one on first."]:format(Key()),
      Bold(L["Bite:"]) .. " " .. L["press the interact key %s again (or right-click the bobber). While the line is out, Luredon raises the interact range so the bobber is in reach."]:format(Key()),
    }
  else
    texts = {
      Bold(L["Cast:"]) .. " " .. L["double right-click into the world, or press your interact key. If the pole has no lure, Luredon puts one on first."],
      Bold(L["Bite:"]) .. " " .. L["press the interact key again (or right-click the bobber). While the line is out, Luredon raises the interact range so the bobber is in reach."],
    }
  end
  texts[3] = L["Next to an NPC, an object or a corpse, with a loot or vendor window open and in combat the key keeps its usual meaning."]
  local bw = W - 2 * S.pad
  local tw = bw - NUM - 9
  local y = 0
  for i, step in ipairs(dialog.steps) do
    step.box:ClearAllPoints()
    step.box:SetPoint("TOPLEFT", dialog.body, "TOPLEFT", 0, -(y + 1))
    step.text:ClearAllPoints()
    step.text:SetPoint("TOPLEFT", dialog.body, "TOPLEFT", NUM + 9, -y)
    step.text:SetWidth(tw)
    step.text:SetText(texts[i])
    y = y + math.max(NUM, TextHeight(step.text, texts[i], tw)) + 9
    if i == 1 then
      -- the note sits between step 1 and step 2 (where the missing key matters)
      local warn = dialog.warn
      if key then
        warn:Hide()
      else
        local text = L["Your interact key is not bound yet."]
        local bwid = 110
        warn.button:ClearAllPoints()
        warn.button:SetPoint("RIGHT", warn, "RIGHT", -6, 0)
        warn.button:Layout(bwid)
        warn.text:ClearAllPoints()
        warn.text:SetPoint("LEFT", warn, "LEFT", 8, 0)
        warn.text:SetWidth(bw - bwid - 22)
        warn.text:SetText("! " .. text)
        local h = math.max(S.buttonSmall + 8, TextHeight(warn.text, text, bw - bwid - 22) + 12)
        warn:ClearAllPoints()
        warn:SetPoint("TOPLEFT", dialog.body, "TOPLEFT", 0, -y)
        warn:SetSize(bw, h)
        warn:Show()
        y = y + h + 9
      end
    end
  end
  local foot = L["Show this again: Options, Casting and lures."]
  dialog.foot:ClearAllPoints()
  dialog.foot:SetPoint("TOPLEFT", dialog.body, "TOPLEFT", 0, -y)
  dialog.foot:SetWidth(bw)
  dialog.foot:SetText(foot)
  y = y + TextHeight(dialog.foot, foot, bw)
  dialog:SetBodySize(bw, y)
  dialog.texts = texts -- (tests)
end

-- Shows the introduction (also from the options). Returns true when it is shown.
function ns.ShowIntro()
  if InCombatLockdown and InCombatLockdown() then return false end
  if not dialog and not Build() then return false end
  ns.Call("intro fill", Fill)
  dialog:Show()
  return true
end

-- Once per account at the first cast with the interface visible; not with another fishing addon (the clicks are its),
-- not over the hide-the-interface question (it comes first; the introduction follows at the next line in or out).
function ns.MaybeIntro()
  if not ns.db or ns.db.introShown or ns.conflict then return false end
  if InCombatLockdown and InCombatLockdown() then return false end
  if ns.InterfaceHidden and ns.InterfaceHidden() then return false end
  local ask = rawget(_G, "LuredonAskHideUI")
  if ask and ask.IsShown and ask:IsShown() then return false end
  if not ns.ShowIntro() then return false end
  ns.db.introShown = true
  return true
end

local function OnLine(_, _, _, spellID)
  if ns.db and not ns.db.introShown and ns.IsFishingSpell(spellID) then ns.MaybeIntro() end
end
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_START", OnLine)
ns.OnPlayer("UNIT_SPELLCAST_CHANNEL_STOP", OnLine)

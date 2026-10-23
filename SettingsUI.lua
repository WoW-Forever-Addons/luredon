local addonName, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Options in Blizzard's own settings (Esc > Options > AddOns), built the way
-- Blizzard builds its pages: a main page with status, buttons to the subpages
-- and tools, then one subpage per area.
--
-- Every row goes in through Settings.RegisterInitializer, which inserts it from
-- Blizzard's secure code. Settings.CreateCheckbox / layout:AddInitializer would
-- insert from addon code and taint the settings search.
--
-- spec = {
--   name = "Luredon",
--   status = function() return { "line", ... } end,
--   tools  = { { label, button, onClick, tooltip }, ... },
--   pages  = { { title, items = { item, ... } }, ... },
-- }
-- item = { header = "Text" }
--      | { key, name, tip, kind = "check"|"slider"|"dropdown", parent, blockedBy,
--          min, max, step, format, options, onChange }
--      | { kind = "button", name, button, onClick, tip }   (1.15, tool inside a page)
---------------------------------------------------------------------------
local function Var(key) return addonName .. "_" .. key end
ns.SettingVariable = Var

local function Available()
  return Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterVerticalLayoutSubcategory
    and Settings.RegisterAddOnSetting and Settings.RegisterInitializer and Settings.CreateCheckboxInitializer
    and Settings.RegisterAddOnCategory
end

local function Tooltip(item)
  return function()
    local text = item.tip and L[item.tip] or nil
    local blocker = item.blockedBy and item.blockedBy()
    if blocker then
      local note = "|cffff4040" .. L["%s already does this, so it is off here."]:format(blocker) .. "|r"
      text = text and (text .. "\n\n" .. note) or note
    end
    return text
  end
end

local function VarType(kind, default)
  local types = Settings.VarType or {}
  if kind == "slider" then return types.Number or "number" end
  if kind == "dropdown" then return types.String or type(default) end
  return types.Boolean or "boolean"
end

local function AddItem(category, item)
  -- 1.15: tool button inside a page (e.g. "Reset position" on "Appearance", as in the other addons)
  if item.kind == "button" then
    if CreateSettingsButtonInitializer then
      Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(L[item.name], L[item.button],
        ns.Safe("tool " .. tostring(item.name), item.onClick), item.tip and L[item.tip] or nil, false))
    end
    return
  end
  if item.header then
    if CreateSettingsListSectionHeaderInitializer then
      Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(L[item.header]))
    end
    return
  end
  local kind = item.kind or "check"
  local default = ns.defaults[item.key]
  local setting = Settings.RegisterAddOnSetting(category, Var(item.key), item.key, ns.db,
    VarType(kind, default), L[item.name], default)

  local init
  if kind == "slider" then
    if not (Settings.CreateSliderInitializer and Settings.CreateSliderOptions) then return end
    local options = Settings.CreateSliderOptions(item.min, item.max, item.step)
    if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
      options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, item.format or function(v)
        return ("%d%%"):format(v * 100 + 0.5)
      end)
    end
    init = Settings.CreateSliderInitializer(setting, options, Tooltip(item))
  elseif kind == "dropdown" then
    if not (Settings.CreateDropdownInitializer and Settings.CreateControlTextContainer) then return end
    init = Settings.CreateDropdownInitializer(setting, function()
      local container = Settings.CreateControlTextContainer()
      for _, option in ipairs(item.options()) do container:Add(option[1], option[2]) end
      return container:GetData()
    end, Tooltip(item))
  else
    init = Settings.CreateCheckboxInitializer(setting, nil, Tooltip(item))
  end

  if init.AddModifyPredicate then
    if item.blockedBy then
      init:AddModifyPredicate(function() return not item.blockedBy() end)
    end
    if item.parent then
      if init.Indent then init:Indent() end
      init:AddModifyPredicate(function() return ns.db[item.parent] and true or false end)
      if init.AddEvaluateStateCVar then init:AddEvaluateStateCVar(Var(item.parent)) end
    end
  end
  Settings.RegisterInitializer(category, init)

  if item.onChange and Settings.SetOnValueChangedCallback then
    Settings.SetOnValueChangedCallback(Var(item.key), function() item.onChange() end)
  end
end

function ns.BuildSettings(spec)
  if not Available() then return nil end
  local main = Settings.RegisterVerticalLayoutCategory(spec.name)

  -- Status
  local status = spec.status and spec.status() or {}
  if #status > 0 and CreateSettingsListSectionHeaderInitializer then
    Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L["Status"]))
    for _, line in ipairs(status) do
      Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer("|cffcccccc" .. line .. "|r"))
    end
  end

  -- Subpages
  local subpages = {}
  for _, page in ipairs(spec.pages) do
    local sub = Settings.RegisterVerticalLayoutSubcategory(main, L[page.title])
    subpages[#subpages + 1] = { page = page, category = sub }
    for _, item in ipairs(page.items) do AddItem(sub, item) end
  end
  if CreateSettingsButtonInitializer then
    if CreateSettingsListSectionHeaderInitializer then
      Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L["Settings"]))
    end
    for _, s in ipairs(subpages) do
      Settings.RegisterInitializer(main, CreateSettingsButtonInitializer(L[s.page.title], L["Open"], function()
        Settings.OpenToCategory(s.category:GetID())
      end, s.page.tip and L[s.page.tip] or nil, false))
    end
    -- Tools
    if spec.tools and #spec.tools > 0 then
      if CreateSettingsListSectionHeaderInitializer then
        Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L["Tools"]))
      end
      for _, t in ipairs(spec.tools) do
        Settings.RegisterInitializer(main, CreateSettingsButtonInitializer(L[t[1]], L[t[2]], t[3], t[4] and L[t[4]] or nil, false))
      end
    end
  end

  Settings.RegisterAddOnCategory(main)
  return main
end

-- Two clicks within 5 seconds for dangerous tools (no Blizzard popups).
local confirmUntil = {}
function ns.Confirm(id, message)
  local now = GetTime()
  if confirmUntil[id] and now < confirmUntil[id] then
    confirmUntil[id] = nil
    return true
  end
  confirmUntil[id] = now + 5
  ns.Print(message)
  return false
end

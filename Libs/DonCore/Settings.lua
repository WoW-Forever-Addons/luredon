local M = LibStub("DonCore-1.0"):NewModule("Settings", 7)
if not M then return end
local Core = LibStub("DonCore-1.0")

-- (minor 7, 24.11.2026, Fenstercheck, Daniel: "Bei den Optionen immer nur das Optionsfenster des jeweiligen Addons
-- aufmachen") with an Options module that opens one window per addon (Options minor 8, O.ownWindows) the game's AddOns
-- list keeps one short page per addon: only the button "Options / Open" that opens the addon's own window.
-- spec.fullPages no longer builds Blizzard's full pages then (no labels cut by the game's fixed column, no dark empty
-- check boxes, no status lines that were written once at login and grew old, no section heads with a hanging tooltip).
-- The look option's tip no longer says the options open in the game's settings.

-- (minor 6, 20.11.2026, Daniel after a player did not find the way back to the old look: "bei allen addons den namen der
-- option gleich machen", chosen: a choice Don / Blizzard) ns.LookOption(o): the one option item for the look of an
-- addon's windows, the same words in every Don addon and in the game's languages: a dropdown "Window style" with
-- "Don look" (false) and "Blizzard look" (true) on db.blizzLook (the stored value stays the boolean of the old checkbox).
-- o = { addon = display name (default the Attach name), category = the addon's name in the game's settings (default
-- addon), note = one more sentence of the addon, already in the game's language, onChange = function(value), key, parent }.
-- The item is donCommon: DonCore's Options window runs its onChange itself (Options minor 5), like the minimap switch.
-- M.LookWord(text) gives the words in the game's language. The tip also says that the windows keep the Don look where
-- the game lacks its templates (Classic Era), so no addon needs a note for that.
-- (minor 5, 17.11.2026, Daniel: the look of Questdon's quest list could only be picked in the start window) a "choice"
-- item with options() (list of { value, text }) shows here as a dropdown on db[key]; its onChange(value) applies it.
-- Choices without options() stay in the addon's window only.
-- (minor 5, 17.11.2026, Daniel: "ob da was an oder aus ist, sieht man auch nicht") a tool with state() (a switch in
-- DonCore's window: Questdon's "Only collect and share data", Leveldon's "Only record your run", the example guild) shows
-- as a checkbox with its state; a click runs the tool when the box differs from the state, then the real state is shown.

-- (minor 4, 16.11.2026, Blizzard look for Guildon, Guildon Crafts, Golddon) a dropdown takes the type of its default
-- (numbers stay numbers: Crafts' wish days, Golddon's money steps). The spec may name its own table and words, like
-- Options.Register: spec.db() (the table of the values, default ns.db), spec.default(key) (default ns.defaults[key]),
-- spec.changed(key, value) (after the item's onChange, for every option of the pages), spec.T(text) (the module's words
-- and the item texts, default ns.L).

-- (minor 2, 01.11.2026, STYLEKIT_PLAN.md "Schritt 3") with DonCore's Options module loaded (Libs\DonCore\Options.lua)
-- ns.BuildSettings(spec) puts the same pages into the one options window of all Don addons (Options.FromSettings) and
-- Blizzard's AddOns list keeps one page per addon: the status and a button that opens the window. spec.ownWindow = true:
-- the addon registers its tabs itself (Questdon, Leveldon, Luredon, Golddon), only the short page here. Without the
-- Options module the pages are built as before. ns.OpenDonOptions(tab) opens the window at the addon.

---------------------------------------------------------------------------
-- DonCore module "Settings" (minor 1, 30.10.2026, DONCORE_PLAN.md step 2).
-- Options in Blizzard's own settings (Esc > Options > AddOns), built the way
-- Blizzard builds its pages: a main page with status, buttons to the subpages
-- and tools, then one subpage per area. One source for the six SettingsUI.lua
-- copies (Questdon's 1.19 version: button items, onChange with the value,
-- RefreshSettingsUI, "choice" items skipped).
--
-- An addon attaches once, in Core.lua after its ns.Style line:
--   LibStub("DonCore-1.0"):Get("Settings", 1):Attach(addonName, ns)
-- Attach puts on ns: BuildSettings(spec), RefreshSettingsUI(), SettingsObjects(),
-- SettingVariable(key), Confirm(id, message). It reads ns.L, ns.db, ns.defaults,
-- ns.Guard (or ns.Safe) and ns.Print only when they are called, so the order of
-- the addon's files does not matter.
--
-- Every row goes in through Settings.RegisterInitializer, which inserts it from
-- Blizzard's secure code. Settings.CreateCheckbox / layout:AddInitializer would
-- insert from addon code and taint the settings search.
--
-- spec = {
--   name = "Questdon",
--   status = function() return { "line", ... } end,
--   tools  = { { label, button, onClick, tooltip }, ... },
--   pages  = { { title, tip, items = { item, ... } }, ... },
-- }
-- item = { header = "Text" }
--      | { key, name, tip, kind = "check"|"slider"|"dropdown", parent, blockedBy,
--          min, max, step, format, options, onChange(value) }
--      | { kind = "button", name, button, onClick, tip }   (tool in a page)
--      | { kind = "choice", ... }                          (addon window only, skipped here)
---------------------------------------------------------------------------

local function Available()
  return Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterVerticalLayoutSubcategory
    and Settings.RegisterAddOnSetting and Settings.RegisterInitializer and Settings.CreateCheckboxInitializer
    and Settings.RegisterAddOnCategory
end

local function VarType(kind, default)
  local types = Settings.VarType or {}
  if kind == "slider" then return types.Number or "number" end
  if kind == "dropdown" then
    if type(default) == "number" then return types.Number or "number" end -- (minor 4)
    if type(default) == "boolean" then return types.Boolean or "boolean" end
    return types.String or type(default)
  end
  return types.Boolean or "boolean"
end

-- (minor 6) the words of the look choice; English is the key
local LOOK, LOOK_DON, LOOK_BLIZZ = "Window style", "Don look", "Blizzard look"
local LOOK_TIP = "Don look: %s's windows in the style of the Don addons. Blizzard look: the windows look like the game's own, with the game's frames, tabs, buttons and lists; the options window follows the choice. Where the game lacks its templates (Classic Era) the windows keep the Don look."
local LOOK_WORDS = {
  deDE = { [LOOK] = "Fensterstil", [LOOK_DON] = "Don-Look", [LOOK_BLIZZ] = "Blizzard-Look",
    [LOOK_TIP] = "Don-Look: die Fenster von %s im Stil der Don-Addons. Blizzard-Look: die Fenster sehen aus wie die des Spiels, mit Rahmen, Reitern, Knöpfen und Listen des Spiels; das Optionsfenster folgt der Wahl. Wo dem Spiel die Vorlagen fehlen (Classic Era), bleiben die Fenster im Don-Look." },
  esES = { [LOOK] = "Estilo de ventana", [LOOK_DON] = "Aspecto Don", [LOOK_BLIZZ] = "Aspecto Blizzard",
    [LOOK_TIP] = "Aspecto Don: las ventanas de %s con el estilo de los addons Don. Aspecto Blizzard: las ventanas se ven como las del juego, con sus marcos, pestañas, botones y listas; la ventana de opciones sigue esta elección. Donde el juego no tiene sus plantillas (Classic Era), las ventanas conservan el aspecto Don." },
  esMX = { [LOOK] = "Estilo de ventana", [LOOK_DON] = "Aspecto Don", [LOOK_BLIZZ] = "Aspecto Blizzard",
    [LOOK_TIP] = "Aspecto Don: las ventanas de %s con el estilo de los addons Don. Aspecto Blizzard: las ventanas se ven como las del juego, con sus marcos, pestañas, botones y listas; la ventana de opciones sigue esta elección. Donde el juego no tiene sus plantillas (Classic Era), las ventanas conservan el aspecto Don." },
  frFR = { [LOOK] = "Style des fenêtres", [LOOK_DON] = "Style Don", [LOOK_BLIZZ] = "Style Blizzard",
    [LOOK_TIP] = "Style Don : les fenêtres de %s dans le style des addons Don. Style Blizzard : les fenêtres ressemblent à celles du jeu, avec ses cadres, onglets, boutons et listes ; la fenêtre des options suit ce choix. Là où le jeu n'a pas ses modèles (Classic Era), les fenêtres gardent le style Don." },
  koKR = { [LOOK] = "창 스타일", [LOOK_DON] = "Don 스타일", [LOOK_BLIZZ] = "블리자드 스타일",
    [LOOK_TIP] = "Don 스타일: %s의 창을 Don 애드온의 스타일로 표시합니다. 블리자드 스타일: 창이 게임의 틀, 탭, 버튼, 목록을 사용해 게임 기본 창처럼 보입니다. 설정 창도 이 선택을 따릅니다. 게임에 해당 템플릿이 없는 경우(Classic Era) 창은 Don 스타일로 유지됩니다." },
  ptBR = { [LOOK] = "Estilo das janelas", [LOOK_DON] = "Visual Don", [LOOK_BLIZZ] = "Visual Blizzard",
    [LOOK_TIP] = "Visual Don: as janelas do %s no estilo dos addons Don. Visual Blizzard: as janelas ficam como as do jogo, com suas molduras, abas, botões e listas; a janela de opções segue essa escolha. Onde o jogo não tem seus modelos (Classic Era), as janelas mantêm o visual Don." },
  ruRU = { [LOOK] = "Стиль окон", [LOOK_DON] = "Стиль Don", [LOOK_BLIZZ] = "Стиль Blizzard",
    [LOOK_TIP] = "Стиль Don: окна %s в стиле аддонов Don. Стиль Blizzard: окна выглядят как окна игры, с её рамками, вкладками, кнопками и списками; окно настроек следует этому выбору. Там, где в игре нет нужных шаблонов (Classic Era), окна остаются в стиле Don." },
  zhTW = { [LOOK] = "視窗風格", [LOOK_DON] = "Don 風格", [LOOK_BLIZZ] = "暴雪風格",
    [LOOK_TIP] = "Don 風格：%s 的視窗使用 Don 插件的風格。暴雪風格：視窗看起來像遊戲內建視窗，使用遊戲的框架、分頁、按鈕和清單；選項視窗也會跟著這個選擇。遊戲缺少這些範本時（Classic Era），視窗維持 Don 風格。" },
  zhCN = { [LOOK] = "窗口风格", [LOOK_DON] = "Don 风格", [LOOK_BLIZZ] = "暴雪风格",
    [LOOK_TIP] = "Don 风格：%s 的窗口使用 Don 插件的风格。暴雪风格：窗口看起来像游戏自带窗口，使用游戏的框体、标签页、按钮和列表；选项窗口也会跟随这个选择。游戏缺少这些模板时（Classic Era），窗口保持 Don 风格。" },
}
function M.LookWord(text)
  local loc = type(GetLocale) == "function" and GetLocale() or nil
  local t = type(loc) == "string" and LOOK_WORDS[loc]
  return t and t[text] or text
end

function M:Attach(addonName, ns)
  assert(type(addonName) == "string" and type(ns) == "table", "DonCore Settings:Attach(addonName, ns)")
  local function Var(key) return addonName .. "_" .. key end
  -- (minor 4) the spec of the last BuildSettings: its own table, defaults, words and change callback
  local cur = {}
  local function L(key)
    if type(cur.T) == "function" then
      local ok, s = pcall(cur.T, key)
      if ok and s ~= nil then return s end
    end
    return ns.L and ns.L[key] or key
  end
  local function DB()
    if type(cur.db) == "function" then
      local ok, t = pcall(cur.db)
      if ok and type(t) == "table" then return t end
    end
    return ns.db
  end
  local function Default(key)
    if type(cur.default) == "function" then
      local ok, v = pcall(cur.default, key)
      if ok then return v end
    end
    return ns.defaults and ns.defaults[key]
  end
  -- Questdon, Vitaldon, Geardon, Dropdon have ns.Guard; Luredon has ns.Safe (same shape)
  local function Guard(context, fn)
    local g = ns.Guard or ns.Safe
    return g and g(context, fn) or fn
  end

  local function Tooltip(item)
    return function()
      local text = item.tip and L(item.tip) or nil
      local blocker = item.blockedBy and item.blockedBy()
      if blocker then
        local note = "|cffff4040" .. L("%s already does this, so it is off here."):format(blocker) .. "|r"
        text = text and (text .. "\n\n" .. note) or note
      end
      return text
    end
  end

  -- the settings objects, so ns.RefreshSettingsUI can show values the addon changed itself
  local settingsByKey, refreshing = {}, false
  local ToolSwitch -- (minor 5) below
  local toolSwitches, toolValues = {}, {} -- (minor 5) tools with state(): their checkboxes, values in a table of their own
  function ns.RefreshSettingsUI()
    refreshing = true
    local db = DB()
    for key, setting in pairs(settingsByKey) do
      local v = db and db[key]
      if setting.GetValue and setting.SetValue then
        local ok, cur = pcall(setting.GetValue, setting)
        if ok and cur ~= v then pcall(setting.SetValue, setting, v) end
      end
    end
    -- (minor 5) the tools with a state
    for key, sw in pairs(toolSwitches) do
      local ok, on = pcall(sw.state)
      on = ok and on and true or false
      toolValues[key] = on
      if sw.setting and sw.setting.GetValue and sw.setting.SetValue then
        local okG, cur = pcall(sw.setting.GetValue, sw.setting)
        if okG and cur ~= on then pcall(sw.setting.SetValue, sw.setting, on) end
      end
    end
    refreshing = false
  end
  ns.SettingsObjects = function() return settingsByKey end -- (tests)
  ns.SettingVariable = Var

  local function AddItem(category, item)
    -- tool button inside a page (e.g. "Reset position")
    if item.kind == "button" then
      if CreateSettingsButtonInitializer then
        Settings.RegisterInitializer(category, CreateSettingsButtonInitializer(L(item.name), L(item.button),
          Guard("tool", item.onClick), item.tip and L(item.tip) or nil, false))
      end
      return
    end
    if item.header then
      if CreateSettingsListSectionHeaderInitializer then
        Settings.RegisterInitializer(category, CreateSettingsListSectionHeaderInitializer(L(item.header)))
      end
      return
    end
    local kind = item.kind or "check"
    if kind == "choice" then -- (29.10.2026) only in Questdon's window; (minor 5) as a dropdown when it has options()
      if type(item.options) ~= "function" then return end
      kind = "dropdown"
    end
    local default = Default(item.key)
    local db = DB()
    if db[item.key] == nil and default ~= nil then db[item.key] = default end -- (minor 4) a value never saved: its default
    local setting = Settings.RegisterAddOnSetting(category, Var(item.key), item.key, db,
      VarType(kind, default), L(item.name), default)
    if setting then settingsByKey[item.key] = setting end

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
        init:AddModifyPredicate(function() return DB()[item.parent] and true or false end)
        if init.AddEvaluateStateCVar then init:AddEvaluateStateCVar(Var(item.parent)) end
      end
    end
    Settings.RegisterInitializer(category, init)

    local changed = cur.changed -- (minor 4)
    if (item.onChange or changed) and Settings.SetOnValueChangedCallback then
      Settings.SetOnValueChangedCallback(Var(item.key), Guard("setting", function()
        if refreshing then return end -- a value shown again, not changed by the player
        local v = DB()[item.key]
        if item.onChange then item.onChange(v) end
        if changed then changed(item.key, v) end
      end))
    end
  end

  -- (minor 5) a tool with state() as a checkbox; false when the client cannot (then the button as before)
  ToolSwitch = function(category, t, n)
    if not (Settings.CreateCheckboxInitializer and Settings.SetOnValueChangedCallback) then return false end
    local key = "donTool" .. n
    local ok, on = pcall(t.state)
    toolValues[key] = ok and on and true or false
    local setting = Settings.RegisterAddOnSetting(category, Var(key), key, toolValues, VarType("check"), L(t[1]), false)
    if not setting then return false end
    toolSwitches[key] = { setting = setting, state = t.state }
    Settings.RegisterInitializer(category, Settings.CreateCheckboxInitializer(setting, nil, t[4] and L(t[4]) or nil))
    Settings.SetOnValueChangedCallback(Var(key), Guard("tool", function()
      if refreshing then return end
      local okS, now = pcall(t.state)
      if (okS and now and true or false) ~= (toolValues[key] == true) then t[3]() end
      ns.RefreshSettingsUI() -- the real state (a tool may refuse, e.g. in combat)
    end))
    return true
  end

  function ns.OpenDonOptions(tab)
    local Opt = Core:Get("Options", 1)
    if Opt and Opt.addons[ns.donOptionsId or addonName] then return Opt.Open(ns.donOptionsId or addonName, tab) end
  end

  function ns.BuildSettings(spec)
    cur = spec -- (minor 4)
    local Opt = Core:Get("Options", 1)
    -- (minor 3, 16.11.2026, Blizzard look) spec.fullPages: the addon wants its pages in Blizzard's settings as without
    -- the Options module (it opens them there, Options spec.redirect); DonCore's window keeps its tabs as well
    if Opt and spec.fullPages and not Opt.ownWindows then
      ns.donOptionsId = spec.name
      if not spec.ownWindow then Opt.FromSettings(spec, ns) end
    elseif Opt then
      ns.donOptionsId = spec.name
      if not spec.ownWindow then Opt.FromSettings(spec, ns) end
      if not Available() then return nil end
      local main = Settings.RegisterVerticalLayoutCategory(spec.name)
      -- (minor 7) the status lives in the addon's own window (fresh on every look); before, Options minor 8, here too
      local status = not Opt.ownWindows and spec.status and spec.status() or {}
      if CreateSettingsListSectionHeaderInitializer and not Opt.ownWindows then
        if #status > 0 then
          Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L("Status")))
          for _, line in ipairs(status) do
            Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer("|cffcccccc" .. line .. "|r"))
          end
        end
        Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L("Settings")))
      end
      if CreateSettingsButtonInitializer then
        Settings.RegisterInitializer(main, CreateSettingsButtonInitializer(L("Options"), L("Open"), Guard("options", function()
          Opt.OpenFromBlizzard(spec.name)
        end), nil, false))
      end
      Settings.RegisterAddOnCategory(main)
      -- (minor 7) an addon that asked for the full pages (spec.fullPages) opens its options in the game's settings when it
      -- gets a category back (its ns.OpenGameOptions); with Options' own windows it gets nil, so its cog and slash
      -- command end in its own window, while the short page with the button stays in the AddOns list
      if spec.fullPages and Opt.ownWindows then return nil end
      return main
    end
    if not Available() then return nil end
    local main = Settings.RegisterVerticalLayoutCategory(spec.name)

    -- Status
    local status = spec.status and spec.status() or {}
    if #status > 0 and CreateSettingsListSectionHeaderInitializer then
      Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L("Status")))
      for _, line in ipairs(status) do
        Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer("|cffcccccc" .. line .. "|r"))
      end
    end

    -- Subpages
    local subpages = {}
    for _, page in ipairs(spec.pages) do
      local sub = Settings.RegisterVerticalLayoutSubcategory(main, L(page.title))
      subpages[#subpages + 1] = { page = page, category = sub }
      for _, item in ipairs(page.items) do AddItem(sub, item) end
    end
    if CreateSettingsButtonInitializer then
      if CreateSettingsListSectionHeaderInitializer then
        Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L("Settings")))
      end
      for _, s in ipairs(subpages) do
        Settings.RegisterInitializer(main, CreateSettingsButtonInitializer(L(s.page.title), L("Open"), function()
          Settings.OpenToCategory(s.category:GetID())
        end, s.page.tip and L(s.page.tip) or nil, false))
      end
      -- Tools
      if spec.tools and #spec.tools > 0 then
        if CreateSettingsListSectionHeaderInitializer then
          Settings.RegisterInitializer(main, CreateSettingsListSectionHeaderInitializer(L("Tools")))
        end
        for n, t in ipairs(spec.tools) do
          if not (type(t.state) == "function" and ToolSwitch(main, t, n)) then
            Settings.RegisterInitializer(main, CreateSettingsButtonInitializer(L(t[1]), L(t[2]), t[3], t[4] and L(t[4]) or nil, false))
          end
        end
      end
    end

    Settings.RegisterAddOnCategory(main)
    return main
  end

  -- (minor 6) the look of the addon's windows as a choice of two named looks (see the head of the file)
  function ns.LookOption(o)
    o = type(o) == "table" and o or {}
    local addon = o.addon or addonName
    local tip = o.tip or M.LookWord(LOOK_TIP):format(addon, o.category or addon)
    if type(o.note) == "string" and o.note ~= "" then tip = tip .. " " .. o.note end
    return { key = o.key or "blizzLook", kind = "dropdown", parent = o.parent, donCommon = true,
      name = o.name or M.LookWord(LOOK), tip = tip,
      options = function() return { { false, M.LookWord(LOOK_DON) }, { true, M.LookWord(LOOK_BLIZZ) } } end,
      onChange = o.onChange }
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

  return ns
end

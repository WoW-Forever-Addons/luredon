local O = LibStub("DonCore-1.0"):NewModule("Options", 5)

---------------------------------------------------------------------------
-- DonCore module "Options" (minor 1, 01.11.2026, STYLEKIT_PLAN.md "Schritt 3"): one options window for every Don addon
-- that is installed, built from the Kit blocks (Kit.lua, Don style). Left the addons and their tabs, in the middle the
-- option rows (Toggle, Slider, Dropdown, Button; sub-options indented; rarely used ones under "More settings"), right a
-- card with the picture and the explanation of the option under the mouse, a search over all options in the header,
-- "Reset this tab" in the footer. Lifted from Questdon/OptionsWindow.lua (17.10. to 31.10.2026).
--   local Opt = LibStub("DonCore-1.0"):Get("Options", 1)
--   Opt.Register("Leveldon", spec)   Opt.Open("Leveldon", "route")   Opt.Toggle("Leveldon")
-- spec (an addon only describes its options, the window is shared):
--   name (plain, for the left side), order (smaller first), tabs = { { key, title, text, pic, icon, top, main, more,
--   tools, status } }, pages() (items with key, name, tip, kind = nil (switch) | "slider" | "dropdown" | "choice" |
--   "button", parent, min/max/step/format, options(), get/set/choices, onClick, button, status(), blockedBy()),
--   tools() ({ name, button, fn, tip, state = fn -> true / false for a tool that switches: shown as a switch }), db(), default(key), changed(key), T(text), status(), help(),
--   buttonKey(section), media (path of its pictures, ending in \\), labels(englishText) (translation of the window's
--   own words; the first addon that gives one is used).
-- (minor 2, 02.11.2026, Guildon step 4) tabs[i].preview = function(frame, width, height): the tab draws its own preview
-- card (pin looks, sizes) into frame instead of the picture; kind = "checklist": options() = { { value, text } }, one switch
-- per entry under the option's name, values in db[key][value] = true (or isChecked(value) / setChecked(value, on));
-- blockedBy() may return { reason = "text" } to explain in its own words why the option is locked.
-- (minor 3, 02.11.2026, Geardon step 4) FromSettings: a page with preview = function(frame, width, height) gets that preview
-- card as well (the Settings pages of Geardon, Vitaldon, Dropdon).
-- (minor 4, 02.11.2026, Daniel: "Maßstab 80 % für alle Kit-Fenster, im Optionsfenster einstellbar von 60 bis 110 %") a last
-- page "General" with the window scale of every Kit window (Kit minor 13), kept in the SavedVariables of every Don addon
-- (donWindowScale, donWindowScaleAt: the newest one wins at login). O.GENERAL is its id.
-- (minor 5, 04.11.2026, Era-Test) an item made by DonCore (item.donCommon, e.g. MinimapButton's ns.MinimapOption()) runs
-- its onChange(value) here after spec.changed, so an addon with its own Register spec needs no code for it (FromSettings
-- specs already run onChange in their changed()).
-- Needs Kit (minor 2). Only own frames, no hooks, no SavedVariables (place and size kept for the session).
---------------------------------------------------------------------------
if not O then return end
local Core = LibStub("DonCore-1.0")
O.VERSION = 5
O.addons = O.addons or {}   -- id -> spec (kept across upgrades)
O.ids = O.ids or {}         -- ids in the order they registered
O.store = O.store or {}     -- the window's place and size for the session
O.state = O.state or { query = "", more = {}, tabOf = {} }

local floor, max, min = math.floor, math.max, math.min
local ipairs, pairs, type, tostring, tonumber, pcall = ipairs, pairs, type, tostring, tonumber, pcall
local PREV_W, NAV_W, TEXT_H, RESET_SECONDS = 270, 200, 20, 5
local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

local function K() return Core:Get("Kit", 2) end -- (minor 2: Kit.IconButton for the cog)

-- O.onError = function(where, err) ... end (set by an addon); nil: errors of callbacks stay silent
local function Safe(where, fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
  if type(O.onError) == "function" then pcall(O.onError, where, a) end
end

-- the window's own words in the game's languages (taken from Questdon's translations, 01.11.2026); English is the key
local WORDS = {
  deDE = {
    ["General"] = "Allgemein",
    ["Windows"] = "Fenster",
    ["Window scale"] = "Fenstermaßstab",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "Die Größe aller Don-Fenster: Questbuch, Fenster der Addons, Optionen, Dialoge. 80 % passt auf die meisten Bildschirme.",
    ["Options"] = "Optionen",
    ["Search all options"] = "Alle Optionen durchsuchen",
    ["More settings"] = "Weitere Einstellungen",
    ["Reset this tab"] = "Diesen Reiter zurücksetzen",
    ["Tools"] = "Werkzeuge",
    ["Status"] = "Status",
    ["Commands"] = "Befehle",
    ["Nothing found. Try another word."] = "Nichts gefunden. Versuch ein anderes Wort.",
    ["Needs: %s"] = "Braucht: %s",
    ["Open"] = "Öffnen",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "Innerhalb von 5 Sekunden noch einmal klicken, um die Einstellungen dieses Reiters zurückzusetzen.",
    ["%s already does this, so it is off here."] = "%s macht das schon, darum ist es hier aus.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s zeigt jetzt den Kompass, deshalb bleiben der Pfeil und der Kompass der Liste im Hintergrund. Schließe sein Fenster oder schalte seinen Kompass aus, dann sind sie wieder zu sehen.",
  },
  esES = {
    ["General"] = "General",
    ["Windows"] = "Ventanas",
    ["Window scale"] = "Escala de ventanas",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "El tamaño de todas las ventanas Don: libro de misiones, ventanas de los addons, opciones, diálogos. El 80 % encaja en la mayoría de pantallas.",
    ["Options"] = "Opciones",
    ["Search all options"] = "Buscar en todas las opciones",
    ["More settings"] = "Más ajustes",
    ["Reset this tab"] = "Restablecer esta pestaña",
    ["Tools"] = "Herramientas",
    ["Status"] = "Estado",
    ["Commands"] = "Comandos",
    ["Nothing found. Try another word."] = "No se encontró nada. Prueba otra palabra.",
    ["Needs: %s"] = "Requiere: %s",
    ["Open"] = "Abrir",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "Vuelve a hacer clic en 5 segundos para devolver los ajustes de esta pestaña a sus valores por defecto.",
    ["%s already does this, so it is off here."] = "%s ya se encarga de esto, así que aquí queda desactivado.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s muestra ahora la brújula, por eso la flecha y la brújula de la lista quedan en segundo plano. Cierra su ventana o desactiva su brújula para verlas.",
  },
  esMX = {
    ["General"] = "General",
    ["Windows"] = "Ventanas",
    ["Window scale"] = "Escala de ventanas",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "El tamaño de todas las ventanas Don: libro de misiones, ventanas de los addons, opciones, diálogos. El 80 % encaja en la mayoría de pantallas.",
    ["Options"] = "Opciones",
    ["Search all options"] = "Buscar en todas las opciones",
    ["More settings"] = "Más ajustes",
    ["Reset this tab"] = "Restablecer esta pestaña",
    ["Tools"] = "Herramientas",
    ["Status"] = "Estado",
    ["Commands"] = "Comandos",
    ["Nothing found. Try another word."] = "No se encontró nada. Prueba otra palabra.",
    ["Needs: %s"] = "Requiere: %s",
    ["Open"] = "Abrir",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "Vuelve a hacer clic en 5 segundos para devolver los ajustes de esta pestaña a sus valores por defecto.",
    ["%s already does this, so it is off here."] = "%s ya se encarga de esto, así que aquí queda desactivado.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s muestra ahora la brújula, por eso la flecha y la brújula de la lista quedan en segundo plano. Cierra su ventana o desactiva su brújula para verlas.",
  },
  frFR = {
    ["General"] = "Général",
    ["Windows"] = "Fenêtres",
    ["Window scale"] = "Échelle des fenêtres",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "La taille de toutes les fenêtres Don : livre de quêtes, fenêtres des addons, options, dialogues. 80 % convient à la plupart des écrans.",
    ["Options"] = "Options",
    ["Search all options"] = "Rechercher dans toutes les options",
    ["More settings"] = "Plus de réglages",
    ["Reset this tab"] = "Réinitialiser cet onglet",
    ["Tools"] = "Outils",
    ["Status"] = "État",
    ["Commands"] = "Commandes",
    ["Nothing found. Try another word."] = "Rien trouvé. Essayez un autre mot.",
    ["Needs: %s"] = "Nécessite : %s",
    ["Open"] = "Ouvrir",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "Cliquez à nouveau dans les 5 secondes pour remettre les réglages de cet onglet par défaut.",
    ["%s already does this, so it is off here."] = "%s s’en charge déjà, l’option est donc désactivée ici.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s affiche maintenant la boussole, donc la flèche et la boussole de la liste restent en retrait. Fermez sa fenêtre ou désactivez sa boussole pour les voir.",
  },
  koKR = {
    ["General"] = "일반",
    ["Windows"] = "창",
    ["Window scale"] = "창 크기 비율",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "모든 Don 창의 크기: 퀘스트북, 애드온 창, 설정, 대화 상자. 대부분의 화면에는 80 %가 알맞습니다.",
    ["Options"] = "설정",
    ["Search all options"] = "모든 옵션 검색",
    ["More settings"] = "추가 설정",
    ["Reset this tab"] = "이 탭 초기화",
    ["Tools"] = "도구",
    ["Status"] = "상태",
    ["Commands"] = "명령어",
    ["Nothing found. Try another word."] = "찾지 못했습니다. 다른 단어로 찾아 보세요.",
    ["Needs: %s"] = "필요: %s",
    ["Open"] = "열기",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "5초 안에 다시 클릭하면 이 탭의 설정이 기본값으로 돌아갑니다.",
    ["%s already does this, so it is off here."] = "%s 애드온이 이미 이 기능을 제공하므로 여기서는 꺼져 있습니다.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s이(가) 지금 나침반을 표시하므로 화살표와 목록의 나침반은 뒤로 물러나 있습니다. 해당 창을 닫거나 나침반을 끄면 다시 보입니다.",
  },
  ptBR = {
    ["General"] = "Geral",
    ["Windows"] = "Janelas",
    ["Window scale"] = "Escala das janelas",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "O tamanho de todas as janelas Don: livro de missões, janelas dos addons, opções, diálogos. 80 % cabe na maioria das telas.",
    ["Options"] = "Opções",
    ["Search all options"] = "Buscar em todas as opções",
    ["More settings"] = "Mais opções",
    ["Reset this tab"] = "Redefinir esta aba",
    ["Tools"] = "Ferramentas",
    ["Status"] = "Status",
    ["Commands"] = "Comandos",
    ["Nothing found. Try another word."] = "Nada encontrado. Tente outra palavra.",
    ["Needs: %s"] = "Requer: %s",
    ["Open"] = "Abrir",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "Clique de novo em 5 segundos para voltar as opções desta aba ao padrão.",
    ["%s already does this, so it is off here."] = "%s já faz isso, por isso esta opção está desativada aqui.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s mostra a bússola agora, por isso a seta e a bússola da lista ficam de lado. Feche a janela dele ou desligue a bússola dele para vê-las.",
  },
  ruRU = {
    ["General"] = "Общие",
    ["Windows"] = "Окна",
    ["Window scale"] = "Масштаб окон",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "Размер всех окон Don: книга заданий, окна аддонов, настройки, диалоги. 80 % подходит для большинства экранов.",
    ["Options"] = "Параметры",
    ["Search all options"] = "Поиск по всем настройкам",
    ["More settings"] = "Дополнительные настройки",
    ["Reset this tab"] = "Сбросить эту вкладку",
    ["Tools"] = "Инструменты",
    ["Status"] = "Статус",
    ["Commands"] = "Команды",
    ["Nothing found. Try another word."] = "Ничего не найдено. Попробуйте другое слово.",
    ["Needs: %s"] = "Нужно: %s",
    ["Open"] = "Открыть",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "Нажмите ещё раз в течение 5 секунд, чтобы вернуть настройки этой вкладки по умолчанию.",
    ["%s already does this, so it is off here."] = "Это уже делает %s, поэтому здесь функция отключена.",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s сейчас показывает компас, поэтому стрелка и компас списка остаются в стороне. Закройте его окно или отключите его компас, чтобы увидеть их.",
  },
  zhTW = {
    ["General"] = "一般",
    ["Windows"] = "視窗",
    ["Window scale"] = "視窗縮放",
    ["The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."] = "所有 Don 視窗的大小：任務書、插件視窗、設定、對話框。80 % 適合大多數螢幕。",
    ["Options"] = "選項",
    ["Search all options"] = "搜尋所有選項",
    ["More settings"] = "更多設定",
    ["Reset this tab"] = "重設此分頁",
    ["Tools"] = "工具",
    ["Status"] = "狀態",
    ["Commands"] = "指令",
    ["Nothing found. Try another word."] = "找不到結果，請換個字試試。",
    ["Needs: %s"] = "需要：%s",
    ["Open"] = "開啟",
    ["Click again within 5 seconds to put this tab's settings back to their defaults."] = "5 秒內再按一次，即可將此分頁的設定恢復預設值。",
    ["%s already does this, so it is off here."] = "%s 已提供這項功能，因此這裡已關閉。",
    ["%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them."] = "%s 目前顯示指南針,所以箭頭和清單的指南針暫時退到一旁。關閉它的視窗或關閉它的指南針即可看到。",
  },
}
local LOCALE_WORDS = WORDS[type(GetLocale) == "function" and GetLocale() or "enUS"]

-- the window's own words: the kit's translation (above), else the first addon that brings labels(), else English
local function Label(text)
  local own = LOCALE_WORDS and LOCALE_WORDS[text]
  if own then return own end
  for _, id in ipairs(O.ids) do
    local s = O.addons[id]
    if s and type(s.labels) == "function" then
      local t = Safe("labels", s.labels, text)
      if type(t) == "string" and t ~= "" then return t end
    end
  end
  return text
end
O.Label = Label

local function T(spec, s)
  if s == nil then return "" end
  local t = spec.T and Safe("T", spec.T, s)
  return type(t) == "string" and t or tostring(s)
end
local function DB(spec) return (spec.db and Safe("db", spec.db)) or {} end
local function Default(spec, key) return spec.default and Safe("default", spec.default, key) end
local Index
local function Changed(spec, key)
  if spec.changed then Safe("changed", spec.changed, key) end
  -- (minor 5) a DonCore item (the minimap switch) refreshes itself
  if spec.fromSettings or not Index then return end
  local item = Index(spec).items[key]
  if item and item.donCommon and item.onChange then Safe("onChange " .. tostring(key), item.onChange, DB(spec)[key]) end
end
local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- the addon's icon from its toc (## IconTexture), shown on the right when a tab has no picture of its own
local function TocIcon(addon)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  if type(get) ~= "function" or type(addon) ~= "string" then return nil end
  local ok, v = pcall(get, addon, "IconTexture")
  return ok and type(v) == "string" and v ~= "" and v or nil
end

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------
function O.Register(id, spec)
  if type(id) ~= "string" or type(spec) ~= "table" or type(spec.tabs) ~= "table" then return nil end
  if not O.addons[id] then O.ids[#O.ids + 1] = id end
  spec.id = id
  spec._index = nil
  spec.icon = spec.icon or TocIcon(spec.addon or id)
  O.addons[id] = spec
  table.sort(O.ids, function(a, b)
    local x, y = tonumber(O.addons[a].order) or 50, tonumber(O.addons[b].order) or 50
    if x ~= y then return x < y end
    return a < b
  end)
  if O.win and O.win:IsShown() then O.Render() end
  -- (minor 4) an addon that comes after the login brings its kept window scale
  if O.loggedIn and id ~= O.GENERAL and O.LoadScale then Safe("load scale", O.LoadScale) end
  return spec
end

-- the options of pages() by key, the page buttons by the section they stand in, the tools by name
function Index(spec)
  if spec._index then return spec._index end
  local ix = { items = {}, buttons = {}, tools = {} }
  for _, page in ipairs((spec.pages and Safe("pages", spec.pages)) or {}) do
    local section
    for _, item in ipairs(page.items or {}) do
      if item.header then section = item.header end
      if item.key then ix.items[item.key] = item end
      if item.kind == "button" and item.optKey then ix.buttons[item.optKey] = item end
      if item.kind == "button" and not item.key and spec.buttonKey then
        local k = Safe("buttonKey", spec.buttonKey, section)
        if k then ix.buttons[k] = item end
      end
    end
  end
  for _, t in ipairs((spec.tools and Safe("tools", spec.tools)) or {}) do if t[1] then ix.tools[t[1]] = t end end
  spec._index = ix
  return ix
end
function O.Item(id, key)
  local spec = O.addons[id]
  if not spec then return nil end
  return Index(spec).items[key]
end

-- (01.11.2026) an addon that describes its options for DonCore's Settings module (ns.BuildSettings spec: name, status(),
-- tools, pages = { { title, tip, items } }, items with key, name, tip, kind, parent, onChange(value)) gets the same
-- options here: one tab per page, a last tab with the status, the tools and the commands. Values live in ns.db,
-- defaults in ns.defaults, texts through ns.L. Called by Settings (minor 2) from ns.BuildSettings.
function O.FromSettings(spec, ns)
  if type(spec) ~= "table" or type(ns) ~= "table" or type(spec.name) ~= "string" then return nil end
  local function L(s) return ns.L and ns.L[s] or s end
  local tabs, byKey, toolNames = {}, {}, {}
  for p, page in ipairs(spec.pages or {}) do
    local main = {}
    for i, item in ipairs(page.items or {}) do
      if item.header then
        main[#main + 1] = "header:" .. item.header
      elseif item.kind == "button" then
        item.optKey = item.optKey or ("button:" .. p .. ":" .. i)
        main[#main + 1] = item.optKey
      elseif item.key then
        main[#main + 1] = item.key
        byKey[item.key] = item
      end
    end
    tabs[#tabs + 1] = { key = "page" .. p, title = page.title, text = page.tip or page.title, main = main,
      preview = type(page.preview) == "function" and page.preview or nil }
  end
  for _, t in ipairs(spec.tools or {}) do toolNames[#toolNames + 1] = t[1] end
  if spec.status or #toolNames > 0 or spec.help then
    tabs[#tabs + 1] = { key = "tools", title = "Tools", text = "Status", status = true,
      tools = #toolNames > 0 and toolNames or nil }
  end
  return O.Register(spec.name, {
    name = spec.name, order = spec.order or 20, icon = spec.icon, addon = spec.addon or spec.name, tabs = tabs,
    pages = function() return spec.pages end,
    tools = function() return spec.tools end,
    db = function() return ns.db end,
    default = function(key) return ns.defaults and ns.defaults[key] end,
    changed = function(key)
      local item = byKey[key]
      if item and item.onChange then Safe("onChange " .. key, item.onChange, ns.db[key]) end
      if ns.RefreshSettingsUI then Safe("refresh", ns.RefreshSettingsUI) end
    end,
    T = L, labels = function(s) return L(s) end,
    status = spec.status, help = spec.help, fromSettings = true,
  })
end

local function TabOf(spec, key)
  for _, t in ipairs(spec and spec.tabs or {}) do if t.key == key then return t end end
end
local function ParentOff(spec, item) return item.parent and not DB(spec)[item.parent] end
local function Same(a, b) return a == b or (a ~= nil and b ~= nil and tostring(a) == tostring(b)) end

-- a picture: a file name in the addon's media folder, a full path or a file ID
local function PicPath(spec, p)
  if type(p) == "number" then return p end
  if type(p) ~= "string" or p == "" then return nil end
  if p:find("[\\/]") then return p end
  return (spec.media or "") .. p
end

-- a slider's value as text: its own format, else percent
function O.ValueText(item, v)
  if item.format then return Safe("format", item.format, v) or tostring(v) end
  return ("%d%%"):format((tonumber(v) or 0) * 100 + 0.5)
end

local function DropItems(item)
  local list = item.options
  -- a list that fails shows the stored value only (quietly, as the old window did)
  if type(list) == "function" then local ok, l = pcall(list) list = ok and l or nil end
  local out = {}
  for _, o in ipairs(type(list) == "table" and list or {}) do out[#out + 1] = { value = o[1], text = tostring(o[2] or o[1]) } end
  return out
end

---------------------------------------------------------------------------
-- Entries: what the middle shows, built fresh on every Render
--   { kind = "header" | "more" | "option" | "tool" | "text", ... }
---------------------------------------------------------------------------
local function OptionEntries(out, spec, keys, ix)
  local inList, done, kids = {}, {}, {}
  for _, k in ipairs(keys) do inList[k] = true end
  for _, k in ipairs(keys) do
    local it = ix.items[k]
    if it and it.parent and inList[it.parent] then
      kids[it.parent] = kids[it.parent] or {}
      table.insert(kids[it.parent], k)
    end
  end
  local function Add(k, indent)
    local it = ix.items[k] or (k:sub(1, 7) == "button:" and ix.buttons[k])
    if it then out[#out + 1] = { kind = "option", spec = spec, key = k, item = it, indent = indent } end
    if it and it.kind == "checklist" then
      for _, o in ipairs(DropItems(it)) do
        out[#out + 1] = { kind = "option", spec = spec, key = k, item = it, choice = o, indent = true }
      end
    end
  end
  for _, k in ipairs(keys) do
    local it = ix.items[k]
    if k:sub(1, 7) == "header:" then
      out[#out + 1] = { kind = "header", text = T(spec, k:sub(8)) }
    elseif not done[k] and not (it and it.parent and inList[it.parent]) then
      -- sub-options at any depth (Geardon: soonLevels under arrowSoon under upgradeArrow), indented once
      local function Tree(key, indent)
        done[key] = true
        Add(key, indent)
        for _, c in ipairs(kids[key] or {}) do if not done[c] then Tree(c, true) end end
      end
      Tree(k)
    end
  end
end

local function CountKeys(list)
  local n = 0
  for _, k in ipairs(list) do if k:sub(1, 7) ~= "header:" then n = n + 1 end end
  return n
end

local function Matches(spec, item, q)
  local function Has(s) return s ~= nil and T(spec, s):lower():find(q, 1, true) ~= nil end
  return Has(item.name) or Has(item.tip)
end

local function Lines(text)
  local out = {}
  for line in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do out[#out + 1] = line end
  return out
end

local function CurrentSpec()
  local st = O.state
  local spec = st.addon and O.addons[st.addon]
  if not spec then spec = O.addons[O.ids[1]] st.addon = spec and spec.id end
  return spec
end
local function CurrentTab(spec)
  if not spec then return nil end
  local st = O.state
  local tab = TabOf(spec, st.tabOf[spec.id]) or spec.tabs[1]
  st.tabOf[spec.id] = tab and tab.key
  return tab
end

local function Entries()
  local out, st = {}, O.state
  local q = (st.query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if q ~= "" then
    for _, id in ipairs(O.ids) do
      local spec = O.addons[id]
      local ix = Index(spec)
      for _, tab in ipairs(spec.tabs) do
        local hits = {}
        for _, list in ipairs({ tab.main or {}, tab.more or {} }) do
          for _, k in ipairs(list) do
            local it = ix.items[k] or ix.buttons[k]
            if it and Matches(spec, it, q) then hits[#hits + 1] = { kind = "option", spec = spec, key = k, item = it } end
          end
        end
        for _, list in ipairs({ tab.top or {}, tab.tools or {} }) do
          for _, name in ipairs(list) do
            local t = ix.tools[name]
            if t and Matches(spec, { name = t[1], tip = t[4] }, q) then hits[#hits + 1] = { kind = "tool", spec = spec, tool = t } end
          end
        end
        if #hits > 0 then
          out[#out + 1] = { kind = "header", text = Plain(spec.name or id) .. " · " .. T(spec, tab.title) }
          for _, e in ipairs(hits) do out[#out + 1] = e end
        end
      end
    end
    if #out == 0 then out[1] = { kind = "text", text = Label("Nothing found. Try another word."), color = "quiet" } end
    return out
  end
  local spec = CurrentSpec()
  local tab = CurrentTab(spec)
  if not tab then return out end
  local ix = Index(spec)
  if tab.status and spec.status then
    out[#out + 1] = { kind = "header", text = Label("Status") }
    for _, line in ipairs((Safe("status", spec.status)) or {}) do
      for _, l in ipairs(Lines(line)) do out[#out + 1] = { kind = "text", text = l, color = "title" } end
    end
  end
  for _, name in ipairs(tab.top or {}) do
    if ix.tools[name] then out[#out + 1] = { kind = "tool", spec = spec, tool = ix.tools[name] } end
  end
  if tab.main then OptionEntries(out, spec, tab.main, ix) end
  if tab.more and #tab.more > 0 then
    local key = spec.id .. ":" .. tab.key
    out[#out + 1] = { kind = "more", key = key, open = st.more[key] and true or false,
      text = Label("More settings") .. (" (%d)"):format(CountKeys(tab.more)) }
    if st.more[key] then OptionEntries(out, spec, tab.more, ix) end
  end
  if tab.tools and #tab.tools > 0 then
    out[#out + 1] = { kind = "header", text = Label("Tools") }
    for _, name in ipairs(tab.tools) do
      if ix.tools[name] then out[#out + 1] = { kind = "tool", spec = spec, tool = ix.tools[name] } end
    end
  end
  if tab.status and spec.help then
    out[#out + 1] = { kind = "header", text = Label("Commands") }
    for _, l in ipairs(Lines(Safe("help", spec.help))) do out[#out + 1] = { kind = "text", text = l, color = "body" } end
  end
  return out
end
O.Entries = Entries -- (tests)

---------------------------------------------------------------------------
-- Rows: pooled per kind; an option row carries one control of each sort and shows the one it needs
---------------------------------------------------------------------------
local pools, used = { option = {}, header = {}, text = {} }, {}
local Render, Preview

local function Hover(r)
  O.state.hovered = r and r.entry
  Preview()
end

local function NewOptionRow(parent)
  local Kit = K()
  local r = Kit.OptionRow(parent, {})
  r.name = r.label
  r.toggle = Kit.Toggle(r, { set = function(v)
    local e = r.entry
    if not e then return end
    -- a tool with a state (on / off): its function switches, the switch shows the state it reports
    -- (a window that fades out reports its state a moment later: draw again then)
    local function Again() Render() if C_Timer and C_Timer.After then C_Timer.After(0.5, function() if O.win and O.win:IsShown() then Render() end end) end end
    if e.kind == "tool" then Safe("tool", e.tool[3]) Again() return end
    if e.item and e.item.kind == "button" then Safe("button", e.item.onClick) Again() return end
    if e.choice then
      local it = e.item
      if it.setChecked then Safe("checklist set", it.setChecked, e.choice.value, v and true or false)
      else
        local db = DB(e.spec)
        if type(db[e.key]) ~= "table" then db[e.key] = {} end
        db[e.key][e.choice.value] = v and true or nil
      end
      Changed(e.spec, e.key)
      Render()
      return
    end
    DB(e.spec)[e.key] = v and true or false
    Changed(e.spec, e.key)
    Render()
  end })
  r.drop = Kit.Dropdown(r, { width = 160, items = function() return r.dropItems or {} end, set = function(v)
    local e = r.entry
    if not e then return end
    if e.item.kind == "choice" then
      Safe("choice set", e.item.set, v)
    elseif not Same(DB(e.spec)[e.key], v) then
      DB(e.spec)[e.key] = v
      Changed(e.spec, e.key)
    end
    Render()
  end })
  r.button = Kit.Button(r, "", { small = true })
  r.sliders = {}
  for _, c in ipairs({ r.toggle, r.drop, r.button }) do
    c:ClearAllPoints()
    c:SetPoint("RIGHT", r, "RIGHT", -Kit.SIZE.pad, 0)
    c:Hide()
  end
  r:RegisterForClicks("LeftButtonUp")
  r:SetScript("OnClick", function(self) if self.onClick and not self._disabled then Safe("row click", self.onClick, self) end end)
  local enter = r:GetScript("OnEnter")
  r:SetScript("OnEnter", function(self) if enter then enter(self) end Hover(self) end)
  return r
end

-- a slider per option (its range is fixed when it is made), kept on the row that shows it
local sliders = {}
local function SliderFor(r, e)
  local Kit = K()
  local id = e.spec.id .. ":" .. e.key
  local s = sliders[id]
  if not s then
    local item = e.item
    s = Kit.Slider(r, { min = item.min or 0, max = item.max or 1, step = item.step or 0.05, width = 200,
      format = function(v) return O.ValueText(item, v) end,
      set = function(v)
        local cur = s.entry
        if not cur or ParentOff(cur.spec, cur.item) then return end
        DB(cur.spec)[cur.key] = v
        Changed(cur.spec, cur.key)
        Preview()
      end })
    sliders[id] = s
  end
  s:SetParent(r)
  s:ClearAllPoints()
  s:SetPoint("RIGHT", r, "RIGHT", -Kit.SIZE.pad, 0)
  s.entry, s.row = e, r
  s:Show()
  return s
end

local function Take(kind, parent)
  local pool = pools[kind]
  pool.used = (pool.used or 0) + 1
  local r = pool[pool.used]
  if not r then
    local Kit = K()
    if kind == "option" then
      r = NewOptionRow(parent)
    elseif kind == "header" then
      r = Kit.GroupHeader(parent)
      r.name = r.text
      r:RegisterForClicks("LeftButtonUp")
      r:SetScript("OnClick", function(self) if self.onClick then Safe("header click", self.onClick, self) end end)
    else
      r = CreateFrame("Frame", nil, parent)
      r:SetHeight(TEXT_H)
      r.name = Kit.Text(r, "sub", Kit.C.body)
      r.name:SetPoint("LEFT", Kit.SIZE.pad, 0)
    end
    r.kind = kind
    pool[pool.used] = r
  end
  used[#used + 1] = r
  r.entry, r.item, r.optKey, r.onClick, r.btn = nil, nil, nil, nil, nil
  r:ClearAllPoints()
  r:Show()
  return r
end

local function FillOption(r, e)
  local Kit = K()
  if e.kind == "tool" and not e.item then e.item = { name = e.tool[1], tip = e.tool[4] } end
  local spec, item, key = e.spec, e.item, e.key
  r.entry, r.item, r.optKey = e, item, key
  r.indent = e.indent and (Kit.SIZE.indent - Kit.SIZE.pad) or 0
  r.toggle:Hide() r.drop:Hide() r.button:Hide()
  if r.slider then if r.slider.row == r then r.slider:Hide() end r.slider = nil end
  local blocker = item.blockedBy and Safe("blockedBy", item.blockedBy)
  local off = ParentOff(spec, item) or blocker
  local db = DB(spec)
  local desc, warn = item.tip and T(spec, item.tip) or "", false
  if e.choice then
    -- one entry of a checklist: a switch, the entry's text as the name
    local v
    if item.isChecked then v = Safe("checklist get", item.isChecked, e.choice.value)
    else local t = db[key] v = type(t) == "table" and t[e.choice.value] end
    r.toggle:SetValue(v and true or false)
    r.control = r.toggle
    if not off then r.onClick = function() r.toggle:GetScript("OnClick")(r.toggle, "LeftButton") end end
    r.btn = r.control
    r.control:Show()
    r:SetText(e.choice.text, "")
    r:SetDisabled(off and true or false)
    return
  elseif item.kind == "checklist" then
    -- the checklist's own row: its name and explanation, the switches follow
    r.control, r.btn = nil, nil
    r:SetText(T(spec, item.name), desc)
    local c = Kit.C.muted
    r.desc:SetTextColor(c[1], c[2], c[3], 1)
    r:SetDisabled(off and true or false)
    return
  elseif e.kind == "tool" then
    local t = e.tool
    if type(t.state) == "function" then
      -- (02.11.2026, Daniel: "da ist keine visuelle bestätigung, was gerade ist") a tool that switches something on and
      -- off (t.state() -> true / false) is a switch showing its state, not a button
      r.toggle:SetValue(Safe("tool state", t.state) and true or false)
      r.control = r.toggle
      r.onClick = function() r.toggle:GetScript("OnClick")(r.toggle, "LeftButton") end
    else
      r.button:SetText(T(spec, t[2]))
      r.button._onClick = function() Safe("tool", t[3]) Render() end
      r.control = r.button
    end
    r:SetText(T(spec, t[1]), desc)
  elseif item.kind == "slider" then
    local s = SliderFor(r, e)
    r.slider = s
    s:SetValue(tonumber(db[key]) or tonumber(Default(spec, key)) or item.min or 0)
    r.control = s
  elseif item.kind == "dropdown" or item.kind == "choice" then
    if item.kind == "choice" then
      local list = {}
      for i, c in ipairs(item.choices or {}) do list[i] = { value = i, text = T(spec, c) } end
      r.dropItems = list
      r.drop:Update(item.get and Safe("choice get", item.get) or 1)
      local why = item.status and Safe("status", item.status)
      if why then desc, warn = tostring(why), true end
    else
      r.dropItems = DropItems(item)
      local v = db[key]
      for _, o in ipairs(r.dropItems) do if Same(o.value, v) then v = o.value break end end
      r.drop:Update(v)
      -- a value the list does not know: shown as it is stored
      if r.drop.text:GetText() == "" and v ~= nil then r.drop.text:SetText(tostring(v)) end
    end
    r.control = r.drop
    if not off then r.onClick = function() r.drop:Open() end end
  elseif item.kind == "button" and type(item.state) == "function" then
    -- a page button that switches something (a window shown or not): a switch with its state, like a tool with state
    r.toggle:SetValue(Safe("button state", item.state) and true or false)
    r.control = r.toggle
    r.onClick = function() r.toggle:GetScript("OnClick")(r.toggle, "LeftButton") end
  elseif item.kind == "button" then
    r.button:SetText(item.button and T(spec, item.button) or Label("Open"))
    r.button._onClick = function() Safe("button", item.onClick) Render() end
    r.control = r.button
  else
    local on = db[key] and true or false
    r.toggle:SetValue(on)
    local why = on and item.status and Safe("status", item.status)
    if why then desc, warn = tostring(why), true end
    r.control = r.toggle
    if not off then r.onClick = function() r.toggle:GetScript("OnClick")(r.toggle, "LeftButton") end end
  end
  r.btn = r.control
  r.control:Show()
  if e.kind ~= "tool" then r:SetText(T(spec, item.name), desc) end
  local c = warn and Kit.C.yellow or Kit.C.muted
  r.desc:SetTextColor(c[1], c[2], c[3], 1)
  r:SetDisabled(off and true or false)
end

local function Place(e, parent, y, w)
  local Kit = K()
  local S = Kit.SIZE
  local r
  if e.kind == "option" or e.kind == "tool" then
    r = Take("option", parent)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    r:SetHeight(S.row)
    FillOption(r, e)
    r:Layout(w)
    return y + S.row
  elseif e.kind == "header" or e.kind == "more" then
    r = Take("header", parent)
    r.entry = e
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(y + (y > 0 and S.unit or 0)))
    r:SetSize(w, S.sub)
    r._w = w
    r:SetItem({ text = e.text, static = e.kind ~= "more", collapsed = not e.open })
    if e.kind == "more" then
      r.onClick = function() O.state.more[e.key] = not O.state.more[e.key] Render() end
    end
    return y + S.sub + (y > 0 and S.unit or 0)
  end
  r = Take("text", parent)
  r.entry = e
  r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
  r:SetSize(w, TEXT_H)
  local c = Kit.C[e.color or "body"] or Kit.C.body
  r.name:SetTextColor(c[1], c[2], c[3], 1)
  r.name:SetText(e.text or "")
  Kit.Fit(r.name, w - 2 * S.pad)
  return y + TEXT_H
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function NavItems()
  local items, sel = {}, nil
  local st = O.state
  local spec = CurrentSpec()
  local tab = CurrentTab(spec)
  for _, id in ipairs(O.ids) do
    local s = O.addons[id]
    items[#items + 1] = { kind = "group", static = true, text = Plain(s.name or id) }
    for _, t in ipairs(s.tabs) do
      local title = T(s, t.title)
      local it = { kind = "zone", text = title, short = title:sub(1, 2), id = id, tab = t.key }
      items[#items + 1] = it
      if (st.query or "") == "" and spec == s and tab == t then sel = it end
    end
  end
  return items, sel
end

Preview = function()
  local win = O.win
  if not (win and win.preview and win.preview:IsShown()) then return end
  local p = win.preview
  local e = O.state.hovered
  local spec = (e and e.spec) or CurrentSpec()
  if not spec then return end
  local tab = CurrentTab(spec) or {}
  local it = e and e.item
  local pic = (it and PicPath(spec, it.pic)) or ((O.state.query or "") == "" and PicPath(spec, tab.pic))
  local icon = not pic and (PicPath(spec, tab.icon) or (tab.key and spec.icons and spec.icons[tab.key]) or spec.icon or ICON_FALLBACK)
  local w = (p._w or PREV_W) - 24
  p.title:ClearAllPoints()
  -- the tab draws its own card (pins in their looks and sizes) into a frame of its own (one per addon and tab, so the
  -- parts of one tab never show under another's)
  p.customs = p.customs or {}
  local own = not pic and type(tab.preview) == "function" and (spec.id .. ":" .. tostring(tab.key)) or nil
  for k, f in pairs(p.customs) do if k ~= own then f:Hide() end end
  p.custom = nil
  if own then
    local f = p.customs[own]
    if not f then
      f = CreateFrame("Frame", nil, p)
      f:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -12)
      p.customs[own] = f
    end
    p.custom = f
    local ch = floor(w * 0.6)
    f:SetSize(w, ch)
    f:Show()
    p.pic:Hide()
    Safe("preview", tab.preview, f, w, ch)
    p.title:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -14)
  else
    p.title:SetPoint("TOPLEFT", p.pic, "BOTTOMLEFT", 0, -14)
  end
  if p.custom and p.custom:IsShown() then
    -- (drawn above)
  elseif pic then
    p.pic:SetSize(w, w / 2)
    p.pic:SetTexture(pic)
    pcall(p.pic.SetTexCoord, p.pic, 0, 1, 0, 1)
  else
    p.pic:SetSize(64, 64)
    p.pic:SetTexture(icon)
    pcall(p.pic.SetTexCoord, p.pic, 0.08, 0.92, 0.08, 0.92)
  end
  if not (p.custom and p.custom:IsShown()) then p.pic:Show() end
  p.title:SetText(it and T(spec, it.name) or T(spec, tab.title))
  K().Fit(p.title, w)
  local text = it and it.tip and T(spec, it.tip) or T(spec, tab.text)
  if it and it.blockedBy and Safe("blockedBy", it.blockedBy) then
    -- (minor 2) blockedBy may return { reason = "..." }: its own words instead of "%s already does this"
    local why = Safe("blockedBy", it.blockedBy)
    text = (type(why) == "table" and tostring(why.reason or "") or Label("%s already does this, so it is off here."):format(tostring(why))) .. "\n\n" .. text
  elseif it and it.status and it.key and DB(spec)[it.key] and Safe("status", it.status) then
    -- (25.10., Questdon) another addon does the job now (Leveldon's compass)
    text = Label("%s shows the compass now, so the arrow and the list's compass stay aside. Close its window or switch off its compass to see them.")
      :format(tostring(Safe("status", it.status))) .. "\n\n" .. text
  elseif it and ParentOff(spec, it) then
    local par = Index(spec).items[it.parent]
    text = Label("Needs: %s"):format(par and T(spec, par.name) or tostring(it.parent)) .. "\n\n" .. text
  end
  p.text:SetText(text)
end
O.Preview = function() return Preview() end

local function LayoutRows()
  local win = O.win
  if not win then return end
  local w = win._cw or 400
  for _, pool in pairs(pools) do pool.used = 0 end
  used = {}
  local y = K().SIZE.pad
  for _, e in ipairs(win.entries or {}) do y = Place(e, win.area.content, y, w) end
  for _, pool in pairs(pools) do for i = (pool.used or 0) + 1, #pool do pool[i]:Hide() end end
  win.area:SetContentHeight(y + K().SIZE.pad)
end

local function Layout(win, w, h, mode)
  if not win.nav then return end
  local Kit = K()
  local S = Kit.SIZE
  local rail = mode == "rail"
  local navW = rail and S.rail or NAV_W
  win.nav:Layout(h, rail)
  local prevW = mode == "full" and PREV_W or 0
  local cw = w - navW - 2 * S.pad - (prevW > 0 and prevW + S.pad or 0)
  win._cw = cw - 6
  win.area:ClearAllPoints()
  win.area:SetPoint("TOPLEFT", win.body, "TOPLEFT", navW + S.pad, 0)
  win.area:Resize(cw, h)
  if prevW > 0 then
    win.preview:Show()
    win.preview._w = prevW
    win.preview:SetSize(prevW, h - 2 * S.pad)
    win.preview.title:SetWidth(prevW - 24)
    win.preview.text:SetWidth(prevW - 24)
  else
    win.preview:Hide()
  end
  local sw = min(260, max(140, floor(w * 0.28)))
  win.search:Layout(sw)
  Kit.Fit(win.title, max(40, w - sw - 3 * S.pad - S.buttonSmall - S.gap))
  if win.reset then win.reset:ClearAllPoints() win.reset:SetPoint("RIGHT", win.footer, "RIGHT", -S.pad - 16, 0) end
  LayoutRows()
  Preview()
end

local function SetStatus(text)
  local win = O.win
  if win and win.status then win.status:SetText(text or "") K().Fit(win.status, (win._w or 600) - 200) end
end

local function ResetTab()
  local spec = CurrentSpec()
  local tab = CurrentTab(spec)
  if not (spec and tab and tab.main) then return end
  local key, now = spec.id .. ":" .. tab.key, (type(GetTime) == "function" and GetTime()) or 0
  local ask = O.state.resetAsk
  if not (ask and ask.key == key and now - ask.t <= RESET_SECONDS) then
    O.state.resetAsk = { key = key, t = now }
    SetStatus(Label("Click again within 5 seconds to put this tab's settings back to their defaults."))
    return false
  end
  O.state.resetAsk = nil
  local ix = Index(spec)
  local db = DB(spec)
  for _, list in ipairs({ tab.main or {}, tab.more or {} }) do
    for _, k in ipairs(list) do
      if ix.items[k] and ix.items[k].key then db[k] = Default(spec, k) Changed(spec, k) end
    end
  end
  SetStatus("")
  Render()
  return true
end
O.ResetTab = ResetTab

local function Create()
  local Kit = K()
  if not Kit then return nil end
  local S = Kit.SIZE
  local win = Kit.Window("DonCoreOptions", { title = Label("Options"), width = 980, height = 640, footer = true,
    store = O.store, onLayout = Layout })
  O.win = win
  win.search = Kit.SearchBox(win.header, { placeholder = Label("Search all options"), onChange = function(text)
    O.state.query, O.state.hovered = text or "", nil
    win.area:SetOffset(0)
    Render()
  end })
  win.search:SetPoint("RIGHT", win.close, "LEFT", -S.gap, 0)
  win.nav = Kit.Sidebar(win.body, { onClick = function(it)
    if not it.id then return end
    O.state.addon, O.state.hovered, O.state.query = it.id, nil, ""
    O.state.tabOf[it.id] = it.tab
    win.search:SetText("")
    win.search:ClearFocus()
    win.area:SetOffset(0)
    Render()
  end })
  win.nav:SetPoint("TOPLEFT", win.body, "TOPLEFT", 0, 0)
  win.area = Kit.ScrollArea(win.body)
  local wheel = win.area:GetScript("OnMouseWheel")
  win.area:SetScript("OnMouseWheel", function(self, d)
    if Kit._menu and Kit._menu:IsShown() then Kit._menu:Hide() end
    if wheel then wheel(self, d) end
  end)
  -- the picture and the explanation on the right, a card
  local p = CreateFrame("Frame", nil, win.body)
  win.preview = p
  p:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", -S.pad, -S.pad)
  local bg = p:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bg:SetAllPoints(p)
  bg:SetVertexColor(Kit.C.card[1], Kit.C.card[2], Kit.C.card[3], 1)
  p.pic = p:CreateTexture(nil, "ARTWORK")
  p.pic:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -12)
  p.title = Kit.Text(p, "title", Kit.C.txGold)
  p.title:SetPoint("TOPLEFT", p.pic, "BOTTOMLEFT", 0, -14)
  -- the explanation is the one text of the window that wraps (it is read, not scanned)
  p.text = p:CreateFontString(nil, "OVERLAY")
  local fo = Kit.Font("row")
  if fo then pcall(p.text.SetFontObject, p.text, fo) end
  p.text:SetTextColor(Kit.C.body[1], Kit.C.body[2], Kit.C.body[3], 1)
  p.text:SetJustifyH("LEFT")
  pcall(p.text.SetJustifyV, p.text, "TOP")
  pcall(p.text.SetWordWrap, p.text, true)
  p.text:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -10)
  -- footer: what to know, "Reset this tab"
  win.reset = Kit.Button(win.footer, Label("Reset this tab"), { small = true, onClick = function() ResetTab() end })
  win:SetScript("OnHide", function()
    if Kit._menu and Kit._menu:IsShown() then Kit._menu:Hide() end
    O.state.hovered = nil
  end)
  win:Layout()
  win:Hide()
  return win
end

Render = function()
  local win = O.win
  if not win then return end
  local Kit = K()
  if Kit._menu and Kit._menu:IsShown() then Kit._menu:Hide() end
  local items, sel = NavItems()
  win.nav.list:SetItems(items)
  win.nav.list:Select(sel)
  win.entries = Entries()
  local spec = CurrentSpec()
  local tab = CurrentTab(spec)
  local searching = (O.state.query or "") ~= ""
  win.reset:SetShown(not searching and tab and tab.main and true or false)
  if not (O.state.resetAsk) then
    SetStatus(searching and "" or (spec and (Plain(spec.name or spec.id) .. " · " .. T(spec, tab and tab.title)) or ""))
  end
  LayoutRows()
  Preview()
end
O.Render = function() return Render() end

---------------------------------------------------------------------------
-- Opening
---------------------------------------------------------------------------
-- id: the addon to show (default: the one shown last, else the first); tab: its tab key
function O.Open(id, tab)
  if not O.win and not Create() then return nil end
  local st = O.state
  if id and O.addons[id] then st.addon = id end
  local spec = CurrentSpec()
  if spec and tab and TabOf(spec, tab) then st.tabOf[spec.id] = tab end
  st.hovered, st.query, st.resetAsk = nil, "", nil
  O.win.search:SetText("")
  O.win.area:SetOffset(0)
  O.win:Show()
  pcall(O.win.Raise, O.win)
  Render()
  -- the left list starts at the addon's own section (its title on top), so its tabs need no scrolling (Daniel 03.11.2026)
  local list = O.win.nav.list
  if spec and list.ScrollTo then
    local name = Plain(spec.name or spec.id)
    for _, it in ipairs(list.items or {}) do
      if it.kind == "group" and it.text == name then list:ScrollTo(it, true) break end
    end
  end
  return O.win
end
function O.Toggle(id)
  if O.win and O.win:IsShown() and (not id or O.state.addon == id) then O.win:Hide() return end
  O.Open(id)
end
function O.Search(text)
  O.state.query, O.state.hovered = text or "", nil
  if O.win then O.win.search:SetText(text or "") end
  Render()
end
-- (01.11.2026, Daniel: "jedes bekommt natürlich passend das gleiche einstellungszahnrädchen"; "Alles was überall gleich
-- sein kann, sollten die addons aus dem gleichen kit ziehen") the cog of every Don addon: Kit.IconButton "options",
-- tooltip "Options", a click opens this window at the addon (and tab). The addon only places it:
--   local cog = Opt.Button(header, "Geardon")   cog:SetPoint("RIGHT", close, "LEFT", -6, 0)
function O.Button(parent, id, tab)
  local Kit = K()
  if not Kit then return nil end
  local b = Kit.IconButton(parent, "options", { tooltip = Label("Options"),
    onClick = function() O.Open(id, tab) end })
  b.donOptionsId = id
  return b
end

-- the button on Blizzard's AddOns page: closes Blizzard's settings, opens this window at the addon
function O.OpenFromBlizzard(id, tab)
  if SettingsPanel and SettingsPanel.Hide then pcall(SettingsPanel.Hide, SettingsPanel) end
  return O.Open(id, tab)
end

function O.Frame() return O.win end
function O.Rows() local out = {} for i, r in ipairs(used) do out[i] = r end return out end -- (tests)
function O.NavItems() return (NavItems()) end -- (tests)

---------------------------------------------------------------------------
-- (minor 4) page "General": the window scale of every Kit window (Kit minor 13)
---------------------------------------------------------------------------
O.GENERAL = "DonGeneral"
O.general = O.general or {}
local function KitScale() return Core:Get("Kit", 13) end
local function Stamp() return (type(time) == "function" and time()) or (type(GetTime) == "function" and GetTime()) or 0 end

local function ApplyScaleNow()
  local Kit = KitScale()
  if Kit and O.pendingScale then Kit.SetScale(O.pendingScale) end
  O.pendingScale = nil
end
-- while the slider is held the windows (this one too) keep their size: the scale follows when the button is let go
local function ApplyScale(v)
  O.pendingScale = v
  local f = O.events
  if f and type(IsMouseButtonDown) == "function" and IsMouseButtonDown("LeftButton") then
    f:SetScript("OnUpdate", function(self)
      if IsMouseButtonDown("LeftButton") then return end
      self:SetScript("OnUpdate", nil)
      ApplyScaleNow()
    end)
  else
    ApplyScaleNow()
  end
end

-- every Don addon keeps the value, so it stays with any one of them installed
local function SpreadScale(v)
  local at = Stamp()
  for _, id in ipairs(O.ids) do
    local spec = O.addons[id]
    if id ~= O.GENERAL and spec then
      local db = spec.db and Safe("db", spec.db)
      if type(db) == "table" then db.donWindowScale, db.donWindowScaleAt = v, at end
    end
  end
end

-- the newest value of all addons (none kept: the default)
function O.LoadScale()
  local Kit = KitScale()
  if not Kit then return nil end
  local best, bestAt
  for _, id in ipairs(O.ids) do
    local spec = O.addons[id]
    local db = id ~= O.GENERAL and spec and spec.db and Safe("db", spec.db)
    local v = type(db) == "table" and tonumber(db.donWindowScale)
    if v then
      local at = tonumber(db.donWindowScaleAt) or 0
      if not bestAt or at > bestAt then best, bestAt = v, at end
    end
  end
  local v = Kit.SetScale(best or Kit.SCALE_DEFAULT)
  O.general.windowScale = v
  return v
end

local function RegisterGeneral()
  local Kit = KitScale()
  if not Kit or O.addons[O.GENERAL] then return end
  local TIP = "The size of every Don window: quest book, lists of the windows, options, dialogs. 80 % fits most screens."
  O.general.windowScale = O.general.windowScale or Kit.scale or Kit.SCALE_DEFAULT
  O.Register(O.GENERAL, {
    name = Label("General"), order = 1000, icon = "Interface\\Icons\\INV_Misc_Gear_01",
    tabs = { { key = "windows", title = "Windows", text = TIP, main = { "windowScale" } } },
    pages = function()
      return { { items = { { key = "windowScale", kind = "slider", name = "Window scale", tip = TIP,
        min = Kit.SCALE_MIN, max = Kit.SCALE_MAX, step = 0.05 } } } }
    end,
    -- the slider shows the scale in use (set elsewhere too), except while a held slider waits
    db = function()
      if not O.pendingScale then O.general.windowScale = Kit.scale or Kit.SCALE_DEFAULT end
      return O.general
    end,
    default = function(key) if key == "windowScale" then return Kit.SCALE_DEFAULT end end,
    changed = function(key)
      if key ~= "windowScale" then return end
      local v = tonumber(O.general.windowScale) or Kit.SCALE_DEFAULT
      SpreadScale(v)
      ApplyScale(v)
    end,
    T = function(text) return Label(text) end,
  })
end
RegisterGeneral()

-- at login every addon's SavedVariables are there: take the newest scale
O.events = O.events or (type(CreateFrame) == "function" and CreateFrame("Frame") or nil)
if O.events then
  pcall(O.events.RegisterEvent, O.events, "PLAYER_LOGIN")
  O.events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then O.loggedIn = true Safe("load scale", O.LoadScale) end
  end)
end

Core.slash = Core.slash or {}
Core.slash.options = function() O.Toggle() end

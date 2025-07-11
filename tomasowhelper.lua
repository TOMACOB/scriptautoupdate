-- Объединенный скрипт

script_name("TOMASOWHELPER")
script_version("12.07.2025")

local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local sampev = require('lib.samp.events')
local u8 = encoding.UTF8
local inicfg = require "inicfg"
local currentTab = imgui.new.int(0)
local promo = '#tomasow'
local min_HEALTH = 1
local strings = {
    'Вы успешно активировали промокод {FFFFFF}"(.-)"{33AA33}.',
    'Вам необходимо выполнить квест {FFFFFF}"Больше машин.."{33AA33} для получения {FFFFFF}"вознаграждения"',
    'Подробнее: {FFFFFF}"/quest"{33AA33} или клавиша {FFFFFF}"H"{33AA33} у .*'
}
local clists = {
    {
        0x009F00, -- grove.
        0xB313E7, -- ballas.
        0xFFDE24, -- vagos.
        0x2A9170, -- rifa.
        0x01FCFF, -- aztec.
        0xDDA701, -- lcn.
        0xFF0000, -- yakuza.
        0x114D71, -- russian mafia.
        0x333333, -- masked.
        0x00FFFFFF, -- bomj.
    },
}
local texts = {
    'Grove: {$CLR}$CNT {FFFFFF}| Ballas: {$CLR}$CNT {FFFFFF}| Vagos: {$CLR}$CNT {FFFFFF}| Rifa: {$CLR}$CNT {FFFFFF}| Aztecas: {$CLR}$CNT\nLCN: {$CLR}$CNT {FFFFFF}| Yakuza: {$CLR}$CNT {FFFFFF}| Russian Mafia: {$CLR}$CNT\nMasked: {$CLR}$CNT {FFFFFF}| Bomj: {$CLR}$CNT',
}
local cfg = "tomasowhelper.ini"
local poff = false
local healthCheckEnabled = imgui.new.bool(false)
local breakCheckEnabled = imgui.new.bool(false)
local deletebat = imgui.new.bool(false)
local autoexitdnk = imgui.new.bool(false)

-- Функция для автоматического обновления
function autoupdate(json_url, prefix, url)
    local dlstatus = require('moonloader').download_status
    local json = getWorkingDirectory() .. '\\'..thisScript().name..'-version.json'
    if doesFileExist(json) then os.remove(json) end
    downloadUrlToFile(json_url, json,
        function(id, status, p1, p2)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                if doesFileExist(json) then
                    local f = io.open(json, 'r')
                    if f then
                        local info = decodeJson(f:read('*a'))
                        updatelink = info.updateurl
                        updateversion = info.latest
                        f:close()
                        os.remove(json)
                        if updateversion ~= thisScript().version then
                            lua_thread.create(function(prefix)
                                local dlstatus = require('moonloader').download_status
                                local color = -1
                                sampAddChatMessage((prefix..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion), color)
                                wait(250)
                                downloadUrlToFile(updatelink, thisScript().path,
                                    function(id3, status1, p13, p23)
                                        if status1 == dlstatus.STATUS_DOWNLOADINGDATA then
                                            print(string.format('Загружено %d из %d.', p13, p23))
                                        elseif status1 == dlstatus.STATUS_ENDDOWNLOADDATA then
                                            print('Загрузка обновления завершена.')
                                            sampAddChatMessage((prefix..'Обновление завершено!'), color)
                                            goupdatestatus = true
                                            lua_thread.create(function() wait(500) thisScript():reload() end)
                                        end
                                        if status1 == dlstatus.STATUSEX_ENDDOWNLOAD then
                                            if goupdatestatus == nil then
                                                sampAddChatMessage((prefix..'Обновление прошло неудачно. Запускаю устаревшую версию..'), color)
                                                update = false
                                            end
                                        end
                                    end
                                )
                            end, prefix
                            )
                        else
                            update = false
                            print('v'..thisScript().version..': Обновление не требуется.')
                        end
                    end
                else
                    print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..url)
                    update = false
                end
            end
        end
    )
    while update ~= false do wait(100) end
end

function getCurrentServer(name)
    if name:find('Evolve%-Rp') then return 1 end
end

function chocount()
    current_server = getCurrentServer(sampGetCurrentServerName())
    assert(current_server, 'Server not found.')
    local text = texts[current_server]
    for i = 1, #clists[current_server] do
        local online = 0
        for l = 0, 1004 do
            if sampIsPlayerConnected(l) then
                if sampGetPlayerColor(l) == clists[current_server][i] then online = online + 1 end
            end
        end
        text = text:gsub('$CLR', ('%06X'):format(bit.band(clists[current_server][i], 0xFFFFFF)), 1)
        text = text:gsub('$CNT', online, 1)
    end
    for w in text:gmatch('[^\r\n]+') do sampAddChatMessage(w, -1)end
end

function handleTransportDialog(dialogId, style, title, button1, button2, text)
    if autoexitdnk[0] and text:find('Вы действительно желаете покинуть транспортное средство?') then
        sampSendDialogResponse(dialogId, 1, 0)
        sampSendChat('/de 20')
    end
end

function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if title:find('{.-}Регистрация | {.-}Приглашение') then
        sampSendDialogResponse(dialogId, 1, 0, promo)
        return false
    end
    handleTransportDialog(dialogId, style, title, button1, button2, text)
end

function sampev.onServerMessage(color, text)
    for k, v in ipairs(strings) do
        if text:find(v) then
            return false
        end
    end
    if breakCheckEnabled[0] and text:lower():find('ломка') then
        sampSendChat('/usedrugs 1')
    end
end

local function saveCheckboxStates()
    local cfg = inicfg.save({
        checkboxes = {
            healthCheckEnabled = healthCheckEnabled[0],
            breakCheckEnabled = breakCheckEnabled[0],
            deletebat = deletebat[0],
            autoexitdnk = autoexitdnk[0],
            poff = poff
        }
    }, cfg)
end

local function loadCheckboxStates()
    local loadedCfg = inicfg.load(nil, cfg)
    if loadedCfg and loadedCfg.checkboxes then
        healthCheckEnabled[0] = loadedCfg.checkboxes.healthCheckEnabled or false
        breakCheckEnabled[0] = loadedCfg.checkboxes.breakCheckEnabled or false
        deletebat[0] = loadedCfg.checkboxes.deletebat or false
        autoexitdnk[0] = loadedCfg.checkboxes.autoexitdnk or false
        poff = loadedCfg.checkboxes.poff or false
    end
end

function whiteTheme()
    local style = imgui.GetStyle();
    local colors = style.Colors;
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(12.00, 30.00);
    style.WindowRounding = 0;
    style.WindowBorderSize = 0;
    style.WindowMinSize = imgui.ImVec2(128.00, 128.00);
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50);
    style.ChildRounding = 0;
    style.ChildBorderSize = 1;
    style.PopupRounding = 0;
    style.PopupBorderSize = 1;
    style.FramePadding = imgui.ImVec2(4.00, 3.00);
    style.FrameRounding = 10;
    style.FrameBorderSize = 1;
    style.ItemSpacing = imgui.ImVec2(8.00, 4.00);
    style.ItemInnerSpacing = imgui.ImVec2(4.00, 4.00);
    style.IndentSpacing = 21;
    style.ScrollbarSize = 14;
    style.ScrollbarRounding = 9;
    style.GrabMinSize = 10;
    style.GrabRounding = 0;
    style.TabRounding = 4;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.00, 0.00);
    colors[imgui.Col.Text] = imgui.ImVec4(0.00, 0.00, 0.00, 1.00);
    colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.50, 0.50, 0.50, 1.00);
    colors[imgui.Col.WindowBg] = imgui.ImVec4(0.94, 0.94, 0.94, 1.00);
    colors[imgui.Col.ChildBg] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.PopupBg] = imgui.ImVec4(0.94, 0.94, 0.94, 0.78);
    colors[imgui.Col.Border] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    colors[imgui.Col.FrameBg] = imgui.ImVec4(0.94, 0.94, 0.94, 1.00);
    colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.88, 1.00, 1.00, 1.00);
    colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.80, 0.89, 0.97, 1.00);
    colors[imgui.Col.TitleBg] = imgui.ImVec4(0.94, 0.94, 0.94, 1.00);
    colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.30, 0.29, 0.28, 1.00);
    colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(0.00, 0.00, 0.00, 0.51);
    colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.94, 0.94, 0.94, 1.00);
    colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.02, 0.02, 0.02, 0.00);
    colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.31, 0.31, 0.31, 1.00);
    colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.41, 0.41, 0.41, 1.00);
    colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.51, 0.51, 0.51, 1.00);
    colors[imgui.Col.CheckMark] = imgui.ImVec4(0.20, 0.20, 0.20, 1.00);
    colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.00, 0.48, 0.85, 1.00);
    colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.80, 0.80, 0.80, 1.00);
    colors[imgui.Col.Button] = imgui.ImVec4(0.88, 0.88, 0.88, 1.00);
    colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.88, 1.00, 1.00, 1.00);
    colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.80, 0.89, 0.97, 1.00);
    colors[imgui.Col.Header] = imgui.ImVec4(0.88, 0.88, 0.88, 1.00);
    colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.88, 1.00, 1.00, 1.00);
    colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.80, 0.89, 0.97, 1.00);
    colors[imgui.Col.Separator] = imgui.ImVec4(0.43, 0.43, 0.50, 0.50);
    colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.10, 0.40, 0.75, 0.78);
    colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.10, 0.40, 0.75, 1.00);
    colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.00, 0.00, 0.00, 0.25);
    colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.00, 0.00, 0.00, 0.67);
    colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.00, 0.00, 0.00, 0.95);
    colors[imgui.Col.Tab] = imgui.ImVec4(0.88, 0.88, 0.88, 1.00);
    colors[imgui.Col.TabHovered] = imgui.ImVec4(0.88, 1.00, 1.00, 1.00);
    colors[imgui.Col.TabActive] = imgui.ImVec4(0.80, 0.89, 0.97, 1.00);
    colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.07, 0.10, 0.15, 0.97);
    colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.14, 0.26, 0.42, 1.00);
    colors[imgui.Col.PlotLines] = imgui.ImVec4(0.61, 0.61, 0.61, 1.00);
    colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00);
    colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00);
    colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 1.00);
    colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.00, 0.47, 0.84, 1.00);
    colors[imgui.Col.DragDropTarget] = imgui.ImVec4(1.00, 1.00, 0.00, 0.90);
    colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(1.00, 1.00, 1.00, 0.70);
    colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.20);
    colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.80, 0.80, 0.80, 0.35);
end

function att()
    on = not on
end

function onCreateObject(arg0, arg1)
    if arg1.attachToVehicleId ~= 65535 and on then
        return false
    end
end

function DeleteBatFunction()
    while true do
        wait(100)
        if deletebat[0] then
            local weapon = getCurrentCharWeapon(PLAYER_PED)
            if weapon == 5 then
                removeWeaponFromChar(PLAYER_PED, 5)
            end
        end
    end
end

local renderWindow = imgui.new.bool(false)

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    whiteTheme()
    loadCheckboxStates()
    if doesFileExist(getWorkingDirectory()..'\\resource\\promo.png') then
        imhandle = imgui.CreateTextureFromFile(getWorkingDirectory() .. '\\resource\\promo.png')
    end
end)

local work = imgui.new.bool(false)
local work1 = imgui.new.bool(false)

function checkHealthAndUseDrugs()
    while true do
        wait(100)
        if healthCheckEnabled[0] then
            local HEALTH = getCharHealth(PLAYER_PED)
            if HEALTH < min_HEALTH then
                sampSendChat('/usedrugs 15')
                wait(5000)
            end
        end
    end
end

function checkAmmoAndSell()
    while true do
        wait(0)
        local ccfg = inicfg.load(nil, cfg)
        if not ccfg.antizeroammo then
            ccfg.antizeroammo = {
                tocraft = 5,
                count = 10
            }
        end
        local gg_tocraft = tonumber(ccfg.antizeroammo.tocraft)
        local gg_count = tonumber(ccfg.antizeroammo.count)
        if poff == false then
            prevammo = getAmmoInCharWeapon(PLAYER_PED, 24)
            if prevammo == gg_tocraft then
                _, mmmid = sampGetPlayerIdByCharHandle(PLAYER_PED)
                sampSendChat(string.format("/sellgun deagle %d 100 %d", gg_count, mmmid))
                wait(1000)
                nowammo = getAmmoInCharWeapon(PLAYER_PED, 24)
                if prevammo == nowammo then
                    poff = true
                    printStringNow('aza script stopped due to error', 1000)
                end
            end
        end
    end
end

local newFrame = imgui.OnFrame(
    function() return renderWindow[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 650, 600
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('TOMASOWHELPER', renderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoScrollbar)
        if imhandle then
            imgui.Image(imhandle, imgui.ImVec2(550, 80))
        else
            imgui.Text("Image not loaded")
        end
        imgui.Dummy(imgui.ImVec2(0, 10))
        imgui.Separator()
        imgui.Dummy(imgui.ImVec2(0, 10))
        if currentTab[0] == 0 then
            if imgui.Checkbox('AutoUseDrugs', healthCheckEnabled) then
                if healthCheckEnabled[0] then
                    sampAddChatMessage("AutoUseDrugs включен", -1)
                else
                    sampAddChatMessage("AutoUseDrugs выключен", -1)
                end
                saveCheckboxStates() 
            end
            local work1 = imgui.new.bool(not poff)
            if imgui.Checkbox('AntiZeroAmmo', work1) then
                poff = not work1[0]
                saveCheckboxStates() 
            end
            if imgui.Checkbox(u8'AntiLomka', breakCheckEnabled) then
                if breakCheckEnabled[0] then
                    sampAddChatMessage("АнтиЛомка включен", -1)
                else
                    sampAddChatMessage("АнтиЛомка выключен", -1)
                end
                saveCheckboxStates() 
            end
            if imgui.Checkbox('DeleteNeon', work) then
                att()
                if work[0] then
                    sampAddChatMessage("[DeleteNeon] Удаление attach объектов {00ff00}включено. {FFFFFF}Для работы необходимо перезайти в зону стрима.", -1)
                else
                    sampAddChatMessage("[DeleteNeon] Удаление attach объектов {ff0000}выключено.", -1)
                end
                saveCheckboxStates() 
            end
            if imgui.Checkbox('DeleteBat', deletebat) then
                if deletebat[0] then
                    sampAddChatMessage("DeleteBat включен", -1)
                else
                    sampAddChatMessage("DeleteBat выключен", -1)
                end
                saveCheckboxStates() 
            end
            if imgui.Checkbox('AutoExit', autoexitdnk) then
                if autoexitdnk[0] then
                    sampAddChatMessage("AutoExitDNK включен", -1)
                else
                    sampAddChatMessage("AutoExitDNK выключен", -1)
                end
                saveCheckboxStates() 
            end
        else
            imgui.Text(u8'AutoUseDrugs - /autous, при смерти автоматически использует нар%@#^#и. ')
            imgui.Text(u8'/aza - [патроны в обойме] [количество патронов] - Докрафчивает патроны при указанном количестве.')
            imgui.Text(u8'/cho - Чекер онлайна банд.')
            imgui.Text(u8'AntiLomka - при ломке автоматом использует и сбивает нар%@#^#и. ')
            imgui.Text(u8'DeleteNeon - убирает надписи/неон на машинах. ')
        end
        local windowWidth = imgui.GetWindowWidth()
        local buttonSpacing = 10
        local totalWidth = 2 * 30 + buttonSpacing
        imgui.SetCursorPosY(imgui.GetWindowHeight() - 50) -- РЈРІРµР»РёС‡РёР» РѕС‚СЃС‚СѓРї РґР»СЏ С‚РµРєСЃС‚Р°
        imgui.SetCursorPosX((windowWidth - totalWidth) / 2)
        if imgui.Button("1", imgui.ImVec2(30, 20)) then
            currentTab[0] = 0
        end
        imgui.SameLine()
        if imgui.Button("2", imgui.ImVec2(30, 20)) then
            currentTab[0] = 1
        end
        -- Р”РѕР±Р°РІР»РµРЅРЅС‹Р№ С‚РµРєСЃС‚
        imgui.SetCursorPosY(imgui.GetWindowHeight() - 20) -- РџРѕР·РёС†РёСЏ РґР»СЏ С‚РµРєСЃС‚Р°
        imgui.SetCursorPosX((windowWidth - imgui.CalcTextSize("author: tomasow, РќРµР№СЂРѕСЃРµС‚СЊ").x) / 2) -- Р¦РµРЅС‚СЂРёСЂРѕРІР°РЅРёРµ С‚РµРєСЃС‚Р°
        imgui.Text("author: tomasow, РќРµР№СЂРѕСЃРµС‚СЊ")
        imgui.End()
    end
)

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then
        return
    end
    while not isSampAvailable() do wait(100) end

    autoupdate("https://raw.githubusercontent.com/TOMACOB/scriptautoupdate/main/autoupdate.json", '[1]: ', "https://github.com/TOMACOB/scriptautoupdate")

    sampRegisterChatCommand("th", function()
        renderWindow[0] = not renderWindow[0]
    end)
    sampRegisterChatCommand("mycommand", function()
        sampAddChatMessage("Скрипт работает!", -1)
    end)
    sampRegisterChatCommand("aza", cmdaza)
    sampRegisterChatCommand("autous", autousedrugs)
    sampRegisterChatCommand("cho", chocount)

    lua_thread.create(checkHealthAndUseDrugs)
    lua_thread.create(checkAmmoAndSell)
    lua_thread.create(DeleteBatFunction)

    while true do
        wait(0)
    end
end

function cmdaza(arg)
    if #arg == 0 then
        printStringNow('/aza [ammo do crafta] [ammo dlya crafta]', 5000)
    else
        local var1, var2 = string.match(arg, "(%S+) (%S+)")
        if var1 and var2 then
            local ccfg = inicfg.load(nil, cfg)
            if not ccfg.antizeroammo then
                ccfg.antizeroammo = {}
            end
            ccfg.antizeroammo.tocraft = var1
            ccfg.antizeroammo.count = var2
            local scfg = inicfg.save(ccfg, cfg)
            printStringNow('CONFIG SAVED!', 1000)
        else
            printStringNow('INVALID ARGUMENTS!', 1000)
        end
    end
end

function autousedrugs()
    healthCheckEnabled[0] = not healthCheckEnabled[0]
    if healthCheckEnabled[0] then
        sampAddChatMessage("AUTOUSEDRUGS включен", -1)
    else
        sampAddChatMessage("AUTOUSEDRUGS выключен", -1)
    end
end

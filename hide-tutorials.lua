--@module = true
--@enable = true

local gui = require('gui')
local utils = require('utils')

local GLOBAL_KEY = 'hide-tutorials'

enabled = enabled or false

function isEnabled()
    return enabled
end

local function is_fort_map_loaded()
    return df.global.gamemode == df.game_mode.DWARF and dfhack.isMapLoaded()
end

local help = df.global.game.main_interface.help

local function close_help()
    help.open = false
end

function skip_tutorial_prompt()
    if not help.open then return end
    local scr = dfhack.gui.getDFViewscreen(true)
    local mouse_y = 23
    if help.context == df.help_context_type.EMBARK_TUTORIAL_CHOICE then
        help.context = df.help_context_type.EMBARK_MESSAGE
        -- dialog behavior changes for the button click, but the button is still
        -- in the "tutorial choice" button position
        mouse_y = 18
    end
    if help.context == df.help_context_type.EMBARK_MESSAGE then
        df.global.gps.mouse_x = df.global.gps.dimx // 2
        df.global.gps.mouse_y = mouse_y
        gui.simulateInput(scr, '_MOUSE_L')
    end
    if help.open then
        -- retry later
        help.context = df.help_context_type.EMBARK_TUTORIAL_CHOICE
    end
end

local function hide_all_popups()
    for i,name in ipairs(df.help_context_type) do
        if not name:startswith('POPUP_') then goto continue end
        utils.insert_sorted(df.global.plotinfo.tutorial_seen, i)
        utils.insert_sorted(df.global.plotinfo.tutorial_hide, i)
        ::continue::
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if not enabled then return end

    if sc == SC_VIEWSCREEN_CHANGED then
        local scr = dfhack.gui.getDFViewscreen(true)
        if df.viewscreen_new_regionst:is_instance(scr) then
            close_help()
        elseif df.viewscreen_choose_start_sitest:is_instance(scr) then
            skip_tutorial_prompt()
            dfhack.timeout(10, 'frames', skip_tutorial_prompt)
            dfhack.timeout(100, 'frames', skip_tutorial_prompt)
            dfhack.timeout(1000, 'frames', skip_tutorial_prompt)
        end
    elseif sc == SC_MAP_LOADED and df.global.gamemode == df.game_mode.DWARF then
        hide_all_popups()
    end
end

if dfhack_flags.module then
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and 'enable' or 'disable'}
end

if args[1] == "enable" then
    enabled = true
    if is_fort_map_loaded() then
        hide_all_popups()
    end
elseif args[1] == "disable" then
    enabled = false
elseif is_fort_map_loaded() then
    hide_all_popups()
else
    qerror('hide-tutorials needs a loaded fortress map to work')
end

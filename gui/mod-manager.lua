-- Show, save, and restore lists of active mods.
--@ module = true

local dialogs = require('gui.dialogs')
local gui = require('gui')
local json = require('json')
local overlay = require('plugins.overlay')
local scriptmanager = require('script-manager')
local utils = require('utils')
local widgets = require('gui.widgets')

local presets_file = json.open("dfhack-config/mod-manager.json")
local GLOBAL_KEY = 'mod-manager'

-- get_newregion_viewscreen and get_modlist_fields are declared as global functions
-- so external tools can call them to get the DF mod list
function get_newregion_viewscreen()
    local vs = dfhack.gui.getViewscreenByType(df.viewscreen_new_regionst, 0)
    return vs
end

function get_modlist_fields(kind, viewscreen)
    if kind == "available" then
        return {
            id = viewscreen.available_id,
            numeric_version = viewscreen.available_numeric_version,
            earliest_compat_numeric_version = viewscreen.available_earliest_compat_numeric_version,
            src_dir = viewscreen.available_src_dir,
            name = viewscreen.available_name,
            displayed_version = viewscreen.available_displayed_version,
            mod_header = viewscreen.available_mod_header,
        }
    elseif kind == "base_available" then
        return {
            id = viewscreen.base_available_id,
            numeric_version = viewscreen.base_available_numeric_version,
            earliest_compat_numeric_version = viewscreen.base_available_earliest_compat_numeric_version,
            src_dir = viewscreen.base_available_src_dir,
            name = viewscreen.base_available_name,
            displayed_version = viewscreen.base_available_displayed_version,
            mod_header = viewscreen.base_available_mod_header,
        }
    elseif kind == "object_load_order" then
        return {
            id = viewscreen.object_load_order_id,
            numeric_version = viewscreen.object_load_order_numeric_version,
            earliest_compat_numeric_version = viewscreen.object_load_order_earliest_compat_numeric_version,
            src_dir = viewscreen.object_load_order_src_dir,
            name = viewscreen.object_load_order_name,
            displayed_version = viewscreen.object_load_order_displayed_version,
            mod_header = viewscreen.object_load_order_mod_header,
        }
    else
        error("Invalid kind: " .. kind)
    end
end

local function move_mod_entry(viewscreen, to, from, mod_id, mod_version)
    local to_fields = get_modlist_fields(to, viewscreen)
    local from_fields = get_modlist_fields(from, viewscreen)

    local mod_index = nil
    for i, v in ipairs(from_fields.id) do
        local version = from_fields.numeric_version[i]
        if v.value == mod_id and version == mod_version then
            mod_index = i
            break
        end
    end

    if mod_index == nil then
        return false
    end

    for k, v in pairs(to_fields) do
        if type(from_fields[k][mod_index]) == "userdata" then
            v:insert('#', from_fields[k][mod_index]:new())
        else
            v:insert('#', from_fields[k][mod_index])
        end
    end

    for k, v in pairs(from_fields) do
        v:erase(mod_index)
    end

    return true
end

local function enable_mod(viewscreen, mod_id, mod_version)
    return move_mod_entry(viewscreen, "object_load_order", "available", mod_id, mod_version)
end

local function disable_mod(viewscreen, mod_id, mod_version)
    return move_mod_entry(viewscreen, "available", "object_load_order", mod_id, mod_version)
end

local function get_active_modlist(viewscreen)
    local t = {}
    local fields = get_modlist_fields("object_load_order", viewscreen)
    for i, v in ipairs(fields.id) do
        local version = fields.numeric_version[i]
        table.insert(t, { version = version, id = v.value })
    end
    return t
end

local function swap_modlist(viewscreen, modlist)
    local current = get_active_modlist(viewscreen)
    for _, v in ipairs(current) do
        disable_mod(viewscreen, v.id, v.version)
    end

    local failures = {}
    for _, v in ipairs(modlist) do
        if not enable_mod(viewscreen, v.id, v.version) then
            table.insert(failures, v.id)
        end
    end
    return failures
end

--------------------
-- ModmanageMenu

ModmanageMenu = defclass(ModmanageMenu, widgets.Window)
ModmanageMenu.ATTRS {
    view_id = "modman_menu",
    frame_title = "Modlist Manager",
    frame_style = gui.WINDOW_FRAME,

    resize_min = { w = 30, h = 15 },
    frame = { w = 40, t = 10, b = 15 },

    resizable = true,
    autoarrange_subviews=false,
}

local function save_new_preset(preset_name)
    local viewscreen = get_newregion_viewscreen()
    local modlist = get_active_modlist(viewscreen)
    table.insert(presets_file.data, { name = preset_name, modlist = modlist })
    presets_file:write()
end

local function remove_preset(idx)
    if idx > #presets_file.data then
        return
    end

    table.remove(presets_file.data, idx)
    presets_file:write()
end

local function overwrite_preset(idx)
    if idx > #presets_file.data then
        return
    end

    local viewscreen = get_newregion_viewscreen()
    local modlist = get_active_modlist(viewscreen)
    presets_file.data[idx].modlist = modlist
    presets_file:write()
end

local function load_preset(idx, unset_default_on_failure)
    if idx > #presets_file.data then
        return
    end

    local viewscreen = get_newregion_viewscreen()
    local modlist = presets_file.data[idx].modlist
    local failures = swap_modlist(viewscreen, modlist)

    if #failures > 0 then
        local text = {}
        if unset_default_on_failure then
            presets_file.data[idx].default = false
            presets_file:write()

            table.insert(text, {
                text='Failed to load some mods from your default preset.',
                pen=COLOR_LIGHTRED,
            })
            table.insert(text, NEWLINE)
            table.insert(text, {
                text='Preset is being unmarked as the default for safety.',
                pen=COLOR_LIGHTRED,
            })
        else
            table.insert(text, {
                text='Failed to load some mods from the preset.',
                pen=COLOR_LIGHTRED,
            })
        end
        table.insert(text, NEWLINE)
        table.insert(text, NEWLINE)
        table.insert(text, 'Please re-create your preset with mods you currently have installed.')
        table.insert(text, NEWLINE)
        table.insert(text, 'Here are the mods that failed to load:')
        table.insert(text, NEWLINE)
        table.insert(text, NEWLINE)
        for _, v in ipairs(failures) do
            table.insert(text, ('- %s'):format(v))
            table.insert(text, NEWLINE)
        end
        dialogs.showMessage("Warning", text)
end
end

local function find_preset_by_name(name)
    for i, v in ipairs(presets_file.data) do
        if v.name == name then
            return i
        end
    end
end

local function rename_preset(idx, new_name)
    if idx > #presets_file.data then
        return
    end

    presets_file.data[idx].name = new_name
    presets_file:write()
end

local function toggle_default(idx)
    if idx > #presets_file.data then
        return
    end

    if presets_file.data[idx].default then
        presets_file.data[idx].default = false
        presets_file:write()
    else
        for i, v in ipairs(presets_file.data) do
            v.default = false
        end
        presets_file.data[idx].default = true
        presets_file:write()
    end
end

function ModmanageMenu:init()
    local presetList

    local function refresh_list()
        presets_file:read()
        local presets = utils.clone(presets_file.data, true)
        local default_set = false
        for _, v in ipairs(presets) do
            v.text = v.name

            if v.default and not default_set then
                v.text = v.text .. " (default)"
                default_set = true
            end
        end

        presetList:setChoices(presets)
    end

    presetList = widgets.List {
        frame = { b = 5 },
        on_double_click = function(idx, current)
            load_preset(idx)
        end,
    }

    refresh_list()

    self:addviews{
        presetList,

        widgets.HotkeyLabel{
            frame = { l = 0, b = 1, w = 15 },
            key = "CUSTOM_S",
            label = "Save current",
            on_activate = function()
                dialogs.showInputPrompt("Enter preset name", nil, nil, "", function(t)
                    local existing_idx = find_preset_by_name(t)
                    if existing_idx then
                        dialogs.showYesNoPrompt(
                            "Confirmation",
                            "Overwrite " .. t .. "?",
                            nil,
                            function()
                                overwrite_preset(existing_idx)
                                refresh_list()
                            end
                        )

                        return
                    else
                        save_new_preset(t)
                        refresh_list()
                    end
                end)
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 16, b = 1, w = 15 },
            key = "CUSTOM_R",
            label = "Rename",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                dialogs.showInputPrompt("Enter new name", nil, nil, current.name, function(t)
                    local existing_idx = find_preset_by_name(t)

                    if existing_idx then
                        if existing_idx == idx then
                            return
                        end

                        dialogs.showYesNoPrompt(
                            "Confirmation",
                            "Overwrite " .. t .. "?",
                            nil,
                            function()
                                remove_preset(existing_idx)
                                rename_preset(idx, t)
                                refresh_list()
                            end
                        )
                    else
                        rename_preset(idx, t)
                        refresh_list()
                    end
                end)
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 0, b = 2, w = 15 },
            key = "SELECT",
            label = "Load",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                load_preset(idx)
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 16, b = 2, w = 15 },
            key = "CUSTOM_D",
            label = "Delete",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                dialogs.showYesNoPrompt(
                    "Confirmation",
                    "Delete " .. current.text .. "?",
                    nil,
                    function()
                        remove_preset(idx)
                        refresh_list()
                    end
                )
            end,
        },

        widgets.HotkeyLabel{
            frame = { l = 0, b = 0, w = 20 },
            key = "CUSTOM_Q",
            label = "Set as default",
            on_activate = function()
                local idx, current = presetList:getSelected()

                if not idx then
                    return
                end

                toggle_default(idx)
                refresh_list()
            end
        },
    }
end

--------------------
-- ModmanageScreen

ModmanageScreen = defclass(ModmanageScreen, gui.ZScreen)
ModmanageScreen.ATTRS {
    focus_path = "mod-manager",
    defocusable = false,
}

function ModmanageScreen:init()
    self:addviews{
        ModmanageMenu{}
    }
end

--------------------
-- ModlistWindow

ModlistWindow = defclass(ModlistWindow, widgets.Window)
ModlistWindow.ATTRS{
    frame_title="Active Mods",
    frame={w=55, h=20},
    resizable=true,
}

local function get_num_vanilla_mods()
    local count = 0
    for _,mod in ipairs(scriptmanager.get_active_mods()) do
        if mod.vanilla then
            count = count + 1
        end
    end
    return count
end

local function get_num_non_vanilla_mods()
    local count = 0
    for _,mod in ipairs(scriptmanager.get_active_mods()) do
        if not mod.vanilla then
            count = count + 1
        end
    end
    return count
end

function ModlistWindow:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='vanilla',
            frame={l=0, t=0, w=24},
            key='CUSTOM_V',
            label='Vanilla mods:',
            options={
                {label='Include', value=true, pen=COLOR_LIGHTBLUE},
                {label='Exclude', value=false, pen=COLOR_LIGHTRED},
            },
            initial_option=false,
            on_change=function() self:refresh_list() end,
        },
        widgets.Divider{
            frame={t=2, h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.HotkeyLabel{
            frame={t=4, r=0},
            label='Export to clipboard (single line)',
            text_pen=COLOR_YELLOW,
            auto_width=true,
            on_activate=function()
                local text = {}
                for _,choice in ipairs(self.subviews.list:getChoices()) do
                    table.insert(text, ('%s %s'):format(choice.data.name, choice.data.version))
                end
                dfhack.internal.setClipboardTextCp437Multiline(table.concat(text, ', '))
            end,
            enabled=function() return #self.subviews.list:getChoices() > 0 end,
        },
        widgets.HotkeyLabel{
            frame={t=5, r=0},
            label='Export to clipboard (with links)',
            text_pen=COLOR_YELLOW,
            auto_width=true,
            on_activate=function()
                local text = {}
                for _,choice in ipairs(self.subviews.list:getChoices()) do
                    table.insert(text, choice.export_text)
                end
                dfhack.internal.setClipboardTextCp437Multiline(table.concat(text, NEWLINE))
            end,
            enabled=function() return #self.subviews.list:getChoices() > 0 end,
        },
        widgets.Label{
            frame={l=0, t=4},
            text={
                'Load',
                NEWLINE,
                'order',
            },
        },
        widgets.Label{
            frame={l=7, t=5},
            text='Mod',
        },
        widgets.List{
            view_id='list',
            frame={t=7, b=2},
        },
        widgets.Label{
            frame={l=0, b=0},
            text={
                {text=('%d'):format(get_num_vanilla_mods()), pen=COLOR_LIGHTBLUE},
                ' vanilla mods',
                {text=function() return self.subviews.vanilla:getOptionValue() and '' or ' (hidden)' end},
                ', ',
                {text=('%d'):format(get_num_non_vanilla_mods()), pen=COLOR_BROWN},
                ' non-vanilla mods',
            },
        },
    }

    self:refresh_list()
end

function ModlistWindow:refresh_list()
    local include_vanilla = self.subviews.vanilla:getOptionValue()

    local choices = {}
    for idx,mod in ipairs(scriptmanager.get_active_mods()) do
        if not include_vanilla and mod.vanilla then goto continue end
        local steam_id = scriptmanager.get_mod_info_metadata(mod.path, 'STEAM_FILE_ID').STEAM_FILE_ID
        local url = steam_id and (': https://steamcommunity.com/sharedfiles/filedetails/?id=%s'):format(steam_id) or ''
        table.insert(choices, {
            text={
                {text=idx, width=2, rjustify=true},
                ') ',
                {text=mod.name, gap=3},
                ' (',
                {text=mod.version, pen=COLOR_LIGHTGREEN},
                ')',
            },
            data=mod,
            export_text=('- %s (%s)%s'):format(mod.name, mod.version, url),
        })
        ::continue::
    end

    self.subviews.list:setChoices(choices)
end

--------------------
-- ModlistScreen

ModlistScreen = defclass(ModlistScreen, gui.ZScreen)
ModlistScreen.ATTRS{
    focus_path="mod-manager",
}

function ModlistScreen:init()
    self:addviews{
        ModlistWindow{}
    }
end

function ModlistScreen:onDismiss()
    view = nil
end

--------------------
-- Overlays

ModmanageOverlay = defclass(ModmanageOverlay, overlay.OverlayWidget)
ModmanageOverlay.ATTRS {
    frame = { w=16, h=3 },
    frame_style = gui.MEDIUM_FRAME,
    desc = "Adds a link to the mod selection screen for accessing the mod manager.",
    default_pos = { x=5, y=-6 },
    version = 2,
    viewscreens = { "new_region/Mods" },
    default_enabled=true,
}

function ModmanageOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame = {l=0, t=0, w = 20, h = 1},
            key = "CUSTOM_M",
            view_id = "modman_open",
            label = "Mod Manager",
            on_activate = function()
                ModmanageScreen{}:show()
            end,
        },
    }
end

NotificationOverlay = defclass(NotificationOverlay, overlay.OverlayWidget)
NotificationOverlay.ATTRS {
    frame = { w=60, h=1 },
    desc = "Displays a message when a mod preset has been automatically applied.",
    default_pos = { x=3, y=-6 },
    version = 2,
    viewscreens = { "new_region" },
    default_enabled=true,
}

notification_message = ""
next_notification_timer_call = 0
notification_overlay_end = 0
function NotificationOverlay:init()
    self:addviews{
        widgets.Label{
            frame = { l=0, t=0, w = 60, h = 1 },
            view_id = "lbl",
            text = {{ text = function() return notification_message end }},
            text_pen = { fg = COLOR_GREEN, bold = true, bg = nil },

        },
    }
end

OVERLAY_WIDGETS = {
    button = ModmanageOverlay,
    notification = NotificationOverlay,
}

function notification_timer_fn()
    if #notification_message > 0 then
        if notification_overlay_end < dfhack.getTickCount() then
            notification_message = ""
        end
    end

    dfhack.timeout(50, 'frames', notification_timer_fn)
end

notification_timer_fn()

local default_applied = false
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_VIEWSCREEN_CHANGED then
        local vs = get_newregion_viewscreen()
        if vs and not default_applied then
            default_applied = true
            for i, v in ipairs(presets_file.data) do
                if v.default then
                    load_preset(i, true)

                    notification_message = "*** Loaded mod list '" .. v.name .. "'!"
                    notification_overlay_end = dfhack.getTickCount() + 5000

                    break
                end
            end
        elseif not vs then
            default_applied = false
        end
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.isWorldLoaded() then
    qerror("Please load a game before using the mod manager to see active mods.")
end

view = view and view:raise() or ModlistScreen{}:show()

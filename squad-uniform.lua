-- Import and export squad uniform templates from the military equipment screen.
--@ module = true

--[====[

squad-uniform
=============
Provides overlay hotkeys in ``Military > Equipment > Customize`` to export the
current uniform template to disk and import previously-saved templates.

Exported files are JSON and stored in:
``dfhack-config/squad_uniform/*.dfuniform``

]====]

local dialogs = require('gui.dialogs')
local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local json = require('json')

local UNIFORM_DIR = dfhack.getDFPath() .. '/dfhack-config/squad_uniform/'
local FILE_EXT = '.dfuniform'
local DEFAULT_UNIFORM_FLAG = 2

local SLOT_FIELDS = {
    {'cat', 'cs_cat', -1},
    {'spec_item_id', 'cs_it_spec_item_id', -1},
    {'it_type', 'cs_it_type', -1},
    {'it_subtype', 'cs_it_subtype', -1},
    {'civ_mat', 'cs_civ_mat', -1},
    {'spec_mat', 'cs_spec_mat', -1},
    {'spec_matg', 'cs_spec_matg', -1},
    {'color_pattern_index', 'cs_color_pattern_index', -1},
    {'icp_flag', 'cs_icp_flag', 0},
    {'assigned_item_number', 'cs_assigned_item_number', -1},
    {'assigned_item_id', 'cs_assigned_item_id', -1},
}

local function ensure_uniform_dir()
    if dfhack.filesystem.isdir(UNIFORM_DIR) then
        return true
    end
    local ok, err = dfhack.filesystem.mkdir(UNIFORM_DIR)
    if not ok then
        dfhack.printerr(('Failed to create uniform directory "%s": %s')
            :format(UNIFORM_DIR, tostring(err)))
    end
    return ok
end

local function is_valid_name(name)
    return type(name) == 'string' and #name > 0 and not name:find('[^%w%._%s]')
end

local function get_panel()
    return df.global.game.main_interface and df.global.game.main_interface.squad_equipment
end

local function make_filename(name)
    return UNIFORM_DIR .. name .. FILE_EXT
end

local function basename_without_ext(path)
    return path:match('([^/\\]+)%.dfuniform$') or 'ImportedUniform'
end

local function decode_uniform_file(path)
    local file, err = io.open(path, 'r')
    if not file then
        return nil, ('Failed to open file for reading: %s'):format(tostring(err))
    end

    local text = file:read('*a')
    file:close()

    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' then
        return nil, 'Failed to decode uniform file or invalid format.'
    end

    if type(data.uniform) ~= 'table' then
        return nil, 'Uniform data is missing or invalid.'
    end

    return data
end

local function get_uniform_files()
    if not ensure_uniform_dir() then
        return {}
    end

    local files = {}
    local list, err = dfhack.filesystem.listdir(UNIFORM_DIR)
    if not list then
        if err then
            dfhack.printerr('Failed to list uniform files: ' .. tostring(err))
        end
        return files
    end

    for _, file in ipairs(list) do
        if file:match('%.dfuniform$') then
            table.insert(files, file)
        end
    end

    table.sort(files)
    return files
end

local function get_uniform_choices()
    local choices = {}
    for _, file in ipairs(get_uniform_files()) do
        table.insert(choices, {text=file})
    end
    return choices
end

local function import_uniform_file(path)
    if not ensure_uniform_dir() then
        return false, 'Uniform directory is unavailable.'
    end

    local panel = get_panel()
    if not panel then
        return false, 'Squad equipment panel is not available. Please open the Military > Equipment screen.'
    end

    local data, err = decode_uniform_file(path)
    if not data then
        return false, err
    end

    local uniform_data = data.uniform
    local nickname = data.nickname
    if not is_valid_name(nickname) then
        nickname = basename_without_ext(path)
    end

    local n = #uniform_data
    for _, field in ipairs(SLOT_FIELDS) do
        panel[field[2]]:resize(n)
    end

    panel.open = true
    panel.customizing_equipment = true
    panel.customizing_squad_entering_uniform_nickname = true
    panel.customizing_squad_uniform_nickname = nickname

    for i, slot in ipairs(uniform_data) do
        if type(slot) ~= 'table' then
            return false, ('Uniform slot %d is invalid. Expected table.'):format(i)
        end

        local idx = i - 1
        for _, field in ipairs(SLOT_FIELDS) do
            panel[field[2]][idx] = slot[field[1]] or field[3]
        end
    end

    panel.cs_uniform_flag = data.uniform_flag or DEFAULT_UNIFORM_FLAG
    return true, 'Uniform successfully imported.'
end

local function export_uniform_file(path)
    if not ensure_uniform_dir() then
        return false, 'Uniform directory is unavailable.'
    end

    local panel = get_panel()
    if not panel then
        return false, 'Squad equipment panel is not available. Please open the Military > Equipment screen.'
    end

    local uniform_data = {}
    for i = 0, #panel.cs_cat - 1 do
        local slot = {}
        for _, field in ipairs(SLOT_FIELDS) do
            slot[field[1]] = panel[field[2]][i]
        end
        table.insert(uniform_data, slot)
    end

    local payload = {
        nickname = panel.customizing_squad_uniform_nickname or '',
        uniform = uniform_data,
        uniform_flag = panel.cs_uniform_flag or DEFAULT_UNIFORM_FLAG,
    }

    local encoded, enc_err = json.encode(payload)
    if not encoded then
        return false, ('Failed to encode uniform data: %s'):format(tostring(enc_err))
    end

    local file, err = io.open(path, 'w')
    if not file then
        return false, ('Failed to open file for writing: %s'):format(tostring(err))
    end

    file:write(encoded)
    file:close()
    return true, 'Uniform saved to: ' .. path
end

local function show_export_dialog()
    dialogs.showInputPrompt(
        'Export Squad Uniform',
        'Enter file name (no extension):',
        COLOR_WHITE,
        '',
        function(name)
            if not is_valid_name(name) then
                dialogs.showMessage('Invalid Name',
                    'Name can only contain letters, numbers, underscores, periods, and spaces.')
                return
            end

            local path = make_filename(name)
            local ok, msg = export_uniform_file(path)
            if ok then
                dfhack.println(msg)
            else
                dfhack.printerr(msg)
            end
        end
    )
end

local function refresh_listbox(list)
    local filter = list:getFilter()
    local choices = get_uniform_choices()
    local selected = list:getSelected()

    if #choices == 0 then
        selected = nil
    elseif not selected then
        selected = 1
    elseif selected > #choices then
        selected = #choices
    end

    list:setChoices(choices, selected)
    list:setFilter(filter)
end

local function show_import_dialog()
    ensure_uniform_dir()

    local dlg
    local function get_dlg() return dlg end

    dlg = dialogs.ListBox{
        frame_title = 'Import/Delete Squad Uniform',
        with_filter = true,
        choices = get_uniform_choices(),
        on_select = function(_, choice)
            dfhack.timeout(2, 'frames', function()
                local path = UNIFORM_DIR .. choice.text
                local ok, msg = import_uniform_file(path)
                if ok then
                    dfhack.println('Imported from: ' .. path)
                else
                    dfhack.printerr(msg)
                end
            end)
        end,
        dismiss_on_select2 = false,
        on_select2 = function(_, choice)
            local path = UNIFORM_DIR .. choice.text
            if not dfhack.filesystem.isfile(path) then return end

            dialogs.showYesNoPrompt(
                'Delete uniform file?',
                ('Are you sure you want to delete "%s"?'):format(path),
                nil,
                function()
                    local ok, err = os.remove(path)
                    if not ok then
                        dialogs.showMessage('Delete failed',
                            ('Unable to delete "%s": %s'):format(path, tostring(err)))
                        return
                    end

                    dfhack.println('Deleted: ' .. path)
                    refresh_listbox(get_dlg().subviews.list)
                end
            )
        end,
        select2_hint = 'Delete file',
    }:show()
end

local UniformOverlay = defclass(UniformOverlay, overlay.OverlayWidget)
UniformOverlay.ATTRS{
    desc = 'Manage squad uniforms.',
    viewscreens = 'dwarfmode/Squads/Equipment/Customizing/Default',
    default_enabled = true,
    default_pos = {x = -33, y = -5},
    frame = {w = 40, h = 3},
}

function UniformOverlay:init()
    self:addviews{
        widgets.Panel{
            frame = {t = 0, l = 0, w = 40, h = 3},
            frame_style = gui.MEDIUM_FRAME,
            frame_background = gui.CLEAR_PEN,
            subviews = {
                widgets.HotkeyLabel{
                    frame = {l = 0, t = 0},
                    label = '[Import]',
                    key = 'CUSTOM_CTRL_I',
                    auto_width = true,
                    on_activate = show_import_dialog,
                },
                widgets.HotkeyLabel{
                    frame = {l = 20, t = 0},
                    label = '[Export]',
                    key = 'CUSTOM_CTRL_E',
                    auto_width = true,
                    on_activate = show_export_dialog,
                },
            },
        },
    }
end

OVERLAY_WIDGETS = {
    uniform_overlay = UniformOverlay,
}

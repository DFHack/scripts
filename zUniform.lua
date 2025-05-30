--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
local dialogs = require('gui.dialogs')
local json = require('json')

local UNIFORM_DIR = dfhack.getDFPath() .. '/dfhack-config/squad_uniform/'

local function ensure_uniform_dir()
    if not dfhack.filesystem.isdir(UNIFORM_DIR) then
        dfhack.filesystem.mkdir(UNIFORM_DIR)
    end
end

local function is_valid_name(name)
    return name and #name > 0 and not name:find('[^%w%._%s]')
end

local function get_uniform_files()
    ensure_uniform_dir()
    local files = {}
    local list = dfhack.filesystem.listdir(UNIFORM_DIR)
    if list then
        for _, file in ipairs(list) do
            if file:match('%.dfuniform$') then
                table.insert(files, file)
            end
        end
        table.sort(files)
    end
    return files
end

local function import_uniform_file(filepath)
    ensure_uniform_dir()
    local file, err = io.open(filepath, 'r')
    if not file then
        return false, 'Failed to open file for reading: ' .. tostring(err)
    end

    local text = file:read('*a')
    file:close()

    local ok, data = pcall(json.decode, text)
    if not ok or type(data) ~= 'table' then
        return false, 'Failed to decode uniform file or invalid format.'
    end

    local uniform_data = data.uniform
    if type(uniform_data) ~= 'table' then
        return false, 'Uniform data is missing or invalid.'
    end

    local nickname = data.nickname
    if not nickname or nickname == '' then
        nickname = filepath:match('([^/\\]+)%.dfuniform$') or 'ImportedUniform'
    end

    local panel = df.global.game.main_interface and df.global.game.main_interface.squad_equipment
    if not panel then
        return false, 'Squad equipment panel is not available. Please open the Military > Equipment screen.'
    end

    local n = #uniform_data
    panel.cs_cat:resize(n)
    panel.cs_it_spec_item_id:resize(n)
    panel.cs_it_type:resize(n)
    panel.cs_it_subtype:resize(n)
    panel.cs_civ_mat:resize(n)
    panel.cs_spec_mat:resize(n)
    panel.cs_spec_matg:resize(n)
    panel.cs_color_pattern_index:resize(n)
    panel.cs_icp_flag:resize(n)
    panel.cs_assigned_item_number:resize(n)
    panel.cs_assigned_item_id:resize(n)

    panel.open = true
    panel.customizing_equipment = true
    panel.customizing_squad_entering_uniform_nickname = true
    panel.customizing_squad_uniform_nickname = nickname

    for i, slot in ipairs(uniform_data) do
        local idx = i - 1
        panel.cs_cat[idx] = slot.cat or -1
        panel.cs_it_spec_item_id[idx] = slot.spec_item_id or -1
        panel.cs_it_type[idx] = slot.it_type or -1
        panel.cs_it_subtype[idx] = slot.it_subtype or -1
        panel.cs_civ_mat[idx] = slot.civ_mat or -1
        panel.cs_spec_mat[idx] = slot.spec_mat or -1
        panel.cs_spec_matg[idx] = slot.spec_matg or -1
        panel.cs_color_pattern_index[idx] = slot.color_pattern_index or -1
        panel.cs_icp_flag[idx] = slot.icp_flag or 0
        panel.cs_assigned_item_number[idx] = slot.assigned_item_number or -1
        panel.cs_assigned_item_id[idx] = slot.assigned_item_id or -1
    end

    panel.cs_uniform_flag = data.uniform_flag or 2

    return true, 'Uniform successfully imported!'
end

local function export_uniform_file(filepath)
    ensure_uniform_dir()
    local panel = df.global.game.main_interface and df.global.game.main_interface.squad_equipment
    if not panel then
        return false, 'Squad equipment panel is not available. Please open the Military > Equipment screen.'
    end

    local n = #panel.cs_cat
    local uniform_data = {}
    for i = 0, n - 1 do
        table.insert(uniform_data, {
            cat = panel.cs_cat[i],
            spec_item_id = panel.cs_it_spec_item_id[i],
            it_type = panel.cs_it_type[i],
            it_subtype = panel.cs_it_subtype[i],
            civ_mat = panel.cs_civ_mat[i],
            spec_mat = panel.cs_spec_mat[i],
            spec_matg = panel.cs_spec_matg[i],
            color_pattern_index = panel.cs_color_pattern_index[i],
            icp_flag = panel.cs_icp_flag[i],
            assigned_item_number = panel.cs_assigned_item_number[i],
            assigned_item_id = panel.cs_assigned_item_id[i],
        })
    end

    local nickname = panel.customizing_squad_uniform_nickname or ''
    local uniform_flag = panel.cs_uniform_flag or 2

    local file, err = io.open(filepath, 'w')
    if not file then return false, 'Failed to open file for writing: ' .. tostring(err) end
    file:write(json.encode({
        nickname = nickname,
        uniform = uniform_data,
        uniform_flag = uniform_flag
    }))
    file:close()
    return true, 'Uniform saved to ' .. filepath
end

local function ExportUniformDialog()
    dialogs.InputBox{
        frame_title = 'Export Squad Uniform',
        text = 'Enter file name (no extension):',
        on_input = function(name)
            if not is_valid_name(name) then
                dialogs.showMessage("Invalid Name", "Name can only contain letters, numbers, underscores, periods, and spaces.")
                return
            end
            local fname = UNIFORM_DIR .. name .. '.dfuniform'
            local ok, msg = export_uniform_file(fname)
            if ok then
                dfhack.println('Exported to: ' .. fname)
            else
                dfhack.printerr(msg)
            end
        end
    }:show()
end

local function get_uniform_choices()
    local files = get_uniform_files()
    local choices = {}
    for _, f in ipairs(files) do
        table.insert(choices, {text = f})
    end
    return choices
end

local function ImportUniformDialog()
    ensure_uniform_dir()
    local dlg
    local function get_dlg() return dlg end

    dlg = dialogs.ListBox{
        frame_title = 'Import/Delete Squad Uniform',
        with_filter = true,
        choices = get_uniform_choices(),
        on_select = function(_, choice)
            dfhack.timeout(2, 'frames', function()
                local fname = UNIFORM_DIR .. choice.text
                local ok, msg = import_uniform_file(fname)
                if ok then
                    dfhack.println('Imported from: ' .. fname)
                else
                    dfhack.printerr(msg)
                end
            end)
        end,
        dismiss_on_select2 = false,
        on_select2 = function(_, choice)
            local fname = UNIFORM_DIR .. choice.text
            if not dfhack.filesystem.isfile(fname) then return end

            dialogs.showYesNoPrompt('Delete uniform file?',
                'Are you sure you want to delete "' .. fname .. '"?', nil,
                function()
                    os.remove(fname)
                    dfhack.println('Deleted: ' .. fname)
                    local list = get_dlg().subviews.list
                    local filter = list:getFilter()
                    list:setChoices(get_uniform_choices(), list:getSelected())
                    list:setFilter(filter)
                end)
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
                    on_activate = ImportUniformDialog,
                },
                widgets.HotkeyLabel{
                    frame = {l = 20, t = 0},
                    label = '[Export]',
                    key = 'CUSTOM_CTRL_E',
                    auto_width = true,
                    on_activate = ExportUniformDialog,
                },
            },
        },
    }
end

OVERLAY_WIDGETS = {
    uniform_overlay = UniformOverlay,
}
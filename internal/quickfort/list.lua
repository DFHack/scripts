-- list-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')
local xlsxreader = require('plugins.xlsxreader')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_parse = reqscript('internal/quickfort/parse')

local function get_modeline(filepath)
    local file = io.open(filepath)
    local first_line = file:read()
    file:close()
    if (not first_line) then return nil end
    return quickfort_parse.parse_modeline(
        quickfort_parse.tokenize_csv_line(first_line)[1])
end

local blueprint_cache = {}

local function scan_csv_blueprint(path)
    local filepath = quickfort_common.get_blueprint_filepath(path)
    local mtime = dfhack.filesystem.mtime(filepath)
    if not blueprint_cache[path] or blueprint_cache[path].mtime ~= mtime then
        blueprint_cache[path] = {modeline=get_modeline(filepath), mtime=mtime}
    end
    if not blueprint_cache[path].modeline then
        print(string.format('skipping "%s": no #mode marker detected', path))
    end
    return blueprint_cache[path].modeline
end

local function get_xlsx_sheet_modeline(xlsx_file, sheet_name)
    local xlsx_sheet = xlsxreader.open_sheet(xlsx_file, sheet_name)
    return dfhack.with_finalize(
        function() xlsxreader.close_sheet(xlsx_sheet) end,
        function()
            local row_cells = xlsxreader.get_row(xlsx_sheet)
            if not row_cells or #row_cells == 0 then return nil end
            return quickfort_parse.parse_modeline(row_cells[1])
        end
    )
end

local function get_xlsx_file_sheet_infos(filepath)
    local sheet_infos = {}
    local xlsx_file = xlsxreader.open_xlsx_file(filepath)
    if not xlsx_file then return sheet_infos end
    return dfhack.with_finalize(
        function() xlsxreader.close_xlsx_file(xlsx_file) end,
        function()
            for _, sheet_name in ipairs(xlsxreader.list_sheets(xlsx_file)) do
                local modeline = get_xlsx_sheet_modeline(xlsx_file, sheet_name)
                if modeline then
                    table.insert(sheet_infos,
                                 {name=sheet_name, modeline=modeline})
                end
            end
            return sheet_infos
        end
    )
end

local function scan_xlsx_blueprint(path)
    local filepath = quickfort_common.get_blueprint_filepath(path)
    local mtime = dfhack.filesystem.mtime(filepath)
    if blueprint_cache[path] and blueprint_cache[path].mtime == mtime then
        return blueprint_cache[path].sheet_infos
    end
    local sheet_infos = get_xlsx_file_sheet_infos(filepath)
    if #sheet_infos == 0 then
        print(string.format(
                'skipping "%s": no sheet with #mode markers detected', path))
    end
    blueprint_cache[path] = {sheet_infos=sheet_infos, mtime=mtime}
    return sheet_infos
end

local blueprints = {}

local function scan_blueprints()
    local paths = dfhack.filesystem.listdir_recursive(
        quickfort_common.settings['blueprints_dir'].value, nil, false)
    blueprints = {}
    local library_blueprints = {}
    for _, v in ipairs(paths) do
        local is_library = string.find(v.path, '^library/') ~= nil
        local target_list = blueprints
        if is_library then target_list = library_blueprints end
        if not v.isdir and string.find(v.path:lower(), '[.]csv$') then
            local modeline = scan_csv_blueprint(v.path)
            if modeline then
                table.insert(target_list,
                        {path=v.path, modeline=modeline, is_library=is_library})
            end
        elseif not v.isdir and string.find(v.path:lower(), '[.]xlsx$') then
            local sheet_infos = scan_xlsx_blueprint(v.path)
            if #sheet_infos > 0 then
                for _, sheet_info in ipairs(sheet_infos) do
                    table.insert(target_list,
                            {path=v.path,
                             sheet_name=sheet_info.name,
                             modeline=sheet_info.modeline,
                             is_library=is_library})
                end
            end
        end
    end
    -- tack library files on to the end so user files are contiguous
    for i=1, #library_blueprints do
        blueprints[#blueprints + 1] = library_blueprints[i]
    end
end

function get_blueprint_by_number(list_num)
    if #blueprints == 0 then
        scan_blueprints()
    end
    local blueprint = blueprints[list_num]
    if not blueprint then
        qerror(string.format('invalid list index: %d', list_num))
    end
    return blueprint.path, blueprint.sheet_name
end

local valid_list_args = utils.invert({
    'l',
    '-library',
    'm',
    '-mode',
})

function do_list(in_args)
    local filter_string = nil
    if #in_args > 0 and not in_args[1]:startswith('-') then
        filter_string = table.remove(in_args, 1)
    end
    local args = utils.processArgs(in_args, valid_list_args)
    local show_library = args['l'] ~= nil or args['-library'] ~= nil
    local filter_mode = args['m'] or args['-mode']
    if filter_mode and not quickfort_common.valid_modes[filter_mode] then
        qerror(string.format('invalid mode: "%s"', filter_mode))
    end
    scan_blueprints()
    local num_blueprints, num_printed = 0, 0
    for i, v in ipairs(blueprints) do
        if v.is_library and not show_library then goto continue end
        num_blueprints = num_blueprints + 1
        if filter_mode and v.modeline.mode ~= filter_mode then goto continue end
        local sheet_spec = ''
        if v.sheet_name then
            sheet_spec = string.format(' -n "%s"', v.sheet_name)
        end
        local comment = ')'
        if #v.modeline.comment > 0 then
            comment = string.format(': %s)', v.modeline.comment)
        end
        local start_comment = ''
        if v.modeline.start_comment and #v.modeline.start_comment > 0 then
            start_comment = string.format('; cursor start: %s',
                                            v.modeline.start_comment)
        end
        local line = string.format(
            '%d) "%s"%s (%s%s%s',
            i, v.path, sheet_spec, v.modeline.mode, comment, start_comment)
        if not filter_string or string.find(line, filter_string) then
            print(line)
            num_printed = num_printed + 1
        end
        ::continue::
    end
    local num_filtered = num_blueprints - num_printed
    if num_filtered > 0 then
        print(string.format('  %d blueprints did not match filter',
                            num_filtered))
    end
end


-- command sequencing and routing logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local argparse = require('argparse')
local guidm = require('gui.dwarfmode')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_parse = reqscript('internal/quickfort/parse')
local utils = require('utils')

local mode_modules = {}
for mode, _ in pairs(quickfort_parse.valid_modes) do
    if mode ~= 'ignore' and mode ~= 'aliases' then
        mode_modules[mode] = reqscript('internal/quickfort/'..mode)
    end
end

local command_switch = {
    run='do_run',
    orders='do_orders',
    undo='do_undo',
}

function init_ctx(command, blueprint_name, cursor, aliases, dry_run,
                  preserve_engravings)
    return {
        command=command,
        blueprint_name=blueprint_name,
        cursor=cursor,
        aliases=aliases,
        dry_run=dry_run,
        preserve_engravings=preserve_engravings,
        zmin=30000, zmax=0,
        transform_fn_stack = {},
        shift_fn_stack = {},
        stats={out_of_bounds={label='Tiles outside map boundary', value=0},
               invalid_keys={label='Invalid key sequences', value=0}},
        messages={},
    }
end

function do_command_raw(mode, zlevel, grid, ctx)
    -- this error checking is done here again because this function can be
    -- called directly by the quickfort API
    if not mode or not mode_modules[mode] then
        error(string.format('invalid mode: "%s"', mode))
    end
    if not ctx.command or not command_switch[ctx.command] then
        error(string.format('invalid command: "%s"', ctx.command))
    end

    ctx.cursor.z = zlevel
    ctx.zmin, ctx.zmax = math.min(ctx.zmin, zlevel), math.max(ctx.zmax, zlevel)
    mode_modules[mode][command_switch[ctx.command]](zlevel, grid, ctx)
end

local function make_transform_fn(ctx)
    local tfns = ctx.transform_fn_stack
    local sfns = ctx.shift_fn_stack
    return function(pos, reference_pos)
        for i=#tfns,1,-1 do
            pos = tfns[i](pos, reference_pos)
        end
        for i=#sfns,1,-1 do
            pos = sfns[i](pos)
        end
        return pos
    end
end

local function do_apply_modifiers(filepath, sheet_name, label, ctx, modifiers)
    local first_modeline = nil
    local saved_zmin, saved_zmax = ctx.zmin, ctx.zmax
    if modifiers.repeat_count > 1 then
        -- scope min and max tracking to the closest repeat modifier so we can
        -- figure out which level to jump to when repeating up or down
        ctx.zmin, ctx.zmax = 30000, 0
    end
    for _,f in ipairs(modifiers.transform_fn_stack) do
        table.insert(ctx.transform_fn_stack, f)
    end
    for _,f in ipairs(modifiers.shift_fn_stack) do
        table.insert(ctx.shift_fn_stack, f)
    end
    local transform_fn = make_transform_fn(ctx)
    for i=1,modifiers.repeat_count do
        local section_data_list = quickfort_parse.process_section(
                filepath, sheet_name, label, ctx.cursor, transform_fn)
        for _, section_data in ipairs(section_data_list) do
            if not first_modeline then first_modeline = section_data.modeline end
            do_command_raw(section_data.modeline.mode, section_data.zlevel,
                           section_data.grid, ctx)
        end
        if modifiers.repeat_zoff > 0 then
            ctx.cursor.z = ctx.zmax + modifiers.repeat_zoff
        else
            ctx.cursor.z = ctx.zmin + modifiers.repeat_zoff
        end
    end
    if modifiers.repeat_count > 1 then
        ctx.zmin = math.min(ctx.zmin, saved_zmin)
        ctx.zmax = math.max(ctx.zmax, saved_zmax)
    end
    for _,_ in ipairs(modifiers.transform_fn_stack) do
        ctx.transform_fn_stack[#ctx.transform_fn_stack] = nil
    end
    for _,_ in ipairs(modifiers.shift_fn_stack) do
        ctx.shift_fn_stack[#ctx.shift_fn_stack] = nil
    end
    return first_modeline
end

function do_command_section(ctx, section_name, modifiers)
    modifiers = utils.assign(quickfort_parse.get_modifiers_defaults(),
                             modifiers or {})
    local sheet_name, label = quickfort_parse.parse_section_name(section_name)
    ctx.sheet_name = sheet_name
    local filepath = quickfort_list.get_blueprint_filepath(ctx.blueprint_name)
    local first_modeline =
            do_apply_modifiers(filepath, sheet_name, label, ctx, modifiers)
    if first_modeline and first_modeline.message then
        table.insert(ctx.messages, first_modeline.message)
    end
end

function finish_command(ctx, section_name, quiet)
    if ctx.command == 'orders' then quickfort_orders.create_orders(ctx) end
    if not quiet then
        print(string.format('%s successfully completed',
                            quickfort_parse.format_command(
                                ctx.command, ctx.blueprint_name, section_name)))
        for _,stat in pairs(ctx.stats) do
            if stat.always or stat.value > 0 then
                print(string.format('  %s: %d', stat.label, stat.value))
            end
        end
    end
end

local function do_one_command(command, cursor, blueprint_name, section_name,
                              mode, quiet, dry_run, preserve_engravings,
                              modifiers)
    if not cursor then
        if command == 'orders' or mode == 'notes' then
            cursor = {x=0, y=0, z=0}
        else
            qerror('please position the game cursor at the blueprint start ' ..
                   'location or use the --cursor option')
        end
    end

    local aliases = quickfort_list.get_aliases(blueprint_name)
    local ctx = init_ctx(command, blueprint_name, cursor, aliases, dry_run,
                         preserve_engravings)
    do_command_section(ctx, section_name, modifiers)
    finish_command(ctx, section_name, quiet)
    if command == 'run' then
        for _,message in ipairs(ctx.messages) do
            print('* '..message)
        end
    end
end

local function do_bp_name(commands, cursor, bp_name, sec_names, quiet, dry_run,
                          preserve_engravings, modifiers)
    for _,sec_name in ipairs(sec_names) do
        local mode = quickfort_list.get_blueprint_mode(bp_name, sec_name)
        for _,command in ipairs(commands) do
            do_one_command(command, cursor, bp_name, sec_name, mode,
                           quiet, dry_run, preserve_engravings, modifiers)
        end
    end
end

local function do_list_num(commands, cursor, list_nums, quiet, dry_run,
                           preserve_engravings, modifiers)
    for _,list_num in ipairs(list_nums) do
        local bp_name, sec_name, mode =
                quickfort_list.get_blueprint_by_number(list_num)
        for _,command in ipairs(commands) do
            do_one_command(command, cursor, bp_name, sec_name, mode,
                           quiet, dry_run, preserve_engravings, modifiers)
        end
    end
end

function do_command(args)
    for _,command in ipairs(args.commands) do
        if not command or not command_switch[command] then
            qerror(string.format('invalid command: "%s"', command))
        end
    end
    local cursor = guidm.getCursorPos()
    local quiet, verbose, dry_run, section_names = false, false, false, {''}
    local preserve_engravings, modifiers = df.item_quality.Masterful, {}
    local other_args = argparse.processArgsGetopt(args, {
            {'c', 'cursor', hasArg=true,
             handler=function(optarg) cursor = argparse.coords(optarg) end},
            {nil, 'preserve-engravings', hasArg=true,
             handler=function(optarg)
                preserve_engravings = quickfort_parse.parse_preserve_engravings(
                                                                optarg) end},
            {'d', 'dry-run', handler=function() dry_run = true end},
            {'n', 'name', hasArg=true,
             handler=function(optarg)
                section_names = argparse.stringList(optarg) end},
            {'q', 'quiet', handler=function() quiet = true end},
            {'r', 'repeat', hasArg=true,
             handler=function(optarg)
                quickfort_parse.parse_repeat_params(optarg, modifiers) end},
            {'s', 'shift', hasArg=true,
             handler=function(optarg)
                quickfort_parse.parse_shift_params(optarg, modifiers) end},
            {'t', 'transform', hasArg=true,
             handler=function(optarg)
                quickfort_parse.parse_transform_params(optarg, modifiers) end},
            {'v', 'verbose', handler=function() verbose = true end},
        })
    local blueprint_name = other_args[1]
    if not blueprint_name or blueprint_name == '' then
        qerror('expected <list_num>[,<list_num>...] or <blueprint_name>')
    end
    if #other_args > 1 then
        local extra = other_args[2]
        qerror(('unexpected argument: "%s"; did you mean "-n %s"?')
               :format(extra, extra))
    end

    quickfort_common.verbose = verbose
    dfhack.with_finalize(
        function() quickfort_common.verbose = false end,
        function()
            local ok, list_nums = pcall(argparse.numberList, blueprint_name)
            if not ok then
                do_bp_name(args.commands, cursor, blueprint_name, section_names,
                           quiet, dry_run, preserve_engravings, modifiers)
            else
                do_list_num(args.commands, cursor, list_nums, quiet, dry_run,
                            preserve_engravings, modifiers)
            end
        end)
end

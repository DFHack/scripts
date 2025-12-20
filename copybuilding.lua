--@ module = true

local help = [====[

copybuilding
============

Copy a building and start building placement mode for the same building type.

Usage:

    copybuilding
        Copy building under cursor
    copybuilding 1..9
        Copy the last n building you copied

Examples:

    copybuilding
        Copy the building under the cursor and start placing the same type
    copybuilding 1
        Re-copy the last building type you copied

Note:

  - Calling this script is intended to be done via keybindings. e.g. `keybinding add Alt-1 "copybuilding 1"`
  - History is not persisted between sessions

]====]

local argparse = require('argparse')

local copybuilding = require('plugins.buildingplan.copybuilding')

local function print_help()
    print(help)
end

local function process_args(opts, args)
    if args[1] == 'help' then
        opts.help = true
        return {}
    end

    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help', handler=function() opts.help = true end},
    })

    return positionals
end

local function main(...)
    local args, opts = {...}, {}
    local positionals = process_args(opts, args)

    if opts.help then
        print_help()
        return
    end

    local history_index = tonumber(positionals[1])

    if history_index then
        if history_index < 1 or history_index > copybuilding.MAX_HISTORY then
            qerror('History index must be 1-' .. copybuilding.MAX_HISTORY)
        end

        local success, message = copybuilding.copy_building_from_history(history_index)
        if message then
            if success then
                print('Copied ' .. message)
            else
                qerror(message)
            end
        end
    else
        local success, message = copybuilding.copy_building_at_cursor()
        if message then
            if success then
                print('Copied ' .. message .. ' and starting construction mode...')
            else
                qerror(message)
            end
        end
    end
end

if dfhack_flags.module then
    return
end

main(...)

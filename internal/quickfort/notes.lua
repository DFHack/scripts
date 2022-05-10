-- notes-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_parse = reqscript('internal/quickfort/parse')

local log = quickfort_common.log

function do_run(_, grid, ctx)
    local cells = quickfort_parse.get_ordered_grid_cells(grid)
    local lines = {}
    local prev_y = nil
    for _,cell in ipairs(cells) do
        if prev_y then
            for dy = prev_y,cell.y-2 do
                table.insert(lines, '')
            end
        end
        table.insert(lines, cell.text)
        prev_y = cell.y
    end
    table.insert(ctx.messages, table.concat(lines, '\n'))
end

function do_orders()
    log('nothing to do for blueprints in mode: notes')
end

function do_undo()
    log('nothing to do for blueprints in mode: notes')
end

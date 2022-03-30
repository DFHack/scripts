-- config mode-related logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_aliases = reqscript('internal/quickfort/aliases')
local quickfort_keycodes = reqscript('internal/quickfort/keycodes')
local quickfort_map = reqscript('internal/quickfort/map')

local log = quickfort_common.log

local function handle_modifiers(token, modifiers)
    local token_lower = token:lower()
    if token_lower == 'shift' or
            token_lower == 'ctrl' or
            token_lower == 'alt' then
        modifiers[token_lower] = true
        return true
    end
    if token_lower == 'wait' then
        -- accepted for compatibility with Python Quickfort, but waiting has no
        -- effect in DFHack quickfort.
        return true
    end
    return false
end

function do_query_config_blueprint(zlevel, grid, ctx, sidebar_mode,
                                   pre_tile_fn, post_tile_fn)
    local stats = ctx.stats
    stats.query_config_keystrokes = stats.query_config_keystrokes or
            {label='Keystrokes sent', value=0, always=true}

    quickfort_keycodes.init_keycodes()
    quickfort_aliases.reload_aliases(ctx)

    local dry_run = ctx.dry_run
    local saved_mode = df.global.ui.main.mode
    if not dry_run and saved_mode ~= sidebar_mode then
        guidm.enterSidebarMode(sidebar_mode)
    end

    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            local tile_ctx = {pos=xyz2pos(x, y, zlevel)}
            tile_ctx.cell,tile_ctx.text = cell_and_text.cell,cell_and_text.text
            if not pre_tile_fn(ctx, tile_ctx) then
                goto continue
            end
            local modifiers = {} -- tracks ctrl, shift, and alt modifiers
            for _,token in ipairs(quickfort_aliases.expand_aliases(text)) do
                if handle_modifiers(token, modifiers) then goto continue2 end
                local kcodes = quickfort_keycodes.get_keycodes(token, modifiers)
                if not kcodes then
                    qerror(string.format(
                            'unknown alias or keycode: "%s"', token))
                end
                if not dry_run then
                    gui.simulateInput(dfhack.gui.getCurViewscreen(true), kcodes)
                end
                modifiers = {}
                stats.query_config_keystrokes = stats.query_config_keystrokes+1
                ::continue2::
            end
            post_tile_fn(ctx, tile_ctx)
            ::continue::
        end
    end

    if not dry_run then
        if saved_mode ~= sidebar_mode
                    and guidm.SIDEBAR_MODE_KEYS[saved_mode] then
            guidm.enterSidebarMode(saved_mode)
        end
        quickfort_map.move_cursor(ctx.cursor)
    end
end

local function config_pre_tile_fn(ctx, tile_ctx)
    log('applying spreadsheet cell %s with text "%s"',
        tile_ctx.cell, tile_ctx.text)
    return true
end

function do_run(zlevel, grid, ctx)
    do_query_config_blueprint(zlevel, grid, ctx, df.ui_sidebar_mode.Default,
                              config_pre_tile_fn, function() end)
end

function do_orders()
    log('nothing to do for blueprints in mode: config')
end

function do_undo()
    log('cannot undo blueprints for mode: config')
end


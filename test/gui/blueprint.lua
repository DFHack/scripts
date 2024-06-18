local function test_wrapper(test_fn)
    mock.patch(dfhack.filesystem, 'listdir_recursive', mock.func({}), test_fn)
end

config = {
    mode = 'fortress',
    wrapper = test_wrapper,
}

local b = reqscript('gui/blueprint')
local blueprint = require('plugins.blueprint')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')

function test.fail_if_no_map_loaded()
    local mock_is_map_loaded = mock.func(false)
    mock.patch(dfhack, 'isMapLoaded', mock_is_map_loaded,
        function()
            expect.error_match('requires a fortress map to be loaded',
                            function() dfhack.run_script('gui/blueprint') end)
        end)
end

local function send_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end
end

local function load_ui()
    local options = {}
    blueprint.parse_gui_commandline(options, {})
    local view = b.BlueprintUI{presets=options}
    view:show()
    return view
end

function test.minimal_happy_path()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=10, y=20, z=30})
            send_keys('SELECT') -- set the first cursor position
            expect.table_eq({x=10, y=20, z=30}, view.mark)
            send_keys('CURSOR_RIGHT', 'CURSOR_DOWN', 'CURSOR_DOWN',
                      'CURSOR_UP_Z', 'CURSOR_UP_Z', 'CURSOR_UP_Z')
            send_keys('SELECT') -- set the second cursor position
            expect.eq('running: blueprint 2 3 -4 blueprint --cursor=10,20,33',
                    mock_print.call_args[1][1])
            expect.table_eq({'2', '3', '-4', 'blueprint', '--cursor=10,20,33'},
                            mock_run.call_args[1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
        end)
end

function test.cancel_ui()
    local mock_print, mock_run = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            load_ui()
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            send_keys('LEAVESCREEN')
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
            expect.eq(0, mock_print.call_count)
            expect.eq(0, mock_run.call_count)
        end)
end

function test.cancel_selection()
    local mock_print, mock_run = mock.func(), mock.func()
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=10, y=20, z=30})
            send_keys('SELECT') -- set first cursor position
            send_keys('LEAVESCREEN') -- cancel first cursor position
            expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
            guidm.setCursorPos({x=12, y=24, z=24})
            send_keys('SELECT') -- set first cursor position again
            guidm.setCursorPos({x=11, y=22, z=27})
            send_keys('SELECT') -- set second cursor position
            expect.eq('running: blueprint 2 3 -4 blueprint --cursor=11,22,27',
                    mock_print.call_args[1][1])
            expect.table_eq({'2', '3', '-4', 'blueprint',
                            '--cursor=11,22,27'},
                            mock_run.call_args[1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
        end)
end

local screen_width, screen_height = dfhack.screen.getWindowSize()
local SPACE_ASCII = (' '):byte()
local function get_screen_word(screen_pos)
    local str = ''
    for x = screen_pos.x,screen_width do
        local pen = dfhack.screen.readTile(x, screen_pos.y, false)
        if pen.ch == SPACE_ASCII then break end
        str = str .. string.char(pen.ch)
    end
    return str
end

local function get_cancel_word_pos(cancel_label)
    return {x=cancel_label.frame_body.x1+5, y=cancel_label.frame_body.y1}
end

function test.render_labels()
    if true then
        -- test is broken on 25 line displays
        return
    end
    local view = load_ui()
    view:updateLayout()
    view:onRender()
    local action_label = view.subviews.action_label
    local action_word_pos = {x=action_label.frame_body.x1+11,
                             y=action_label.frame_body.y1}
    local cancel_label = view.subviews.cancel_label
    expect.eq('first', get_screen_word(action_word_pos))
    expect.eq('Back', get_screen_word(get_cancel_word_pos(cancel_label)))
    guidm.setCursorPos({x=10, y=20, z=30})
    send_keys('CUSTOM_S')
    view:onRender()
    expect.eq('playback', get_screen_word(action_word_pos))
    send_keys('LEAVESCREEN') -- cancel start pos selection
    view:onRender()
    expect.eq('first', get_screen_word(action_word_pos))
    send_keys('SELECT')
    view:onRender()
    expect.eq('second', get_screen_word(action_word_pos))
    expect.eq('Cancel', get_screen_word(get_cancel_word_pos(cancel_label)))
    send_keys('LEAVESCREEN') -- cancel selection
    view:onRender()
    expect.eq('first', get_screen_word(action_word_pos))
    expect.eq('Back', get_screen_word(get_cancel_word_pos(cancel_label)))
    send_keys('LEAVESCREEN') -- leave UI
    expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
end

local X_ASCII = ('X'):byte()
local function check_overlay(view, mark, cursor)
    guidm.setCursorPos(cursor)
    dfhack.gui.revealInDwarfmodeMap(cursor, true)
    view:onRender()
    local vp = view:getViewport()
    local z = cursor.z
    local upper_left = {x=math.min(mark.x, cursor.x),
                        y=math.min(mark.y, cursor.y),
                        z=z}
    local lower_right = {x=math.max(mark.x, cursor.x),
                         y=math.max(mark.y, cursor.y),
                         z=z}
    -- ensure tiles within boundaries are all 'X' characters and ensure
    -- surrounding tiles do not have 'X' characters
    -- also ensure 'X' characters are COLOR_GREEN except for the cursor position
    for y = upper_left.y-1,lower_right.y+1 do
        for x = upper_left.x-1,lower_right.x+1 do
            local pos = xyz2pos(x, y, z)
            local stile = vp:tileToScreen(pos)
            -- +1 in each dimension to account for screen border
            local pen = dfhack.screen.readTile(stile.x+1, stile.y+1, true)
            local on_border = y == upper_left.y-1 or y == lower_right.y+1 or
                    x == upper_left.x-1 or x == lower_right.x+1
            if on_border then
                if pen.ch == X_ASCII then return false end
            else
                if pen.ch ~= X_ASCII then return false end
                if same_xyz(cursor, pos) ~= (pen.fg ~= COLOR_GREEN) then
                    return false
                end
            end
        end
    end
    return true
end

function test.render_selected()
    mock.patch(gui, 'blink_visible', mock.func(true),
        function()
            local view = load_ui()
            local mark = {x=10, y=20, z=30}
            guidm.setCursorPos(mark)
            send_keys('SELECT')
            expect.true_(check_overlay(view, mark, {x=8, y=18, z=30}),
                         'up_left')
            expect.true_(check_overlay(view, mark, {x=12, y=18, z=30}),
                         'up_right')
            expect.true_(check_overlay(view, mark, {x=8, y=22, z=30}),
                         'down_left')
            expect.true_(check_overlay(view, mark, {x=12, y=22, z=30}),
                         'down_right')
            send_keys('LEAVESCREEN', 'LEAVESCREEN') -- cancel selection and UI
            expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
        end)
end

function test.preset_cursor()
    guidm.enterSidebarMode(df.ui_sidebar_mode.LookAround)
    guidm.setCursorPos({x=10, y=20, z=30})
    dfhack.run_script('gui/blueprint', '--cursor=11,12,13')
    local view = b.view
    expect.table_eq({x=11, y=12, z=13}, guidm.getCursorPos())
    expect.true_(not not view.mark)
    -- cancel selection, ui, and look mode
    send_keys('LEAVESCREEN', 'LEAVESCREEN', 'LEAVESCREEN')
end

-- auto enter and leave cursor-supporting mode
function test.restore_mode()
    guidm.enterSidebarMode(df.ui_sidebar_mode.Stockpiles)
    load_ui()
    expect.eq(df.ui_sidebar_mode.LookAround, df.global.plotinfo.main.mode)
    send_keys('LEAVESCREEN') -- cancel out of ui
    expect.eq(df.ui_sidebar_mode.Stockpiles, df.global.plotinfo.main.mode)
    send_keys('LEAVESCREEN') -- get back to Default mode
end

function test.restore_default_on_unsupported_mode()
    guidm.enterSidebarMode(df.ui_sidebar_mode.Default)
    send_keys('D_BURROWS')
    load_ui()
    expect.eq(df.ui_sidebar_mode.LookAround, df.global.plotinfo.main.mode)
    send_keys('LEAVESCREEN') -- cancel out of ui
    expect.eq(df.ui_sidebar_mode.Default, df.global.plotinfo.main.mode)
end

function test.fail_to_find_default_mode()
    guidm.enterSidebarMode(df.ui_sidebar_mode.Default)
    send_keys('D_BURROWS')
    mock.patch(gui, 'simulateInput', mock.func(),
        function()
            expect.error_match('Unable to get into target sidebar mode',
                               function() load_ui() end)
        end)
    send_keys('LEAVESCREEN') -- cancel out of ui
    expect.eq(df.ui_sidebar_mode.Default, df.global.plotinfo.main.mode)
end

function test.exit_out_of_other_ui()
    dfhack.run_script('gui/mass-remove') -- some other script that displays a ui
    expect.ne('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
    expect.true_(dfhack.gui.getCurFocus(true):find('^dfhack/'))
    load_ui()
    expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
    send_keys('LEAVESCREEN') -- cancel out of ui
end

-- clear and reshow ui if gui/blueprint is run while currently shown
function test.replace_ui()
    dfhack.run_script('gui/blueprint')
    expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
    local view = b.view
    expect.true_(not not view)
    dfhack.run_script('gui/blueprint')
    expect.eq('dfhack/lua/blueprint', dfhack.gui.getCurFocus(true))
    expect.true_(not not b.view)
    expect.ne(view, b.view)
    send_keys('LEAVESCREEN') -- cancel out of ui
    expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'),
                'ensure the original ui is not still on the stack')
end

function test.reset_ui()
    dfhack.run_script('gui/blueprint')
    send_keys('SELECT') -- set cursor position
    expect.true_(not not b.view.mark)
    dfhack.run_script('gui/blueprint')
    expect.nil_(b.view.mark)
    send_keys('LEAVESCREEN') -- cancel out of ui
    expect.nil_(dfhack.gui.getCurFocus(true):find('^dfhack/'),
                'ensure the original ui is not still on the stack')
end

-- mouse support for selecting boundary tiles
function test.set_with_mouse()
    local pos = {x=df.global.window_x,
                 y=df.global.window_y,
                 z=df.global.window_z}
    mock.patch(dfhack.gui, 'getMousePos', mock.func(pos),
        function()
            local view = load_ui()
            view:onInput({_MOUSE_L=true})
            expect.table_eq(pos, view.mark, comment)
            send_keys('LEAVESCREEN') -- cancel selection
            send_keys('LEAVESCREEN') -- cancel out of UI
        end)
end

-- live status line showing the dimensions of the currently selected area
function test.render_status_line()
    local view = load_ui()
    view:updateLayout()
    local status_label = view.subviews.selected_area
    local status_text_pos = {x=status_label.frame_body.x1,
                             y=status_label.frame_body.y1}
    view:onRender()
    expect.false_(utils.getval(status_label.visible))
    guidm.setCursorPos({x=10, y=20, z=30})
    send_keys('SELECT')
    view:onRender()
    expect.true_(utils.getval(status_label.visible))
    expect.eq('1x1x1', get_screen_word(status_text_pos))

    send_keys('CURSOR_LEFT', 'CURSOR_DOWN', 'CURSOR_DOWN')
    view:onRender()
    expect.eq('2x3x1', get_screen_word(status_text_pos))

    send_keys('CURSOR_UP_Z', 'CURSOR_UP_Z', 'CURSOR_UP_Z')
    view:onRender()
    expect.eq('2x3x4', get_screen_word(status_text_pos))

    send_keys('LEAVESCREEN') -- cancel selection
    view:onRender()
    expect.false_(utils.getval(status_label.visible))

    send_keys('LEAVESCREEN') -- leave UI
end

-- edit widget for setting the blueprint name
function test.preset_basename()
    dfhack.run_script('gui/blueprint', 'imaname')
    local view = b.view
    expect.eq('imaname', view.subviews.name.text)
    send_keys('LEAVESCREEN') -- leave UI
end

function test.edit_basename()
    local view = load_ui()
    local name_widget = view.subviews.name
    expect.eq('blueprint', name_widget.text)
    send_keys('CUSTOM_N')
    expect.eq('', name_widget.text)
    view:onInput({_STRING=string.byte('h')})
    view:onInput({_STRING=string.byte('i')})
    send_keys('SELECT')
    expect.eq('hi', name_widget.text)
    send_keys('LEAVESCREEN') -- leave UI
end

function test.cancel_name_edit()
    local view = load_ui()
    local name_widget = view.subviews.name
    expect.eq('blueprint', name_widget.text)
    send_keys('CUSTOM_N')
    expect.eq('', name_widget.text)
    view:onInput({_STRING=string.byte('h')})
    view:onInput({_STRING=string.byte('i')})
    send_keys('LEAVESCREEN') -- cancel edit
    expect.eq('blueprint', name_widget.text)
    send_keys('LEAVESCREEN') -- leave UI
end

function test.name_no_collision()
    mock.patch(dfhack.filesystem, 'listdir_recursive',
               mock.func({{path='blue-dig.csv'}}),
        function()
            local view = load_ui()
            view:updateLayout()
            local name_help_label = view.subviews.name_help
            local name_help_text_pos = {x=name_help_label.frame_body.x1+2,
                                        y=name_help_label.frame_body.y1}
            view:onRender()
            if utils.getval(name_help_label.visible) then
                expect.eq('Set', get_screen_word(name_help_text_pos))
            end
            send_keys('LEAVESCREEN') -- cancel ui
        end)

    mock.patch(dfhack.filesystem, 'listdir_recursive',
               mock.func({{path='blueprint'}}),
        function()
            local view = load_ui()
            view.subviews.name.text = 'blueprint/'
            view.subviews.name.on_change()
            view:updateLayout()
            local name_help_label = view.subviews.name_help
            local name_help_text_pos = {x=name_help_label.frame_body.x1+2,
                                        y=name_help_label.frame_body.y1}
            view:onRender()
            if utils.getval(name_help_label.visible) then
                expect.eq('Set', get_screen_word(name_help_text_pos),
                          'dirname does not conflict with similar filename')
            end
            send_keys('LEAVESCREEN') -- cancel ui
        end)
end

function test.name_collision()
    mock.patch(dfhack.filesystem, 'listdir_recursive',
               mock.func({{path='blueprint-dig.csv'}}),
        function()
            local view = load_ui()
            view:updateLayout()
            local name_help_label = view.subviews.name_help
            local name_help_text_pos = {x=name_help_label.frame_body.x1+2,
                                        y=name_help_label.frame_body.y1}
            view:onRender()
            expect.eq('Warning:', get_screen_word(name_help_text_pos))
            send_keys('LEAVESCREEN') -- cancel ui
        end)

    mock.patch(dfhack.filesystem, 'listdir_recursive',
               mock.func({{path='blueprint', isdir=true}}),
        function()
            local view = load_ui()
            view.subviews.name.text = 'blueprint/'
            view.subviews.name.on_change()
            view:updateLayout()
            local name_help_label = view.subviews.name_help
            local name_help_text_pos = {x=name_help_label.frame_body.x1+2,
                                        y=name_help_label.frame_body.y1}
            view:onRender()
            expect.eq('Warning:', get_screen_word(name_help_text_pos),
                      'dirname match generates warning')
            send_keys('LEAVESCREEN') -- cancel ui
        end)
end

-- widgets to configure which blueprint phases to output

function test.phase_preset()
    dfhack.run_script('gui/blueprint', 'imaname', 'build')
    local view = b.view

    local phases_view = view.subviews.phases
    expect.eq('Custom', phases_view:getOptionValue())

    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label ~= 'phases' and sv.label ~= 'toggle all' then
            expect.true_(utils.getval(sv.visible))
            -- only build should be on; everything else should be off
            expect.eq(sv.label == 'build', sv:getOptionValue())
        end
    end
    send_keys('LEAVESCREEN') -- leave UI
end

function test.phase_toggle_visible()
    local view = load_ui()
    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label ~= 'phases' then
            expect.false_(utils.getval(sv.visible))
        end
    end
    send_keys('CUSTOM_A')
    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label ~= 'phases' then
            expect.true_(utils.getval(sv.visible))
        end
    end
    send_keys('CUSTOM_A')
    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label ~= 'phases' then
            expect.false_(utils.getval(sv.visible))
        end
    end
    send_keys('LEAVESCREEN') -- leave UI
end

function test.phase_cycle()
    local view = load_ui()
    send_keys('CUSTOM_A')
    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label == 'dig' then
            expect.true_(sv:getOptionValue())
        end
    end
    send_keys('CUSTOM_D')
    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label == 'dig' then
            expect.false_(sv:getOptionValue())
        end
    end
    send_keys('CUSTOM_D')
    for _,sv in ipairs(view.subviews.phases_panel.subviews) do
        if sv.label and sv.label == 'dig' then
            expect.true_(sv:getOptionValue())
        end
    end
    send_keys('LEAVESCREEN') -- leave UI
end

function test.phase_set()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            -- turn off autodetect and turn all phases except dig off
            for _,sv in pairs(view.subviews.phases_panel.subviews) do
                if sv.option_idx then
                    sv.option_idx = sv.label == 'dig' and 1 or 2
                end
            end
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT') -- a one-tile blueprint, why not?
            expect.eq('running: blueprint 1 1 1 blueprint dig --cursor=1,2,3',
                    mock_print.call_args[1][1])
            expect.table_eq({'1', '1', '1', 'blueprint', 'dig',
                             '--cursor=1,2,3'}, mock_run.call_args[1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.phase_nothing_set()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            -- turn off autodetect and turn all phases off
            for _,sv in pairs(view.subviews.phases_panel.subviews) do
                sv.option_idx = 2
            end
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.eq(0, mock_print.call_count)
            send_keys('SELECT') -- dismiss the error messagebox
            send_keys('LEAVESCREEN', 'LEAVESCREEN') -- cancel and leave UI
            delay_until(view:callback('isDismissed'))
        end)
end

function test.nometa()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_M')
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.str_find('%-%-nometa', mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.preset_nometa()
    dfhack.run_script('gui/blueprint', '--nometa')
    local view = b.view
    expect.false_(view.subviews.meta:getOptionValue())
    send_keys('LEAVESCREEN') -- leave UI
end

function test.splitby_group()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_T')
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.str_find('%-%-splitby=group', mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.splitby_phase()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_T', 'CUSTOM_T')
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.str_find('%-%-splitby=phase', mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.preset_splitby()
    dfhack.run_script('gui/blueprint', '--splitby=phase')
    local view = b.view
    expect.eq('phase', view.subviews.splitby:getOptionValue())
    send_keys('LEAVESCREEN') -- leave UI
end

function test.format_pretty()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_F')
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.str_find('%-%-format=pretty', mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.preset_format()
    dfhack.run_script('gui/blueprint', '--format=pretty')
    local view = b.view
    expect.eq('pretty', view.subviews.format:getOptionValue())
    send_keys('LEAVESCREEN') -- leave UI
end

function test.engrave()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_E')
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.str_find('%-%-engrave', mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.preset_engrave()
    dfhack.run_script('gui/blueprint', '--engrave')
    local view = b.view
    expect.true_(view.subviews.engrave:getOptionValue())
    send_keys('LEAVESCREEN') -- leave UI
end

function test.smooth()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_SHIFT_S')
            guidm.setCursorPos({x=1, y=2, z=3})
            send_keys('SELECT', 'SELECT')
            expect.str_find('%-%-smooth', mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.preset_smooth()
    dfhack.run_script('gui/blueprint', '--smooth')
    local view = b.view
    expect.true_(view.subviews.smooth:getOptionValue())
    send_keys('LEAVESCREEN') -- leave UI
end

function test.start_pos_comment()
    local view = load_ui()
    guidm.setCursorPos({x=1, y=2, z=3})
    expect.eq('Comment: ', view.subviews.startpos_panel:get_comment())
    -- set start pos and comment
    send_keys('CUSTOM_S', 'SELECT')
    local startpos_panel = view.subviews.startpos_panel
    startpos_panel._input_box:onInput({_STRING=string.byte('c')})
    startpos_panel._input_box:onInput({_STRING=string.byte('m')})
    send_keys('SELECT')
    expect.eq('Comment: cm', startpos_panel:get_comment())
    -- unset start pos
    send_keys('CUSTOM_S')
    -- reset start pos, expect previous comment to still be there
    send_keys('CUSTOM_S', 'SELECT', 'SELECT')
    expect.eq('Comment: cm', startpos_panel:get_comment())
    send_keys('LEAVESCREEN') -- leave UI
end

function test.start_pos_before_range_set()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_S')
            guidm.setCursorPos({x=1, y=2, z=3})
            -- select start pos and then surround it by the blueprint range
            send_keys('SELECT', 'SELECT', 'CURSOR_UP', 'CURSOR_LEFT', 'SELECT',
                      'CURSOR_DOWN', 'CURSOR_DOWN', 'CURSOR_RIGHT',
                      'CURSOR_RIGHT', 'SELECT')
            expect.str_find('%-%-playback%-start=2,2',
                            mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.start_pos_during_range_set()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            guidm.setCursorPos({x=1, y=2, z=3})
            -- select upper left corner of blueprint range
            send_keys('SELECT')
            -- select start pos
            send_keys('CUSTOM_S', 'SELECT')
            -- set comment
            local startpos_panel = view.subviews.startpos_panel
            startpos_panel._input_box:onInput({_STRING=string.byte('h')})
            startpos_panel._input_box:onInput({_STRING=string.byte('i')})
            send_keys('SELECT')
            -- select second corner of blueprint range
            send_keys('SELECT')
            expect.str_find('%-%-playback%-start=1,1,hi',
                            mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

function test.start_pos_overlay_blink_with_cursor()
    local view = load_ui()
    local pos = xyz2pos(1, 2, 3)
    guidm.setCursorPos(pos)
    send_keys('CUSTOM_S', 'SELECT', 'SELECT')
    dfhack.gui.revealInDwarfmodeMap(pos, true)
    local vp = view:getViewport()
    local stile = vp:tileToScreen(pos)

    -- when blink is off, (yellow) cursor should be visible
    mock.patch(gui, 'blink_visible', mock.func(false),
               function() view:onRender() end)
    local pen = dfhack.screen.readTile(stile.x+1, stile.y+1, true)
    expect.eq(X_ASCII, pen.ch)
    expect.ne(COLOR_BLUE, pen.fg)

    -- when blink is on, (blue) marker should be visible
    mock.patch(gui, 'blink_visible', mock.func(true),
               function() view:onRender() end)
    pen = dfhack.screen.readTile(stile.x+1, stile.y+1, true)
    expect.eq(X_ASCII, pen.ch)
    expect.eq(COLOR_BLUE, pen.fg)
    send_keys('LEAVESCREEN') -- leave UI
end

function test.start_pos_overlay()
    local view = load_ui()
    local pos = xyz2pos(1, 2, 3)
    guidm.setCursorPos(pos)
    dfhack.gui.revealInDwarfmodeMap(pos, true)
    local vp = view:getViewport()
    local stile = vp:tileToScreen(pos)

    -- ensure blue marker is visible when range is being selected and the marker
    -- is outside of the range
    send_keys('CUSTOM_S', 'SELECT', 'SELECT', 'CURSOR_DOWN', 'SELECT',
              'CURSOR_DOWN')
    mock.patch(gui, 'blink_visible', mock.func(true),
               function() view:onRender() end)
    pen = dfhack.screen.readTile(stile.x+1, stile.y+1, true)
    expect.eq(X_ASCII, pen.ch)
    expect.eq(COLOR_BLUE, pen.fg)

    -- ensure blue marker is visible when range is being selected and the marker
    -- is inside of the range
    send_keys('CURSOR_UP', 'CURSOR_UP', 'CURSOR_UP')
    mock.patch(gui, 'blink_visible', mock.func(true),
               function() view:onRender() end)
    pen = dfhack.screen.readTile(stile.x+1, stile.y+1, true)
    expect.eq(X_ASCII, pen.ch)
    expect.eq(COLOR_BLUE, pen.fg)

    send_keys('LEAVESCREEN', 'LEAVESCREEN') -- cancel selection and leave UI
end

function test.start_pos_out_of_selected_area()
    local mock_print, mock_run = mock.func(), mock.func({'blueprints/dig.csv'})
    mock.patch({
            {b, 'print', mock_print},
            {blueprint, 'run', mock_run},
        },
        function()
            local view = load_ui()
            send_keys('CUSTOM_S')
            guidm.setCursorPos({x=1, y=2, z=3})
            -- select start pos and set the blueprint range somewhere else
            send_keys('SELECT', 'SELECT', 'CURSOR_RIGHT', 'SELECT',
                      'CURSOR_DOWN', 'SELECT')
            expect.eq(1, mock_print.call_count)
            expect.str_find('%-%-playback%-start=1,2',
                            mock_print.call_args[1][1])
            send_keys('SELECT') -- dismiss the success messagebox
            delay_until(view:callback('isDismissed'))
        end)
end

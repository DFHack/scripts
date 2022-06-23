local q = reqscript('gui/quickfort')
local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_list = reqscript('internal/quickfort/list')

local gui = require('gui')
local guidm = require('gui.dwarfmode')

-- usable by tests
local mock_do_command_section
local mock_print

-- overridable by tests
local mock_bp_data_list

local function mock_get_blueprint_by_number(id)
    for _,v in ipairs(mock_bp_data_list) do
        if v.id == id then
            return v.path, v.section_name, v.mode
        end
    end
end

local function test_wrapper(test_fn)
    -- reset quickfort gui state
    q.show_library = true
    q.show_hidden = false
    q.filter_text = ''
    q.selected_id = 1
    q.repeat_dir = false
    q.repetitions = 1
    q.transform = false
    q.transformations = {}

    -- reset global test state
    mock_do_command_section, mock_print = mock.func(), mock.func()
    mock_bp_data_list = {{id=1, path='bp1.csv', mode='dig',
                          search_key='1 bp1.csv dig'}}

    -- ensure we don't do any I/O or modify any game state
    mock.patch(
        {
            {q, 'print', mock_print},
            {quickfort_command, 'do_command_section', mock_do_command_section},
            {quickfort_command, 'finish_command', function() end},
            {quickfort_list, 'get_aliases', function() return nil end},
            {quickfort_list, 'do_list_internal',
             function() return mock_bp_data_list end},
            {quickfort_list, 'get_blueprint_by_number',
             mock_get_blueprint_by_number},
        },
        test_fn)
end

config.mode = 'fortress'
config.wrapper = test_wrapper

local function load_ui(filter)
    local view = q.QuickfortUI{filter=filter}
    view:show()
    return view
end

local function send_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end
end

function test.fail_if_no_map_loaded()
    local mock_is_map_loaded = mock.func(false)
    mock.patch(dfhack, 'isMapLoaded', mock_is_map_loaded,
        function()
            expect.error_match('requires a fortress map to be loaded',
                            function() dfhack.run_script('gui/quickfort') end)
        end)
end

function test.happy_path()
    mock_bp_data_list = {
        {id=1, path='bp1.csv', mode='dig', search_key='1 bp1.csv dig'},
        {id=5, path='dir/bp5.csv', mode='build', section_name='/lbl',
         start_comment='startcom', comment='imacom',
         search_key='5 dir/bp5.csv build /lbl startcom imacom'}
    }

    dfhack.run_script('gui/quickfort')
    expect.eq('dfhack/lua/quickfort/dialog', dfhack.gui.getCurFocus(true))

    send_keys('STANDARDSCROLL_DOWN', 'SELECT')
    expect.eq('dfhack/lua/quickfort', dfhack.gui.getCurFocus(true))

    send_keys('SELECT')

    expect.eq(1, mock_do_command_section.call_count)
    expect.eq('dir/bp5.csv',
              mock_do_command_section.call_args[1][1].blueprint_name)

    expect.eq(1, mock_print.call_count)
    expect.eq('executing via gui/quickfort: quickfort run dir/bp5.csv -n /lbl',
              mock_print.call_args[1][1])
end

function test.load_reload()
    mock_bp_data_list = {
        {id=1, path='bp1.csv', mode='dig', search_key='1 bp1.csv dig'},
        {id=5, path='dir/bp5.csv', mode='build', section_name='/lbl',
         start_comment='startcom', comment='imacom',
         search_key='5 dir/bp5.csv build /lbl startcom imacom'}
    }

    local view = load_ui()
    expect.eq('No blueprint loaded', view:get_blueprint_name())

    send_keys('SELECT')
    expect.table_eq({'bp1.csv'}, view:get_blueprint_name())

    send_keys('CUSTOM_L', 'STANDARDSCROLL_DOWN', 'SELECT')
    expect.table_eq({'dir/bp5.csv', '  /lbl'}, view:get_blueprint_name())

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))

    expect.eq(0, mock_do_command_section.call_count)
    expect.eq(0, mock_print.call_count)
end

function test.preset_filter()
    mock_bp_data_list = {
        {id=1, path='bp1.csv', mode='build', search_key='1 bp1.csv build'},
        {id=2, path='bp2.csv', mode='dig', search_key='2 bp2.csv dig'},
        {id=5, path='dir/bp5.csv', mode='dig', section_name='/lbl',
         search_key='5 dir/bp5.csv dig /lbl'}
    }

    local view = load_ui('dig')

    -- should filter to only the matching blueprints
    local choices = view._dialog.subviews.list:getVisibleChoices()
    expect.eq(2, #choices)
    expect.eq('2)', choices[1].text:sub(1, 2))
    expect.eq('5)', choices[2].text:sub(1, 2))

    -- a single esc exits the entire ui since we haven't loaded a blueprint yet
    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.preset_filter_autoload()
    mock_bp_data_list = {
        {id=1, path='bp1.csv', mode='dig', search_key='1 bp1.csv dig'},
        {id=2, path='bp2.csv', mode='dig', search_key='2 bp2.csv dig'},
        {id=5, path='dir/bp5.csv', mode='build', section_name='/lbl',
         search_key='5 dir/bp5.csv build /lbl'}
    }

    local view = load_ui('bp1')

    -- should autoload the only matching entry
    expect.table_eq({'bp1.csv'}, view:get_blueprint_name())

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.filter_settings()
    local mock_do_list_internal = mock.func(mock_bp_data_list)
    mock.patch(quickfort_list, 'do_list_internal', mock_do_list_internal,
        function()
            local view = load_ui('nomatch')
            expect.eq(1, mock_do_list_internal.call_count)
            -- expect show_library==true and show_hidden==false
            expect.eq(true, mock_do_list_internal.call_args[1][1])
            expect.eq(false, mock_do_list_internal.call_args[1][2])

            send_keys('CUSTOM_ALT_L')
            expect.eq(2, mock_do_list_internal.call_count)
            -- expect show_library==false and show_hidden==false
            expect.eq(false, mock_do_list_internal.call_args[2][1])
            expect.eq(false, mock_do_list_internal.call_args[2][2])

            send_keys('CUSTOM_ALT_H')
            expect.eq(3, mock_do_list_internal.call_count)
            -- expect show_library==false and show_hidden==true
            expect.eq(false, mock_do_list_internal.call_args[3][1])
            expect.eq(true, mock_do_list_internal.call_args[3][2])

            send_keys('LEAVESCREEN')
            delay_until(view:callback('isDismissed'))
        end)
end

function test.show_hide_details()
    local view = load_ui()
    expect.eq('dfhack/lua/quickfort/dialog', dfhack.gui.getCurFocus(true))

    send_keys('STANDARDSCROLL_RIGHT')
    expect.eq('dfhack/lua/quickfort/dialog/details',
              dfhack.gui.getCurFocus(true))
    -- render so that code is covered
    view._dialog._details:onRender()

    send_keys('STANDARDSCROLL_LEFT')
    expect.eq('dfhack/lua/quickfort/dialog', dfhack.gui.getCurFocus(true))

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.truncate_long_names()
    mock_bp_data_list = {
        {id=1, mode='build',
         path='extremely/long/path/to/a/file/that/cannot/fit/in/window/bp1.csv',
         search_key=''},
    }

    local view = load_ui()

    local choices = view._dialog.subviews.list:getVisibleChoices()
    expect.eq(1, #choices)
    expect.gt(#choices[1].full_text, #choices[1].text)

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.summary_label()
    mock_bp_data_list = {
        {id=1, path='bp1.csv', mode='dig', search_key='dig'},
        {id=2, path='bp2.csv', mode='config', search_key='config'},
        {id=3, path='bp3.csv', mode='notes', search_key='notes'},
    }

    local view = load_ui()
    send_keys('SELECT')
    expect.str_find('Reposition', view:get_summary_label())

    send_keys('CUSTOM_L', 'STANDARDSCROLL_DOWN', 'SELECT')
    expect.str_find('configures', view:get_summary_label())

    send_keys('CUSTOM_L', 'STANDARDSCROLL_DOWN', 'SELECT')
    expect.str_find('help text', view:get_summary_label())

    send_keys('LEAVESCREEN', 'LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.save_selection()
    mock_bp_data_list = {
        {id=1, path='bp1.csv', mode='dig', search_key='x'},
        {id=2, path='bp2.csv', mode='dig', search_key='y'},
        {id=3, path='bp3.csv', mode='dig', search_key='z'},
    }

    local view = load_ui()

    local choices = view._dialog.subviews.list:getVisibleChoices()
    local _, obj = view._dialog.subviews.list:getSelected()
    expect.eq(3, #choices)
    expect.eq('1)', obj.text:sub(1, 2))

    view._dialog:onInput({_STRING=string.byte('y')})
    choices = view._dialog.subviews.list:getVisibleChoices()
    _, obj = view._dialog.subviews.list:getSelected()
    expect.eq(1, #choices)
    expect.eq('2)', obj.text:sub(1, 2))

    -- send backspace, expect there to be 3 items again, but 2nd is selected
    view._dialog:onInput({_STRING=0})
    choices = view._dialog.subviews.list:getVisibleChoices()
    _, obj = view._dialog.subviews.list:getSelected()
    expect.eq(3, #choices)
    expect.eq('2)', obj.text:sub(1, 2))

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.lock_cursor()
    local view = load_ui('b') -- autoload the default blueprint
    send_keys('CURSOR_DOWN') -- make sure we're not at the top of the screen
    local cursor = guidm.getCursorPos()
    -- do a render pass so the cursor position is saved
    mock.patch(gui, 'blink_visible', mock.func(true),
               view:callback('onRender'))
    expect.table_eq(cursor, view.saved_cursor)
    -- move up and verify that the saved cursor pos changes
    send_keys('CURSOR_UP')
    mock.patch(gui, 'blink_visible', mock.func(true),
               view:callback('onRender'))
    expect.ne(cursor.y, view.saved_cursor.y)
    -- move down again and update the saved cursor
    send_keys('CURSOR_DOWN')
    mock.patch(gui, 'blink_visible', mock.func(true),
               view:callback('onRender'))
    expect.table_eq(cursor, view.saved_cursor)
    -- lock the cursor and ensure the saved cursor doesn't change when moving
    send_keys('CUSTOM_SHIFT_L', 'CURSOR_UP')
    mock.patch(gui, 'blink_visible', mock.func(true),
               view:callback('onRender'))
    expect.table_eq(cursor, view.saved_cursor)
    expect.ne(guidm.getCursorPos().y, view.saved_cursor.y)
    -- unlock the cursor and ensure the cursor jumps back to the saved spot
    send_keys('CUSTOM_SHIFT_L')
    expect.table_eq(cursor, view.saved_cursor)
    expect.table_eq(cursor, guidm.getCursorPos())

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.orders_empty()
    local view = load_ui('b') -- autoload the default blueprint
    expect.eq('dfhack/lua/quickfort', dfhack.gui.getCurFocus(true))

    send_keys('CUSTOM_SHIFT_O')
    expect.eq('dfhack/lua/MessageBox', dfhack.gui.getCurFocus(true))

    expect.eq('0 order(s) would be enqueued for\nbp1.csv.',
              view._dialog.subviews.label.text)

    send_keys('LEAVESCREEN')
    expect.eq('dfhack/lua/quickfort', dfhack.gui.getCurFocus(true))

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

local function populate_orders(ctx)
    ctx.order_specs = {'a'} -- invalid, but we just need the item count
    ctx.stats.a = {is_order=true, label='a', value=4}
end

function test.orders_nonempty()
    local view = load_ui('b') -- autoload the default blueprint

    mock.patch(quickfort_command, 'do_command_section', populate_orders,
               function() send_keys('CUSTOM_SHIFT_O') end)

    expect.eq('1 order(s) would be enqueued for\nbp1.csv.\n\n  a: 4',
              view._dialog.subviews.label.text)

    send_keys('LEAVESCREEN', 'LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

local function populate_messages(ctx)
    ctx.messages = {'imamessage'}
end

function test.messages()
    local view = load_ui('b') -- autoload the default blueprint

    mock.patch(quickfort_command, 'do_command_section', populate_messages,
               function() send_keys('SELECT') end)

    expect.eq('imamessage',
              view._dialog.subviews.label.text)

    send_keys('LEAVESCREEN', 'LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.repeat_widgets()
    local view = load_ui('b') -- autoload the default blueprint

    -- validate initial state
    expect.false_(q.repeat_dir)
    expect.false_(view.subviews.repeat_times_panel.visible)
    expect.eq(1, q.repetitions)

    send_keys('CUSTOM_R')

    expect.true_(q.repeat_dir)
    expect.true_(view.subviews.repeat_times_panel.visible)
    expect.eq(1, q.repetitions)

    send_keys('SECONDSCROLL_UP')
    expect.eq(1, q.repetitions, 'cannot go below minimum')
    send_keys('SECONDSCROLL_DOWN')
    expect.eq(2, q.repetitions)
    send_keys('SECONDSCROLL_PAGEDOWN')
    expect.eq(12, q.repetitions)
    send_keys('SECONDSCROLL_UP', 'SECONDSCROLL_UP')
    expect.eq(10, q.repetitions)
    send_keys('SECONDSCROLL_PAGEUP')
    expect.eq(1, q.repetitions, 'cannot go below minimum')

    send_keys('CUSTOM_SHIFT_R')
    view:onInput{_STRING=string.byte('0')}
    view:onInput{_STRING=string.byte('0')}
    send_keys('SELECT')
    expect.eq(100, q.repetitions)

    view:refresh_preview()
    expect.eq(1, mock_do_command_section.call_count)
    local modifiers = mock_do_command_section.call_args[1][3]
    expect.eq(-1, modifiers.repeat_zoff)
    expect.eq(100, modifiers.repeat_count)

    send_keys('CUSTOM_SHIFT_R')
    view:onInput{_STRING=0}
    view:onInput{_STRING=0}
    view:onInput{_STRING=0}
    send_keys('SELECT')
    expect.eq(1, q.repetitions, '0 repetitions bumped up to 1')

    view:refresh_preview()
    expect.eq(2, mock_do_command_section.call_count)
    local modifiers = mock_do_command_section.call_args[2][3]
    expect.eq(0, modifiers.repeat_zoff)
    expect.eq(1, modifiers.repeat_count)

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

function test.transform_widgets()
    local view = load_ui('b') -- autoload the default blueprint

    -- validate initial state
    expect.false_(q.transform)
    expect.false_(view.subviews.transform_panel.visible)
    expect.table_eq({}, q.transformations)

    send_keys('CUSTOM_T')

    expect.true_(q.transform)
    expect.true_(view.subviews.transform_panel.visible)
    expect.table_eq({}, q.transformations)

    send_keys('A_MOVE_E_DOWN')
    expect.table_eq({'cw'}, q.transformations)
    send_keys('A_MOVE_W_DOWN')
    expect.table_eq({}, q.transformations, 'ccw undoes cw')
    send_keys('A_MOVE_N_DOWN', 'A_MOVE_S_DOWN')
    expect.table_eq({'flipv', 'fliph'}, q.transformations)
    send_keys('A_MOVE_E_DOWN')
    expect.table_eq({'ccw'}, q.transformations, 'flipv+fliph+cw=ccw')

    view:refresh_preview()
    expect.eq(1, mock_do_command_section.call_count)
    local modifiers = mock_do_command_section.call_args[1][3]
    expect.eq(1, #modifiers.transform_fn_stack)

    send_keys('LEAVESCREEN')
    delay_until(view:callback('isDismissed'))
end

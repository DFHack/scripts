local gui = require('gui')
local gui_journal = reqscript('gui/journal')

config = {
    target = 'gui/journal',
    mode = 'fortress'
}

local df_major_version = tonumber(dfhack.getCompiledDFVersion():match('%d+'))

local function simulate_input_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end

    gui_journal.view:onRender()
end

local function simulate_input_text(text)
    local screen = dfhack.gui.getCurViewscreen(true)

    for i = 1, #text do
        local charcode = string.byte(text:sub(i,i))
        local code_key = string.format('STRING_A%03d', charcode)

        gui.simulateInput(screen, { [code_key]=true })
    end

    gui_journal.view:onRender()
end

local function simulate_mouse_click(element, x, y)
    local screen = dfhack.gui.getCurViewscreen(true)

    local g_x, g_y = element.frame_body:globalXY(x, y)
    df.global.gps.mouse_x = g_x
    df.global.gps.mouse_y = g_y

    if not element.frame_body:inClipGlobalXY(g_x, g_y) then
        print('--- Click outside provided element area, re-check the test')
        return
    end

    gui.simulateInput(screen, {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })
    gui.simulateInput(screen, '_MOUSE_L_DOWN')

    gui_journal.view:onRender()
end

local function simulate_mouse_drag(element, x_from, y_from, x_to, y_to)
    local g_x_from, g_y_from = element.frame_body:globalXY(x_from, y_from)
    local g_x_to, g_y_to = element.frame_body:globalXY(x_to, y_to)

    df.global.gps.mouse_x = g_x_from
    df.global.gps.mouse_y = g_y_from

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), '_MOUSE_L_DOWN')

    df.global.gps.mouse_x = g_x_to
    df.global.gps.mouse_y = g_y_to
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), '_MOUSE_L_DOWN')

    gui_journal.view:onRender()
end

local function arrange_empty_journal(options)
    options = options or {}

    gui_journal.main({
        save_prefix='test:',
        save_on_change=options.save_on_change or false,
        save_layout=options.allow_layout_restore or false,
    })

    local journal = gui_journal.view
    local journal_window = journal.subviews.journal_window

    if not options.allow_layout_restore then
        journal_window.frame= {w = 50, h = 50}
    end

    if options.w then
        journal_window.frame.w = options.w + 8
    end

    if options.h then
        journal_window.frame.h = options.h + 6
    end

    local text_area = journal_window.subviews.journal_editor.text_area

    text_area.enable_cursor_blink = false
    if not options.save_on_change then
        text_area:setText('')
    end

    if not options.allow_layout_restore then
        local toc_panel = journal_window.subviews.table_of_contents_panel
        toc_panel.visible = false
        toc_panel.frame.w = 25
    end

    journal:updateLayout()
    journal:onRender()

    return journal, text_area, journal_window
end

local function read_rendered_text(text_area)
    local pen = nil
    local text = ''

    local frame_body = text_area.frame_body

    for y=frame_body.clip_y1,frame_body.clip_y2 do

        for x=frame_body.clip_x1,frame_body.clip_x2 do
            pen = dfhack.screen.readTile(x, y)

            if pen == nil or pen.ch == nil or pen.ch == 0 or pen.fg == 0 then
                break
            else
                text = text .. string.char(pen.ch)
            end
        end

        text = text .. '\n'
    end

    return text:gsub("\n+$", "")
end

local function read_selected_text(text_area)
    local pen = nil
    local text = ''

    for y=0,text_area.frame_body.height do
        local has_sel = false

        for x=0,text_area.frame_body.width do
            local g_x, g_y = text_area.frame_body:globalXY(x, y)
            pen = dfhack.screen.readTile(g_x, g_y)

            local pen_char = string.char(pen.ch)
            if pen == nil or pen.ch == nil or pen.ch == 0 then
                break
            elseif pen.bg == COLOR_CYAN then
                has_sel = true
                text = text .. pen_char
            end
        end
        if has_sel then
            text = text .. '\n'
        end
    end

    return text:gsub("\n+$", "")
end

function test.load()
    local journal, text_area = arrange_empty_journal()
    text_area:setText(' ')
    journal:onRender()

    expect.eq('dfhack/lua/journal', dfhack.gui.getCurFocus(true)[1])
    expect.eq(read_rendered_text(text_area), '_')

    journal:dismiss()
end

function test.restore_layout()
    local journal, _ = arrange_empty_journal({allow_layout_restore=true})

    journal.subviews.journal_window.frame = {
        l = 13,
        t = 13,
        w = 80,
        h = 23
    }
    journal.subviews.table_of_contents_panel.frame.w = 37

    journal:updateLayout()

    journal:dismiss()

    journal, _ = arrange_empty_journal({allow_layout_restore=true})

    expect.eq(journal.subviews.journal_window.frame.l, 13)
    expect.eq(journal.subviews.journal_window.frame.t, 13)
    expect.eq(journal.subviews.journal_window.frame.w, 80)
    expect.eq(journal.subviews.journal_window.frame.h, 23)

    journal:dismiss()
end

function test.restore_text_between_sessions()
    local journal, text_area = arrange_empty_journal({w=80,save_on_change=true})

    simulate_input_keys('CUSTOM_CTRL_A')
    simulate_input_keys('CUSTOM_DELETE')

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas,',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)
    simulate_mouse_click(text_area, 10, 1)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed c_nsectetur, urna sit amet aliquet egestas,',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()

    journal, text_area = arrange_empty_journal({w=80, save_on_change=true})

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed c_nsectetur, urna sit amet aliquet egestas,',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.generate_table_of_contents()
    local journal, text_area = arrange_empty_journal({w=100, h=10})

    local text = table.concat({
        '# Header 1',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        '# Header 2',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        '## Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(journal.subviews.table_of_contents_panel.visible, false)

    simulate_input_keys('CUSTOM_CTRL_O')

    expect.eq(journal.subviews.table_of_contents_panel.visible, true)

    local toc_items = journal.subviews.table_of_contents.choices

    expect.eq(#toc_items, 6)

    local expectChoiceToMatch = function (a, b)
        expect.eq(a.line_cursor, b.line_cursor)
        expect.eq(a.text, b.text)
    end

    expectChoiceToMatch(toc_items[1], {line_cursor=1, text='Header 1'})
    expectChoiceToMatch(toc_items[2], {line_cursor=114, text='Header 2'})
    expectChoiceToMatch(toc_items[3], {line_cursor=204, text=' Subheader 1'})
    expectChoiceToMatch(toc_items[4], {line_cursor=338, text=' Subheader 2'})
    expectChoiceToMatch(toc_items[5], {line_cursor=485, text='  Subsubheader 1'})
    expectChoiceToMatch(toc_items[6], {line_cursor=504, text='Header 3'})

    journal:dismiss()
end

function test.jump_to_table_of_contents_sections()
    local journal, text_area = arrange_empty_journal({
        w=100,
        h=10,
        allow_layout_restore=false
    })

    local text = table.concat({
        '# Header 1',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        '# Header 2',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        '## Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_O')

    local toc = journal.subviews.table_of_contents

    toc:setSelected(1)
    toc:submit()

    gui_journal.view:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        '_ Header 1',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        '# Header 2',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        '## Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
    }, '\n'))

    toc:setSelected(2)
    toc:submit()

    gui_journal.view:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        '_ Header 2',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        '## Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
    }, '\n'))

    toc:setSelected(3)
    toc:submit()

    gui_journal.view:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        '_# Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
    }, '\n'))

    toc:setSelected(4)
    toc:submit()

    gui_journal.view:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '_# Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n'))

    toc:setSelected(5)
    toc:submit()

    gui_journal.view:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '_## Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n'))

    toc:setSelected(6)
    toc:submit()

    gui_journal.view:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '_ Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n'))

    journal:dismiss()
end

function test.resize_table_of_contents_together()
    local journal, text_area = arrange_empty_journal({
        w=100,
        h=20,
        allow_layout_restore=false
    })

    local text = table.concat({
        '# Header 1',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(text_area.frame_body.width, 101)

    simulate_input_keys('CUSTOM_CTRL_O')

    expect.eq(text_area.frame_body.width, 101 - 24)

    local toc_panel = journal.subviews.table_of_contents_panel
    -- simulate mouse drag resize of toc panel
    simulate_mouse_drag(
        toc_panel,
        toc_panel.frame_body.width + 1,
        1,
        toc_panel.frame_body.width + 1 + 10,
        1
    )

    expect.eq(text_area.frame_body.width, 101 - 24 - 10)

    journal:dismiss()
end

function test.table_of_contents_selection_follows_cursor()
    local journal, text_area = arrange_empty_journal({
        w=100,
        h=50,
        allow_layout_restore=false
    })

    local text = table.concat({
        '# Header 1',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        '# Header 2',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        '## Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_O')

    local toc = journal.subviews.table_of_contents

    text_area:setCursor(1)
    gui_journal.view:onRender()

    expect.eq(toc:getSelected(), 1)


    text_area:setCursor(8)
    gui_journal.view:onRender()

    expect.eq(toc:getSelected(), 1)


    text_area:setCursor(140)
    gui_journal.view:onRender()

    expect.eq(toc:getSelected(), 2)


    text_area:setCursor(300)
    gui_journal.view:onRender()

    expect.eq(toc:getSelected(), 3)


    text_area:setCursor(646)
    gui_journal.view:onRender()

    expect.eq(toc:getSelected(), 6)

    journal:dismiss()
end

if df_major_version < 51 then
    -- temporary ignore test features that base on newest API of the DF game
    return
end

function test.table_of_contents_keyboard_navigation()
    local journal, text_area = arrange_empty_journal({
        w=100,
        h=50,
        allow_layout_restore=false
    })

    local text = table.concat({
        '# Header 1',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        '# Header 2',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        '## Subheader 1',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        '## Subheader 2',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '### Subsubheader 1',
        '# Header 3',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_O')

    local toc = journal.subviews.table_of_contents

    text_area:setCursor(5)
    gui_journal.view:onRender()

    simulate_input_keys('A_MOVE_N_DOWN')

    expect.eq(toc:getSelected(), 1)

    simulate_input_keys('A_MOVE_N_DOWN')

    expect.eq(toc:getSelected(), 6)

    simulate_input_keys('A_MOVE_N_DOWN')
    simulate_input_keys('A_MOVE_N_DOWN')

    expect.eq(toc:getSelected(), 4)

    simulate_input_keys('A_MOVE_S_DOWN')

    expect.eq(toc:getSelected(), 5)

    simulate_input_keys('A_MOVE_S_DOWN')
    simulate_input_keys('A_MOVE_S_DOWN')
    simulate_input_keys('A_MOVE_S_DOWN')

    expect.eq(toc:getSelected(), 2)


    text_area:setCursor(250)
    gui_journal.view:onRender()

    simulate_input_keys('A_MOVE_N_DOWN')

    expect.eq(toc:getSelected(), 3)

    journal:dismiss()
end

function test.show_tutorials_on_first_use()
    local journal, text_area, journal_window = arrange_empty_journal({w=65})
    simulate_input_keys('CUSTOM_CTRL_O')

    expect.str_find('Welcome to gui/journal', read_rendered_text(text_area));

    simulate_input_text(' ')

    expect.eq(read_rendered_text(text_area), ' _');

    local toc_panel = journal_window.subviews.table_of_contents_panel
    expect.str_find('Start a line with\n# symbols', read_rendered_text(toc_panel));

    simulate_input_text('\n# Section 1')

    expect.str_find('Section 1\n', read_rendered_text(toc_panel));
    journal:dismiss()
end

-- TODO: separate journal tests from TextEditor tests
-- add "one_line_mode" tests

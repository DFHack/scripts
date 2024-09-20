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


    local text_area = journal_window.subviews.text_area

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

function test.load_input_multiline_text()
    local journal, text_area, journal_window = arrange_empty_journal({w=80})

    local text = table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Pellentesque dignissim volutpat orci, sed molestie metus elementum vel.',
        'Donec sit amet mattis ligula, ac vestibulum lorem.',
    }, '\n')
    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), text .. '_')

    journal:dismiss()
end

function test.handle_numpad_numbers_as_text()
    local journal, text_area, journal_window = arrange_empty_journal({w=80})

    local text = table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')
    simulate_input_text(text)

    simulate_input_keys({
        STANDARDSCROLL_LEFT      = true,
        KEYBOARD_CURSOR_LEFT     = true,
        _STRING                  = 52,
        STRING_A052              = true,
    })

    expect.eq(read_rendered_text(text_area), text .. '4_')

    simulate_input_keys({
        STRING_A054              = true,
        STANDARDSCROLL_RIGHT     = true,
        KEYBOARD_CURSOR_RIGHT    = true,
        _STRING                  = 54,
    })
    expect.eq(read_rendered_text(text_area), text .. '46_')

    simulate_input_keys({
        KEYBOARD_CURSOR_DOWN     = true,
        STRING_A050              = true,
        _STRING                  = 50,
        STANDARDSCROLL_DOWN      = true,
    })

    expect.eq(read_rendered_text(text_area), text .. '462_')

    simulate_input_keys({
        KEYBOARD_CURSOR_UP       = true,
        STRING_A056              = true,
        STANDARDSCROLL_UP        = true,
        _STRING                  = 56,
    })

    expect.eq(read_rendered_text(text_area), text .. '4628_')
    journal:dismiss()
end

function test.wrap_text_to_available_width()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor est pellentesque ac.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac._',
    }, '\n'));

    journal:dismiss()
end

function test.submit_new_line()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('SELECT')
    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '',
        '_',
    }, '\n'));

    text_area:setCursor(58)
    journal:onRender()

    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'el',
        '_t.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        -- empty end lines are not rendered
    }, '\n'));

    text_area:setCursor(84)
    journal:onRender()

    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'el',
        'it.',
        '112: Sed consectetur,',
        -- wrapping changed
        '_urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        -- empty end lines are not rendered
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_up_navigation()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor est pellentesque ac.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim _uismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim li_ero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor _i, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')
    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur_ urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_down_navigation()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor est pellentesque ac.',
    }, '\n')

    simulate_input_text(text)
    text_area:setCursor(11)
    journal:onRender()

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem _psum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed c_nsectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellen_esque ac.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin dignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
        '41: Etiam id congue urna, vel aliquet mi.',
        '45: Nam dignissim libero a interdum porttitor.',
        '73: Proin _ignissim euismod augue, laoreet porttitor ',
        'est pellentesque ac.',
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_left_navigation()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero_',
    }, '\n'));

    for i=1,6 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        '_ibero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec_',
        'libero.',
    }, '\n'));

    for i=1,105 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,60 do
        simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    journal:dismiss()
end

function test.keyboard_arrow_right_navigation()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)
    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '6_: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,53 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing_',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        '_lit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,5 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,113 do
        simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    journal:dismiss()
end

function test.handle_backspace()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero_',
    }, '\n'));

    for i=1,3 do
        simulate_input_keys('STRING_A000')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec lib_',
    }, '\n'));

    text_area:setCursor(62)
    journal:onRender()

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._12: Sed consectetur, urna sit amet aliquet ',
        'egestas, ante nibh porttitor mi, vitae rutrum eros ',
        'metus nec lib',
    }, '\n'));

    text_area:setCursor(2)
    journal:onRender()

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.112: Sed consectetur, urna sit amet aliquet ',
        'egestas, ante nibh porttitor mi, vitae rutrum eros ',
        'metus nec lib',
    }, '\n'));

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.112: Sed consectetur, urna sit amet aliquet ',
        'egestas, ante nibh porttitor mi, vitae rutrum eros ',
        'metus nec lib',
    }, '\n'));

    journal:dismiss()
end

function test.handle_delete()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_DELETE')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(124)
    journal:onRender()
    simulate_input_keys('CUSTOM_DELETE')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        '_rttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(123)
    journal:onRender()
    simulate_input_keys('CUSTOM_DELETE')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibh_rttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(171)
    journal:onRender()
    simulate_input_keys('CUSTOM_DELETE')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibhorttitor mi, vitae rutrum eros metus nec libero._0: Lorem ',
        'ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    for i=1,59 do
        simulate_input_keys('CUSTOM_DELETE')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibhorttitor mi, vitae rutrum eros metus nec libero._',
    }, '\n'));

    simulate_input_keys('CUSTOM_DELETE')

    expect.eq(read_rendered_text(text_area), table.concat({
        '0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante ',
        'nibhorttitor mi, vitae rutrum eros metus nec libero._',
    }, '\n'));

    journal:dismiss()
end

function test.line_end()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_END')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(70)
    journal:onRender()

    simulate_input_keys('CUSTOM_END')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero._',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(200)
    journal:onRender()

    simulate_input_keys('CUSTOM_END')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_END')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    journal:dismiss()
end

function test.line_beging()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_HOME')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(173)
    journal:onRender()

    simulate_input_keys('CUSTOM_HOME')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_12: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_HOME')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.line_delete()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(65)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_'
    }, '\n'));

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_'
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_'
    }, '\n'));

    journal:dismiss()
end

function test.line_delete_to_end()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(70)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed_',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_last_word()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing _',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur _',
    }, '\n'));

    text_area:setCursor(82)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed _ urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    text_area:setCursor(37)
    journal:onRender()

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, _ctetur adipiscing elit.',
        '112: Sed , urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    for i=1,6 do
        simulate_input_keys('CUSTOM_CTRL_W')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '_ctetur adipiscing elit.',
        '112: Sed , urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_ctetur adipiscing elit.',
        '112: Sed , urna sit amet aliquet egestas, ante nibh porttitor ',
        'mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur ',
    }, '\n'));

    journal:dismiss()
end

function test.jump_to_text_end()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('KEYBOARD_CURSOR_DOWN_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_DOWN_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    journal:dismiss()
end

function test.jump_to_text_begin()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.select_all()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.text_key_replace_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_text('+')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: +_psum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 6, 1, 6, 2)

    simulate_input_text('!')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: +ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: S!_r mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 3, 1, 6, 2)

    simulate_input_text('@')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: +ipsum dolor sit amet, consectetur adipiscing elit.',
        '112@_m ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.arrows_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_LEFT')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_UP')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('KEYBOARD_CURSOR_DOWN')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.click_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_mouse_click(text_area, 4, 0)
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_mouse_click(text_area, 4, 8)
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.line_navigation_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('CUSTOM_HOME')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_END')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.jump_begin_or_end_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('KEYBOARD_CURSOR_DOWN_FAST')
    expect.eq(read_selected_text(text_area), '')

    journal:dismiss()
end

function test.new_line_override_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
         '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum ero',
    }, '\n'));

    simulate_input_keys('SELECT')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ',
        '_ metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.backspace_delete_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
         '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum ero',
    }, '\n'));

    simulate_input_keys('STRING_A000')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _ metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_char_delete_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
         '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum ero',
    }, '\n'));

    simulate_input_keys('CUSTOM_DELETE')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _ metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_line_delete_selection_lines()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_12: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 4, 1, 29, 2)

    simulate_input_keys('CUSTOM_CTRL_U')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_1: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_line_rest_delete_selection_lines()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 6, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ',
        '112: S_',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 3, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_K')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ',
        '112_',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.delete_last_word_delete_selection()
        local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 9, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ');

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _psum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 6, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: S_r mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    simulate_mouse_drag(text_area, 3, 1, 6, 2)

    simulate_input_keys('CUSTOM_CTRL_W')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: ipsum dolor sit amet, consectetur adipiscing elit.',
        '112_m ipsum dolor sit amet, consectetur adipiscing elit.',
        '51: Sed consectetur, urna sit amet aliquet egestas.',
    }, '\n'));

    journal:dismiss()
end

function test.single_mouse_click_set_cursor()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_click(text_area, 4, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: _orem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 40, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus ne_ libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 49, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero._',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 60, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero._',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 10)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 21, 10)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor_sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 63, 10)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    journal:dismiss()
end

function test.double_mouse_click_select_word()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)
    simulate_mouse_click(text_area, 0, 0)

    expect.eq(read_selected_text(text_area), '60:')

    simulate_mouse_click(text_area, 4, 0)
    simulate_mouse_click(text_area, 4, 0)

    expect.eq(read_selected_text(text_area), 'Lorem')

    simulate_mouse_click(text_area, 40, 2)
    simulate_mouse_click(text_area, 40, 2)

    expect.eq(read_selected_text(text_area), 'nec')

    simulate_mouse_click(text_area, 58, 3)
    simulate_mouse_click(text_area, 58, 3)
    expect.eq(read_selected_text(text_area), 'elit')

    simulate_mouse_click(text_area, 60, 3)
    simulate_mouse_click(text_area, 60, 3)
    expect.eq(read_selected_text(text_area), '.')

    journal:dismiss()
end

function test.double_mouse_click_select_white_spaces()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = 'Lorem ipsum dolor sit amet,     consectetur elit.'
    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), text .. '_')

    simulate_mouse_click(text_area, 29, 0)
    simulate_mouse_click(text_area, 29, 0)

    expect.eq(read_selected_text(text_area), '     ')

    journal:dismiss()
end

function test.triple_mouse_click_select_line()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)
    simulate_mouse_click(text_area, 0, 0)
    simulate_mouse_click(text_area, 0, 0)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    simulate_mouse_click(text_area, 4, 0)
    simulate_mouse_click(text_area, 4, 0)
    simulate_mouse_click(text_area, 4, 0)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    simulate_mouse_click(text_area, 40, 2)
    simulate_mouse_click(text_area, 40, 2)
    simulate_mouse_click(text_area, 40, 2)

    expect.eq(read_selected_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_mouse_click(text_area, 58, 3)
    simulate_mouse_click(text_area, 58, 3)
    simulate_mouse_click(text_area, 58, 3)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    simulate_mouse_click(text_area, 60, 3)
    simulate_mouse_click(text_area, 60, 3)
    simulate_mouse_click(text_area, 60, 3)

    expect.eq(
        read_selected_text(text_area),
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    )

    journal:dismiss()
end

function test.mouse_selection_control()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 29, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem ipsum dolor sit amet')

    simulate_mouse_drag(text_area, 0, 0, 29, 0)

    expect.eq(read_selected_text(text_area), '60: Lorem ipsum dolor sit amet')

    simulate_mouse_drag(text_area, 32, 0, 32, 1)

    expect.eq(read_selected_text(text_area), table.concat({
        'consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit am'
    }, '\n'));

    simulate_mouse_drag(text_area, 32, 1, 48, 2)

    expect.eq(read_selected_text(text_area), table.concat({
        'met aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 59, 3)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 65, 3)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 65, 6)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
    }, '\n'));

    simulate_mouse_drag(text_area, 42, 2, 42, 6)

    expect.eq(read_selected_text(text_area), table.concat({
        'libero.',
        '60: Lorem ipsum dolor sit amet, consectetur'
    }, '\n'));

    journal:dismiss()
end

function test.copy_and_paste_text_line()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_mouse_click(text_area, 15, 3)
    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum_dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 5, 0)
    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '112: _ed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 6, 0)
    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_mouse_click(text_area, 5, 6)
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: L_rem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    journal:dismiss()
end

function test.copy_and_paste_selected_text()
        local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 8, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem')

    simulate_input_keys('CUSTOM_CTRL_C')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem_ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 4, 2)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLorem_itor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Lorem_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLoremtitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 60, 4)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Lorem60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLoremtitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.Lorem_',
    }, '\n'));

    journal:dismiss()
end

function test.cut_and_paste_text_line()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit._',
    }, '\n'));

    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_',
    }, '\n'));

    simulate_mouse_click(text_area, 0, 0)
    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_click(text_area, 60, 2)
    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '_',
    }, '\n'));

    journal:dismiss()
end

function test.cut_and_paste_selected_text()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n')

    simulate_input_text(text)

    simulate_mouse_drag(text_area, 4, 0, 8, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), 'Lorem')

    simulate_input_keys('CUSTOM_CTRL_X')
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem_ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_drag(text_area, 4, 0, 8, 0)
    simulate_input_keys('CUSTOM_CTRL_X')

    simulate_mouse_click(text_area, 4, 2)

    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60:  ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLorem_itor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_drag(text_area, 5, 2, 8, 2)
    simulate_input_keys('CUSTOM_CTRL_X')

    simulate_mouse_click(text_area, 0, 0)
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'orem_0:  ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLtitor mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    }, '\n'));

    simulate_mouse_drag(text_area, 5, 2, 8, 2)
    simulate_input_keys('CUSTOM_CTRL_X')

    simulate_mouse_click(text_area, 60, 4)
    simulate_input_keys('CUSTOM_CTRL_V')

    expect.eq(read_rendered_text(text_area), table.concat({
        'orem60:  ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'portLr mi, vitae rutrum eros metus nec libero.',
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.tito_',
    }, '\n'));

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

function test.scroll_long_text()
    local journal, text_area = arrange_empty_journal({w=100, h=10})
    local scrollbar = journal.subviews.scrollbar

    local text = table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        'Nam scelerisque ligula vitae magna varius, vel porttitor tellus egestas.',
        'Suspendisse aliquet dolor ac velit maximus, ut tempor lorem tincidunt.',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
        '18: Vestibulum at ante ut dui hendrerit pellentesque ut eu ex.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
        '18: Vestibulum at ante ut dui hendrerit pellentesque ut eu ex._',
    }, '\n'))

    simulate_mouse_click(scrollbar, 0, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
    }, '\n'))

    simulate_mouse_click(scrollbar, 0, 0)
    simulate_mouse_click(scrollbar, 0, 0)

    expect.eq(read_rendered_text(text_area), table.concat({
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
    }, '\n'))

    simulate_mouse_click(scrollbar, 0, scrollbar.frame_body.height - 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
        '18: Vestibulum at ante ut dui hendrerit pellentesque ut eu ex._',
    }, '\n'))

    simulate_mouse_click(scrollbar, 0, 2)

    expect.eq(read_rendered_text(text_area), table.concat({
        'Suspendisse aliquet dolor ac velit maximus, ut tempor lorem tincidunt.',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
    }, '\n'))

    journal:dismiss()
end

function test.scroll_follows_cursor()
    local journal, text_area = arrange_empty_journal({w=100, h=10})
    local scrollbar = journal.subviews.text_area_scrollbar

    local text = table.concat({
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        'Nulla ut lacus ut tortor semper consectetur.',
        'Nam scelerisque ligula vitae magna varius, vel porttitor tellus egestas.',
        'Suspendisse aliquet dolor ac velit maximus, ut tempor lorem tincidunt.',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
        '18: Vestibulum at ante ut dui hendrerit pellentesque ut eu ex.',
    }, '\n')

    simulate_input_text(text)

    expect.eq(read_rendered_text(text_area), table.concat({
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
        '18: Vestibulum at ante ut dui hendrerit pellentesque ut eu ex._',
    }, '\n'))

    simulate_mouse_click(text_area, 0, 8)
    simulate_input_keys('KEYBOARD_CURSOR_UP')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_nteger tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        'Aenean non orci id erat malesuada pharetra.',
        'Nunc in lectus et metus finibus venenatis.',
        'Morbi id mauris dignissim, suscipit metus nec, auctor odio.',
        'Sed in libero eget velit condimentum lacinia ut quis dui.',
        'Praesent sollicitudin dui ac mollis lacinia.',
        'Ut gravida tortor ac accumsan suscipit.',
    }, '\n'))

    simulate_input_keys('KEYBOARD_CURSOR_UP_FAST')

    simulate_mouse_click(text_area, 0, 9)
    simulate_input_keys('KEYBOARD_CURSOR_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Nulla ut lacus ut tortor semper consectetur.',
        'Nam scelerisque ligula vitae magna varius, vel porttitor tellus egestas.',
        'Suspendisse aliquet dolor ac velit maximus, ut tempor lorem tincidunt.',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        '_onec quis lectus ac erat placerat eleifend.',
    }, '\n'))

    simulate_mouse_click(text_area, 44, 10)
    simulate_input_keys('KEYBOARD_CURSOR_RIGHT')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Nam scelerisque ligula vitae magna varius, vel porttitor tellus egestas.',
        'Suspendisse aliquet dolor ac velit maximus, ut tempor lorem tincidunt.',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
        '_enean non orci id erat malesuada pharetra.',
    }, '\n'))

    simulate_mouse_click(text_area, 0, 2)
    simulate_input_keys('KEYBOARD_CURSOR_LEFT')

    expect.eq(read_rendered_text(text_area), table.concat({
        'Nulla ut lacus ut tortor semper consectetur._',
        'Nam scelerisque ligula vitae magna varius, vel porttitor tellus egestas.',
        'Suspendisse aliquet dolor ac velit maximus, ut tempor lorem tincidunt.',
        'Ut eu orci non nibh hendrerit posuere.',
        'Sed euismod odio eu fringilla bibendum.',
        'Etiam dignissim diam nec aliquet facilisis.',
        'Integer tristique purus at tellus luctus, vel aliquet sapien sollicitudin.',
        'Fusce ornare est vitae urna feugiat, vel interdum quam vestibulum.',
        '10: Vivamus id felis scelerisque, lobortis diam ut, mollis nisi.',
        'Donec quis lectus ac erat placerat eleifend.',
    }, '\n'))

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

function test.fast_rewind_words_right()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)
    text_area:setCursor(1)
    journal:onRender()

    simulate_input_keys('A_MOVE_E_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60:_Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_E_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem_ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,6 do
        simulate_input_keys('A_MOVE_E_DOWN')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing_',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_E_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit._',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_E_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112:_Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,17 do
        simulate_input_keys('A_MOVE_E_DOWN')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    simulate_input_keys('A_MOVE_E_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero._',
    }, '\n'));

    journal:dismiss()
end

function test.fast_rewind_words_left()
    local journal, text_area = arrange_empty_journal({w=55})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('A_MOVE_W_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        '_ibero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_W_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus _ec ',
        'libero.',
    }, '\n'));

    for i=1,8 do
        simulate_input_keys('A_MOVE_W_DOWN')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        '_nte nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_W_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet _gestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    for i=1,16 do
        simulate_input_keys('A_MOVE_W_DOWN')
    end

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_W_DOWN')

    expect.eq(read_rendered_text(text_area), table.concat({
        '_0: Lorem ipsum dolor sit amet, consectetur adipiscing ',
        'elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ',
        'ante nibh porttitor mi, vitae rutrum eros metus nec ',
        'libero.',
    }, '\n'));

    journal:dismiss()
end

function test.fast_rewind_reset_selection()
    local journal, text_area = arrange_empty_journal({w=65})

    local text = table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n')

    simulate_input_text(text)

    simulate_input_keys('CUSTOM_CTRL_A')

    expect.eq(read_rendered_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    expect.eq(read_selected_text(text_area), table.concat({
        '60: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
        '112: Sed consectetur, urna sit amet aliquet egestas, ante nibh ',
        'porttitor mi, vitae rutrum eros metus nec libero.',
    }, '\n'));

    simulate_input_keys('A_MOVE_W_DOWN')
    expect.eq(read_selected_text(text_area), '')

    simulate_input_keys('CUSTOM_CTRL_A')

    simulate_input_keys('A_MOVE_E_DOWN')
    expect.eq(read_selected_text(text_area), '')

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

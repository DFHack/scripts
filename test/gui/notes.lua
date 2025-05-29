local gui = require('gui')
local gui_notes = reqscript('gui/notes')
local utils = require('utils')
local guidm = require('gui.dwarfmode')
local overlay = require('plugins.overlay')
local notes_textures = reqscript('notes').textures

config = {
    target = 'gui/notes',
    mode = 'fortress'
}

local waypoints = df.global.plotinfo.waypoints
local map_points = df.global.plotinfo.waypoints.points

local map_points_backup = nil

local function arrange_notes(notes)
    map_points_backup = utils.clone(map_points)
    map_points:resize(0)

    for _, note in ipairs(notes or {}) do
        map_points:insert("#", {
            new=true,

            id=waypoints.next_point_id,
            tile=88,
            fg_color=7,
            bg_color=0,
            name=note.name,
            comment=note.comment,
            pos=note.pos
        })

        waypoints.next_point_id = waypoints.next_point_id + 1
    end
end

local function arrange_gui_notes(options)
    options = options or {}

    -- running tests removes all overlays because of IN_TEST reloading.
    -- rescan so we can load the gui/notes widget for these tests
    overlay.rescan()

    arrange_notes(options.notes)

    gui_notes.main()

    local view = gui_notes.view
    view.enable_selector_blink = false

    view:updateLayout()
    view:onRender()

    return view, view.subviews.notes_window
end

local function cleanup(gui_notes)
    gui_notes:dismiss()

    df.global.plotinfo.waypoints.points:resize(#map_points_backup)
    for ind, map_point in ipairs(map_points_backup) do
        df.global.plotinfo.waypoints.points[ind - 1] = map_point
    end
    map_points_backup = nil
end

function get_visible_map_center()
    local viewport = guidm.Viewport.get()

    local half_x = math.max(
        math.floor((viewport.x1 + viewport.x2) / 2),
        2
    )
    local half_y = math.max(
        math.floor((viewport.y1 + viewport.y2) / 2),
        2
    )

    return half_x, half_y, viewport.z
end

function test.load_gui_notes()
    local gui_notes = arrange_gui_notes()
    expect.eq(gui_notes.visible, true)
    cleanup(gui_notes)
end

function test.provide_notes_list()
    local notes = {
        {name='note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes = arrange_gui_notes({ notes=notes })
    local note_list = gui_notes.subviews.note_list:getChoices()

    for ind, note in ipairs(notes) do
        local gui_note = note_list[ind]
        expect.eq(gui_note.text, note.name)
        expect.eq(gui_note.point.comment, note.comment)
        expect.table_eq(gui_note.point.pos, note.pos)
    end

    cleanup(gui_notes)
end

function test.auto_select_first_note()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='green note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='blue note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes = arrange_gui_notes({ notes=notes })
    expect.eq(gui_notes.subviews.name.text_to_wrap, 'green note 1')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 1')

    cleanup(gui_notes)
end

function test.select_on_arrow_up_down()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='green note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='blue note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes = arrange_gui_notes({ notes=notes })
    local screen = dfhack.gui.getCurViewscreen(true)

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
    expect.eq(gui_notes.subviews.name.text_to_wrap, 'green note 2')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 2')

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
    expect.eq(gui_notes.subviews.name.text_to_wrap, 'blue note 3')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 3')

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
    expect.eq(gui_notes.subviews.name.text_to_wrap, 'green note 1')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 1')

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_UP')
    expect.eq(gui_notes.subviews.name.text_to_wrap, 'blue note 3')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 3')

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_UP')
    expect.eq(gui_notes.subviews.name.text_to_wrap, 'green note 2')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 2')

    cleanup(gui_notes)
end

function test.center_at_submit_note()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='green note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='blue note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes = arrange_gui_notes({ notes=notes })
    local screen = dfhack.gui.getCurViewscreen(true)

    -- it would be best to check viewport, but it's not updated instantly
    -- and I do not know way how to force it
    -- local viewport = guidm.Viewport.get()

    local last_recenter_pos = nil
    mock.patch(dfhack.gui, 'pauseRecenter', function (pos)
        last_recenter_pos = pos
    end, function ()
        gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
        gui.simulateInput(screen, 'SELECT')

        expect.eq(last_recenter_pos.x, 2)
        expect.eq(last_recenter_pos.y, 2)
        expect.eq(last_recenter_pos.z, 2)

        gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
        gui.simulateInput(screen, 'SELECT')

        expect.eq(last_recenter_pos.x, 3)
        expect.eq(last_recenter_pos.y, 3)
        expect.eq(last_recenter_pos.z, 3)
    end)

    cleanup(gui_notes)
end

function test.filter_notes()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='green note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='blue note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes = arrange_gui_notes({ notes=notes })
    gui_notes.subviews.search:setText('green')

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 2)

    for ind, note in ipairs({table.unpack(notes, 1, 2)}) do
        local gui_note = note_list[ind]
        expect.eq(gui_note.text, note.name)
        expect.eq(gui_note.point.comment, note.comment)
        expect.table_eq(gui_note.point.pos, note.pos)
    end

    expect.eq(gui_notes.subviews.name.text_to_wrap, 'green note 1')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 1')

    gui_notes.subviews.search:setText('blue')

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 1)

    expect.eq(note_list[1].text, notes[3].name)
    expect.eq(note_list[1].point.comment, notes[3].comment)
    expect.table_eq(note_list[1].point.pos, notes[3].pos)

    expect.eq(gui_notes.subviews.name.text_to_wrap, 'blue note 3')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 3')

    gui_notes.subviews.search:setText('red')

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 0)

    cleanup(gui_notes)
end

function test.edit_note()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='green note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='blue note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes, gui_notes_window = arrange_gui_notes({ notes=notes })
    local screen = dfhack.gui.getCurViewscreen(true)

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
    gui.simulateInput(screen, 'CUSTOM_CTRL_E')

    local note_manager = gui_notes_window.note_manager
    expect.ne(note_manager, nil)

    expect.eq(note_manager.subviews.name:getText(), 'green note 2')
    expect.eq(note_manager.subviews.comment:getText(), 'comment 2')

    note_manager.subviews.name:setText('updated green note 2')
    note_manager.subviews.comment:setText('updated comment 2')
    local screen = dfhack.gui.getCurViewscreen(true)
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_ENTER')

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 3)

    local updated_note = note_list[2]

    expect.eq(updated_note.text, 'updated green note 2')
    expect.eq(updated_note.point.name, 'updated green note 2')
    expect.eq(updated_note.point.comment, 'updated comment 2')

    cleanup(gui_notes)
end

function test.delete_note()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
        {name='green note 2', comment='comment 2', pos={x=2, y=2, z=2}},
        {name='blue note 3', comment='comment 3', pos={x=3, y=3, z=3}},
    }

    local gui_notes = arrange_gui_notes({ notes=notes })
    local screen = dfhack.gui.getCurViewscreen(true)

    gui.simulateInput(screen, 'KEYBOARD_CURSOR_DOWN')
    gui.simulateInput(screen, 'CUSTOM_CTRL_D')

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 2)

    for ind, note in ipairs({notes[1], notes[3]}) do
        local gui_note = note_list[ind]
        expect.eq(gui_note.text, note.name)
        expect.eq(gui_note.point.comment, note.comment)
        expect.table_eq(gui_note.point.pos, note.pos)
    end

    expect.eq(gui_notes.subviews.name.text_to_wrap, 'blue note 3')
    expect.eq(gui_notes.subviews.comment.text_to_wrap, 'comment 3')

    cleanup(gui_notes)
end

function test.create_new_note()
    local notes = {
        {name='green note 1', comment='comment 1', pos={x=1, y=1, z=1}},
    }

    local gui_notes, gui_notes_window = arrange_gui_notes({ notes=notes })

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 1)

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_N')

    local viewport = guidm.Viewport.get()

    local half_x, half_y = get_visible_map_center()

    local pos = {x=half_x, y=half_y, z=viewport.z}
    local screen_pos = viewport:tileToScreen(pos)
    df.global.cursor = pos

    -- should not be a test function to map screen tile to mouse pos?
    df.global.gps.precise_mouse_x = screen_pos.x * df.global.gps.viewport_zoom_factor / 4
    df.global.gps.precise_mouse_y = screen_pos.y * df.global.gps.viewport_zoom_factor / 4

    df.global.gps.mouse_x = screen_pos.x
    df.global.gps.mouse_y = screen_pos.y

    gui_notes:render(gui.Painter.new())

    local pen = dfhack.screen.readTile(screen_pos.x, screen_pos.y, true)

    if dfhack.screen.inGraphicsMode() then
        local pin_textpos = dfhack.textures.getTexposByHandle(
            notes_textures.green_pin[1]
        )
        expect.eq(pen and pen.tile, pin_textpos)
    else
        expect.eq(pen and pen.ch, string.byte('X'))
    end

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })

    local note_manager = gui_notes_window.note_manager

    expect.ne(note_manager, nil)
    expect.eq(note_manager.visible, true)

    note_manager.subviews.name:setText('note 2')
    note_manager.subviews.comment:setText('new note')

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_ENTER')

    local note_list = gui_notes.subviews.note_list:getChoices()
    expect.eq(#note_list, 2)

    local gui_note = note_list[2]
    expect.eq(gui_note.text, 'note 2')
    expect.eq(gui_note.point.comment, 'new note')
    expect.table_eq(gui_note.point.pos, pos)

    cleanup(gui_notes)
end

local gui = require('gui')
local gui_notes = reqscript('gui/notes')
local utils = require('utils')
local guidm = require('gui.dwarfmode')


-- local guidm = require('gui.dwarfmode')

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

    arrange_notes(options.notes)

    gui_notes.main()

    local gui_notes = gui_notes.view

    gui_notes:updateLayout()
    gui_notes:onRender()

    return gui_notes
end

local function cleanup(gui_notes)
    gui_notes:dismiss()

    df.global.plotinfo.waypoints.points:resize(#map_points_backup)
    for ind, map_point in ipairs(map_points_backup) do
        df.global.plotinfo.waypoints.points[ind - 1] = map_point
    end
    map_points_backup = nil
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

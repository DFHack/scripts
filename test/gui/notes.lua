local gui = require('gui')
local gui_notes = reqscript('gui/notes')
local utils = require('utils')

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

            id = waypoints.next_point_id,
            tile=88,
            fg_color=7,
            bg_color=0,
            name=note.name,
            comment=note.comment,
            pos=note.pos
        })
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

    expect.eq(gui_notes.visible, true)
    cleanup(gui_notes)
end

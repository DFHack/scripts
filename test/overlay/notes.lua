local gui = require('gui')
local overlay = require('plugins.overlay')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local notes_textures = reqscript('notes').textures

local waypoints = df.global.plotinfo.waypoints
local map_points = df.global.plotinfo.waypoints.points

config = {
    target = 'notes',
    mode = 'fortress'
}

local map_points_backup = nil

local function install_notes_overlay(options)
    options = options or {}

    map_points_backup = utils.clone(map_points)
    map_points:resize(0)

    overlay.rescan()
    overlay.overlay_command({'enable', 'notes.map_notes'})
    -- if overlay
    local overlay_state = overlay.get_state()
    if not overlay_state.config['notes.map_notes'].enabled then
        qerror('can not enable notes.map_notes overlay')
    end

    return overlay_state.db['notes.map_notes'].widget
end

local function reload_notes()
    overlay.overlay_command({'trigger', 'notes.map_notes'})
end

local function cleanup(notes_overlay)
    if notes_overlay.note_manager then
        notes_overlay.note_manager:dismiss()
    end

    df.global.plotinfo.waypoints.points:resize(#map_points_backup)
    for ind, map_point in ipairs(map_points_backup) do
        df.global.plotinfo.waypoints.points[ind - 1] = map_point
    end
    map_points_backup = nil

    reload_notes()
end

local function add_note(notes_overlay, pos, name, comment)
    df.global.cursor = copyall(pos)

    local cmd_result = overlay.overlay_command({
        'trigger', 'notes.map_notes', 'add'
    })

    notes_overlay.note_manager.subviews.name:setText(name)
    notes_overlay.note_manager.subviews.comment:setText(comment)

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_ENTER')
end


function test.load_notes_overlay()
    local notes_overlay = install_notes_overlay()
    expect.ne(notes_overlay, nil)
    cleanup(notes_overlay)
end

function test.trigger_add_new_note_modal()
    local notes_overlay = install_notes_overlay()

    local cmd_result = overlay.overlay_command({
        'trigger', 'notes.map_notes', 'add'
    })

    expect.eq(cmd_result, true)
    expect.ne(notes_overlay.note_manager, nil)
    expect.eq(notes_overlay.note_manager.visible, true)

    cleanup(notes_overlay)
end

function test.render_existing_notes()
    local notes_overlay = install_notes_overlay()

    local pos_1 = {x=10, y=20, z=0}
    local pos_2 = {x=10, y=20, z=0}
    local pos_3 = {x=10, y=20, z=0}

    add_note(notes_overlay, pos_1, 'note 1', 'first note')
    add_note(notes_overlay, pos_2, 'note 2', 'second note')
    add_note(notes_overlay, pos_3, 'note 3', 'last note')

    reload_notes()

    local viewport = guidm.Viewport.get()

    local pin_textpos = dfhack.textures.getTexposByHandle(
        notes_textures.green_pin[1]
    )

    for _, pos in ipairs({pos_1, pos_2, pos_3}) do
        dfhack.gui.revealInDwarfmodeMap(pos)

        -- TODO: find better way to wait for overlay re-render
        delay(10)

        local screen_pos = viewport:tileToScreen(pos)
        local pen = dfhack.screen.readTile(screen_pos.x, screen_pos.y, true)
        expect.eq(pen and pen.tile, pin_textpos)
    end

    cleanup(notes_overlay)
end

function test.edit_clicked_note()
    local notes_overlay = install_notes_overlay()

    local pos = {x=10, y=20, z=0}
    add_note(notes_overlay, pos, 'note 1', 'note to edit')
    add_note(notes_overlay, {x=20, y=10, z=2}, 'note 2', 'other note')
    add_note(notes_overlay, {x=0, y=10, z=5}, 'note 3', 'another note')

    reload_notes()
    dfhack.screen.invalidate()
    dfhack.gui.revealInDwarfmodeMap(pos)

    -- TODO: find better way to wait for overlay re-render
    delay(10)

    notes_overlay:updateLayout()

    local viewport = guidm.Viewport.get()
    local screen_pos = viewport:tileToScreen(pos)

    local rect = gui.ViewRect{rect=notes_overlay.frame_rect}

    -- should not be a test function to map screen tile to mouse pos?
    df.global.gps.precise_mouse_x = screen_pos.x * df.global.gps.viewport_zoom_factor / 4
    df.global.gps.precise_mouse_y = screen_pos.y * df.global.gps.viewport_zoom_factor / 4

    local screen = dfhack.gui.getCurViewscreen(true)
    gui.simulateInput(screen, {
        _MOUSE_L=true,
    })

    local note_manager = notes_overlay.note_manager
    expect.ne(note_manager, nil)

    expect.eq(note_manager.subviews.name:getText(), 'note 1')
    expect.eq(note_manager.subviews.comment:getText(), 'note to edit')

    note_manager.subviews.name:setText('edited note 1')
    note_manager.subviews.comment:setText('edited comment')

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_ENTER')

    expect.eq(map_points[0].name, 'edited note 1')
    expect.eq(map_points[0].comment, 'edited comment')

    cleanup(notes_overlay)
end

function test.delete_clicked_note()
    local notes_overlay = install_notes_overlay()

    local pos = {x=10, y=20, z=0}
    add_note(notes_overlay, {x=20, y=10, z=2}, 'note 1', 'note to edit')
    add_note(notes_overlay, pos, 'note 2', 'other note')
    add_note(notes_overlay, {x=0, y=10, z=5}, 'note 3', 'another note')

    reload_notes()
    dfhack.screen.invalidate()
    dfhack.gui.revealInDwarfmodeMap(pos)

    notes_overlay:updateLayout()

    local viewport = guidm.Viewport.get()
    local screen_pos = viewport:tileToScreen(pos)

    local rect = gui.ViewRect{rect=notes_overlay.frame_rect}

    -- should not be a test function to map screen tile to mouse pos?
    df.global.gps.precise_mouse_x = screen_pos.x * df.global.gps.viewport_zoom_factor / 4
    df.global.gps.precise_mouse_y = screen_pos.y * df.global.gps.viewport_zoom_factor / 4

    local screen = dfhack.gui.getCurViewscreen(true)
    gui.simulateInput(screen, {
        _MOUSE_L=true,
    })

    expect.eq(#map_points, 3)

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_D')

    expect.eq(#map_points, 2)
    expect.eq(map_points[0].name, 'note 1')
    expect.eq(map_points[1].name, 'note 3')

    cleanup(notes_overlay)
end

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
local was_overlay_enabled = overlay.isEnabled()

local function install_notes_overlay(options)
    options = options or {}

    map_points_backup = utils.clone(map_points)
    map_points:resize(0)

    local was_overlay_enabled = overlay.isEnabled()

    overlay.setEnabled(true)
    overlay.rescan()
    overlay.overlay_command({'enable', 'notes.map_notes'})

    if not overlay.isOverlayEnabled('notes.map_notes') then
        qerror('can not enable notes.map_notes overlay')
    end

    local overlay_state = overlay.get_state()

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

    overlay.setEnabled(was_overlay_enabled)
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

function assert_note_pen(pen)
    if dfhack.screen.inGraphicsMode() then
        local pin_textpos = dfhack.textures.getTexposByHandle(
            notes_textures.green_pin[1]
        )
        expect.eq(pen and pen.tile, pin_textpos)
    else
        expect.eq(pen and pen.ch, string.byte('N'))
    end
end

function set_mouse_screen_pos(screen_pos)
    -- should not be a test function to map screen tile to mouse pos?
    df.global.gps.precise_mouse_x = screen_pos.x * df.global.gps.viewport_zoom_factor / 4
    df.global.gps.precise_mouse_y = screen_pos.y * df.global.gps.viewport_zoom_factor / 4

    df.global.gps.mouse_x = screen_pos.x
    df.global.gps.mouse_y = screen_pos.y

end

function get_visible_map_center()
    local viewport = guidm.Viewport.get()

    local map_width, map_height = dfhack.maps.getTileSize()
    local world_rect = gui.mkdims_wh(0, 0, map_width, map_height)
    -- find center of visible part of the map
    local map_rect = gui.ViewRect{rect=world_rect}:viewport(viewport)

    local half_x = math.floor((map_rect.clip_x1 + map_rect.clip_x2) / 2)
    local normalized_half_x = math.min(
        math.max(half_x, map_rect.clip_x1),
        map_rect.clip_x2
    )

    local half_y = math.floor((map_rect.clip_y1 + map_rect.clip_y2) / 2)
    local normalized_half_y = math.min(
        math.max(half_y, map_rect.clip_y1),
        map_rect.clip_y2
    )

    return normalized_half_x, normalized_half_y, viewport.z
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

    local viewport = guidm.Viewport.get()

    local half_x, half_y = get_visible_map_center()

    local pos_1 = {x=half_x, y=half_y, z=viewport.z}
    local pos_2 = {x=half_x - 2, y=half_y + 2, z=viewport.z}
    local pos_3 = {x=half_x + 2, y=half_y + 2, z=viewport.z}

    add_note(notes_overlay, pos_1, 'note 1', 'first note')
    add_note(notes_overlay, pos_2, 'note 2', 'second note')
    add_note(notes_overlay, pos_3, 'note 3', 'last note')

    reload_notes()

    for _, pos in ipairs({pos_1, pos_2, pos_3}) do
        notes_overlay:render(gui.Painter.new())

        local screen_pos = viewport:tileToScreen(pos)
        local pen = dfhack.screen.readTile(screen_pos.x, screen_pos.y, true)
        assert_note_pen(pen)
    end

    cleanup(notes_overlay)
end

function test.edit_clicked_note()
    local notes_overlay = install_notes_overlay()

    local viewport = guidm.Viewport.get()

    local half_x, half_y, z = get_visible_map_center()

    local pos_1 = {x=half_x, y=half_y, z=viewport.z}
    local pos_2 = {x=half_x - 2, y=half_y + 2, z=viewport.z}
    local pos_3 = {x=half_x + 2, y=half_y + 2, z=viewport.z}

    add_note(notes_overlay, pos_1, 'note 1', 'note to edit')
    add_note(notes_overlay, pos_2, 'note 2', 'other note')
    add_note(notes_overlay, pos_3, 'note 3', 'another note')

    reload_notes()

    local screen_pos = viewport:tileToScreen(pos_1)

    set_mouse_screen_pos(screen_pos)

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })

    local note_manager = notes_overlay.note_manager
    expect.ne(note_manager, nil)
    expect.eq(note_manager:isDismissed(), false)

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

    local viewport = guidm.Viewport.get()

    local half_x, half_y = get_visible_map_center()

    local pos_1 = {x=half_x, y=half_y, z=viewport.z}
    local pos_2 = {x=half_x - 2, y=half_y + 2, z=viewport.z}
    local pos_3 = {x=half_x + 2, y=half_y + 2, z=viewport.z}

    add_note(notes_overlay, pos_1, 'note 1', 'note to edit')
    add_note(notes_overlay, pos_2, 'note 2', 'other note')
    add_note(notes_overlay, pos_3, 'note 3', 'another note')

    reload_notes()

    local screen_pos = viewport:tileToScreen(pos_2)

    local rect = gui.ViewRect{rect=notes_overlay.frame_rect}

    set_mouse_screen_pos(screen_pos)

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), {
        _MOUSE_L=true,
        _MOUSE_L_DOWN=true,
    })

    expect.eq(#map_points, 3)

    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'CUSTOM_CTRL_D')

    expect.eq(#map_points, 2)
    expect.eq(map_points[0].name, 'note 1')
    expect.eq(map_points[1].name, 'note 3')

    cleanup(notes_overlay)
end

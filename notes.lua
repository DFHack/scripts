--@ module = true

local overlay = require('plugins.overlay')
local guidm = require('gui.dwarfmode')
local note_manager = reqscript('internal/notes/note_manager')

local green_pin = dfhack.textures.loadTileset(
    'hack/data/art/note_green_pin_map.png',
    32,
    32,
    true
)

NotesOverlay = defclass(NotesOverlay, overlay.OverlayWidget)
NotesOverlay.ATTRS{
    desc='Render map notes.',
    viewscreens='dwarfmode',
    default_enabled=true,
    overlay_onupdate_max_freq_seconds=30,
}

local map_points = df.global.plotinfo.waypoints.points

function NotesOverlay:init()
    self.visible_notes = {}
    self.note_manager = nil
    self.last_click_pos = {}
    self:reloadVisibleNotes()
end

function NotesOverlay:overlay_onupdate()
    self:reloadVisibleNotes()
end

function NotesOverlay:overlay_trigger(cmd)
    if cmd == 'add' then
        self:showNoteManager()
    else
        self:reloadVisibleNotes()
    end
end

function NotesOverlay:onInput(keys)
    if keys._MOUSE_L then
        local top_most_screen = dfhack.gui.getDFViewscreen(true)
        if dfhack.gui.matchFocusString('dwarfmode/Default', top_most_screen) then
            local pos = dfhack.gui.getMousePos()
            if pos == nil then
                return false
            end

            local note = self:clickedNote(pos)
            if note ~= nil then
                self:showNoteManager(note)
            end
        end
    end
end

function NotesOverlay:clickedNote(click_pos)
    local pos_curr_note = same_xyz(self.last_click_pos, click_pos)
        and self.note_manager
        and self.note_manager.note
        or nil

    self.last_click_pos = click_pos

    local last_note_on_pos = nil
    local first_note_on_pos = nil
    for _, note in ipairs(self.visible_notes) do
        if same_xyz(note.point.pos, click_pos) then
            if (last_note_on_pos and pos_curr_note
                and last_note_on_pos.point.id == pos_curr_note.point.id
            ) then
                return note
            end

            first_note_on_pos = first_note_on_pos or note
            last_note_on_pos = note
        end
    end

    return first_note_on_pos
end

function NotesOverlay:showNoteManager(note)
    if self.note_manager ~= nil then
        self.note_manager:dismiss()
    end

    self.note_manager = note_manager.NoteManager{
        note=note,
        on_update=function() self:reloadVisibleNotes() end
    }

    return self.note_manager:show()
end

function NotesOverlay:viewportChanged()
    return self.viewport_pos.x ~=  df.global.window_x or
        self.viewport_pos.y ~=  df.global.window_y or
        self.viewport_pos.z ~=  df.global.window_z
end

function NotesOverlay:onRenderFrame(dc)
    if not df.global.pause_state and not dfhack.screen.inGraphicsMode() then
        return
    end

    if self:viewportChanged() then
        self:reloadVisibleNotes()
    end

    dc:map(true)

    local texpos = dfhack.textures.getTexposByHandle(green_pin[1])
    dc:pen({fg=COLOR_BLACK, bg=COLOR_LIGHTCYAN, tile=texpos})

    for _, note in pairs(self.visible_notes) do
        dc
            :seek(note.screen_pos.x, note.screen_pos.y)
            :char('N')
    end

    dc:map(false)
end

function NotesOverlay:reloadVisibleNotes()
    self.visible_notes = {}

    local viewport = guidm.Viewport.get()
    self.viewport_pos = {
        x=df.global.window_x,
        y=df.global.window_y,
        z=df.global.window_z
    }

    for _, map_point in ipairs(map_points) do
        if (viewport:isVisible(map_point.pos)
            and map_point.name ~= nil and #map_point.name > 0)
        then
            local screen_pos = viewport:tileToScreen(map_point.pos)
            table.insert(self.visible_notes, {
                point=map_point,
                screen_pos=screen_pos
            })
        end
    end
end

-- register widgets
OVERLAY_WIDGETS = {
    map_notes=NotesOverlay
}

local function main(args)
    if #args == 0 then
        return
    end

    if args[1] == 'add' then
        local cursor_pos = guidm.getCursorPos()
        if cursor_pos == nil then
            dfhack.printerr('Enable keyboard cursor to add a note.')
            return
        end

        return dfhack.run_command_silent('overlay trigger notes.map_notes add')
    end
end

if not dfhack_flags.module then
    main({...})
end

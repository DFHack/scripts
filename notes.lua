--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')
local textures = require('gui.textures')
local overlay = require('plugins.overlay')
local guidm = require('gui.dwarfmode')

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

local waypoints = df.global.plotinfo.waypoints
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

function NotesOverlay:overlay_trigger(args)
    return self:showNoteManager()
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

    self.note_manager = NoteManager{
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

NoteManager = defclass(NoteManager, gui.ZScreen)
NoteManager.ATTRS{
    focus_path='notes/note-manager',
    note=DEFAULT_NIL,
    on_update=DEFAULT_NIL,
}

function NoteManager:init()
    local edit_mode = self.note ~= nil

    self:addviews{
        widgets.Window{
            frame={w=35,h=20},
            frame_inset={t=1},
            frame_title='Notes',
            resizable=true,
            subviews={
                widgets.HotkeyLabel {
                    key='CUSTOM_ALT_N',
                    label='Name',
                    frame={l=0,t=0},
                    auto_width=true,
                    on_activate=function() self.subviews.name:setFocus(true) end,
                },
                widgets.TextArea{
                    view_id='name',
                    frame={t=1,h=3},
                    frame_style=gui.FRAME_INTERIOR,
                    init_text=self.note and self.note.point.name or '',
                    init_cursor=self.note and #self.note.point.name+1 or 1,
                    one_line_mode=true
                },
                widgets.HotkeyLabel {
                    key='CUSTOM_ALT_C',
                    label='Comment',
                    frame={l=0,t=5},
                    auto_width=true,
                    on_activate=function() self.subviews.comment:setFocus(true) end,
                },
                widgets.TextArea{
                    view_id='comment',
                    frame={t=6,b=3},
                    frame_style=gui.FRAME_INTERIOR,
                    init_text=self.note and self.note.point.comment or '',
                    init_cursor=1
                },
                widgets.Panel{
                    view_id='buttons',
                    frame={b=0,h=1},
                    frame_inset={l=1,r=1},
                    subviews={
                        widgets.HotkeyLabel{
                            view_id='Save',
                            frame={l=0,t=0,h=1},
                            auto_width=true,
                            label='Save',
                            key='CUSTOM_ALT_S',
                            visible=edit_mode,
                            on_activate=function() self:saveNote() end,
                            enabled=function() return #self.subviews.name:getText() > 0 end,
                        },
                        widgets.HotkeyLabel{
                            view_id='Create',
                            frame={l=0,t=0,h=1},
                            auto_width=true,
                            label='Create',
                            key='CUSTOM_ALT_S',
                            visible=not edit_mode,
                            on_activate=function() self:createNote() end,
                            enabled=function() return #self.subviews.name:getText() > 0 end,
                        },
                        widgets.HotkeyLabel{
                            view_id='delete',
                            frame={r=0,t=0,h=1},
                            auto_width=true,
                            label='Delete',
                            key='CUSTOM_ALT_D',
                            visible=edit_mode,
                            on_activate=function() self:deleteNote() end,
                        } or nil,
                    }
                }
            },
        },
    }
end

function NoteManager:createNote()
    local cursor_pos = guidm.getCursorPos()
    if cursor_pos == nil then
        dfhack.printerr('Enable keyboard cursor to add a note.')
        return
    end

    local name = self.subviews.name:getText()
    local comment = self.subviews.comment:getText()

    if #name == 0 then
        dfhack.printerr('Note need at least a name')
        return
    end

    map_points:insert("#", {
        new=true,

        id = waypoints.next_point_id,
        tile=88,
        fg_color=7,
        bg_color=0,
        name=name,
        comment=comment,
        pos=cursor_pos
    })
    waypoints.next_point_id = waypoints.next_point_id + 1

    if self.on_update then
        self.on_update()
    end

    self:dismiss()
end

function NoteManager:saveNote()
    if self.note == nil then
        return
    end

    local name = self.subviews.name:getText()
    local comment = self.subviews.comment:getText()

    if #name == 0 then
        dfhack.printerr('Note need at least a name')
        return
    end

    self.note.point.name = name
    self.note.point.comment = comment

    if self.on_update then
        self.on_update()
    end

    self:dismiss()
end

function NoteManager:deleteNote()
    if self.note == nil then
        return
    end

    for ind, map_point in pairs(map_points) do
        if map_point.id == self.note.point.id then
            map_points:erase(ind)
            break
        end
    end

    if self.on_update then
        self.on_update()
    end

    self:dismiss()
end

function NoteManager:onDismiss()
    self.note = nil
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

        return dfhack.internal.runCommand('overlay trigger notes.map_notes')
    end
end

if not dfhack_flags.module then
    main({...})
end

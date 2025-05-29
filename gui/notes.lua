-- Map notes
--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local guidm = require 'gui.dwarfmode'
local script = require 'gui.script'
local overlay = require 'plugins.overlay'
local utils = require 'utils'

local note_manager = reqscript('internal/notes/note_manager')
local notes_textures = reqscript('notes').textures

local map_points = df.global.plotinfo.waypoints.points

local NOTE_LIST_RESIZE_MIN = {w=26}
local RESIZE_MIN = {w=65, h=30}
local NOTE_SEARCH_BATCH_SIZE = 25
local OVERLAY_NAME = 'notes.map_notes'

NotesWindow = defclass(NotesWindow, widgets.Window)
NotesWindow.ATTRS {
    frame_title='DF Notes',
    resizable=true,
    resize_min=RESIZE_MIN,
    frame_inset={l=0,r=0,t=0,b=0},
    on_note_add=DEFAULT_NIL
}

function NotesWindow:init()
    self.selected_note = nil
    self.note_manager = nil
    self.curr_search_phrase = nil

    local left_panel_content = {
        widgets.Panel{
            frame={l=0,h=3},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.EditField{
                    view_id='search',
                    on_change=self:callback('loadFilteredNotes'),
                    on_submit=function()
                        self.subviews.note_list:submit()
                    end
                },
            }
        },
        widgets.List{
            view_id='note_list',
            frame={l=0,b=2},
            frame_inset={t=1},
            row_height=1,
            on_select=function (ind, note)
                self:loadNote(note)
            end,
            on_submit=function (ind, note)
                self:loadNote(note)
                dfhack.gui.pauseRecenter(note.point.pos)
            end
        },
    }

    self:addviews{
        widgets.Panel{
            view_id='note_list_panel',
            frame={l=0, w=NOTE_LIST_RESIZE_MIN.w, t=0, b=1},
            visible=true,
            frame_inset={l=1,t=1,b=1,r=1},
            autoarrange_subviews=true,
            subviews=left_panel_content,
        },
        widgets.HotkeyLabel{
            view_id='create',
            frame={l=1,b=1,h=1},
            auto_width=true,
            label='New note',
            key='CUSTOM_CTRL_N',
            visible=true,
            on_activate=function()
                if self.on_note_add then
                    self:on_note_add()
                end
            end,
        },
        widgets.Divider{
            frame={l=NOTE_LIST_RESIZE_MIN.w,t=0,b=0,w=1},

            interior_b=false,
            frame_style_t=false,
            frame_style_b=false,
        },
        widgets.Panel{
            view_id='note_details',
            frame={l=NOTE_LIST_RESIZE_MIN.w + 1,t=0,b=0},
            frame_inset=1,
            subviews={
                widgets.Panel{
                    view_id="name_panel",
                    frame_title='Name',
                    frame_style=gui.FRAME_INTERIOR,
                    frame={l=0,r=0,t=0,h=4},
                    frame_inset={l=1,r=1},
                    subviews={
                        widgets.WrappedLabel{
                            view_id='name',
                            auto_height=false,
                            frame={l=0,r=0,t=0,b=0},
                        },
                    },
                },
                widgets.Panel{
                    view_id="comment_panel",
                    frame_title='Comment',
                    frame_style=gui.FRAME_INTERIOR,
                    frame={l=0,r=0,t=4,b=2},
                    frame_inset={l=1,r=1,t=1},
                    subviews={
                        widgets.WrappedLabel{
                            view_id='comment',
                            auto_height=false,
                            frame={l=0,r=0,t=0,b=0},
                        },
                    }
                },
                widgets.Panel{
                    frame={l=0,r=0,b=0,h=2},
                    frame_inset={l=1,r=1,t=1},
                    subviews={
                        widgets.HotkeyLabel{
                            view_id='edit',
                            frame={l=0,t=0,h=1},
                            auto_width=true,
                            label='Edit',
                            key='CUSTOM_CTRL_E',
                            on_activate=function() self:showNoteManager(self.selected_note) end,
                        },
                        widgets.HotkeyLabel{
                            view_id='delete',
                            frame={r=0,t=0,h=1},
                            auto_width=true,
                            label='Delete',
                            key='CUSTOM_CTRL_D',
                            on_activate=function() self:deleteNote(self.selected_note) end,
                        },
                    }
                }
            }
        }
    }
end

function NotesWindow:postUpdateLayout()
    if self.curr_search_phrase == nil then
        self:loadFilteredNotes('', true)
    end
end

function NotesWindow:showNoteManager(note)
    if self.note_manager ~= nil then
        self.note_manager:dismiss()
    end

    self.note_manager = note_manager.NoteManager{
        note=note,
        on_update=function()
            self:reloadFilteredNotes()
            dfhack.run_command_silent('overlay trigger notes.map_notes')
        end,
        on_dismiss=function() self.visible = true end
    }

    self.visible = false
    return self.note_manager:show():raise()
end

function NotesWindow:deleteNote(note)
    for ind, map_point in pairs(map_points) do
        if map_point.id == note.point.id then
            map_points:erase(ind)
            break
        end
    end

    self:reloadFilteredNotes()
end

function NotesWindow:loadNote(note)
    self.selected_note = note

    if note == nil then
        return
    end

    self.subviews.name.text_to_wrap = self.selected_note.point.name
    self.subviews.comment.text_to_wrap = self.selected_note.point.comment

    self.subviews.note_details:updateLayout()
end

function NotesWindow:reloadFilteredNotes()
    self:loadFilteredNotes(self.curr_search_phrase, true)
end

function NotesWindow:loadFilteredNotes(search_phrase, force)
    local full_list_loaded = self.curr_search_phrase == ''

    search_phrase = search_phrase:lower()

    self.curr_search_phrase = search_phrase

    script.start(function ()
        if #search_phrase == 0 and full_list_loaded and not force then
            return
        end

        local choices = {}

        for ind, map_point in ipairs(map_points) do
            if ind > 0 and ind % NOTE_SEARCH_BATCH_SIZE == 0 then
                script.sleep(1, 'frames')
            end
            if self.curr_search_phrase ~= search_phrase then
                -- stop the work if user provided new search phrase
                return
            end

            if (
                 #map_point.name > 0 and
                utils.search_text(map_point.name, search_phrase)
            ) then
                table.insert(choices, {
                    text=map_point.name,
                    point=map_point
                })
            end
        end

        self.subviews.note_list:setChoices(choices)

        local sel_ind, sel_note = self.subviews.note_list:getSelected()
        self:loadNote(sel_note)
    end)
end

NotesScreen = defclass(NotesScreen, gui.ZScreen)
NotesScreen.ATTRS {
    focus_path='gui/notes',
    pass_movement_keys=true,
    enable_selector_blink = true,
}

function NotesScreen:init()
    self.is_adding_note = false
    self.adding_note_pos = nil
    self:addviews{
        NotesWindow{
            view_id='notes_window',
            frame={w=RESIZE_MIN.w, h=35},
            on_note_add=self:callback('startNoteAdd')
        },
    }
end

function NotesScreen:startNoteAdd()
    self.adding_note_pos = nil
    self.subviews.notes_window.visible = false
    self.is_adding_note = true
end

function NotesScreen:stopNoteAdd()
    self.subviews.notes_window.visible = true
    self.is_adding_note = false
end

function NotesScreen:onInput(keys)
    if self.is_adding_note then
        if (keys.SELECT or keys._MOUSE_L) then
            self.adding_note_pos = dfhack.gui.getMousePos()

            local note_manager = note_manager.NoteManager{
                note=nil,
                on_update=function()
                    dfhack.run_command_silent('overlay trigger notes.map_notes')
                    self.subviews.notes_window:reloadFilteredNotes()
                    self:stopNoteAdd()
                end,
                on_dismiss=function()
                    self:stopNoteAdd()
                end
            }:show()
            note_manager:setNotePos(self.adding_note_pos)
            self.subviews.notes_window.note_manager = note_manager

            return true
        elseif (keys.LEAVESCREEN or keys._MOUSE_R)then
            self:stopNoteAdd()
            return true
        end
    end

    return NotesScreen.super.onInput(self, keys)
end

function NotesScreen:onRenderFrame(dc, rect)
    NotesScreen.super.onRenderFrame(self, dc, rect)

    if self.enable_selector_blink and not gui.blink_visible(500) then
        return
    end

    if self.is_adding_note then
        local curr_pos = self.adding_note_pos or dfhack.gui.getMousePos()
        if not curr_pos then
            return
        end

        local function get_overlay_pen(pos)
            if same_xy(curr_pos, pos) then
                local texpos = dfhack.textures.getTexposByHandle(
                    notes_textures.green_pin[1]
                )
                return dfhack.pen.parse{
                    ch='X',
                    fg=COLOR_BLUE,
                    tile=texpos
                }
            end
        end

        guidm.renderMapOverlay(get_overlay_pen, {
            x1=curr_pos.x,
            y1=curr_pos.y,
            x2=curr_pos.x,
            y2=curr_pos.y,
        })
    end
end

function NotesScreen:onAboutToShow()
    if not overlay.isOverlayEnabled(OVERLAY_NAME) then
        self.should_disable_overlay = true
        overlay.overlay_command({'enable', 'notes.map_notes'})
    end
end

function NotesScreen:onDismiss()
    if self.should_disable_overlay then
        overlay.overlay_command({'disable', 'notes.map_notes'})
    end

    if self.subviews.notes_window.note_manager then
        self.subviews.notes_window.note_manager:dismiss()
    end

    view = nil
end

function main()
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('notes requires a fortress map to be loaded')
    end

    view = view and view:raise() or NotesScreen{}:show()
end

if not dfhack_flags.module then
    main()
end

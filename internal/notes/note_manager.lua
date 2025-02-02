--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')
local guidm = require('gui.dwarfmode')

local waypoints = df.global.plotinfo.waypoints
local map_points = df.global.plotinfo.waypoints.points


NoteManager = defclass(NoteManager, gui.ZScreen)
NoteManager.ATTRS{
    focus_path='notes/note-manager',
    note=DEFAULT_NIL,
    on_update=DEFAULT_NIL,
    on_dismiss=DEFAULT_NIL,
}

function NoteManager:init()
    self.note_pos = nil
    local edit_mode = self.note ~= nil

    self:addviews{
        widgets.Window{
            frame={w=35,h=20},
            frame_inset={t=1},
            resizable=true,
            frame_title='Note',
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
                    -- init_cursor=self.note and #self.note.point.name + 1 or 1,
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
                            key='CUSTOM_CTRL_ENTER',
                            visible=edit_mode,
                            on_activate=function() self:saveNote() end,
                            enabled=function() return #self.subviews.name:getText() > 0 end,
                        },
                        widgets.HotkeyLabel{
                            view_id='Create',
                            frame={l=0,t=0,h=1},
                            auto_width=true,
                            label='Create',
                            key='CUSTOM_CTRL_ENTER',
                            visible=not edit_mode,
                            on_activate=function() self:createNote() end,
                            enabled=function() return #self.subviews.name:getText() > 0 end,
                        },
                        widgets.HotkeyLabel{
                            view_id='delete',
                            frame={r=0,t=0,h=1},
                            auto_width=true,
                            label='Delete',
                            key='CUSTOM_CTRL_D',
                            visible=edit_mode,
                            on_activate=function() self:deleteNote() end,
                        },
                    }
                }
            },
        },
    }
end

function NoteManager:setNotePos(note_pos)
    self.notes_pos = note_pos
end

function NoteManager:createNote()
    local cursor_pos = self.notes_pos or guidm.getCursorPos()
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
    if self.notes_pos then
        self.note.pos=self.notes_pos
    end

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
    if self.on_dismiss then
        self:on_dismiss()
    end
end

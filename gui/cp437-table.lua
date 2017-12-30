-- An in-game CP437 table

--[====[

gui/cp437-table
===============

An in-game CP437 table. Allows typing or selecting characters with the mouse.
Input is fed directly to the parent screen when "enter" is pressed, so there
should be a text field selected before running this script.

]====]

local gui = require 'gui'
local dialog = require 'gui.dialogs'
local gps = df.global.gps

ctable = defclass(ctable, gui.FramedScreen)
ctable.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = 'CP437 table',
    frame_width = 34,
    frame_height = 15,
}

function ctable:init()
    self.entry = ''
    self.cursor = 1
end

function ctable:onRenderBody(p)
    local entry_start = math.max(1, 1 + self.cursor - self.frame_width + 2)
    local entry_end = math.min(#self.entry, entry_start + self.frame_width - 3)
    p:seek(1, 1):string(self.entry:sub(entry_start, entry_end))
    if gui.blink_visible(333) then
        p:seek(self.cursor - entry_start + 1):string('_', {fg = COLOR_LIGHTCYAN})
    end
    if entry_start ~= 1 then
        p:seek(0):char(27, {fg = COLOR_LIGHTCYAN})
    end
    if entry_end ~= #self.entry then
        p:seek(self.frame_width - 1):char(26, {fg = COLOR_LIGHTCYAN})
    end
    for ch = 0, 255 do
        if dfhack.screen.charToKey(ch) then
            p:seek(1 + (ch % 32), 3 + math.floor(ch / 32)):char(ch)
        end
    end
    p:seek(1, self.frame_height - 3):string('Mouse to select')
    p:seek(1, self.frame_height - 2):key('LEAVESCREEN'):string(': Cancel, ')
     :key('SELECT'):string(': Done')
end

function ctable:insert(ch)
    if type(ch) == 'number' then ch = string.char(ch) end
    if ch == '\0' then
        if self.cursor > 1 then
            self.entry = self.entry:sub(1, self.cursor - 2) .. self.entry:sub(self.cursor)
            self.cursor = math.max(self.cursor - 1, 1)
        end
    else
        self.entry = self.entry:sub(1, self.cursor - 1) .. ch .. self.entry:sub(self.cursor)
        self.cursor = self.cursor + 1
    end
end

function ctable:simulate()
    local keys = {}
    for i = 1, #self.entry do
        local k = dfhack.screen.charToKey(string.byte(self.entry:sub(i, i)))
        if not k then
            qerror(('Invalid character at position %d: %s'):format(i, self.entry:sub(i, i)))
        end
        keys[i] = k
    end
    for i, k in pairs(keys) do
        gui.simulateInput(self._native.parent, k)
    end
    return true
end

function ctable:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
    elseif keys.SELECT then
        local ret, err = dfhack.pcall(function() self:simulate() end)
        if ret then
            self:dismiss()
        else
            dialog.showMessage('Error', err.message, COLOR_LIGHTRED)
        end
    elseif keys._MOUSE_L then
        local gx = gps.mouse_x - self.frame_rect.x1 - 2
        local gy = gps.mouse_y - self.frame_rect.y1 - 4
        if gx >= 0 and gx <= 31 and gy >= 0 and gy <= 7 then
            local ch = gx + (32 * gy)
            if ch ~= 0 and dfhack.screen.charToKey(ch) then
                self:insert(ch)
            end
        end
    elseif keys._STRING then
        for k in pairs(keys) do
            if df.interface_key[k] then
                ch = dfhack.screen.keyToChar(df.interface_key[k])
                if ch then
                    self:insert(ch)
                end
            end
        end
    elseif keys.CURSOR_LEFT then
        self.cursor = math.max(1, self.cursor - 1)
    elseif keys.CURSOR_RIGHT then
        self.cursor = math.min(self.cursor + 1, #self.entry + 1)
    end
end

scr = ctable()
scr:show()

-- Fort journal with a multi-line text editor

local gui = require 'gui'
local widgets = require 'gui.widgets'

local CLIPBOARD_MODE = {LOCAL = 1, LINE = 2}

TextEditor = defclass(TextEditor, widgets.Widget)

TextEditor.ATTRS{
    text = '',
    text_pen = COLOR_LIGHTCYAN,
    ignore_keys = {'STRING_A096'},
    select_pen = COLOR_CYAN,
    on_change = DEFAULT_NIL,
    debug = false
}

function TextEditor:init()
    self.render_start_line_y = 1
    self.scrollbar = widgets.Scrollbar{
        frame={r=0},
        on_scroll=self:callback('onScrollbar')
    }
    self.editor = TextEditorView{
        frame={l=0,r=1},
        text = self.text,
        text_pen = self.text_pen,
        ignore_keys = self.ignore_keys,
        select_pen = self.select_pen,
        debug = self.debug,

        on_change = function (val)
            self:updateLayout()
            if self.on_change then
                self.on_change(val)
            end
        end,

        on_cursor_change = function ()
            if (self.editor.cursor.y >= self.render_start_line_y + self.editor.frame_body.height) then
                self:setRenderStartLineY(self.editor.cursor.y - self.editor.frame_body.height + 1)
            elseif  (self.editor.cursor.y < self.render_start_line_y) then
                self:setRenderStartLineY(self.editor.cursor.y)
            end
        end
    }

    self:addviews{
        self.editor,
        self.scrollbar
    }
    self:setFocus(true)
end

function TextEditor:getPreferredFocusState()
    return true
end

function TextEditor:postUpdateLayout()
    self:updateScrollbar()
end

function TextEditor:onScrollbar(scroll_spec)
    local height = self.editor.frame_body.height

    local render_start_line = self.render_start_line_y
    if scroll_spec == 'down_large' then
        render_start_line = render_start_line + math.ceil(height / 2)
    elseif scroll_spec == 'up_large' then
        render_start_line = render_start_line - math.ceil(height / 2)
    elseif scroll_spec == 'down_small' then
        render_start_line = render_start_line + 1
    elseif scroll_spec == 'up_small' then
        render_start_line = render_start_line - 1
    else
        render_start_line = tonumber(scroll_spec)
    end

    self:setRenderStartLineY(math.min(
        #self.editor.lines - height + 1,
        math.max(1, render_start_line)
    ))
end

function TextEditor:updateScrollbar()
    local lines_count = #self.editor.lines

    self.scrollbar:update(
        self.render_start_line_y,
        self.frame_body.height,
        lines_count
    )

    if (self.frame_body.height >= lines_count) then
        self:setRenderStartLineY(1)
    end
end

function TextEditor:renderSubviews(dc)
    self:updateScrollbar()

    self.editor.frame_body.y1 = self.frame_body.y1-(self.render_start_line_y - 1)
    self.editor:render(dc)
    self.scrollbar:render(dc)
end

function TextEditor:setRenderStartLineY(render_start_line_y)
    self.render_start_line_y = render_start_line_y
    self.editor:setRenderStartLineY(render_start_line_y)
end


TextEditorView = defclass(TextEditorView, widgets.Widget)

TextEditorView.ATTRS{
    text = '',
    text_pen = COLOR_LIGHTCYAN,
    ignore_keys = {'STRING_A096'},
    select_pen = COLOR_CYAN,
    on_change = DEFAULT_NIL,
    on_cursor_change = DEFAULT_NIL,
    debug = false
}

function TextEditorView:init()
    self.cursor = nil
    -- lines are derivate of text, stored as variable for performance
    self.lines = {}
    self.clipboard = nil
    self.clipboard_mode = CLIPBOARD_MODE.LOCAL
    self.render_start_line_y = 1
end

function TextEditorView:setRenderStartLineY(render_start_line_y)
    self.render_start_line_y = render_start_line_y
end

function TextEditorView:getPreferredFocusState()
    return true
end

function TextEditorView:postComputeFrame()
    self:stashCursor()

    self:recomputeLines()

    self:restoreCursor()
end

function TextEditorView:stashCursor(cursor_x, cursor_y)
    local cursor = (
        cursor_x and cursor_y and {x=cursor_x, y=cursor_y}
    ) or self.cursor
    self.stash_cursor_index = cursor and self:cursorToIndex(
        cursor.x - 1,
        cursor.y
    )
    self.stash_sel_end = self.sel_end and self:cursorToIndex(
        self.sel_end.x - 1,
        self.sel_end.y
    )
end

function TextEditorView:restoreCursor()
    local cursor = self.stash_cursor_index and
        self:indexToCursor(self.stash_cursor_index)
        or {
            x = math.max(1, #self.lines[#self.lines]),
            y = math.max(1, #self.lines)
        }

    self:setCursor(cursor.x, cursor.y)
    self.sel_end = self.stash_sel_end and
        self:indexToCursor(self.stash_sel_end) or nil
end

function TextEditorView:recomputeLines()
    self.lines = self.text:wrap(
        self.frame_body.width,
        {
            return_as_table=true,
            keep_trailing_spaces=true,
            keep_original_newlines=true
        }
    )
    -- as cursor always point to "next" char we need invisible last char
    -- that can not be pass by
    self.lines[#self.lines] = self.lines[#self.lines] .. NEWLINE
end

function TextEditorView:setCursor(x, y)
    x, y = self:normalizeCursor(x, y)
    self.cursor = {x=x, y=y}

    if self.debug then
        print(string.format('cursor {%s, %s}', x, y))
    end

    self.sel_end = nil
    self.last_cursor_x = nil

    if self.on_cursor_change then
        self.on_cursor_change()
    end
end

function TextEditorView:normalizeCursor(x, y)
    local lines_count = #self.lines

    while (x < 1 and y > 1) do
        y = y - 1
        x = x + #self.lines[y]
    end

    while (x > #self.lines[y] and y < lines_count) do
        x = x - #self.lines[y]
        y = y + 1
    end

    x = math.min(x, #self.lines[y])
    y = math.min(y, lines_count)

    return math.max(1, x), math.max(1, y)
end

function TextEditorView:setSelection(from_x, from_y, to_x, to_y)
    from_x, from_y = self:normalizeCursor(from_x, from_y)
    to_x, to_y = self:normalizeCursor(to_x, to_y)

    -- text selection is always start on self.cursor and on self.sel_end
    local from = {x=from_x, y=from_y}
    local to = {x=to_x, y=to_y}

    self.cursor = from
    self.sel_end = to
end

function TextEditorView:hasSelection()
    return not not self.sel_end
end

function TextEditorView:eraseSelection()
    if (self:hasSelection()) then
        local from, to = self.cursor, self.sel_end
        if (from.y > to.y or (from.y == to.y and from.x > to.x)) then
            from, to = to, from
        end

        local from_ind = self:cursorToIndex(from.x, from.y)
        local to_ind = self:cursorToIndex(to.x, to.y)

        local new_text = self.text:sub(1, from_ind - 1) .. self.text:sub(to_ind + 1)
        self:setText(new_text, from.x, from.y)
        self.sel_end = nil
    end
end

function TextEditorView:setClipboard(text)
    dfhack.internal.setClipboardTextCp437Multiline(text)
end

function TextEditorView:copy()
    if self.sel_end then
        self.clipboard_mode =  CLIPBOARD_MODE.LOCAL

        local from = self.cursor
        local to = self.sel_end

        local from_ind = self:cursorToIndex(from.x, from.y)
        local to_ind = self:cursorToIndex(to.x, to.y)
        if from_ind > to_ind then
            from_ind, to_ind = to_ind, from_ind
        end

        self:setClipboard(self.text:sub(from_ind, to_ind))
    else
        self.clipboard_mode = CLIPBOARD_MODE.LINE

        self:setClipboard(self.lines[self.cursor.y])
    end
end

function TextEditorView:cut()
    self:copy()
    self:eraseSelection()
end

function TextEditorView:paste()
    local clipboard_lines = dfhack.internal.getClipboardTextCp437Multiline()
    local clipboard = table.concat(clipboard_lines, '\n')
    if clipboard then
        if self.clipboard_mode == CLIPBOARD_MODE.LINE and not self:hasSelection() then
            local cursor_x = self.cursor.x
            self:setCursor(1, self.cursor.y)
            self:insert(clipboard)
            self:setCursor(cursor_x, self.cursor.y)
        else
            self:eraseSelection()
            self:insert(clipboard)
        end

    end
end

function TextEditorView:setText(text, cursor_x, cursor_y)
    local changed = self.text ~= text
    self.text = text

    self:stashCursor(cursor_x, cursor_y)

    self:recomputeLines()

    self:restoreCursor()

    if changed and self.on_change then
        self.on_change(text)
    end
end

function TextEditorView:insert(text)
    self:eraseSelection()
    local index = self:cursorToIndex(
        self.cursor.x - 1,
        self.cursor.y
    )

    local new_text =
        self.text:sub(1, index) ..
        text ..
        self.text:sub(index + 1)

    self:setText(new_text, self.cursor.x + #text, self.cursor.y)
end

function TextEditorView:cursorToIndex(x, y)
    local cursor = x
    local lines = {table.unpack(self.lines, 1, y - 1)}
    for _, line in ipairs(lines) do
      cursor = cursor + #line
    end

    return cursor
end

function TextEditorView:indexToCursor(index)
    for y, line in ipairs(self.lines) do
        if index < #line then
            return {x=index + 1, y=y}
        end
        index = index - #line
    end

    return {
        x=#self.lines[#self.lines],
        y=#self.lines
    }
end

function TextEditorView:onRenderBody(dc)
    dc:pen({fg=self.text_pen, bg=COLOR_RESET, bold=true})

    local max_width = dc.width
    local new_line = self.debug and NEWLINE or ''

    local lines_to_render = math.min(
        dc.height,
        #self.lines - self.render_start_line_y + 1
    )

    dc:seek(0, self.render_start_line_y - 1)
    for i = self.render_start_line_y, self.render_start_line_y + lines_to_render - 1 do
        -- do not render new lines symbol
        local line = self.lines[i]:gsub(NEWLINE, new_line)
        dc:string(line)
        dc:newline()
    end

    local show_focus = not self:hasSelection()
        and self.parent_view.focus
        and gui.blink_visible(530)

    if (show_focus) then
        dc:seek(self.cursor.x - 1, self.cursor.y - 1)
            :char('_')
    end

    if self:hasSelection() then
        local sel_new_line = self.debug and PERIOD or ''
        local from, to = self.cursor, self.sel_end
        if (from.y > to.y or (from.y == to.y and from.x > to.x)) then
            from, to = to, from
        end

        local line = self.lines[from.y]
            :sub(from.x, to.y == from.y and to.x or nil)
            :gsub(NEWLINE, sel_new_line)
        dc:pen({ fg=self.text_pen, bg=self.select_pen })
            :seek(from.x - 1, from.y - 1)
            :string(line)

        for y = from.y + 1, to.y - 1 do
            line = self.lines[y]:gsub(NEWLINE, sel_new_line)
            dc:seek(0, y - 1)
                :string(line)
        end

        if (to.y > from.y) then
            local line = self.lines[to.y]
                :sub(1, to.x)
                :gsub(NEWLINE, sel_new_line)
            dc:seek(0, to.y - 1)
                :string(line)
        end

        dc:pen({fg=self.text_pen, bg=COLOR_RESET})
    end

    if self.debug then
        local cursor_char = self:charAtCursor()
        local debug_msg = string.format(
            'x: %s y: %s ind: %s #line: %s char: %s',
            self.cursor.x,
            self.cursor.y,
            self:cursorToIndex(self.cursor.x, self.cursor.y),
            #self.lines[self.cursor.y],
            (cursor_char == NEWLINE and 'NEWLINE') or
            (cursor_char == ' ' and 'SPACE') or
            (cursor_char == '' and 'nil') or
            cursor_char
        )
        local sel_debug_msg = self.sel_end and string.format(
            'sel_end_x: %s sel_end_y: %s',
            self.sel_end.x,
            self.sel_end.y
        ) or ''
        dc:pen({fg=COLOR_LIGHTRED, bg=COLOR_RESET})
            :seek(0, self.parent_view.frame_body.height + self.render_start_line_y - 2)
            :string(debug_msg)
            :seek(0, self.parent_view.frame_body.height + self.render_start_line_y - 3)
            :string(sel_debug_msg)
    end
end

function TextEditorView:charAtCursor()
    local cursor_ind = self:cursorToIndex(self.cursor.x, self.cursor.y)
    return self.text:sub(cursor_ind, cursor_ind)
end

function TextEditorView:getMultiLeftClick()
    local from_last_click_ms = (dfhack.getTickCount() - (self.last_click or 0))

    if (from_last_click_ms > widgets.DOUBLE_CLICK_MS) then
        self.clicks_count = 0;
    end

    return self.clicks_count
end

function TextEditorView:triggerMultiLeftClick()
    local clicks_count = self:getMultiLeftClick()

    self.clicks_count = clicks_count + 1
    if (self.clicks_count >= 4) then
        self.clicks_count = 1
    end

    self.last_click = dfhack.getTickCount()
    return self.clicks_count
end

function TextEditorView:currentSpacesRange()
    local ind = self:cursorToIndex(self.cursor.x, self.cursor.y)
    -- select "word" only from spaces
    local prev_word_end, _  = self.text
        :sub(1, ind)
        :find('[^%s]%s+$')
    local _, next_word_start = self.text:find('%s[^%s]', ind)

    return {
        x_from=prev_word_end and self.cursor.x - (ind - prev_word_end) + 1 or 1,
        x_to=next_word_start and self.cursor.x + next_word_start - ind - 1 or #self.text
    }
end

function TextEditorView:currentWordRange()
    -- select current word
    local ind = self:cursorToIndex(self.cursor.x, self.cursor.y)
    local _, prev_word_end = self.text
        :sub(1, ind-1)
        :find('.*[%s,."\']')
    local next_word_start, _  = self.text:find('[%s,."\']', ind)

    return {
        x_from=prev_word_end and self.cursor.x - (ind - prev_word_end) + 1 or 1,
        x_to=next_word_start and self.cursor.x + next_word_start - ind - 1 or #self.text
    }
end

function TextEditorView:onInput(keys)
    for _,ignore_key in ipairs(self.ignore_keys) do
        if keys[ignore_key] then
            return false
        end
    end

    if keys.SELECT then
        -- handle enter
        self:insert(NEWLINE)
        return true

    elseif keys._MOUSE_L then
        local mouse_x, mouse_y = self:getMousePos()
        if mouse_x and mouse_y then

            local clicks_count = self:triggerMultiLeftClick()
            if clicks_count >= 3 then
                self:setSelection(
                    1,
                    self.cursor.y,
                    #self.lines[self.cursor.y],
                    self.cursor.y
                )
            elseif clicks_count >= 2 then
                local cursor_char = self:charAtCursor()

                local word_range = (
                    cursor_char == ' ' or cursor_char == NEWLINE
                ) and self:currentSpacesRange() or self:currentWordRange()

                self:setSelection(
                    word_range.x_from,
                    self.cursor.y,
                    word_range.x_to,
                    self.cursor.y
                )
            elseif clicks_count == 1 then
                y = math.min(#self.lines, mouse_y + 1)
                x = math.min(#self.lines[y], mouse_x + 1)
                self:setCursor(x, y)
            end

            return true
        end

    elseif keys._MOUSE_L_DOWN then
        if (self:getMultiLeftClick() > 1) then
            return true
        end

        local mouse_x, mouse_y = self:getMousePos()
        if mouse_x and mouse_y then
            y = math.min(#self.lines, mouse_y + 1 )
            x = math.min(
                #self.lines[y],
                mouse_x + 1
            )

            if self.cursor.x ~= x or self.cursor.y ~= y then
                self:setSelection(self.cursor.x, self.cursor.y, x, y)
            else
                self.sel_end = nil
            end

            return true
        end

    elseif keys._STRING then
        if keys._STRING == 0 then
            -- handle backspace
            if (self:hasSelection()) then
                self:eraseSelection()
            else
                local x, y = self.cursor.x - 1, self.cursor.y
                self:setSelection(x, y, x, y)
                self:eraseSelection()
            end
        else
            if (self:hasSelection()) then
                self:eraseSelection()
            end
            local cv = string.char(keys._STRING)
            self:insert(cv)
        end

        return true
    elseif keys.KEYBOARD_CURSOR_LEFT then
        self:setCursor(self.cursor.x - 1, self.cursor.y)
        return true
    elseif keys.KEYBOARD_CURSOR_RIGHT then
        self:setCursor(self.cursor.x + 1, self.cursor.y)
        return true
    elseif keys.KEYBOARD_CURSOR_UP then
        local last_cursor_x = self.last_cursor_x or self.cursor.x
        local y = math.max(1, self.cursor.y - 1)
        local x = math.min(last_cursor_x, #self.lines[y])
        self:setCursor(x, y)
        self.last_cursor_x = last_cursor_x
        return true
    elseif keys.KEYBOARD_CURSOR_DOWN then
        local last_cursor_x = self.last_cursor_x or self.cursor.x
        local y = math.min(#self.lines, self.cursor.y + 1)
        local x = math.min(last_cursor_x, #self.lines[y])
        self:setCursor(x, y)
        self.last_cursor_x = last_cursor_x
        return true
    elseif keys.KEYBOARD_CURSOR_UP_FAST then
        self:setCursor(1, 1)
        return true
    elseif keys.KEYBOARD_CURSOR_DOWN_FAST then
        -- go to text end
        self:setCursor(
            #self.lines[#self.lines],
            #self.lines
        )
        return true
    elseif keys.CUSTOM_CTRL_B or keys.KEYBOARD_CURSOR_LEFT_FAST then
        -- back one word
        local ind = self:cursorToIndex(self.cursor.x, self.cursor.y)
        local _, prev_word_end = self.text
            :sub(1, ind-1)
            :find('.*%s[^%s]')

        self:setCursor(
            self.cursor.x - (ind - (prev_word_end or 1)),
            self.cursor.y
        )
        return true
    elseif keys.CUSTOM_CTRL_F or keys.KEYBOARD_CURSOR_RIGHT_FAST then
        -- forward one word
        local ind = self:cursorToIndex(self.cursor.x, self.cursor.y)
        local _, next_word_start = self.text:find('.-[^%s][%s]', ind)

        self:setCursor(
            self.cursor.x + ((next_word_start or #self.text) - ind),
            self.cursor.y
        )
        return true
    elseif keys.CUSTOM_CTRL_A then
        -- select all
        self:setSelection(1, 1, #self.lines[#self.lines], #self.lines)
        return true
    elseif keys.CUSTOM_CTRL_H then
        -- line start
        self:setCursor(1, self.cursor.y)
        return true
    elseif keys.CUSTOM_CTRL_E then
        -- line end
        self:setCursor(
            #self.lines[self.cursor.y],
            self.cursor.y
        )
        return true
    elseif keys.CUSTOM_CTRL_U then
        -- delete current line
        if (self:hasSelection()) then
            -- delete all lines that has selection
            self:setSelection(
                1,
                self.cursor.y,
                #self.lines[self.sel_end.y],
                self.sel_end.y
            )
            self:eraseSelection()
        else
            local y = self.cursor.y
            self:setSelection(1, y, #self.lines[y], y)
            self:eraseSelection()
        end
        return true
    elseif keys.CUSTOM_CTRL_K then
        -- delete from cursor to end of current line
        if (self:hasSelection()) then
            self:eraseSelection()
        else
            local y = self.cursor.y
            self:setSelection(self.cursor.x, y, #self.lines[y] - 1, y)
            self:eraseSelection()
        end
        return true
    elseif keys.CUSTOM_CTRL_D then
        -- delete char, there is no support for `Delete` key
        local old = self.text
        if (self:hasSelection()) then
            self:eraseSelection()
        else
            local del_pos = self:cursorToIndex(
                self.cursor.x,
                self.cursor.y
            )
            self:setText(old:sub(1, del_pos-1) .. old:sub(del_pos+1))
        end

        return true
    elseif keys.CUSTOM_CTRL_W then
        -- delete one word backward
        local ind = self:cursorToIndex(self.cursor.x, self.cursor.y)
        local _, prev_word_end = self.text
            :sub(1, ind-1)
            :find('.*%s[^%s]')
        local word_start = prev_word_end or 1
        local cursor = self:indexToCursor(word_start - 1)
        local new_text = self.text:sub(1, word_start - 1) .. self.text:sub(ind)
        self:setText(new_text, cursor.x, cursor.y)
        return true
    elseif keys.CUSTOM_CTRL_C then
        self:copy()
        return true
    elseif keys.CUSTOM_CTRL_X then
        self:cut()
        return true
    elseif keys.CUSTOM_CTRL_V then
        self:paste()
        return true
    end

end

JOURNAL_PERSIST_KEY = 'journal'

JournalScreen = defclass(JournalScreen, gui.ZScreen)
JournalScreen.ATTRS {
    focus_path='journal',
}

function JournalScreen:init()
    local content = self:loadContextContent()

    self:addviews{
        widgets.Window{
            frame_title='DF Journal',
            frame={w=65, h=45},
            resizable=true,
            resize_min={w=32, h=10},
            frame_inset=0,
            subviews={
                TextEditor{
                    frame={l=1, t=1, b=1, r=0},
                    text=content,
                    on_change=function(text) self:saveContextContent(text) end
                }
            }
        }
    }
end

function JournalScreen:loadContextContent()
    local site_data = dfhack.persistent.getSiteData(JOURNAL_PERSIST_KEY) or {
        text = {''}
    }
    return site_data.text ~= nil and site_data.text[1] or ''
end

function JournalScreen:saveContextContent(text)
    if dfhack.isWorldLoaded() then
        dfhack.persistent.saveSiteData(JOURNAL_PERSIST_KEY, {text={text}})
    end
end

function JournalScreen:onDismiss()
    view = nil
end

function main()
    if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
        qerror('journal requires a fortress map to be loaded')
    end

    view = view and view:raise() or JournalScreen{}:show()
end

if not dfhack_flags.module then
    main()
end

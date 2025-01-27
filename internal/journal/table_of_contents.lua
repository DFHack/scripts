--@ module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'

local df_major_version = tonumber(dfhack.getCompiledDFVersion():match('%d+'))

local INVISIBLE_FRAME = {
    frame_pen=gui.CLEAR_PEN,
    signature_pen=false,
}

TableOfContents = defclass(TableOfContents, widgets.Panel)
TableOfContents.ATTRS {
    frame_style=INVISIBLE_FRAME,
    frame_background = gui.CLEAR_PEN,
    on_submit=DEFAULT_NIL,
    text_cursor=DEFAULT_NIL
}

function TableOfContents:init()
    self:addviews{
        widgets.List{
            frame={l=0, t=0, r=0, b=3},
            view_id='table_of_contents',
            choices={},
            on_submit=self.on_submit
        },
    }

    if df_major_version < 51 then
        -- widgets below this line require DF 51
        -- TODO: remove this check once DF 51 is stable and DFHack is no longer
        -- releasing new versions for DF 50
        return
    end

    local function can_prev()
        local toc = self.subviews.table_of_contents
        return #toc:getChoices() > 0
    end
    local function can_next()
        local toc = self.subviews.table_of_contents
        local num_choices = #toc:getChoices()
        return num_choices > 0
    end

    self:addviews{
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            key='A_MOVE_N_DOWN',
            label='Prev Section',
            auto_width=true,
            on_activate=self:callback('previousSection'),
            enabled=can_prev,
        },
        widgets.Label{
            frame={l=5, b=1, w=1},
            text_pen=function() return can_prev() and COLOR_LIGHTGREEN or COLOR_GREEN end,
            text=string.char(24),
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key='A_MOVE_S_DOWN',
            label='Next Section',
            auto_width=true,
            on_activate=self:callback('nextSection'),
            enabled=can_next,
        },
        widgets.Label{
            frame={l=5, b=0, w=1},
            text_pen=function() return can_next() and COLOR_LIGHTGREEN or COLOR_GREEN end,
            text=string.char(25),
        },
    }
end

function TableOfContents:previousSection()
    local section_cursor, section = self:currentSection()

    if section == nil then
        return
    end

    if section.line_cursor == self.text_cursor then
        self.subviews.table_of_contents:setSelected(section_cursor - 1)
    end

    self.subviews.table_of_contents:submit()
end

function TableOfContents:nextSection()
    local section_cursor, section = self:currentSection()

    if section == nil then
        return
    end

    local curr_sel = self.subviews.table_of_contents:getSelected()

    local target_sel = self.text_cursor and section_cursor + 1 or curr_sel + 1

    if curr_sel ~= target_sel then
        self.subviews.table_of_contents:setSelected(target_sel)
        self.subviews.table_of_contents:submit()
    end
end

function TableOfContents:setSelectedSection(section_index)
    local curr_sel = self.subviews.table_of_contents:getSelected()

    if curr_sel ~= section_index then
        self.subviews.table_of_contents:setSelected(section_index)
    end
end

function TableOfContents:currentSection()
    local section_ind = nil

    for ind, choice in ipairs(self.subviews.table_of_contents.choices) do
        if choice.line_cursor > self.text_cursor then
            break
        end
        section_ind = ind
    end

    return section_ind, self.subviews.table_of_contents.choices[section_ind]
end

function TableOfContents:setCursor(cursor)
    self.text_cursor = cursor
end

function TableOfContents:sections()
    return self.subviews.table_of_contents.choices
end

function TableOfContents:reload(text, cursor)
    if not self.visible then
        return
    end

    local sections = {}

    local line_cursor = 1
    for line in text:gmatch("[^\n]*") do
        local header, section = line:match("^(#+)%s(.+)")
        if header ~= nil then
            table.insert(sections, {
                line_cursor=line_cursor,
                text=string.rep(" ", #header - 1) .. section,
            })
        end

        line_cursor = line_cursor + #line + 1
    end

    self.text_cursor = cursor
    self.subviews.table_of_contents:setChoices(sections)
end

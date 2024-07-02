-- The DFHack in-game command launcher
--@module=true

local dialogs = require('gui.dialogs')
local gui = require('gui')
local helpdb = require('helpdb')
local json = require('json')
local utils = require('utils')
local widgets = require('gui.widgets')

local AUTOCOMPLETE_PANEL_WIDTH = 28
local EDIT_PANEL_HEIGHT = 4

local HISTORY_SIZE = 5000
local HISTORY_ID = 'gui/launcher'
local HISTORY_FILE = 'dfhack-config/launcher.history'
local CONSOLE_HISTORY_FILE = 'dfhack-config/dfhack.history'
local CONSOLE_HISTORY_FILE_OLD = 'dfhack.history'
local TITLE = 'DFHack Launcher'

-- this size chosen since it's reasonably large and it also keeps the latency
-- within 1s when adding text to a full scrollback buffer
local SCROLLBACK_CHARS = 2^18

-- smaller amount of scrollback persisted between gui/launcher invocations
local PERSISTED_SCROLLBACK_CHARS = 2^15

config = config or json.open('dfhack-config/launcher.json')
base_freq = base_freq or json.open('hack/data/base_command_counts.json')
user_freq = user_freq or json.open('dfhack-config/command_counts.json')

-- track whether the user has enabled dev mode
dev_mode = dev_mode or false

-- track the last value of mortal mode
prev_mortal_mode = prev_mortal_mode
if prev_mortal_mode == nil then
    prev_mortal_mode = dfhack.getMortalMode()
end

local function get_default_tag_filter_base(mortal_mode)
    local ret = {
        includes={},
        excludes={},
    }
    if not dev_mode then
        ret.excludes.dev = true
        ret.excludes.unavailable = true
        if mortal_mode then
            ret.excludes.armok = true
        end
    end
    return ret
end

local function get_default_tag_filter()
    return get_default_tag_filter_base(dfhack.getMortalMode())
end

_tag_filter = _tag_filter or nil
local selecting_filters = false

local function get_tag_filter()
    _tag_filter = _tag_filter or get_default_tag_filter()
    return _tag_filter
end

local function toggle_dev_mode()
    local tag_filter = get_tag_filter()
    tag_filter.excludes.dev = dev_mode or nil
    tag_filter.excludes.unavailable = dev_mode or nil
    if not dev_mode then
        tag_filter.excludes.armok = nil
    elseif dfhack.getMortalMode() then
        tag_filter.excludes.armok = true
    end
    dev_mode = not dev_mode
end

local function matches(a, b)
    for k,v in pairs(a) do
        if b[k] ~= v then return false end
    end
    for k,v in pairs(b) do
        if a[k] ~= v then return false end
    end
    return true
end

local function is_default_filter_base(mortal_mode)
    local tag_filter = get_tag_filter()
    local default_filter = get_default_tag_filter_base(mortal_mode)
    return matches(tag_filter.includes, default_filter.includes) and
        matches(tag_filter.excludes, default_filter.excludes)
end

local function is_default_filter()
    return is_default_filter_base(dfhack.getMortalMode())
end

local function get_filter_text()
    local tag_filter = get_tag_filter()
    if not next(tag_filter.includes) and not next(tag_filter.excludes) then
        return 'Dev default'
    elseif is_default_filter() then
        return 'Default'
    end
    local ret
    for tag in pairs(tag_filter.includes) do
        if not ret then
            ret = tag
        else
            return 'Custom'
        end
    end
    return ret or 'Custom'
end

local function get_filter_pen()
    local text = get_filter_text()
    if text == 'Default' then
        return COLOR_GREEN
    elseif text == 'Dev default' then
        return COLOR_LIGHTRED
    else
        return COLOR_YELLOW
    end
end

-- trims the history down to its maximum size, if needed
local function trim_history(hist)
    local hist_size = #hist
    local overage = hist_size - HISTORY_SIZE
    if overage <= 0 then return end
    -- This is O(N) in the HISTORY_SIZE. if we need to make this more efficient,
    -- we can use a ring buffer.
    for i=overage+1,hist_size do
        hist[i-overage] = hist[i]
        if i > HISTORY_SIZE then
            hist[i] = nil
        end
    end
end

-- adds the given line to the front of the history as long as it is different from the previous command
local function add_history(hist, line, defer_trim)
    line = line:trim()
    local hist_size = #hist
    if line == hist[hist_size] then return end
    table.insert(hist, line)
    if not defer_trim then
        trim_history(hist)
    end
end

local function file_exists(fname)
    return dfhack.filesystem.mtime(fname) ~= -1
end

-- history files are written with the most recent entry on *top*, which the
-- opposite of what we want. add the file contents to our history in reverse.
-- you must manually call trim_history() after this function
local function add_history_lines(lines, hist)
    for i=#lines,1,-1 do
        add_history(hist, lines[i], true)
    end
end

-- you must manually call trim_history() after this function
local function add_history_file(fname, hist)
    if not file_exists(fname) then
        return
    end
    local lines = {}
    for line in io.lines(fname) do
        table.insert(lines, line)
    end
    add_history_lines(lines, hist)
end

local function init_history()
    local hist = {}
    -- snarf the console history into our active history. it would be better if
    -- both the launcher and the console were using the same history object so
    -- the sharing would be "live", but we can address that later.
    add_history_file(CONSOLE_HISTORY_FILE_OLD, hist)
    add_history_file(CONSOLE_HISTORY_FILE, hist)

    -- read in our own command history
    add_history_lines(dfhack.getCommandHistory(HISTORY_ID, HISTORY_FILE), hist)

    trim_history(hist)

    return hist
end

-- history is a list of previously run commands, most recent at history[#history]
history = history or init_history()

local function get_first_word(text)
    local word = text:trim():split(' +')[1]
    if word:startswith(':') then word = word:sub(2) end
    return word:lower()
end

local function get_command_count(command)
    return (base_freq.data[command] or 0) + (user_freq.data[command] or 0)
end

local function record_command(line)
    add_history(history, line)
    local firstword = get_first_word(line)
    user_freq.data[firstword] = (user_freq.data[firstword] or 0) + 1
    user_freq:write()
end

----------------------------------
-- TagFilterPanel
--

TagFilterPanel = defclass(TagFilterPanel, widgets.Panel)
TagFilterPanel.ATTRS{
    frame={t=0, r=AUTOCOMPLETE_PANEL_WIDTH, w=46, h=#helpdb.get_tags()+15},
    frame_style=gui.FRAME_INTERIOR_MEDIUM,
    frame_background=gui.CLEAR_PEN,
}

function TagFilterPanel:init()
    self:addviews{
        widgets.FilteredList{
            view_id='list',
            frame={t=0, l=0, r=0, b=11},
            on_select=self:callback('on_select'),
            on_double_click=self:callback('on_submit'),
        },
        widgets.Divider{
            frame={l=0, r=0, b=9, h=1},
            frame_style=gui.FRAME_INTERIOR,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.WrappedLabel{
            view_id='desc',
            frame={b=3, h=6},
            auto_height=false,
            text_to_wrap='', -- updated in on_select
        },
        widgets.Divider{
            frame={l=0, r=0, b=2, h=1},
            frame_style=gui.FRAME_INTERIOR,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Cycle filter',
            key='SELECT',
            auto_width=true,
            on_activate=self:callback('on_submit')
        },
        widgets.HotkeyLabel{
            frame={b=0, r=0},
            label='Cycle all',
            key='CUSTOM_CTRL_A',
            auto_width=true,
            on_activate=self:callback('toggle_all')
        },
    }
    self:refresh()
end

function TagFilterPanel:on_select(_, choice)
    local desc = self.subviews.desc
    desc.text_to_wrap = choice and choice.desc or ''
    if desc.frame_body then
        desc:updateLayout()
    end
end

function TagFilterPanel:on_submit()
    local _,choice = self.subviews.list:getSelected()
    if not choice then return end
    local tag_filter = get_tag_filter()
    local tag = choice.tag
    if tag_filter.includes[tag] then
        tag_filter.includes[tag] = nil
        tag_filter.excludes[tag] = true
    elseif tag_filter.excludes[tag] then
        tag_filter.excludes[tag] = nil
    else
        tag_filter.includes[tag] = true
        tag_filter.excludes[tag] = nil
    end
    self:refresh()
    self.parent_view:refresh_autocomplete()
end

function TagFilterPanel:toggle_all()
    local choices = self.subviews.list:getVisibleChoices()
    if not choices or #choices == 0 then return end
    local tag_filter = get_tag_filter()
    local canonical_tag = choices[1].tag
    if tag_filter.includes[canonical_tag] then
        for _,choice in ipairs(choices) do
            local tag = choice.tag
            tag_filter.includes[tag] = nil
            tag_filter.excludes[tag] = true
        end
    elseif tag_filter.excludes[canonical_tag] then
        for _,choice in ipairs(choices) do
            local tag = choice.tag
            tag_filter.includes[tag] = nil
            tag_filter.excludes[tag] = nil
        end
    else
        for _,choice in ipairs(choices) do
            local tag = choice.tag
            tag_filter.includes[tag] = true
            tag_filter.excludes[tag] = nil
        end
    end
    self:refresh()
    self.parent_view:refresh_autocomplete()
end

local function get_tag_text(tag)
    local status, pen = '', nil
    local tag_filter = get_tag_filter()
    if tag_filter.includes[tag] then
        status, pen = '(included)', COLOR_GREEN
    elseif tag_filter.excludes[tag] then
        status, pen = '(excluded)', COLOR_LIGHTRED
    end
    return {
        text={
            {text=tag, width=20, rjustify=true},
            {gap=1, text=status, pen=pen},
        },
        tag=tag,
        desc=helpdb.get_tag_data(tag).description
    }
end

function TagFilterPanel:refresh()
    local choices = {}
    for _, tag in ipairs(helpdb.get_tags()) do
        table.insert(choices, get_tag_text(tag))
    end
    local list = self.subviews.list
    local filter = list:getFilter()
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setFilter(filter, selected)
end

----------------------------------
-- AutocompletePanel
--

AutocompletePanel = defclass(AutocompletePanel, widgets.Panel)
AutocompletePanel.ATTRS{
    frame_background=gui.CLEAR_PEN,
    frame_inset={l=1},
    on_autocomplete=DEFAULT_NIL,
    tag_filter_panel=DEFAULT_NIL,
    on_double_click=DEFAULT_NIL,
    on_double_click2=DEFAULT_NIL,
}

function AutocompletePanel:init()
    local function open_filter_panel()
        selecting_filters = true
        self.tag_filter_panel.subviews.list.edit:setFocus(true)
        self.tag_filter_panel:refresh()
    end

    self:addviews{
        widgets.Label{
            frame={l=0, t=0},
            text='Click or select via'
        },
        widgets.Label{
            frame={l=1, t=1},
            text={{text='Tab', pen=COLOR_LIGHTGREEN},
                  {text='/'},
                  {text='Shift+Tab', pen=COLOR_LIGHTGREEN}}
        },
        widgets.Label{
            frame={l=0, t=3},
            text={
                {key='CUSTOM_CTRL_W', key_sep=': ', on_activate=open_filter_panel, text='Tags:'},
                {gap=1, pen=get_filter_pen, text=get_filter_text},
            },
            on_click=open_filter_panel,
        },
        widgets.HotkeyLabel{
            frame={l=0, t=4},
            key='CUSTOM_CTRL_G',
            label='Reset tag filter',
            disabled=is_default_filter,
            on_activate=function()
                _tag_filter = get_default_tag_filter()
                if selecting_filters then
                    self.tag_filter_panel:refresh()
                end
                self.parent_view:refresh_autocomplete()
            end,
        },
        widgets.Label{
            frame={l=0, t=6},
            text='Showing:',
        },
        widgets.Label{
            view_id="autocomplete_label",
            frame={l=9, t=6},
            text={{text='Matching tools', pen=COLOR_GREY}},
        },
        widgets.List{
            view_id='autocomplete_list',
            frame={l=0, r=0, t=8, b=0},
            scroll_keys={},
            on_select=self:callback('on_list_select'),
            on_double_click=self.on_double_click,
            on_double_click2=self.on_double_click2,
        },
    }
end

function AutocompletePanel:set_options(options, initially_selected)
    local list = self.subviews.autocomplete_list
    -- disable on_select while we reset the options so we don't automatically
    -- trigger the callback
    list.on_select = nil
    list:setChoices(options, 1)
    list.on_select = self:callback('on_list_select')
    list.cursor_pen = initially_selected and COLOR_LIGHTCYAN or COLOR_CYAN
    self.first_advance = not initially_selected
end

function AutocompletePanel:advance(delta)
    local list = self.subviews.autocomplete_list
    if self.first_advance then
        if list.cursor_pen == COLOR_CYAN and delta > 0 then
            delta = 0
        end
        self.first_advance = false
    end
    list.cursor_pen = COLOR_LIGHTCYAN -- enable highlight
    list:moveCursor(delta, true)
end

function AutocompletePanel:on_list_select(idx, option)
    -- enable highlight
    self.subviews.autocomplete_list.cursor_pen = COLOR_LIGHTCYAN
    self.first_advance = false
    if self.on_autocomplete then self.on_autocomplete(idx, option) end
end

----------------------------------
-- EditPanel
--
EditPanel = defclass(EditPanel, widgets.Panel)
EditPanel.ATTRS{
    on_change=DEFAULT_NIL,
    on_submit=DEFAULT_NIL,
    on_submit2=DEFAULT_NIL,
    on_toggle_minimal=DEFAULT_NIL,
    prefix_visible=DEFAULT_NIL,
}

function EditPanel:init()
    self.stack = {}
    self.seen_search = {}
    self:reset_history_idx()

    self:addviews{
        widgets.Label{
            view_id='prefix',
            frame={l=0, t=0, r=0},
            frame_background=gui.CLEAR_PEN,
            text='[DFHack]#',
            auto_width=false,
            visible=self.prefix_visible},
        widgets.EditField{
            view_id='editfield',
            frame={l=1, t=1, r=1},
            -- ignore the backtick from the hotkey. otherwise if it is still
            -- held down as the launcher appears, it will be read and be added
            -- to the commandline
            ignore_keys={'STRING_A096'},
            on_char=function(ch, text)
                -- if game was not initially paused, then allow double-space to toggle pause
                if ch == ' ' and not self.parent_view.parent_view.saved_pause_state then
                    return text:sub(1, self.subviews.editfield.cursor - 1):match('%S$')
                end
                return true
            end,
            on_change=self.on_change,
            on_submit=self.on_submit,
            on_submit2=self.on_submit2},
        widgets.HotkeyLabel{
            frame={l=1, t=3, w=10},
            key='SELECT',
            label='run',
            disabled=self.prefix_visible,
            on_activate=function()
                if dfhack.internal.getModifiers().shift then
                    self.on_submit2(self.subviews.editfield.text)
                else
                    self.on_submit(self.subviews.editfield.text)
                end
                end},
        widgets.HotkeyLabel{
            frame={r=0, t=0, w=10},
            key='CUSTOM_ALT_M',
            label=string.char(31)..string.char(30),
            disabled=function() return selecting_filters end,
            on_activate=self.on_toggle_minimal},
        widgets.EditField{
            view_id='search',
            frame={l=13, b=0, r=1},
            frame_background=gui.CLEAR_PEN,
            key='CUSTOM_ALT_S',
            label_text='history search: ',
            disabled=function() return selecting_filters end,
            on_change=function(text) self:on_search_text(text) end,
            on_focus=function()
                local text = self.subviews.editfield.text
                if #text:trim() > 0 then
                    self.subviews.search:setText(text)
                    self:on_search_text(text)
                end end,
            on_unfocus=function()
                self.subviews.search:setText('')
                self.subviews.editfield:setFocus(true)
                self.subviews.search.visible = not self.prefix_visible()
                gui.Screen.request_full_screen_refresh = true
            end,
            on_submit=function()
                self.on_submit(self.subviews.editfield.text) end,
            on_submit2=function()
                self.on_submit2(self.subviews.editfield.text) end},
    }
end

function EditPanel:reset_history_idx()
    self.history_idx = #history + 1
end

function EditPanel:set_text(text, inhibit_change_callback)
    local edit = self.subviews.editfield
    if inhibit_change_callback then
        edit.on_change = nil
    end
    edit:setText(text)
    edit.on_change = self.on_change
    self:reset_history_idx()
end

function EditPanel:move_history(delta)
    local history_idx = self.history_idx + delta
    if history_idx < 1 or history_idx > #history + 1 or delta == 0 then
        return
    end
    local editfield = self.subviews.editfield
    if self.history_idx == #history + 1 then
        -- we're moving off the initial buffer. save it so we can get it back.
        self.saved_buffer = editfield.text
    end
    self.history_idx = history_idx
    local text
    if history_idx == #history + 1 then
        -- we're moving onto the initial buffer. restore it.
        text = self.saved_buffer
    else
        text = history[history_idx]
    end
    editfield:setText(text)
    self.on_change(text)
end

function EditPanel:on_search_text(search_str, next_match)
    if not next_match then self.seen_search = {} end
    if not search_str or #search_str == 0 then return end
    local start_idx = math.min(self.history_idx - (next_match and 1 or 0),
                               #history)
    for history_idx = start_idx, 1, -1 do
        local line = history[history_idx]
        if line:find(search_str, 1, true) then
            self:move_history(history_idx - self.history_idx)
            if not self.seen_search[line] then
                self.seen_search[line] = true
                return
            end
        end
    end
    -- no matches. restart at the saved input buffer for the next search.
    self.seen_search = {}
    self:move_history(#history + 1 - self.history_idx)
end

function EditPanel:onInput(keys)
    if self.prefix_visible() then
        local search = self.subviews.search
        search.visible = keys.CUSTOM_ALT_S or search.focus
    end

    if EditPanel.super.onInput(self, keys) then return true end

    if keys.STANDARDSCROLL_UP then
        self:move_history(-1)
        return true
    elseif keys.STANDARDSCROLL_DOWN then
        self:move_history(1)
        return true
    elseif keys.CUSTOM_ALT_S then
        -- search to the next match with the current search string
        -- only reaches here if the search field is already active
        self:on_search_text(self.subviews.search.text, true)
        return true
    end
end

function EditPanel:preUpdateLayout()
    local search = self.subviews.search
    local minimized = self.prefix_visible()
    if minimized then
        self.frame_background = nil
        search.frame.l = 0
        search.frame.r = 11
    else
        self.frame_background = gui.CLEAR_PEN
        search.frame.l = 13
        search.frame.r = 1
    end
    search.visible = not minimized or search.focus
end

----------------------------------
-- HelpPanel
--

HelpPanel = defclass(HelpPanel, widgets.Panel)
HelpPanel.ATTRS{
    frame_background=gui.CLEAR_PEN,
    frame_inset={t=0, l=1, r=1, b=0},
}

persisted_scrollback = persisted_scrollback or ''

-- this text is intentionally unwrapped so the in-UI wrapping can do the job
local DEFAULT_HELP_TEXT = [[Welcome to DFHack!

Type a command or click on it in the autocomplete panel to see its help text here. Hit Enter or click on the "run" button to run the command as typed. You can also run a command without parameters by double clicking on it in the autocomplete list.

You can filter the autocomplete list by clicking on the "Tags" button. Tap backtick (`) or hit ESC to close this dialog. This dialog also closes automatically if you run a command that shows a new GUI screen.

Not sure what to do? You can browse and configure DFHack most important tools in "gui/control-panel". Please also run "quickstart-guide" to get oriented with DFHack and its capabilities.

To see more detailed help for this command launcher (including info on keyboard and mouse controls), type "gui/launcher".

You're running DFHack ]] .. dfhack.getDFHackVersion() ..
            (dfhack.isRelease() and '' or (' (git: %s)'):format(dfhack.getGitCommit(true)))

function HelpPanel:init()
    self.cur_entry = ''

    self:addviews{
        widgets.TabBar{
            frame={t=0, l=0},
            labels={
                'Help',
                'Output',
            },
            on_select=function(idx) self.subviews.pages:setSelected(idx) end,
            get_cur_page=function() return self.subviews.pages:getSelected() end,
        },
        widgets.HotkeyLabel{
            frame={t=0, r=1},
            label='Clear output',
            text_pen=COLOR_YELLOW,
            auto_width=true,
            on_activate=function() self:add_output('', true) end,
            visible=function() return self.subviews.pages:getSelected() == 2 end,
            enabled=function() return #self.subviews.output_label.text_to_wrap > 0 end,
        },
        widgets.HotkeyLabel{
            view_id='copy',
            frame={t=1, r=1},
            label='Copy output to clipboard',
            text_pen=COLOR_YELLOW,
            auto_width=true,
            on_activate=function()
                dfhack.internal.setClipboardTextCp437Multiline(self.subviews.output_label.text_to_wrap)
                self.subviews.copy.visible = false
                self.subviews.copy_flash.visible = true
                local end_ms = dfhack.getTickCount() + 5000
                local function label_reset()
                    if dfhack.getTickCount() < end_ms then
                        dfhack.timeout(10, 'frames', label_reset)
                    else
                        self.subviews.copy_flash.visible = false
                        self.subviews.copy.visible = true
                    end
                end
                label_reset()
            end,
            visible=function() return self.subviews.pages:getSelected() == 2 end,
            enabled=function() return #self.subviews.output_label.text_to_wrap > 0 end,
        },
        widgets.Label{
            view_id='copy_flash',
            frame={t=1, r=12},
            text='Copied',
            auto_width=true,
            text_pen=COLOR_GREEN,
            visible=false,
        },
        widgets.Pages{
            view_id='pages',
            frame={t=3, l=0, b=0, r=0},
            subviews={
                widgets.WrappedLabel{
                    view_id='help_label',
                    auto_height=false,
                    scroll_keys={
                        KEYBOARD_CURSOR_UP_FAST=-1,  -- Shift-Up
                        KEYBOARD_CURSOR_DOWN_FAST=1, -- Shift-Down
                        STANDARDSCROLL_PAGEUP='-halfpage',
                        STANDARDSCROLL_PAGEDOWN='+halfpage',
                    },
                    text_to_wrap=DEFAULT_HELP_TEXT},
                widgets.WrappedLabel{
                    view_id='output_label',
                    auto_height=false,
                    scroll_keys={
                        KEYBOARD_CURSOR_UP_FAST=-1,  -- Shift-Up
                        KEYBOARD_CURSOR_DOWN_FAST=1, -- Shift-Down
                        STANDARDSCROLL_PAGEUP='-halfpage',
                        STANDARDSCROLL_PAGEDOWN='+halfpage',
                    },
                    text_to_wrap=persisted_scrollback},
            },
        },
    }
end

local function HelpPanel_update_label(label, text)
    label.text_to_wrap = text
    label:postComputeFrame() -- wrap
    label:updateLayout() -- update the scroll arrows after rewrapping text
end

function HelpPanel:add_output(output, clear)
    self.subviews.pages:setSelected('output_label')
    local label = self.subviews.output_label
    local text_height = label:getTextHeight()
    label:scroll('end')
    local line_num = label.start_line_num
    local text = output
    if not clear and label.text_to_wrap ~= '' then
        text = label.text_to_wrap .. NEWLINE .. output
    end
    local text_len = #text
    if text_len > SCROLLBACK_CHARS then
        text = text:sub(-SCROLLBACK_CHARS)
        local text_diff = text_len - #text
        HelpPanel_update_label(label, label.text_to_wrap:sub(text_diff))
        text_height = label:getTextHeight()
        label:scroll('end')
        line_num = label.start_line_num
    end
    persisted_scrollback = text:sub(-PERSISTED_SCROLLBACK_CHARS)
    HelpPanel_update_label(label, text)
    if line_num == 1 then
        label:scroll(text_height - 1)
    else
        label:scroll('home')
        label:scroll(line_num - 1)
        label:scroll('+page')
    end
end

function HelpPanel:set_entry(entry_name, show_help)
    if show_help then
        self.subviews.pages:setSelected('help_label')
    end
    local label = self.subviews.help_label
    if #entry_name == 0 then
        HelpPanel_update_label(label, DEFAULT_HELP_TEXT)
        self.cur_entry = ''
        return
    end
    if not helpdb.is_entry(entry_name) or entry_name == self.cur_entry then
        return
    end
    local wrapped_help = helpdb.get_entry_long_help(entry_name,
                                                    self.frame_body.width - 5)
    HelpPanel_update_label(label, wrapped_help)
    self.cur_entry = entry_name
end

function HelpPanel:postComputeFrame()
    if #self.cur_entry == 0 then return end
    local wrapped_help = helpdb.get_entry_long_help(self.cur_entry,
                                                    self.frame_body.width - 5)
    HelpPanel_update_label(self.subviews.help_label, wrapped_help)
end

function HelpPanel:postUpdateLayout()
    if not self.sentinel then
        self.sentinel = true
        self.subviews.output_label:scroll('end')
    end
end

----------------------------------
-- MainPanel
--

MainPanel = defclass(MainPanel, widgets.Panel)
MainPanel.ATTRS{
    frame_title=TITLE,
    frame_inset=0,
    draggable=true,
    resizable=true,
    resize_min={w=AUTOCOMPLETE_PANEL_WIDTH+48, h=EDIT_PANEL_HEIGHT+20},
    get_minimal=DEFAULT_NIL,
    update_autocomplete=DEFAULT_NIL,
    on_edit_input=DEFAULT_NIL,
}

function MainPanel:postUpdateLayout()
    if self.get_minimal() then return end
    config:write(self.frame)
end

function MainPanel:onInput(keys)
    if MainPanel.super.onInput(self, keys) then
        return true
    end

    if selecting_filters and (keys.LEAVESCREEN or keys._MOUSE_R) then
        selecting_filters = false
        self.subviews.search.on_unfocus()
    elseif keys.CUSTOM_CTRL_D then
        toggle_dev_mode()
        self:refresh_autocomplete()
    elseif keys.CHANGETAB then
        self.subviews.autocomplete:advance(1)
    elseif keys.SEC_CHANGETAB then
        self.subviews.autocomplete:advance(-1)
    else
        return false
    end
    return true
end

function MainPanel:refresh_autocomplete()
    self.update_autocomplete(get_first_word(self.subviews.editfield.text))
end

----------------------------------
-- LauncherUI
--

LauncherUI = defclass(LauncherUI, gui.ZScreen)
LauncherUI.ATTRS{
    focus_path='launcher',
    defocusable=false,
    minimal=false,
}

local function get_frame_r()
    -- scan for anchor elements and do our best to avoid them
    local gps = df.global.gps
    local dimy = gps.dimy
    local maxx = gps.dimx - 1
    for x = 0,maxx do
        local index = x * dimy
        if (gps.top_in_use and gps.screentexpos_top_anchored[index] ~= 0) or
                gps.screentexpos_anchored[index] ~= 0 then
            return maxx - x + 1
        end
    end
    return 0
end

function LauncherUI:init()
    self.firstword = ""

    local main_panel = MainPanel{
        view_id='main',
        get_minimal=function() return self.minimal end,
        update_autocomplete=self:callback('update_autocomplete'),
        on_edit_input=self:callback('on_edit_input'),
    }

    local function not_minimized() return not self.minimal end

    local frame_r = get_frame_r()

    local update_frames = function()
        local new_frame = {}
        if self.minimal then
            new_frame.l = 0
            new_frame.r = frame_r
            new_frame.t = 0
            new_frame.h = 2
        else
            new_frame = config.data
            if not next(new_frame) then
                new_frame = {w=110, h=36}
            else
                for k,v in pairs(new_frame) do
                    if v < 0 then
                        new_frame[k] = 0
                    end
                end
                local w, h = dfhack.screen.getWindowSize()
                local min = MainPanel.ATTRS.resize_min
                if new_frame.t and h - new_frame.t - (new_frame.b or 0) < min.h then
                    new_frame.t = h - min.h
                    new_frame.b = 0
                end
                if new_frame.b and h - new_frame.b - (new_frame.t or 0) < min.h then
                    new_frame.b = h - min.h
                    new_frame.t = 0
                end
                if new_frame.l and w - new_frame.l - (new_frame.r or 0) < min.w then
                    new_frame.l = w - min.w
                    new_frame.r = 0
                end
                if new_frame.r and w - new_frame.r - (new_frame.l or 0) < min.w then
                    new_frame.r = w - min.w
                    new_frame.l = 0
                end
            end
        end
        main_panel.frame = new_frame
        main_panel.frame_style = not self.minimal and gui.WINDOW_FRAME or nil

        local edit_frame = self.subviews.edit.frame
        edit_frame.r = self.minimal and
                0 or AUTOCOMPLETE_PANEL_WIDTH+1
        edit_frame.h = self.minimal and 2 or EDIT_PANEL_HEIGHT

        local editfield_frame = self.subviews.editfield.frame
        editfield_frame.t = self.minimal and 0 or 1
        editfield_frame.l = self.minimal and 10 or 1
        editfield_frame.r = self.minimal and 11 or 1
    end

    local tag_filter_panel = TagFilterPanel{
        visible=function() return not_minimized() and selecting_filters end,
    }

    main_panel:addviews{
        AutocompletePanel{
            view_id='autocomplete',
            frame={t=0, r=0, w=AUTOCOMPLETE_PANEL_WIDTH},
            on_autocomplete=self:callback('on_autocomplete'),
            tag_filter_panel=tag_filter_panel,
            on_double_click=function(_,c) self:run_command(true, c.text) end,
            on_double_click2=function(_,c) self:run_command(false, c.text) end,
            visible=not_minimized,
        },
        EditPanel{
            view_id='edit',
            frame={t=0, l=0},
            on_change=function(text) self:on_edit_input(text, false) end,
            on_submit=self:callback('run_command', true),
            on_submit2=self:callback('run_command', false),
            on_toggle_minimal=function()
                self.minimal = not self.minimal
                update_frames()
                self:updateLayout()
            end,
            prefix_visible=function() return self.minimal end,
        },
        HelpPanel{
            view_id='help',
            frame={t=EDIT_PANEL_HEIGHT+1, l=0, r=AUTOCOMPLETE_PANEL_WIDTH},
            visible=not_minimized,
        },
        widgets.Divider{
            frame={t=0, b=0, r=AUTOCOMPLETE_PANEL_WIDTH, w=1},
            frame_style_t=false,
            frame_style_b=false,
            visible=not_minimized,
        },
        widgets.Divider{
            frame={t=EDIT_PANEL_HEIGHT, l=0, r=AUTOCOMPLETE_PANEL_WIDTH, h=1},
            interior=true,
            frame_style_l=false,
            visible=not_minimized,
        },
        tag_filter_panel,
    }
    self:addviews{main_panel}

    update_frames()
    self:on_edit_input('')
end

function LauncherUI:update_help(text, firstword, show_help)
    firstword = firstword or get_first_word(text)
    if firstword == self.firstword then
        return
    end
    self.firstword = firstword
    self.subviews.help:set_entry(firstword, show_help)
end

local function extract_entry(entries, firstword)
    for i,v in ipairs(entries) do
        if v == firstword then
            table.remove(entries, i)
            return true
        end
    end
end

local function sort_by_freq(entries)
    -- remember starting position of each entry so we can sort stably
    local indices = utils.invert(entries)
    local stable_sort_by_frequency = function(a, b)
        local acount, bcount = get_command_count(a), get_command_count(b)
        if acount > bcount then return true
        elseif acount == bcount then
            return indices[a] < indices[b]
        end
        return false
    end
    table.sort(entries, stable_sort_by_frequency)
end

-- adds the n most closely affiliated peer entries for the given entry that
-- aren't already in the entries list. affiliation is determined by how many
-- tags the entries share.
local function add_top_related_entries(entries, entry, n)
    local dev_ok = dev_mode or helpdb.get_entry_tags(entry).dev
    local tags = helpdb.get_entry_tags(entry)
    local affinities, buckets = {}, {}
    local skip_armok = dfhack.getMortalMode()
    for tag in pairs(tags) do
        for _,peer in ipairs(helpdb.get_tag_data(tag)) do
            if not skip_armok or not helpdb.get_entry_tags(peer).armok then
                affinities[peer] = (affinities[peer] or 0) + 1
            end
        end
        buckets[#buckets + 1] = {}
    end
    for peer,affinity in pairs(affinities) do
        if helpdb.get_entry_types(peer).command then
            table.insert(buckets[affinity], peer)
        end
    end
    local entry_set = utils.invert(entries)
    for i=#buckets,1,-1 do
        sort_by_freq(buckets[i])
        for _,peer in ipairs(buckets[i]) do
            if not entry_set[peer] then
                entry_set[peer] = true
                if dev_ok or not helpdb.get_entry_tags(peer).dev then
                    table.insert(entries, peer)
                    n = n - 1
                    if n < 1 then return end
                end
            end
        end
    end
end

function LauncherUI:update_autocomplete(firstword)
    local includes = {str=firstword, types='command'}
    local excludes = {}
    if helpdb.is_tag(firstword) then
        includes = {tag=firstword, types='command'}
        for tag in pairs(get_default_tag_filter().excludes) do
            table.insert(ensure_key(excludes, 'tag'), tag)
        end
    else
        includes = {includes}
        local tag_filter = get_tag_filter()
        for tag in pairs(tag_filter.includes) do
            table.insert(includes, {tag=tag})
        end
        for tag in pairs(tag_filter.excludes) do
            table.insert(ensure_key(excludes, 'tag'), tag)
        end
    end
    local entries = helpdb.search_entries(includes, excludes)
    -- if firstword is in the list, extract it so we can add it to the top later
    -- even if it's not in the list, add it back anyway if it's a valid db entry
    -- (e.g. if it's a dev script that we masked out) to show that it's a valid
    -- command
    local found = extract_entry(entries, firstword) or helpdb.is_entry(firstword)
    sort_by_freq(entries)
    if helpdb.is_tag(firstword) then
        self.subviews.autocomplete_label:setText{{text='Tagged tools', pen=COLOR_LIGHTMAGENTA}}
    elseif found then
        table.insert(entries, 1, firstword)
        self.subviews.autocomplete_label:setText{{text='Similar tools', pen=COLOR_BROWN}}
        add_top_related_entries(entries, firstword, 20)
    else
        self.subviews.autocomplete_label:setText{{text='Matching tools', pen=COLOR_GREY}}
    end

    self.subviews.autocomplete:set_options(entries, found)
end

function LauncherUI:on_edit_input(text, show_help)
    local firstword = get_first_word(text)
    self:update_help(text, firstword, show_help)
    self:update_autocomplete(firstword)
end

function LauncherUI:on_autocomplete(_, option)
    if option then
        self.subviews.edit:set_text(option.text..' ', true)
        self:update_help(option.text)
    end
end

function LauncherUI:run_command(reappear, command)
    command = command:trim()
    if #command == 0 then return end
    dfhack.addCommandToHistory(HISTORY_ID, HISTORY_FILE, command)
    record_command(command)
    local output, clear
    if command == 'clear' or command == 'cls' or
        command:startswith('clear ') or command:startswith('cls ')
    then
        output = ''
        clear = true
    else
        -- remember the previous parent screen address so we can detect changes
        local _,prev_parent_addr = self._native.parent:sizeof()
        -- propagate saved unpaused status to the new ZScreen
        local saved_pause_state = df.global.pause_state
        if not self.saved_pause_state then
            df.global.pause_state = false
        end
        -- remove our viewscreen from the stack while we run the command. this
        -- allows hotkey guards and tools that interact with the top viewscreen
        -- without checking whether it is active to work reliably.
        output = dfhack.screen.hideGuard(self, dfhack.run_command_silent,
                                            command)
        df.global.pause_state = saved_pause_state
        if #output > 0 then
            print('Output from command run from gui/launcher:')
            print('> ' .. command)
            print()
            print(output)
        end
        output = output:gsub('\t', ' ')
        -- if we displayed a different screen, don't come back up, even if reappear
        -- is true, so the user can interact with the new screen.
        local _,parent_addr = self._native.parent:sizeof()
        if self.minimal or parent_addr ~= prev_parent_addr then
            reappear = false
            if self.minimal and #output > 0 then
                dialogs.showMessage(TITLE, output)
            end
        end
        if #output == 0 then
            output = 'Command finished successfully'
        end
        if not output:endswith('\n') then
            output = output .. '\n'
        end
        output = ('> %s\n\n%s'):format(command, output)
    end

    self.subviews.edit:set_text('')
    self.subviews.help:add_output(output, clear)

    if not reappear then
        self:dismiss()
    end
end

function LauncherUI:render(dc)
    local mortal_mode = dfhack.getMortalMode()
    if mortal_mode ~= prev_mortal_mode then
        prev_mortal_mode = mortal_mode
        if is_default_filter_base(not mortal_mode) then
            _tag_filter = get_default_tag_filter_base(mortal_mode)
            self.subviews.main:refresh_autocomplete()
        end
    end
    LauncherUI.super.render(self, dc)
end

function LauncherUI:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

local args = {...}
local minimal = false
if args[1] == '--minimal' or args[1] == '-m' then
    table.remove(args, 1)
    minimal = true
end

if not view then
    view = LauncherUI{minimal=minimal}:show()
elseif minimal ~= view.minimal then
    view.subviews.edit.on_toggle_minimal()
elseif not view:hasFocus() then
    view:raise()
elseif #args == 0 then
    -- running the launcher while it is open (e.g. from hitting the launcher
    -- hotkey a second time) should close the dialog
    view:dismiss()
    return
end

if #args > 0 then
    local initial_command = table.concat(args, ' ')
    view.subviews.edit:set_text(initial_command)
    view:on_edit_input(initial_command, true)
end

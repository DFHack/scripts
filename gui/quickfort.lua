-- A GUI front-end for quickfort
--@ module = true
--[====[
gui/quickfort
=============
Graphical interface for the `quickfort` script. Once you load a blueprint, you
will see a blinking "shadow" over the tiles that will be modified. You can use
the cursor to reposition the blueprint or the hotkeys to rotate and repeat the
blueprint up or down z-levels. Once you are satisfied, hit :kbd:`ENTER` to apply
the blueprint to the map.

Usage::

    gui/quickfort [<search terms>]

If the (optional) search terms match a single blueprint (e.g. if the search
terms are copied from the ``quickfort list`` output like
``gui/quickfort library/dreamfort.csv -n /industry1``), then that blueprint is
pre-loaded into the UI and a preview for that blueprint appears. Otherwise, a
dialog is shown where you can select a blueprint to load.

You can also type search terms in the dialog and the list of matching blueprints
will be filtered as you type. You can search for directory names, file names,
blueprint labels, modes, or comments. Note that, depending on the active list
filters, the id numbers in the list may not be contiguous.

To rotate or flip the blueprint around, enable transformations with :kbd:`t` and
use :kbd:`Ctrl` with the arrow keys to add a transformation step:

:kbd:`Ctrl`:kbd:`Left`:  Rotate counterclockwise (ccw)
:kbd:`Ctrl`:kbd:`Right`: Rotate clockwise (cw)
:kbd:`Ctrl`:kbd:`Up`:    Flip vertically (vflip)
:kbd:`Ctrl`:kbd:`Down`:  Flip horizontally (hflip)

If a shorter transformation sequence can be used to get the blueprint into the
configuration you want, it will automatically be used. For example, if you
rotate clockwise three times, gui/quickfort will shorten the sequence to a
single counterclockwise rotation for you.

Any settings you set in the UI, such as search terms for the blueprint list or
transformation options, are saved for the next time you run the script.

Examples:

============================== =================================================
Command                        Effect
============================== =================================================
gui/quickfort                  opens the quickfort interface with saved settings
gui/quickfort dreamfort        opens with a custom blueprint filter
gui/quickfort myblueprint.csv  opens with the specified blueprint pre-loaded
============================== =================================================
]====]

local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_map = reqscript('internal/quickfort/map')
local quickfort_parse = reqscript('internal/quickfort/parse')
local quickfort_preview = reqscript('internal/quickfort/preview')
local quickfort_transform = reqscript('internal/quickfort/transform')

local argparse = require('argparse')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

-- wide enough to take up most of the screen, allowing long lines to be
-- displayed without rampant wrapping, but not so large that it blots out the
-- entire DF map screen.
local dialog_width = 73

-- persist these between invocations
show_library = show_library == nil and true or show_library
show_hidden = show_hidden or false
filter_text = filter_text or ''
selected_id = selected_id or 1
repeat_dir = repeat_dir or false
repetitions = repetitions or 1
transform = transform or false
transformations = transformations or {}

-- displays blueprint details, such as the full modeline and comment, that
-- otherwise might be truncated for length in the blueprint selection list
local BlueprintDetails = defclass(BlueprintDetails, dialogs.MessageBox)
BlueprintDetails.ATTRS{
    focus_path='quickfort/dialog/details',
    frame_title='Details',
    frame_width=28, -- minimum width required for the bottom frame text
}

-- adds hint about left arrow being a valid "exit" key for this dialog
function BlueprintDetails:onRenderFrame(dc, rect)
    BlueprintDetails.super.onRenderFrame(self, dc, rect)
    dc:seek(rect.x1+2, rect.y2):string('Left arrow', dc.cur_key_pen):
            string(': Back', COLOR_GREY)
end

function BlueprintDetails:onInput(keys)
    if keys.STANDARDSCROLL_LEFT or keys.SELECT or keys.LEAVESCREEN then
        self:dismiss()
    end
end

-- blueprint selection dialog, shown when the script starts or when a user wants
-- to load a new blueprint into the ui
local BlueprintDialog = defclass(BlueprintDialog, dialogs.ListBox)
BlueprintDialog.ATTRS{
    focus_path='quickfort/dialog',
    frame_title='Load quickfort blueprint',
    with_filter=true,
    frame_width=dialog_width,
    row_height=2,
    frame_inset={t=0,l=1,r=1,b=1},
    list_frame_inset={t=1},
}

function BlueprintDialog:init()
    self:addviews{
        widgets.Label{frame={t=0, l=1}, text='Filters:', text_pen=COLOR_GREY},
        widgets.ToggleHotkeyLabel{frame={t=0, l=12}, label='Library',
                key='CUSTOM_ALT_L', initial_option=show_library,
                text_pen=COLOR_GREY,
                on_change=self:callback('update_setting', 'show_library')},
        widgets.ToggleHotkeyLabel{frame={t=0, l=34}, label='Hidden',
                key='CUSTOM_ALT_H', initial_option=show_hidden,
                text_pen=COLOR_GREY,
                on_change=self:callback('update_setting', 'show_hidden')}
    }
end

-- always keep our list big enough to display 10 items so we don't jarringly
-- resize when the filter is being edited and it suddenly matches no blueprints
function BlueprintDialog:getWantedFrameSize()
    local mw, mh = BlueprintDialog.super.getWantedFrameSize(self)
    return mw, math.max(mh, 24)
end

function BlueprintDialog:onRenderFrame(dc, rect)
    BlueprintDialog.super.onRenderFrame(self, dc, rect)
    dc:seek(rect.x1+2, rect.y2):string('Right arrow', dc.cur_key_pen):
            string(': Show details', COLOR_GREY)
end

function BlueprintDialog:update_setting(setting, value)
    _ENV[setting] = value
    self:refresh()
end

-- ensures each newline-delimited sequence within text is no longer than
-- width characters long. also ensures that no more than max_lines lines are
-- returned in the truncated string.
local more_marker = '...->'
local function truncate(text, width, max_lines)
    local truncated_text = {}
    for line in text:gmatch('[^'..NEWLINE..']*') do
        if #line > width then
            line = line:sub(1, width-#more_marker) .. more_marker
        end
        table.insert(truncated_text, line)
        if #truncated_text >= max_lines then break end
    end
    return table.concat(truncated_text, NEWLINE)
end

-- extracts the blueprint list id from a dialog list entry
local function get_id(text)
    local _, _, id = text:find('^(%d+)')
    return tonumber(id)
end

local function save_selection(list)
    local _, obj = list:getSelected()
    if obj then
        selected_id = get_id(obj.text)
    end
end

-- reinstate the saved selection in the list, or a nearby list id if that exact
-- item is no longer in the list
local function restore_selection(list)
    local best_idx = 1
    for idx,v in ipairs(list:getVisibleChoices()) do
        local cur_id = get_id(v.text)
        if selected_id >= cur_id then best_idx = idx end
        if selected_id <= cur_id then break end
    end
    list.list:setSelected(best_idx)
    save_selection(list)
end

-- generates a new list of unfiltered choices by calling quickfort's list
-- implementation, then applies the saved (or given) filter text
function BlueprintDialog:refresh()
    local choices = {}
    for _,v in ipairs(
            quickfort_list.do_list_internal(show_library, show_hidden)) do
        local start_comment = ''
        if v.start_comment then
            start_comment = string.format(' cursor start: %s', v.start_comment)
        end
        local sheet_spec = ''
        if v.section_name then
            sheet_spec = string.format(
                    ' -n %s',
                    quickfort_parse.quote_if_has_spaces(v.section_name))
        end
        local main = ('%d) %s%s (%s)')
                     :format(v.id, quickfort_parse.quote_if_has_spaces(v.path),
                     sheet_spec, v.mode)
        local text = ('%s%s'):format(main, start_comment)
        if v.comment then
            text = text .. ('\n    %s'):format(v.comment)
        end
        local full_text = main
        if #start_comment > 0 then
            full_text = full_text .. '\n\n' .. start_comment
        end
        if v.comment then
            full_text = full_text .. '\n\n comment: ' .. v.comment
        end
        local truncated_text =
                truncate(text, self.frame_body.width, self.row_height)

        -- search for the extra syntax shown in the list items in case someone
        -- is typing exactly what they see
        table.insert(choices,
                     {text=truncated_text,
                      full_text=full_text,
                      search_key=v.search_key .. main})
    end
    self.subviews.list:setChoices(choices)
    self:updateLayout() -- allows the dialog to resize width to fit the content
    self.subviews.list:setFilter(filter_text)
    restore_selection(self.subviews.list)
end

function BlueprintDialog:onInput(keys)
    local _, obj = self.subviews.list:getSelected()
    if keys.STANDARDSCROLL_RIGHT and obj then
        local details = BlueprintDetails{
                text=obj.full_text:wrap(self.frame_body.width)}
        details:show()
        -- for testing
        self._details = details
    elseif keys.LEAVESCREEN then
        self:dismiss()
        if self.on_cancel then
            self.on_cancel()
        end
    else
        self:inputToSubviews(keys)
        local prev_filter_text = filter_text
        -- save the filter if it was updated so we always have the most recent
        -- text for the next invocation of the dialog
        filter_text = self.subviews.list:getFilter()
        if prev_filter_text ~= filter_text then
            -- if the filter text has changed, restore the last selected item
            restore_selection(self.subviews.list)
        else
            -- otherwise, save the new selected item
            save_selection(self.subviews.list)
        end
        -- allow the list box to grow and shrink with the contents
        self:updateLayout()
    end
end

-- the main map screen UI. the information panel overlays the sidebar menu and
-- the loaded blueprint generates a flashing shadow over tiles that will be
-- modified by the blueprint when it is applied.
QuickfortUI = defclass(QuickfortUI, guidm.MenuOverlay)
QuickfortUI.ATTRS {
    frame_inset=1,
    focus_path='quickfort',
    sidebar_mode=df.ui_sidebar_mode.LookAround,
    filter='',
}
function QuickfortUI:init()
    local main_panel = widgets.Panel{autoarrange_subviews=true,
                                     autoarrange_gap=1}
    main_panel:addviews{
        widgets.Label{text='Quickfort'},
        widgets.ResizingPanel{subviews={
            widgets.WrappedLabel{view_id='summary',
                frame={t=0, l=0},
                text_pen=COLOR_GREY,
                text_to_wrap=self:callback('get_summary_label')},
            widgets.HotkeyLabel{view_id='commit_label',
                frame={t=1, l=13}, key='SELECT', key_sep=' ', label='to apply.',
                text_pen=COLOR_GREY, on_activate=self:callback('commit')}
        }},
        widgets.HotkeyLabel{key='CUSTOM_L', label='Load new blueprint',
            on_activate=self:callback('show_dialog')},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.Label{text='Current blueprint:'},
            widgets.WrappedLabel{
                text_pen=COLOR_GREY,
                text_to_wrap=self:callback('get_blueprint_name')}
            }},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.Label{
                text={'Blueprint tiles: ',
                    {text=self:callback('get_total_tiles')}}},
            widgets.Label{
                text={'Invalid tiles:   ',
                    {text=self:callback('get_invalid_tiles')}},
                text_dpen=COLOR_RED,
                disabled=self:callback('has_invalid_tiles')}}},
        widgets.HotkeyLabel{key='CUSTOM_SHIFT_L',
            label=self:callback('get_lock_cursor_label'),
            on_activate=self:callback('toggle_lock_cursor')},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.CycleHotkeyLabel{key='CUSTOM_R',
                view_id='repeat_cycle',
                label='Repeat',
                options={{label='No', value=false},
                         {label='Down z-levels', value='>'},
                         {label='Up z-levels', value='<'}},
                initial_option=repeat_dir,
                on_change=self:callback('on_repeat_change')},
            widgets.ResizingPanel{view_id='repeat_times_panel',
                    visible=repeat_dir,
                    subviews={
                widgets.HotkeyLabel{key='SECONDSCROLL_UP',
                    frame={l=2}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', -1)},
                widgets.HotkeyLabel{key='SECONDSCROLL_DOWN',
                    frame={l=3}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', 1)},
                widgets.HotkeyLabel{key='SECONDSCROLL_PAGEUP',
                    frame={l=4}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', -10)},
                widgets.HotkeyLabel{key='SECONDSCROLL_PAGEDOWN',
                    frame={l=5}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', 10)},
                widgets.EditField{key='CUSTOM_SHIFT_R',
                    view_id='repeat_times',
                    frame={l=7, h=1},
                    label_text='x ',
                    text=tostring(repetitions),
                    on_char=function(ch) return ch:match('%d') end,
                    on_submit=self:callback('on_repeat_times_submit')}}}}},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.ToggleHotkeyLabel{key='CUSTOM_T',
                view_id='transform',
                label='Transform',
                initial_option=transform,
                on_change=self:callback('on_transform_change')},
            widgets.ResizingPanel{view_id='transform_panel',
                    visible=transform,
                    subviews={
                widgets.Label{text={{text='Ctrl+'..string.char(24)..
                                          string.char(25)..string.char(26)..
                                          string.char(27),
                                     pen=COLOR_LIGHTGREEN},
                                    {text=':'}},
                    frame={l=2}},
                widgets.WrappedLabel{
                    frame={l=14},
                    text_to_wrap=function()
                            return #transformations == 0 and 'No transform'
                                or table.concat(transformations, ', ') end}}}}},
        widgets.HotkeyLabel{key='CUSTOM_O', label='Generate manager orders',
            on_activate=self:callback('do_command', 'orders')},
        widgets.HotkeyLabel{key='CUSTOM_SHIFT_O',
            label='Preview manager orders',
            on_activate=self:callback('do_command', 'orders', true)},
        widgets.HotkeyLabel{key='CUSTOM_SHIFT_U', label='Undo blueprint',
            on_activate=self:callback('do_command', 'undo')},
        widgets.HotkeyLabel{key='LEAVESCREEN', label='Back',
            on_activate=self:callback('dismiss')}
    }
    self:addviews{main_panel}
end

function QuickfortUI:get_summary_label()
    local commit_label_frame = self.subviews.commit_label.frame
    if self.mode == 'config' then
        commit_label_frame.l = 13
        return 'Blueprint configures game, not map. Hit'
    elseif self.mode == 'notes' then
        commit_label_frame.l = 4
        return 'Blueprint shows help text. Hit'
    end
    commit_label_frame.l = 13
    return 'Reposition with the cursor keys and hit'
end

function QuickfortUI:get_blueprint_name()
    if self.blueprint_name then
        local text = {self.blueprint_name}
        if self.section_name then
            table.insert(text, '  '..self.section_name)
        end
        return text
    end
    return 'No blueprint loaded'
end

function QuickfortUI:get_lock_cursor_label()
    return (self.cursor_locked and 'Unl' or 'L') .. 'ock blueprint position'
end

function QuickfortUI:toggle_lock_cursor()
    if self.cursor_locked then
        quickfort_map.move_cursor(self.saved_cursor)
    end
    self.cursor_locked = not self.cursor_locked
end

function QuickfortUI:get_total_tiles()
    if not self.saved_preview then return '0' end
    return tostring(self.saved_preview.total_tiles)
end

function QuickfortUI:has_invalid_tiles()
    return self:get_invalid_tiles() ~= '0'
end

function QuickfortUI:get_invalid_tiles()
    if not self.saved_preview then return '0' end
    return tostring(self.saved_preview.invalid_tiles)
end

function QuickfortUI:on_repeat_change(val)
    repeat_dir = val
    self.subviews.repeat_times_panel.visible = val
    self:updateLayout()
    self.dirty = true
end

function QuickfortUI:on_adjust_repetitions(amt)
    repetitions = math.max(1, repetitions + amt)
    self.subviews.repeat_times.text = tostring(repetitions)
    self.dirty = true
end

function QuickfortUI:on_repeat_times_submit(val)
    repetitions = tonumber(val)
    if not repetitions or repetitions < 1 then
        repetitions = 1
    end
    self.subviews.repeat_times.text = tostring(repetitions)
    self.dirty = true
end

function QuickfortUI:on_transform_change(val)
    transform = val
    self.subviews.transform_panel.visible = val
    self:updateLayout()
    self.dirty = true
end

local origin, test_point = {x=0, y=0}, {x=1, y=-2}
local minimal_sequence = {
    ['x=1, y=-2'] = {},
    ['x=2, y=-1'] = {'cw', 'flipv'},
    ['x=2, y=1'] = {'cw'},
    ['x=1, y=2'] = {'flipv'},
    ['x=-1, y=2'] = {'cw', 'cw'},
    ['x=-2, y=1'] = {'ccw', 'flipv'},
    ['x=-2, y=-1'] = {'ccw'},
    ['x=-1, y=-2'] = {'fliph'}
}

-- reduces the list of transformations to a minimal sequence
local function reduce_transform(elements)
    local pos = test_point
    for _,elem in ipairs(elements) do
        pos = quickfort_transform.make_transform_fn_from_name(elem)(pos, origin)
    end
    local ret = quickfort_transform.resolve_vector(pos, minimal_sequence)
    if #ret == #elements then
        -- if we're not making the sequence any shorter, prefer the existing set
        return elements
    end
    return copyall(ret)
end

function QuickfortUI:on_transform(val)
    table.insert(transformations, val)
    transformations = reduce_transform(transformations)
    self:updateLayout()
    self.dirty = true
end

function QuickfortUI:dialog_cb(text)
    local id = get_id(text)
    local name, sec_name, mode = quickfort_list.get_blueprint_by_number(id)
    self.blueprint_name, self.section_name, self.mode = name, sec_name, mode
    self:updateLayout()
    if self.mode == 'notes' then
        self:do_command('run', false, self:callback('show_dialog'))
    end
    self.dirty = true
end

function QuickfortUI:dialog_cancel_cb()
    if not self.blueprint_name then
        -- ESC was pressed on the first showing of the dialog when no blueprint
        -- has ever been loaded. the user doesn't want to be here. exit script.
        self:dismiss()
    end
end

function QuickfortUI:show_dialog(initial)
    -- if this is the first showing, absorb the filter from the commandline (if
    -- one was specified)
    if initial and #self.filter > 0 then
        filter_text = self.filter
    end

    local file_dialog = BlueprintDialog{
        on_select=function(idx, obj) self:dialog_cb(obj.text) end,
        on_cancel=self:callback('dialog_cancel_cb')
    }
    file_dialog:refresh()

    -- autoload if this is the first showing of the dialog and a filter was
    -- specified on the commandline and the filter matches exactly one choice
    if initial and #self.filter > 0 then
        local choices = file_dialog.subviews.list:getVisibleChoices()
        if #choices == 1 then
            local selection = choices[1].text
            file_dialog:dismiss()
            self:dialog_cb(selection)
            return
        end
    end

    file_dialog:show()

    -- for testing
    self._dialog = file_dialog
end

function QuickfortUI:onShow()
    QuickfortUI.super.onShow(self)
    self.saved_cursor = guidm.getCursorPos()
    self:show_dialog(true)
end

function QuickfortUI:run_quickfort_command(command, dry_run, preview)
    local ctx = quickfort_command.init_ctx{
        command=command,
        blueprint_name=self.blueprint_name,
        cursor=self.saved_cursor,
        aliases=quickfort_list.get_aliases(self.blueprint_name),
        quiet=true,
        dry_run=dry_run,
        preview=preview,
    }

    local section_name = self.section_name
    local modifiers = quickfort_parse.get_modifiers_defaults()

    if repeat_dir and repetitions > 1 then
        local repeat_str = repeat_dir .. tostring(repetitions)
        quickfort_parse.parse_repeat_params(repeat_str, modifiers)
    end

    if transform and #transformations > 0 then
        local transform_str = table.concat(transformations, ',')
        quickfort_parse.parse_transform_params(transform_str, modifiers)
    end

    quickfort_command.do_command_section(ctx, section_name, modifiers)

    return ctx
end

function QuickfortUI:refresh_preview()
    local ctx = self:run_quickfort_command('run', true, true)
    self.saved_preview = ctx.preview
end

function QuickfortUI:onRenderBody()
    if not self.blueprint_name or not gui.blink_visible(500) then return end

    -- if the (non-locked) cursor has moved since last preview processing or any
    -- settings have changed, regenerate the preview
    local cursor = guidm.getCursorPos()
    if self.dirty or not same_xyz(self.saved_cursor, cursor) then
        if not self.cursor_locked then
            self.saved_cursor = cursor
        end
        self:refresh_preview()
        self.dirty = false
    end

    local tiles = self.saved_preview.tiles
    if not tiles[cursor.z] then return end

    local function get_overlay_char(pos)
        local preview_tile = quickfort_preview.get_preview_tile(tiles, pos)
        if preview_tile == nil then return nil end
        return 'X', preview_tile and COLOR_GREEN or COLOR_RED
    end

    self:renderMapOverlay(get_overlay_char, self.saved_preview.bounds[cursor.z])
end

function QuickfortUI:onInput(keys)
    if self:inputToSubviews(keys) then
        return true
    end

    if transform then
        if keys.A_MOVE_E_DOWN then self:on_transform('cw')
        elseif keys.A_MOVE_W_DOWN then self:on_transform('ccw')
        elseif keys.A_MOVE_N_DOWN then self:on_transform('flipv')
        elseif keys.A_MOVE_S_DOWN then self:on_transform('fliph')
        end
    end

    return self:propagateMoveKeys(keys)
end

function QuickfortUI:commit()
    if self.mode ~= 'notes' then
        self:dismiss()
    end
    self:do_command('run', false)
end

function QuickfortUI:do_command(command, dry_run, post_fn)
    print(string.format('executing via gui/quickfort: quickfort %s',
                        quickfort_parse.format_command(
                            command, self.blueprint_name, self.section_name)))
    local ctx = self:run_quickfort_command(command, dry_run, false)
    quickfort_command.finish_command(ctx, self.section_name)
    if command == 'run' then
        if #ctx.messages > 0 then
            self._dialog = dialogs.showMessage(
                    'Attention',
                    table.concat(ctx.messages, '\n\n'):wrap(dialog_width),
                    nil,
                    post_fn)
        elseif post_fn then
            post_fn()
        end
    elseif command == 'orders' then
        local count = 0
        for _,_ in pairs(ctx.order_specs or {}) do count = count + 1 end
        local messages = {string.format(
            '%d order(s) %senqueued for %s.', count,
            dry_run and 'would be ' or '',
            quickfort_parse.format_command(nil, self.blueprint_name,
                                           self.section_name))}
        if count > 0 then
            table.insert(messages, '')
        end
        for _,stat in pairs(ctx.stats) do
            if stat.is_order then
                table.insert(messages, ('  %s: %d'):format(stat.label,
                                                           stat.value))
            end
        end
        self._dialog = dialogs.showMessage(
               ('Orders %senqueued'):format(dry_run and 'that would be ' or ''),
               table.concat(messages,'\n'):wrap(dialog_width))
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

-- treat all arguments as blueprint list dialog filter text
QuickfortUI{filter=table.concat({...}, ' ')}:show()

-- A GUI front-end for quickfort
--@ module = true

-- reload changed transitive dependencies
reqscript('quickfort').refresh_scripts()

local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_parse = reqscript('internal/quickfort/parse')
local quickfort_preview = reqscript('internal/quickfort/preview')
local quickfort_transform = reqscript('internal/quickfort/transform')

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
marker_expanded = marker_expanded or false
markers = markers or {blueprint=false, warm=false, damp=false}
repeat_dir = repeat_dir or false
repetitions = repetitions or 1
transform = transform or false
transformations = transformations or {}

--
-- BlueprintDialog
--

-- blueprint selection dialog, shown when the script starts or when a user wants
-- to load a new blueprint into the ui
BlueprintDialog = defclass(SelectDialog, gui.ZScreenModal)
BlueprintDialog.ATTRS{
    focus_path='quickfort/dialog',
    on_select=DEFAULT_NIL,
    on_cancel=DEFAULT_NIL,
}

function BlueprintDialog:init()
    local options={
        {label='Show', value=true, pen=COLOR_GREEN},
        {label='Hide', value=false}
    }

    self:addviews{
        widgets.Window{
            frame={w=80, h=35},
            frame_title='Load quickfort blueprint',
            resizable=true,
            subviews={
                widgets.Label{
                    frame={t=0, l=1},
                    text='Filters:',
                    text_pen=COLOR_GREY,
                },
                widgets.ToggleHotkeyLabel{
                    frame={t=0, l=12, w=20},
                    key='CUSTOM_ALT_L',
                    label='Library:',
                    options=options,
                    initial_option=show_library,
                    text_pen=COLOR_GREY,
                    on_change=self:callback('update_setting', 'show_library')
                },
                widgets.ToggleHotkeyLabel{
                    frame={t=0, l=35, w=19},
                    key='CUSTOM_ALT_H',
                    label='Hidden:',
                    options=options,
                    initial_option=show_hidden,
                    text_pen=COLOR_GREY,
                    on_change=self:callback('update_setting', 'show_hidden')
                },
                widgets.FilteredList{
                    view_id='list',
                    frame={t=2, b=9},
                    row_height=2,
                    on_select=function()
                        local desc = self.subviews.desc
                        if desc.frame_body then desc:updateLayout() end
                    end,
                    on_double_click=self:callback('commit'),
                    on_submit2=self:callback('delete_blueprint'),
                    on_double_click2=self:callback('delete_blueprint'),
                },
                widgets.Panel{
                    frame={b=3, h=5},
                    frame_style=gui.FRAME_INTERIOR,
                    subviews={
                        widgets.WrappedLabel{
                            frame={l=0, h=3},
                            view_id='desc',
                            auto_height=false,
                            text_to_wrap=function()
                                local list = self.subviews.list
                                local _, choice = list:getSelected()
                                return choice and choice.desc or ''
                            end,
                        },
                    },
                },
                widgets.Label{
                    frame={b=1, l=0},
                    text='Double click or',
                },
                widgets.HotkeyLabel{
                    frame={b=1, l=16},
                    key='SELECT',
                    label='Load selected blueprint',
                    on_activate=self:callback('commit'),
                    enabled=function()
                        local list = self.subviews.list
                        local _, choice = list:getSelected()
                        return choice
                    end,
                },
                widgets.Label{
                    frame={b=0, l=0},
                    text='Shift click or',
                },
                widgets.HotkeyLabel{
                    frame={b=0, l=15},
                    key='SELECT_ALL', -- TODO: change to SEC_SELECT once 51.01 is stable
                    label='Delete selected blueprint',
                    on_activate=self:callback('delete_blueprint'),
                    enabled=function()
                        local list = self.subviews.list
                        local _, choice = list:getSelected()
                        return choice and not choice.library
                    end,
                },
            },
        },
    }
end

function BlueprintDialog:commit()
    local list = self.subviews.list
    local _, choice = list:getSelected()
    if choice then
        self:dismiss()
        self.on_select(choice.id)
    end
end

function BlueprintDialog:update_setting(setting, value)
    _ENV[setting] = value
    self:refresh()
end

local function save_selection(list)
    local _, choice = list:getSelected()
    if choice then
        selected_id = choice.id
    end
end

-- reinstate the saved selection in the list, or a nearby list id if that exact
-- item is no longer in the list
local function restore_selection(list)
    local best_idx = 1
    for idx,v in ipairs(list:getVisibleChoices()) do
        local cur_id = v.id
        if selected_id >= cur_id then best_idx = idx end
        if selected_id <= cur_id then break end
    end
    list.list:setSelected(best_idx)
    save_selection(list)
end

-- generates a new list of unfiltered choices by calling quickfort's list
-- implementation, then applies the saved (or given) filter text
-- returns false on list error
function BlueprintDialog:refresh()
    local choices = {}
    local ok, results = pcall(quickfort_list.do_list_internal, show_library,
                              show_hidden)
    if not ok then
        self._dialog = dialogs.showMessage('Cannot list blueprints',
                tostring(results):wrap(dialog_width), COLOR_RED)
        self:dismiss()
        return false
    end
    for _,v in ipairs(results) do
        local sheet_spec = ''
        if v.section_name then
            sheet_spec = (' -n %s'):format(quickfort_parse.quote_if_has_spaces(v.section_name))
        end
        local main = ('%d) %s%s (%s)'):format(
            v.id, quickfort_parse.quote_if_has_spaces(v.path), sheet_spec, v.mode)

        local comment = ''
        if v.comment then
            comment = ('%s'):format(v.comment)
        end
        local start_comment = ''
        if v.start_comment then
            start_comment = ('%scursor on: %s'):format(#comment > 0 and '; ' or '', v.start_comment)
        end
        local extra = #comment == 0 and #start_comment == 0 and 'No description' or ''
        local desc = ('%s%s%s'):format(comment, start_comment, extra)

        -- search for the extra syntax shown in the list items in case someone
        -- is typing exactly what they see
        table.insert(choices, {
            text=main,
            desc=desc,
            id=v.id,
            library=v.library,
            name=v.path,
            search_key=v.search_key .. main,
        })
    end
    local list = self.subviews.list
    list:setFilter('')
    list:setChoices(choices, list:getSelected())
    list:setFilter(filter_text)
    restore_selection(list)
    return true
end

function BlueprintDialog:delete_blueprint(idx, choice)
    local list = self.subviews.list
    if choice then
        list.list:setSelected(idx)
        save_selection(list)
    else
        _, choice = list:getSelected()
    end
    if not choice or choice.library then return end

    local function do_delete(pause_confirmations)
        dfhack.run_script('quickfort', 'delete', choice.name)
        self:refresh()
        self.pause_confirmations = self.pause_confirmations or pause_confirmations
    end

    if self.pause_confirmations then
        do_delete()
    else
        dialogs.showYesNoPrompt('Delete blueprint',
            'Are you sure you want to delete this blueprint?\n'..choice.name,
            COLOR_YELLOW, do_delete, nil, curry(do_delete, true))
    end
end

function BlueprintDialog:onInput(keys)
    if keys.LEAVESCREEN or keys._MOUSE_R then
        self.on_cancel()
        self:dismiss()
        return true
    elseif BlueprintDialog.super.onInput(self, keys) then
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
        return true
    end
end

--
-- Quickfort
--

-- the main map screen UI. the information panel appears in a window and
-- the loaded blueprint generates a flashing shadow over tiles that will be
-- modified by the blueprint when it is applied.
Quickfort = defclass(Quickfort, widgets.Window)
Quickfort.ATTRS {
    frame_title='Quickfort',
    frame={w=34, h=42, r=2, t=18},
    resizable=true,
    resize_min={h=32},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    filter='',
}
function Quickfort:init()
    self.saved_cursor = dfhack.gui.getMousePos() or {x=0, y=0, z=0}

    self:addviews{
        widgets.ResizingPanel{subviews={
            widgets.Label{
                frame={t=0, l=0, w=30},
                text_pen=COLOR_GREY,
                text={
                    {text=self:callback('get_summary_label')},
                    NEWLINE,
                    'Click or hit ',
                    {key='SELECT', key_sep=' ',
                     on_activate=self:callback('commit')},
                    'to apply.',
                },
            },
        }},
        widgets.HotkeyLabel{key='CUSTOM_L', label='Load new blueprint',
            on_activate=self:callback('show_dialog')},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.Label{text='Current blueprint:'},
            widgets.WrappedLabel{
                text_pen=COLOR_CYAN,
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
            active=function() return self.blueprint_name end,
            enabled=function() return self.blueprint_name end,
            on_activate=self:callback('toggle_lock_cursor')},
        widgets.Divider{frame={h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false},
        widgets.CycleHotkeyLabel{key='CUSTOM_SHIFT_P',
            key_back='CUSTOM_P',
            view_id='priority',
            label='Baseline dig priority:',
            options={1, 2, 3, 4, 5, 6, 7},
            initial_option=4,
            active=function() return self.blueprint_name and self.has_dig end,
            enabled=function() return self.blueprint_name and self.has_dig end},
        widgets.ResizingPanel{subviews={
            widgets.ToggleHotkeyLabel{key='CUSTOM_M',
                frame={t=0, h=1},
                view_id='marker',
                label='Add marker:',
                initial_option=marker_expanded,
                active=function() return self.blueprint_name and self.has_dig end,
                enabled=function() return self.blueprint_name and self.has_dig end,
                on_change=function(val)
                    marker_expanded = val
                    self:updateLayout()
                end,
            },
            widgets.Panel{
                frame={t=0, h=4},
                visible=function() return self.subviews.marker:getOptionValue() end,
                subviews={
                    widgets.ToggleHotkeyLabel{key='CUSTOM_CTRL_B',
                        frame={t=1, l=0},
                        view_id='marker_blueprint',
                        label='Blueprint:',
                        initial_option=markers.blueprint,
                        on_change=function(val) markers.blueprint = val end,
                    },
                    widgets.ToggleHotkeyLabel{key='CUSTOM_CTRL_D',
                        frame={t=2, l=0},
                        view_id='marker_damp',
                        label='Damp dig:',
                        initial_option=markers.damp,
                        on_change=function(val) markers.damp = val end,
                    },
                    widgets.ToggleHotkeyLabel{key='CUSTOM_CTRL_W',
                        frame={t=3, l=0},
                        view_id='marker_warm',
                        label='Warm dig:',
                        initial_option=markers.warm,
                        on_change=function(val) markers.warm = val end,
                    },
                },
            },
        }},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.CycleHotkeyLabel{key='CUSTOM_R',
                view_id='repeat_cycle',
                label='Repeat:',
                active=function() return self.blueprint_name end,
                enabled=function() return self.blueprint_name end,
                options={{label='No', value=false},
                         {label='Down z-levels', value='>'},
                         {label='Up z-levels', value='<'}},
                initial_option=repeat_dir,
                on_change=self:callback('on_repeat_change')},
            widgets.ResizingPanel{view_id='repeat_times_panel',
                    visible=function() return repeat_dir and self.blueprint_name end,
                    subviews={
                widgets.HotkeyLabel{key='STRING_A045',
                    frame={t=1, l=2, w=1}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', -1)},
                widgets.HotkeyLabel{key='STRING_A043',
                    frame={t=1, l=3, w=1}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', 1)},
                widgets.HotkeyLabel{key='STRING_A047',
                    frame={t=1, l=4, w=1}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', -10)},
                widgets.HotkeyLabel{key='STRING_A042',
                    frame={t=1, l=5, w=1}, key_sep='',
                    on_activate=self:callback('on_adjust_repetitions', 10)},
                widgets.EditField{key='CUSTOM_SHIFT_R',
                    view_id='repeat_times',
                    frame={t=1, l=7, h=1},
                    label_text='x ',
                    text=tostring(repetitions),
                    on_char=function(ch) return ch:match('%d') end,
                    on_submit=self:callback('on_repeat_times_submit')}}}}},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.ToggleHotkeyLabel{key='CUSTOM_T',
                view_id='transform',
                label='Transform:',
                active=function() return self.blueprint_name end,
                enabled=function() return self.blueprint_name end,
                initial_option=transform,
                on_change=self:callback('on_transform_change')},
            widgets.ResizingPanel{view_id='transform_panel',
                    visible=function() return transform and self.blueprint_name end,
                    subviews={
                widgets.HotkeyLabel{key='STRING_A040',
                    frame={t=1, l=2, w=1}, key_sep='',
                    on_activate=self:callback('on_transform', 'ccw')},
                widgets.HotkeyLabel{key='STRING_A041',
                    frame={t=1, l=3, w=1}, key_sep='',
                    on_activate=self:callback('on_transform', 'cw')},
                widgets.HotkeyLabel{key='STRING_A095',
                    frame={t=1, l=4, w=1}, key_sep='',
                    on_activate=self:callback('on_transform', 'flipv')},
                widgets.HotkeyLabel{key='STRING_A061',
                    frame={t=1, l=5, w=1}, key_sep=':',
                    on_activate=self:callback('on_transform', 'fliph')},
                widgets.WrappedLabel{
                    frame={t=1, l=8},
                    text_to_wrap=function()
                            return #transformations == 0 and 'No transform'
                                or table.concat(transformations, ', ') end}}}}},
        widgets.Divider{frame={h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false},
        widgets.HotkeyLabel{key='CUSTOM_O', label='Generate manager orders',
            active=function() return self.blueprint_name end,
            enabled=function() return self.blueprint_name end,
            on_activate=self:callback('do_command', 'orders')},
        widgets.HotkeyLabel{key='CUSTOM_SHIFT_O',
            label='Preview manager orders',
            active=function() return self.blueprint_name end,
            enabled=function() return self.blueprint_name end,
            on_activate=self:callback('do_command', 'orders', true)},
        widgets.HotkeyLabel{key='CUSTOM_SHIFT_U', label='Undo blueprint',
            active=function() return self.blueprint_name end,
            enabled=function() return self.blueprint_name end,
            on_activate=self:callback('do_command', 'undo')},
        widgets.WrappedLabel{
            text_to_wrap='Build mode blueprints will use DFHack building planner material filter settings.',
        },
    }
end

function Quickfort:get_summary_label()
    if self.mode == 'notes' then
        return 'Blueprint shows help text.'
    end
    return 'Reposition with the mouse.'
end

function Quickfort:get_blueprint_name()
    if self.blueprint_name then
        local text = {self.blueprint_name}
        if self.section_name then
            table.insert(text, '  '..self.section_name)
        end
        return text
    end
    return 'No blueprint loaded'
end

function Quickfort:get_lock_cursor_label()
    if self.cursor_locked and self.saved_cursor.z ~= df.global.window_z then
        return 'Zoom to locked position'
    end
    return (self.cursor_locked and 'Unl' or 'L') .. 'ock blueprint position'
end

function Quickfort:toggle_lock_cursor()
    if self.cursor_locked then
        local was_on_different_zlevel = self.saved_cursor.z ~= df.global.window_z
        dfhack.gui.revealInDwarfmodeMap(self.saved_cursor)
        if was_on_different_zlevel then
            return
        end
    end
    self.cursor_locked = not self.cursor_locked
end

function Quickfort:get_total_tiles()
    if not self.saved_preview then return '0' end
    return tostring(self.saved_preview.total_tiles)
end

function Quickfort:has_invalid_tiles()
    return self:get_invalid_tiles() ~= '0'
end

function Quickfort:get_invalid_tiles()
    if not self.saved_preview then return '0' end
    return tostring(self.saved_preview.invalid_tiles)
end

function Quickfort:on_repeat_change(val)
    repeat_dir = val
    self:updateLayout()
    self.dirty = true
end

function Quickfort:on_adjust_repetitions(amt)
    repetitions = math.max(1, repetitions + amt)
    self.subviews.repeat_times:setText(tostring(repetitions))
    self.dirty = true
end

function Quickfort:on_repeat_times_submit(val)
    repetitions = tonumber(val)
    if not repetitions or repetitions < 1 then
        repetitions = 1
    end
    self.subviews.repeat_times:setText(tostring(repetitions))
    self.dirty = true
end

function Quickfort:on_transform_change(val)
    transform = val
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

function Quickfort:on_transform(val)
    table.insert(transformations, val)
    transformations = reduce_transform(transformations)
    self:updateLayout()
    self.dirty = true
end

function Quickfort:dialog_cb(id)
    local name, sec_name, mode = quickfort_list.get_blueprint_by_number(id)
    self.blueprint_name, self.section_name, self.mode = name, sec_name, mode
    self:updateLayout()
    if self.mode == 'notes' then
        self:do_command('run', false, self:callback('show_dialog'))
    end
    self.dirty = true
end

function Quickfort:dialog_cancel_cb()
    if not self.blueprint_name then
        -- ESC was pressed on the first showing of the dialog when no blueprint
        -- has ever been loaded. the user doesn't want to be here. exit script.
        self.parent_view:dismiss()
    end
end

function Quickfort:show_dialog(initial)
    -- if this is the first showing, absorb the filter from the commandline (if
    -- one was specified)
    if initial and #self.filter > 0 then
        filter_text = self.filter
    end

    local file_dialog = BlueprintDialog{
        on_select=self:callback('dialog_cb'),
        on_cancel=self:callback('dialog_cancel_cb')
    }

    if file_dialog:refresh() then
        -- autoload if this is the first showing of the dialog and a filter was
        -- specified on the commandline and the filter matches exactly one
        -- choice
        if initial and #self.filter > 0 then
            local choices = file_dialog.subviews.list:getVisibleChoices()
            if #choices == 1 then
                local selection = choices[1].id
                file_dialog:dismiss()
                self:dialog_cb(selection)
                return
            end
        end
        file_dialog:show()
    end

    -- for testing
    self._dialog = file_dialog
end

function Quickfort:run_quickfort_command(command, marker, priority, dry_run, preview)
    local ctx = quickfort_command.init_ctx{
        command=command,
        blueprint_name=self.blueprint_name,
        cursor=self.saved_cursor,
        aliases=quickfort_list.get_aliases(self.blueprint_name),
        quiet=true,
        marker=marker,
        priority=priority,
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

function Quickfort:refresh_preview()
    local ctx = self:run_quickfort_command('run', false, 4, true, true)
    self.saved_preview = ctx.preview
    self.has_dig = ctx.stats.dig_designated
end

local to_pen = dfhack.pen.parse
local CURSOR_PEN = to_pen{ch='o', fg=COLOR_BLUE,
                         tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 22)}
local GOOD_PEN = to_pen{ch='x', fg=COLOR_GREEN,
                        tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}
local BAD_PEN = to_pen{ch='X', fg=COLOR_RED,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 3, 0)}

function Quickfort:onRenderFrame(dc, rect)
    Quickfort.super.onRenderFrame(self, dc, rect)

    if not self.blueprint_name then return end
    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    -- if the (non-locked) cursor has moved since last preview processing or any
    -- settings have changed, regenerate the preview
    local cursor = dfhack.gui.getMousePos() or self.saved_cursor
    if self.dirty or not same_xyz(self.saved_cursor, cursor) then
        if not self.cursor_locked then
            self.saved_cursor = cursor
        end
        self:refresh_preview()
        self.dirty = false
    end

    local tiles = self.saved_preview.tiles
    if not tiles[cursor.z] then return end

    local function get_overlay_pen(pos)
        if same_xyz(pos, self.saved_cursor) then return CURSOR_PEN end
        local preview_tile = quickfort_preview.get_preview_tile(tiles, pos)
        if preview_tile == nil then return end
        return preview_tile and GOOD_PEN or BAD_PEN
    end

    guidm.renderMapOverlay(get_overlay_pen, self.saved_preview.bounds[cursor.z])
end

function Quickfort:onInput(keys)
    if Quickfort.super.onInput(self, keys) then
        return true
    end

    if keys._MOUSE_L and not self:getMouseFramePos() then
        local pos = dfhack.gui.getMousePos()
        if pos then
            self:commit()
            return true
        end
    end
end

function Quickfort:commit()
    -- don't dismiss the window in case the player wants to lay down more copies
    self:do_command('run', false)
end

function Quickfort:do_command(command, dry_run, post_fn)
    self.dirty = true
    print(('executing via gui/quickfort: quickfort %s --cursor=%d,%d,%d'):format(
                quickfort_parse.format_command(
                    command, self.blueprint_name, self.section_name, dry_run),
                self.saved_cursor.x, self.saved_cursor.y, self.saved_cursor.z))
    local marker = marker_expanded and markers or {}
    local priority = self.subviews.priority:getOptionValue()
    local ctx = self:run_quickfort_command(command, marker, priority, dry_run, false)
    quickfort_command.finish_commands(ctx)
    if command == 'run' then
        if #ctx.messages > 0 then
            self._dialog = dialogs.showMessage(
                    'Blueprint messages',
                    table.concat(ctx.messages, '\n\n'):wrap(dialog_width),
                    nil,
                    post_fn)
        elseif post_fn then
            post_fn()
        end
    elseif command == 'orders' then
        local count = 0
        for _,_ in pairs(ctx.order_specs or {}) do count = count + 1 end
        local messages = {('%d order(s) %senqueued for\n%s.'):format(count,
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

--
-- QuickfortScreen
--

QuickfortScreen = defclass(QuickfortScreen, gui.ZScreen)
QuickfortScreen.ATTRS {
    focus_path='quickfort',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
    filter=DEFAULT_NIL,
}

function QuickfortScreen:init()
    self:addviews{Quickfort{filter=self.filter}}
end

function QuickfortScreen:onShow()
    QuickfortScreen.super.onShow(self)
    self.subviews[1]:show_dialog(true)
end

function QuickfortScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

-- treat all arguments as blueprint list dialog filter text
view = view and view:raise()
        or QuickfortScreen{filter=table.concat({...}, ' ')}:show()

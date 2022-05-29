-- A GUI front-end for the blueprint plugin
--@ module = true
--[====[

gui/blueprint
=============
The `blueprint` plugin records the structure of a portion of your fortress in
a blueprint file that you (or anyone else) can later play back with `quickfort`.

This script provides a visual, interactive interface to make configuring and
using the blueprint plugin much easier.

Usage::

    gui/blueprint [<name> [<phases>]] [<options>]

All parameters are optional. Anything you specify will override the initial
values set in the interface. See the `blueprint` documentation for information
on the possible parameters and options.
]====]

local blueprint = require('plugins.blueprint')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

ActionPanel = defclass(ActionPanel, widgets.ResizingPanel)
ActionPanel.ATTRS{
    get_mark_fn=DEFAULT_NIL,
    is_setting_start_pos_fn=DEFAULT_NIL,
    autoarrange_subviews=true,
}
function ActionPanel:init()
    self:addviews{
        widgets.WrappedLabel{
            view_id='action_label',
            text_to_wrap=self:callback('get_action_text')},
        widgets.TooltipLabel{
            view_id='selected_area',
            indent=1,
            text={{text=self:callback('get_area_text')}},
            show_tooltip=self.get_mark_fn}}
end
function ActionPanel:get_action_text()
    local text = 'Select the '
    if self.is_setting_start_pos_fn() then
        text = text .. 'playback start'
    elseif self.get_mark_fn() then
        text = text .. 'second corner'
    else
        text = text .. 'first corner'
    end
    return text .. ' with the cursor or mouse.'
end
function ActionPanel:get_area_text()
    local mark = self.get_mark_fn()
    if not mark then return '' end
    local width, height, depth = get_dims(mark, df.global.cursor)
    local tiles = width * height * depth
    local plural = tiles > 1 and 's' or ''
    return ('%dx%dx%d (%d tile%s)'):format(width, height, depth, tiles, plural)
end

NamePanel = defclass(NamePanel, widgets.ResizingPanel)
NamePanel.ATTRS{
    name=DEFAULT_NIL,
    autoarrange_subviews=true,
    show_help_fn=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL,
}
function NamePanel:init()
    self:addviews{
        widgets.EditField{
            view_id='name',
            key='CUSTOM_N',
            text=self.name,
            on_change=self:callback('update_tooltip'),
            on_focus=self:callback('on_edit_focus'),
            on_unfocus=self:callback('on_edit_unfocus'),
        },
        widgets.TooltipLabel{
            view_id='name_help',
            text_to_wrap=self:callback('get_name_help'),
            text_dpen=COLOR_RED,
            disabled=function() return self.has_name_collision end,
            show_tooltip=function()
                    return self.has_name_collision or self.show_help_fn() end,
        },
    }

    self:detect_name_collision()
end
function NamePanel:on_edit_focus()
    local name_view = self.subviews.name
    if name_view.text == 'blueprint' then
        name_view.text = ''
        self:update_tooltip()
    end
end
function NamePanel:on_edit_unfocus()
    local name_view = self.subviews.name
    if name_view.text == '' then
        name_view.text = 'blueprint'
        self:update_tooltip()
    end
end
function NamePanel:detect_name_collision()
    -- don't let base names start with a slash - it would get ignored by
    -- the blueprint plugin later anyway
    local name = utils.normalizePath(self.subviews.name.text):gsub('^/','')
    self.subviews.name.text = name

    if name == '' then
        self.has_name_collision = false
        return
    end

    local suffix_pos = #name + 1

    local paths = dfhack.filesystem.listdir_recursive('blueprints', nil, false)
    for _,v in ipairs(paths) do
        if (v.isdir and v.path..'/' == name) or
                (v.path:startswith(name) and
                 v.path:sub(suffix_pos,suffix_pos):find('[.-]')) then
            self.has_name_collision = true
            return
        end
    end
    self.has_name_collision = false
end
function NamePanel:update_tooltip()
    local prev_val = self.has_name_collision
    self:detect_name_collision()
    if self.has_name_collision ~= prev_val then
        self.on_layout_change()
    end
end
function NamePanel:get_name_help()
    if self.has_name_collision then
        return 'Warning: may overwrite existing files.'
    end
    return 'Set base name for the generated blueprint files.'
end

PhasesPanel = defclass(PhasesPanel, widgets.ResizingPanel)
PhasesPanel.ATTRS{
    phases=DEFAULT_NIL,
    show_help_fn=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL,
    autoarrange_subviews=true,
}
function PhasesPanel:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='phases',
            key='CUSTOM_A',
            label='phases',
            options={'Autodetect', 'Custom'},
            initial_option=self.phases.auto_phase and 'Autodetect' or 'Custom',
            on_change=function() self.on_layout_change() end,
        },
        widgets.HotkeyLabel{
            view_id='toggle_all',
            key='CUSTOM_SHIFT_A',
            label='toggle all',
            on_activate=self:callback('toggle_all'),
        },
        -- we need an explicit spacer since the subviews are autoarranged
        widgets.Panel{frame={h=1}},
        widgets.Panel{frame={h=1},
                      subviews={widgets.ToggleHotkeyLabel{view_id='dig_phase',
                                    frame={t=0, l=0},
                                    key='CUSTOM_D', label='dig',
                                    initial_option=self:get_default('dig'),
                                    label_width=5},
                                widgets.ToggleHotkeyLabel{view_id='carve_phase',
                                    frame={t=0, l=15},
                                    key='CUSTOM_SHIFT_D', label='carve',
                                    initial_option=self:get_default('carve')},
                               }},
        widgets.ToggleHotkeyLabel{view_id='build_phase',
                                  key='CUSTOM_B', label='build',
                                  initial_option=self:get_default('build')},
        widgets.Panel{frame={h=1},
                      subviews={widgets.ToggleHotkeyLabel{view_id='place_phase',
                                    frame={t=0, l=0},
                                    key='CUSTOM_P', label='place',
                                    initial_option=self:get_default('place')},
                                widgets.ToggleHotkeyLabel{view_id='zone_phase',
                                    frame={t=0, l=15},
                                    key='CUSTOM_Z', label='zone',
                                    initial_option=self:get_default('zone'),
                                    label_width=5}
                               }},
        widgets.ToggleHotkeyLabel{view_id='query_phase',
                                  key='CUSTOM_Q', label='query',
                                  initial_option=self:get_default('query')},
        widgets.TooltipLabel{
            text_to_wrap='Select blueprint phases to export.',
            show_tooltip=self.show_help_fn,
        },
    }
end
function PhasesPanel:get_default(label)
    return self.phases.auto_phase or not not self.phases[label]
end
function PhasesPanel:toggle_all()
    local dig_phase = self.subviews.dig_phase
    dig_phase:cycle()
    local target_state = dig_phase.option_idx
    for _,subview in pairs(self.subviews) do
        if subview.options and subview.view_id:endswith('_phase') then
            subview.option_idx = target_state
        end
    end
end
function PhasesPanel:preUpdateLayout()
    local is_custom = self.subviews.phases.option_idx > 1
    for _,subview in ipairs(self.subviews) do
        if subview.view_id ~= 'phases' then
            subview.visible = is_custom
        end
    end
end

StartPosPanel = defclass(StartPosPanel, widgets.ResizingPanel)
StartPosPanel.ATTRS{
    start_pos=DEFAULT_NIL,
    start_comment=DEFAULT_NIL,
    on_setting_fn=DEFAULT_NIL,
    show_help_fn=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL,
    autoarrange_subviews = true,
}
function StartPosPanel:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='startpos',
            key='CUSTOM_S',
            label='playback start',
            options={'Unset', 'Setting', 'Set'},
            initial_option=self.start_pos and 'Set' or 'Unset',
            on_change=self:callback('on_change'),
        },
        widgets.TooltipLabel{
            text_to_wrap=self:callback('get_comment'),
            show_tooltip=function() return not not self.start_pos end,
            indent=1,
            text_pen=COLOR_WHITE,
        },
        widgets.TooltipLabel{
            text_to_wrap='Choose where the cursor should be positioned when ' ..
                    'replaying the blueprints.',
            show_tooltip=self.show_help_fn,
        },
    }
end
function StartPosPanel:get_comment()
    return ('Comment: %s'):format(self.start_comment or '')
end
function StartPosPanel:on_change()
    local option = self.subviews.startpos:getOptionLabel()
    if option == 'Unset' then
        self.start_pos = nil
    elseif option == 'Setting' then
        self.on_setting_fn()
    elseif option == 'Set' then
        -- keep reference to _input_box so it is available to tests
        self._input_box = dialogs.InputBox{
            text={'Please enter a comment for the start position\n',
                  '\n',
                  'Example: "on central stairs"\n'},
            on_input=function(comment) self.start_comment = comment end,
            on_close=function() self.on_layout_change() end,
        }
        if self.start_comment then
            self._input_box.subviews.edit.text = self.start_comment
        end
        self._input_box:show()
    end
    self.on_layout_change()
end

BlueprintUI = defclass(BlueprintUI, guidm.MenuOverlay)
BlueprintUI.ATTRS {
    presets=DEFAULT_NIL,
    frame_inset=1,
    focus_path='blueprint',
    sidebar_mode=df.ui_sidebar_mode.LookAround,
}
function BlueprintUI:preinit(info)
    if not info.presets then
        local presets = {}
        blueprint.parse_gui_commandline(presets, {})
        info.presets = presets
    end
end
function BlueprintUI:init()
    -- show_help gets toggled when the help text would make the sidebar contents
    -- taller than the visible frame height
    self.show_help = true
    local function get_show_help() return self.show_help end

    local main_panel = widgets.Panel{view_id='main',
                                     autoarrange_subviews=true,
                                     autoarrange_gap=1}
    main_panel:addviews{
        widgets.Label{text='Blueprint'},
        widgets.TooltipLabel{
            text_to_wrap='Create quickfort blueprints from a live game map.',
            show_tooltip=get_show_help,
            indent=0},
        ActionPanel{
            get_mark_fn=function() return self.mark end,
            is_setting_start_pos_fn=self:callback('is_setting_start_pos')},
        NamePanel{
            name=self.presets.name,
            show_help_fn=get_show_help,
            on_layout_change=self:callback('updateLayout')},
        PhasesPanel{
            phases=self.presets,
            view_id='phases_panel',
            show_help_fn=get_show_help,
            on_layout_change=self:callback('updateLayout')},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
                widgets.ToggleHotkeyLabel{
                    view_id='engrave',
                    key='CUSTOM_E',
                    label='engrave',
                    initial_option=not not self.presets.engrave},
                widgets.TooltipLabel{
                    text_to_wrap='Capture engravings.',
                    show_tooltip=get_show_help}}},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
                widgets.CycleHotkeyLabel{
                    view_id='format',
                    key='CUSTOM_F',
                    label='format',
                    options={{label='Minimal text .csv', value='minimal'},
                            {label='Pretty text .csv', value='pretty'}},
                    initial_option=self.presets.format},
                widgets.TooltipLabel{
                    text_to_wrap='File output format.',
                    show_tooltip=get_show_help}}},
        StartPosPanel{
            view_id='startpos_panel',
            start_pos=self.presets.start_pos,
            start_comment=self.presets.start_comment,
            on_setting_fn=self:callback('save_cursor_pos'),
            show_help_fn=get_show_help,
            on_layout_change=self:callback('updateLayout')},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
                widgets.CycleHotkeyLabel{
                    view_id='splitby',
                    key='CUSTOM_T',
                    label='split',
                    options={{label='No', value='none'},
                            {label='By phase', value='phase'}},
                    initial_option=self.presets.split_strategy},
                widgets.TooltipLabel{
                    text_to_wrap='Split blueprints into multiple files.',
                    show_tooltip=get_show_help}}},
        widgets.HotkeyLabel{
            view_id='cancel_label',
            key='LEAVESCREEN',
            label=self:callback('get_cancel_label'),
            on_activate=self:callback('on_cancel')}
    }
    self:addviews{main_panel}
end

function BlueprintUI:onShow()
    BlueprintUI.super.onShow(self)
    local start = self.presets.start
    if not start or not dfhack.maps.isValidTilePos(start) then
        return
    end
    guidm.setCursorPos(start)
    dfhack.gui.revealInDwarfmodeMap(start, true)
    self:on_mark(start)
end

function BlueprintUI:on_mark(pos)
    self.mark = pos
    self:updateLayout()
end

function BlueprintUI:save_cursor_pos()
    self.saved_cursor = copyall(df.global.cursor)
end

function BlueprintUI:is_setting_start_pos()
    return self.subviews.startpos:getOptionLabel() == 'Setting'
end

function BlueprintUI:get_cancel_label()
    if self.mark or self:is_setting_start_pos() then
        return 'Cancel selection'
    end
    return 'Back'
end

function BlueprintUI:on_cancel()
    if self:is_setting_start_pos() then
        self.subviews.startpos.option_idx = 1
        self.saved_cursor = nil
        self:updateLayout()
    elseif self.mark then
        self.mark = nil
        self:updateLayout()
    else
        self:dismiss()
    end
end

function BlueprintUI:postUpdateLayout(parent_rect)
    -- if we can't fit in the screen, hide help text and try again
    local y = self.subviews.main.frame_rect.height
    local refresh_layout = false
    if self.show_help and parent_rect and
            y > parent_rect.clip_y2 - 2*self.frame_inset then
        self.show_help = false
        self.show_help_y = y
        refresh_layout = true
    elseif not self.show_help and parent_rect and
            self.show_help_y <= parent_rect.clip_y2 - 2*self.frame_inset then
        -- screen is tall enough for help text again
        self.show_help = true
        refresh_layout = true
    end
    if refresh_layout then
        self:updateLayout(parent_rect)
    end
end

function BlueprintUI:get_bounds()
    local cur = self.saved_cursor or guidm.getCursorPos()
    local mark = self.mark or cur
    local start_pos = self.subviews.startpos_panel.start_pos or mark

    return {
        x1=math.min(cur.x, mark.x, start_pos.x),
        x2=math.max(cur.x, mark.x, start_pos.x),
        y1=math.min(cur.y, mark.y, start_pos.y),
        y2=math.max(cur.y, mark.y, start_pos.y),
        z1=math.min(cur.z, mark.z),
        z2=math.max(cur.z, mark.z)
    }
end

function BlueprintUI:onRenderBody()
    if not gui.blink_visible(500) then return end

    local start_pos = self.subviews.startpos_panel.start_pos
    if not self.mark and not start_pos then return end

    local function get_overlay_char(pos, is_cursor)
        -- always render start_pos tile, even if it would overwrite the cursor
        if same_xy(start_pos, pos) then return 'X', COLOR_BLUE end
        if is_cursor then return nil end
        return 'X'
    end

    self:renderMapOverlay(get_overlay_char, self:get_bounds())
end

function BlueprintUI:onInput(keys)
    if self:inputToSubviews(keys) then return true end

    local pos = nil
    if keys._MOUSE_L then
        local x, y = dfhack.screen.getMousePos()
        if gui.is_in_rect(guidm.getPanelLayout().map, x, y) then
            pos = xyz2pos(df.global.window_x + x - 1,
                          df.global.window_y + y - 1,
                          df.global.window_z)
            guidm.setCursorPos(pos)
        end
    elseif keys.SELECT then
        pos = guidm.getCursorPos()
    end

    if pos then
        if self:is_setting_start_pos() then
            self.subviews.startpos_panel.start_pos = pos
            self.subviews.startpos:cycle()
            guidm.setCursorPos(self.saved_cursor)
            self.saved_cursor = nil
        elseif self.mark then
            self:commit(pos)
        else
            self:on_mark(pos)
        end
        return true
    end

    return self:propagateMoveKeys(keys)
end

-- assemble and execute the blueprint commandline
function BlueprintUI:commit(pos)
    local mark = self.mark
    local width, height, depth = get_dims(mark, pos)
    if depth > 1 then
        -- when there are multiple levels, process them top to bottom
        depth = -depth
    end

    local name = self.subviews.name.text
    local params = {tostring(width), tostring(height), tostring(depth), name}

    local phases_view = self.subviews.phases
    if phases_view:getOptionValue() == 'Custom' then
        local some_phase_is_set = false
        for _,sv in pairs(self.subviews.phases_panel.subviews) do
            if sv.options and sv:getOptionLabel() == 'On' then
                table.insert(params, sv.label)
                some_phase_is_set = true
            end
        end
        if not some_phase_is_set then
            dialogs.MessageBox{
                frame_title='Error',
                text='Ensure at least one phase is enabled or enable autodetect'
            }:show()
            return
        end
    end

    -- set cursor to top left corner of the *uppermost* z-level
    local bounds = self:get_bounds()
    table.insert(params, ('--cursor=%d,%d,%d')
                         :format(bounds.x1, bounds.y1, bounds.z2))

    if self.subviews.engrave:getOptionValue() then
        table.insert(params, '--engrave')
    end

    local format = self.subviews.format:getOptionValue()
    if format ~= 'minimal' then
        table.insert(params, ('--format=%s'):format(format))
    end

    local start_pos = self.subviews.startpos_panel.start_pos
    if start_pos then
        local playback_start_x = start_pos.x - bounds.x1 + 1
        local playback_start_y = start_pos.y - bounds.y1 + 1
        local start_pos_param = ('--playback-start=%d,%d')
                                :format(playback_start_x, playback_start_y)
        local start_comment = self.subviews.startpos_panel.start_comment
        if start_comment and #start_comment > 0 then
            start_pos_param = start_pos_param .. (',%s'):format(start_comment)
        end
        table.insert(params, start_pos_param)
    end

    local splitby = self.subviews.splitby:getOptionValue()
    if splitby ~= 'none' then
        table.insert(params, ('--splitby=%s'):format(splitby))
    end

    print('running: blueprint ' .. table.concat(params, ' '))
    local files = blueprint.run(table.unpack(params))

    local text = 'No files generated (see console for any error output)'
    if files and #files > 0 then
        text = 'Generated blueprint file(s):\n'
        for _,fname in ipairs(files) do
            text = text .. ('  %s\n'):format(fname)
        end
    end

    dialogs.MessageBox{
        frame_title='Blueprint completed',
        text=text,
        on_close=self:callback('dismiss'),
    }:show()
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

local options, args = {}, {...}
local ok, err = dfhack.pcall(blueprint.parse_gui_commandline, options, args)
if not ok then
    dfhack.printerr(tostring(err))
    options.help = true
end

if options.help then
    print(dfhack.script_help())
    return
end

view = BlueprintUI{presets=options}
view:show()

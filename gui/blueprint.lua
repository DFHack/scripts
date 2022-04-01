-- A GUI front-end for the blueprint plugin
--@ module = true
--[====[

gui/blueprint
=============
The `blueprint` plugin records the structure of a portion of your fortress in
a blueprint file that you (or anyone else) can later play back with `quickfort`.

This script provides a visual, interactive interface to make configuring and
using the blueprint plugin much easier.

Usage:

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

local function auto_layout(panel, spacer)
    -- recalculate widget frames
    panel:updateSubviewLayout()

    -- vertically lay out subviews, adding spacer lines of space between each
    spacer = spacer or 0
    local y = 0
    for _,subview in ipairs(panel.subviews) do
        subview.frame.t = y
        if subview.visible then
            y = y + subview.frame.h + spacer
        end
    end

    -- recalculate widget frames again
    panel:updateSubviewLayout()

    return y
end

ResizingPanel = defclass(ResizingPanel, widgets.Panel)
function ResizingPanel:init()
    if not self.frame then self.frame = {} end
end
function ResizingPanel:postUpdateLayout()
    local h = 0
    for _,subview in ipairs(self.subviews) do
        if subview.visible then
            h = math.max(h, (subview.frame.t or 1) + (subview.frame.h or 1))
        end
    end
    self.frame.h = h
end

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

ActionPanel = defclass(ActionPanel, ResizingPanel)
ActionPanel.ATTRS{
    get_mark_fn=DEFAULT_NIL,
    is_setting_start_pos_fn=DEFAULT_NIL,
}
function ActionPanel:init()
    self:addviews{
        widgets.Label{
            view_id='action_label',
            text={{text=self:callback('get_action_text')}},
            frame={t=0},
        },
        widgets.Label{
            text='with the cursor or mouse.',
            frame={t=1},
        },
        widgets.Label{
            view_id='selected_area',
            text={{text=self:callback('get_area_text')}},
            frame={t=2,l=1},
        },
    }
end
function ActionPanel:preUpdateLayout()
    self.subviews.selected_area.visible = self.get_mark_fn() ~= nil
end
function ActionPanel:get_action_text()
    if self.is_setting_start_pos_fn() then
        return 'Select the playback start'
    end
    if self.get_mark_fn() then
        return 'Select the second corner'
    end
    return 'Select the first corner'
end
function ActionPanel:get_area_text()
    local width, height, depth = get_dims(self.get_mark_fn(), df.global.cursor)
    local tiles = width * height * depth
    local plural = tiles > 1 and 's' or ''
    return ('%dx%dx%d (%d tile%s)'):format(width, height, depth, tiles, plural)
end

NamePanel = defclass(NamePanel, ResizingPanel)
NamePanel.ATTRS{
    name='blueprint',
}
function NamePanel:init()
    self:addviews{
        widgets.EditField{
            view_id='name',
            frame={t=0,h=1},
            key='CUSTOM_N',
            active=false,
            text=self.name,
            on_change=self:callback('detect_name_collision'),
        },
        widgets.Label{
            view_id='name_help',
            frame={t=1,l=2},
            text={{text=self:callback('get_name_help', 1),
                   pen=self:callback('get_help_pen')}, '\n',
                  {text=self:callback('get_name_help', 2),
                   pen=self:callback('get_help_pen')}}
        },
    }

    self:detect_name_collision()
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
function NamePanel:get_name_help(line_number)
    if self.has_name_collision then
        return ({'Warning: may overwrite',
                 'existing files.'})[line_number]
    end
    return ({'Set base name for the',
             'generated blueprint files.'})[line_number]
end
function NamePanel:get_help_pen()
    return self.has_name_collision and COLOR_RED or COLOR_GREY
end

-- each option in the options list can be a simple string or a table of
-- {label=string, value=string}. simple string options use the same string for
-- the label and value.
CycleHotkeyLabel = defclass(CycleHotkeyLabel, widgets.Label)
CycleHotkeyLabel.ATTRS{
    key=DEFAULT_NIL,
    label=DEFAULT_NIL,
    label_width=DEFAULT_NIL,
    options=DEFAULT_NIL,
    option_idx=1,
    help=DEFAULT_NIL,
    show_help_fn=DEFAULT_NIL,
    on_change=DEFAULT_NIL,
}
function CycleHotkeyLabel:init()
    self:preUpdateLayout()
end
function CycleHotkeyLabel:cycle()
    if self.option_idx == #self.options then
        self.option_idx = 1
    else
        self.option_idx = self.option_idx + 1
    end
    if self.on_change then self.on_change() end
end
function CycleHotkeyLabel:get_current_option_label()
    local option = self.options[self.option_idx]
    if type(option) == 'table' then
        return option.label
    end
    return option
end
function CycleHotkeyLabel:get_current_option_value()
    local option = self.options[self.option_idx]
    if type(option) == 'table' then
        return option.value
    end
    return option
end
function CycleHotkeyLabel:preUpdateLayout()
    local contents = {
        {text=self.label, width=self.label_width, key=self.key, key_sep=': ',
         on_activate=self:callback('cycle')},
        '  ',
        {text=self:callback('get_current_option_label')},
    }
    if self.help and (not self.show_help_fn or self.show_help_fn()) then
        table.insert(contents, '\n')
        for _,line in ipairs(self.help) do
            table.insert(contents, {gap=2, text=line, pen=COLOR_GREY})
            table.insert(contents, '\n')
        end
    end
    self:setText(contents)
end

ToggleHotkeyLabel = defclass(ToggleHotkeyLabel, CycleHotkeyLabel)
ToggleHotkeyLabel.ATTRS{
    options={'On', 'Off'},
}

PhasesPanel = defclass(PhasesPanel, ResizingPanel)
PhasesPanel.ATTRS{
    phases={},
    show_help_fn=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL,
}
function PhasesPanel:init()
    self:addviews{
        CycleHotkeyLabel{
            view_id='phases',
            key='CUSTOM_A',
            label='phases',
            options={'Autodetect', 'Custom'},
            option_idx=self.phases.auto_phase and 1 or 2,
            help={'Select blueprint phases',
                  'to export.'},
            show_help_fn=self.show_help_fn,
            on_change=self.on_layout_change,
        },
        CycleHotkeyLabel{
            view_id='toggle_all',
            key='CUSTOM_SHIFT_A',
            label='toggle all',
            options={'', ''},
            on_change=self:callback('toggle_all'),
        },
        -- we need an explicit spacer since the panel height is autocalculated
        -- from the subviews
        widgets.Panel{frame={h=1}},
        widgets.Panel{frame={h=1},
                      subviews={ToggleHotkeyLabel{view_id='dig_phase',
                                    frame={t=0, l=0},
                                    key='CUSTOM_D', label='dig',
                                    option_idx=self:get_default('dig'),
                                    label_width=5},
                                ToggleHotkeyLabel{view_id='carve_phase',
                                    frame={t=0, l=15},
                                    key='CUSTOM_SHIFT_D', label='carve',
                                    option_idx=self:get_default('carve')}}},
        ToggleHotkeyLabel{view_id='build_phase', key='CUSTOM_B', label='build',
                          option_idx=self:get_default('build')},
        widgets.Panel{frame={h=1},
                      subviews={ToggleHotkeyLabel{view_id='place_phase',
                                    frame={t=0, l=0},
                                    key='CUSTOM_P', label='place',
                                    option_idx=self:get_default('place')},
                                ToggleHotkeyLabel{view_id='zone_phase',
                                    frame={t=0, l=15},
                                    key='CUSTOM_Z', label='zone',
                                    option_idx=self:get_default('zone'),
                                    label_width=5}}},
        ToggleHotkeyLabel{view_id='query_phase', key='CUSTOM_Q', label='query',
                          option_idx=self:get_default('query')},
    }
end
function PhasesPanel:get_default(label)
    return (self.phases.auto_phase or self.phases[label]) and 1 or 2
end
function PhasesPanel:toggle_all()
    local target_state = self.subviews.toggle_all.option_idx
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
function PhasesPanel:updateLayout(parent_rect)
    -- set frame boundaries and calculate subframe heights
    PhasesPanel.super.updateLayout(self, parent_rect)

    auto_layout(self)
end

StartPosPanel = defclass(StartPosPanel, ResizingPanel)
StartPosPanel.ATTRS{
    start_pos=DEFAULT_NIL,
    start_comment=DEFAULT_NIL,
    on_setting_fn=DEFAULT_NIL,
    show_help_fn=DEFAULT_NIL,
    on_layout_change=DEFAULT_NIL,
}
function StartPosPanel:init()
    self:addviews{
        CycleHotkeyLabel{
            view_id='startpos',
            frame={t=0},
            key='CUSTOM_S',
            label='playback start',
            options={'Unset', 'Setting', 'Set'},
            option_idx=self.start_pos and 3 or 1,
            help={'Set where the cursor',
                  'should be positioned when',
                  'replaying the blueprints.'},
            show_help_fn=self.show_help_fn,
            on_change=self:callback('on_change'),
        },
        widgets.Label{
            view_id='comment',
            frame={t=4},
            text={{text=self:callback('print_comment')}}
        }
    }
end
function StartPosPanel:preUpdateLayout()
    self.subviews.comment.visible = not not self.start_pos
end
function StartPosPanel:print_comment()
    return ('Comment: %s'):format(self.start_comment or '')
end
function StartPosPanel:on_change()
    local option = self.subviews.startpos:get_current_option_label()
    if option == 'Unset' then
        self.start_pos = nil
    elseif option == 'Setting' then
        self.on_setting_fn()
    elseif option == 'Set' then
        self.input_box = dialogs.InputBox{
            text={'Please enter a comment for the start position\n',
                  '\n',
                  'Example: "on central stairs"\n'},
            on_input=function(comment)
                        self.start_comment = comment
                        self.input_box = nil
                     end,
        }
        if self.start_comment then
            self.input_box.subviews.edit.text = self.start_comment
        end
        self.input_box:show()
    end
    if self.on_layout_change then self.on_layout_change() end
end

BlueprintUI = defclass(BlueprintUI, guidm.MenuOverlay)
BlueprintUI.ATTRS {
    presets={},
    frame_inset=1,
    focus_path='blueprint',
}
function BlueprintUI:init()
    self.show_help = true
    local function get_show_help() return self.show_help end

    self:addviews{
        widgets.Label{text='Blueprint'},
        widgets.Label{
            view_id='summary',
            text={'Create quickfort blueprints\n',
                  'from a live game map.'},
            text_pen=COLOR_GREY},
        ActionPanel{
            get_mark_fn=function() return self.mark end,
            is_setting_start_pos_fn=self:callback('is_setting_start_pos')},
        NamePanel{name=self.presets.name},
        PhasesPanel{
            phases=self.presets,
            view_id='phases_panel',
            show_help_fn=get_show_help,
            on_layout_change=self:callback('updateLayout')},
        ToggleHotkeyLabel{
            view_id='engrave',
            key='CUSTOM_E',
            label='engrave',
            option_idx=self.presets.engrave and 1 or 2,
            help={'Capture engravings.'},
            show_help_fn=get_show_help},
        CycleHotkeyLabel{
            view_id='format',
            key='CUSTOM_F',
            label='format',
            options={{label='Minimal text .csv', value='minimal'},
                     {label='Pretty text .csv', value='pretty'}},
            option_idx=self.presets.format == 'minimal' and 1 or 2,
            help={'File output format.'},
            show_help_fn=get_show_help},
        StartPosPanel{
            view_id='startpos_panel',
            start_pos=self.presets.start_pos,
            start_comment=self.presets.start_comment,
            on_setting_fn=self:callback('save_cursor_pos'),
            show_help_fn=get_show_help,
            on_layout_change=self:callback('updateLayout')},
        CycleHotkeyLabel{
            view_id='splitby',
            key='CUSTOM_T',
            label='split',
            options={{label='No', value='none'},
                     {label='By phase', value='phase'}},
            option_idx=self.presets.split_strategy == 'none' and 1 or 2,
            help={'Split blueprints into',
                  'multiple files.'},
            show_help_fn=get_show_help},
        widgets.Label{
            view_id='cancel_label',
            text={{text=self:callback('get_cancel_label'), key='LEAVESCREEN',
                   key_sep=': ', on_activate=self:callback('on_cancel')}}}
    }
end

function BlueprintUI:onAboutToShow()
    if not dfhack.isMapLoaded() then
        qerror('Please load a fortress map.')
    end

    self.saved_mode = df.global.ui.main.mode
    if dfhack.gui.getCurFocus(true):find('^dfhack/')
            or not guidm.SIDEBAR_MODE_KEYS[self.saved_mode] then
        self.saved_mode = df.ui_sidebar_mode.Default
    end
    guidm.enterSidebarMode(df.ui_sidebar_mode.LookAround)
end

function BlueprintUI:onShow()
    local start = self.presets.start
    if not start or not dfhack.maps.isValidTilePos(start) then
        return
    end
    guidm.setCursorPos(start)
    dfhack.gui.revealInDwarfmodeMap(start, true)
    self:on_mark(start)
end

function BlueprintUI:onDismiss()
    guidm.enterSidebarMode(self.saved_mode)
end

function BlueprintUI:on_mark(pos)
    self.mark = pos
    self:updateLayout()
end

function BlueprintUI:save_cursor_pos()
    self.saved_cursor = copyall(df.global.cursor)
end

function BlueprintUI:is_setting_start_pos()
    return self.subviews.startpos:get_current_option_label() == 'Setting'
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
    elseif self.mark then
        self.mark = nil
        self:updateLayout()
    else
        self:dismiss()
    end
end

function BlueprintUI:updateLayout(parent_rect)
    -- set frame boundaries and calculate subframe heights
    BlueprintUI.super.updateLayout(self, parent_rect)

    -- set help text visibility
    self.subviews.summary.visible = self.show_help

    local y = auto_layout(self, 1)

    -- if we can't fit in the screen, hide help text and try again
    if self.show_help and parent_rect and
            y > parent_rect.clip_y2 - 2*self.frame_inset then
        self.show_help = false
        self.show_help_y = y
        self:updateLayout(parent_rect)
    elseif not self.show_help and parent_rect and
            self.show_help_y <= parent_rect.clip_y2 - 2*self.frame_inset then
        -- screen is tall enough for help text again
        self.show_help = true
        self:updateLayout(parent_rect)
    end
end

-- Sorts and returns the given arguments.
local function min_to_max(...)
    local args = {...}
    table.sort(args, function(a, b) return a < b end)
    return table.unpack(args)
end

function BlueprintUI:onRenderBody()
    if not gui.blink_visible(500) then return end

    local start_pos = self.subviews.startpos_panel.start_pos
    if not self.mark and not start_pos then return end

    local vp = self:getViewport()
    local dc = gui.Painter.new(self.df_layout.map)

    local cursor = df.global.cursor
    local highlight_bound = self.saved_cursor or cursor
    local mark = self.mark or highlight_bound

    -- mark start_pos (will get ignored if it's offscreen)
    if start_pos then
        local start_tile = vp:tileToScreen(start_pos)
        dc:map(true):seek(start_tile.x, start_tile.y):
                pen(COLOR_BLUE, COLOR_BLACK):char('X'):map(false)
    end

    -- clip scanning range to viewport for performance. offscreen writes will
    -- get ignored, but it can be slow to scan over large offscreen regions.
    local _,y_start,y_end = min_to_max(mark.y, highlight_bound.y, vp.y1, vp.y2)
    local _,x_start,x_end = min_to_max(mark.x, highlight_bound.x, vp.x1, vp.x2)
    for y=y_start,y_end do
        for x=x_start,x_end do
            local pos = xyz2pos(x, y, cursor.z)
            -- don't overwrite the cursor or start_tile so the user can still
            -- see them
            if not same_xy(cursor, pos) and not same_xy(start_pos, pos) then
                local stile = vp:tileToScreen(pos)
                dc:map(true):seek(stile.x, stile.y):
                        pen(COLOR_GREEN, COLOR_BLACK):char('X'):map(false)
            end
        end
    end
end

function BlueprintUI:onInput(keys)
    -- the 'name' edit field must have its 'active' state managed at this level.
    -- we also have to implement 'cancel edit' logic here
    local name_view = self.subviews.name
    if not name_view.active and keys[name_view.key] then
        self.saved_name = name_view.text
        if name_view.text == 'blueprint' then
            name_view.text = ''
            name_view:on_change()
        end
        name_view.active = true
        return true
    end
    if name_view.active then
        if keys.SELECT or keys.LEAVESCREEN then
            name_view.active = false
            if keys.LEAVESCREEN or name_view.text == '' then
                name_view.text = self.saved_name
                name_view:on_change()
            end
            return true
        end
        name_view:onInput(keys)
        return true
    end

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
    if phases_view:get_current_option_value() == 'Custom' then
        local some_phase_is_set = false
        for _,sv in pairs(self.subviews.phases_panel.subviews) do
            if sv.options and sv:get_current_option_value() == 'On' then
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
    local x, y, z = math.min(mark.x, pos.x), math.min(mark.y, pos.y),
            math.max(mark.z, pos.z)
    table.insert(params, ('--cursor=%d,%d,%d'):format(x, y, z))

    local engrave = self.subviews.engrave:get_current_option_value()
    if engrave == 'On' then
        table.insert(params, '--engrave')
    end

    local format = self.subviews.format:get_current_option_value()
    if format ~= 'minimal' then
        table.insert(params, ('--format=%s'):format(format))
    end

    local start_pos = self.subviews.startpos_panel.start_pos
    if start_pos then
        local playback_start_x = start_pos.x - x + 1
        local playback_start_y = start_pos.y - y + 1
        if playback_start_x < 1 or playback_start_x > width or
                playback_start_y < 1 or playback_start_y > height then
            dialogs.MessageBox{
                frame_title='Error',
                text='Playback start position must be within the blueprint area'
            }:show()
            return
        end
        start_pos_param = ('--playback-start=%d,%d')
                          :format(playback_start_x, playback_start_y)
        local start_comment = self.subviews.startpos_panel.start_comment
        if start_comment and #start_comment > 0 then
            start_pos_param = start_pos_param .. (',%s'):format(start_comment)
        end
        table.insert(params, start_pos_param)
    end

    local splitby = self.subviews.splitby:get_current_option_value()
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

if active_screen then
    active_screen:dismiss()
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

active_screen = BlueprintUI{presets=options}
active_screen:show()

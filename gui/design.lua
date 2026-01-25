-- A GUI front-end for creating designs
--@ module = true

-- TODOS ====================

-- Refactor duplicated code into functions
--  File is getting long... might be time to consider creating additional modules
-- All the various states are getting hard to keep track of, e.g. placing extra/mirror/mark/etc...
--   Should consolidate the states into a single state attribute with enum values
-- Keyboard support
-- Grid view without slowness (can ignore if next TODO is done, since normal mining mode has grid view)
--   Lags when drawing the full screen grid on each frame render
-- Integrate with default mining mode for designation type, priority, etc... (possible?)
-- Figure out how to remove dug stairs with mode (nothing seems to work, include 'dig ramp')
-- 'No overwrite' mode to not overwrite existing designations
-- Snap to grid, or angle, like 45 degrees, or some kind of tools to assist with symmetrical designs

-- Nice To Haves
-----------------------------
-- Exploration pattern ladder https://dwarffortresswiki.org/index.php/DF2014:Exploratory_mining#Ladder_Rows

-- Stretch Goals
-----------------------------
-- Shape preview in panel
-- Shape designer in preview panel to draw repeatable shapes i'e' 2x3 room with door
-- 3D shapes, would allow stuff like spiral staircases/minecart tracks and other neat stuff, probably not too hard

-- END TODOS ================

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local overlay = require('plugins.overlay')
local plugin = require('plugins.design')
local quickfort = reqscript('quickfort')
local shapes = reqscript('internal/design/shapes')
local textures = require('gui.textures')
local util = reqscript('internal/design/util')
local utils = require('utils')
local widgets = require('gui.widgets')

local Point = util.Point
local getMousePoint = util.getMousePoint

local to_pen = dfhack.pen.parse
local guide_tile_pen = to_pen{
    ch='+',
    fg=COLOR_YELLOW,
    tile=dfhack.screen.findGraphicsTile('CURSORS', 0, 22),
}
local mirror_guide_pen = to_pen{
    ch='+',
    fg=COLOR_YELLOW,
    tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 22),
}

-- ----------------- --
-- DimensionsOverlay --
-- ----------------- --

DimensionsOverlay = defclass(DimensionsOverlay, overlay.OverlayWidget)
DimensionsOverlay.ATTRS{
    desc='Adds a tooltip that shows the selected dimensions when drawing boxes.',
    default_pos={x=1,y=1},
    default_enabled=true,
    fullscreen=true, -- not player-repositionable
    viewscreens={
        'dwarfmode/Designate',
        'dwarfmode/Burrow/Paint',
        'dwarfmode/Stockpile/Paint',
        'dwarfmode/Zone/Paint',
        'dwarfmode/Building/Placement',
    },
}

local main_interface = df.global.game.main_interface
local selection_rect = df.global.selection_rect
local uibs = df.global.buildreq

local function get_selection_rect_pos()
    if selection_rect.start_x < 0 then return end
    return xyz2pos(selection_rect.start_x, selection_rect.start_y, selection_rect.start_z)
end

local function get_uibs_pos()
    if uibs.selection_pos.x < 0 then return end
    return uibs.selection_pos
end

function DimensionsOverlay:init()
    self:addviews{
        widgets.DimensionsTooltip{
            get_anchor_pos_fn=function()
                if dfhack.gui.matchFocusString('dwarfmode/Building/Placement',
                    dfhack.gui.getDFViewscreen(true))
                then
                    return get_uibs_pos()
                else
                    return get_selection_rect_pos()
                end
            end,
        },
    }
end

-- don't imply that stockpiles or zones will be 3d
local function check_stockpile_dims()
    if selection_rect.start_x > 0 and
        (main_interface.bottom_mode_selected == df.main_bottom_mode_type.STOCKPILE_PAINT or
         main_interface.bottom_mode_selected == df.main_bottom_mode_type.ZONE_PAINT)
    then
        selection_rect.start_z = df.global.window_z
    end
end

function DimensionsOverlay:render(dc)
    check_stockpile_dims()
    DimensionsOverlay.super.render(self, dc)
end

function DimensionsOverlay:preUpdateLayout(parent_rect)
    self.frame.w = parent_rect.width
    self.frame.h = parent_rect.height
end

function DimensionsOverlay:overlay_onenable()
    df.global.d_init.display.flags.SHOW_RECTANGLE_DIMENSIONS = false
end

function DimensionsOverlay:overlay_ondisable()
    df.global.d_init.display.flags.SHOW_RECTANGLE_DIMENSIONS = true
end

---
--- RightClickOverlay
---

RightClickOverlay = defclass(RightClickOverlay, overlay.OverlayWidget)
RightClickOverlay.ATTRS{
    desc='When drawing boxes, makes right click cancel selection instead of exiting.',
    default_enabled=true,
    fullscreen=true,
    viewscreens={
        'dwarfmode/Designate',
        'dwarfmode/Burrow/Paint',
        'dwarfmode/Stockpile/Paint',
        'dwarfmode/Zone/Paint',
        'dwarfmode/Building/Placement'
        },
}

function RightClickOverlay:onInput(keys)
    if keys._MOUSE_R or keys.LEAVESCREEN then
        -- building mode
        if dfhack.gui.matchFocusString('dwarfmode/Building/Placement',
            dfhack.gui.getDFViewscreen(true))
        then
            if uibs.selection_pos.x >= 0 then
                uibs.selection_pos:clear()
                return true
            end
        -- all other modes
        elseif selection_rect.start_x >= 0 then
            selection_rect.start_x = -30000
            selection_rect.start_y = -30000
            selection_rect.start_z = -30000
            return true
        end
    end
end

OVERLAY_WIDGETS = {
    dimensions=DimensionsOverlay,
    rightclick=RightClickOverlay,
}

---
--- HelpWindow
---

CONSTRUCTION_HELP = {
    'Building filters',
    '================',
    NEWLINE,
    'Use the DFHack building planner to configure filters for the desired construction types. This tool will use the current buildingplan filters for a building type.'
}

HelpWindow = defclass(HelpWindow, widgets.Window)
HelpWindow.ATTRS{
    frame_title='gui/design Help',
    frame={w=43, h=20, t=10, l=10},
    resizable=true,
    resize_min={h=10},
    message='',
}

function HelpWindow:init()
    self:addviews{
        widgets.WrappedLabel{
            auto_height=false,
            text_to_wrap=function() return self.message end,
        },
    }
end

-- Utilities

local BUTTON_PEN_LEFT = to_pen{fg=COLOR_CYAN, tile=curry(textures.tp_control_panel, 7) or nil, ch=string.byte('[')}
local HELP_PEN_CENTER = to_pen{tile=curry(textures.tp_control_panel, 9) or nil, ch=string.byte('?')}
local BUTTON_PEN_RIGHT = to_pen{fg=COLOR_CYAN, tile=curry(textures.tp_control_panel, 8) or nil, ch=string.byte(']')}

-- Debug window

SHOW_DEBUG_WINDOW = SHOW_DEBUG_WINDOW or false

local function table_to_string(tbl, indent)
    indent = indent or ''
    local result = {}
    for k, v in pairs(tbl) do
        local key = type(k) == 'number' and ('[%d]'):format(k) or tostring(k)
        if type(v) == 'table' then
            table.insert(result, indent .. key .. ' = {')
            local subTable = table_to_string(v, indent .. '  ')
            for _, line in ipairs(subTable) do
                table.insert(result, line)
            end
            table.insert(result, indent .. '},')
        else
            local val = utils.getval(v)
            local value = type(val) == 'string' and ('"%s"'):format(val) or tostring(val)
            table.insert(result, indent .. key .. ' = ' .. value .. ',')
        end
    end
    return result
end

DesignDebugWindow = defclass(DesignDebugWindow, widgets.Window)
DesignDebugWindow.ATTRS {
    frame_title='Debug',
    frame={w=47, h=40, l=10, t=8},
    resizable=true,
    resize_min={w=20, h=30},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    design_window=DEFAULT_NIL,
}

function DesignDebugWindow:init()

    local attrs = {
        'needs_update',
        'placing_mark',
        '#marks',
        'placing_mirror',
        'mirror',
        'mirror_point',
        'placing_extra',
        'extra_points',
        'last_mouse_point',
        'prev_center',
        'start_center',
    }

    for _, attr in ipairs(attrs) do
        self:addviews{
            widgets.WrappedLabel{
                text_to_wrap=function()
                    local want_size = attr:startswith('#')
                    local field = want_size and attr:sub(2) or attr
                    if type(self.design_window[field]) ~= 'table' then
                        return ('%s: %s'):format(field, self.design_window[field])
                    end

                    if want_size then
                        return ('%s: %d'):format(attr, #self.design_window[field])
                    else
                        return ('%s: %s'):format(attr,
                            table.concat(table_to_string(self.design_window[attr], '  ')))
                    end
                end,
            },
        }
    end
end

function DesignDebugWindow:render(dc)
    self:updateLayout()
    DesignDebugWindow.super.render(self, dc)
end

--
-- Design
--

Design = defclass(Design, widgets.Window)
Design.ATTRS {
    frame_title = 'Design',
    frame={w=40, h=48, r=2, t=18},
    resizable=true,
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

local function make_mode_option(desig, mode, ch1, ch2, ch1_color, ch2_color, x, y, x_selected, y_selected)
    y_selected = y_selected or y
    return {
        desig=desig,
        mode=mode,
        button_spec=util.make_button_spec(ch1, ch2, ch1_color, ch2_color, COLOR_GRAY, COLOR_WHITE, x, y),
        button_selected_spec=util.make_button_spec(ch1, ch2, ch1_color, ch2_color, COLOR_YELLOW, COLOR_YELLOW, x_selected, y_selected),
    }
end

function Design:init()
    self.needs_update = true
    self.marks = {}
    self.extra_points = {}
    self.placing_extra = {active=false, index=nil}
    self.placing_mark = {active=true, index=1, continue=true}
    self.placing_mirror = false
    self.mirror = {horizontal=false, vertical=false}

    local mode_options = {
        {label='Dig', value=make_mode_option('d', 'dig', '-', ')', COLOR_BROWN, COLOR_GRAY, 0, 22, 4)},
        {label='Stairs', value=make_mode_option('i', 'dig', '>', '<', COLOR_GRAY, COLOR_GRAY, 8, 22, 12)},
        {label='Ramp', value=make_mode_option('r', 'dig', 30, 30, COLOR_GRAY, COLOR_GRAY, 0, 25, 4)},
        {label='Channel', value=make_mode_option('h', 'dig', 31, 31, COLOR_GRAY, COLOR_GRAY, 8, 25, 12)},
        {label='Smooth', value=make_mode_option('s', 'dig', 177, 219, COLOR_GRAY, COLOR_WHITE, 0, 55, 4)},
        {label='Engrave', value=make_mode_option('e', 'dig', 219, 1, COLOR_GRAY, {fg=COLOR_WHITE, bg=COLOR_GRAY}, 0, 58, 4)},
        -- TODO: get matching selected version of erase icon
        {label='Remove Designation', value=make_mode_option('x', 'dig', 'X', 'X', COLOR_LIGHTRED, COLOR_LIGHTRED, 24, 28, 12)},
        {label='Building', value=make_mode_option('b', 'build', 210, 229, COLOR_BROWN, COLOR_DARKGRAY, 16, 31, 20)},
    }
    local mode_button_specs, mode_button_specs_selected = {}, {}
    for _, mode_option in ipairs(mode_options) do
        table.insert(mode_button_specs, mode_option.value.button_spec)
        table.insert(mode_button_specs_selected, mode_option.value.button_selected_spec)
    end

    local DESIGN_ICONS_WIDTH = 224 -- Must match design.png image width
    local DESIGN_ICONS_HEIGHT = 72 -- Must match design.png image height
    local DESIGN_ICON_ROW_COUNT = 2
    local DESIGN_CHAR_WIDTH = 8
    local DESIGN_CHAR_HEIGHT = 12
    local shape_tileset = dfhack.textures.loadTileset('hack/data/art/design.png', DESIGN_CHAR_WIDTH, DESIGN_CHAR_HEIGHT, true)

    local STRIDE = DESIGN_ICONS_WIDTH / DESIGN_CHAR_WIDTH
    local CHARS_PER_ROW = DESIGN_ICONS_HEIGHT / (DESIGN_ICON_ROW_COUNT * DESIGN_CHAR_HEIGHT)

    local shape_options, shape_button_specs, shape_button_specs_selected = {}, {}, {}
    for _, shape in ipairs(shapes.all_shapes) do
        table.insert(shape_options, {label=shape.name, value=shape})
        table.insert(shape_button_specs, {
            chars=shape.button_chars,
            tileset=shape_tileset,
            tileset_offset=shape.texture_offset,
            tileset_stride=STRIDE,
        })
        table.insert(shape_button_specs_selected, {
            chars=shape.button_chars,
            pens=COLOR_YELLOW,
            tileset=shape_tileset,
            tileset_offset=shape.texture_offset+(STRIDE*CHARS_PER_ROW),
            tileset_stride=STRIDE,
        })
    end

    local build_options = {
        {label='Walls', value='Cw'},
        {label='Reinforced Walls', value='CW'},
        {label='Floor', value='Cf'},
        {label='Fortification', value='CF'},
        {label='Ramps', value='Cr'},
        {label='None', value='`'},
    }

    self:addviews{
        widgets.ButtonGroup{
            view_id='mode',
            key='CUSTOM_F',
            key_back='CUSTOM_SHIFT_F',
            label='Designation:',
            options=mode_options,
            on_change=function() self.needs_update = true end,
            button_specs=mode_button_specs,
            button_specs_selected=mode_button_specs_selected,
        },
        widgets.ResizingPanel{
            autoarrange_subviews=true,
            subviews={
                widgets.Panel{
                    frame={h=2},
                    visible=function() return self.subviews.mode:getOptionValue().desig == 'i' end,
                    subviews={
                        widgets.CycleHotkeyLabel{
                            view_id='stairs_top_subtype',
                            frame={t=0, l=0},
                            key='CUSTOM_R',
                            label='   Top stair type:',
                            visible=function()
                                local bounds = self:get_view_bounds()
                                return bounds and bounds.z1 ~= bounds.z2 or false
                            end,
                            options={
                                {label='Auto', value='auto'},
                                {label='UpDown', value='i'},
                                {label='Down', value='j'},
                            },
                        },
                        widgets.CycleHotkeyLabel {
                            view_id='stairs_bottom_subtype',
                            frame={t=1, l=0},
                            key='CUSTOM_G',
                            label='Bottom Stair Type:',
                            visible=function()
                                local bounds = self:get_view_bounds()
                                return bounds and bounds.z1 ~= bounds.z2 or false
                            end,
                            options={
                                {label='Auto', value='auto'},
                                {label='UpDown', value='i'},
                                {label='Up', value='u'},
                            },
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='stairs_only_subtype',
                            frame={t=0, l=0},
                            key='CUSTOM_R',
                            label='Single level stair:',
                            visible=function()
                                local bounds = self:get_view_bounds()
                                return not bounds or bounds.z1 == bounds.z2
                            end,
                            options={
                                {label='Up', value='u'},
                                {label='UpDown', value='i'},
                                {label='Down', value='j'},
                            },
                        },
                    }
                },
                widgets.Panel{
                    frame={h=2},
                    visible=function() return self.subviews.mode:getOptionValue().mode == 'build' end,
                    subviews={
                        widgets.Label{
                            frame={t=0, l=0},
                            text={{tile=BUTTON_PEN_LEFT}, {tile=HELP_PEN_CENTER}, {tile=BUTTON_PEN_RIGHT}},
                            on_click=self:callback('show_help', CONSTRUCTION_HELP),
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='building_outer_tiles',
                            frame={t=0, l=4},
                            key='CUSTOM_R',
                            label='Outer Tiles:',
                            initial_option='Cw',
                            options=build_options,
                        },
                        widgets.CycleHotkeyLabel {
                            view_id='building_inner_tiles',
                            frame={t=1, l=4},
                            key='CUSTOM_G',
                            label='Inner Tiles:',
                            initial_option='Cf',
                            options=build_options,
                        },
                    },
                },
                widgets.CycleHotkeyLabel{
                    view_id='priority',
                    key='CUSTOM_SHIFT_P',
                    key_back='CUSTOM_P',
                    label='Priority:',
                    options={1, 2, 3, 4, 5, 6, 7},
                    initial_option=4,
                    visible=function()
                        local mode = self.subviews.mode:getOptionValue()
                        return mode.mode == 'dig' and mode.desig ~= 'x'
                    end,
                },
                widgets.HotkeyLabel{
                    key='CUSTOM_CTRL_X',
                    label='Clear entire z-level',
                    on_activate=function()
                        local map = df.global.world.map
                        quickfort.apply_blueprint{
                            mode='dig',
                            data=('x(%dx%d)'):format(map.x_count, map.y_count),
                            pos=xyz2pos(0, 0, df.global.window_z),
                        }
                    end,
                    visible=function()
                        local mode = self.subviews.mode:getOptionValue()
                        return mode.mode == 'dig' and mode.desig == 'x'
                    end,
                },
            },
        },
        widgets.Divider{
            frame={h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.ButtonGroup{
            view_id='shape',
            key='CUSTOM_Z',
            key_back='CUSTOM_SHIFT_Z',
            label='Shape:',
            options=shape_options,
            on_change=function(shape, prev_shape)
                self.needs_update = true
                if shape.max_points ~= prev_shape.max_points then
                    self:reset()
                end
            end,
            button_specs=shape_button_specs,
            button_specs_selected=shape_button_specs_selected,
        },
    }

    -- Currently only supports "bool" aka toggle and "plusminus" which creates
    -- a pair of HotKeyLabel's to increment/decrement a value
    -- Will need to update as needed to add more option types
    local shape_options_panel = widgets.ResizingPanel{
        autoarrange_subviews=true,
    }

    for _, shape in ipairs(shapes.all_shapes) do
        for _, option in pairs(shape.options) do
            if option.type ~= 'bool' then goto continue end
            shape_options_panel:addviews{
                widgets.ToggleHotkeyLabel{
                    frame={h=1},
                    auto_height=false,
                    key=option.key,
                    label=option.name..':',
                    initial_option=option.value,
                    enabled=option.enabled and function()
                        return shape.options[option.enabled[1]].value == option.enabled[2]
                    end or nil,
                    on_change=function(val)
                        option.value = val
                        self.needs_update = true
                    end,
                    visible=function() return self.subviews.shape:getOptionValue() == shape end,
                }
            }
            ::continue::
        end
        for _, option in pairs(shape.options) do
            if option.type ~= 'plusminus' then goto continue end
            shape_options_panel:addviews{
                widgets.Panel{
                    frame={h=1},
                    visible=function() return self.subviews.shape:getOptionValue() == shape end,
                    subviews={
                        widgets.HotkeyLabel{
                            frame={t=0, l=0, w=1},
                            key=option.keys[1],
                            key_sep='',
                            enabled=function()
                                if option.enabled then
                                    if shape.options[option.enabled[1]].value ~= option.enabled[2] then
                                        return false
                                    end
                                end
                                local min = utils.getval(option.min, shape)
                                return not min or option.value > min
                            end,
                            on_activate=function()
                                option.value = option.value - 1
                                self.needs_update = true
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={t=0, l=1},
                            key=option.keys[2],
                            label=function() return ('%s: %d'):format(option.name, option.value) end,
                            enabled=function()
                                if option.enabled then
                                    if shape.options[option.enabled[1]].value ~= option.enabled[2] then
                                        return false
                                    end
                                end
                                local max = utils.getval(option.max, shape)
                                return not max or option.value <= max
                            end,
                            on_activate=function()
                                option.value = option.value + 1
                                self.needs_update = true
                            end,
                        }
                    },
                },
            }
            ::continue::
        end
        if shape.invertable then
            shape_options_panel:addviews{
                widgets.ToggleHotkeyLabel{
                    key='CUSTOM_I',
                    label='Invert:',
                    initial_option=shape.invert,
                    on_change=function(val)
                        shape.invert = val
                        self.needs_update = true
                    end,
                    visible=function() return self.subviews.shape:getOptionValue() == shape end,
                },
            }
        end
    end

    local mirror_options = {
        {label='Off', value=1},
        {label='On (odd)', value=2},
        {label='On (even)', value=3}
    }

    self:addviews{
        shape_options_panel,
        widgets.Divider{
            frame={h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.ResizingPanel{
            autoarrange_subviews=true,
            subviews={
                widgets.HotkeyLabel {
                    key='CUSTOM_B',
                    label=function()
                        return self.placing_mark.active and 'Stop placing points' or 'Start placing more points'
                    end,
                    visible=function() return not self.subviews.shape:getOptionValue().max_points end,
                    enabled=function() return not self.prev_center end,
                    on_activate=function()
                        self.placing_mark.active = not self.placing_mark.active
                        self.placing_mark.index = self.placing_mark.active and #self.marks + 1 or nil
                        if not self.placing_mark.active then
                            table.remove(self.marks, #self.marks)
                        else
                            self.placing_mark.continue = true
                        end
                        self.needs_update=true
                    end,
                },
                widgets.HotkeyLabel {
                    key='CUSTOM_V',
                    label=function()
                        local msg='Add: '
                        local shape = self.subviews.shape:getOptionValue()
                        if #self.extra_points < #shape.extra_points then
                            return msg .. shape.extra_points[#self.extra_points + 1].label
                        end
                        return msg .. 'N/A'
                    end,
                    enabled=function()
                        return #self.marks > 1 and
                            #self.extra_points < #self.subviews.shape:getOptionValue().extra_points
                    end,
                    visible=function() return #self.subviews.shape:getOptionValue().extra_points > 0 end,
                    on_activate=function()
                        if not self.placing_mark.active then
                            self.placing_extra.active=true
                            self.placing_extra.index=#self.extra_points + 1
                        elseif #self.marks > 0 then
                            local mouse_pos = getMousePoint()
                            if mouse_pos then table.insert(self.extra_points, mouse_pos) end
                        end
                        self.needs_update = true
                    end,
                },
                widgets.Panel{
                    frame={h=1},
                    subviews={
                        widgets.HotkeyLabel{
                            frame={t=0, l=0, w=1},
                            key='STRING_A040',
                            key_sep='',
                            enabled=function() return #self.marks > 1 end,
                            on_activate=self:callback('on_transform', 'ccw'),
                        },
                        widgets.HotkeyLabel{
                            frame={t=0, l=1},
                            key='STRING_A041',
                            label='Rotate',
                            auto_width=true,
                            enabled=function() return #self.marks > 1 end,
                            on_activate=self:callback('on_transform', 'cw'),
                        },
                        widgets.HotkeyLabel{
                            frame={t=0, l=14, w=1},
                            key='STRING_A095',
                            key_sep='',
                            enabled=function() return #self.marks > 1 end,
                            on_activate=self:callback('on_transform', 'flipv'),
                        },
                        widgets.HotkeyLabel {
                            frame={t=0, l=15},
                            key='STRING_A061',
                            label='Flip',
                            auto_width=true,
                            enabled=function() return #self.marks > 1 end,
                            on_activate=self:callback('on_transform', 'fliph'),
                        },
                    }
                },
                widgets.HotkeyLabel{
                    key='CUSTOM_M',
                    visible=function() return self.subviews.shape:getOptionValue().can_mirror end,
                    label=function()
                        if not self.placing_mirror and not self.mirror_point then
                            return 'Mirror across axis'
                        else
                            return 'Cancel mirror'
                        end
                    end,
                    enabled=function()
                        if #self.marks < 2 then return false end
                        return not self.placing_extra.active and
                            not self.placing_mark.active and not self.prev_center
                    end,
                    on_activate=function()
                        if not self.mirror_point then
                            self.placing_mark.active = false
                            self.placing_extra.active = false
                            self.placing_extra.active = false
                            self.placing_mirror = true
                        else
                            self.placing_mirror = false
                            self.mirror_point = nil
                        end
                        self.needs_update = true
                    end
                },
                widgets.CycleHotkeyLabel {
                    view_id='mirror_horiz_label',
                    frame={l=1},
                    key='CUSTOM_SHIFT_J',
                    label='Mirror horizontal: ',
                    options=mirror_options,
                    on_change=function() self.needs_update = true end,
                    visible=function() return self.placing_mirror or self.mirror_point end,
                },
                widgets.CycleHotkeyLabel {
                    view_id='mirror_diag_label',
                    frame={l=1},
                    key='CUSTOM_SHIFT_O',
                    label='Mirror diagonal: ',
                    options=mirror_options,
                    on_change=function() self.needs_update = true end,
                    visible=function() return self.placing_mirror or self.mirror_point end,
                },
                widgets.CycleHotkeyLabel {
                    view_id='mirror_vert_label',
                    frame={l=1},
                    key='CUSTOM_SHIFT_K',
                    label='Mirror vertical: ',
                    options=mirror_options,
                    on_change=function() self.needs_update = true end,
                    visible=function() return self.placing_mirror or self.mirror_point end,
                },
                widgets.HotkeyLabel {
                    frame={l=1},
                    key='CUSTOM_SHIFT_M',
                    label='Commit mirror changes',
                    on_activate=function()
                        self.marks = self:get_mirrored_points(self.marks)
                        self.mirror_point = nil
                        self.needs_update = true
                    end,
                    visible=function() return self.placing_mirror or self.mirror_point end,
                },
                widgets.HotkeyLabel {
                    key='CUSTOM_X',
                    label='Reset',
                    enabled=function() return #self.marks > 0 or #self.extra_points > 0 end,
                    on_activate=self:callback('reset'),
                },
            }
        },
        widgets.Panel{
            frame={b=0},
            subviews={
                widgets.Panel{
                    frame={t=0, b=3},
                    frame_style=gui.FRAME_INTERIOR,
                    subviews={
                        widgets.Panel{
                            -- area expands with window
                            frame={t=0, b=2},
                            autoarrange_subviews=true,
                            autoarrange_gap=1,
                            subviews={
                                widgets.WrappedLabel{
                                    text_to_wrap=self:callback('get_action_text'),
                                    text_pen=COLOR_YELLOW,
                                },
                                widgets.WrappedLabel{
                                    text_to_wrap=self:callback('get_area_text'),
                                },
                                widgets.WrappedLabel{
                                    view_id='mark_text',
                                    text_to_wrap=self:callback('get_mark_text'),
                                },
                            },
                        },
                        widgets.HotkeyLabel{
                            frame={b=0, l=0},
                            key='SELECT',
                            label='Commit shape to the map',
                            enabled=function() return #self.marks >= self.subviews.shape:getOptionValue().min_points end,
                            on_activate=function()
                                self:commit()
                                self.needs_update=true
                            end,
                        },
                    },
                },
                widgets.ToggleHotkeyLabel{
                    view_id='show_guides',
                    frame={b=1, l=0},
                    key='CUSTOM_SHIFT_G',
                    label='Show alignment guides:',
                    initial_option=true,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='autocommit',
                    frame={b=0, l=0},
                    key='CUSTOM_ALT_C',
                    label='Auto-commit on click:',
                    initial_option=false,
                },
            },
        },
    }
end

function Design:reset()
    self.needs_update = true
    self.marks = {}
    self.extra_points = {}
    self.placing_extra = {active=false, index=nil}
    self.placing_mark = {active=true, index=1, continue=true}
    self.placing_mirror = false
    self.mirror = {horizontal=false, vertical=false}
    self.prev_center = nil
    self.start_center = nil
end

function Design:get_action_text()
    local text = ''
    if self.marks[2] and self.placing_mark.active then
        text = 'Click to place the point'
    elseif not self.marks[2] then
        text = 'Click to place the first point'
    elseif not self.placing_extra.active and not self.prev_center then
        text = 'Move any draggable points'
    elseif self.placing_extra.active then
        text = 'Place any extra points'
    elseif self.prev_center then
        text = 'Move the center point'
    else
        text = 'Move any draggable points'
    end
    return text .. ' with the mouse. Use right-click to dismiss points in order.'
end

function Design:get_area_text()
    local bounds = self:get_view_bounds()
    local label = 'Area: '
    if not bounds then return label .. 'N/A' end
    local width = math.abs(bounds.x2 - bounds.x1) + 1
    local height = math.abs(bounds.y2 - bounds.y1) + 1
    local depth = math.abs(bounds.z2 - bounds.z1) + 1
    local tiles = self.subviews.shape:getOptionValue().num_tiles * depth
    local plural = tiles == 1 and '' or 's'
    return label .. ('%dx%dx%d (%d tile%s)'):format(width, height, depth, tiles, plural)
end

function Design:get_mark_text()
    local label_text = {}
    local marks = self.marks
    local num_marks = #marks

    if num_marks >= 1 then
        local first_mark = marks[1]
        table.insert(label_text, ('First Mark (%d): %d, %d, %d')
            :format(1, first_mark.x, first_mark.y, first_mark.z))
    end

    if num_marks > 1 then
        local last_index = num_marks - (self.placing_mark.active and 1 or 0)
        local last_mark = marks[last_index]
        if last_mark then
            table.insert(label_text, ('Last Mark (%d): %d, %d, %d')
                :format(last_index, last_mark.x, last_mark.y, last_mark.z))
        end
    end

    local mouse_pos = getMousePoint()
    if mouse_pos then
        table.insert(label_text, ('Mouse: %d, %d, %d'):format(mouse_pos.x, mouse_pos.y, mouse_pos.z))
    end

    local mirror = self.mirror_point
    if mirror then
        table.insert(label_text, ('Mirror Point: %d, %d, %d'):format(mirror.x, mirror.y, mirror.z))
    end

    return label_text
end

-- Check to see if we're moving a point, or some change was made that implies we need to update the shape
-- This stops us needing to update the shape geometery every frame which can tank FPS
function Design:shape_needs_update()
    if self.needs_update then return true end

    local mouse_pos = getMousePoint()
    if mouse_pos then
        local mouse_moved = not self.last_mouse_point and mouse_pos or
            (self.last_mouse_point ~= mouse_pos)

        if self.placing_mark.active and mouse_moved then
            return true
        end

        if self.placing_extra.active and mouse_moved then
            return true
        end
    end

    return false
end

function Design:on_transform(val)
    local shape = self.subviews.shape:getOptionValue()
    local center = shape:get_center()

    -- Save mirrored points first
    if self.mirror_point then
        local points = self:get_mirrored_points(self.marks)
        self.marks = points
        self.mirror_point = nil
    end

    -- Transform marks
    for i, mark in ipairs(self.marks) do
        local x, y = mark.x, mark.y
        if val == 'cw' then
            x, y = center.x - (y - center.y), center.y + (x - center.x)
        elseif val == 'ccw' then
            x, y = center.x + (y - center.y), center.y - (x - center.x)
        elseif val == 'fliph' then
            x = center.x - (x - center.x)
        elseif val == 'flipv' then
            y = center.y - (y - center.y)
        end
        self.marks[i] = Point{x=math.floor(x + 0.5), y=math.floor(y + 0.5), z=self.marks[i].z}
    end

    -- Transform extra points
    for i, point in ipairs(self.extra_points) do
        local x, y = point.x, point.y
        if val == 'cw' then
            x, y = center.x - (y - center.y), center.y + (x - center.x)
        elseif val == 'ccw' then
            x, y = center.x + (y - center.y), center.y - (x - center.x)
        elseif val == 'fliph' then
            x = center.x - (x - center.x)
        elseif val == 'flipv' then
            y = center.y - (y - center.y)
        end
        self.extra_points[i] = Point{x=math.floor(x + 0.5), y=math.floor(y + 0.5), z=self.extra_points[i].z}
    end

    -- Calculate center point after transformation
    shape:update(self.marks, self.extra_points)
    local new_center = shape:get_center()

    -- Calculate delta between old and new center points
    local delta = center - new_center

    -- Adjust marks and extra points based on delta
    for i, mark in ipairs(self.marks) do
        self.marks[i] = mark + Point{x=delta.x, y=delta.y, z=0}
    end

    for i, point in ipairs(self.extra_points) do
        self.extra_points[i] = point + Point{x=delta.x, y=delta.y, z=0}
    end

    self.needs_update = true
end

function Design:get_view_bounds()
    if #self.marks == 0 then return nil end

    local min_x = self.marks[1].x
    local max_x = self.marks[1].x
    local min_y = self.marks[1].y
    local max_y = self.marks[1].y
    local min_z = self.marks[1].z
    local max_z = self.marks[1].z

    local marks_plus_next = copyall(self.marks)
    local mouse_pos = getMousePoint()
    if mouse_pos then
        if not self.placing_mark.active then
            -- only get the z coord from the mouse position
            mouse_pos.x = self.marks[1].x
            mouse_pos.y = self.marks[1].y
        end
        table.insert(marks_plus_next, mouse_pos)
    end

    for _, mark in ipairs(marks_plus_next) do
        min_x = math.min(min_x, mark.x)
        max_x = math.max(max_x, mark.x)
        min_y = math.min(min_y, mark.y)
        max_y = math.max(max_y, mark.y)
        min_z = math.min(min_z, mark.z)
        max_z = math.max(max_z, mark.z)
    end

    return { x1 = min_x, y1 = min_y, z1 = min_z, x2 = max_x, y2 = max_y, z2 = max_z }
end

-- TODO Function is too long
function Design:onRenderFrame(dc, rect)
    self.subviews.mark_text:updateLayout()
    Design.super.onRenderFrame(self, dc, rect)

    local mouse_pos = getMousePoint()
    local shape = self.subviews.shape:getOptionValue()

    if self.placing_mark.active and self.placing_mark.index and mouse_pos then
        self.marks[self.placing_mark.index] = mouse_pos
    end

    -- Set the pos of the currently moving extra point
    if self.placing_extra.active then
        self.extra_points[self.placing_extra.index] = mouse_pos
    end

    if self.placing_mirror and mouse_pos then
        if not self.mirror_point or (mouse_pos ~= self.mirror_point) then
            self.needs_update = true
        end
        self.mirror_point = mouse_pos
    end

    -- Check if moving center, if so shift the shape by the delta between the previous and current points
    if self.prev_center and
        ((shape.basic_shape and #self.marks == shape.max_points)
            or (not shape.basic_shape and not self.placing_mark.active))
        and mouse_pos and (self.prev_center ~= mouse_pos)
    then
        self.needs_update = true
        local transform = mouse_pos - self.prev_center

        transform.z = transform.z or mouse_pos.z

        for i, mark in ipairs(self.marks) do
            mark.z = mark.z or transform.z
            self.marks[i] = mark + transform
        end

        for i, point in ipairs(self.extra_points) do
            self.extra_points[i] = point + transform
        end

        if self.mirror_point then
            self.mirror_point = self.mirror_point + transform
        end

        self.prev_center = mouse_pos
    end

    -- Set main points
    local points = copyall(self.marks)

    if self.mirror_point then
        points = self:get_mirrored_points(points)
    end

    if self:shape_needs_update() then
        shape:update(points, self.extra_points)
        self.last_mouse_point = mouse_pos
        self.needs_update = false
        self:updateLayout()
        plugin.design_clear_shape(shape.arr)
    end

    -- Generate bounds based on the shape's dimensions
    local bounds = self:get_view_bounds()
    if bounds then
        local top_left, bot_right = shape:get_view_dims(self.extra_points, self.mirror_point)
        if not top_left or not bot_right then return end
        bounds.x1 = top_left.x
        bounds.x2 = bot_right.x
        bounds.y1 = top_left.y
        bounds.y2 = bot_right.y
    end

    -- Show mouse guidelines
    if self.subviews.show_guides:getOptionValue() and mouse_pos and not self:getMouseFramePos() then
        local map_x, map_y = dfhack.maps.getTileSize()
        local horiz_bounds = {x1=0, x2=map_x, y1=mouse_pos.y, y2=mouse_pos.y, z1=mouse_pos.z, z2=mouse_pos.z}
        guidm.renderMapOverlay(function() return guide_tile_pen end, horiz_bounds)
        local vert_bounds = {x1=mouse_pos.x, x2=mouse_pos.x, y1=0, y2=map_y, z1=mouse_pos.z, z2=mouse_pos.z}
        guidm.renderMapOverlay(function() return guide_tile_pen end, vert_bounds)
    end

    -- Show Mirror guidelines
    if self.mirror_point then
        local mirror_horiz_value = self.subviews.mirror_horiz_label:getOptionValue()
        local mirror_diag_value = self.subviews.mirror_diag_label:getOptionValue()
        local mirror_vert_value = self.subviews.mirror_vert_label:getOptionValue()

        local map_x, map_y, _ = dfhack.maps.getTileSize()

        if mirror_horiz_value ~= 1 or mirror_diag_value ~= 1 then
            local horiz_bounds = {
                x1 = 0, x2 = map_x,
                y1 = self.mirror_point.y, y2 = self.mirror_point.y,
                z1 = self.mirror_point.z, z2 = self.mirror_point.z
            }
            guidm.renderMapOverlay(function() return mirror_guide_pen end, horiz_bounds)
        end

        if mirror_vert_value ~= 1 or mirror_diag_value ~= 1 then
            local vert_bounds = {
                x1=self.mirror_point.x, x2=self.mirror_point.x,
                y1=0, y2=map_y,
                z1=self.mirror_point.z, z2=self.mirror_point.z,
            }
            guidm.renderMapOverlay(function() return mirror_guide_pen end, vert_bounds)
        end
    end

    plugin.design_draw_shape(shape.arr)

    if #self.marks >= shape.min_points and shape.basic_shape then
        local shape_top_left, shape_bot_right = shape:get_point_dims()
        local drag_points = {
            Point{x=shape_top_left.x, y=shape_top_left.y},
            Point{x=shape_bot_right.x, y=shape_bot_right.y},
            Point{x=shape_top_left.x, y=shape_bot_right.y},
            Point{x=shape_bot_right.x, y=shape_top_left.y}
        }
        plugin.design_draw_points({drag_points, 'drag_point'})
    else
        plugin.design_draw_points({self.marks, 'drag_point'})
    end

    plugin.design_draw_points({self.extra_points, 'extra_point'})

    if (shape.basic_shape and #self.marks == shape.max_points) or
        (not shape.basic_shape and not self.placing_mark.active and #self.marks > 0) then
        plugin.design_draw_points({{shape:get_center()}, 'extra_point'})
    end
    plugin.design_draw_points({{self.mirror_point}, 'extra_point'})
end

function Design:onInput(keys)
    if Design.super.onInput(self, keys) then
        return true
    end

    local shape = self.subviews.shape:getOptionValue()

    if keys.LEAVESCREEN or keys._MOUSE_R then
        if dfhack.internal.getModifiers().shift then
            -- shift right click always closes immediately
            return false
        end

        -- Close help window if open
        if view.help_window.visible then self:dismiss_help() return true end

        -- If center dragging, put the shape back to the original center
        if self.prev_center then
            local transform = self.start_center - self.prev_center

            for i, mark in ipairs(self.marks) do
                self.marks[i] = mark + transform
            end

            for i, point in ipairs(self.extra_points) do
                self.extra_points[i] = point + transform
            end

            self.prev_center = nil
            self.start_center = nil
            self.needs_update = true
            return true
        end

        -- If extra points, clear them and return
        if #self.extra_points > 0 or self.placing_extra.active then
            self.extra_points = {}
            self.placing_extra.active = false
            self.prev_center = nil
            self.start_center = nil
            self.placing_extra.index = 0
            self.needs_update = true
            return true
        end

        -- If marks are present, pop the last mark
        if #self.marks > 1 then
            self.placing_mark.index = #self.marks - ((self.placing_mark.active) and 1 or 0)
            self.placing_mark.active = true
            self.needs_update = true
            table.remove(self.marks, #self.marks)
        else
            -- nothing left to remove, so dismiss
            self.parent_view:dismiss()
        end

        return true
    end

    local pos = nil
    if keys._MOUSE_L and not self:getMouseFramePos() then
        pos = getMousePoint()
        if not pos then return true end
        guidm.setCursorPos(dfhack.gui.getMousePos())
    elseif keys.SELECT then
        pos = Point(guidm.getCursorPos())
    end

    if keys._MOUSE_L and pos then
        self.needs_update = true

        -- TODO Refactor this a bit
        if shape.max_points and #self.marks == shape.max_points and self.placing_mark.active then
            self.marks[self.placing_mark.index] = pos
            self.placing_mark.index = self.placing_mark.index + 1
            self.placing_mark.active = false
            -- The statement after the or is to allow the 1x1 special case for easy doorways
            if self.subviews.autocommit:getOptionValue() or (self.marks[1] == self.marks[2]) then
                self:commit()
            end
        elseif not self.placing_extra.active and self.placing_mark.active then
            self.marks[self.placing_mark.index] = pos
            if self.placing_mark.continue then
                self.placing_mark.index = self.placing_mark.index + 1
            else
                self.placing_mark.index = nil
                self.placing_mark.active = false
            end
        elseif self.placing_extra.active then
            self.placing_extra.active = false
        elseif self.placing_mirror then
            self.mirror_point = pos
            self.placing_mirror = false
        else
            -- Clicking center point
            if #self.marks > 0 then
                local center = shape:get_center()
                if pos == center and not self.prev_center then
                    self.start_center = pos
                    self.prev_center = pos
                    return true
                elseif self.prev_center then
                    --If there was no movement presume user wanted to click the mark underneath instead and let the flow through.
                    if pos == self.start_center then
                        self.start_center = nil
                        self.prev_center = nil
                    else
                    -- Since it moved let's just drop the shape here.
                        self.start_center = nil
                        self.prev_center = nil
                        return true
                    end
                end
            end

            if shape.basic_shape and #self.marks == shape.max_points then
                -- Clicking a corner of a basic shape
                local shape_top_left, shape_bot_right = shape:get_point_dims()
                local corner_drag_info = {
                    { pos = shape_top_left, opposite_x = shape_bot_right.x, opposite_y = shape_bot_right.y,
                        corner = 'nw' },
                    { pos = Point { x = shape_bot_right.x, y = shape_top_left.y }, opposite_x = shape_top_left.x,
                        opposite_y = shape_bot_right.y, corner = 'ne' },
                    { pos = Point { x = shape_top_left.x, y = shape_bot_right.y }, opposite_x = shape_bot_right.x,
                        opposite_y = shape_top_left.y, corner = 'sw' },
                    { pos = shape_bot_right, opposite_x = shape_top_left.x, opposite_y = shape_top_left.y,
                        corner = 'se' }
                }

                for _, info in ipairs(corner_drag_info) do
                    if pos == info.pos and shape.drag_corners[info.corner] then
                        self.marks[1] = Point { x = info.opposite_x, y = info.opposite_y, z = self.marks[1].z }
                        table.remove(self.marks, 2)
                        self.placing_mark.active = true
                        self.placing_mark.index = 2
                        break
                    end
                end
            else
                for i, point in ipairs(self.marks) do
                    if pos == point then
                        self.placing_mark = { active = true, index = i, continue = false }
                    end
                end
            end

            -- Clicking an extra point
            for i = 1, #self.extra_points do
                if pos == self.extra_points[i] then
                    self.placing_extra = { active = true, index = i }
                    return true
                end
            end

            if self.mirror_point == pos then
                self.placing_mirror = true
            end
        end

        return true
    end

    if guidm.getMapKey(keys) then
        self.needs_update = true
    end
end

-- Put any special logic for designation type here
-- Right now it's setting the stair type based on the z-level
-- Fell through, pass through the option directly from the options value
function Design:get_designation(point)
    local mode = self.subviews.mode:getOptionValue()

    local view_bounds = self:get_view_bounds()
    local shape = self.subviews.shape:getOptionValue()
    local top_left, bot_right = shape:get_true_dims()

    -- Stairs
    if mode.desig == 'i' then
        local stairs_top_type = self.subviews.stairs_top_subtype:getOptionValue()
        local stairs_bottom_type = self.subviews.stairs_bottom_subtype:getOptionValue()
        local stairs_only_type = self.subviews.stairs_only_subtype:getOptionValue()
        if point.z == 0 then
            if view_bounds.z1 == view_bounds.z2 then
                -- Single layer staircase
                return stairs_only_type
            else
                -- Bottom of multi-level staircase
                return stairs_bottom_type == 'auto' and 'u' or stairs_bottom_type
        end
        elseif view_bounds and point.z == math.abs(view_bounds.z1 - view_bounds.z2) then
            local pos = Point{x=view_bounds.x1, y=view_bounds.y1, z=view_bounds.z1} + point
            local tile_type = dfhack.maps.getTileType(xyz2pos(pos.x, pos.y, pos.z))
            local tile_shape = tile_type and df.tiletype.attrs[tile_type].shape or nil
            local designation = dfhack.maps.getTileFlags(xyz2pos(pos.x, pos.y, pos.z))

            -- If top of the view_bounds is down stair, 'auto' should change it to up/down to match vanilla stair logic
            local up_or_updown_dug = (
                tile_shape == df.tiletype_shape.STAIR_DOWN or tile_shape == df.tiletype_shape.STAIR_UPDOWN)
            local up_or_updown_desig = designation and (designation.dig == df.tile_dig_designation.UpStair or
                designation.dig == df.tile_dig_designation.UpDownStair)

            if stairs_top_type == 'auto' then
                return (up_or_updown_desig or up_or_updown_dug) and 'i' or 'j'
            else
                return stairs_top_type
            end
        else
            return 'i'
        end
    elseif mode.desig == 'b' then
        local building_outer_tiles = self.subviews.building_outer_tiles:getOptionValue()
        local building_inner_tiles = self.subviews.building_inner_tiles:getOptionValue()
        local darr = { { 1, 1 }, { 1, 0 }, { 0, 1 }, { 0, 0 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 }, { -1, 1 } }

        -- If not completed surrounded, then use outer tile
        for i, d in ipairs(darr) do
            if not (shape:get_point(top_left.x + point.x + d[1], top_left.y + point.y + d[2])) then
                return building_outer_tiles
            end
        end

        -- Is inner tile
        return building_inner_tiles
    end

    return mode.desig
end

-- Commit the shape using quickfort API
function Design:commit()
    local data = {}
    local shape = self.subviews.shape:getOptionValue()
    local prio = self.subviews.priority:getOptionValue()
    local top_left, bot_right = shape:get_true_dims()
    local view_bounds = self:get_view_bounds()

    -- Means mo marks set
    if not view_bounds then return end

    local mode = self.subviews.mode:getOptionValue().mode
    -- Generates the params for quickfort API
    local function generate_params(grid, position)
        -- local top_left, bot_right = shape:get_true_dims()
        for zlevel = 0, math.abs(view_bounds.z1 - view_bounds.z2) do
            data[zlevel] = {}
            for row = 0, math.abs(bot_right.y - top_left.y) do
                data[zlevel][row] = {}
                for col = 0, math.abs(bot_right.x - top_left.x) do
                    if grid[col] and grid[col][row] then
                        local desig = self:get_designation(Point{x=col, y=row, z=zlevel})
                        if desig ~= '`' then
                            data[zlevel][row][col] =
                            desig .. (mode ~= 'build' and tostring(prio) or '')
                        end
                    end
                end
            end
        end

        return {
            data = data,
            pos = position,
            mode = mode,
        }
    end

    local start = {
        x = top_left.x,
        y = top_left.y,
        z = math.min(view_bounds.z1, view_bounds.z2),
    }

    local grid = shape:transform(0, 0)

    -- Special case for 1x1 to ease doorway marking
    if top_left == bot_right then
        grid = {}
        grid[0] = {}
        grid[0][0] = true
    end

    local params = generate_params(grid, start)
    quickfort.apply_blueprint(params)

    -- Only clear points if we're autocommit, or if we're doing a complex shape and still placing
    local autocommit = self.subviews.autocommit:getOptionValue()
    if (autocommit and shape.basic_shape) or
        (not shape.basic_shape and
            (self.placing_mark.active or (autocommit and shape.max_points == #self.marks))) then
        self.marks = {}
        self.placing_mark = { active = true, index = 1, continue = true }
        self.placing_extra = { active = false, index = nil }
        self.extra_points = {}
        self.prev_center = nil
        self.start_center = nil
    end

    self.needs_update = true
end

function Design:get_mirrored_points(points)
    local mirror_horiz_value = self.subviews.mirror_horiz_label:getOptionValue()
    local mirror_diag_value = self.subviews.mirror_diag_label:getOptionValue()
    local mirror_vert_value = self.subviews.mirror_vert_label:getOptionValue()

    local mirrored_points = {}
    for i = #points, 1, -1 do
        local point = points[i]
        -- 1 maps to 'Off'
        if mirror_horiz_value ~= 1 then
            local mirrored_y = self.mirror_point.y + ((self.mirror_point.y - point.y))

            -- if Mirror (even), then increase mirror amount by 1
            if mirror_horiz_value == 3 then
                if mirrored_y > self.mirror_point.y then
                    mirrored_y = mirrored_y + 1
                else
                    mirrored_y = mirrored_y - 1
                end
            end

            table.insert(mirrored_points, Point { z = point.z, x = point.x, y = mirrored_y })
        end
    end

    for i, point in ipairs(points) do
        if mirror_diag_value ~= 1 then
            local mirrored_y = self.mirror_point.y + ((self.mirror_point.y - point.y))
            local mirrored_x = self.mirror_point.x + ((self.mirror_point.x - point.x))

            -- if Mirror (even), then increase mirror amount by 1
            if mirror_diag_value == 3 then
                if mirrored_y > self.mirror_point.y then
                    mirrored_y = mirrored_y + 1
                    mirrored_x = mirrored_x + 1
                else
                    mirrored_y = mirrored_y - 1
                    mirrored_x = mirrored_x - 1
                end
            end

            table.insert(mirrored_points, Point { z = point.z, x = mirrored_x, y = mirrored_y })
        end
    end

    for i = #points, 1, -1 do
        local point = points[i]
        if mirror_vert_value ~= 1 then
            local mirrored_x = self.mirror_point.x + ((self.mirror_point.x - point.x))

            -- if Mirror (even), then increase mirror amount by 1
            if mirror_vert_value == 3 then
                if mirrored_x > self.mirror_point.x then
                    mirrored_x = mirrored_x + 1
                else
                    mirrored_x = mirrored_x - 1
                end
            end

            table.insert(mirrored_points, Point { z = point.z, x = mirrored_x, y = point.y })
        end
    end

    for i, point in ipairs(mirrored_points) do
        table.insert(points, Point(mirrored_points[i]))
    end

    return points
end

function Design:show_help(text)
    self.parent_view.help_window.message = text
    self.parent_view.help_window.visible = true
    self.parent_view:updateLayout()
end

function Design:dismiss_help()
    self.parent_view.help_window.visible = false
end

function Design:get_anchor_pos()
    -- TODO: return a pos when the player is actively drawing
    return nil
end

--
-- DesignScreen
--

DesignScreen = defclass(DesignScreen, gui.ZScreen)
DesignScreen.ATTRS {
    focus_path='design',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
}

function DesignScreen:init()
    self.design_window = Design{}
    self.help_window = HelpWindow{visible=false}
    self:addviews{
        self.design_window,
        self.help_window,
        widgets.DimensionsTooltip{
            get_anchor_pos_fn=self.design_window:callback('get_anchor_pos'),
        },
    }
    if SHOW_DEBUG_WINDOW then
        self.debug_window = DesignDebugWindow{design_window=self.design_window}
        self:addviews{self.debug_window}
    end
end

function DesignScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then return end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

view = view and view:raise() or DesignScreen{}:show()

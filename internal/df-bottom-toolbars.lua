-- Provide data-driven locations for the DF toolbars at the bottom of the
-- screen. Not quite as nice as getting the data from DF directly, but better
-- than hand-rolling calculations for each "interesting" button.

--[[

DF bottom toolbars module
-------------------------

This module provides a (black box) reproduction of how DF places its toolbar
buttons at the bottom of the screen. Several DFHack overlay UI elements are
placed with respect to (parts of) the toolbars that DF puts at the bottom of the
screen.

The three primary toolbars are placed flush left, "centered", and flush right in
the interface area (which varies based on configured interface percentage and
the width (in UI tiles) of the DF window itself).

In narrow interfaces areas (114-130 UI columns) the center toolbar isn't exactly
centered to avoid overlapping with the left toolbar. Furthermore the center
toolbar has secondary toolbars that can be opened above it. These secondary
toolbars are nominally opened directly above the button for the "tool" they
belong to. If there is not room for a secondary toolbar placed above its
"opening button", it will be pushed to the left to fit (even when most of the
width of the toolbar is currently hidden because its advanced options are
disabled). For example, the following secondary toolbars are "pushed left" when
the interface area is narrow enough:

* dig: 114-175 UI columns
* chop, gather: 114-120 UI columns
* smooth, 114-151 UI columns
* traffic, 114-195 UI columns

This nearly-centering and width-constrained placement can be derived manually
for specific toolbars, but this often results in using the above-mentioned
widths as "magic numbers". Instead of internalizing these values, this module
implicitly derives them based on the static toolbar widths and dynamic interface
sizes (combined with a few directly observable "padding" widths and a specific
rounding method used for the center toolbar).

The module provides the following fields:

* ``MINIMUM_INTERFACE_RECT``

  The UI tile dimensions (from ``gui.mkdims_wh``) of the minimum-size DF window:
  114x46 UI tiles.

* ``TOOLBAR_HEIGHT``

  The UI tile height of the primary toolbars at the bottom of the DF window.

* ``SECONDARY_TOOLBAR_HEIGHT``

  The UI tile height of the secondary toolbars that are sometimes placed above
  the primary toolbar.

* ``fort``

  The static "definitions" of the fortress mode toolbars. Each of
  ``fort.right``, ``fort.center``, and ``fort.left`` has the following fields:

  * ``toolbar.width``

    The overall width of the DF toolbar.

  * ``toolbar.buttons`` table that can be indexed by "button names" provided by
    this module:

    * ``fort.left.buttons`` has ``citizens``, ``tasks``, ``places``, ``labor``, ``orders``,
    ``nobles``, ``objects``, and ``justice`` buttons

    * ``fort.center.buttons`` has ``dig``, ``chop``, ``gather``, ``smooth``, ``erase``,
    ``build``, ``stockpile``, ``zone``, ``burrow``, ``cart``, ``traffic``, and
    ``mass_designation`` buttons

    * ``fort.right.buttons`` has ``squads``, and ``world`` buttons

    Each button (``toolbar.buttons[name]``) has two fields:

    * ``button.offset``

      The offset of the button from the left-most column of the toolbar.

    * ``button.width``

      The width of the button in UI tiles.

  * ``toolbar:frame(interface_rect)`` method

    The ``interface_rect`` parameter must have ``width`` and ``height`` fields,
    and should represent the size of an interface area (e.g., from the
    ``parent_rect`` parameter given to a non-fullscreen overlay's
    ``updateLayout`` method, or directly from ``gui.get_interface_rect()``).

    Returns a Widget-style "frame" table that has fields for the offsets (``l``,
    ``r``, ``t``, ``b``) and size (``w``, ``h``) of the toolbar when it is
    displayed in an interface area of ``interface_rect`` size.

    The interface area left-offset of a specific button can be found by adding a
    toolbar's frame's ``l`` field and the ``offset`` of one of its buttons::

      local tb = reqscript('internal/df-bottom-toolbars')
      ...
      local right = tb.fort.right
      local squads_offset = right:frame(interface_size) + right.buttons.squads.offset

  The ``center`` definition has an additional field and method:

  * ``fort.center.secondary_toolbars``

    Provides the definitions of secondary toolbar for several "tools": ``dig``,
    ``chop``, ``gather``, ``smooth``, ``erase``, ``stockpile``,
    ``stockpile_paint``, ``burrow_paint``, ``traffic``, and
    ``mass_designation``. See the complete list of secondary toolbar buttons in
    the module's code.

    The definition of a secondary toolbar uses the same ``width`` & ``buttons``
    fields as the primary toolbars.

  * ``fort.center:secondary_toolbar_frame(interface_rect, secondary_name)``

    Provides the frame (like ``toolbar:frame()``) for the specified secondary
    toolbar when displayed in the specified interface size.

    Again, a button's ``offset`` can be combined with its secondary toolbar's
    frame's ``l`` to find the location of a specific button::

      local tb = reqscript('internal/df-bottom-toolbars')
      ...
      local center = tb.fort.center
      local dig_advanced_offset = center:secondary_toolbar_frame(interface_size, 'dig')
          + center.secondary_toolbars.dig.advanced_toggle.offset

]]

--@module = true

TOOLBAR_HEIGHT = 3
SECONDARY_TOOLBAR_HEIGHT = 3
MINIMUM_INTERFACE_RECT = require('gui').mkdims_wh(0, 0, 114, 46)

---@generic T
---@param sequences T[][]
---@return T[]
local function concat_sequences(sequences)
    local collected = {}
    for _, sequence in ipairs(sequences) do
        table.move(sequence, 1, #sequence, #collected + 1, collected)
    end
    return collected
end

---@alias NamedWidth table<string,integer> -- single entry, value is width
---@alias NamedOffsets table<string,integer> -- multiple entries, values are offsets
---@alias Button { offset: integer, width: integer }
---@alias NamedButtons table<string,Button> -- multiple entries

---@class Toolbar
---@field button_offsets NamedOffsets deprecated, use buttons[name].offset
---@field buttons NamedButtons
---@field width integer

---@class Toolbar.Widget.frame: widgets.Widget.frame
---@field l integer Gap between the left edge of the frame and the parent.
---@field t integer Gap between the top edge of the frame and the parent.
---@field r integer Gap between the right edge of the frame and the parent.
---@field b integer Gap between the bottom edge of the frame and the parent.
---@field w integer Width
---@field h integer Height

---@param widths NamedWidth[] single-name entries only!
---@return Toolbar
local function button_widths_to_toolbar(widths)
    local offsets = {}
    local buttons = {}
    local offset = 0
    for _, ww in ipairs(widths) do
        local name, w = next(ww)
        if name then
            if not name:startswith('_') then
                offsets[name] = offset
                buttons[name] = { offset = offset, width = w }
            end
            offset = offset + w
        end
    end
    return { button_offsets = offsets, buttons = buttons, width = offset }
end

---@param buttons string[]
---@return NamedWidth[]
local function buttons_to_widths(buttons)
    local widths = {}
    for _, button_name in ipairs(buttons) do
        table.insert(widths, { [button_name] = 4 })
    end
    return widths
end

---@param buttons string[]
---@return Toolbar
local function buttons_to_toolbar(buttons)
    return button_widths_to_toolbar(buttons_to_widths(buttons))
end

-- Fortress mode toolbar definitions
fort = {}

---@class LeftToolbar : Toolbar
fort.left = buttons_to_toolbar{
    'citizens', 'tasks', 'places', 'labor',
    'orders', 'nobles', 'objects', 'justice',
}

---@param interface_rect gui.dimension
---@return Toolbar.Widget.frame
function fort.left:frame(interface_rect)
    return {
        l = 0,
        w = self.width,
        r = interface_rect.width - self.width,

        t = interface_rect.height - TOOLBAR_HEIGHT,
        h = TOOLBAR_HEIGHT,
        b = 0,
    }
end

fort.left_center_gap_minimum = 7

---@class CenterToolbar: Toolbar
fort.center = button_widths_to_toolbar{
    { _left_border = 1 },
    { dig = 4 }, { chop = 4 }, { gather = 4 }, { smooth = 4 }, { erase = 4 },
    { _divider = 1 },
    { build = 4 }, { stockpile = 4 }, { zone = 4 },
    { _divider = 1 },
    { burrow = 4 }, { cart = 4 }, { traffic = 4 },
    { _divider = 1 },
    { mass_designation = 4 },
    { _right_border = 1 },
}

---@param interface_rect gui.dimension
---@return Toolbar.Widget.frame
function fort.center:frame(interface_rect)
    -- center toolbar is "centered" in interface area, but never closer to the
    -- left toolbar than fort.left_center_gap_minimum

    local interface_offset_centered = math.ceil((interface_rect.width - self.width + 1) / 2)
    local interface_offset_min = fort.left.width + fort.left_center_gap_minimum
    local interface_offset = math.max(interface_offset_min, interface_offset_centered)

    return {
        l = interface_offset,
        w = self.width,
        r = interface_rect.width - interface_offset - self.width,

        t = interface_rect.height - TOOLBAR_HEIGHT,
        h = TOOLBAR_HEIGHT,
        b = 0,
    }
end

---@alias CenterToolbarToolNames              'dig' | 'chop' | 'gather' | 'smooth' | 'erase' | 'build' | 'stockpile' |                     'zone' | 'burrow' |                   'cart' | 'traffic' | 'mass_designation'
---@alias CenterToolbarSecondaryToolbarNames  'dig' | 'chop' | 'gather' | 'smooth' | 'erase' |           'stockpile' | 'stockpile_paint' |                      'burrow_paint' |          'traffic' | 'mass_designation'

---@param interface_rect gui.dimension
---@param toolbar_name CenterToolbarSecondaryToolbarNames
---@return Toolbar.Widget.frame
function fort.center:secondary_toolbar_frame(interface_rect, toolbar_name)
    local secondary_toolbar = self.secondary_toolbars[toolbar_name] or
        dfhack.error('invalid toolbar name: ' .. toolbar_name)

    ---@type CenterToolbarToolNames
    local tool_name
    if toolbar_name == 'stockpile_paint' then
        tool_name = 'stockpile'
    elseif toolbar_name == 'burrow_paint' then
        tool_name = 'burrow'
    else
        tool_name = toolbar_name --[[@as CenterToolbarToolNames]]
    end
    local toolbar_offset = self:frame(interface_rect).l
    local toolbar_button = self.buttons[tool_name] or dfhack.error('invalid tool name: ' .. tool_name)

    -- Ideally, the secondary toolbar is positioned directly above the (main) toolbar button
    local ideal_offset = toolbar_offset + toolbar_button.offset

    -- In "narrow" interfaces conditions, a wide secondary toolbar (pretty much
    -- any tool that has "advanced" options) that was ideally positioned above
    -- its tool's button would extend past the right edge of the interface area.
    -- Such wide secondary toolbars are instead right justified with a bit of
    -- padding.

    -- padding necessary to line up width-constrained secondaries
    local secondary_padding = 5
    local width_constrained_offset = math.max(0, interface_rect.width - (secondary_toolbar.width + secondary_padding))

    -- Use whichever position is left-most.
    local l = math.min(ideal_offset, width_constrained_offset)
    return {
        l = l,
        w = secondary_toolbar.width,
        r = interface_rect.width - l - secondary_toolbar.width,

        t = interface_rect.height - TOOLBAR_HEIGHT - SECONDARY_TOOLBAR_HEIGHT,
        h = SECONDARY_TOOLBAR_HEIGHT,
        b = TOOLBAR_HEIGHT,
    }
end

---@type table<CenterToolbarSecondaryToolbarNames,Toolbar>
fort.center.secondary_toolbars = {
    dig = buttons_to_toolbar{
        'dig', 'stairs', 'ramp', 'channel', 'remove_construction', '_gap',
        'rectangle', 'draw', '_gap',
        'advanced_toggle', '_gap',
        'all', 'auto', 'ore_gem', 'gem', '_gap',
        'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', '_gap',
        'blueprint', 'blueprint_to_standard', 'standard_to_blueprint',
    },
    chop = buttons_to_toolbar{
        'chop', '_gap',
        'rectangle', 'draw', '_gap',
        'advanced_toggle', '_gap',
        'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', '_gap',
        'blueprint', 'blueprint_to_standard', 'standard_to_blueprint',
    },
    gather = buttons_to_toolbar{
        'gather', '_gap',
        'rectangle', 'draw', '_gap',
        'advanced_toggle', '_gap',
        'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', '_gap',
        'blueprint', 'blueprint_to_standard', 'standard_to_blueprint',
    },
    smooth = buttons_to_toolbar{
        'smooth', 'engrave', 'carve_track', 'carve_fortification', '_gap',
        'rectangle', 'draw', '_gap',
        'advanced_toggle', '_gap',
        'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', '_gap',
        'blueprint', 'blueprint_to_standard', 'standard_to_blueprint',
    },
    erase = buttons_to_toolbar{
        'rectangle',
        'draw',
    },
    -- build   -- completely different and quite variable
    stockpile = buttons_to_toolbar{ 'add_stockpile' },
    stockpile_paint = buttons_to_toolbar{
        'rectangle', 'draw', 'erase_toggle', 'remove',
    },
    -- zone    -- no secondary toolbar
    -- burrow -- no direct secondary toolbar
    burrow_paint = buttons_to_toolbar{
        'rectangle', 'draw', 'erase_toggle', 'remove',
    },
    -- cart    -- no secondary toolbar
    traffic = button_widths_to_toolbar(
        concat_sequences{ buttons_to_widths{
            'high', 'normal', 'low', 'restricted', '_gap',
            'rectangle', 'draw', '_gap',
            'advanced_toggle', '_gap',
        }, {
            { weight_which = 4 },
            { weight_slider = 26 },
            { weight_input = 6 },
        } }
    ),
    mass_designation = buttons_to_toolbar{
        'claim', 'forbid', 'dump', 'no_dump', 'melt', 'no_melt', 'hidden', 'visible', '_gap',
        'rectangle', 'draw',
    },
}

---@class RightToolbar: Toolbar
fort.right = buttons_to_toolbar{
    'squads', 'world',
}

---@param interface_rect gui.dimension
---@return Toolbar.Widget.frame
function fort.right:frame(interface_rect)
    return {
        l = interface_rect.width - self.width,
        w = self.width,
        r = 0,

        t = interface_rect.height - TOOLBAR_HEIGHT,
        h = TOOLBAR_HEIGHT,
        b = 0,
    }
end

if dfhack_flags.module then return end

if not dfhack.world.isFortressMode() then
    qerror('Demo only supports fort mode.')
end

local gui = require('gui')
local Panel = require('gui.widgets.containers.panel')
local Label = require('gui.widgets.labels.label')
local utils = require('utils')
local Window = require('gui.widgets.containers.window')
local Toggle = require('gui.widgets.labels.toggle_hotkey_label')

local screen

local visible_when_not_focused = true

local function visible()
    return visible_when_not_focused or screen and screen:isActive() and not screen.defocused
end

ToolbarDemoPanel = defclass(ToolbarDemoPanel, Panel)
ToolbarDemoPanel.ATTRS{
    frame_style = function(...)
        local style = gui.FRAME_THIN(...)
        style.signature_pen = false
        return style
    end,
    visible_override = true,
    visible = visible,
    frame_background = { ch = 32, bg = COLOR_BLACK },
}

local temp_x, temp_y = 10, 10
local label_width = 9 -- max len of words left, right, center, secondary
local demo_panel_width = label_width + 4
local demo_panel_height = 3

local left_toolbar_demo = ToolbarDemoPanel{
    frame_title = 'left toolbar',
    frame = { l = temp_x, t = temp_y, w = demo_panel_width, h = demo_panel_height },
    subviews = { Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
}
local center_toolbar_demo = ToolbarDemoPanel{
    frame_title = 'center toolbar',
    frame = { l = temp_x + demo_panel_width, t = temp_y, w = demo_panel_width, h = demo_panel_height },
    subviews = { Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
}
local right_toolbar_demo = ToolbarDemoPanel{
    frame_title = 'right toolbar',
    frame = { l = temp_x + 2 * demo_panel_width, t = temp_y, w = demo_panel_width, h = demo_panel_height },
    subviews = { Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
}
local secondary_visible = false
local secondary_toolbar_demo
secondary_toolbar_demo = ToolbarDemoPanel{
    frame_title = 'secondary toolbar',
    frame = { l = temp_x + demo_panel_width, t = temp_y - demo_panel_height, w = demo_panel_width, h = demo_panel_height },
    subviews = { Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
    visible = function() return visible() and secondary_visible end,
}

---@param secondary? CenterToolbarSecondaryToolbarNames
local function update_demonstrations(secondary)
    -- by default, draw primary toolbar demonstrations right above the primary toolbars:
    -- {l demo}   {c demo}   {r demo}
    -- [l tool]   [c tool]   [r tool]  (bottom of UI)
    local toolbar_demo_dy = -TOOLBAR_HEIGHT
    local ir = gui.get_interface_rect()
    ---@param v widgets.Panel
    ---@param frame widgets.Widget.frame
    ---@param buttons NamedButtons
    local function update(v, frame, buttons)
        v.frame = {
            w = frame.w,
            h = frame.h,
            l = frame.l + ir.x1,
            t = frame.t + ir.y1 + toolbar_demo_dy,
        }
        local sorted = {}
        for _, button in pairs(buttons) do
            utils.insert_sorted(sorted, button, 'offset')
        end
        local buttons = ''
        for i, o in ipairs(sorted) do
            if o.offset > #buttons then
                buttons = buttons .. (' '):rep(o.offset - #buttons)
            end
            if o.width == 1 then
                buttons = buttons .. '|'
            elseif o.width > 1 then
                buttons = buttons .. '/'..('-'):rep(o.width - 2)..'\\'
            end
        end
        v.subviews.buttons:setText(
            buttons:sub(2) -- the demo panel border is at offset 0, so trim first character to start at offset 1
        )
    end
    if secondary then
        -- a secondary toolbar is active, move the primary demonstration up to
        -- let the secondary be demonstrated right above the actual secondary:
        -- {l demo}   {c demo}   {r demo}
        --               {s demo}
        --               [s tool]
        -- [l tool]   [c tool]   [r tool]  (bottom of UI)
        update(secondary_toolbar_demo, fort.center:secondary_toolbar_frame(ir, secondary),
            fort.center.secondary_toolbars[secondary].buttons)
        secondary_visible = true
        toolbar_demo_dy = toolbar_demo_dy - 2 * SECONDARY_TOOLBAR_HEIGHT
    else
        secondary_visible = false
    end

    update(left_toolbar_demo, fort.left:frame(ir), fort.left.buttons)
    update(right_toolbar_demo, fort.right:frame(ir), fort.right.buttons)
    update(center_toolbar_demo, fort.center:frame(ir), fort.center.buttons)
end

local tool_from_designation = {
    -- df.main_designation_type.NONE -- not a tool
    [df.main_designation_type.DIG_DIG] = 'dig',
    [df.main_designation_type.DIG_REMOVE_STAIRS_RAMPS] = 'dig',
    [df.main_designation_type.DIG_STAIR_UP] = 'dig',
    [df.main_designation_type.DIG_STAIR_UPDOWN] = 'dig',
    [df.main_designation_type.DIG_STAIR_DOWN] = 'dig',
    [df.main_designation_type.DIG_RAMP] = 'dig',
    [df.main_designation_type.DIG_CHANNEL] = 'dig',
    [df.main_designation_type.CHOP] = 'chop',
    [df.main_designation_type.GATHER] = 'gather',
    [df.main_designation_type.SMOOTH] = 'smooth',
    [df.main_designation_type.TRACK] = 'smooth',
    [df.main_designation_type.ENGRAVE] = 'smooth',
    [df.main_designation_type.FORTIFY] = 'smooth',
    -- df.main_designation_type.REMOVE_CONSTRUCTION -- not used?
    [df.main_designation_type.CLAIM] = 'mass_designation',
    [df.main_designation_type.UNCLAIM] = 'mass_designation',
    [df.main_designation_type.MELT] = 'mass_designation',
    [df.main_designation_type.NO_MELT] = 'mass_designation',
    [df.main_designation_type.DUMP] = 'mass_designation',
    [df.main_designation_type.NO_DUMP] = 'mass_designation',
    [df.main_designation_type.HIDE] = 'mass_designation',
    [df.main_designation_type.NO_HIDE] = 'mass_designation',
    -- df.main_designation_type.TOGGLE_ENGRAVING -- not used?
    [df.main_designation_type.DIG_FROM_MARKER] = 'dig',
    [df.main_designation_type.DIG_TO_MARKER] = 'dig',
    [df.main_designation_type.CHOP_FROM_MARKER] = 'chop',
    [df.main_designation_type.CHOP_TO_MARKER] = 'chop',
    [df.main_designation_type.GATHER_FROM_MARKER] = 'gather',
    [df.main_designation_type.GATHER_TO_MARKER] = 'gather',
    [df.main_designation_type.SMOOTH_FROM_MARKER] = 'smooth',
    [df.main_designation_type.SMOOTH_TO_MARKER] = 'smooth',
    [df.main_designation_type.DESIGNATE_TRAFFIC_HIGH] = 'traffic',
    [df.main_designation_type.DESIGNATE_TRAFFIC_NORMAL] = 'traffic',
    [df.main_designation_type.DESIGNATE_TRAFFIC_LOW] = 'traffic',
    [df.main_designation_type.DESIGNATE_TRAFFIC_RESTRICTED] = 'traffic',
    [df.main_designation_type.ERASE] = 'erase',
}
local tool_from_bottom = {
    -- df.main_bottom_mode_type.NONE
    -- df.main_bottom_mode_type.BUILDING
    -- df.main_bottom_mode_type.BUILDING_PLACEMENT
    -- df.main_bottom_mode_type.BUILDING_PICK_MATERIALS
    -- df.main_bottom_mode_type.ZONE
    -- df.main_bottom_mode_type.ZONE_PAINT
    [df.main_bottom_mode_type.STOCKPILE] = 'stockpile',
    [df.main_bottom_mode_type.STOCKPILE_PAINT] = 'stockpile_paint',
    -- df.main_bottom_mode_type.BURROW
    [df.main_bottom_mode_type.BURROW_PAINT] = 'burrow_paint'
    -- df.main_bottom_mode_type.HAULING
    -- df.main_bottom_mode_type.ARENA_UNIT
    -- df.main_bottom_mode_type.ARENA_TREE
    -- df.main_bottom_mode_type.ARENA_WATER_PAINT
    -- df.main_bottom_mode_type.ARENA_MAGMA_PAINT
    -- df.main_bottom_mode_type.ARENA_SNOW_PAINT
    -- df.main_bottom_mode_type.ARENA_MUD_PAINT
    -- df.main_bottom_mode_type.ARENA_REMOVE_PAINT
}
---@return CenterToolbarSecondaryToolbarNames?
local function active_secondary()
    local designation = df.global.game.main_interface.main_designation_selected
    if designation ~= df.main_designation_type.NONE then
        return tool_from_designation[designation]
    end
    local bottom = df.global.game.main_interface.bottom_mode_selected
    if bottom ~= df.main_bottom_mode_type.NONE then
        return tool_from_bottom[bottom]
    end
end

DemoWindow = defclass(DemoWindow, Window)
DemoWindow.ATTRS{
    frame_title = 'DF "bottom toolbars" module demo',
    frame = { w = 39, h = 5 },
    resizable = true,
}

function DemoWindow:init()
    self:addviews{
        Toggle{
            label = 'Demos visible when not focused?',
            initial_option = visible_when_not_focused,
            on_change = function(new, old)
                visible_when_not_focused = new
            end
        }
    }
end

DemoScreen = defclass(DemoScreen, gui.ZScreen)
function DemoScreen:init()
    self:addviews{
        DemoWindow{},
        left_toolbar_demo,
        center_toolbar_demo,
        right_toolbar_demo,
        secondary_toolbar_demo,
    }
end

local secondary, if_percentage
function DemoScreen:render(...)
    if visible_when_not_focused then
        local new_secondary = active_secondary()
        local new_if_percentage = df.global.init.display.max_interface_percentage
        if new_secondary ~= secondary or new_if_percentage ~= if_percentage then
            secondary = new_secondary
            self:updateLayout()
        end
    end
    return DemoScreen.super.render(self, ...)
end

function DemoScreen:postComputeFrame(frame_body)
    update_demonstrations(active_secondary())
end

screen = DemoScreen{}:show()

local gui = require('gui')
local layout = require('gui.dflayout')
local widgets = require('gui.widgets')
local utils = require('utils')

--- Demo Control Window and Screen ---

---@class Demo
---@field text string text displayed in main window demo list
---@field available fun(): boolean? return true if demo is available in current context
---@field active? boolean whether the main window has enabled this demo (managed by main window)
---@field views gui.View[] list of views to add to main ZScreen
---@field update fun() called by main window to recompute demo frames

local visible_when_not_focused = true
function demos_are_visible()
    if not screen then return false end
    if visible_when_not_focused then return true end
    return screen:isActive() and screen:hasFocus()
end

DemoWindow = defclass(DemoWindow, widgets.Window)
DemoWindow.ATTRS{
    frame_title = 'dflayout demos',
    frame = { w = 39, h = 9 },
    resizable = true,
    autoarrange_subviews = true,
    autoarrange_gap = 1,
}

---@param args { demos: Demo[] }
function DemoWindow:init(args)
    self.demos = args.demos
    self:addviews{
        widgets.ToggleHotkeyLabel{
            label = 'Demos visible when not focused?',
            initial_option = visible_when_not_focused,
            on_change = function(new, old)
                visible_when_not_focused = new
            end
        },
        widgets.List{
            view_id = 'list',
            frame = { h = 10, },
            icon_pen = COLOR_GREY,
            icon_width = 3,
            on_submit = function(index, item)
                local demo = self.demos[index]
                demo.active = demo.available() and not demo.active
                if demo.active then demo.update() end
                self:refresh()
            end
        },
    }
end

local CHECK = string.char(251) -- U+221A SQUARE ROOT

function DemoWindow:refresh()
    local choices = {}
    for _, demo in ipairs(self.demos) do
        local icon
        if not demo.available() then
            icon = '-'
        elseif demo.active then
            icon = CHECK
        end
        table.insert(choices, {
            text = demo.text,
            icon = icon,
        })
    end
    self.subviews.list:setChoices(choices)
    return self
end

DemoScreen = defclass(DemoScreen, gui.ZScreen)
DemoScreen.ATTRS{
    focus_path = 'gui.dflayout-demo'
}

function DemoScreen:init(args)
    self.demos = args.demos
    local function demo_views()
        local views = {}
        for _, demo in ipairs(self.demos) do
            if demo.views then
                table.move(demo.views, 1, #demo.views, #views + 1, views)
            end
        end
        return views
    end
    self:addviews{
        DemoWindow{ demos = self.demos }:refresh(),
        table.unpack(demo_views())
    }
end

function DemoScreen:onDismiss()
    screen = nil
end

local if_percentage
function DemoScreen:render(...)
    if visible_when_not_focused then
        local new_if_percentage = df.global.init.display.max_interface_percentage
        if new_if_percentage ~= if_percentage then
            if_percentage = new_if_percentage
            self:updateLayout()
        end
    end
    return DemoScreen.super.render(self, ...)
end

function DemoScreen:postComputeFrame(frame_body)
    for _, demo in ipairs(self.demos) do
        if demo.available() and demo.active then
            demo.update()
        end
    end
end

--- Fort Toolbar Demo ---

---@class FortToolbarsDemo: Demo
local fort_toolbars_demo = {
    text = 'fort toolbars',
    available = dfhack.world.isFortressMode,
}

local function fort_toolbars_visible()
    return demos_are_visible() and fort_toolbars_demo.active
end

local secondary_visible = false

local function primary_toolbar_dy()
    if secondary_visible then
        -- When a secondary toolbar is active, move the primary demos up to let
        -- the secondary demo be right above the actual secondary:
        -- {l demo}   {c demo}   {r demo}
        --               {s demo}
        --               [s tool]
        -- [l tool]   [c tool]   [r tool]  (bottom of UI)
        return -(layout.TOOLBAR_HEIGHT + 2 * layout.SECONDARY_TOOLBAR_HEIGHT)
    else
        -- Otherwise, draw primary toolbar demos right above the primary
        -- toolbars:
        -- {l demo}   {c demo}   {r demo}
        -- [l tool]   [c tool]   [r tool]  (bottom of UI)
        return -layout.TOOLBAR_HEIGHT
    end
end

-- Generates a `view:computeFrame()` function that tracks the placement of the
-- given `toolbar`.
--
-- Note: The returned function does not return a separate body rect; subviews
-- will be able to overwrite the normal UI-drawn frame!
---@param toolbar DFLayout.Toolbar
---@param dy_fn fun(): integer
---@return function
local function get_computeFrame_fn(toolbar, dy_fn)
    return function(self, parent_rect)
        local ir = gui.get_interface_rect()
        local frame = toolbar.frame(ir)
        return gui.mkdims_wh(
            ir.x1 + frame.l,
            ir.y1 + frame.t + dy_fn(),
            frame.w,
            frame.h)
    end
end

---@param buttons DFLayout.Toolbar.NamedButtons
local function buttons_string(buttons)
    local sorted = {}
    for _, button in pairs(buttons) do
        utils.insert_sorted(sorted, button, 'offset')
    end
    -- For a one-column button, use | to indicate the button's position.
    -- For wider buttons, use shapes like /\ or /--\ to illustrate the
    -- button's position and width.
    local str = ''
    for i, o in ipairs(sorted) do
        if o.offset > #str then
            str = str .. (' '):rep(o.offset - #str)
        end
        if o.width == 1 then
            str = str .. '|'
        elseif o.width > 1 then
            str = str .. '/' .. ('-'):rep(o.width - 2) .. '\\'
        end
    end
    return str
end

---@class ToolbarDemo.attrs: widgets.Panel.attrs
---@class ToolbarDemo.attrs.partial: widgets.Panel.attrs.partial
---@class ToolbarDemo.initTable: ToolbarDemo.attrs.partial, { toolbar?: DFLayout.Toolbar, toolbar_dy?: fun(): integer }
---@class ToolbarDemo: widgets.Panel
---@field super widgets.Panel
---@field ATTRS ToolbarDemo.attrs|fun(attributes: ToolbarDemo.attrs.partial)
---@overload fun(init_table: ToolbarDemo.initTable): self
ToolbarDemo = defclass(ToolbarDemo, widgets.Panel)
ToolbarDemo.ATTRS{
    frame_style = function(...)
        local style = gui.FRAME_THIN(...)
        style.signature_pen = false
        return style
    end,
    visible = fort_toolbars_visible,
    frame_background = { ch = 32, bg = COLOR_BLACK },
}

---@param args ToolbarDemo.initTable
function ToolbarDemo:init(args)
    self.label = widgets.Label{ frame = { l = 0 } }
    if args.toolbar and args.toolbar_dy then
        self:update_to_toolbar(args.toolbar, args.toolbar_dy)
    end
    self:addviews{ self.label }
end

---@param toolbar DFLayout.Toolbar
---@param dy fun(): integer
---@return unknown
function ToolbarDemo:update_to_toolbar(toolbar, dy)
    -- set button representation string
    local text = buttons_string(toolbar.buttons)
    local l_inset = 0
    if text:sub(1, 1) == ' ' then
        -- don't overwrite the left border edge with a plain space
        l_inset = 1
        text = text:sub(2)
    end
    self.label.frame.l = l_inset
    self.label:setText(text)

    -- track actual toolbar, but with a y offset
    self.computeFrame = get_computeFrame_fn(toolbar, dy)

    return self
end

local left_toolbar_demo = ToolbarDemo{
    frame_title = 'left toolbar',
    toolbar = layout.fort.toolbars.left,
    toolbar_dy = primary_toolbar_dy,
}

local center_toolbar_demo = ToolbarDemo{
    frame_title = 'center toolbar',
    toolbar = layout.fort.toolbars.center,
    toolbar_dy = primary_toolbar_dy,
}

local right_toolbar_demo = ToolbarDemo{
    frame_title = 'right toolbar',
    toolbar = layout.fort.toolbars.right,
    toolbar_dy = primary_toolbar_dy,
}

local secondary_toolbar_demo = ToolbarDemo{
    frame_title = 'secondary toolbar',
    visible = function()
        return fort_toolbars_visible() and secondary_visible
    end,
}

fort_toolbars_demo.views = {
    left_toolbar_demo,
    center_toolbar_demo,
    right_toolbar_demo,
    secondary_toolbar_demo,
}

---@param secondary? DFLayout.Fort.SecondaryToolbar.Names
local function update_fort_toolbars(secondary)
    local function updateLayout(view)
        if view.frame_parent_rect then
            view:updateLayout()
        end
    end
    if secondary then
        -- show secondary demo just above actual secondary
        local function dy()
            return -layout.SECONDARY_TOOLBAR_HEIGHT
        end
        secondary_toolbar_demo:update_to_toolbar(layout.fort.secondary_toolbars[secondary], dy)
        updateLayout(secondary_toolbar_demo)
        secondary_visible = true
    else
        secondary_visible = false
    end

    updateLayout(left_toolbar_demo)
    updateLayout(right_toolbar_demo)
    updateLayout(center_toolbar_demo)
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
---@return DFLayout.Fort.SecondaryToolbar.Names?
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

fort_toolbars_demo.update = function()
    update_fort_toolbars(active_secondary())
end

local secondary
local center_render = center_toolbar_demo.render
function center_toolbar_demo:render(...)
    local new_secondary = active_secondary()
    if new_secondary ~= secondary then
        secondary = new_secondary
        update_fort_toolbars(secondary)
    end
    return center_render(self, ...)
end

--- start demo control window ---

screen = screen and screen:raise() or DemoScreen{
    demos = {
        fort_toolbars_demo,
    },
}:show()

local gui = require('gui')
local layout = require('gui.dflayout')
local widgets = require('gui.widgets')
local utils = require('utils')

---@class Demo
---@field text string text displayed in main window demo list
---@field available fun(): boolean? return true if demo is available in current context
---@field active? boolean whether the main window has enabled this demo (managed by main window)
---@field views gui.View[] list of views to add to main ZScreen
---@field on_render? fun() called by main window every render; useful to notice changes in overall UI state

if visible_when_not_focused == nil then
    visible_when_not_focused = true
end
local function demos_are_visible()
    if not screen then return false end
    if visible_when_not_focused then return true end
    return screen:isActive() and screen:hasFocus()
end

---@param demo Demo
local function demo_active(demo)
    return demos_are_visible() and demo.active
end

-- Generates a `view:computeFrame()` function that tracks the placement of the
-- given `el`.
--
-- Note: The returned function does not return a separate body rect; subviews
-- will be able to overwrite the normal UI-drawn frame!
---@param el DFLayout.DynamicUIElement
---@param dy_fn? fun(): integer
---@return function
local function get_computeFrame_fn(el, dy_fn)
    return function(self, parent_rect)
        local ir = gui.get_interface_rect()
        local frame = layout.getUIElementFrame(el, ir)
        return gui.mkdims_wh(
            ir.x1 + frame.l,
            ir.y1 + frame.t + (dy_fn and dy_fn() or 0),
            frame.w,
            frame.h)
    end
end

local normal_frame_style = function(...)
    local style = gui.FRAME_THIN(...)
    style.signature_pen = false
    return style
end

local hover_frame_style = function(...)
    local style = gui.FRAME_BOLD(...)
    style.signature_pen = false
    return style
end

--- Fort Toolbar Demo ---

---@class FortToolbarsDemo: Demo
local fort_toolbars_demo = {
    text = 'fort toolbars',
    available = dfhack.world.isFortressMode,
}

local fort_toolbars_visible = curry(demo_active, fort_toolbars_demo)

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

---@param buttons DFLayout.Toolbar.Layout
local function buttons_tokens(buttons)
    local sorted_buttons = {}
    for button_name, button in pairs(buttons) do
        utils.insert_sorted(sorted_buttons, {
            name = button_name,
            offset = button.offset,
            width = button.width,
        }, 'offset')
    end
    local offset = 0
    local sorted_button_names = {}
    local tokens_by_name = {}
    for _, button_info in ipairs(sorted_buttons) do
        table.insert(sorted_button_names, button_info.name)
        local token = { gap = button_info.offset - offset, width = button_info.width }
        if button_info.width == 1 then
            -- For a one-column button, use | to indicate the button's position.
            token.text = '|'
        elseif button_info.width > 1 then
            -- For wider buttons, use shapes like /\ or /--\ to illustrate the
            -- button's position and width.
            token.text = '/' .. ('-'):rep(button_info.width - 2) .. '\\'
        end
        offset = button_info.offset + button_info.width
        tokens_by_name[button_info.name] = token
    end
    return sorted_button_names, tokens_by_name
end

---@class ToolbarDemo.ToolbarInfo
---@field el DFLayout.DynamicUIElement
---@field buttons DFLayout.Toolbar.Layout
---@field button_els table<string, DFLayout.DynamicUIElement>
---@field demo_dy fun(): integer

---@class ToolbarDemo.attrs: widgets.Panel.attrs
---@class ToolbarDemo.attrs.partial: widgets.Panel.attrs.partial
---@field toolbar_info? ToolbarDemo.ToolbarInfo
---@class ToolbarDemo.initTable: ToolbarDemo.attrs.partial
---@class ToolbarDemo: widgets.Panel
---@field super widgets.Panel
---@field ATTRS ToolbarDemo.attrs|fun(attributes: ToolbarDemo.attrs.partial)
---@overload fun(init_table: ToolbarDemo.initTable): self
ToolbarDemo = defclass(ToolbarDemo, widgets.Panel)
ToolbarDemo.ATTRS{
    frame_style = normal_frame_style,
    visible = fort_toolbars_visible,
    frame_background = { ch = 32, bg = COLOR_BLACK },
}

---@param args ToolbarDemo.initTable
function ToolbarDemo:init(args)
    self.label = widgets.Label{ frame = { l = 0 } }
    if args.toolbar_info then
        self:update_to_toolbar(args.toolbar_info)
    end
    self:addviews{ self.label }
end

---@param toolbar_info ToolbarDemo.ToolbarInfo
---@return ToolbarDemo
function ToolbarDemo:update_to_toolbar(toolbar_info)
    local order, named_tokens = buttons_tokens(toolbar_info.buttons)
    function set_button_text(lit_button_name)
        local lit = false
        local tokens = {}
        for _, name in ipairs(order) do
            local token = copyall(named_tokens[name])
            if name == lit_button_name then
                lit = true
                token.pen = { fg = COLOR_BLACK, bg = COLOR_BLUE }
            end
            table.insert(tokens, token)
        end
        self.label:setText(tokens)
        return lit
    end

    set_button_text()

    -- track actual toolbar, but with a y offset
    self.computeFrame = get_computeFrame_fn(toolbar_info.el, toolbar_info.demo_dy)

    self.toolbar_el = toolbar_info.el
    self.button_els = toolbar_info.button_els
    self.set_button_text = set_button_text

    return self
end

-- capture computed locations of toolbar and buttons
function ToolbarDemo:postUpdateLayout()
    local ir = gui.get_interface_rect()
    local function vr(el)
        local f = layout.getUIElementFrame(el, ir)
        return gui.ViewRect{ rect = gui.mkdims_wh(ir.x1 + f.l, ir.y1 + f.t, f.w, f.h) }
    end
    if self.toolbar_el then
        self.toolbar_vr = vr(self.toolbar_el)
    end
    if self.button_els then
        local vrs = {}
        for name, el in pairs(self.button_els) do
            vrs[name] = vr(el)
        end
        self.toolbar_button_vrs = vrs
    end
end

function ToolbarDemo:render(...)
    if self.toolbar_vr then
        if self:getMousePos(self.toolbar_vr) then
            self.frame_style = hover_frame_style
            if self.toolbar_button_vrs then
                local lit = false
                for button_name, button_vr in pairs(self.toolbar_button_vrs) do
                    if self:getMousePos(button_vr) then
                        if self.set_button_text(button_name) then
                            lit = true
                            break
                        end
                    end
                end
                if not lit then
                    self.set_button_text()
                end
            end
        else
            self.frame_style = normal_frame_style
            self.set_button_text()
        end
    end
    return ToolbarDemo.super.render(self, ...)
end

local left_toolbar_demo = ToolbarDemo{
    frame_title = 'left toolbar',
    toolbar_info = {
        el = layout.elements.fort.toolbars.left,
        buttons = layout.element_layouts.fort.toolbars.left.buttons,
        button_els = layout.elements.fort.toolbar_buttons.left,
        demo_dy = primary_toolbar_dy,
    },
}

local center_toolbar_demo = ToolbarDemo{
    frame_title = 'center toolbar',
    toolbar_info = {
        el = layout.elements.fort.toolbars.center,
        buttons = layout.element_layouts.fort.toolbars.center.buttons,
        button_els = layout.elements.fort.toolbar_buttons.center,
        demo_dy = primary_toolbar_dy,
    },
}

local right_toolbar_demo = ToolbarDemo{
    frame_title = 'right toolbar',
    toolbar_info = {
        el = layout.elements.fort.toolbars.right,
        buttons = layout.element_layouts.fort.toolbars.right.buttons,
        button_els = layout.elements.fort.toolbar_buttons.right,
        demo_dy = primary_toolbar_dy,
    }
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
local function update_secondary_toolbar(secondary)
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
        secondary_toolbar_demo:update_to_toolbar{
            el = layout.elements.fort.secondary_toolbars[secondary],
            buttons = layout.element_layouts.fort.secondary_toolbars[secondary].buttons,
            button_els = layout.elements.fort.secondary_toolbar_buttons[secondary],
            demo_dy = dy
        }
        updateLayout(secondary_toolbar_demo)
        secondary_visible = true
    else
        secondary_visible = false
    end

    -- update primary toolbar demos since their positions depends on whether a
    -- secondary is active
    updateLayout(left_toolbar_demo)
    updateLayout(right_toolbar_demo)
    updateLayout(center_toolbar_demo)
end

local secondary_toolbar_from_designation = {
    -- df.main_designation_type.NONE -- not a tool
    [df.main_designation_type.DIG_DIG] = 'DIG',
    [df.main_designation_type.DIG_REMOVE_STAIRS_RAMPS] = 'DIG',
    [df.main_designation_type.DIG_STAIR_UP] = 'DIG',
    [df.main_designation_type.DIG_STAIR_UPDOWN] = 'DIG',
    [df.main_designation_type.DIG_STAIR_DOWN] = 'DIG',
    [df.main_designation_type.DIG_RAMP] = 'DIG',
    [df.main_designation_type.DIG_CHANNEL] = 'DIG',
    [df.main_designation_type.CHOP] = 'CHOP',
    [df.main_designation_type.GATHER] = 'GATHER',
    [df.main_designation_type.SMOOTH] = 'SMOOTH',
    [df.main_designation_type.TRACK] = 'SMOOTH',
    [df.main_designation_type.ENGRAVE] = 'SMOOTH',
    [df.main_designation_type.FORTIFY] = 'SMOOTH',
    -- df.main_designation_type.REMOVE_CONSTRUCTION -- not used?
    [df.main_designation_type.CLAIM] = 'ITEM_BUILDING',
    [df.main_designation_type.UNCLAIM] = 'ITEM_BUILDING',
    [df.main_designation_type.MELT] = 'ITEM_BUILDING',
    [df.main_designation_type.NO_MELT] = 'ITEM_BUILDING',
    [df.main_designation_type.DUMP] = 'ITEM_BUILDING',
    [df.main_designation_type.NO_DUMP] = 'ITEM_BUILDING',
    [df.main_designation_type.HIDE] = 'ITEM_BUILDING',
    [df.main_designation_type.NO_HIDE] = 'ITEM_BUILDING',
    -- df.main_designation_type.TOGGLE_ENGRAVING -- not used?
    [df.main_designation_type.DIG_FROM_MARKER] = 'DIG',
    [df.main_designation_type.DIG_TO_MARKER] = 'DIG',
    [df.main_designation_type.CHOP_FROM_MARKER] = 'CHOP',
    [df.main_designation_type.CHOP_TO_MARKER] = 'CHOP',
    [df.main_designation_type.GATHER_FROM_MARKER] = 'GATHER',
    [df.main_designation_type.GATHER_TO_MARKER] = 'GATHER',
    [df.main_designation_type.SMOOTH_FROM_MARKER] = 'SMOOTH',
    [df.main_designation_type.SMOOTH_TO_MARKER] = 'SMOOTH',
    [df.main_designation_type.DESIGNATE_TRAFFIC_HIGH] = 'TRAFFIC',
    [df.main_designation_type.DESIGNATE_TRAFFIC_NORMAL] = 'TRAFFIC',
    [df.main_designation_type.DESIGNATE_TRAFFIC_LOW] = 'TRAFFIC',
    [df.main_designation_type.DESIGNATE_TRAFFIC_RESTRICTED] = 'TRAFFIC',
    [df.main_designation_type.ERASE] = 'ERASE',
}
local secondary_toolbar_from_bottom = {
    -- df.main_bottom_mode_type.NONE
    -- df.main_bottom_mode_type.BUILDING
    -- df.main_bottom_mode_type.BUILDING_PLACEMENT
    -- df.main_bottom_mode_type.BUILDING_PICK_MATERIALS
    -- df.main_bottom_mode_type.ZONE
    -- df.main_bottom_mode_type.ZONE_PAINT
    [df.main_bottom_mode_type.STOCKPILE] = 'MAIN_STOCKPILE_MODE',
    [df.main_bottom_mode_type.STOCKPILE_PAINT] = 'STOCKPILE_NEW',
    -- df.main_bottom_mode_type.BURROW
    [df.main_bottom_mode_type.BURROW_PAINT] = 'Add new burrow',
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
        return secondary_toolbar_from_designation[designation]
    end
    local bottom = df.global.game.main_interface.bottom_mode_selected
    if bottom ~= df.main_bottom_mode_type.NONE then
        return secondary_toolbar_from_bottom[bottom]
    end
end

local secondary
fort_toolbars_demo.on_render = function()
    local new_secondary = active_secondary()
    if new_secondary ~= secondary then
        secondary = new_secondary
        update_secondary_toolbar(secondary)
    end
end

--- experimental Info window Demos ---

---@param text string
---@param focus_string string
---@param el DFLayout.DynamicUIElement
---@param item_count_fn fun(): integer
---@return Demo
local function info_items_demo(text, focus_string, el)
    local demo = {
        text = text,
        available = dfhack.world.isFortressMode,
    }
    local panel = widgets.Panel{
        frame_style = normal_frame_style,
        frame_background = nil, -- do not fill panel interior, leave it "see through"
        visible = function()
            return demo_active(demo)
                and dfhack.gui.matchFocusString(focus_string, dfhack.gui.getDFViewscreen(true))
        end,
    }
    panel.computeFrame = get_computeFrame_fn(el)
    panel.getMouseFramePos = function() end -- hide from ZScreen:isMouseOver(), so that mouse input passes through

    demo.views = { panel }

    local state_changed = layout.getUIElementStateChecker(el)
    function demo.on_render()
        if state_changed() then
            panel:updateLayout()
        end
    end

    return demo
end

local orders_demo = info_items_demo(
    'info Orders tab',
    'dwarfmode/Info/WORK_ORDERS/Default',
    layout.experimental_elements.orders)

local zones_demo = info_items_demo(
    'info Places/Zones tab',
    'dwarfmode/Info/BUILDINGS/ZONES',
    layout.experimental_elements.zones)

--- Demo Control Window and Screen ---

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
    focus_path = 'gui.dflayout-demo',
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
    self:addviews(demo_views())
    -- put main window last so it is rendered "on top"
    self:addviews{ DemoWindow{ demos = self.demos }:refresh() }
end

function DemoScreen:onDismiss()
    screen = nil
end

local if_percentage
function DemoScreen:render(...)
    if demos_are_visible() then
        local new_if_percentage = df.global.init.display.max_interface_percentage
        if new_if_percentage ~= if_percentage then
            if_percentage = new_if_percentage
            self:updateLayout()
        end
        for _, demo in ipairs(self.demos) do
            if demo.on_render and demo.available() and demo.active then
                demo.on_render()
            end
        end
    end
    return DemoScreen.super.render(self, ...)
end

screen = screen and screen:raise() or DemoScreen{
    demos = {
        fort_toolbars_demo,
        orders_demo,
        zones_demo,
    },
}:show()

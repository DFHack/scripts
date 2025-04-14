local gui = require('gui')
local layout = require('gui.dflayout')
local widgets = require('gui.widgets')
local utils = require('utils')

--- Demo Control Window and Screen ---

local function demo_available(demo)
    if not demo.available then return true end
    return demo.available()
end

local visible_when_not_focused = true
function visible()
    if visible_when_not_focused then return true end
    if not screen then return false end
    return screen:isActive() and not screen.defocused
end

DemoWindow = defclass(DemoWindow, widgets.Window)
DemoWindow.ATTRS{
    frame_title = 'dflayout demos',
    frame = { w = 39, h = 9 },
    resizable = true,
    autoarrange_subviews = true,
    autoarrange_gap = 1,
}

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
                demo.active = demo_available(demo) and not demo.active
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
        if not demo_available(demo) then
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
            self:updateLayout()
        end
    end
    return DemoScreen.super.render(self, ...)
end

function DemoScreen:postComputeFrame(frame_body)
    for _, demo in ipairs(self.demos) do
        if demo.active and demo.update then
            demo.update()
        end
    end
end

--- Fort Toolbar Demo ---

local fort_toolbars_demo = {
    text = 'fort toolbars',
    available = dfhack.world.isFortressMode,
}

local function fort_toolbars_visible()
    return visible() and fort_toolbars_demo.active
end

FortToolbarDemoPanel = defclass(FortToolbarDemoPanel, widgets.Panel)
FortToolbarDemoPanel.ATTRS{
    frame_style = function(...)
        local style = gui.FRAME_THIN(...)
        style.signature_pen = false
        return style
    end,
    visible_override = true,
    visible = fort_toolbars_visible,
    frame_background = { ch = 32, bg = COLOR_BLACK },
}

local left_toolbar_demo = FortToolbarDemoPanel{
    frame_title = 'left toolbar',
    subviews = { widgets.Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
}
local center_toolbar_demo = FortToolbarDemoPanel{
    frame_title = 'center toolbar',
    subviews = { widgets.Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
}
local right_toolbar_demo = FortToolbarDemoPanel{
    frame_title = 'right toolbar',
    subviews = { widgets.Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
}
local secondary_visible = false
local secondary_toolbar_demo = FortToolbarDemoPanel{
    frame_title = 'secondary toolbar',
    subviews = { widgets.Label{ view_id = 'buttons', frame = { l = 0, r = 0 } } },
    visible = function() return fort_toolbars_visible() and secondary_visible end,
}

fort_toolbars_demo.views = {
    left_toolbar_demo,
    center_toolbar_demo,
    right_toolbar_demo,
    secondary_toolbar_demo,
}

---@param secondary? DFLayout.Fort.SecondaryToolbar.Names
local function update_fort_toolbars(secondary)
    -- by default, draw primary toolbar demonstrations right above the primary toolbars:
    -- {l demo}   {c demo}   {r demo}
    -- [l tool]   [c tool]   [r tool]  (bottom of UI)
    local toolbar_demo_dy = -layout.TOOLBAR_HEIGHT
    local ir = gui.get_interface_rect()
    ---@param v widgets.Panel
    ---@param frame widgets.Widget.frame
    ---@param buttons DFLayout.Toolbar.NamedButtons
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
                buttons = buttons .. '/' .. ('-'):rep(o.width - 2) .. '\\'
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
        update(secondary_toolbar_demo, layout.fort.secondary_toolbars[secondary].frame(ir),
            layout.fort.secondary_toolbars[secondary].buttons)
        secondary_visible = true
        toolbar_demo_dy = toolbar_demo_dy - 2 * layout.SECONDARY_TOOLBAR_HEIGHT
    else
        secondary_visible = false
    end

    update(left_toolbar_demo, layout.fort.toolbars.left.frame(ir), layout.fort.toolbars.left.buttons)
    update(right_toolbar_demo, layout.fort.toolbars.right.frame(ir), layout.fort.toolbars.right.buttons)
    update(center_toolbar_demo, layout.fort.toolbars.center.frame(ir), layout.fort.toolbars.center.buttons)
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
function center_toolbar_demo:render(...)
    local new_secondary = active_secondary()
    if new_secondary ~= secondary then
        secondary = new_secondary
        update_fort_toolbars(secondary)
    end
    return FortToolbarDemoPanel.render(self, ...)
end

--- start demo control window ---

screen = screen and screen:raise() or DemoScreen{
    demos = {
        fort_toolbars_demo,
    },
}:show()

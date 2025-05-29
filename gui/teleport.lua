local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')

saved_citizens = saved_citizens or (saved_citizens == nil and true)
saved_friendly = saved_friendly or (saved_friendly == nil and true)
saved_hostile = saved_hostile or (saved_hostile == nil and true)

local indicator = df.global.game.main_interface.recenter_indicator_m

local function is_good_unit(include, unit)
    if not unit then return false end
    if dfhack.units.isDead(unit) or
        not dfhack.units.isActive(unit) or
        unit.flags1.caged
    then
        return false
    end
    if dfhack.units.isCitizen(unit) or dfhack.units.isResident(unit) then
        return include.citizens
    end
    local dangerous = dfhack.units.isDanger(unit)
    if not dangerous then return include.friendly end
    return include.hostile
end

-----------------
-- Teleport
--

Teleport = defclass(Teleport, widgets.Window)
Teleport.ATTRS {
    frame_title='Teleport',
    frame={w=45, h=26, r=2, t=18},
    resizable=true,
    resize_min={h=20},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function Teleport:init()
    self.mark = nil
    self.prev_help_text = ''
    self:reset_selected_state() -- sets self.selected_*
    self:reset_double_click() -- sets self.last_map_click_ms and self.last_map_click_pos

    -- pre-add UI selected unit, if any
    local initial_unit = dfhack.gui.getSelectedUnit(true)
    if initial_unit then
        self:add_unit(initial_unit)
    end
    -- close the view sheet panel (if it's open) so the player can see the map
    df.global.game.main_interface.view_sheets.open = false

    self:addviews{
        widgets.WrappedLabel{
            frame={l=0},
            text_to_wrap=self:callback('get_help_text'),
        },
        widgets.HotkeyLabel{
            frame={l=0},
            label='Teleport units to mouse cursor',
            key='CUSTOM_CTRL_T',
            auto_width=true,
            on_activate=self:callback('do_teleport'),
            enabled=function()
                return dfhack.gui.getMousePos() and #self.selected_units.list > 0
            end,
        },
        widgets.ResizingPanel{
            autoarrange_subviews=true,
            subviews={
                widgets.ToggleHotkeyLabel{
                    view_id='include_citizens',
                    frame={l=0, w=29},
                    label='Include citizen units ',
                    key='CUSTOM_SHIFT_U',
                    initial_option=saved_citizens,
                    on_change=function(val) saved_citizens = val end,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='include_friendly',
                    frame={l=0, w=29},
                    label='Include friendly units',
                    key='CUSTOM_SHIFT_F',
                    initial_option=saved_friendly,
                    on_change=function(val) saved_friendly = val end,
                },
                widgets.ToggleHotkeyLabel{
                    view_id='include_hostile',
                    frame={l=0, w=29},
                    label='Include hostile units ',
                    key='CUSTOM_SHIFT_H',
                    initial_option=saved_hostile,
                    on_change=function(val) saved_hostile = val end,
                },
            },
        },
        widgets.Panel{
            frame={t=10, b=0, l=0, r=0},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text='No selected units',
                    visible=function() return #self.selected_units.list == 0 end,
                },
                widgets.Label{
                    frame={t=0, l=0},
                    text='Selected units:',
                    visible=function() return #self.selected_units.list > 0 end,
                },
                widgets.List{
                    view_id='list',
                    frame={t=2, l=0, r=0, b=4},
                    on_select=function(_, choice)
                        if choice then
                            df.assign(indicator, xyz2pos(dfhack.units.getPosition(choice.unit)))
                        end
                    end,
                    on_submit=function(_, choice)
                        if choice then
                            local pos = xyz2pos(dfhack.units.getPosition(choice.unit))
                            dfhack.gui.revealInDwarfmodeMap(pos, true, true)
                        end
                    end,
                },
                widgets.HotkeyLabel{
                    frame={l=0, b=1},
                    key='CUSTOM_SHIFT_R',
                    label='Deselect unit',
                    auto_width=true,
                    on_activate=self:callback('remove_unit'),
                    enabled=function() return #self.selected_units.list > 0 end,
                },
                widgets.HotkeyLabel{
                    frame={l=26, b=1},
                    key='CUSTOM_SHIFT_X',
                    label='Clear list',
                    auto_width=true,
                    on_activate=self:callback('reset_selected_state'),
                    enabled=function() return #self.selected_units.list > 0 end,
                },
                widgets.Label{
                    frame={l=0, b=0},
                    text={
                        'Click name or hit ',
                        {text='Enter', pen=COLOR_LIGHTGREEN},
                        ' to zoom to unit',
                    },
                },
            }
        }
    }

    self:refresh_choices()
end

function Teleport:reset_double_click()
    self.last_map_click_ms = 0
    self.last_map_click_pos = {}
end

function Teleport:update_coords(x, y, z)
    ensure_keys(self.selected_coords, z, y)[x] = true
    local selected_bounds = ensure_key(self.selected_bounds, z,
            {x1=x, x2=x, y1=y, y2=y})
    selected_bounds.x1 = math.min(selected_bounds.x1, x)
    selected_bounds.x2 = math.max(selected_bounds.x2, x)
    selected_bounds.y1 = math.min(selected_bounds.y1, y)
    selected_bounds.y2 = math.max(selected_bounds.y2, y)
end

function Teleport:add_unit(unit)
    if not unit then return end
    local x, y, z = dfhack.units.getPosition(unit)
    if not x then return end
    if not self.selected_units.set[unit.id] then
        self.selected_units.set[unit.id] = true
        utils.insert_sorted(self.selected_units.list, unit, 'id')
        self:update_coords(x, y, z)
    end
end

function Teleport:reset_selected_state(keep_units)
    if not keep_units then
        self.selected_units = {list={}, set={}}
    end
    self.selected_coords = {} -- z -> y -> x -> true
    self.selected_bounds = {} -- z -> bounds rect
    for _, unit in ipairs(self.selected_units.list) do
        self:update_coords(dfhack.units.getPosition(unit))
    end
    if next(self.subviews) then
        self:updateLayout()
        self:refresh_choices()
    end
end

function Teleport:refresh_choices()
    local choices = {}
    for _, unit in ipairs(self.selected_units.list) do
        local suffix = ''
        if dfhack.units.isCitizen(unit) then suffix = ' (citizen)'
        elseif dfhack.units.isResident(unit) then suffix = ' (resident)'
        elseif dfhack.units.isDanger(unit) then suffix = ' (hostile)'
        elseif dfhack.units.isMerchant(unit) or dfhack.units.isForest(unit) then
            suffix = ' (merchant)'
        elseif dfhack.units.isAnimal(unit) then
            -- tame units will already have an annotation in the readable name
            if not dfhack.units.isTame(unit) then
                suffix = ' (wild)'
            end
        else
            suffix = ' (friendly)'
        end
        table.insert(choices, {
            text=dfhack.units.getReadableName(unit)..suffix,
            unit=unit
        })
    end
    table.sort(choices, function(a, b) return a.text < b.text end)
    self.subviews.list:setChoices(choices)
end

function Teleport:remove_unit()
    local _, choice = self.subviews.list:getSelected()
    if not choice then return end
    self.selected_units.set[choice.unit.id] = nil
    utils.erase_sorted_key(self.selected_units.list, choice.unit.id, 'id')
    self:reset_selected_state(true)
end

function Teleport:get_include()
    local include = {citizens=false, friendly=false, hostile=false}
    if next(self.subviews) then
        include.citizens = self.subviews.include_citizens:getOptionValue()
        include.friendly = self.subviews.include_friendly:getOptionValue()
        include.hostile = self.subviews.include_hostile:getOptionValue()
    end
    return include
end

function Teleport:get_help_text()
    local help_text = 'Draw boxes around units to select'
    local num_selected = #self.selected_units.list
    if num_selected > 0 then
        help_text = help_text ..
            (', or double click on a tile to teleport %d selected unit(s).'):format(num_selected)
    end
    if help_text ~= self.prev_help_text then
        self.prev_help_text = help_text
    end
    return help_text
end

function Teleport:get_bounds(cursor, mark)
    cursor = cursor or self.mark
    mark = mark or self.mark or cursor
    if not mark then return end

    return {
        x1=math.min(cursor.x, mark.x),
        x2=math.max(cursor.x, mark.x),
        y1=math.min(cursor.y, mark.y),
        y2=math.max(cursor.y, mark.y),
        z1=math.min(cursor.z, mark.z),
        z2=math.max(cursor.z, mark.z)
    }
end

function Teleport:select_box(bounds)
    if not bounds then return end
    local filter = curry(is_good_unit, self:get_include())
    local selected_units = dfhack.units.getUnitsInBox(
        bounds.x1, bounds.y1, bounds.z1, bounds.x2, bounds.y2, bounds.z2, filter)
    for _,unit in ipairs(selected_units) do
        self:add_unit(unit)
    end
    self:refresh_choices()
end

function Teleport:onInput(keys)
    if Teleport.super.onInput(self, keys) then return true end
    if keys._MOUSE_R and self.mark then
        self.mark = nil
        self:updateLayout()
        return true
    elseif keys._MOUSE_L then
        if self:getMouseFramePos() then return true end
        local pos = dfhack.gui.getMousePos()
        if not pos then
            self:reset_double_click()
            return false
        end
        local now_ms = dfhack.getTickCount()
        if same_xyz(pos, self.last_map_click_pos) and
                now_ms - self.last_map_click_ms <= widgets.getDoubleClickMs() then
            self:reset_double_click()
            self:do_teleport(pos)
            self.mark = nil
            self:updateLayout()
            return true
        end
        self.last_map_click_ms = now_ms
        self.last_map_click_pos = pos
        if self.mark then
            self:select_box(self:get_bounds(pos))
            self:reset_double_click()
            self.mark = nil
            self:updateLayout()
            return true
        end
        self.mark = pos
        self:updateLayout()
        return true
    end
end

local to_pen = dfhack.pen.parse
local CURSOR_PEN = to_pen{ch='o', fg=COLOR_BLUE,
                         tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 22)}
local BOX_PEN = to_pen{ch='X', fg=COLOR_GREEN,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 0, 0)}
local SELECTED_PEN = to_pen{ch='I', fg=COLOR_GREEN,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}

function Teleport:onRenderFrame(dc, rect)
    Teleport.super.onRenderFrame(self, dc, rect)

    local highlight_coords = self.selected_coords[df.global.window_z]
    if highlight_coords then
        local function get_overlay_pen(pos)
            if same_xyz(indicator, pos) then return end
            if safe_index(highlight_coords, pos.y, pos.x) then
                return SELECTED_PEN
            end
        end
        guidm.renderMapOverlay(get_overlay_pen, self.selected_bounds[df.global.window_z])
    end

    -- draw selection box and cursor (blinking when in ascii mode)
    local cursor = dfhack.gui.getMousePos()
    local selection_bounds = self:get_bounds(cursor)
    if selection_bounds and (dfhack.screen.inGraphicsMode() or gui.blink_visible(500)) then
        guidm.renderMapOverlay(
            function() return self.mark and BOX_PEN or CURSOR_PEN end,
            selection_bounds)
    end
end

function Teleport:do_teleport(pos)
    pos = pos or dfhack.gui.getMousePos()
    if not pos then return end
    print(('teleporting %d unit(s)'):format(#self.selected_units.list))
    for _,unit in ipairs(self.selected_units.list) do
        dfhack.units.teleport(unit, pos)
    end
    indicator.x = -30000
    self:reset_selected_state()
    self:updateLayout()
end

-----------------
-- TeleportScreen
--

TeleportScreen = defclass(TeleportScreen, gui.ZScreen)
TeleportScreen.ATTRS {
    focus_path='teleport',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
    force_pause=true,
}

function TeleportScreen:init()
    local window = Teleport{}
    self:addviews{
        window,
        widgets.DimensionsTooltip{
            get_anchor_pos_fn=function() return window.mark end,
        },
    }
end

function TeleportScreen:onDismiss()
    indicator.x = -30000
    view = nil
end

view = view and view:raise() or TeleportScreen{}:show()

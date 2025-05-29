--@ module = true

local dialogs = require('gui.dialogs')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local assign_minecarts = reqscript('assign-minecarts')
local quickfort = reqscript('quickfort')
local quickfort_command = reqscript('internal/quickfort/command')
local quickfort_orders = reqscript('internal/quickfort/orders')

local function get_qsp_pos(cursor, offset)
    return {
        x=cursor.x+(offset.x or 0),
        y=cursor.y+(offset.y or 0),
        z=cursor.z
    }
end

local function is_valid_pos(cursor, qsp_pos)
    local stats = quickfort.apply_blueprint{mode='build', data='trackstop', pos=cursor, dry_run=true}
    if stats.build_designated.value <= 0 then return false end

    if not qsp_pos then return true end

    stats = quickfort.apply_blueprint{mode='place', data='c', pos=qsp_pos, dry_run=true}
    return stats.place_designated.value > 0
end


local function get_quantumstop_data(feeders, name, trackstop_dir)
    local stop_name, route_name
    if name == '' then
        local next_route_id = df.global.plotinfo.hauling.next_id
        stop_name = ('Dumper %d'):format(next_route_id)
        route_name = ('Quantum %d'):format(next_route_id)
    else
        stop_name = ('%s dumper'):format(name)
        route_name = ('%s quantum'):format(name)
    end

    local feeder_ids = {}
    for _, feeder in ipairs(feeders) do
        table.insert(feeder_ids, tostring(feeder.id))
    end

    return ('trackstop%s{name="%s" take_from=%s route="%s"}')
           :format(trackstop_dir, stop_name, table.concat(feeder_ids, ','), route_name)
end

local function get_quantumsp_data(name)
    if name == '' then
        local next_route_id = df.global.plotinfo.hauling.next_id
        name = ('Quantum %d'):format(next_route_id-1)
    end
    return ('ry{name="%s" quantum=true}:+all'):format(name)
end

-- this function assumes that is_valid_pos() has already validated the positions
local function create_quantum(pos, qsp_pos, feeders, name, trackstop_dir)
    local data = get_quantumstop_data(feeders, name, trackstop_dir)
    local stats = quickfort.apply_blueprint{mode='build', pos=pos, data=data}
    if stats.build_designated.value == 0 then
        error(('failed to build trackstop at (%d, %d, %d)')
              :format(pos.x, pos.y, pos.z))
    end

    if qsp_pos then
        data = get_quantumsp_data(name)
        stats = quickfort.apply_blueprint{mode='place', pos=qsp_pos, data=data}
        if stats.place_designated.value == 0 then
            error(('failed to place stockpile at (%d, %d, %d)')
                :format(qsp_pos.x, qsp_pos.y, qsp_pos.z))
        end
    end
end

local function order_minecart(pos)
    local quickfort_ctx = quickfort_command.init_ctx{
            command='orders', blueprint_name='gui/quantum', cursor=pos}
    quickfort_orders.enqueue_additional_order(quickfort_ctx, 'wooden minecart')
    quickfort_orders.create_orders(quickfort_ctx)
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        is_valid_pos=is_valid_pos,
        create_quantum=create_quantum,
    }
end

----------------------
-- Quantum
--

Quantum = defclass(Quantum, widgets.Window)
Quantum.ATTRS {
    frame_title='Quantum',
    frame={w=35, h=21, r=2, t=18},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    feeders=DEFAULT_NIL,
}

function Quantum:init()
    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap=self:callback('get_help_text'),
            text_pen=COLOR_GREY,
        },
        widgets.EditField{
            view_id='name',
            label_text='Name: ',
            key='CUSTOM_CTRL_N',
            key_sep=' ',
            on_char=function(_, text) return #text < 12 end,  -- TODO can be circumvented by pasting
            text='',
        },
        widgets.CycleHotkeyLabel{
            view_id='dump_dir',
            key='CUSTOM_CTRL_D',
            key_sep=' ',
            label='Dump direction:',
            options={
                {label='North', value={y=-1}, pen=COLOR_YELLOW},
                {label='South', value={y=1}, pen=COLOR_YELLOW},
                {label='East', value={x=1}, pen=COLOR_YELLOW},
                {label='West', value={x=-1}, pen=COLOR_YELLOW},
            },
        },
        widgets.ToggleHotkeyLabel{
            view_id='create_sp',
            key='CUSTOM_CTRL_Z',
            label='Create output pile:',
        },
        widgets.CycleHotkeyLabel{
            view_id='feeder_mode',
            key='CUSTOM_CTRL_F',
            label='Feeder select:',
            options={
                {label='Single', value='single', pen=COLOR_GREEN},
                {label='Multi', value='multi', pen=COLOR_YELLOW},
            },
        },
        widgets.CycleHotkeyLabel{
            view_id='minecart',
            key='CUSTOM_CTRL_M',
            label='Assign minecart:',
            options={
                {label='Auto', value='auto', pen=COLOR_GREEN},
                {label='Order', value='order', pen=COLOR_YELLOW},
                {label='Manual', value='manual', pen=COLOR_LIGHTRED},
            },
        },
        widgets.Panel{
            frame={h=4},
            subviews={
                widgets.WrappedLabel{
                    text_to_wrap=function() return ('%d minecart%s available: %s will be %s'):format(
                        self.cart_count, self.cart_count == 1 and '' or 's',
                        self.cart_count == 1 and 'it' or 'one',
                        self.cart_count > 0 and 'automatically assigned to the quantum route'
                            or 'ordered via the manager for you to assign to the quantum route later')
                    end,
                    visible=function() return self.subviews.minecart:getOptionValue() == 'auto' end,
                },
                widgets.WrappedLabel{
                    text_to_wrap=function() return ('%d minecart%s available: %s will be ordered for you to assign to the quantum route later'):format(
                        self.cart_count, self.cart_count == 1 and '' or 's',
                        self.cart_count >= 1 and 'an additional one' or 'one')
                    end,
                    visible=function() return self.subviews.minecart:getOptionValue() == 'order' end,
                },
                widgets.WrappedLabel{
                    text_to_wrap=function() return ('%d minecart%s available: please %s a minecart of your choice to the quantum route later'):format(
                        self.cart_count, self.cart_count == 1 and '' or 's',
                        self.cart_count == 0 and 'order and assign' or 'assign')
                    end,
                    visible=function() return self.subviews.minecart:getOptionValue() == 'manual' end,
                },
            },
        },
    }

    self:refresh()
end

function Quantum:refresh()
    self.cart_count = #assign_minecarts.get_free_vehicles()
end

function Quantum:get_help_text()
    if #self.feeders == 0 then
        return 'Please select a feeder stockpile.'
    end
    if self.subviews.feeder_mode:getOptionValue() == 'single' then
        return 'Please select the location of the new quantum dumper.'
    end
    return 'Please select additional feeder stockpiles or the location of the new quantum dumper.'
end

local function get_hover_stockpile(pos)
    pos = pos or dfhack.gui.getMousePos()
    if not pos then return end
    local bld = dfhack.buildings.findAtTile(pos)
    if not bld or bld:getType() ~= df.building_type.Stockpile then return end
    return bld
end

function Quantum:get_pos_qsp_pos()
    local pos = dfhack.gui.getMousePos()
    if not pos then return end
    local qsp_pos = self.subviews.create_sp:getOptionValue() and
        get_qsp_pos(pos, self.subviews.dump_dir:getOptionValue())
    return pos, qsp_pos
end

local to_pen = dfhack.pen.parse
local SELECTED_SP_PEN = to_pen{ch='=', fg=COLOR_LIGHTGREEN,
                               tile=dfhack.screen.findGraphicsTile('ACTIVITY_ZONES', 3, 15)}
local HOVERED_SP_PEN = to_pen{ch='=', fg=COLOR_GREEN,
                              tile=dfhack.screen.findGraphicsTile('ACTIVITY_ZONES', 2, 15)}

function Quantum:render_sp_overlay(sp, pen)
    if not sp or sp.z ~= df.global.window_z then return end

    local function get_overlay_char(pos)
        if dfhack.buildings.containsTile(sp, pos.x, pos.y) then return pen end
    end

    guidm.renderMapOverlay(get_overlay_char, sp)
end

local CURSOR_PEN = to_pen{ch='o', fg=COLOR_BLUE,
                          tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 22)}
local GOOD_PEN = to_pen{ch='x', fg=COLOR_GREEN,
                        tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}
local BAD_PEN = to_pen{ch='X', fg=COLOR_RED,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 3, 0)}

function Quantum:render_placement_overlay()
    if #self.feeders == 0 then return end
    local stop_pos, qsp_pos = self:get_pos_qsp_pos()

    if not stop_pos then return end

    local bounds = {
        x1=stop_pos.x,
        x2=stop_pos.x,
        y1=stop_pos.y,
        y2=stop_pos.y,
    }
    if qsp_pos then
        bounds.x1 = math.min(bounds.x1, qsp_pos.x)
        bounds.x2 = math.max(bounds.x2, qsp_pos.x)
        bounds.y1 = math.min(bounds.y1, qsp_pos.y)
        bounds.y2 = math.max(bounds.y2, qsp_pos.y)
    end

    local ok = is_valid_pos(stop_pos, qsp_pos)

    local function get_overlay_char(pos)
        if not ok then return BAD_PEN end
        return same_xy(pos, stop_pos) and CURSOR_PEN or GOOD_PEN
    end

    guidm.renderMapOverlay(get_overlay_char, bounds)
end

function Quantum:render(dc)
    self:render_sp_overlay(get_hover_stockpile(), HOVERED_SP_PEN)
    for _, feeder in ipairs(self.feeders) do
        self:render_sp_overlay(feeder, SELECTED_SP_PEN)
    end
    self:render_placement_overlay()
    Quantum.super.render(self, dc)
end

function Quantum:try_commit()
    local pos, qsp_pos = self:get_pos_qsp_pos()
    if not is_valid_pos(pos, qsp_pos) then
        return
    end

    create_quantum(pos, qsp_pos, self.feeders, self.subviews.name.text,
        self.subviews.dump_dir:getOptionLabel():sub(1,1))

    local minecart, message = nil, nil
    local minecart_option = self.subviews.minecart:getOptionValue()
    if minecart_option == 'auto' then
        minecart = assign_minecarts.assign_minecart_to_last_route(true)
        if minecart then
            message = 'An available minecart (' ..
                    dfhack.items.getReadableDescription(minecart) ..
                    ') was assigned to your new' ..
                    ' quantum stockpile. You\'re all done!'
        else
            message = 'There are no minecarts available to assign to the' ..
            ' quantum stockpile, but a manager order to produce' ..
            ' one was created for you. Once the minecart is' ..
            ' built, please add it to the quantum stockpile route' ..
            ' with the "assign-minecarts all" command or manually in' ..
            ' the (H)auling menu.'
        end
    end
    if minecart_option == 'order' then
        order_minecart(pos)
        message = 'A manager order to produce a minecart has been' ..
                ' created for you. Once the minecart is' ..
                ' built, please add it to the quantum stockpile route' ..
                ' with the "assign-minecarts all" command or manually in' ..
                ' the (H)auling menu.'
    end
    if not message then
        message = 'Please add a minecart of your choice to the quantum' ..
                ' stockpile route in the (H)auling menu.'
    end
    -- display a message box telling the user what we just did
    dialogs.MessageBox{text=message:wrap(70)}:show()
    return true
end

function Quantum:onInput(keys)
    if Quantum.super.onInput(self, keys) then return true end

    if not keys._MOUSE_L then return end
    local sp = get_hover_stockpile()
    if sp then
        if self.subviews.feeder_mode:getOptionValue() == 'single' then
            self.feeders = {sp}
        else
            local found = false
            for idx, feeder in ipairs(self.feeders) do
                if sp.id == feeder.id then
                    found = true
                    table.remove(self.feeders, idx)
                    break
                end
            end
            if not found then
                table.insert(self.feeders, sp)
            end
        end
        self:updateLayout()
    elseif #self.feeders > 0 then
        self:try_commit()
        self:refresh()
        self:updateLayout()
    end
end

----------------------
-- QuantumScreen
--

QuantumScreen = defclass(QuantumScreen, gui.ZScreen)
QuantumScreen.ATTRS {
    focus_path='quantum',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
    feeder=DEFAULT_NIL,
}

function QuantumScreen:init()
    self:addviews{Quantum{feeders={self.feeder}}}
end

function QuantumScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

view = view and view:raise() or QuantumScreen{feeder=dfhack.gui.getSelectedStockpile(true)}:show()

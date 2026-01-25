local gui = require('gui')
local widgets = require('gui.widgets')
local textures = require('gui.textures')

--
-- Button label definitions
--
local function make_button(ascii, pens, x, y)
    local out = {}
    -- Grid of 3x3 tiles
    for i=1,3 do
        local tmp = {}
        for j=1,3 do
            table.insert(tmp, {
                tile=dfhack.pen.parse{
                    ch=ascii[i][j],
                    fg=pens[i][j],
                    keep_lower=true,
                    tile=dfhack.screen.findGraphicsTile('INTERFACE_BITS',x+j-1,y+i-1)
                },
            })
        end
        table.insert(out, tmp)
    end
    return out
end

local function make_activity_button(ch, color, border_color, border_acolor, x, y, ax, ay)
    local ascii = {
        {218, 196, 191},
        {179, ch, 179},
        {192, 196, 217},
    }

    local function make_pens(border, main)
        return {
            {border, border, border},
            {border, main, border},
            {border, border, border},
        }
    end

    return {
        inactive = make_button(ascii, make_pens(border_color, color), x, y),
        active = make_button(ascii, make_pens(border_acolor, color), ax, ay)
    }
end

local activity_buttons = {
    -- NotInUse
    [0] = make_activity_button('-', COLOR_LIGHTRED, COLOR_DARKGREY, COLOR_YELLOW, 59, 18, 59, 15),
    -- KeepLoaded
    [1] = make_activity_button('L', COLOR_LIGHTCYAN, COLOR_DARKGREY, COLOR_YELLOW, 59, 24, 59, 21),
    -- PrepareToFire
    [2] = make_activity_button('P', COLOR_YELLOW, COLOR_DARKGREY, COLOR_YELLOW, 56, 18, 56, 15),
    -- FireAtWill
    [3] = make_activity_button('F', COLOR_LIGHTRED, COLOR_DARKGREY, COLOR_YELLOW, 53, 18, 53, 15),
    -- PracticeFire
    [4] = make_activity_button('T', COLOR_LIGHTGREEN, COLOR_DARKGREY, COLOR_YELLOW, 44, 42, 44, 39),
}

local goto_button_ascii = {
    {218, 196, 191},
    {26, 'X', 179},
    {192, 196, 217},
}
local goto_button_color = {
    {COLOR_LIGHTCYAN, COLOR_LIGHTCYAN, COLOR_LIGHTCYAN},
    {COLOR_LIGHTCYAN, COLOR_LIGHTRED, COLOR_LIGHTCYAN},
    {COLOR_LIGHTCYAN, COLOR_LIGHTCYAN, COLOR_LIGHTCYAN},
}
local goto_button = make_button(goto_button_ascii, goto_button_color, 32, 0)


-- TODO: The usage of these icons requires the ability to adjust screentexpos_flag
-- from a pen. Specifically anchor_subordinate, anchor_x_coord, and anchor_y_coord in order
-- to stretch a singular tile to fit the 5x5 area that vanilla displays portraits at.
--
-- local function make_engine_icon(ascii, color, tile_x, tile_y)
--     local icon = {}
--     local tile = dfhack.screen.findGraphicsTile('BUILDING_ICONS',tile_x, tile_y)
--
--     for y=1,5 do
--         icon[y] = {}
--         for x=1,5 do
--             local ch = 32
--             local fg = nil
--             -- Adapt indices for a 3x3 icon into 5x5 like the graphics icon
--             if x >= 2 and x <= 4 and y >= 2 and y <= 4 then
--                 ch = ascii[y-1][x-1]
--                 fg = color[y-1][x-1]
--             end
--             icon[y][x] = {
--                 tile = dfhack.pen.parse{
--                     ch=ch,
--                     fg=fg,
--                     keep_lower=true,
--                     tile=subtile,
--                 },
--             }
--         end
--     end
--
--     return icon
-- end
--
-- local catapult_icon_ascii = {
--     {177, 210, 177},
--     {177, 186, 177},
--     {177, 8, 177},
-- }
-- local catapult_icon_color = {
--     {COLOR_YELLOW, COLOR_BROWN, COLOR_YELLOW},
--     {COLOR_YELLOW, COLOR_BROWN, COLOR_YELLOW},
--     {COLOR_YELLOW, COLOR_BROWN, COLOR_YELLOW},
-- }
--
-- local ballista_icon_ascii = {
--     {220, 30, 220},
--     {221, 179, 222},
--     {92, 207, 47},
-- }
-- local ballista_icon_color = {
--     {COLOR_YELLOW, COLOR_BROWN, COLOR_YELLOW},
--     {COLOR_YELLOW, COLOR_BROWN, COLOR_YELLOW},
--     {COLOR_BROWN, COLOR_YELLOW, COLOR_BROWN},
-- }
--
-- local boltthrower_icon_ascii = {
--     {32, 32, 32},
--     {32, 147, 32},
--     {32, 32, 32},
-- }
-- local boltthrower_icon_color = {
--     {COLOR_BLACK, COLOR_BLACK, COLOR_BLACK},
--     {COLOR_BLACK, COLOR_YELLOW, COLOR_BLACK},
--     {COLOR_BLACK, COLOR_BLACK, COLOR_BLACK},
-- }
--
-- local siegeengine_icons = {
--     -- Catapult
--     [0] = make_engine_icon(catapult_icon_ascii, catapult_icon_color, 7, 11),
--     -- Ballista
--     [1] = make_engine_icon(ballista_icon_ascii, ballista_icon_color, 6, 11),
--     -- Bolt Thrower
--     [2] = make_engine_icon(boltthrower_icon_ascii, boltthrower_icon_color, 3, 12),
-- }

local function is_siege_ammo(item)
    return df.item_ammost:is_instance(item)
        or df.item_siegeammost:is_instance(item)
        or df.item_boulderst:is_instance(item)
end

-- Obtain a list of siege engine buildings on the map with specific information
local function get_siege_engines()
    local siege_list = {}
    for _, building in ipairs(df.global.world.buildings.other.IN_PLAY) do
        if not df.building_siegeenginest:is_instance(building) then goto continue end
        if not building.flags.exists then goto continue end

        -- Calculate amount of ammo stored in the building
        local loaded_ammo = 0
        for _, item in ipairs(building.contained_items) do
            if item.use_mode == df.building_item_role_type.TEMP and is_siege_ammo(item.item) then
                loaded_ammo = loaded_ammo + item.item.stack_size
            end
        end

        -- Display information on active jobs involving this building.
        local active_job = nil
        for _, job in ipairs(building.jobs) do
            if job.job_type == df.job_type.LoadCatapult
                or job.job_type == df.job_type.LoadBallista
                or job.job_type == df.job_type.LoadBoltThrower then
                active_job = 'Loading'
            elseif job.job_type == df.job_type.FireCatapult
                or job.job_type == df.job_type.FireBallista
                or job.job_type == df.job_type.FireBoltThrower then
                -- Display `Ready` instead of firing when in standby mode
                -- as the same job_type is used when actively firing and waiting.
                -- This is to reduce confusion as no projectiles are fired
                active_job = building.action == 2 and 'Ready' or 'Firing'
            end
        end

        siege_list[building.id] = {
            id = building.id,
            type = building.type,
            action = building.action,
            loaded_ammo = loaded_ammo,
            name = building.name,
            active_job=active_job,
            pos = {
                x=building.centerx,
                y=building.centery,
                z=building.z,
            },
        }
        ::continue::
    end
    return siege_list
end

local function item_in_list(item, list)
    for _, v in ipairs(list) do
        if v == item then
            return true
        end
    end
    return false
end

-- Set siegeengine action, returning false if the building isn't found
local function set_siege_engine_action(id_list, action)
    local count = 0
    for _, building in ipairs(df.global.world.buildings.other.IN_PLAY) do
        if item_in_list(building.id, id_list) then
            if not df.building_siegeenginest:is_instance(building) then return false end
            building.action = action
            count = count + 1
            if count == #id_list then
                return count
            end
        end
    end
    return count
end

-- SiegeEngineList
SiegeEngineList = defclass(SiegeEngineList, widgets.Panel)
SiegeEngineList.ATTRS = {
    view_id='list',
    frame={l=0, r=0, t=1, b=7},
    frame_style=gui.FRAME_INTERIOR,

    -- Filters by siegeengine_type, -1 being all
    type_filter=-1,
}

function SiegeEngineList:init()
    self:refresh_data()

    self.refresh_rate = 30
    self.refresh_timer = 0

    self.button_start_x = 24

    self:addviews({
        widgets.List {
            view_id='list',
            frame={l=0,t=0,b=0,r=0},
            row_height=3,
        }
    })

    self:refresh_view(true)
end

-- Used to manage how often the ui data refreshes
function SiegeEngineList:onRenderBody()
    self.refresh_timer = self.refresh_timer + 1
    if (self.refresh_timer > self.refresh_rate) then
        self.refresh_timer = 0
        self:refresh_data()
    end
end

local siegeengine_type_string = {
    [0] = 'Catapult',
    [1] = 'Ballista',
    [2] = 'Thrower'
}

local function concat_tables(to, from)
    for _, val in ipairs(from) do
        table.insert(to, val)
    end
end

-- TODO: Replace constants with df.siegeengine_action enum once structures merged
local action_button_order={3, 4, 2, 1, 0}
local action_button_keybinds = {'CUSTOM_SHIFT_F', 'CUSTOM_SHIFT_T', 'CUSTOM_SHIFT_P', 'CUSTOM_SHIFT_L', 'CUSTOM_SHIFT_N'}

-- Add a multiline label definition from `from` to `to` starting at y=y_start or 0
local function add_multiline(to, from, y_start)
    for i, item in pairs(from) do
        concat_tables(to[i + (y_start or 0)], from[i])
    end
end

-- Label string callbacks, used to update the display without resetting the scrolling List
local action_text_pen = dfhack.pen.parse({ fg=COLOR_GREEN })
function SiegeEngineList:get_action_text(id)
    return self.engines[id].active_job or ''
end

local ammo_text_pen = dfhack.pen.parse({ fg=COLOR_GREY })
function SiegeEngineList:get_ammo_text(id)
    return (self.engines[id].loaded_ammo or '?')
end

local ammo_out_pen = dfhack.pen.parse({ fg=COLOR_RED })
local ammo_pen = dfhack.pen.parse({ fg=COLOR_YELLOW })
function SiegeEngineList:get_ammo_pen(id)
    return self.engines[id].loaded_ammo == 0 and ammo_out_pen or ammo_pen
end

function SiegeEngineList:get_name_text(id)
    local engine = self.engines[id]
    return siegeengine_type_string[engine.type]..' '..(#engine.name ==0 and 'Unnamed' or engine.name)
end

function SiegeEngineList:get_activity_button_tile(id, action, x, y)
    return activity_buttons[action][self.engines[id].action == action and 'active' or 'inactive'][y][x].tile
end

-- Generate the multiline Label display for an engine
function SiegeEngineList:make_entry_text(engine)
    local lines = {
        {{text=self:callback('get_name_text', engine.id), width=self.button_start_x}},
        {
            { text=self:callback('get_action_text', engine.id), pen=action_text_pen, width=9 },
            { text='ammo=', pen=ammo_text_pen },
            { text=self:callback('get_ammo_text', engine.id), pen=self:callback('get_ammo_pen', engine.id), width=self.button_start_x - 14},
        },
        {{text='', width=self.button_start_x}},
    }

    -- Goto Position Button
    add_multiline(lines, goto_button)

    -- Padding following goto button
    add_multiline(lines, {{{text='', width=3}},{{text='', width=3}},{{text='', width=3}}})

    -- Siege Engine activity selection buttons
    for _, button_action in ipairs(action_button_order) do
        for y=1,3 do
            for x=1,3 do
                table.insert(lines[y], { tile = self:callback('get_activity_button_tile', engine.id, button_action, x, y)})
            end
        end
    end

    -- Transform multiline label into a single label with newlines
    local out_tokens = {}
    for i=1,3 do
        concat_tables(out_tokens, lines[i])
        table.insert(out_tokens, NEWLINE)
    end

    return out_tokens
end

-- Refresh the engine information being displayed, but not the list.
-- Updating data here *does not* add or remove new/deleted engines.
function SiegeEngineList:refresh_data()
    local old_engines = self.engines
    self.engines = get_siege_engines()
    if self.type_filter ~= -1 then
        for id, eng in pairs(self.engines) do
            if eng.type ~= self.type_filter then
                self.engines[id] = nil
            end
        end
    end

    if not old_engines then return end
    -- Determine if a listed engine was removed, if so refresh ui
    for id, _ in pairs(old_engines) do
        if self.engines[id] == nil then
            self:refresh_view(false)
            return
        end
    end
end

-- Refresh the engine list, updating to display new/deleted engines correctly.
function SiegeEngineList:refresh_view(refresh_data)
    if refresh_data then self:refresh_data() end
    local choices = {}
    for _, data in pairs(self.engines) do
        table.insert(choices, {
            text=self:make_entry_text(data),
            search_key="",
            data=data.id
        });
    end
    self.subviews.list:setChoices(choices)
end

function SiegeEngineList:reveal_selected()
    local _, selected = self.subviews.list:getSelected()
    if selected ~= nil then
        dfhack.gui.revealInDwarfmodeMap(self.engines[selected.data].pos, true, true)
    end
end

function SiegeEngineList:set_all_action(action)
    local listed = {}
    for key, _ in pairs(self.engines) do
        listed[#listed+1] = key
    end

    local count = set_siege_engine_action(listed, action)
    if count ~= #listed then
        self:refresh_view(true)
        return
    end

    for _, engine in ipairs(self.engines) do
        engine.action = action
    end
end

function SiegeEngineList:set_selected_action(action)
    local _, selected = self.subviews.list:getSelected()

    local successful = set_siege_engine_action({selected.data}, action)
    if not successful then
        self:refresh_view(true)
        return
    end

    -- Successfully updated, just update the cached state
    self.engines[selected.data].action = action
end

function SiegeEngineList:onInput(keys)
    if not keys._MOUSE_L then
        SiegeEngineList.super.onInput(self, keys)
        return
    end

    local list = self.subviews.list
    local idx = list:getIdxUnderMouse()
    if not idx then
        SiegeEngineList.super.onInput(self, keys)
        return
    end

    local x = list:getMousePos()
    if x < self.button_start_x or x > self.button_start_x+(3*7) then
        SiegeEngineList.super.onInput(self, keys)
        return
    end

    list:setSelected(idx)

    -- 0 is goto, 1 is blank, following are action buttons
    local button_pressed = math.ceil((x-self.button_start_x+1)/3)-1

    if button_pressed == 0 then
        self:reveal_selected()
        return
    end

    if button_pressed == 1 then
        -- Blank space
        return
    end

    local action = action_button_order[button_pressed-1]
    self:set_selected_action(action)
end

-- SiegeManager
SiegeManager = defclass(SiegeManager, widgets.Window)
SiegeManager.ATTRS = {
    frame_title = 'Siege Manager',
    frame = {w=54,h=48,r=2,t=18},
    resizable=true,
    drag_anchors = {title=true},

    engines=DEFAULT_NIL,
}

function SiegeManager:init()
    self:addviews({
        SiegeEngineList {},
        widgets.CycleHotkeyLabel {
            frame={b=6},
            key='CUSTOM_T',
            on_change=self:callback('set_type_filter'),
            label='Show Types:',
            options={
                {label='All', value=-1},
                {label='Ballista', value=df.siegeengine_type.Ballista},
                {label='Bolt Thrower', value=df.siegeengine_type.BoltThrower},
                {label='Catapult', value=df.siegeengine_type.Catapult},
            },
            initial_option=1,
        },
        widgets.ToggleHotkeyLabel {
            view_id = 'configure_all',
            frame={b=2},
            key = 'CUSTOM_SHIFT_A',
            key_sep = ': ',
            label = 'Configure All',
            initial_option=2,
        },
        widgets.HotkeyLabel {
            frame={b=0},
            key='CUSTOM_CTRL_C',
            label='Reveal in World',
            on_activate=self:callback('reveal_selected')
        },
    })

    for i, action_button in ipairs(action_button_order) do
        self:addviews({
            widgets.HotkeyLabel {
                frame = {b=3, l=(i - 1)*2},
                key = action_button_keybinds[i],
                key_sep = i == #action_button_order and ': ' or '',
                label = i == #action_button_order and 'Set Action' or '',
                on_activate = self:callback('set_action', action_button)
            }
        })
    end
end

function SiegeManager:set_type_filter(new)
    self.subviews.list.type_filter = new
    self.subviews.list:refresh_view(true)
end

function SiegeManager:reveal_selected()
    self.subviews.list:reveal_selected()
end

function SiegeManager:set_action(action)
    if self.subviews.configure_all:getOptionValue() then
        self.subviews.list:set_all_action(action)
    else
        self.subviews.list:set_selected_action(action)
    end
end

-- SiegeManagerScreen
SiegeManagerScreen = defclass(SiegeManagerScreen, gui.ZScreen)
SiegeManagerScreen.ATTRS = {}

function SiegeManagerScreen:init()
    self:addviews({SiegeManager{}})
end

function SiegeManagerScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('requires a map to be loaded')
end

view = view and view:raise() or SiegeManagerScreen{}:show()

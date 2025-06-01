--@module = true

local gui = require("gui")
local json = require('json')
local overlay = require('plugins.overlay')
local presets = reqscript('internal/manipulator/presets')
local textures = require('gui.textures')
local utils = require('utils')
local widgets = require("gui.widgets")

------------------------
-- persistent state
--

local GLOBAL_KEY = 'manipulator'
local CONFIG_FILE = 'dfhack-config/manipulator.json'

-- persistent player (global) state schema
local function get_default_config()
    return {
        tags={},
        presets={},
    }
end

-- persistent per-fort state schema
local function get_default_state()
    return {
        favorites={},
        tagged={},
    }
end

-- preset schema
local function get_default_preset()
    return {
        cols={},
        pinned={},
    }
end

local function get_config()
    local data = get_default_config()
    local cfg = json.open(CONFIG_FILE)
    utils.assign(data, cfg.data)
    cfg.data = data
    return cfg
end

config = config or get_config()
state = state or get_default_state()
preset = preset or get_default_preset()

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        state = get_default_state()
        return
    end
    if sc ~= SC_MAP_LOADED or not dfhack.world.isFortressMode() then
        return
    end
    state = get_default_state()
    utils.assign(state, dfhack.persistent.getSiteData(GLOBAL_KEY, state))
end

------------------------
-- ColumnMenu
--

ColumnMenu = defclass(ColumnMenu, widgets.Panel)
ColumnMenu.ATTRS{
    frame_style=gui.FRAME_INTERIOR,
    frame_background=gui.CLEAR_PEN,
    visible=false,
    col=DEFAULT_NIL,
}

function ColumnMenu:init()
    local choices = {}

    table.insert(choices, {
        text='Sort',
        fn=self.col:callback('sort', true),
    })
    table.insert(choices, {
        text='Hide column',
        fn=self.col:callback('hide_column'),
    })
    table.insert(choices, {
        text='Hide group',
        fn=self.col:callback('hide_group'),
    })
    if self.col.zoom_fn then
        table.insert(choices, {
            text='Zoom to',
            fn=self.col.zoom_fn,
        })
    end

    self:addviews{
        widgets.List{
            choices=choices,
            on_submit=function(_, choice)
                choice.fn()
                self:hide()
            end,
        },
    }
end

function ColumnMenu:show()
    self.prev_focus_owner = self.focus_group.cur
    self.visible = true
    self:setFocus(true)
end

function ColumnMenu:hide()
    self.visible = false
    if self.prev_focus_owner then
        self.prev_focus_owner:setFocus(true)
    end
end

function ColumnMenu:onInput(keys)
    if ColumnMenu.super.onInput(self, keys) then
        return true
    end
    if keys._MOUSE_R then
        self:hide()
    elseif keys._MOUSE_L and not self:getMouseFramePos() then
        self:hide()
    end
    return true
end

------------------------
-- Column
--

local DEFAULT_DATA_WIDTH = 4
local DEFAULT_COL_OVERSCAN = 14

Column = defclass(Column, widgets.Panel)
Column.ATTRS{
    label=DEFAULT_NIL,
    group='',
    label_inset=0,
    data_width=DEFAULT_DATA_WIDTH,
    hidden=DEFAULT_NIL,
    shared=DEFAULT_NIL,
    data_fn=DEFAULT_NIL,
    count_fn=DEFAULT_NIL,
    cmp_fn=DEFAULT_NIL,
    choice_fn=DEFAULT_NIL,
    zoom_fn=DEFAULT_NIL,
}

local CH_DOT = string.char(15)
local CH_UP = string.char(30)
local CH_DN = string.char(31)

function Column:init()
    self.frame = utils.assign({t=0, b=0, l=0, w=DEFAULT_COL_OVERSCAN}, self.frame or {})

    local function show_menu()
        self.subviews.col_menu:show()
    end

    self:addviews{
        widgets.TextButton{
            view_id='col_group',
            frame={t=0, l=0, h=1, w=#self.group+2},
            label=self.group,
            visible=#self.group > 0,
        },
        widgets.Label{
            view_id='col_current',
            frame={t=7, l=1+self.label_inset, w=4},
            auto_height=false,
        },
        widgets.Label{
            view_id='col_total',
            frame={t=8, l=1+self.label_inset, w=4},
            auto_height=false,
        },
        widgets.List{
            view_id='col_list',
            frame={t=10, l=0, w=self.data_width+2}, -- +2 for the invisible scrollbar
            on_submit=self:callback('on_select'),
        },
        widgets.Panel{
            frame={t=2, l=0, h=10},
            subviews={
                widgets.Divider{
                    view_id='col_stem',
                    frame={l=self.label_inset, t=4, w=1, h=1},
                    frame_style=gui.FRAME_INTERIOR,
                    frame_style_b=false,
                },
                widgets.Panel{
                    view_id='col_label',
                    frame={l=self.label_inset, t=4},
                    subviews={
                        widgets.HotkeyLabel{
                            frame={l=0, t=0, w=1},
                            label=CH_DN,
                            text_pen=COLOR_LIGHTGREEN,
                            on_activate=show_menu,
                            visible=function()
                                local sort_spec = self.shared.sort_stack[#self.shared.sort_stack]
                                return sort_spec.col == self and not sort_spec.rev
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={l=0, t=0, w=1},
                            label=CH_UP,
                            text_pen=COLOR_LIGHTGREEN,
                            on_activate=show_menu,
                            visible=function()
                                local sort_spec = self.shared.sort_stack[#self.shared.sort_stack]
                                return sort_spec.col == self and sort_spec.rev
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={l=0, t=0, w=1},
                            label=CH_DOT,
                            text_pen=COLOR_GRAY,
                            on_activate=show_menu,
                            visible=function()
                                local sort_spec = self.shared.sort_stack[#self.shared.sort_stack]
                                return sort_spec.col ~= self
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={l=1, t=0},
                            label=self.label,
                            on_activate=self:callback('on_click'),
                        },
                        ColumnMenu{
                            view_id='col_menu',
                            frame={l=0, t=1, h=self.zoom_fn and 6 or 5},
                            col=self,
                        },
                    },
                },
            },
        },
    }

    self.subviews.col_list.scrollbar.visible = false
    self.col_data = {}
    self.dirty = true
end

-- extended by subclasses
function Column:on_select(idx, choice)
    -- conveniently, this will be nil for the namelist column itself,
    -- avoiding an infinite loop
    local namelist = self.parent_view.parent_view.namelist
    if namelist then
        self.shared.set_cursor_col_fn(self)
        namelist:setSelected(idx)
    end
end

function Column:hide_column()
    self.hidden = true
    self.shared.refresh_headers = true
end

function Column:unhide_column()
    self.hidden = false
    self.shared.refresh_headers = true
end

function Column:hide_group()
    for _,col in ipairs(self.parent_view.subviews) do
        if col.group == self.group then
            col.hidden = true
        end
    end
    self.shared.refresh_headers = true
end

function Column:on_click()
    local modifiers = dfhack.internal.getModifiers()
    if modifiers.shift then
        self:hide_group()
    elseif modifiers.ctrl then
        self:hide_column()
    else
        self:sort(true)
    end
end

function Column:sort(make_primary)
    local sort_stack = self.shared.sort_stack
    if make_primary then
        -- we are newly sorting by this column: reverse sort if we're already on top of the
        -- stack; otherwise put us on top of the stack
        local top = sort_stack[#sort_stack]
        if top.col == self then
            top.rev = not top.rev
        else
            for idx,sort_spec in ipairs(sort_stack) do
                if sort_spec.col == self then
                    table.remove(sort_stack, idx)
                    break
                end
            end
            table.insert(sort_stack, {col=self, rev=false})
        end
    end
    for _,sort_spec in ipairs(sort_stack) do
        local col = sort_spec.col
        if col.dirty then
            col:refresh()
        end
    end
    local compare = function(a, b)
        for idx=#sort_stack,1,-1 do
            local sort_spec = sort_stack[idx]
            local col = sort_spec.col
            local first, second
            if sort_spec.rev then
                first, second = col.col_data[b], col.col_data[a]
            else
                first, second = col.col_data[a], col.col_data[b]
            end
            if first == second then goto continue end
            if not first then return 1 end
            if not second then return -1 end
            local ret = (col.cmp_fn or utils.compare)(first, second)
            if ret ~= 0 then return ret end
            ::continue::
        end
        return 0
    end
    local order = utils.tabulate(function(i) return i end, 1, #self.shared.filtered_unit_ids)
    local spec = {compare=compare}
    self.shared.sort_order = utils.make_sort_order(order, {spec})
end

function Column:get_units()
    if self.shared.cache.units then return self.shared.cache.units end
    local units = {}
    for _, unit_id in ipairs(self.shared.unit_ids) do
        local unit = df.unit.find(unit_id)
        if unit then
            table.insert(units, unit)
        else
            self.shared.fault = true
        end
    end
    self.shared.cache.units = units
    return units
end

function Column:get_sorted_unit_id(idx)
    return self.shared.filtered_unit_ids[self.shared.sort_order[idx]]
end

function Column:get_sorted_data(idx)
    return self.col_data[self.shared.sort_order[idx]]
end

function Column:refresh()
    local col_data, choices = {}, {}
    local current, total = 0, 0
    local next_id_idx = 1
    for _, unit in ipairs(self:get_units()) do
        local data = self.data_fn(unit)
        local val = self.count_fn(data)
        if unit.id == self.shared.filtered_unit_ids[next_id_idx] then
            local idx = next_id_idx
            table.insert(col_data, data)
            table.insert(choices, self.choice_fn(function() return self:get_sorted_data(idx) end))
            current = current + val
            next_id_idx = next_id_idx + 1
        end
        total = total + val
    end

    self.col_data = col_data
    self.subviews.col_current:setText(tostring(current))
    self.subviews.col_total:setText(tostring(total))
    self.subviews.col_list:setChoices(choices)

    self.dirty = false
end

function Column:render(dc)
    if self.dirty then
        self:refresh()
    end
    Column.super.render(self, dc)
end

function Column:set_stem_height(h)
    self.subviews.col_label.frame.t = 4 - h
    self.subviews.col_stem.frame.t = 4 - h
    self.subviews.col_stem.frame.h = h + 1
end

------------------------
-- DataColumn
--

local function data_cmp(a, b)
    if type(a) == 'number' then return -utils.compare(a, b) end
    return utils.compare(a, b)
end

local function data_count(data)
    if not data then return 0 end
    if type(data) == 'number' then return data > 0 and 1 or 0 end
    return 1
end

local function data_choice(get_ordered_data_fn)
    return {
        text={
            {
                text=function()
                    local ordered_data = get_ordered_data_fn()
                    return (not ordered_data or ordered_data == 0) and '-' or tostring(ordered_data)
                end,
            },
        },
    }
end

DataColumn = defclass(DataColumn, Column)
DataColumn.ATTRS{
    cmp_fn=data_cmp,
    count_fn=data_count,
    choice_fn=data_choice,
}

------------------------
-- ToggleColumn
--

local ENABLED_PEN_LEFT = dfhack.pen.parse{fg=COLOR_CYAN,
        tile=curry(textures.tp_control_panel, 1), ch=string.byte('[')}
local ENABLED_PEN_CENTER = dfhack.pen.parse{fg=COLOR_LIGHTGREEN,
        tile=curry(textures.tp_control_panel, 2) or nil, ch=251} -- check
local ENABLED_PEN_RIGHT = dfhack.pen.parse{fg=COLOR_CYAN,
        tile=curry(textures.tp_control_panel, 3) or nil, ch=string.byte(']')}
local DISABLED_PEN_LEFT = dfhack.pen.parse{fg=COLOR_CYAN,
        tile=curry(textures.tp_control_panel, 4) or nil, ch=string.byte('[')}
local DISABLED_PEN_CENTER = dfhack.pen.parse{fg=COLOR_RED,
        tile=curry(textures.tp_control_panel, 5) or nil, ch=string.byte('x')}
local DISABLED_PEN_RIGHT = dfhack.pen.parse{fg=COLOR_CYAN,
        tile=curry(textures.tp_control_panel, 6) or nil, ch=string.byte(']')}

local function toggle_count(data)
    return data and 1 or 0
end

local function toggle_choice(get_ordered_data_fn)
    local function get_enabled_button_token(enabled_tile, disabled_tile)
        return {
            tile=function() return get_ordered_data_fn() and enabled_tile or disabled_tile end,
        }
    end
    return {
        text={
            get_enabled_button_token(ENABLED_PEN_LEFT, DISABLED_PEN_LEFT),
            get_enabled_button_token(ENABLED_PEN_CENTER, DISABLED_PEN_CENTER),
            get_enabled_button_token(ENABLED_PEN_RIGHT, DISABLED_PEN_RIGHT),
            ' ',
        },
    }
end

local function toggle_sorted_vec_data(vec, unit)
    return utils.binsearch(vec, unit.id) and true or false
end

local function toggle_sorted_vec(vec, unit_id, prev_val)
    if prev_val then
        utils.erase_sorted(vec, unit_id)
    else
        utils.insert_sorted(vec, unit_id)
    end
end

ToggleColumn = defclass(ToggleColumn, Column)
ToggleColumn.ATTRS{
    count_fn=toggle_count,
    choice_fn=toggle_choice,
    toggle_fn=DEFAULT_NIL,
}

function ToggleColumn:on_select(idx, choice)
    ToggleColumn.super.on_select(self, idx, choice)
    if not self.toggle_fn then return end
    local unit_id = self:get_sorted_unit_id(idx)
    local prev_val = self:get_sorted_data(idx)
    self.toggle_fn(unit_id, prev_val)
    self.dirty = true
end

------------------------
-- Cols
--

Cols = defclass(Cols, widgets.Panel)

function Cols:renderSubviews(dc)
    -- allow labels of columns to the left to overwrite the stems of columns on the right
    for idx=#self.subviews,1,-1 do
        local child = self.subviews[idx]
        if utils.getval(child.visible) then
            child:render(dc)
        end
    end
    -- but group labels and popup menus on the right should overwrite long group names on the left
    for _,child in ipairs(self.subviews) do
        if utils.getval(child.visible) then
            if utils.getval(child.subviews.col_group.visible) then
                child.subviews.col_group:render(dc)
            end
            if utils.getval(child.subviews.col_menu.visible) then
                child:render(dc)
            end
        end
    end
end

------------------------
-- Spreadsheet
--

Spreadsheet = defclass(Spreadsheet, widgets.Panel)
Spreadsheet.ATTRS{
    get_units_fn=DEFAULT_NIL,
}

local function get_workshop_label(workshop, type_enum, bld_defs)
    if #workshop.name > 0 then
        return workshop.name
    end
    local type_name = type_enum[workshop.type]
    if type_name == 'Custom' then
        local bld_def = bld_defs[workshop.custom_type]
        if bld_def then return bld_def.code end
    end
    return type_name
end

function Spreadsheet:init()
    self.left_col = 1
    self.prev_filter = ''

    self.shared = {
        unit_ids={},
        filtered_unit_ids={},
        sort_stack={},
        sort_order={},  -- list of indices into filtered_unit_ids (or cache.filtered_units)
        cache={},       -- cached pointers; reset at end of frame
        cursor_col=nil,
        set_cursor_col_fn=self:callback('set_cursor_col'),
        refresh_units=true,
        refresh_headers=true,
    }

    local goals_by_type = {}
    goals_by_type[df.goal_type.MAINTAIN_ENTITY_STATUS]      = { value = 1, name = "--------", pen = COLOR_BROWN, pen_achieved = COLOR_YELLOW }
    goals_by_type[df.goal_type.STAY_ALIVE]                  = { value = 2, name = "Alive", pen = COLOR_BROWN, pen_achieved = COLOR_YELLOW }
    goals_by_type[df.goal_type.BATHE_WORLD_IN_CHAOS]        = { value = 3, name = "Chaos", pen = COLOR_BROWN, pen_achieved = COLOR_YELLOW }
    goals_by_type[df.goal_type.RULE_THE_WORLD]              = { value = 4, name = "Rule Wld", pen = COLOR_BROWN, pen_achieved = COLOR_YELLOW }
    goals_by_type[df.goal_type.BRING_PEACE_TO_THE_WORLD]    = { value = 5, name = "Peace", pen = COLOR_BROWN, pen_achieved = COLOR_YELLOW }
    goals_by_type[df.goal_type.SEE_THE_GREAT_NATURAL_SITES] = { value = 6, name = "Travel", pen = COLOR_BROWN, pen_achieved = COLOR_YELLOW }
    goals_by_type[df.goal_type.IMMORTALITY]                 = { value = 7, name = "Immortal", pen = COLOR_RED, pen_achieved = COLOR_GREEN }
    goals_by_type[df.goal_type.ATTAIN_RANK_IN_SOCIETY]      = { value = 8, name = "Rank", pen = COLOR_RED, pen_achieved = COLOR_GREEN }
    goals_by_type[df.goal_type.FALL_IN_LOVE]                = { value = 9, name = "Love", pen = COLOR_RED, pen_achieved = COLOR_GREEN }
    goals_by_type[df.goal_type.START_A_FAMILY]              = { value = 10, name = "Family", pen = COLOR_RED, pen_achieved = COLOR_GREEN }
    goals_by_type[df.goal_type.MAKE_A_GREAT_DISCOVERY]      = { value = 11, name = "Discvry"..string.char(15), pen = COLOR_LIGHTRED, pen_achieved = COLOR_LIGHTGREEN }
    goals_by_type[df.goal_type.BECOME_A_LEGENDARY_WARRIOR]  = { value = 12, name = "Warrior"..string.char(15), pen = COLOR_LIGHTRED, pen_achieved = COLOR_LIGHTGREEN }
    goals_by_type[df.goal_type.MASTER_A_SKILL]              = { value = 13, name = "Skill"..string.char(15), pen = COLOR_LIGHTRED, pen_achieved = COLOR_LIGHTGREEN }
    goals_by_type[df.goal_type.CREATE_A_GREAT_WORK_OF_ART]  = { value = 14, name = "Art"..string.char(15), pen = COLOR_LIGHTRED, pen_achieved = COLOR_LIGHTGREEN }
    goals_by_type[df.goal_type.CRAFT_A_MASTERWORK]          = { value = 15, name = "Craft"..string.char(15), pen = COLOR_LIGHTRED, pen_achieved = COLOR_LIGHTGREEN }

    local goals_by_value = {}
    for _, v in ipairs(goals_by_type) do
        goals_by_value[v.value] = v
    end


    local cols = Cols{}
    self.cols = cols

    cols:addviews{
        ToggleColumn{
            view_id='favorites',
            group='tags',
            label='Favorites',
            shared=self.shared,
            data_fn=curry(toggle_sorted_vec_data, state.favorites),
            toggle_fn=function(unit_id, prev_val)
                toggle_sorted_vec(state.favorites, unit_id, prev_val)
                persist_state()
            end,
        },
        DataColumn{
            view_id='stress',
            group='summary',
            label='Stress',
            shared=self.shared,
            data_fn=function(unit) return unit.status.current_soul.personality.stress end,
            choice_fn=function(get_ordered_data_fn)
                return {
                    text={
                        {
                            text=function()
                                local ordered_data = get_ordered_data_fn()
                                if ordered_data > 99999 then
                                    return '>99k'
                                elseif ordered_data > 9999 then
                                    return ('%3dk'):format(ordered_data // 1000)
                                elseif ordered_data < -99999 then
                                    return ' -' .. string.char(236)  -- -∞
                                elseif ordered_data < -999 then
                                    return ('%3dk'):format(-(-ordered_data // 1000))
                                end
                                return ('%4d'):format(ordered_data)
                            end,
                            pen=function()
                                local ordered_data = get_ordered_data_fn()
                                local level = dfhack.units.getStressCategoryRaw(ordered_data)
                                local is_graphics = dfhack.screen.inGraphicsMode()
                                -- match colors of stress faces depending on mode
                                if level == 0 then return COLOR_RED end
                                if level == 1 then return COLOR_LIGHTRED end
                                if level == 2 then return is_graphics and COLOR_BROWN or COLOR_YELLOW end
                                if level == 3 then return is_graphics and COLOR_YELLOW or COLOR_WHITE end
                                if level == 4 then return is_graphics and COLOR_CYAN or COLOR_GREEN end
                                if level == 5 then return is_graphics and COLOR_GREEN or COLOR_LIGHTGREEN end
                                return is_graphics and COLOR_LIGHTGREEN or COLOR_LIGHTCYAN
                            end,
                        },
                    },
                }
            end,
        },
        DataColumn{
            view_id='arrival',
            group='summary',
            label='Arrival',
            shared=self.shared,
            data_fn=function(unit) return unit.curse.interaction.time_on_site end,
            choice_fn=function(get_ordered_data_fn)
                return {
                    text={
                        {
                            text=function()
                                local ordered_data = get_ordered_data_fn()
                                local days = ordered_data // 1200
                                local months = days // 28
                                local years = months // 12
                                if years > 9 then
                                    return ('%3dy'):format(years)
                                elseif years > 0 and (months % 12) > 9 then
                                    return ('%dy%d'):format(years, months % 12)
                                elseif years > 0 then
                                    return ('%dy%dm'):format(years, months % 12)
                                elseif months > 9 then
                                    return ('%dm'):format(months)
                                elseif days > 28 then
                                    return ('%dm%d'):format(months, days % 28)
                                else
                                    return ('%dd'):format(days)
                                end
                            end,
                            pen=function()
                                local ordered_data = get_ordered_data_fn()
                                local days = ordered_data // 1200
                                local months = days // 28
                                local years = months // 12
                                if years > 9 then return COLOR_LIGHTCYAN end
                                if years > 4 then return COLOR_LIGHTGREEN end
                                if years > 0 then return COLOR_GREEN end
                                if months > 5 then return COLOR_WHITE end
                                if months > 2 then return COLOR_YELLOW end
                                if days > 28 then return COLOR_LIGHTRED end
                                return COLOR_RED
                            end,
                        },
                    },
                }
            end,
        },
        DataColumn{
            view_id='goal',
            group='summary',
            label='Goal',
            shared=self.shared,
            data_width=8,
            data_fn=function(unit)
                local goal = #unit.status.current_soul.personality.dreams > 0 and unit.status.current_soul.personality.dreams[0].type or df.goal_type.MAINTAIN_ENTITY_STATUS
                local isAchieved = #unit.status.current_soul.personality.dreams > 0 and unit.status.current_soul.personality.dreams[0].flags.accomplished and 1 or -1
                return isAchieved * (goals_by_type[goal].value or 1)
            end,
            choice_fn=function(get_ordered_data_fn)
                return {
                    text={
                        {
                            text=function()
                                local ordered_data = get_ordered_data_fn()
                                local goal_index = math.abs(ordered_data)
                                return goals_by_value[goal_index].name
                            end,
                            pen=function()
                                local ordered_data = get_ordered_data_fn()
                                local isAchieved = ordered_data > 0
                                local goal_index = math.abs(ordered_data)
                                return isAchieved and goals_by_value[goal_index].pen_achieved or goals_by_value[goal_index].pen
                            end,
                        },
                    },
                }
            end,
        }
    }

    for i in ipairs(df.job_skill) do
        local caption = df.job_skill.attrs[i].caption
        if caption then
            cols:addviews{
                DataColumn{
                    view_id=caption:lower(),
                    group='skills',
                    label=caption,
                    shared=self.shared,
                    data_fn=function(unit)
                        return (utils.binsearch(unit.status.current_soul.skills, i, 'id') or {rating=0}).rating
                    end,
                }
            }
        end
    end

    local work_details = df.global.plotinfo.labor_info.work_details
    for _, wd in ipairs(work_details) do
        cols:addviews{
            ToggleColumn{
                view_id=wd.name:lower(),
                group='work details',
                label=wd.name,
                shared=self.shared,
                data_fn=curry(toggle_sorted_vec_data, wd.assigned_units),
                toggle_fn=function(unit_id, prev_val)
                    toggle_sorted_vec(wd.assigned_units, unit_id, prev_val)
                    local unit = df.unit.find(unit_id)
                    if unit then dfhack.units.setAutomaticProfessions(unit) end
                end,
            }
        }
    end

    local function add_workshops(vec, type_enum, type_defs)
        for _, bld in ipairs(vec) do
            cols:addviews{
                ToggleColumn{
                    view_id=get_workshop_label(bld, type_enum, type_defs):lower(),
                    group='workshops',
                    label=get_workshop_label(bld, type_enum, type_defs),
                    shared=self.shared,
                    data_fn=curry(toggle_sorted_vec_data, bld.profile.permitted_workers),
                    toggle_fn=function(unit_id, prev_val)
                        if not prev_val then
                            -- there can be only one
                            bld.profile.permitted_workers:resize(0)
                        end
                        toggle_sorted_vec(bld.profile.permitted_workers, unit_id, prev_val)
                    end,
                    zoom_fn=function()
                        dfhack.gui.revealInDwarfmodeMap(
                            xyz2pos(bld.centerx, bld.centery, bld.z), true, true)
                    end,
                }
            }
        end
    end
    add_workshops(df.global.world.buildings.other.FURNACE_ANY, df.furnace_type, df.global.world.raws.buildings.furnaces)
    add_workshops(df.global.world.buildings.other.WORKSHOP_ANY, df.workshop_type, df.global.world.raws.buildings.workshops)

    self:addviews{
        widgets.TextButton{
            view_id='left_group',
            frame={t=1, l=0, h=1},
            key='CUSTOM_CTRL_Y',
            visible=false,
        },
        widgets.TextButton{
            view_id='right_group',
            frame={t=1, r=0, h=1},
            key='CUSTOM_CTRL_T',
            visible=false,
        },
        widgets.Label{
            frame={t=7, l=0},
            text='Shown:',
        },
        widgets.Label{
            frame={t=8, l=0},
            text='Total:',
        },
        DataColumn{
            view_id='name',
            frame={w=45},
            label='Name',
            label_inset=8,
            data_fn=dfhack.units.getReadableName,
            data_width=45,
            shared=self.shared,
        },
        cols,
    }

    -- teach each column about its relative position so we can track cursor movement
    for idx, col in ipairs(cols) do
        col.idx = idx
    end

    -- set up initial sort: primary favorites, secondary name
    self.shared.sort_stack[1] = {col=self.subviews.name, rev=false}
    self.shared.sort_stack[2] = {col=self.subviews.favorites, rev=false}

    -- set initial keyboard cursor position
    self:set_cursor_col(self.subviews.favorites)

    self.namelist = self.subviews.name.subviews.col_list
    self:addviews{
            widgets.Scrollbar{
            view_id='scrollbar',
            frame={t=7, r=0},
            on_scroll=self.namelist:callback('on_scrollbar'),
        }
    }
    self.namelist.scrollbar = self.subviews.scrollbar
    self.namelist:setFocus(true)
end

local CURSOR_PEN = dfhack.pen.parse{fg=COLOR_GREY, bg=COLOR_CYAN}

function Spreadsheet:set_cursor_col(col)
    if self.shared.cursor_col then
        self.shared.cursor_col.subviews.col_list.cursor_pen = COLOR_LIGHTCYAN
    end
    self.shared.cursor_col = col
    col.subviews.col_list.cursor_pen = CURSOR_PEN
end

function Spreadsheet:zoom_to_unit()
    local idx = self.namelist:getSelected()
    if not idx then return end
    local unit = df.unit.find(self.subviews.name:get_sorted_unit_id(idx))
    if not unit then return end
    dfhack.gui.revealInDwarfmodeMap(
        xyz2pos(dfhack.units.getPosition(unit)), true, true)
end

function Spreadsheet:zoom_to_col_source()
    if not self.shared.cursor_col or not self.shared.cursor_col.zoom_fn then return end
    self.shared.cursor_col.zoom_fn()
end

function Spreadsheet:sort_by_current_col()
    if not self.shared.cursor_col then return end
    self.shared.cursor_col:sort(true)
end

function Spreadsheet:hide_current_col()
    if not self.shared.cursor_col then return end
    self.shared.cursor_col:hide_column()
end

function Spreadsheet:hide_current_col_group()
    if not self.shared.cursor_col then return end
    self.shared.cursor_col:hide_group()
end

-- utf8-ize and, if needed, quote and escape
local function make_csv_cell(fmt, ...)
    local str = fmt:format(...)
    str = dfhack.df2utf(str)
    if str:find('[,"]') then
        str = str:gsub('"', '""')
        str = ('"%s"'):format(str)
    end
    return str
end

-- exports visible data, in the current sort, to a .csv file
function Spreadsheet:export()
    local file = io.open('manipulator.csv', 'a+')
    if not file then
        dfhack.printerr('could not open export file: manipulator.csv')
        return
    end
    file:write(make_csv_cell('%s,', self.subviews.name.label))
    for _, col in ipairs(self.cols.subviews) do
        if col.hidden then goto continue end
        file:write(make_csv_cell('%s/%s,', col.group, col.label))
        ::continue::
    end
    file:write(NEWLINE)
    for row=1,#self.shared.filtered_unit_ids do
        file:write(make_csv_cell('%s', self.subviews.name:get_sorted_data(row)))
        file:write(',')
        for _, col in ipairs(self.cols.subviews) do
            if col.hidden then goto continue end
            file:write(make_csv_cell('%s,', col:get_sorted_data(row) or ''))
            ::continue::
        end
        file:write(NEWLINE)
    end
    file:close()
end

function Spreadsheet:jump_to_group(group)
    for i, col in ipairs(self.cols.subviews) do
        if not col.hidden and col.group == group then
            self:jump_to_col(i)
            break
        end
    end
end

function Spreadsheet:jump_to_col(idx)
    idx = math.min(idx, #self.cols.subviews)
    idx = math.max(idx, 1)
    self.left_col = idx
    if self.cols.subviews[idx].hidden then
        local found = false
        for shifted_idx=self.left_col-1,1,-1 do
            if not self.cols.subviews[shifted_idx].hidden then
                self.left_col = shifted_idx
                found = true
                break
            end
        end
        if not found then
            for shifted_idx=self.left_col+1,#self.cols.subviews do
                if not self.cols.subviews[shifted_idx].hidden then
                    self.left_col = shifted_idx
                    break
                end
            end
        end
    end
    self:updateLayout()
end

function Spreadsheet:update_headers()
    local ord = 1
    for _, col in ipairs(self.cols.subviews) do
        if not col.hidden then
            col:set_stem_height((5-ord)%5)
            ord = ord + 1
        end
    end
    self.shared.refresh_headers = false
end

-- TODO: support column addressing for searching/filtering (e.g. "skills/Armoring:>10")
function Spreadsheet:refresh(filter, full_refresh)
    local shared = self.shared
    shared.fault = false
    self.subviews.name.dirty = true
    for _, col in ipairs(self.cols.subviews) do
        col.dirty = true
    end
    local incremental = not full_refresh and self.prev_filter and filter:startswith(self.prev_filter)
    if not incremental then
        local units = self.get_units_fn()
        shared.cache.units = units
        shared.unit_ids = utils.tabulate(function(idx) return units[idx].id end, 1, #units)
    end
    shared.filtered_unit_ids = copyall(shared.unit_ids)
    if #filter > 0 then
        local col = self.subviews.name
        col:refresh()
        for idx=#col.col_data,1,-1 do
            local data = col.col_data[idx]
            if (not utils.search_text(data, filter)) then
                table.remove(shared.filtered_unit_ids, idx)
            end
        end
        if #col.col_data ~= #shared.filtered_unit_ids then
            col.dirty = true
        end
    end
    shared.sort_stack[#shared.sort_stack].col:sort()
    self.shared.refresh_units = false
end

function Spreadsheet:update_col_layout(idx, col, width, group, max_width)
    col.visible = not col.hidden and idx >= self.left_col and width + col.frame.w <= max_width
    col.frame.l = width
    if not col.visible then
        return width, group
    end
    local col_group = col.subviews.col_group
    col_group.label.on_activate=self:callback('jump_to_group', col.group)
    col_group.visible = group ~= col.group
    return width + col.data_width + 1, col.group
end

function Spreadsheet:preUpdateLayout(parent_rect)
    local left_group, right_group = self.subviews.left_group, self.subviews.right_group
    left_group.visible, right_group.visible = false, false

    local width, group, cur_col_group = self.subviews.name.data_width + 1, '', ''
    local prev_col_group, next_col_group
    for idx, col in ipairs(self.cols.subviews) do
        local prev_group = group
        width, group = self:update_col_layout(idx, col, width, group, parent_rect.width)
        if col.hidden then goto continue end
        if not next_col_group and group ~= '' and not col.visible and col.group ~= cur_col_group then
            next_col_group = col.group
            local str = next_col_group .. string.char(26)  -- right arrow
            right_group.frame.w = #str + 10
            right_group.label.on_activate=self:callback('jump_to_group', next_col_group)
            right_group.visible = true
            right_group:setLabel(str)
        end
        if cur_col_group ~= col.group then
            prev_col_group = cur_col_group
        end
        cur_col_group = col.group
        if prev_group == '' and group ~= '' and prev_col_group and prev_col_group ~= '' then
            local str = string.char(27) .. prev_col_group  -- left arrow
            left_group.frame.w = #str + 10
            left_group.label.on_activate=self:callback('jump_to_group', prev_col_group)
            left_group.visible = true
            left_group:setLabel(str)
        end
        ::continue::
    end
    self.shared.layout_changed = false
end

function Spreadsheet:render(dc)
    if self.shared.refresh_headers or self.shared.refresh_units then
        if self.shared.refresh_units then
            self:refresh(self.prev_filter, true)
        end
        if self.shared.refresh_headers then
            self:update_headers()
        end
        if self.cols.subviews[self.left_col].hidden then
            self:jump_to_col(self.left_col)
        else
            self:updateLayout()
        end
    end
    local page_top = self.namelist.page_top
    local selected = self.namelist:getSelected()
    for _, col in ipairs(self.cols.subviews) do
        col.subviews.col_list.page_top = page_top
        col.subviews.col_list.selected = selected
    end
    Spreadsheet.super.render(self, dc)
    self.shared.cache = {}
end

function Spreadsheet:get_num_visible_cols()
    local rect = self.frame_rect
    if not rect then return 1 end
    local other_width = self.subviews.name.data_width + (DEFAULT_COL_OVERSCAN - DEFAULT_DATA_WIDTH)
    local width = rect.width - other_width
    return width // (DEFAULT_DATA_WIDTH + 1)
end

function Spreadsheet:onInput(keys)
    if keys.KEYBOARD_CURSOR_LEFT then
        self:jump_to_col(self.left_col-1)
    elseif keys.KEYBOARD_CURSOR_LEFT_FAST then
        local remaining = self:get_num_visible_cols()
        local target_col = self.left_col
        for idx=self.left_col-1,1,-1 do
            if not self.cols.subviews[idx].hidden then
                remaining = remaining - 1
                target_col = idx
                if remaining == 0 then
                    break
                end
            end
        end
        self:jump_to_col(target_col)
    elseif keys.KEYBOARD_CURSOR_RIGHT then
        for idx=self.left_col+1,#self.cols.subviews do
            if not self.cols.subviews[idx].hidden then
                self:jump_to_col(idx)
                break
            end
        end
    elseif keys.KEYBOARD_CURSOR_RIGHT_FAST then
        local remaining = self:get_num_visible_cols()
        local target_col = self.left_col
        for idx=self.left_col+1,#self.cols.subviews do
            if not self.cols.subviews[idx].hidden then
                remaining = remaining - 1
                target_col = idx
                if remaining == 0 then
                    break
                end
            end
        end
        self:jump_to_col(target_col)
    end
    return Spreadsheet.super.onInput(self, keys)
end

------------------------
-- QuickMenu
--

QuickMenu = defclass(QuickMenu, widgets.Panel)
QuickMenu.ATTRS{
    frame_style=gui.FRAME_INTERIOR,
    frame_background=gui.CLEAR_PEN,
    visible=false,
    multiselect=false,
    label=DEFAULT_NIL,
    choices_fn=DEFAULT_NIL,
}

function QuickMenu:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text=self.label,
        },
        widgets.FilteredList{
            view_id='list',
            frame={t=2, l=0, b=self.multiselect and 3 or 0},
            on_submit=function(_, choice)
                choice.fn()
                self:hide()
            end,
            on_submit2=self.multiselect and function(_, choice)
                choice.fn()
                local list = self.subviews.list
                local filter = list:getFilter()
                list:setChoices(self.choices_fn(), list:getSelected())
                list:setFilter(filter)
            end or nil,
        },
        widgets.Label{
            frame={b=1, l=0},
            text='Shift click to select multiple.',
            visible=self.multiselect,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key='CUSTOM_CTRL_N',
            label='Select all',
            visible=self.multiselect,
            on_activate=function()
                local list = self.subviews.list
                for _,choice in ipairs(list:getVisibleChoices()) do
                    choice.fn()
                end
                local filter = list:getFilter()
                list:setChoices(self.choices_fn(), list:getSelected())
                list:setFilter(filter)
            end,
        },
    }
end

function QuickMenu:show()
    self.prev_focus_owner = self.focus_group.cur
    self.visible = true
    local list = self.subviews.list
    list.edit:setText('')
    list.edit:setFocus(true)
    list:setChoices(self.choices_fn())
end

function QuickMenu:hide()
    self.visible = false
    if self.prev_focus_owner then
        self.prev_focus_owner:setFocus(true)
    end
end

function QuickMenu:onInput(keys)
    if ColumnMenu.super.onInput(self, keys) then
        return true
    end
    if keys._MOUSE_R then
        self:hide()
    elseif keys._MOUSE_L and not self:getMouseFramePos() then
        self:hide()
    end
    return true
end

------------------------
-- Manipulator
--

local REFRESH_MS = 1000

Manipulator = defclass(Manipulator, widgets.Window)
Manipulator.ATTRS{
    frame_title='Unit Overview and Manipulator',
    frame={w=110, h=40},
    frame_inset={t=1, l=1, r=1, b=0},
    resizable=true,
    resize_min={w=70, h=30},
}

function Manipulator:init()
    if dfhack.world.isFortressMode() then
        self.get_units_fn = dfhack.units.getCitizens
    elseif dfhack.world.isAdventureMode() then
        self.get_units_fn = qerror('get party members')
    else
        self.get_units_fn = function() return utils.clone(df.global.world.units.active) end
    end

    self.needs_refresh, self.prev_unit_count, self.prev_last_unit_id = false, 0, -1
    self:update_needs_refresh(true)

    self:addviews{
        widgets.EditField{
            view_id='search',
            frame={l=0, t=0},
            key='FILTER',
            label_text='Search: ',
            on_change=function(text) self.subviews.sheet:refresh(text, false) end,
            on_unfocus=function() self.subviews.sheet.namelist:setFocus(true) end,
        },
        widgets.Divider{
            frame={l=0, r=0, t=2, h=1},
            frame_style=gui.FRAME_INTERIOR,
            frame_style_l=false,
            frame_style_r=false,
        },
        Spreadsheet{
            view_id='sheet',
            frame={l=0, t=3, r=0, b=7},
            get_units_fn=self.get_units_fn,
        },
        widgets.Divider{
            frame={l=0, r=0, b=6, h=1},
            frame_style=gui.FRAME_INTERIOR,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Panel{
            frame={l=0, r=0, b=0, h=5},
            subviews={
                widgets.WrappedLabel{
                    frame={t=0, l=0},
                    text_to_wrap='Use arrow keys or middle click drag to navigate cells. Left click or ENTER to toggle cell.',
                },
                widgets.HotkeyLabel{
                    frame={b=2, l=0},
                    auto_width=true,
                    label='Sort/reverse sort',
                    key='CUSTOM_SHIFT_S',
                    on_activate=function() self.subviews.sheet:sort_by_current_col() end,
                },
                widgets.HotkeyLabel{
                    frame={b=2, l=22},
                    auto_width=true,
                    label='Jump to column',
                    key='CUSTOM_CTRL_G',
                    on_activate=function() self.subviews.quick_jump_menu:show() end,
                },
                widgets.HotkeyLabel{
                    frame={b=2, l=46},
                    auto_width=true,
                    label='Export to csv',
                    key='CUSTOM_SHIFT_E',
                    on_activate=function() self.subviews.sheet:export() end,
                },
                widgets.HotkeyLabel{
                    frame={b=1, l=0},
                    auto_width=true,
                    label='Hide column',
                    key='CUSTOM_SHIFT_H',
                    on_activate=function() self.subviews.sheet:hide_current_col() end,
                },
                widgets.HotkeyLabel{
                    frame={b=1, l=22},
                    auto_width=true,
                    label='Hide group',
                    key='CUSTOM_CTRL_H',
                    on_activate=function() self.subviews.sheet:hide_current_col_group() end,
                },
                widgets.HotkeyLabel{
                    frame={b=1, l=46},
                    auto_width=true,
                    label='Unhide column',
                    key='CUSTOM_SHIFT_U',
                    on_activate=function() self.subviews.unhide_menu:show() end,
                },
                widgets.HotkeyLabel{
                    frame={b=0, l=0},
                    auto_width=true,
                    label='Zoom to unit',
                    key='CUSTOM_SHIFT_Z',
                    on_activate=function() self.subviews.sheet:zoom_to_unit() end,
                },
                widgets.HotkeyLabel{
                    frame={b=0, l=22},
                    auto_width=true,
                    label='Zoom to source',
                    key='CUSTOM_CTRL_Z',
                    on_activate=function() self.subviews.sheet:zoom_to_col_source() end,
                },
                widgets.HotkeyLabel{
                    frame={b=0, l=46},
                    auto_width=true,
                    label=function()
                        return self.needs_refresh and 'Refresh units (new units have arrived)' or 'Refresh units'
                    end,
                    text_pen=function()
                        return self.needs_refresh and COLOR_LIGHTRED or COLOR_WHITE
                    end,
                    key='CUSTOM_SHIFT_R',
                    on_activate=function()
                        self.subviews.sheet:refresh(self.subviews.search.text, true)
                    end,
                },
            },
        },
        QuickMenu{
            view_id='quick_jump_menu',
            frame={b=0, w=35, h=25},
            label='Jump to column:',
            choices_fn=function()
                local choices = {}
                for idx,col in ipairs(self.subviews.sheet.cols.subviews) do
                    if col.hidden then goto continue end
                    table.insert(choices, {
                        text=('%s/%s'):format(col.group, col.label),
                        fn=function() self.subviews.sheet:jump_to_col(idx) end,
                    })
                    ::continue::
                end
                return choices
            end,
        },
        QuickMenu{
            view_id='unhide_menu',
            frame={b=0, w=35, h=25},
            multiselect=true,
            label='Unhide column:',
            choices_fn=function()
                local choices = {}
                for idx,col in ipairs(self.subviews.sheet.cols.subviews) do
                    if not col.hidden then goto continue end
                    table.insert(choices, {
                        text=('%s/%s'):format(col.group, col.label),
                        fn=function() self.subviews.sheet.cols.subviews[idx]:unhide_column() end,
                    })
                    ::continue::
                end
                return choices
            end,
        },
    }
end

function Manipulator:update_needs_refresh(initialize)
    self.next_refresh_ms = dfhack.getTickCount() + REFRESH_MS

    local units = self.get_units_fn()
    local unit_count = #units
    if unit_count ~= self.prev_unit_count then
        self.needs_refresh = true
        self.prev_unit_count = unit_count
    end
    if unit_count <= 0 then
        self.prev_last_unit_id = -1
    else
        local last_unit_id = units[#units]
        if last_unit_id ~= self.prev_last_unit_id then
            self.needs_refresh = true
            self.prev_last_unit_id = last_unit_id
        end
    end
    if initialize then
        self.needs_refresh = false
    end
end

function Manipulator:render(dc)
    if self.next_refresh_ms <= dfhack.getTickCount() then
        self:update_needs_refresh()
    end
    Manipulator.super.render(self, dc)
end

------------------------
-- ManipulatorScreen
--

ManipulatorScreen = defclass(ManipulatorScreen, gui.ZScreen)
ManipulatorScreen.ATTRS{
    focus_path='manipulator',
}

function ManipulatorScreen:init()
    self:addviews{Manipulator{}}
end

function ManipulatorScreen:onDismiss()
    view = nil
end

------------------------
-- ManipulatorOverlay
--

ManipulatorOverlay = defclass(ManipulatorOverlay, overlay.OverlayWidget)
ManipulatorOverlay.ATTRS{
    desc='Adds a hotkey to the vanilla units screen to launch the DFHack units interface.',
    default_pos={x=50, y=-6},
    default_enabled=true,
    viewscreens='dwarfmode/Info/CREATURES/CITIZEN',
    frame={w=35, h=1},
}

function ManipulatorOverlay:init()
    self:addviews{
        widgets.TextButton{
            frame={t=0, l=0},
            label='DFHack citizen management',
            key='CUSTOM_CTRL_N',
            on_activate=function() dfhack.run_script('gui/manipulator') end,
        },
    }
end

--
-- disable overlay widget while tool is still in dark launch mode
--
-- OVERLAY_WIDGETS = {
--     launcher=ManipulatorOverlay,
-- }

if dfhack_flags.module then return end

if not dfhack.isMapLoaded() then
    qerror("This script requires a map to be loaded")
end

view = view and view:raise() or ManipulatorScreen{}:show()

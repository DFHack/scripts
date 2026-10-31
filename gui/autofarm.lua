-- GUI for managing autofarm crop thresholds and enabled state

local dlg = require('gui.dialogs')
local gui = require('gui')
local plugin = require('plugins.autofarm')
local widgets = require('gui.widgets')

local CH_UP = string.char(30)
local CH_DN = string.char(31)

Autofarm = defclass(Autofarm, widgets.Window)
Autofarm.ATTRS{
    frame_title='Autofarm',
    frame={w=62, h=25},
    frame_inset={t=1},
    resizable=true,
}

local function sort_noop(a, b)
    -- this function is used as a marker and never actually gets called
    error('sort_noop should not be called')
end

local function sort_by_name_desc(a, b)
    return a.data.name < b.data.name
end

local function sort_by_name_asc(a, b)
    return a.data.name > b.data.name
end

local function sort_by_stock_desc(a, b)
    if a.data.stock == b.data.stock then
        return sort_by_name_desc(a, b)
    end
    return a.data.stock > b.data.stock
end

local function sort_by_stock_asc(a, b)
    if a.data.stock == b.data.stock then
        return sort_by_name_desc(a, b)
    end
    return a.data.stock < b.data.stock
end

local function sort_by_threshold_desc(a, b)
    if a.data.threshold == b.data.threshold then
        return sort_by_name_desc(a, b)
    end
    return a.data.threshold > b.data.threshold
end

local function sort_by_threshold_asc(a, b)
    if a.data.threshold == b.data.threshold then
        return sort_by_name_desc(a, b)
    end
    return a.data.threshold < b.data.threshold
end

function Autofarm:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=1, t=0, w=31},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='Name'..CH_DN, value=sort_by_name_desc},
                {label='Name'..CH_UP, value=sort_by_name_asc},
                {label='Stock'..CH_DN, value=sort_by_stock_desc},
                {label='Stock'..CH_UP, value=sort_by_stock_asc},
                {label='Threshold'..CH_DN, value=sort_by_threshold_desc},
                {label='Threshold'..CH_UP, value=sort_by_threshold_asc},
            },
            initial_option=sort_by_name_desc,
            on_change=self:callback('refresh', 'sort'),
        },
        widgets.ToggleHotkeyLabel{
            view_id='hide_stocked',
            frame={t=0, l=34, w=31},
            key='CUSTOM_CTRL_H',
            label='Show only below threshold:',
            on_change=self:callback('refresh', 'sort'),
        },
        widgets.Panel{
            view_id='list_panel',
            frame={t=2, l=0, r=0, b=6},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='sort_name',
                    frame={t=0, l=0, w=5},
                    options={
                        {label='Name', value=sort_noop},
                        {label='Name'..CH_DN, value=sort_by_name_desc},
                        {label='Name'..CH_UP, value=sort_by_name_asc},
                    },
                    initial_option=sort_by_name_desc,
                    option_gap=0,
                    on_change=self:callback('refresh', 'sort_name'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_stock',
                    frame={t=0, r=14, w=6},
                    options={
                        {label='Stock', value=sort_noop},
                        {label='Stock'..CH_DN, value=sort_by_stock_desc},
                        {label='Stock'..CH_UP, value=sort_by_stock_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh', 'sort_stock'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_threshold',
                    frame={t=0, r=3, w=9},
                    options={
                        {label='Threshold', value=sort_noop},
                        {label='Threshold'..CH_DN, value=sort_by_threshold_desc},
                        {label='Threshold'..CH_UP, value=sort_by_threshold_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh', 'sort_threshold'),
                },
                widgets.Label{
                    view_id='disabled_warning',
                    visible=function() return not plugin.isEnabled() end,
                    frame={t=3, h=1},
                    auto_width=true,
                    text={'Please enable autofarm to change settings'},
                    text_pen=COLOR_YELLOW
                },
                widgets.List{
                    view_id='list',
                    frame={t=2, b=0},
                    visible=plugin.isEnabled,
                    on_double_click=self:callback('prompt_for_new_threshold'),
                },
            },
        },
        widgets.Panel{
            view_id='footer',
            frame={l=1, r=1, b=0, h=5},
            subviews={
                widgets.Label{
                    view_id='excluded_farms',
                    frame={t=0, l=0},
                },
                widgets.Label{
                    frame={t=1, l=0},
                    text={
                        'Double click on a row or hit ',
                        {text='Enter', pen=COLOR_LIGHTGREEN},
                        ' to set the threshold.',
                    },
                },
                widgets.ToggleHotkeyLabel{
                    view_id='enable_toggle',
                    frame={t=3, l=0, w=27},
                    label='Autofarm is',
                    key='CUSTOM_CTRL_E',
                    options={{value=true, label='Enabled', pen=COLOR_GREEN},
                             {value=false, label='Disabled', pen=COLOR_RED}},
                    on_change=function(val)
                        plugin.setEnabled(val)
                        self:refresh()
                    end,
                },
                widgets.HotkeyLabel{
                    frame={t=3, l=29},
                    label='Set all',
                    key='CUSTOM_CTRL_A',
                    auto_width=true,
                    on_activate=self:callback('prompt_for_all_thresholds'),
                },
                widgets.HotkeyLabel{
                    view_id='default_threshold',
                    frame={t=4, l=0},
                    key='CUSTOM_CTRL_D',
                    auto_width=true,
                    on_activate=self:callback('prompt_for_default_threshold'),
                },
                widgets.HotkeyLabel{
                    frame={t=4, r=0},
                    label='Reset selected to default',
                    key='CUSTOM_CTRL_R',
                    auto_width=true,
                    on_activate=self:callback('reset_selected_threshold'),
                },
            },
        },
    }
end

function Autofarm:render(dc)
    self.subviews.enable_toggle:setOption(plugin.isEnabled())
    Autofarm.super.render(self, dc)
end

function Autofarm:onInput(keys)
    if keys.SELECT then
        self:prompt_for_new_threshold(self.subviews.list:getSelected())
    end
    return Autofarm.super.onInput(self, keys)
end

function Autofarm:postUpdateLayout()
    self:refresh()
end

local SORT_WIDGETS = {
    'sort',
    'sort_name',
    'sort_stock',
    'sort_threshold',
}

local function make_row_text(name, stock, threshold, annotation, row_width)
    return {
        {text=name, width=row_width-24, pad_char=' '},
        '  ', {text=tostring(stock), width=6, rjustify=true, pad_char=' '},
        '  ', {text=tostring(threshold)..(annotation or ''), width=11, rjustify=true, pad_char=' '},
    }
end

local plants_all = df.global.world.raws.plants.all

-- returns the unique stockpile growths of a plant as a list of
-- {id=, name=} tables; only stockpile-marked growths ever become items
local function stockpile_growths(plant)
    local growths, seen = {}, {}
    for _,growth in ipairs(plant.growths) do
        if growth.id and not seen[growth.id] then
            local matinfo = dfhack.matinfo.decode(growth)
            if matinfo and matinfo.material and
                matinfo.material.flags.STOCKPILE_PLANT_GROWTH then
                seen[growth.id] = true
                table.insert(growths, {id=growth.id, name=growth.name})
            end
        end
    end
    return growths
end

function Autofarm:refresh(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs(SORT_WIDGETS) do
        self.subviews[widget_name]:setOption(sort_fn)
    end

    local data = plugin.autofarm_getData()
    local hide_stocked = self.subviews.hide_stocked:getOptionValue()

    self.subviews.default_threshold:setLabel(('Set default threshold (currently %d)')
        :format(data.default_threshold))
    self.subviews.excluded_farms:setText(
        ('%d farm(s) excluded from autofarm management'):format(#data.excluded_farms))

    local list = self.subviews.list
    local row_width = list.frame_body.width
    local choices = {}

    for _,plant in ipairs(plants_all) do
        if not plant.flags.SEED or plant.flags.TREE then goto continue end
        local custom = data.thresholds[plant.index]
        local threshold = custom or data.default_threshold
        local stock = data.last_counts[plant.index] or 0
        if not (hide_stocked and stock >= threshold) then
            table.insert(choices, {
                text=make_row_text(plant.name, stock, threshold,
                        custom and '' or ' (def)', row_width),
                data={
                    idx=plant.index,
                    name=plant.name,
                    stock=stock,
                    threshold=threshold,
                },
            })
        end
        -- stockpile growths are separate products of the plant; each can
        -- have its own threshold, or count toward the plant's pooled
        -- threshold if unset
        local growth_thresholds = data.growth_thresholds[plant.index] or {}
        local growth_counts = data.growth_counts[plant.index] or {}
        for _,growth in ipairs(stockpile_growths(plant)) do
            local gthreshold = growth_thresholds[growth.id]
            local gstock = growth_counts[growth.id] or 0
            -- untracked growths count toward the plant's pooled stock,
            -- so their "below threshold" state is the plant row's
            if hide_stocked and
                (gthreshold and gstock >= gthreshold or
                 not gthreshold and stock >= threshold) then
                goto continue_growth
            end
            table.insert(choices, {
                text=make_row_text('  '..growth.name, gstock,
                        gthreshold or threshold,
                        gthreshold and '' or ' (pool)', row_width),
                data={
                    idx=plant.index,
                    growth=growth.id,
                    name=growth.name,
                    stock=gstock,
                    threshold=gthreshold or threshold,
                },
            })
            ::continue_growth::
        end
        ::continue::
    end

    table.sort(choices, self.subviews.sort:getOptionValue())
    local selected = list:getSelected()
    list:setChoices(choices, selected)
end

local function check_number(target, text)
    if not target then
        dlg.showMessage('Invalid Number', 'This is not a number: '..text, COLOR_LIGHTRED)
        return false
    end
    if target < 0 then
        dlg.showMessage('Invalid Number', 'Negative numbers make no sense!', COLOR_LIGHTRED)
        return false
    end
    return true
end

function Autofarm:prompt_for_new_threshold(_, choice)
    dlg.showInputPrompt(
        'Set threshold',
        ('Enter desired threshold for %s:'):format(choice.data.name),
        COLOR_WHITE,
        tostring(choice.data.threshold),
        function(text)
            local target = tonumber(text)
            if check_number(target, text) then
                if choice.data.growth then
                    plugin.autofarm_setGrowthThreshold(choice.data.idx,
                        choice.data.growth, math.floor(target))
                else
                    plugin.autofarm_setThreshold(choice.data.idx, math.floor(target))
                end
                self:refresh()
            end
        end
    )
end

function Autofarm:prompt_for_all_thresholds()
    dlg.showInputPrompt(
        'Set all thresholds',
        'Enter desired threshold for all crop types',
        COLOR_WHITE,
        '',
        function(text)
            local target = tonumber(text)
            if check_number(target, text) then
                for _,plant in ipairs(plants_all) do
                    if plant.flags.SEED and not plant.flags.TREE then
                        plugin.autofarm_setThreshold(plant.index, math.floor(target))
                    end
                end
                self:refresh()
            end
        end
    )
end

function Autofarm:prompt_for_default_threshold()
    local data = plugin.autofarm_getData()
    dlg.showInputPrompt(
        'Set default threshold',
        'Enter desired default threshold for crops',
        COLOR_WHITE,
        tostring(data.default_threshold),
        function(text)
            local target = tonumber(text)
            if check_number(target, text) then
                plugin.autofarm_setDefaultThreshold(math.floor(target))
                self:refresh()
            end
        end
    )
end

function Autofarm:reset_selected_threshold()
    local _, choice = self.subviews.list:getSelected()
    if not choice then return end
    if choice.data.growth then
        plugin.autofarm_removeGrowthThreshold(choice.data.idx, choice.data.growth)
    else
        plugin.autofarm_removeThreshold(choice.data.idx)
    end
    self:refresh()
end

--
-- AutofarmScreen
--

AutofarmScreen = defclass(AutofarmScreen, gui.ZScreen)
AutofarmScreen.ATTRS{
    focus_path='autofarm',
}

function AutofarmScreen:init()
    self:addviews{Autofarm{}}
end

function AutofarmScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
    qerror('autofarm requires a fort map to be loaded')
end

if not plugin.autofarm_getData then
    qerror('this GUI requires a newer version of the autofarm plugin')
end

view = view and view:raise() or AutofarmScreen{}:show()

local dlg = require('gui.dialogs')
local gui = require('gui')
local plugin = require('plugins.seedwatch')
local widgets = require('gui.widgets')

local CH_UP = string.char(30)
local CH_DN = string.char(31)

Seedwatch = defclass(Seedwatch, widgets.Window)
Seedwatch.ATTRS{
    frame_title='Seedwatch',
    frame={w=58, h=25},
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

local function sort_by_quantity_desc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_name_desc(a, b)
    end
    return a.data.quantity > b.data.quantity
end

local function sort_by_quantity_asc(a, b)
    if a.data.quantity == b.data.quantity then
        return sort_by_name_desc(a, b)
    end
    return a.data.quantity < b.data.quantity
end

local function sort_by_target_desc(a, b)
    if a.data.target == b.data.target then
        return sort_by_name_desc(a, b)
    end
    return a.data.target > b.data.target
end

local function sort_by_target_asc(a, b)
    if a.data.target == b.data.target then
        return sort_by_name_desc(a, b)
    end
    return a.data.target < b.data.target
end

function Seedwatch:init()
    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='sort',
            frame={l=1, t=0, w=31},
            label='Sort by:',
            key='CUSTOM_SHIFT_S',
            options={
                {label='Name'..CH_DN, value=sort_by_name_desc},
                {label='Name'..CH_UP, value=sort_by_name_asc},
                {label='Quantity'..CH_DN, value=sort_by_quantity_desc},
                {label='Quantity'..CH_UP, value=sort_by_quantity_asc},
                {label='Target'..CH_DN, value=sort_by_target_desc},
                {label='Target'..CH_UP, value=sort_by_target_asc},
            },
            initial_option=sort_by_name_desc,
            on_change=self:callback('refresh', 'sort'),
        },
        widgets.ToggleHotkeyLabel{
            view_id='hide_nostock',
            frame={t=0, l=24, w=31},
            key='CUSTOM_CTRL_H',
            label='Show only in stock:',
            on_change=self:callback('refresh', 'sort'),
        },
        widgets.Panel{
            view_id='list_panel',
            frame={t=2, l=0, r=0, b=4},
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
                    view_id='sort_quantity',
                    frame={t=0, r=12, w=9},
                    options={
                        {label='Quantity', value=sort_noop},
                        {label='Quantity'..CH_DN, value=sort_by_quantity_desc},
                        {label='Quantity'..CH_UP, value=sort_by_quantity_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh', 'sort_quantity'),
                },
                widgets.CycleHotkeyLabel{
                    view_id='sort_target',
                    frame={t=0, r=3, w=7},
                    options={
                        {label='Target', value=sort_noop},
                        {label='Target'..CH_DN, value=sort_by_target_desc},
                        {label='Target'..CH_UP, value=sort_by_target_asc},
                    },
                    option_gap=0,
                    on_change=self:callback('refresh', 'sort_target'),
                },
                widgets.Label{
                    view_id='disabled_warning',
                    visible=function() return not plugin.isEnabled() end,
                    frame={t=3, h=1},
                    auto_width=true,
                    text={"Please enable seedwatch to change settings"},
                    text_pen=COLOR_YELLOW
                },
                widgets.List{
                    view_id='list',
                    frame={t=2, b=0},
                    visible=plugin.isEnabled,
                    on_double_click=self:callback('prompt_for_new_target'),
                },
            },
        },
        widgets.Panel{
            view_id='footer',
            frame={l=1, r=1, b=0, h=3},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text={
                        'Double click on a row or hit ',
                        {text='Enter', pen=COLOR_LIGHTGREEN},
                        ' to set the target.'
                    },
                },
                widgets.ToggleHotkeyLabel{
                    view_id='enable_toggle',
                    frame={t=2, l=0, w=29},
                    label='Seedwatch is',
                    key='CUSTOM_CTRL_E',
                    options={{value=true, label='Enabled', pen=COLOR_GREEN},
                             {value=false, label='Disabled', pen=COLOR_RED}},
                    on_change=function(val)
                        plugin.setEnabled(val)
                        self:refresh()
                    end,
                },
                widgets.HotkeyLabel{
                    frame={t=2, l=31},
                    label='Set all targets',
                    key='CUSTOM_CTRL_A',
                    auto_width=true,
                    on_activate=self:callback('prompt_for_all_targets'),
                },
            },
        },
    }
end

function Seedwatch:render(dc)
    self.subviews.enable_toggle:setOption(plugin.isEnabled())
    Seedwatch.super.render(self, dc)
end

function Seedwatch:onInput(keys)
    if keys.SELECT then
        self:prompt_for_new_target(self.subviews.list:getSelected())
    end
    return Seedwatch.super.onInput(self, keys)
end

function Seedwatch:postUpdateLayout()
    self:refresh()
end

local SORT_WIDGETS = {
    'sort',
    'sort_name',
    'sort_quantity',
    'sort_target',
}

local function make_row_text(name, quantity, target, row_width)
    return {
        {text=name, width=row_width-22, pad_char=' '},
        '  ', {text=quantity, width=7, rjustify=true, pad_char=' '},
        '  ', {text=target, width=7, rjustify=true, pad_char=' '},
    }
end

local plants_all = df.global.world.raws.plants.all

function Seedwatch:refresh(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs(SORT_WIDGETS) do
        self.subviews[widget_name]:setOption(sort_fn)
    end

    local watch_map, seed_counts = plugin.seedwatch_getData()
    local hide_nostock = self.subviews.hide_nostock:getOptionValue()

    local list = self.subviews.list
    local row_width = list.frame_body.width
    local choices = {}

    for idx,target in pairs(watch_map) do
        if hide_nostock and not seed_counts[idx] then goto continue end
        local name = plants_all[idx].seed_singular
        local quantity = seed_counts[idx] or 0
        table.insert(choices, {
            text=make_row_text(name, quantity, target, row_width),
            data={
                id=plants_all[idx].id,
                name=name,
                quantity=quantity,
                target=target,
            },
        })
        ::continue::
    end

    table.sort(choices, self.subviews.sort:getOptionValue())
    local selected = list:getSelected()
    list:setChoices(choices, selected)
end

local function check_number(target, text)
    if not target then
        dlg.showMessage('Invalid Number', 'This is not a number: '..text..NEWLINE..'(for zero enter a 0)', COLOR_LIGHTRED)
        return false
    end
    if target < 0 then
        dlg.showMessage('Invalid Number', 'Negative numbers make no sense!', COLOR_LIGHTRED)
        return false
    end
    return true
end

function Seedwatch:prompt_for_new_target(_, choice)
    dlg.showInputPrompt(
        'Set target',
        ('Enter desired target for %s:'):format(choice.data.name),
        COLOR_WHITE,
        tostring(choice.data.target),
        function(text)
            local target = tonumber(text)
            if check_number(target, text) then
                plugin.seedwatch_setTarget(choice.data.id, target)
                self:refresh()
            end
        end
    )
end

function Seedwatch:prompt_for_all_targets()
    dlg.showInputPrompt(
        'Set all targets',
        'Enter desired target for all seed types',
        COLOR_WHITE,
        '',
        function(text)
            local target = tonumber(text)
            if check_number(target, text) then
                plugin.seedwatch_setTarget('all', target)
                self:refresh()
            end
        end
    )
end

--
-- SeedwatchScreen
--

SeedwatchScreen = defclass(SeedwatchScreen, gui.ZScreen)
SeedwatchScreen.ATTRS{
    focus_path='seedwatch',
}

function SeedwatchScreen:init()
    self:addviews{Seedwatch{}}
end

function SeedwatchScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
    qerror('seedwatch requires a fort map to be loaded')
end

view = view and view:raise() or SeedwatchScreen{}:show()

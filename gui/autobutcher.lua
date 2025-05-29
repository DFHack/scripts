local dlg = require('gui.dialogs')
local gui = require('gui')
local plugin = require('plugins.autobutcher')
local widgets = require('gui.widgets')

local CH_UP = string.char(30)
local CH_DN = string.char(31)

local racewidth = 25 -- width of the race name column in the UI

WatchList = defclass(WatchList, gui.ZScreen)
WatchList.ATTRS{
    focus_string='autobutcher',
}

local function sort_noop(a, b)
    -- this function is used as a marker and never actually gets called
    error('sort_noop should not be called')
end

local function either_are_special(a, b)
    return type(a.race) == 'number' or type(b.race) == 'number'
end

local function sort_by_race_desc(a, b)
    if type(a.race) == 'number' then
        if type(b.race) == 'number' then
            return a.race < b.race
        end
        return true
    elseif type(b.race) == 'number' then
        return false
    end
    return a.race < b.race
end

local function sort_by_race_asc(a, b)
    if type(a.race) == 'number' then
        if type(b.race) == 'number' then
            return a.race < b.race
        end
        return true
    elseif type(b.race) == 'number' then
        return false
    end
    return a.race > b.race
end

local function sort_by_total_desc(a, b)
    if either_are_special(a, b) or a.total == b.total then
        return sort_by_race_desc(a, b)
    end
    return a.total > b.total
end

local function sort_by_total_asc(a, b)
    if either_are_special(a, b) or a.total == b.total  then
        return sort_by_race_desc(a, b)
    end
    return a.total < b.total
end

local function sort_by_fk_desc(a, b)
    if either_are_special(a, b) or a.data.fk_total == b.data.fk_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.fk_total > b.data.fk_total
end

local function sort_by_fk_asc(a, b)
    if either_are_special(a, b) or a.data.fk_total == b.data.fk_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.fk_total < b.data.fk_total
end

local function sort_by_fa_desc(a, b)
    if either_are_special(a, b) or a.data.fa_total == b.data.fa_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.fa_total > b.data.fa_total
end

local function sort_by_fa_asc(a, b)
    if either_are_special(a, b) or a.data.fa_total == b.data.fa_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.fa_total < b.data.fa_total
end

local function sort_by_mk_desc(a, b)
    if either_are_special(a, b) or a.data.mk_total == b.data.mk_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.mk_total > b.data.mk_total
end

local function sort_by_mk_asc(a, b)
    if either_are_special(a, b) or a.data.mk_total == b.data.mk_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.mk_total < b.data.mk_total
end

local function sort_by_ma_desc(a, b)
    if either_are_special(a, b) or a.data.ma_total == b.data.ma_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.ma_total > b.data.ma_total
end

local function sort_by_ma_asc(a, b)
    if either_are_special(a, b) or a.data.ma_total == b.data.ma_total then
        return sort_by_race_desc(a, b)
    end
    return a.data.ma_total < b.data.ma_total
end

local function sort_by_watched_desc(a, b)
    if either_are_special(a, b) or a.data.watched == b.data.watched then
        return sort_by_race_desc(a, b)
    end
    return a.data.watched
end

local function sort_by_watched_asc(a, b)
    if either_are_special(a, b) or a.data.watched == b.data.watched then
        return sort_by_race_desc(a, b)
    end
    return b.data.watched
end

local function sort_by_ordered_desc(a, b)
    if either_are_special(a, b) or a.ordered == b.ordered then
        return sort_by_race_desc(a, b)
    end
    return a.ordered > b.ordered
end

local function sort_by_ordered_asc(a, b)
    if either_are_special(a, b) or a.ordered == b.ordered then
        return sort_by_race_desc(a, b)
    end
    return a.ordered < b.ordered
end

function WatchList:init()
    if plugin.isEnabled() then
        -- ensure slaughter counts and autowatch are up to date
        dfhack.run_command('autobutcher', 'now')
    end

    local window = widgets.Window{
        frame_title='Autobutcher',
        frame={w=97, h=31},
        resizable=true,
        subviews={
            widgets.CycleHotkeyLabel{
                view_id='sort',
                frame={l=0, t=0, w=31},
                label='Sort by:',
                key='CUSTOM_SHIFT_S',
                options={
                    {label='Total stock'..CH_DN, value=sort_by_total_desc},
                    {label='Total stock'..CH_UP, value=sort_by_total_asc},
                    {label='Race'..CH_DN, value=sort_by_race_desc},
                    {label='Race'..CH_UP, value=sort_by_race_asc},
                    {label='female kids'..CH_DN, value=sort_by_fk_desc},
                    {label='female kids'..CH_UP, value=sort_by_fk_asc},
                    {label='male kids'..CH_DN, value=sort_by_mk_desc},
                    {label='make kids'..CH_UP, value=sort_by_mk_asc},
                    {label='Female adults'..CH_DN, value=sort_by_fa_desc},
                    {label='Female adults'..CH_UP, value=sort_by_fa_asc},
                    {label='Male adults'..CH_DN, value=sort_by_ma_desc},
                    {label='Male adults'..CH_UP, value=sort_by_ma_asc},
                    {label='Watch?'..CH_DN, value=sort_by_watched_desc},
                    {label='Watch?'..CH_UP, value=sort_by_watched_asc},
                    {label='Butchering ordered'..CH_DN, value=sort_by_ordered_desc},
                    {label='Butchering ordered'..CH_UP, value=sort_by_ordered_asc},
                },
                initial_option=sort_by_total_desc,
                on_change=self:callback('refresh', 'sort'),
            },
            widgets.ToggleHotkeyLabel{
                view_id='hide_zero',
                frame={t=0, l=35, w=49},
                key='CUSTOM_CTRL_H',
                label='Show only rows with non-zero targets',
                on_change=self:callback('refresh', 'sort'),
            },
            widgets.Panel{
                view_id='list_panel',
                frame={t=2, l=0, r=0, b=8},
                frame_style=gui.FRAME_INTERIOR,
                subviews={
                    widgets.CycleHotkeyLabel{
                        view_id='sort_total',
                        frame={t=0, l=0, w=6},
                        options={
                            {label='Total', value=sort_noop},
                            {label='Total'..CH_DN, value=sort_by_total_desc},
                            {label='Total'..CH_UP, value=sort_by_total_asc},
                        },
                        initial_option=sort_by_total_desc,
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_total'),
                    },
                    widgets.Label{
                        frame={t=1, l=0},
                        text='stock'
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_race',
                        frame={t=0, l=8, w=5},
                        options={
                            {label='Race', value=sort_noop},
                            {label='Race'..CH_DN, value=sort_by_race_desc},
                            {label='Race'..CH_UP, value=sort_by_race_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_race'),
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_fk',
                        frame={t=0, l=37, w=7},
                        options={
                            {label='female', value=sort_noop},
                            {label='female'..CH_DN, value=sort_by_fk_desc},
                            {label='female'..CH_UP, value=sort_by_fk_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_fk'),
                    },
                    widgets.Label{
                        frame={t=1, l=38},
                        text='kids'
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_mk',
                        frame={t=0, l=47, w=5},
                        options={
                            {label='male', value=sort_noop},
                            {label='male'..CH_DN, value=sort_by_mk_desc},
                            {label='male'..CH_UP, value=sort_by_mk_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_mk'),
                    },
                    widgets.Label{
                        frame={t=1, l=47},
                        text='kids'
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_fa',
                        frame={t=0, l=55, w=7},
                        options={
                            {label='Female', value=sort_noop},
                            {label='Female'..CH_DN, value=sort_by_fa_desc},
                            {label='Female'..CH_UP, value=sort_by_fa_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_fa'),
                    },
                    widgets.Label{
                        frame={t=1, l=55},
                        text='adults'
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_ma',
                        frame={t=0, l=65, w=5},
                        options={
                            {label='Male', value=sort_noop},
                            {label='Male'..CH_DN, value=sort_by_ma_desc},
                            {label='Male'..CH_UP, value=sort_by_ma_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_ma'),
                    },
                    widgets.Label{
                        frame={t=1, l=64},
                        text='adults'
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_watched',
                        frame={t=0, l=72, w=7},
                        options={
                            {label='Watch?', value=sort_noop},
                            {label='Watch?'..CH_DN, value=sort_by_watched_desc},
                            {label='Watch?'..CH_UP, value=sort_by_watched_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_watched'),
                    },
                    widgets.CycleHotkeyLabel{
                        view_id='sort_ordered',
                        frame={t=0, l=81, w=11},
                        options={
                            {label='Butchering', value=sort_noop},
                            {label='Butchering'..CH_DN, value=sort_by_ordered_desc},
                            {label='Butchering'..CH_UP, value=sort_by_ordered_asc},
                        },
                        option_gap=0,
                        on_change=self:callback('refresh', 'sort_ordered'),
                    },
                    widgets.Label{
                        frame={t=1, l=82},
                        text='ordered'
                    },
                    widgets.Label{
                        view_id='disabled_warning',
                        visible=function() return not plugin.isEnabled() end,
                        frame={t=3, l=8, h=1},
                        text={"Enable autobutcher to change settings"},
                        text_pen=COLOR_YELLOW
                    },
                    widgets.List{
                        view_id='list',
                        frame={t=3, b=0},
                        visible=plugin.isEnabled,
                        on_double_click = self:callback('onDoubleClick'),
                        on_double_click2 = self:callback('zeroOut'),
                    },
                },
            },
            widgets.Panel{
                view_id='footer',
                frame={l=0, r=0, b=0, h=7},
                subviews={
                    widgets.Label{
                        frame={t=0, l=0},
                        text={
                            'Columns show butcherable stock (+ protected stock, if any) / target: ', NEWLINE,
                            'Double click on a value to edit/toggle or use the hotkeys listed below.'
                        }
                    },
                    widgets.HotkeyLabel{
                        view_id='fk',
                        frame={t=3, l=0},
                        key='CUSTOM_F',
                        label='f kids',
                        auto_width=true,
                        on_activate=self:callback('editVal', 'female kids', 'fk'),
                    },
                    widgets.HotkeyLabel{
                        view_id='mk',
                        frame={t=4, l=0},
                        key='CUSTOM_M',
                        label='m kids',
                        auto_width=true,
                        on_activate=self:callback('editVal', 'male kids', 'mk'),
                    },
                    widgets.HotkeyLabel{
                        view_id='fa',
                        frame={t=3, l=17},
                        key='CUSTOM_SHIFT_F',
                        label='F adults',
                        auto_width=true,
                        on_activate=self:callback('editVal', 'female adults', 'fa'),
                    },
                    widgets.HotkeyLabel{
                        view_id='ma',
                        frame={t=4, l=17},
                        key='CUSTOM_SHIFT_M',
                        label='M adults',
                        auto_width=true,
                        on_activate=self:callback('editVal', 'male adults', 'ma'),
                    },
                    widgets.HotkeyLabel{
                        view_id='butcher',
                        frame={t=5, l=0},
                        key='CUSTOM_B',
                        label='Butcher race',
                        auto_width=true,
                        on_activate=self:callback('onButcherRace'),
                    },
                    widgets.HotkeyLabel{
                        view_id='unbutcher',
                        frame={t=5, l=17},
                        key='CUSTOM_SHIFT_B',
                        label='Unbutcher race',
                        auto_width=true,
                        on_activate=self:callback('onUnbutcherRace'),
                    },
                    widgets.HotkeyLabel{
                        view_id='watch',
                        frame={t=3, l=36},
                        key='CUSTOM_W',
                        label='Toggle watch',
                        auto_width=true,
                        on_activate=self:callback('onToggleWatching'),
                    },
                    widgets.HotkeyLabel{
                        frame={t=4, l=36},
                        key='CUSTOM_X',
                        label='Delete row',
                        auto_width=true,
                        on_activate=self:callback('onDeleteEntry'),
                    },
                    widgets.HotkeyLabel{
                        frame={t=3, l=54},
                        key='CUSTOM_R',
                        label='Set row targets to 0',
                        auto_width=true,
                        on_activate=self:callback('zeroOut'),
                    },
                    widgets.HotkeyLabel{
                        frame={t=4, l=54},
                        key='CUSTOM_SHIFT_R',
                        label='Set row targets to N',
                        auto_width=true,
                        on_activate=self:callback('onSetRow'),
                    },
                    widgets.HotkeyLabel{
                        view_id='butcher_all',
                        frame={t=5, l=36},
                        key='CUSTOM_E',
                        label='Butcher all',
                        auto_width=true,
                        on_activate=self:callback('onButcherAll'),
                    },
                    widgets.HotkeyLabel{
                        view_id='unbutcher_all',
                        frame={t=5, l=54},
                        key='CUSTOM_SHIFT_E',
                        label='Unbutcher all',
                        auto_width=true,
                        on_activate=self:callback('onUnbutcherAll'),
                    },
                    widgets.ToggleHotkeyLabel{
                        view_id='enable_toggle',
                        frame={t=6, l=0, w=26},
                        label='Autobutcher is',
                        key='CUSTOM_SHIFT_A',
                        options={{value=true, label='Enabled', pen=COLOR_GREEN},
                                 {value=false, label='Disabled', pen=COLOR_RED}},
                        on_change=function(val)
                            plugin.setEnabled(val)
                            self:refresh()
                        end,
                    },
                    widgets.ToggleHotkeyLabel{
                        view_id='autowatch_toggle',
                        frame={t=6, l=36, w=24},
                        label='Autowatch is',
                        key='CUSTOM_SHIFT_W',
                        options={{value=true, label='Enabled', pen=COLOR_GREEN},
                                 {value=false, label='Disabled', pen=COLOR_RED}},
                        on_change=function(val)
                            plugin.autowatch_setEnabled(val)
                            self:refresh()
                        end,
                    },
                },
            },
        },
    }

    self:addviews{window}
    self:refresh()
    self.subviews.list:setSelected(#self.subviews.list:getChoices() > 2 and 3 or 2)
end

function WatchList:onRenderFrame(dc, rect)
    self.subviews.enable_toggle:setOption(plugin.isEnabled())
    self.subviews.autowatch_toggle:setOption(plugin.autowatch_isEnabled())
    WatchList.super.onRenderFrame(self, dc, rect)
end

function stringify(number)
    if not number then return '' end
    -- cap displayed number to 2 characters to fit in the column width
    if number > 99 then
        return '++'
    end
    return tostring(number)
end

local SORT_WIDGETS = {
    'sort',
    'sort_total',
    'sort_race',
    'sort_fk',
    'sort_mk',
    'sort_fa',
    'sort_ma',
    'sort_watched',
    'sort_ordered'
}

local function make_count_text(butcherable, protected)
    local str = protected and protected > 0 and ('+%s'):format(stringify(protected)) or ''
    str = stringify(butcherable) .. str
    return str .. (#str > 0 and '/' or ' ')
end

local function make_row_text(race, data, total, ordered)
    -- highlight entries where the target quota can't be met because too many are protected
    local fk_pen = (data.fk_protected or 0) > data.fk and COLOR_LIGHTRED or nil
    local fa_pen = (data.fa_protected or 0) > data.fa and COLOR_LIGHTRED or nil
    local mk_pen = (data.mk_protected or 0) > data.mk and COLOR_LIGHTRED or nil
    local ma_pen = (data.ma_protected or 0) > data.ma and COLOR_LIGHTRED or nil

    local watched = data.watched == nil and '' or (data.watched and 'yes' or 'no')

    return {
        {text=total or '', width=5, rjustify=true, pad_char=' '}, '   ',
        {text=race, width=racewidth, pad_char=' '}, ' ',
        {text=make_count_text(data.fk_butcherable, data.fk_protected), width=6, rjustify=true, pad_char=' '},
        {text=data.fk, width=2, pen=fk_pen, pad_char=' '}, ' ',
        {text=make_count_text(data.mk_butcherable, data.mk_protected), width=6, rjustify=true, pad_char=' '},
        {text=data.mk, width=2, pen=mk_pen, pad_char=' '}, ' ',
        {text=make_count_text(data.fa_butcherable, data.fa_protected), width=6, rjustify=true, pad_char=' '},
        {text=data.fa, width=2, pen=fa_pen, pad_char=' '}, ' ',
        {text=make_count_text(data.ma_butcherable, data.ma_protected), width=6, rjustify=true, pad_char=' '},
        {text=data.ma, width=2, pen=ma_pen, pad_char=' '}, ' ',
        {text=watched, width=7, rjustify=true, pad_char=' '}, ' ',
        {text=ordered or '', width=8, rjustify=true, pad_char=' '},
    }
end

function WatchList:refresh(sort_widget, sort_fn)
    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == sort_noop then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs(SORT_WIDGETS) do
        self.subviews[widget_name]:setOption(sort_fn)
    end

    local choices = {}

    local settings = plugin.autobutcher_getSettings()

    -- first two rows are for "edit all races" and "edit new races"
    table.insert(choices, {
        text=make_row_text('!! ALL RACES PLUS NEW', settings),
        race=1,
        data=settings,
    })
    table.insert(choices, {
        text=make_row_text('!! ONLY NEW RACES', settings),
        race=2,
        data=settings,
    })

    local hide_zero = self.subviews.hide_zero:getOptionValue()

    for _, data in ipairs(plugin.autobutcher_getWatchList()) do
        if hide_zero then
            local target = data.fk + data.mk + data.fa + data.ma
            if target == 0 then goto continue end
        end
        local total = data.fk_total + data.mk_total + data.fa_total + data.ma_total
        local ordered = data.fk_butcherflag + data.fa_butcherflag + data.mk_butcherflag + data.ma_butcherflag
        table.insert(choices, {
            text=make_row_text(data.name, data, total, ordered ~= 0 and ordered or nil),
            race=data.name,
            total=total,
            ordered=ordered,
            data=data,
        })
        ::continue::
    end

    table.sort(choices, self.subviews.sort:getOptionValue())
    self.subviews.list:setChoices(choices)
end

function WatchList:onDoubleClick(_, choice)
    local x = self.subviews.list:getMousePos()
    if x <= 32 then return
    elseif x <= 41 then self.subviews.fk.on_activate()
    elseif x <= 42 then return
    elseif x <= 50 then self.subviews.mk.on_activate()
    elseif x <= 51 then return
    elseif x <= 59 then self.subviews.fa.on_activate()
    elseif x <= 60 then return
    elseif x <= 69 then self.subviews.ma.on_activate()
    elseif x <= 70 then return
    elseif x <= 76 then self.subviews.watch.on_activate()
    elseif x <= 77 then return
    elseif x <= 90 and choice.ordered then
        if choice.ordered == 0 then
            self.subviews.butcher.on_activate()
        else
            self.subviews.unbutcher.on_activate()
        end
    end
end

-- check the user input for target population values
local function checkUserInput(count, text)
    if count == nil then
        dlg.showMessage('Invalid Number', 'This is not a number: '..text..NEWLINE..'(for zero enter a 0)', COLOR_LIGHTRED)
        return false
    end
    if count < 0 then
        dlg.showMessage('Invalid Number', 'Negative numbers make no sense!', COLOR_LIGHTRED)
        return false
    end
    return true
end

local function get_race(choice)
    if choice.race == 1 then
        return 'ALL RACES PLUS NEW'
    elseif choice.race == 2 then
        return 'ONLY NEW RACES'
    end
    return choice.race
end

function WatchList:editVal(desc, var)
    local _, choice = self.subviews.list:getSelected()
    local race = get_race(choice)
    local data = choice.data

    dlg.showInputPrompt(
        'Race: '..race,
        ('Enter desired target for %s:'):format(desc),
        COLOR_WHITE,
        ' '..data[var],
        function(text)
            local count = tonumber(text)
            if checkUserInput(count, text) then
                data[var] = count
                if choice.race == 1 then
                    plugin.autobutcher_setDefaultTargetAll(data.fk, data.mk, data.fa, data.ma)
                elseif choice.race == 2 then
                    plugin.autobutcher_setDefaultTargetNew(data.fk, data.mk, data.fa, data.ma)
                else
                    plugin.autobutcher_setWatchListRace(data.id, data.fk, data.mk, data.fa, data.ma, data.watched)
                end
                self:refresh()
            end
        end
    )
end

-- set whole row (fk, mk, fa, ma) to one value
function WatchList:onSetRow()
    local _, choice = self.subviews.list:getSelected()
    local race = get_race(choice)
    local data = choice.data

    dlg.showInputPrompt(
        'Set whole row for '..race,
        'Enter desired value for all targets:',
        COLOR_WHITE,
        ' ',
        function(text)
            local count = tonumber(text)
            if checkUserInput(count, text) then
                if choice.race == 1 then
                    plugin.autobutcher_setDefaultTargetAll(count, count, count, count)
                elseif choice.race == 2 then
                    plugin.autobutcher_setDefaultTargetNew(count, count, count, count)
                else
                    plugin.autobutcher_setWatchListRace(data.id, count, count, count, count, data.watched)
                end
                self:refresh()
            end
        end
    )
end

function WatchList:zeroOut()
    local _, choice = self.subviews.list:getSelected()
    local data = choice.data

    local count = 0
    if choice.race == 1 then
        dlg.showYesNoPrompt(
            'Are you sure?',
            'Really set all targets for all races to 0?',
            COLOR_YELLOW,
            function()
                plugin.autobutcher_setDefaultTargetAll(count, count, count, count)
                self:refresh()
            end
        )
    elseif choice.race == 2 then
        plugin.autobutcher_setDefaultTargetNew(count, count, count, count)
        self:refresh()
    else
        plugin.autobutcher_setWatchListRace(data.id, count, count, count, count, data.watched)
        self:refresh()
    end
end

function WatchList:onToggleWatching()
    local _, choice = self.subviews.list:getSelected()
    if type(choice.race) == 'string' then
        local data = choice.data
        plugin.autobutcher_setWatchListRace(data.id, data.fk, data.mk, data.fa, data.ma, not data.watched)
    end
    self:refresh()
end

function WatchList:onDeleteEntry()
    local _, choice = self.subviews.list:getSelected()
    if type(choice.race) ~= 'string' then
        return
    end
    dlg.showYesNoPrompt(
        'Delete from Watchlist',
        'Really delete the selected entry?'..NEWLINE..'(you could just toggle watch instead)',
        COLOR_YELLOW,
        function()
            plugin.autobutcher_removeFromWatchList(choice.data.id)
            self:refresh()
        end
    )
end

function WatchList:onUnbutcherRace()
    local _, choice = self.subviews.list:getSelected()
    if type(choice.race) ~= 'string' then
        dlg.showMessage('Error', 'Please select a specific race.', COLOR_LIGHTRED)
        return
    end
    plugin.autobutcher_unbutcherRace(choice.data.id)
    self:refresh()
end

function WatchList:onButcherRace()
    local _, choice = self.subviews.list:getSelected()
    if type(choice.race) ~= 'string' then
        dlg.showMessage('Error', 'Please select a specific race.', COLOR_LIGHTRED)
        return
    end
    plugin.autobutcher_butcherRace(choice.data.id)
    self:refresh()
end

function WatchList:onUnbutcherAll()
    for _, data in ipairs(plugin.autobutcher_getWatchList()) do
        plugin.autobutcher_unbutcherRace(data.id)
    end

    self:refresh()
end

function WatchList:onButcherAll()
    dlg.showYesNoPrompt(
        'Butcher all animals',
        'Warning! This will mark ALL animals for butchering.'..NEWLINE..'Proceed with caution.',
        COLOR_YELLOW,
        function()
            for _, data in ipairs(plugin.autobutcher_getWatchList()) do
                plugin.autobutcher_butcherRace(data.id)
            end

            self:refresh()
        end
    )
end

function WatchList:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('autobutcher requires a fortress map to be loaded')
end

view = view and view:raise() or WatchList{}:show()

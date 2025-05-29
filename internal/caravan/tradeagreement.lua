--@ module = true
local dlg = require('gui.dialogs')
local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local diplomacy = df.global.game.main_interface.diplomacy

TradeAgreementOverlay = defclass(TradeAgreementOverlay, overlay.OverlayWidget)
TradeAgreementOverlay.ATTRS{
    desc='Adds quick toggles for groups of trade agreement items.',
    default_pos={x=45, y=-6},
    default_enabled=true,
    viewscreens='dwarfmode/Diplomacy/Requests',
    frame={w=25, h=4},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

local function transform_mat_list(matList)
    local list = {}
    for key, value in pairs(matList.mat_index) do
        list[key] = {type=matList.mat_type[key], index=value}
    end
    return list
end

local function decode_mat_list(mat)
    return dfhack.matinfo.decode(mat.type, mat.index).material.material_value
end

local select_by_value_tab = {
    Leather={
        get_mats=function(resources) return transform_mat_list(resources.organic.leather) end,
        decode=decode_mat_list,
    },
    SmallCutGems={
        get_mats=function(resources) return resources.gems end,
        decode=function(id) return dfhack.matinfo.decode(0, id).material.material_value end,
    },
    Meat={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.meat) end,
        decode=decode_mat_list,
    },
    Parchment={
        get_mats=function(resources) return transform_mat_list(resources.organic.parchment) end,
        decode=decode_mat_list,
    },
}
select_by_value_tab.LargeCutGems = select_by_value_tab.SmallCutGems

local function get_cur_tab_category()
    return diplomacy.taking_requests_tablist[diplomacy.taking_requests_selected_tab]
end

local function get_select_by_value_tab(category)
    category = category or get_cur_tab_category()
    return select_by_value_tab[df.entity_sell_category[category]]
end

local function get_cur_priority_list()
    return diplomacy.environment.dipev.sell_requests.priority[get_cur_tab_category()]
end

local function diplomacy_toggle_cat()
    local priority = get_cur_priority_list()
    if #priority == 0 then return end
    local target_val = priority[0] == 0 and 4 or 0
    for i in ipairs(priority) do
        priority[i] = target_val
    end
end

local function select_by_value(prices, val)
    local priority = get_cur_priority_list()
    for i in ipairs(priority) do
        if prices[i] == val then
            priority[i] = 4
        end
    end
end

function TradeAgreementOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='Select all/none',
            key='CUSTOM_CTRL_A',
            on_activate=diplomacy_toggle_cat,
        },
    }
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=1, l=0},
            label='Select by value',
            key='CUSTOM_CTRL_M',
            on_activate=self:callback('select_by_value'),
            enabled=get_select_by_value_tab,
        },
    }
end

local function get_prices(tab)
    local resource = tab.get_mats(df.historical_entity.find(diplomacy.actor.civ_id).resources)
    local prices = {}
    local matValuesUnique = {}
    local filter = {}
    for civid, matid in pairs(resource) do
        local price = tab.decode(matid)
        prices[civid] = price
        if not filter[price] then
            local val = {value=price, count=1}
            filter[price] = val
            table.insert(matValuesUnique, val)
        else
            filter[price].count = filter[price].count + 1
        end
    end
    table.sort(matValuesUnique, function(a, b) return a.value < b.value end)
    return prices, matValuesUnique
end

function TradeAgreementOverlay:select_by_value()
    local cat = get_cur_tab_category()
    local cur_tab = get_select_by_value_tab(cat)

    local resource_name = df.entity_sell_category[cat]
    if resource_name:endswith('Gems') then resource_name = 'Gem' end
    local prices, matValuesUnique = get_prices(cur_tab)
    local list = {}
    for index, value in ipairs(matValuesUnique) do
        list[index] = ('%4d%s (%d type%s of %s)'):format(
            value.value, string.char(15), value.count, value.count == 1 and '' or 's', resource_name:lower())
    end
    dlg.showListPrompt(
        "Select materials with base value", "",
        COLOR_WHITE,
        list,
        function(id) select_by_value(prices, matValuesUnique[id].value) end
    )
end

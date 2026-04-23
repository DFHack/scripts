--@ module = true
local dlg = require('gui.dialogs')
local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local json = require('json')

local diplomacy = df.global.game.main_interface.diplomacy

TradeAgreementOverlay = defclass(TradeAgreementOverlay, overlay.OverlayWidget)
TradeAgreementOverlay.ATTRS{
    desc='Adds quick toggles for groups of trade agreement items.',
    default_pos={x=45, y=-6},
    default_enabled=true,
    viewscreens='dwarfmode/Diplomacy/Requests',
    frame={w=58, h=7},
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
    local minfo = dfhack.matinfo.decode(mat.type, mat.index)
    return minfo and minfo.material.material_value or 0
end

local function decode_mat_weight(mat)
    local minfo = dfhack.matinfo.decode(mat.type, mat.index)
    return minfo and minfo.material.solid_density or 0
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
    Stone={
        get_mats=function(resources) return resources.stones end,
        decode=function(id) return dfhack.matinfo.decode(0, id).material.material_value end,
    },
    Wood={
        get_mats=function(resources) return resources.wood_products end,
        decode=function(id) return dfhack.matinfo.decode(df.builtin_mats.WOOD, id).material.material_value end,
    },
    MetalBars={
        get_mats=function(resources) return resources.metals end,
        decode=function(id) return dfhack.matinfo.decode(0, id).material.material_value end,
    },
    Cheese={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.cheese) end,
        decode=decode_mat_list,
    },
    Powders={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.powders) end,
        decode=decode_mat_list,
    },
    Extracts={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.extracts) end,
        decode=decode_mat_list,
    },
    Drinks={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.booze) end,
        decode=decode_mat_list,
    },
    CupsMugsGoblets={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.crafts) end,
        decode=decode_mat_list,
    },
    Crafts={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.crafts) end,
        decode=decode_mat_list,
    },
    FlasksWaterskins={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.flasks) end,
        decode=decode_mat_list,
    },
    Quivers={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.quivers) end,
        decode=decode_mat_list,
    },
    Backpacks={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.backpacks) end,
        decode=decode_mat_list,
    },
    Barrels={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.barrels) end,
        decode=decode_mat_list,
    },
    Sand={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.sand) end,
        decode=decode_mat_list,
    },
    Glass={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.glass) end,
        decode=decode_mat_list,
    },
    Clay={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.clay) end,
        decode=decode_mat_list,
    },
    ClothPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_list },
    ThreadPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_list },
    RopesPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_list },
    BagsPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_list },
    ClothSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_list },
    ThreadSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_list },
    RopesSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_list },
    BagsSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_list },
    ClothYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_list },
    ThreadYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_list },
    RopesYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_list },
    BagsYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_list },
    Plants={
        get_mats=function(resources) return resources.plants end,
        decode=function(id) return dfhack.matinfo.decode(df.builtin_mats.PLANT, id).material.material_value end,
    },
    GardenVegetables={
        get_mats=function(resources) return resources.shrub_fruit_plants end,
        decode=function(id) return dfhack.matinfo.decode(df.builtin_mats.PLANT, id).material.material_value end,
    },
}
select_by_value_tab.LargeCutGems = select_by_value_tab.SmallCutGems

local select_by_weight_tab = {
    Stone={
        get_mats=function(resources) return resources.stones end,
        decode=function(id) return dfhack.matinfo.decode(0, id).material.solid_density end,
    },
    Wood={
        get_mats=function(resources) return resources.wood_products end,
        decode=function(id) return dfhack.matinfo.decode(df.builtin_mats.WOOD, id).material.solid_density end,
    },
    MetalBars={
        get_mats=function(resources) return resources.metals end,
        decode=function(id) return dfhack.matinfo.decode(0, id).material.solid_density end,
    },
    Cheese={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.cheese) end,
        decode=decode_mat_weight,
    },
    Powders={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.powders) end,
        decode=decode_mat_weight,
    },
    Extracts={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.extracts) end,
        decode=decode_mat_weight,
    },
    Drinks={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.booze) end,
        decode=decode_mat_weight,
    },
    Meat={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.meat) end,
        decode=decode_mat_weight,
    },
    Leather={
        get_mats=function(resources) return transform_mat_list(resources.organic.leather) end,
        decode=decode_mat_weight,
    },
    Parchment={
        get_mats=function(resources) return transform_mat_list(resources.organic.parchment) end,
        decode=decode_mat_weight,
    },
    SmallCutGems={
        get_mats=function(resources) return resources.gems end,
        decode=function(id) return dfhack.matinfo.decode(0, id).material.solid_density end,
    },
    CupsMugsGoblets={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.crafts) end,
        decode=decode_mat_weight,
    },
    Crafts={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.crafts) end,
        decode=decode_mat_weight,
    },
    FlasksWaterskins={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.flasks) end,
        decode=decode_mat_weight,
    },
    Quivers={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.quivers) end,
        decode=decode_mat_weight,
    },
    Backpacks={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.backpacks) end,
        decode=decode_mat_weight,
    },
    Barrels={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.barrels) end,
        decode=decode_mat_weight,
    },
    Sand={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.sand) end,
        decode=decode_mat_weight,
    },
    Glass={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.glass) end,
        decode=decode_mat_weight,
    },
    Clay={
        get_mats=function(resources) return transform_mat_list(resources.misc_mat.clay) end,
        decode=decode_mat_weight,
    },
    ClothPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_weight },
    ThreadPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_weight },
    RopesPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_weight },
    BagsPlant={ get_mats=function(resources) return transform_mat_list(resources.organic.fiber) end, decode=decode_mat_weight },
    ClothSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_weight },
    ThreadSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_weight },
    RopesSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_weight },
    BagsSilk={ get_mats=function(resources) return transform_mat_list(resources.organic.silk) end, decode=decode_mat_weight },
    ClothYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_weight },
    ThreadYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_weight },
    RopesYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_weight },
    BagsYarn={ get_mats=function(resources) return transform_mat_list(resources.organic.wool) end, decode=decode_mat_weight },
    Plants={
        get_mats=function(resources) return resources.plants end,
        decode=function(id) return dfhack.matinfo.decode(df.builtin_mats.PLANT, id).material.solid_density end,
    },
    GardenVegetables={
        get_mats=function(resources) return resources.shrub_fruit_plants end,
        decode=function(id) return dfhack.matinfo.decode(df.builtin_mats.PLANT, id).material.solid_density end,
    },
}
select_by_weight_tab.LargeCutGems = select_by_weight_tab.SmallCutGems

local function get_cur_tab_category()
    return diplomacy.taking_requests_tablist[diplomacy.taking_requests_selected_tab]
end

local function get_select_by_value_tab(category)
    category = category or get_cur_tab_category()
    return select_by_value_tab[df.entity_sell_category[category]]
end

local function get_select_by_weight_tab(category)
    category = category or get_cur_tab_category()
    return select_by_weight_tab[df.entity_sell_category[category]]
end

local function get_cur_priority_list()
    return diplomacy.environment.dipev.sell_requests.priority[get_cur_tab_category()]
end

local function diplomacy_toggle_cat()
    local priority = get_cur_priority_list()
    if not priority or #priority == 0 then return end
    local target_val = priority[0] == 0 and 4 or 0
    for i in ipairs(priority) do
        priority[i] = target_val
    end
end

local function diplomacy_toggle_all_cats()
    local target_val = 4
    local all_selected = true
    for _, cat in ipairs(diplomacy.taking_requests_tablist) do
        local priority = diplomacy.environment.dipev.sell_requests.priority[cat]
        if priority then
            for i in ipairs(priority) do
                if priority[i] ~= 4 then
                    all_selected = false
                    break
                end
            end
        end
        if not all_selected then break end
    end
    if all_selected then
        target_val = 0
    end

    for _, cat in ipairs(diplomacy.taking_requests_tablist) do
        local priority = diplomacy.environment.dipev.sell_requests.priority[cat]
        if priority then
            for i in ipairs(priority) do
                priority[i] = target_val
            end
        end
    end
end

local function select_by_value(prices, val)
    local priority = get_cur_priority_list()
    if not priority then return end
    for i in ipairs(priority) do
        if prices[i] == val then
            priority[i] = 4
        end
    end
end

local function get_civ_key()
    local civ = df.historical_entity.find(diplomacy.actor.civ_id)
    if not civ then return 'UNKNOWN' end
    local name = dfhack.translation.translateName(civ.name)
    local race = df.creature_raw.find(civ.race)
    local race_name = race and race.name[0] or 'Unknown'
    -- Save by race+name to distinguish different dwarven/elven civs, or just race
    -- "MOUNTAIN" is the raw id, but race_name is "dwarf". We'll use civ ID to be safe,
    -- or race_name to make it portable. Let's use race_name + civ_id to prevent clashes,
    -- but actually the user asked for different civilizations. Let's key by the civ's translated name.
    -- Better yet, key by the English translated name to make it readable in the JSON.
    return dfhack.translation.translateName(civ.name, true)
end

local CONFIG_FILE = 'dfhack-config/trade-agreements.json'

local function save_requests()
    local key = get_civ_key()
    local data = {}
    if dfhack.filesystem.isfile(CONFIG_FILE) then
        data = json.decode_file(CONFIG_FILE) or {}
    end

    local civ_data = data[key] or {}
    for _, cat in ipairs(diplomacy.taking_requests_tablist) do
        local cat_name = df.entity_sell_category[cat]
        local priority = diplomacy.environment.dipev.sell_requests.priority[cat]
        if priority then
            local saved_priority = {}
            local has_requests = false
            for i in ipairs(priority) do
                if priority[i] ~= 0 then
                    saved_priority[tostring(i)] = priority[i]
                    has_requests = true
                end
            end
            if has_requests then
                civ_data[cat_name] = saved_priority
            else
                civ_data[cat_name] = nil
            end
        end
    end

    data[key] = civ_data
    json.encode_file(data, CONFIG_FILE, {pretty=true})
    dfhack.gui.showAnnouncement('Trade requests saved for ' .. key, COLOR_GREEN)
end

local function load_requests()
    if not dfhack.filesystem.isfile(CONFIG_FILE) then
        dfhack.gui.showAnnouncement('No saved trade agreements found.', COLOR_RED)
        return
    end

    local data = json.decode_file(CONFIG_FILE)
    if not data then return end

    local key = get_civ_key()
    local civ_data = data[key]

    if not civ_data then
        dfhack.gui.showAnnouncement('No saved requests found for ' .. key, COLOR_YELLOW)
        return
    end

    for _, cat in ipairs(diplomacy.taking_requests_tablist) do
        local cat_name = df.entity_sell_category[cat]
        local priority = diplomacy.environment.dipev.sell_requests.priority[cat]
        if priority then
            local saved_priority = civ_data[cat_name] or {}
            for i in ipairs(priority) do
                priority[i] = saved_priority[tostring(i)] or 0
            end
        end
    end

    dfhack.gui.showAnnouncement('Trade requests loaded for ' .. key, COLOR_GREEN)
end

function TradeAgreementOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0, w=23},
            label='Select all/none',
            key='CUSTOM_CTRL_A',
            on_activate=diplomacy_toggle_cat,
        },
        widgets.HotkeyLabel{
            frame={t=1, l=0, w=23},
            label='Select globally',
            key='CUSTOM_SHIFT_A',
            on_activate=diplomacy_toggle_all_cats,
        },
        widgets.HotkeyLabel{
            frame={t=2, l=0, w=23},
            label='Select by value',
            key='CUSTOM_CTRL_M',
            on_activate=self:callback('select_by_value'),
            enabled=get_select_by_value_tab,
        },
        widgets.HotkeyLabel{
            frame={t=0, l=24, w=23},
            label='Save requests',
            key='CUSTOM_CTRL_S',
            on_activate=save_requests,
        },
        widgets.HotkeyLabel{
            frame={t=1, l=24, w=23},
            label='Load requests',
            key='CUSTOM_CTRL_L',
            on_activate=load_requests,
        },
        widgets.HotkeyLabel{
            frame={t=2, l=24, w=23},
            label='Select by weight',
            key='CUSTOM_CTRL_W',
            on_activate=self:callback('select_by_weight'),
            enabled=get_select_by_weight_tab,
        },
    }
end

local function get_prices(tab)
    local resource = tab.get_mats(df.historical_entity.find(diplomacy.actor.civ_id).resources)
    if not resource then return {}, {} end
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

function TradeAgreementOverlay:select_by_weight()
    local cat = get_cur_tab_category()
    local cur_tab = get_select_by_weight_tab(cat)

    local resource_name = df.entity_sell_category[cat]
    local prices, matValuesUnique = get_prices(cur_tab)
    local list = {}
    for index, value in ipairs(matValuesUnique) do
        list[index] = ('%4d (%d type%s of %s)'):format(
            value.value, value.count, value.count == 1 and '' or 's', resource_name:lower())
    end
    dlg.showListPrompt(
        "Select materials with solid density", "",
        COLOR_WHITE,
        list,
        function(id) select_by_value(prices, matValuesUnique[id].value) end
    )
end

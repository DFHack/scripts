--@module = true

local argparse = require('argparse')
local dlg = require('gui.dialogs')
local gui = require('gui')
local overlay = require('plugins.overlay')
local sitemap = reqscript('gui/sitemap')
local utils = require('utils')
local widgets = require('gui.widgets')

local CH_UP = string.char(30)
local CH_DN = string.char(31)
local ENGLISH_COL_WIDTH = 16
local NATIVE_COL_WIDTH = 16

local language = df.global.world.raws.language
local translations = df.language_translation.get_vector()

--
-- target selection
--

local entity_names = {
    [df.language_name_type.Figure]=df.entity_name_type.OTHER,
    [df.language_name_type.FigureFirstOnly]=df.entity_name_type.OTHER,
    [df.language_name_type.FigureNoFirst]=df.entity_name_type.OTHER,
    [df.language_name_type.Civilization]=df.entity_name_type.CIV,
    [df.language_name_type.EntitySite]=df.entity_name_type.SITE,
    [df.language_name_type.Site]=df.entity_name_type.OTHER,
    [df.language_name_type.Squad]=df.entity_name_type.OTHER,
    [df.language_name_type.Temple]=df.entity_name_type.TEMPLE,
    [df.language_name_type.Library]=df.entity_name_type.LIBRARY,
    [df.language_name_type.Hospital]=df.entity_name_type.HOSPITAL,
}

local category_names = {
    [df.language_name_type.World]=df.language_name_category.Region,
    [df.language_name_type.Region]=df.language_name_category.Region,
    [df.language_name_type.LegendaryFigure]=df.language_name_category.Unit,
    [df.language_name_type.FigureNoFirst]=df.language_name_category.Unit,
    [df.language_name_type.FigureFirstOnly]=df.language_name_category.Unit,
    [df.language_name_type.Figure]=df.language_name_category.Unit,
    [df.language_name_type.Religion]=df.language_name_category.CommonReligion,
    [df.language_name_type.Temple]=df.language_name_category.Temple,
    [df.language_name_type.FoodStore]=df.language_name_category.FoodStore,
    [df.language_name_type.Library]=df.language_name_category.Library,
    [df.language_name_type.Guildhall]=df.language_name_category.Guildhall,
    [df.language_name_type.Hospital]=df.language_name_category.Hospital,
}

local wt = language.word_table

local function get_word_selectors(name_type, civ)
    -- special cases
    if name_type == df.language_name_type.Artifact then
        -- The game normally only uses ArtifactEvil if it was created by a fell/macabre mood, but we don't know
        -- at this point, so we'll randomize the choice
        if math.random(5) == 1 then
            return wt[0][df.language_name_category.ArtifactEvil], wt[1][df.language_name_category.ArtifactEvil]
        else
            return wt[0][df.language_name_category.Artifact], wt[1][df.language_name_category.Artifact]
        end
    end

    -- entity-based names
    local etype = entity_names[name_type]
    if civ and etype then
        return civ.entity_raw.symbols.symbols_major[etype], civ.entity_raw.symbols.symbols_minor[etype]
    end

    -- category-based names
    local ctype = category_names[name_type]
    if ctype then
        return wt[0][ctype], wt[1][ctype]
    end

    -- default to something generic with a lot of word choices
    return wt[0][df.language_name_category.River], wt[1][df.language_name_category.River]
end

local function get_artifact_target(item)
    if not item or not item.flags.artifact then return end
    local gref = dfhack.items.getGeneralRef(item, df.general_ref_type.IS_ARTIFACT)
    if not gref then return end
    local rec = df.artifact_record.find(gref.artifact_id)
    if not rec then return end
    return {name=rec.name}
end

local function get_hf_target(hf)
    if not hf then return end
    local name = dfhack.units.getVisibleName(hf)
    local unit = df.unit.find(hf.unit_id)
    local sync_names = {}
    if unit then
        local unit_name = dfhack.units.getVisibleName(unit)
        if unit_name ~= name then
            table.insert(sync_names, unit_name)
        end
    end
    return {name=name, sync_names=sync_names, civ_id=hf.civ_id}
end

local function get_unit_target(unit)
    if not unit then return end
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if hf then
        return get_hf_target(hf)
    end
    -- unit with no hf
    return {name=dfhack.units.getVisibleName(unit), civ_id=unit.civ_id}
end

local function get_civ_id_from_entity(entity)
    if not entity then return end
    if entity.type == df.historical_entity_type.Civilization then return entity.id end
    for _,ee_link in ipairs(entity.entity_links) do
        if ee_link.type ~= df.entity_entity_link_type.PARENT then goto continue end
        local linked_he = df.historical_entity.find(ee_link.target)
        if linked_he and linked_he.type == df.historical_entity_type.Civilization then
            return ee_link.target
        end
        ::continue::
    end
end

local function get_civ_id_from_site(site)
    if not site then return end
    for _,he_link in ipairs(site.entity_links) do
        if he_link.type ~= df.entity_site_link_type.All then goto continue end
        local linked_he = df.historical_entity.find(he_link.entity_id)
        if linked_he and linked_he.type == df.historical_entity_type.Civilization then
            return he_link.entity_id
        end
        ::continue::
    end
end

local function get_entity_target(entity)
    if not entity then return end
    return {name=entity.name, civ_id=get_civ_id_from_entity(entity)}
end

local function get_site_target(site)
    if not site then return end
    return {name=site.name, civ_id=get_civ_id_from_site(site)}
end

local function get_location_target(site, loc_id)
    if not site or loc_id < 0 then return end
    local loc = utils.binsearch(site.buildings, loc_id, 'id')
    if not loc then return end
    return {name=loc.name, civ_id=get_civ_id_from_site(site)}
end

local function get_squad_target(fort, squad)
    return {name=squad.name, civ_id=get_civ_id_from_entity(fort)}
end

local function get_world_target()
    local name = df.global.world.world_data.name
    local sync_names = {
        function()
            df.global.world.cur_savegame.world_header.world_name =
                ('%s, "%s"'):format(dfhack.translation.translateName(name),
                    dfhack.translation.translateName(name, true))
        end
    }
    return {name=name, sync_names=sync_names}
end

local function select_artifact(cb)
    local choices = {}
    for _, item in ipairs(df.global.world.items.other.ANY_ARTIFACT) do
        if item.flags.garbage_collect then goto continue end
        local target = get_artifact_target(item)
        if not target then goto continue end
        table.insert(choices, {
            text=dfhack.items.getReadableDescription(item),
            data={target=target},
        })
        ::continue::
    end
    dlg.showListPrompt('Rename', 'Select an artifact to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end, nil, nil, true)
end

local function select_location(site, cb)
    local choices = {}
    for _,loc in ipairs(site.buildings) do
        local desc, pen = sitemap.get_location_desc(loc)
        table.insert(choices, {
            text={
                dfhack.translation.translateName(loc.name, true),
                ' (',
                {text=desc, pen=pen},
                ')',
            },
            data={target=get_location_target(site, loc.id)},
        })
    end
    dlg.showListPrompt('Rename', 'Select a location to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end, nil, nil, true)
end

local function select_entity(entity, cb)
    cb(get_entity_target(entity))
end

local function select_site(site, cb)
    cb(get_site_target(site))
end

local function select_squad(fort, cb)
    local choices = {}
    for _,squad_id in ipairs(fort.squads) do
        local squad = df.squad.find(squad_id)
        if squad then
            table.insert(choices, {
                text=dfhack.military.getSquadName(squad.id),
                data={target=get_squad_target(fort, squad)},
            })
        end
    end
    dlg.showListPrompt('Rename', 'Select a squad to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end, nil, nil, true)
end

local function select_unit(cb)
    local choices = {}
    -- scan through units.all instead of units.active so we can choose starting dwarves on embark prep screen
    for _,unit in ipairs(df.global.world.units.all) do
        if not dfhack.units.isActive(unit) then goto continue end
        local target = get_unit_target(unit)
        if not target then goto continue end
        table.insert(choices, {
            text=dfhack.units.getReadableName(unit),
            data={target=target},
        })
        ::continue::
    end
    dlg.showListPrompt('Rename', 'Select a unit to rename:', COLOR_WHITE,
        choices, function(_, choice) cb(choice.data.target) end,
        nil, nil, true)
end

local function select_world(cb)
    cb(get_world_target())
end

local function select_new_target(cb)
    local choices = {}
    if #df.global.world.items.other.ANY_ARTIFACT > 0 then
        table.insert(choices, {text='An artifact', data={fn=select_artifact}})
    end
    if #df.global.world.units.all > 0 then
        table.insert(choices, {text='A unit', data={fn=select_unit}})
    end
    local site = dfhack.world.getCurrentSite()
    local is_fort_mode = dfhack.world.isFortressMode()
    local fort = is_fort_mode and df.historical_entity.find(df.global.plotinfo.group_id)
    local civ = is_fort_mode and df.historical_entity.find(df.global.plotinfo.civ_id)
    if site then
        if fort and #fort.squads > 0 then
            table.insert(choices, {text='A squad', data={fn=curry(select_squad, fort)}})
        end
        if #site.buildings > 0 then
            table.insert(choices, {text='A location', data={fn=curry(select_location, site)}})
        end
        table.insert(choices, {text='This fortress/site', data={fn=curry(select_site, site)}})
    end
    if fort then
        table.insert(choices, {text='The government of this fortress', data={fn=curry(select_entity, fort)}})
    end
    if civ then
        table.insert(choices, {text='The civilization of this fortress', data={fn=curry(select_entity, civ)}})
    end
    table.insert(choices, {text='The world', data={fn=select_world}})
    dlg.showListPrompt('Rename', 'What would you like to rename?', COLOR_WHITE,
        choices, function(_, choice) choice.data.fn(cb) end)
end

--
-- Rename
--

Rename = defclass(Rename, widgets.Window)
Rename.ATTRS {
    frame_title='Rename',
    frame={w=89, h=43},
    resizable=true,
    resize_min={w=61},
}

local function get_language_options()
    local options, max_width = {}, 5
    for idx, lang in ipairs(translations) do
        max_width = math.max(max_width, #lang.name)
        table.insert(options, {label=dfhack.capitalizeStringWords(dfhack.lowerCp437(lang.name)), value=idx, pen=COLOR_CYAN})
    end
    return options, max_width
end

local function pad_text(text, width)
    return (' '):rep((width - #text)//2) .. text
end

local function sort_by_english_desc(a, b)
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native < b_native
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_english_asc(a, b)
    if a.data.english ~= b.data.english then
        return a.data.english > b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native < b_native
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_native_desc(a, b)
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native < b_native
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_native_asc(a, b)
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    if a_native ~= b_native then
        return a_native > b_native
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    return a.data.part_of_speech < b.data.part_of_speech
end

local function sort_by_part_of_speech_desc(a, b)
    if a.data.part_of_speech ~= b.data.part_of_speech then
        return a.data.part_of_speech < b.data.part_of_speech
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    return a_native < b_native
end

local function sort_by_part_of_speech_asc(a, b)
    if a.data.part_of_speech ~= b.data.part_of_speech then
        return a.data.part_of_speech > b.data.part_of_speech
    end
    if a.data.english ~= b.data.english then
        return a.data.english < b.data.english
    end
    local a_native, b_native = a.data.native_fn(), b.data.native_fn()
    return a_native < b_native
end

function Rename:init(info)
    self.target = info.target
    self.cache = {}

    local function normalize_name()
        if self.target.name.type == df.language_name_type.NONE then
            self.target.name.type = df.language_name_type.Figure
        end
        self.target.sync_names = self.target.sync_names or {}
    end
    normalize_name()

    local language_options, max_lang_name_width = get_language_options()

    self:addviews{
        widgets.Panel{frame={t=0, h=7}, -- header
            subviews={
                widgets.HotkeyLabel{
                    frame={t=0, l=0},
                    key='CUSTOM_CTRL_N',
                    label='Select new target',
                    auto_width=true,
                    on_activate=function()
                        select_new_target(function(target)
                            if not target then return end
                            self.target = target
                            normalize_name()
                            self.subviews.language:setOption(self.target.name.language)
                            self:refresh_list()
                        end)
                    end,
                    visible=info.show_selector,
                },
                widgets.HotkeyLabel{
                    frame={t=0, r=0},
                    key='CUSTOM_CTRL_G',
                    label='Generate random name',
                    auto_width=true,
                    on_activate=self:callback('generate_random_name'),
                },
                widgets.Label{
                    frame={t=2},
                    text={{pen=COLOR_YELLOW, text=function() return pad_text(dfhack.translation.translateName(self.target.name), self.frame_body.width) end}},
                },
                widgets.Label{
                    frame={t=3},
                    text={{pen=COLOR_LIGHTCYAN, text=function() return pad_text(('"%s"'):format(dfhack.translation.translateName(self.target.name, true)), self.frame_body.width) end}},
                },
                widgets.CycleHotkeyLabel{
                    view_id='language',
                    frame={t=5, l=0, w=max_lang_name_width + 18},
                    key='CUSTOM_CTRL_T',
                    label='Language:',
                    options=language_options,
                    initial_option=self.target.name.language,
                    on_change=self:callback('set_language'),
                },
                widgets.Label{
                    frame={t=6, l=7},
                    text={'Name type: ', {pen=COLOR_CYAN, text=function() return df.language_name_type[self.target.name.type] end}},
                },
            },
        },
        widgets.Divider{frame={t=8, l=29, w=1},
            frame_style=gui.FRAME_THIN,
            frame_style_t=false,
            frame_style_b=false,
        },
        widgets.Panel{frame={t=8}, -- body
            subviews={
                widgets.Panel{frame={t=0, l=0, w=30}, -- component selector
                    subviews={
                        widgets.Label{
                            frame={t=0, l=0},
                            text='Name components:',
                        },
                        widgets.List{
                            frame={t=2, l=0, b=4, w=ENGLISH_COL_WIDTH+2},
                            view_id='component_list',
                            on_select=function() self:refresh_list() end,
                            choices=self:get_component_choices(),
                            row_height=3,
                            scroll_keys={},
                        },
                        widgets.List{
                            frame={t=2, l=ENGLISH_COL_WIDTH+4, b=4},
                            on_submit=function(_, choice) choice.data.fn() end,
                            choices=self:get_component_action_choices(),
                            cursor_pen=COLOR_CYAN,
                            scroll_keys={},
                        },
                        widgets.HotkeyLabel{
                            frame={b=3, l=0},
                            --key='SECONDSCROLL_UP', -- use when this is available in mainline DF
                            key='STRING_A045',
                            label='Prev component',
                            on_activate=function()
                                local clist = self.subviews.component_list
                                local move = self.target.name.type ~= df.language_name_type.Figure and
                                    clist:getSelected() == 2 and #clist:getChoices()-2 or -1
                                self.subviews.component_list:moveCursor(move)
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=2, l=0},
                            -- key='SECONDSCROLL_DOWN', -- use when this is available in mainline DF
                            key='STRING_A043',
                            label='Next component',
                            on_activate=function()
                                local clist = self.subviews.component_list
                                local move = self.target.name.type ~= df.language_name_type.Figure and
                                    clist:getSelected() == #clist:getChoices() and -#clist:getChoices()+2 or 1
                                self.subviews.component_list:moveCursor(move)
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=1, l=0},
                            key='CUSTOM_CTRL_D',
                            label='Randomize component',
                            on_activate=function()
                                local _, comp_choice = self.subviews.component_list:getSelected()
                                if comp_choice.data.is_first_name then
                                    self:randomize_first_name()
                                else
                                    self:randomize_component_word(comp_choice.data.val)
                                end
                            end,
                        },
                        widgets.HotkeyLabel{
                            frame={b=0, l=0},
                            key='CUSTOM_CTRL_H',
                            label='Clear component',
                            on_activate=function()
                                local _, comp_choice = self.subviews.component_list:getSelected()
                                self:clear_component_word(comp_choice.data.val)
                            end,
                            enabled=function()
                                local _, comp_choice = self.subviews.component_list:getSelected()
                                if comp_choice.data.is_first_name then return false end
                                return self.target.name.words[comp_choice.data.val] >= 0
                            end,
                        },
                    },
                },
                widgets.Panel{frame={t=0, l=31, r=0}, -- words table
                    subviews={
                        widgets.CycleHotkeyLabel{
                            view_id='sort',
                            frame={t=0, l=0, w=19},
                            label='Change sort',
                            key='CUSTOM_CTRL_O',
                            options={
                                {label='', value=sort_by_english_desc},
                                {label='', value=sort_by_english_asc},
                                {label='', value=sort_by_native_desc},
                                {label='', value=sort_by_native_asc},
                                {label='', value=sort_by_part_of_speech_desc},
                                {label='', value=sort_by_part_of_speech_asc},
                            },
                            initial_option=sort_by_english_desc,
                            on_change=self:callback('refresh_list', 'sort'),
                        },
                        widgets.EditField{
                            view_id='search',
                            frame={t=0, l=22},
                            label_text='Search: ',
                            -- ignore_keys={'SECONDSCROLL_DOWN', 'SECONDSCROLL_UP'}
                            ignore_keys={'STRING_A043', 'STRING_A045'},
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='sort_english',
                            frame={t=2, l=0, w=8},
                            options={
                                {label='English', value=DEFAULT_NIL},
                                {label='English'..CH_DN, value=sort_by_english_desc},
                                {label='English'..CH_UP, value=sort_by_english_asc},
                            },
                            initial_option=sort_by_english_desc,
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_english'),
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='sort_native',
                            frame={t=2, l=ENGLISH_COL_WIDTH+2, w=7},
                            options={
                                {label='native', value=DEFAULT_NIL},
                                {label='native'..CH_DN, value=sort_by_native_desc},
                                {label='native'..CH_UP, value=sort_by_native_asc},
                            },
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_native'),
                        },
                        widgets.CycleHotkeyLabel{
                            view_id='sort_part_of_speech',
                            frame={t=2, l=ENGLISH_COL_WIDTH+2+NATIVE_COL_WIDTH+2, w=15},
                            options={
                                {label='part of speech', value=DEFAULT_NIL},
                                {label='part_of_speech'..CH_DN, value=sort_by_part_of_speech_desc},
                                {label='part_of_speech'..CH_UP, value=sort_by_part_of_speech_asc},
                            },
                            option_gap=0,
                            on_change=self:callback('refresh_list', 'sort_part_of_speech'),
                        },
                        widgets.FilteredList{
                            view_id='words_list',
                            frame={t=4, l=0, b=0, r=0},
                            on_submit=self:callback('set_component_word'),
                        },
                    },
                },
            },
        },
    }

    -- replace the FilteredList's built-in EditField with our own
    self.subviews.words_list.list.frame.t = 0
    self.subviews.words_list.edit.visible = false
    self.subviews.words_list.edit = self.subviews.search
    self.subviews.search.on_change = self.subviews.words_list:callback('onFilterChange')

    self:refresh_list()
end

function Rename:get_component_choices()
    local choices = {}
    table.insert(choices, {
            text={
                {text='First Name',
                    pen=function() return self.target.name.type ~= df.language_name_type.Figure and COLOR_GRAY or nil end},
                NEWLINE,
                {gap=2, pen=COLOR_YELLOW, text=function() return self.target.name.first_name end}
            },
            data={val=df.language_name_component.TheX, is_first_name=true}})
    for val, comp in ipairs(df.language_name_component) do
        local text = {
            {text=comp:gsub('(%l)(%u)', '%1 %2')}, NEWLINE,
            {gap=2, pen=COLOR_YELLOW, text=function()
                local word = self.target.name.words[val]
                if word < 0 then return end
                return ('%s'):format(language.words[word].forms[self.target.name.parts_of_speech[val]])
            end},
        }
        table.insert(choices, {text=text, data={val=val}})
    end
    return choices
end

function Rename:get_component_action_choices()
    local choices = {}
    table.insert(choices, {
        text={
            {text='[', pen=function() return self.target.name.type ~= df.language_name_type.Figure and COLOR_GRAY or COLOR_RED end},
            {text='Random', pen=function() return self.target.name.type ~= df.language_name_type.Figure and COLOR_GRAY or nil end},
            {text=']', pen=function() return self.target.name.type ~= df.language_name_type.Figure and COLOR_GRAY or COLOR_RED end}
        },
        data={fn=self:callback('randomize_first_name')},
    })
    table.insert(choices, {text='', data={fn=function() end}}) -- shouldn't be able to clear a first name, only overwrite
    table.insert(choices, {text='', data={fn=function() end}})

    local randomize_text = {{text='[', pen=COLOR_RED}, 'Random', {text=']', pen=COLOR_RED}}
    for comp in ipairs(df.language_name_component) do
        local randomize_fn = self:callback('randomize_component_word', comp)
        table.insert(choices, {text=randomize_text, data={fn=randomize_fn}})
        local clear_text = {
            {text=function() return self.target.name.words[comp] >= 0 and '[' or '' end, pen=COLOR_RED},
            {text=function() return self.target.name.words[comp] >= 0 and 'Clear' or '' end },
            {text=function() return self.target.name.words[comp] >= 0 and ']' or '' end, pen=COLOR_RED}
        }
        local clear_fn = self:callback('clear_component_word', comp)
        table.insert(choices, {text=clear_text, data={fn=clear_fn}})
        table.insert(choices, {text='', data={fn=function() end}})
    end
    return choices
end

function Rename:clear_component_word(comp)
    self.target.name.words[comp] = -1
    for _, sync_name in ipairs(self.target.sync_names) do
        if type(sync_name) == 'function' then
            sync_name()
        else
            sync_name.words[comp] = -1
        end
    end
end

function Rename:set_first_name(word_idx)
    -- support giving names to previously unnamed units
    self.target.name.has_name = true

    self.target.name.first_name = translations[self.subviews.language:getOptionValue()].words[word_idx].value
    for _, sync_name in ipairs(self.target.sync_names) do
        if type(sync_name) == 'function' then
            sync_name()
        else
            sync_name.first_name = self.target.name.first_name
        end
    end
end

function Rename:set_component_word_by_data(component, word_idx, part_of_speech)
    self.target.name.words[component] = word_idx
    self.target.name.parts_of_speech[component] = part_of_speech
    for _, sync_name in ipairs(self.target.sync_names) do
        if type(sync_name) == 'function' then
            sync_name()
        else
            sync_name.words[component] = word_idx
            sync_name.parts_of_speech[component] = part_of_speech
        end
    end
end

function Rename:set_component_word(_, choice)
    local _, comp_choice = self.subviews.component_list:getSelected()
    if comp_choice.data.is_first_name then
        self:set_first_name(choice.data.idx)
        return
    end
    self:set_component_word_by_data(comp_choice.data.val, choice.data.idx, choice.data.part_of_speech)
end

function Rename:set_language(val, prev_val)
    self.target.name.language = val
    -- translate current first name into target language
    local idx = utils.linear_index(translations[prev_val].words, self.target.name.first_name, 'value')
    if idx then self.target.name.first_name = translations[val].words[idx].value end
    for _, sync_name in ipairs(self.target.sync_names) do
        if type(sync_name) == 'function' then
            sync_name()
        else
            sync_name.language = val
            sync_name.first_name = self.target.name.first_name
        end
    end
end

function Rename:randomize_first_name()
    if self.target.name.type ~= df.language_name_type.Figure then return end
    local choices = self:get_word_choices(df.language_name_component.TheX)
    self:set_first_name(choices[math.random(#choices)].data.idx)
end

function Rename:randomize_component_word(comp)
    local choices = self:get_word_choices(df.language_name_component.TheX)
    local choice = choices[math.random(#choices)]
    self:set_component_word_by_data(comp, choice.data.idx, choice.data.part_of_speech)
end

function Rename:generate_random_name()
    local civ
    if self.target.civ_id then
        civ = df.historical_entity.find(self.target.civ_id)
    end
    local major_selector, minor_selector = get_word_selectors(self.target.name.type, civ)
    dfhack.translation.generateName(self.target.name, self.target.name.language,
        self.target.name.type, major_selector, minor_selector)
    for _, sync_name in ipairs(self.target.sync_names) do
       if type(sync_name) == 'function' then
          sync_name()
      else
         df.assign(sync_name, self.target.name)
      end
    end
end

local part_of_speech_to_display = {
    [df.part_of_speech.Noun] = 'Singular Noun',
    [df.part_of_speech.NounPlural] = 'Plural Noun',
    [df.part_of_speech.Adjective] = 'Adjective',
    [df.part_of_speech.Prefix] = 'Prefix',
    [df.part_of_speech.Verb] = 'Present (1st)',
    [df.part_of_speech.Verb3rdPerson] = 'Present (3rd)',
    [df.part_of_speech.VerbPast] = 'Preterite',
    [df.part_of_speech.VerbPassive] = 'Past Participle',
    [df.part_of_speech.VerbGerund] = 'Present Participle',
}

function Rename:add_word_choice(choices, comp, idx, word, part_of_speech)
    local english = word.forms[part_of_speech]
    if #english == 0 then return end
    local function get_native()
        return translations[self.subviews.language:getOptionValue()].words[idx].value
    end
    local part = part_of_speech_to_display[part_of_speech]
    local clist = self.subviews.component_list
    local function get_pen()
        local _, comp_choice = clist:getSelected()
        if comp_choice.data.is_first_name then
            return get_native() == self.target.name.first_name and COLOR_YELLOW or nil
        end
        if idx == self.target.name.words[comp] and part_of_speech == self.target.name.parts_of_speech[comp] then
            return COLOR_YELLOW
        end
    end
    table.insert(choices, {
        text={
            {text=english, width=ENGLISH_COL_WIDTH, pen=get_pen},
            {gap=2, text=get_native, width=NATIVE_COL_WIDTH, pen=get_pen},
            {gap=2, text=part, width=15, pen=get_pen},
        },
        search_key=function() return ('%s %s %s'):format(english, get_native(), part) end,
        data={idx=idx, english=english, native_fn=get_native, part_of_speech=part_of_speech},
    })
end

function Rename:get_word_choices(comp)
    if self.cache[comp] then
        return self.cache[comp]
    end

    local choices = {}
    for idx, word in ipairs(language.words) do
        local flags = word.flags
        if comp == df.language_name_component.FrontCompound then
            if flags.front_compound_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.front_compound_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.front_compound_adj then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective) end
            if flags.front_compound_prefix then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Prefix) end
            if flags.standard_verb then
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Verb)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbPassive)
            end
        elseif comp == df.language_name_component.RearCompound then
            if flags.rear_compound_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.rear_compound_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.rear_compound_adj then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective) end
            if flags.standard_verb then
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Verb)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Verb3rdPerson)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbPast)
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbPassive)
            end
        elseif comp == df.language_name_component.FirstAdjective or comp == df.language_name_component.SecondAdjective then
            self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective)
        elseif comp == df.language_name_component.HyphenCompound then
            if flags.the_compound_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.the_compound_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.the_compound_adj then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Adjective) end
            if flags.the_compound_prefix then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Prefix) end
        elseif comp == df.language_name_component.TheX then
            if flags.the_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.the_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
        elseif comp == df.language_name_component.OfX then
            if flags.of_noun_sing then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.Noun) end
            if flags.of_noun_plur then self:add_word_choice(choices, comp, idx, word, df.part_of_speech.NounPlural) end
            if flags.standard_verb then
                self:add_word_choice(choices, comp, idx, word, df.part_of_speech.VerbGerund)
            end
        end
    end

    self.cache[comp] = choices
    return choices
end

function Rename:refresh_list(sort_widget, sort_fn)
    local clist = self.subviews.component_list
    if not clist then return end
    if self.target.name.type ~= df.language_name_type.Figure and clist:getSelected() == 1 then
        clist:setSelected(self.prev_selected_component ~= 1 and self.prev_selected_component or 2)
    end
    self.prev_selected_component = clist:getSelected()

    sort_widget = sort_widget or 'sort'
    sort_fn = sort_fn or self.subviews.sort:getOptionValue()
    if sort_fn == DEFAULT_NIL then
        self.subviews[sort_widget]:cycle()
        return
    end
    for _,widget_name in ipairs{'sort', 'sort_english', 'sort_native', 'sort_part_of_speech'} do
        self.subviews[widget_name]:setOption(sort_fn)
    end
    local list = self.subviews.words_list
    local saved_filter = list:getFilter()
    list:setFilter('')
    local _, comp_choice = clist:getSelected()
    local choices = self:get_word_choices(comp_choice.data.val)
    table.sort(choices, sort_fn)
    list:setChoices(choices)
    list:setFilter(saved_filter)
end

--
-- RenameScreen
--

RenameScreen = defclass(RenameScreen, gui.ZScreen)
RenameScreen.ATTRS {
    focus_path='rename',
}

function RenameScreen:init(info)
    self:addviews{
        Rename{
            target=info.target,
            show_selector=info.show_selector,
        }
    }
end

function RenameScreen:onDismiss()
    view = nil
end

--
-- WorldRenameOverlay
--

WorldRenameOverlay = defclass(WorldRenameOverlay, overlay.OverlayWidget)
WorldRenameOverlay.ATTRS {
    desc='Adds a button for renaming newly generated worlds.',
    default_pos={x=57, y=3},
    default_enabled=true,
    viewscreens='new_region',
    frame={w=22, h=1},
    visible=function() return dfhack.isWorldLoaded() end,
}

function WorldRenameOverlay:init()
    self:addviews{
        widgets.TextButton{
            frame={t=0, l=0},
            label='Rename world',
            key='CUSTOM_CTRL_T',
            on_activate=function() dfhack.run_script('gui/rename', '--world', '--no-target-selector') end,
        },
    }
end

--
-- UnitEmbarkRenameOverlay
--

local mi = df.global.game.main_interface

UnitEmbarkRenameOverlay = defclass(UnitEmbarkRenameOverlay, overlay.OverlayWidget)
UnitEmbarkRenameOverlay.ATTRS {
    desc='Allows editing of unit nicknames on the embark preparation screen.',
    default_enabled=true,
    viewscreens='setupdwarfgame/Dwarves',
    fullscreen=true,
    active=function() return mi.view_sheets.open end,
}

local function get_selected_embark_unit()
    local scr = dfhack.gui.getDFViewscreen(true)
    return scr.s_unit[scr.selected_u]
end

function UnitEmbarkRenameOverlay:onInput(keys)
    if (keys.SELECT or keys._STRING) and mi.view_sheets.unit_overview_customizing then
        if mi.view_sheets.unit_overview_entering_nickname then
            if keys.SELECT then
                mi.view_sheets.unit_overview_entering_nickname = false
                return true
            end
            local unit = get_selected_embark_unit()
            if unit then
                if keys._STRING == 0 then
                    unit.name.nickname = string.sub(unit.name.nickname, 1, -2)
                else
                    unit.name.nickname = unit.name.nickname .. string.char(keys._STRING)
                end
                local hf = df.historical_figure.find(unit.hist_figure_id)
                if hf then
                    hf.name.nickname = unit.name.nickname
                end
                return true
            end
        elseif mi.view_sheets.unit_overview_entering_profession_nickname then
            if keys.SELECT then
                mi.view_sheets.unit_overview_entering_profession_nickname = false
                return true
            end
            local unit = get_selected_embark_unit()
            if unit then
                if keys._STRING == 0 then
                    unit.custom_profession = string.sub(unit.custom_profession, 1, -2)
                else
                    unit.custom_profession = unit.custom_profession .. string.char(keys._STRING)
                end
                return true
            end
        end
    end
    return false
end

OVERLAY_WIDGETS = {
    unit_embark=UnitEmbarkRenameOverlay,
    world=WorldRenameOverlay,
}

--
-- CLI
--

if dfhack_flags.module then
    return
end

if not dfhack.isWorldLoaded() then
    qerror('This script requires a world to be loaded')
end

local function get_target(opts)
    local target
    if opts.histfig_id then
        target = get_hf_target(df.historical_figure.find(opts.histfig_id))
        if not target then qerror('Historical figure not found') end
    elseif opts.item_id then
        target = get_artifact_target(df.item.find(opts.item_id))
        if not target then qerror('Artifact not found') end
    elseif opts.location_id then
        local site = opts.site_id and df.world_site.find(opts.site_id) or dfhack.world.getCurrentSite()
        if not site then qerror('Site not found') end
        target = get_location_target(site, opts.location_id)
        if not target then qerror('Location not found') end
    elseif opts.site_id then
        local site = df.world_site.find(opts.site_id)
        if not site then qerror('Site not found') end
        target = site.name
    elseif opts.squad_id then
        local squad = df.squad.find(opts.squad_id)
        if not squad then qerror('Squad not found') end
        target = squad.name
    elseif opts.unit_id then
        target = get_unit_target(df.unit.find(opts.unit_id))
        if not target then qerror('Unit not found') end
    elseif opts.world then
        target = get_world_target()
    end
    return target
end

local function main(args)
    local opts = {
        help=false,
        entity_id=nil,
        histfig_id=nil,
        item_id=nil,
        location_id=nil,
        site_id=nil,
        squad_id=nil,
        unit_id=nil,
        world=false,
        show_selector=true,
    }
    local positionals = argparse.processArgsGetopt(args, {
        { 'a', 'artifact', hasArg=true, handler=function(optarg) opts.item_id = argparse.nonnegativeInt(optarg, 'artifact') end },
        { 'e', 'entity', hasArg=true, handler=function(optarg) opts.entity_id = argparse.nonnegativeInt(optarg, 'entity') end },
        { 'f', 'histfig', hasArg=true, handler=function(optarg) opts.histfig_id = argparse.nonnegativeInt(optarg, 'histfig') end },
        { 'h', 'help', handler = function() opts.help = true end },
        { 'l', 'location', hasArg=true, handler=function(optarg) opts.location_id = argparse.nonnegativeInt(optarg, 'location') end },
        { 'q', 'squad', hasArg=true, handler=function(optarg) opts.squad_id = argparse.nonnegativeInt(optarg, 'squad') end },
        { 's', 'site', hasArg=true, handler=function(optarg) opts.site_id = argparse.nonnegativeInt(optarg, 'site') end },
        { 'u', 'unit', hasArg=true, handler=function(optarg) opts.unit_id = argparse.nonnegativeInt(optarg, 'unit') end },
        { 'w', 'world', handler=function() opts.world = true end },
        { '', 'no-target-selector', handler=function() opts.show_selector = false end },
    })

    if opts.help or positionals[1] == 'help' then
        print(dfhack.script_help())
        return
    end

    local function launch(target)
        view = view and view:raise() or RenameScreen{
            target=target,
            show_selector=opts.show_selector,
        }:show()
    end

    local target = get_target(opts)
    if target then
        launch(target)
        return
    end

    local unit = dfhack.gui.getSelectedUnit(true)
    local item = dfhack.gui.getSelectedItem(true)
    local zone = dfhack.gui.getSelectedCivZone(true)
    if unit then
        target = get_unit_target(unit)
    elseif item then
        target = get_artifact_target(item)
    elseif zone then
        target = get_location_target(df.world_site.find(zone.site_id), zone.location_id)
    end
    if target then
        launch(target)
        return
    end

    if not opts.show_selector then
        qerror('No target selected')
    end

    select_new_target(launch)
end

main{...}

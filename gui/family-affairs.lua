local argparse = require('argparse')
local dlg = require('gui.dialogs')
local gui = require('gui')
local widgets = require('gui.widgets')

----------------------
-- Utility functions
--

local function zoom_to(unit)
    if not unit then return end
    local pos = xyz2pos(dfhack.units.getPosition(unit))
    dfhack.gui.revealInDwarfmodeMap(pos, true, true)
end

local function is_viable_parent(unit, required_pronoun)
    return unit and unit.sex == required_pronoun and dfhack.units.isAdult(unit) and dfhack.units.isSane(unit)
end

local function can_have_spouse(unit)
    if not unit then return end
    local caste_flags = unit.enemy.caste_flags
    return caste_flags.CAN_LEARN and not caste_flags.SLOW_LEARNER
end

-- clears other_hf's link to hf (will clear only one reverse link if there are multiple)
local function remove_hf_link(link_type, hfid, other_hfid)
    local other_hf = df.historical_figure.find(other_hfid)
    if not other_hf then return end
    for i, link in ipairs(other_hf.histfig_links) do
        if link._type == link_type and link.target_hf == hfid then
            other_hf.histfig_links:erase(i)
            link:delete()
            break
        end
    end
end

local function clear_hf_links(link_type, hfid)
    local hf = df.historical_figure.find(hfid)
    if not hf then return end
    for i = #hf.histfig_links-1,0,-1 do
        local link = hf.histfig_links[i]
        if link._type == link_type then
            remove_hf_link(link_type, hfid, link.target_hf)
            hf.histfig_links:erase(i)
            link:delete()
        end
    end
end

local function has_hf_links(link_type, hfid)
    local hf = df.historical_figure.find(hfid)
    if not hf then return false end
    for i = #hf.histfig_links-1,0,-1 do
        local link = hf.histfig_links[i]
        if link._type == link_type then return true end
    end
    return false
end

local function has_spouse_or_lover(unit, target)
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if not hf then return false end
    for _, link in ipairs(hf.histfig_links) do
        if (link._type == df.histfig_hf_link_spousest or link._type == df.histfig_hf_link_loverst) and
            (not target or link.target_hf == target.hist_figure_id)
        then
            return true
        end
    end
end

local function get_lovers(unit)
    local lovers = {}
    if not unit then return lovers end
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if not hf then return lovers end
    for _, link in ipairs(hf.histfig_links) do
        if link._type == df.histfig_hf_link_loverst then
            table.insert(lovers, link.target_hf)
        end
    end
    return lovers
end

local function get_name(unit_or_hf)
    return unit_or_hf and dfhack.units.getReadableName(unit_or_hf) or ''
end

local function get_spouse_hf(unit)
    if not unit then return end
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if not hf then return end
    for _, link in ipairs(hf.histfig_links) do
        if link._type == df.histfig_hf_link_spousest then
            -- may be nil due to hf culling, but then we just treat it as not having a spouse
            return df.historical_figure.find(link.target_hf)
        end
    end
end

local function get_spouse_unit(unit)
    local spouse_hf = get_spouse_hf(unit)
    if not spouse_hf then return end
    return df.unit.find(spouse_hf.unit_id)
end

local function clear_spouse(unit, accept_fn, noconfirm)
    if not unit then return end
    local function do_clear_spouse()
        local spouse = get_spouse_unit(unit)
        clear_hf_links(df.histfig_hf_link_spousest, unit.hist_figure_id)
        if spouse then
            spouse.relationship_ids.Spouse = -1
        end
        unit.relationship_ids.Spouse = -1
        accept_fn()
    end
    if noconfirm then
        do_clear_spouse()
    else
        dlg.showYesNoPrompt('Clear spouse',
            ('Really clear spouse for %s?'):format(get_name(unit)),
            COLOR_YELLOW, do_clear_spouse)
    end
end

-- adds a link to hf pointing to other_hf
local function add_hf_link(link_type, hfid, other_hfid)
    local hf = df.historical_figure.find(hfid)
    if not hf then return end
    local link = link_type:new()
    link.target_hf = other_hfid
    link.link_strength = 100
    hf.histfig_links:insert('#', link)
end

local function set_spouse(unit1, unit2, accept_fn)
    local function do_set_spouse()
        clear_spouse(unit1, function() end, true)
        clear_spouse(unit2, function() end, true)
        unit1.relationship_ids.Spouse = unit2.id
        unit2.relationship_ids.Spouse = unit1.id
        add_hf_link(df.histfig_hf_link_spousest, unit1.hist_figure_id, unit2.hist_figure_id)
        add_hf_link(df.histfig_hf_link_spousest, unit2.hist_figure_id, unit1.hist_figure_id)
        dfhack.gui.showAutoAnnouncement(df.announcement_type.MARRIAGE, xyz2pos(dfhack.units.getPosition(unit1)),
            ('%s and %s have married!'):format(dfhack.translation.translateName(unit1.name),
                dfhack.translation.translateName(unit2.name)),
            COLOR_LIGHTMAGENTA)
        accept_fn()
    end
    local unit1_has_lovers = has_hf_links(df.histfig_hf_link_loverst, unit1.hist_figure_id)
    local unit2_has_lovers = has_hf_links(df.histfig_hf_link_loverst, unit2.hist_figure_id)
    if unit1_has_lovers or unit2_has_lovers then
        dlg.showYesNoPrompt('Clear lovers',
            'New partners have existing lovers. Spurn them?',
            COLOR_YELLOW, function()
                clear_hf_links(df.histfig_hf_link_loverst, unit1.hist_figure_id)
                clear_hf_links(df.histfig_hf_link_loverst, unit2.hist_figure_id)
                do_set_spouse()
            end)
    else
        do_set_spouse()
    end
end

----------------------
-- RelationshipsPage
--

RelationshipsPage = defclass(RelationshipsPage, widgets.Panel)

function RelationshipsPage:init()
    self.cache = {}
    self.unit_id = -1
    self.dirty = 0

    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='Name:',
        },
        widgets.Label{
            frame={t=0, l=6},
            text='None (please select a unit)',
            text_pen=COLOR_YELLOW,
            visible=function() return not self:get_unit() end,
        },
        widgets.Label{
            frame={t=0, l=6},
            text={{text=self:callback('get_name')}},
            text_pen=COLOR_LIGHTMAGENTA,
            auto_width=true,
            on_click=function() zoom_to(self:get_unit()) end,
            visible=self:callback('get_unit'),
        },
        widgets.HotkeyLabel{
            frame={t=2, l=0},
            label="Switch to selected unit",
            key='CUSTOM_U',
            auto_width=true,
            on_activate=self:callback('set_unit'),
            enabled=function()
                local unit = dfhack.gui.getSelectedUnit(true)
                return unit and unit.id ~= self.unit_id
            end,
        },
        widgets.Label{
            frame={t=4, l=0},
            text={{text='Spouse:', pen=function() return can_have_spouse(self:get_unit()) and COLOR_WHITE or COLOR_GRAY end}},
        },
        widgets.Label{
            frame={t=4, l=8},
            text={{text='None', pen=function() return can_have_spouse(self:get_unit()) and COLOR_WHITE or COLOR_GRAY end}},
            visible=function() return not self:get_spouse_unit() and not get_spouse_hf(self:get_unit()) end,
        },
        widgets.Label{
            frame={t=4, l=8},
            text={{text=function() return get_name(self:get_spouse_unit()) end}},
            text_pen=COLOR_BLUE,
            auto_width=true,
            on_click=function() zoom_to(self:get_spouse_unit()) end,
            visible=self:callback('get_spouse_unit'),
        },
        widgets.Label{
            frame={t=4, l=8},
            text={
                {text=function() return get_name(get_spouse_hf(self:get_unit())) end, pen=COLOR_BLUE},
                {gap=1, text='(off-site)', pen=COLOR_YELLOW},
            },
            auto_width=true,
            visible=function() return not self:get_spouse_unit() and get_spouse_hf(self:get_unit()) end,
        },
        widgets.HotkeyLabel{
            frame={t=5, l=2},
            label="Dissolve spouse relationship",
            key='CUSTOM_X',
            auto_width=true,
            on_activate=function() clear_spouse(self:get_unit(), function() self.dirty = 2 end) end,
            visible=function() return get_spouse_hf(self:get_unit()) end,
        },
        widgets.HotkeyLabel{
            frame={t=5, l=2},
            label="Set selected unit as spouse",
            key='CUSTOM_X',
            auto_width=true,
            on_activate=function()
                set_spouse(self:get_unit(), dfhack.gui.getSelectedUnit(true), function() self.dirty = 2 end)
            end,
            visible=function() return not get_spouse_hf(self:get_unit()) end,
            enabled=function()
                local unit = self:get_unit()
                local selected = dfhack.gui.getSelectedUnit(true)
                return unit and not get_spouse_hf(unit) and can_have_spouse(unit) and
                    selected and selected.race == unit.race and selected.id ~= unit.id
            end,
        },
        widgets.Panel{
            frame={t=7, b=0},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text={
                        'Lovers:',
                        {gap=1, text=function() return #self.subviews.lovers:getChoices() end, pen=COLOR_YELLOW},
                    },
                },
                widgets.List{
                    frame={t=2, b=3},
                    view_id='lovers',
                    on_submit=function(_, choice)
                        local hf = df.historical_figure.find(choice.data.hfid)
                        if not hf then return end
                        local unit = df.unit.find(hf.unit_id)
                        if not unit then return end
                        zoom_to(unit)
                    end,
                },
                widgets.HotkeyLabel{
                    frame={b=1, l=0},
                    label='Add selected unit as lover',
                    key='CUSTOM_L',
                    auto_width=true,
                    on_activate=function()
                        local selected = dfhack.gui.getSelectedUnit(true)
                        if not selected then return end
                        local unit = self:get_unit()
                        if not unit then return end
                        add_hf_link(df.histfig_hf_link_loverst, unit.hist_figure_id, selected.hist_figure_id)
                        add_hf_link(df.histfig_hf_link_loverst, selected.hist_figure_id, unit.hist_figure_id)
                        self.dirty = 1
                    end,
                    enabled=function()
                        local unit = self:get_unit()
                        local selected = dfhack.gui.getSelectedUnit(true)
                        return unit and selected and selected.race == unit.race and selected.id ~= unit.id and
                            not has_spouse_or_lover(unit, selected)
                    end,
                },
                widgets.HotkeyLabel{
                    frame={b=0, l=0},
                    label='Remove lover',
                    key='CUSTOM_SHIFT_L',
                    auto_width=true,
                    on_activate=function()
                        local _, selected = self.subviews.lovers:getSelected()
                        if not selected then return end
                        local unit = self:get_unit()
                        if not unit then return end
                        remove_hf_link(df.histfig_hf_link_loverst, unit.hist_figure_id, selected.data.hfid)
                        remove_hf_link(df.histfig_hf_link_loverst, selected.data.hfid, unit.hist_figure_id)
                        self.dirty = 1
                    end,
                    enabled=function()
                        local _, selected = self.subviews.lovers:getSelected()
                        return selected
                    end,
                },
            },
        },
    }
end

function RelationshipsPage:on_show()
    local unit = dfhack.gui.getSelectedUnit(true)
    if self.unit_id == -1 then
        self:set_unit(unit)
    end
end

function RelationshipsPage:get_unit()
    self.cache.unit = self.cache.unit or df.unit.find(self.unit_id)
    return self.cache.unit
end

function RelationshipsPage:set_unit(unit)
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not unit then return end
    self.unit_id = unit.id
    self.dirty = 2
end

function RelationshipsPage:refresh_lover_list()
    local choices = {}
    for _, lover_hfid in ipairs(get_lovers(self:get_unit())) do
        local lover_hf = df.historical_figure.find(lover_hfid)
        if lover_hf then
            local lover_unit = df.unit.find(lover_hf.unit_id)
            local text = {
                {text=get_name(lover_hf)},
                {gap=1, text=lover_unit and '' or '(off-site)', pen=COLOR_YELLOW},
            }
            table.insert(choices, {
                text=text,
                data={hfid=lover_hfid},
            })
        end
    end
    local list = self.subviews.lovers
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setSelected(selected)
end

function RelationshipsPage:render(dc)
    if self.dirty > 0 then
        self:updateLayout()
        self.dirty = self.dirty - 1
        if self.dirty <= 0 then
            self:refresh_lover_list()
        end
    end
    RelationshipsPage.super.render(self, dc)
    self.cache = {}
end

function RelationshipsPage:get_name()
    return get_name(self:get_unit())
end

function RelationshipsPage:get_spouse_unit()
    return get_spouse_unit(self:get_unit())
end

----------------------
-- PregnancyPage
--

PregnancyPage = defclass(PregnancyPage, widgets.Panel)

function PregnancyPage:init()
    self.cache = {}
    self.mother_id, self.father_id = -1, -1
    self.dirty = 0

    self:addviews{
        widgets.Panel{
            frame={t=0},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text='Mother:',
                },
                widgets.Label{
                    frame={t=0, l=8},
                    text='None (please select an adult female)',
                    text_pen=COLOR_YELLOW,
                    visible=function() return not self:get_mother() end,
                },
                widgets.Label{
                    frame={t=0, l=8},
                    text={{text=self:callback('get_name', 'mother')}},
                    text_pen=COLOR_LIGHTMAGENTA,
                    auto_width=true,
                    on_click=function() zoom_to(self:get_mother()) end,
                    visible=self:callback('get_mother'),
                },
                widgets.Label{
                    frame={t=1, l=0},
                    text={{text=self:callback('get_pregnancy_desc')}},
                },
                widgets.HotkeyLabel{
                    frame={t=3, l=0},
                    label="Choose selected unit to be the mother",
                    key='CUSTOM_SHIFT_M',
                    auto_width=true,
                    on_activate=self:callback('set_mother'),
                    enabled=function()
                        local unit = dfhack.gui.getSelectedUnit(true)
                        return unit and unit.id ~= self.mother_id and is_viable_parent(unit, df.pronoun_type.she)
                    end,
                },
                widgets.Label{
                    frame={t=5, l=0},
                    text={{text='Spouse:', pen=function() return can_have_spouse(self:get_mother()) and COLOR_WHITE or COLOR_GRAY end}},
                },
                widgets.Label{
                    frame={t=5, l=8},
                    text={{text='None', pen=function() return can_have_spouse(self:get_mother()) and COLOR_WHITE or COLOR_GRAY end}},
                    visible=function() return not self:get_spouse_unit('mother') and not self:get_spouse_hf('mother') end,
                },
                widgets.Label{
                    frame={t=5, l=8},
                    text={{text=self:callback('get_spouse_name', 'mother')}},
                    text_pen=COLOR_BLUE,
                    auto_width=true,
                    on_click=function() zoom_to(self:get_spouse_unit('mother')) end,
                    visible=self:callback('get_spouse_unit', 'mother'),
                },
                widgets.Label{
                    frame={t=5, l=8},
                    text={
                        {text=self:callback('get_spouse_hf_name', 'mother'), pen=COLOR_BLUE},
                        {gap=1, text='(off-site)', pen=COLOR_YELLOW},
                    },
                    auto_width=true,
                    visible=function() return not self:get_spouse_unit('mother') and self:get_spouse_hf('mother') end,
                },
                widgets.HotkeyLabel{
                    frame={t=6, l=2},
                    label="Set mother's spouse as the father",
                    key='CUSTOM_F',
                    auto_width=true,
                    on_activate=function() self:set_father(self:get_spouse_unit('mother')) end,
                    enabled=function()
                        local spouse = self:get_spouse_unit('mother')
                        return spouse and spouse.id ~= self.father_id and is_viable_parent(spouse, df.pronoun_type.he)
                    end,
                },
            },
        },
        widgets.Divider{
            frame={t=8, h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Panel{
            frame={t=10},
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text='Father:',
                },
                widgets.Label{
                    frame={t=0, l=8},
                    text={
                        'None ',
                        {text='(optionally select an adult male)', pen=COLOR_GRAY},
                    },
                    visible=function() return not self:get_father() end,
                },
                widgets.Label{
                    frame={t=0, l=8},
                    text={{text=self:callback('get_name', 'father')}},
                    text_pen=function()
                        local spouse = self:get_spouse_unit('mother')
                        if spouse and self.father_id == spouse.id then
                            return COLOR_BLUE
                        end
                        return COLOR_CYAN
                    end,
                    auto_width=true,
                    on_click=function() zoom_to(self:get_father()) end,
                    visible=self:callback('get_father'),
                },
                widgets.HotkeyLabel{
                    frame={t=2, l=0},
                    label="Choose selected unit to be the father",
                    key='CUSTOM_SHIFT_F',
                    auto_width=true,
                    on_activate=self:callback('set_father'),
                    enabled=function()
                        local unit = dfhack.gui.getSelectedUnit(true)
                        return unit and unit.id ~= self.father_id and is_viable_parent(unit, df.pronoun_type.he)
                    end,
                },
                widgets.Label{
                    frame={t=4, l=0},
                    text={{text='Spouse:', pen=function() return can_have_spouse(self:get_father()) and COLOR_WHITE or COLOR_GRAY end}},
                },
                widgets.Label{
                    frame={t=4, l=8},
                    text={{text='None', pen=function() return can_have_spouse(self:get_father()) and COLOR_WHITE or COLOR_GRAY end}},
                    visible=function() return not self:get_spouse_unit('father') and not self:get_spouse_hf('father') end,
                },
                widgets.Label{
                    frame={t=4, l=8},
                    text={{text=self:callback('get_spouse_name', 'father')}},
                    text_pen=function()
                        local spouse = self:get_spouse_unit('father')
                        if spouse and self.mother_id == spouse.id then
                            return COLOR_LIGHTMAGENTA
                        end
                        return COLOR_CYAN
                    end,
                    auto_width=true,
                    on_click=function() zoom_to(self:get_spouse_unit('father')) end,
                    visible=self:callback('get_spouse_unit', 'father'),
                },
                widgets.Label{
                    frame={t=4, l=8},
                    text={
                        {text=self:callback('get_spouse_hf_name', 'father'), pen=COLOR_CYAN},
                        {gap=1, text='(off-site)', pen=COLOR_YELLOW},
                    },
                    auto_width=true,
                    visible=function() return not self:get_spouse_unit('father') and self:get_spouse_hf('father') end,
                },
                widgets.HotkeyLabel{
                    frame={t=5, l=2},
                    label="Set father's spouse as the mother",
                    key='CUSTOM_M',
                    auto_width=true,
                    on_activate=function() self:set_mother(self:get_spouse_unit('father')) end,
                    enabled=function()
                        local spouse = self:get_spouse_unit('father')
                        return spouse and spouse.id ~= self.mother_id and is_viable_parent(spouse, df.pronoun_type.she)
                    end,
                },
            },
        },
        widgets.Divider{
            frame={t=17, h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Panel{
            frame={t=19},
            subviews={
                widgets.CycleHotkeyLabel{
                    view_id='term',
                    frame={t=0, l=0, w=40},
                    label='Pregnancy term (in months):',
                    key_back='CUSTOM_SHIFT_Z',
                    key='CUSTOM_Z',
                    options={
                        {label='Default', value='default', pen=COLOR_BROWN},
                        {label='0', value=0, pen=COLOR_BROWN},
                        {label='1', value=1, pen=COLOR_BROWN},
                        {label='2', value=2, pen=COLOR_BROWN},
                        {label='3', value=3, pen=COLOR_BROWN},
                        {label='4', value=4, pen=COLOR_BROWN},
                        {label='5', value=5, pen=COLOR_BROWN},
                        {label='6', value=6, pen=COLOR_BROWN},
                        {label='7', value=7, pen=COLOR_BROWN},
                        {label='8', value=8, pen=COLOR_BROWN},
                        {label='9', value=9, pen=COLOR_BROWN},
                        {label='10', value=10, pen=COLOR_BROWN},
                    },
                    initial_option='default',
                },
                widgets.Panel{
                    frame={t=2, w=23, h=3},
                    frame_style=gui.FRAME_INTERIOR,
                    subviews={
                        widgets.HotkeyLabel{
                            key='CUSTOM_SHIFT_P',
                            label="Generate pregnancy",
                            on_activate=self:callback('commit'),
                            enabled=function() return self:get_mother() end,
                        },
                    }
                },
            },
        },
    }
end

function PregnancyPage:on_show()
    local unit = dfhack.gui.getSelectedUnit(true)
    if self.mother_id == -1 then
        self:set_mother(unit)
    end
    if self.father_id == -1 then
        self:set_father(unit)
    end
end

function PregnancyPage:get_mother()
    self.cache.mother = self.cache.mother or df.unit.find(self.mother_id)
    return self.cache.mother
end

function PregnancyPage:get_father()
    self.cache.father = self.cache.father or df.unit.find(self.father_id)
    return self.cache.father
end

function PregnancyPage:render(dc)
    if self.dirty > 0 then
        -- needs multiple iterations of updateLayout because of multiple
        -- layers of indirection in the text generation
        self:updateLayout()
        self.dirty = self.dirty - 1
    end
    PregnancyPage.super.render(self, dc)
    self.cache = {}
end

function PregnancyPage:get_name(who)
    return get_name(self['get_'..who](self))
end

local TICKS_PER_DAY = 1200
local TICKS_PER_MONTH = 28 * TICKS_PER_DAY

function PregnancyPage:get_pregnancy_desc()
    local mother = self:get_mother()
    if not mother or not mother.pregnancy_genes or mother.pregnancy_timer <= 0 then
        return 'Not currently pregnant'
    end
    local term_str = 'today'
    if mother.pregnancy_timer > TICKS_PER_MONTH then
        local num_months = (mother.pregnancy_timer + TICKS_PER_MONTH//2) // TICKS_PER_MONTH
        term_str = ('in %d month%s'):format(num_months, num_months == 1 and '' or 's')
    elseif mother.pregnancy_timer > TICKS_PER_DAY then
        local num_days = (mother.pregnancy_timer + TICKS_PER_DAY//2) // TICKS_PER_DAY
        term_str = ('in %d day%s'):format(num_days, num_days == 1 and '' or 's')
    end
    return ('Currently pregnant: coming to term %s'):format(term_str)
end

function PregnancyPage:get_spouse_unit(who)
    return get_spouse_unit(self['get_'..who](self))
end

function PregnancyPage:get_spouse_hf(who)
    return get_spouse_hf(self['get_'..who](self))
end

function PregnancyPage:get_spouse_name(who)
    return get_name(self:get_spouse_unit(who))
end

function PregnancyPage:get_spouse_hf_name(who)
    return get_name(self:get_spouse_hf(who))
end

function PregnancyPage:set_mother(unit)
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not is_viable_parent(unit, df.pronoun_type.she) then return end
    local father = self:get_father()
    local function do_set_mother()
        if self.father_id ~= -1 then
            if not father or father.race ~= unit.race then
                self.father_id = -1
            end
        end
        self.mother_id = unit.id
        if self.father_id == -1 then
            self:set_father(self:get_spouse_unit('mother'))
        end
        self.dirty = 2
    end
    if father and father.race ~= unit.race then
        dlg.showYesNoPrompt('Race mismatch',
            'Are you sure you want to select this unit as the mother?\n' ..
            'The unit\'s race does not match the selected father.\n' ..
            'The choice for father will be reset.',
            COLOR_YELLOW, do_set_mother)
    else
        do_set_mother()
    end
end

function PregnancyPage:set_father(unit)
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not is_viable_parent(unit, df.pronoun_type.he) then return end
    local mother = self:get_mother()
    local function do_set_father()
        if self.mother_id ~= -1 then
            if not mother or mother.race ~= unit.race then
                self.mother_id = -1
            end
        end
        self.father_id = unit.id
        if self.mother_id == -1 then
            self:set_mother(self:get_spouse_unit('father'))
        end
        self.dirty = 2
    end
    if mother and mother.race ~= unit.race then
        dlg.showYesNoPrompt('Race mismatch',
            'Are you sure you want to select this unit as the father?\n' ..
            'The unit\'s race does not match the selected mother.\n' ..
            'The choice for mother will be reset.',
            COLOR_YELLOW, do_set_father)
    else
        do_set_father()
    end
end

local function get_term_ticks(months)
    local ticks = months * TICKS_PER_MONTH
    -- subtract off a random amount between 0 and half a month
    ticks = math.max(1, ticks - math.random(0, TICKS_PER_MONTH//2))
    return ticks
end

function PregnancyPage:commit()
    local mother = self:get_mother()
    local father = self:get_father() or mother

    local term_months = self.subviews.term:getOptionValue()
    if term_months == 'default' then
        local caste_flags = mother.enemy.caste_flags
        if caste_flags.CAN_SPEAK or caste_flags.CAN_LEARN then
            term_months = 9
        else
            term_months = 6
        end
    end

    if mother.pregnancy_genes then
        mother.pregnancy_genes:assign(father.appearance.genes)
    else
        mother.pregnancy_genes = father.appearance.genes:new()
    end

    mother.pregnancy_timer = get_term_ticks(term_months)
    mother.pregnancy_caste = father.caste
    mother.pregnancy_spouse = father.hist_figure_id ~= mother.hist_figure_id and father.hist_figure_id or -1

    self.dirty = 2
end

----------------------
-- FamilyAffairs
--

FamilyAffairs = defclass(FamilyAffairs, widgets.Window)
FamilyAffairs.ATTRS {
    frame_title='Family manager',
    frame={w=50, h=30, r=2, t=18},
    frame_inset={t=1, l=1, r=1},
    resizable=true,
    initial_tab=DEFAULT_NIL,
}

function FamilyAffairs:init()
    local function on_select(idx)
        local pages = self.subviews.pages
        pages:setSelected(idx)
        local _, page = pages:getSelected()
        page:on_show()
    end

    self:addviews{
        widgets.TabBar{
            frame={t=0, l=0},
            labels={
                'Relationships',
                'Pregnancy',
            },
            on_select=on_select,
            get_cur_page=function() return self.subviews.pages:getSelected() end,
        },
        widgets.Pages{
            view_id='pages',
            frame={t=3, l=0, b=0, r=0},
            subviews={
                RelationshipsPage{},
                PregnancyPage{},
            },
        },
    }

    on_select(self.initial_tab == 'pregnancy' and 2 or 1)
end

----------------------
-- FamilyAffairsScreen
--

FamilyAffairsScreen = defclass(FamilyAffairsScreen, gui.ZScreen)
FamilyAffairsScreen.ATTRS {
    focus_path='pregnancy',
    initial_tab='relationships',
}

function FamilyAffairsScreen:init()
    self:addviews{FamilyAffairs{initial_tab=self.initial_tab}}
end

function FamilyAffairsScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('requires a map to be loaded')
end

local help, initial_tab = false, 'relationships'

local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
    {nil, 'pregnancy', handler=function() initial_tab = 'pregnancy' end},
})

if positionals[1] == 'help' then help = true end
if help then
    print(dfhack.script_help())
    return
end

view = view and view:raise() or FamilyAffairsScreen{initial_tab=initial_tab}:show()

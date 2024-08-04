local gui = require('gui')
local widgets = require('gui.widgets')

PregnancyGui = defclass(PregnancyGui, widgets.Window)
PregnancyGui.ATTRS {
    frame_title='Pregnancy manager',
    frame={w=64, h=35},
    resizable=true, -- if resizing makes sense for your dialog
    resize_min={w=50, h=20}, -- try to allow users to shrink your windows
}

function PregnancyGui:init()
    if dfhack.gui.getSelectedUnit(true).sex == df.pronoun_type.she then
        self.mother = dfhack.gui.getSelectedUnit(true)
    else self.mother = false
    end
    self.father = false
    self.father_historical = false
    self.msg = {}

    local term_options = {}
    local term_index = {}
    local months
    for months=0,10 do
        -- table.insert(term_options,{label=('%s months'):format(months),value=months}) --I tried this to add labels, probably doing something wrong, it broke the range widget
        table.insert(term_options,months) --this works though
    end
    for k,v in ipairs(term_options) do
        term_index[v] = k
    end

    self:addviews{
        widgets.ResizingPanel{
            frame={t=0},
            frame_style=gui.FRAME_INTERIOR,
            autoarrange_subviews=true,
            subviews={
                widgets.WrappedLabel{
                    text_to_wrap=self:callback('getMotherLabel')
                },
                widgets.HotkeyLabel{
                    frame={l=0},
                    label="Set mother to selected unit",
                    key='CUSTOM_SHIFT_M',
                    on_activate=self:callback('selectmother'),
                },
            },
        },
        widgets.ResizingPanel{
            frame={t=5},
            frame_style=gui.FRAME_INTERIOR,
            autoarrange_subviews=true,
            subviews={
                widgets.WrappedLabel{
                    text_to_wrap=self:callback('getFatherLabel')
                },
                widgets.HotkeyLabel{
                    frame={l=0},
                    label="Set father to selected unit",
                    key='CUSTOM_SHIFT_F',
                    on_activate=self:callback('selectfather'),
                },
                widgets.HotkeyLabel{
                    frame={l=5},
                    label="Set mother's spouse as the father",
                    key='CUSTOM_F',
                    on_activate=self:callback('spouseFather'),
                    disabled=function() return not self.mother or self.mother.relationship_ids.Spouse == -1 end
                },
            },
        },
        widgets.Panel{
            frame={t=12,h=14},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.HotkeyLabel{
                    frame={l=0, t=0},
                    key='CUSTOM_SHIFT_P',
                    label="Create pregnancy",
                    on_activate=self:callback('CreatePregnancy'),
                    enabled=function() return self.mother or self.father and self.father_historical end
                },
                widgets.ToggleHotkeyLabel{
                    frame={l=1, t=1},
                    view_id='Force',
                    label='Replace existing pregnancy',
                    options={{label='On', value=true, pen=COLOR_GREEN},
                    {label='Off', value=false, pen=COLOR_RED}},
                    initial_option=false
                },
                widgets.TooltipLabel{
                    frame={l=0, t=3},
                    text_to_wrap='Pregnancy term range (months):',
                    show_tooltip=true,
                    text_pen=COLOR_WHITE
                },
                widgets.CycleHotkeyLabel{
                    view_id='min_term',
                    frame={l=0, t=6, w=SLIDER_LABEL_WIDTH},
                    label='Min pregnancy term:',
                    key_back='CUSTOM_SHIFT_Z',
                    key='CUSTOM_SHIFT_X',
                    options=term_options,
                    initial_option=7
                },
                widgets.CycleHotkeyLabel{
                    view_id='max_term',
                    frame={l=30, t=6, w=SLIDER_LABEL_WIDTH},
                    label='Max pregnancy term:',
                    key_back='CUSTOM_SHIFT_Q',
                    key='CUSTOM_SHIFT_W',
                    options=term_options,
                    initial_option=9
                },
                widgets.RangeSlider{
                    frame={l=0, t=4},
                    num_stops=#term_options,
                    get_left_idx_fn=function()
                        return term_index[self.subviews.min_term:getOptionLabel()]
                    end,
                    get_right_idx_fn=function()
                        return term_index[self.subviews.max_term:getOptionLabel()]
                    end,
                    on_left_change=function(idx) self.subviews.min_term:setOption(idx, true) end,
                    on_right_change=function(idx) self.subviews.max_term:setOption(idx, true) end,
                },
                widgets.WrappedLabel{
                    frame={t=8},--, h=5},
                    text_to_wrap=function() return self.msg end
                },
            },
        },
        widgets.ResizingPanel{
            frame={t=26},
            frame_style=gui.FRAME_INTERIOR,
            autoarrange_subviews=true,
            subviews={
                widgets.HotkeyLabel{
                    frame={l=1, b=0},
                    key='LEAVESCREEN',
                    label="Return to game",
                    on_activate=function()
                        repeat until not self:onInput{LEAVESCREEN=true}
                        view:dismiss()
                    end,
                },
            },
        },
    }
end

function PregnancyGui:selectmother()
    local unit = dfhack.gui.getSelectedUnit(true)
    if unit then 
        if unit.sex==df.pronoun_type.she and dfhack.units.isAdult(unit) then 
            self.mother = unit
            self:updateLayout()
        end
    end
end

function PregnancyGui:selectfather()
    local unit = dfhack.gui.getSelectedUnit(true)
    if unit and dfhack.units.isAdult(unit) then 
        self.father = unit
        self.father_historical = false
        self:updateLayout()
    end
end

function PregnancyGui:spouseFather()
    local father = self:findSpouse(self.mother)[3]
    if father then
        if df.unit.find(father.unit_id) then
            self.father = df.unit.find(father.unit_id)
            self.father_historical = false
        else 
            self.father_historical = father
            self.father = false
        end
    self:updateLayout()
    end
end

function PregnancyGui:getMotherLabel()
    if self.mother then 
        local motherName = dfhack.TranslateName(self.mother.name)
        if self.mother.relationship_ids.Spouse > -1 then 
            local spouseInfo = self:findSpouse(self.mother)
            return ('Selected mother: %s.%sShe is married to %s (%s).'):format(
                self:findName(self.mother),
                NEWLINE,
                spouseInfo[1],
                spouseInfo[2]
            )
        else 
            return ('Selected mother: %s.%sShe is unmarried.'):format(
                self:findName(self.mother),
                NEWLINE
            )
        end
    else return ('No mother selected - Must be an adult female')
    end
end

function PregnancyGui:getFatherLabel()
    if self.father or self.father_historical then 
        if self.father_historical or self.father.relationship_ids.Spouse > -1 then 
            local father = self.father or self.father_historical
            local spouseInfo = self:findSpouse(father)
            return ('Selected father: %s.%s%s is married to %s (%s).'):format(
                self:findName(father),
                NEWLINE,
                df.pronoun_type[father.sex]:gsub("^%l", string.upper),
                spouseInfo[1],
                spouseInfo[2]
            )
        else 
            return ('Selected father: %s.%s%s is unmarried.'):format(
                self:findName(self.father),
                NEWLINE,
                df.pronoun_type[self.father.sex]:gsub("^%l", string.upper)
            )
        end
    else return ('No father selected')
    end
end

function PregnancyGui:findName(unit)
    local name = dfhack.TranslateName(unit.name)
    if name ~= "" then
        return name
    else return ('Unnamed %s. (Unit id:%s)'):format(
        string.upper(df.global.world.raws.creatures.all[unit.race].name[0]),
        unit.id
    )
    end
end

function PregnancyGui:findSpouse(unit)
    local historical_spouse, spouse_loc, spouse, spouseid
    local culled = false

    --setting variables for if mother or father are local, followed by finding the father's spouse if he is not local
    if self.father == unit or self.mother == unit then
        spouseid = unit.relationship_ids.Spouse
        spouse = df.unit.find(spouseid)
    elseif self.father_historical == unit then
        for index, relation in pairs(unit.histfig_links) do
            if relation._type == df.histfig_hf_link_spousest then
                historical_spouse=df.historical_figure.find(relation.target_hf)
                if not historical_spouse then culled = true --there was an id, but there wasn't a histfig with that id (due culling)
                elseif df.global.plotinfo.site_id==historical_spouse.info.whereabouts.site then
                    spouse_loc = 'local'
                else spouse_loc = 'offsite'
                end
            end
        end
        return {dfhack.TranslateName(historical_spouse.name),spouse_loc,historical_spouse}
    end

    --if the spouse is local this should identify them:
    if spouse then
        historical_spouse = df.historical_figure.find(spouse.hist_figure_id) or false
        spouse_loc = 'local'
    end

    --if spouse is not local (offsite):
    if spouseid > -1 and not spouse then --spouse exists but isnt on the map, so search historical units:
        local historical_unit = df.historical_figure.find(unit.hist_figure_id)
        for index, relation in pairs(historical_unit.histfig_links) do
            if relation._type == df.histfig_hf_link_spousest then
                historical_spouse=df.historical_figure.find(relation.target_hf)
                if not historical_spouse then culled = true --there was an id, but there wasn't a histfig with that id (due culling)
                elseif df.global.plotinfo.site_id==historical_spouse.info.whereabouts.site then--i dont think this should ever be true
                    spouse_loc = 'local'
                else spouse_loc = 'offsite'
                end
            end
        end
    end
    if culled then 
        return {'Unknown','culled'}
    else 
        return {dfhack.TranslateName(historical_spouse.name),spouse_loc,historical_spouse}
    end
end

function PregnancyGui:CreatePregnancy()
    local genes,father_id,father_caste,father_name
    local bypass = true
    local force = self.subviews.Force:getOptionValue()

    self.msg = {}

    if self.subviews.min_term:getOptionLabel() > self.subviews.max_term:getOptionLabel() then
        table.insert(self.msg,('Min term has to be less then max term'))
        self:updateLayout()
        return
    end

    if self.father then
        genes=self.father.appearance.genes:new()
        father_id=self.father.hist_figure_id
        father_caste=self.father.caste
        father_name=self:findName(self.father)
    else
        genes=self.mother.appearance.genes:new()--i dont think historical figures have genes
        father_id=self.father_historical.id
        father_caste=self.father_historical.caste
        father_name=self:findName(self.father_historical)
    end

    if self.mother.pregnancy_timer > 0 then
        local og_father = df.historical_figure.find(self.mother.pregnancy_spouse)
        bypass = false
        if force and og_father then 
            table.insert(self.msg, ('SUCCESS:%sMother:%s%sFather:%s%sPrevious pregnancy with %s replaced'):format(
            NEWLINE,    
            self:findName(self.mother),
            NEWLINE, 
            father_name,
            NEWLINE,
            dfhack.TranslateName(og_father.name)
            ))
        elseif force then 
            table.insert(self.msg, ('SUCCESS:%sMother:%s%sFather:%s%sPrevious pregnancy aborted'):format(
            NEWLINE,    
            self:findName(self.mother),
            NEWLINE, 
            father_name,
            NEWLINE
            ))
        elseif og_father then
            table.insert(self.msg, ('FAILED:%s%s already pregnant with %s%s'):format(
                NEWLINE,
                self:findName(self.mother),
                dfhack.TranslateName(og_father.name),
                force
            ))
        else 
            table.insert(self.msg, ('FAILED:%s%s is already pregnant, no father is recorded'):format(
                NEWLINE,
                self:findName(self.mother)
        ))
        end
    end

    if bypass or force then
        self.mother.pregnancy_timer=math.random(self.subviews.min_term:getOptionLabel()*33600+1, self.subviews.max_term:getOptionLabel()*33600+1)
        self.mother.pregnancy_caste=father_caste
        self.mother.pregnancy_spouse=father_id
        self.mother.pregnancy_genes=genes
        if not force then
            table.insert(self.msg, ('SUCCESS:%sMother:%s%sFather:%s'):format(
                NEWLINE,
                self:findName(self.mother),
                NEWLINE,
                father_name
            ))
        end
    end
    self:updateLayout()
end

PregnancyScreen = defclass(PregnancyScreen, gui.ZScreen)
PregnancyScreen.ATTRS {
    focus_path='pregnancy',
}

function PregnancyScreen:init()
    self:addviews{PregnancyGui{}}
end

function PregnancyScreen:onDismiss()
    view = nil
end

view = view and view:raise() or PregnancyScreen{}:show()

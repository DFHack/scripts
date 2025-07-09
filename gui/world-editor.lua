-- gui/world-editor.lua
local gui       = require('gui')
local widgets   = require('gui.widgets')
local trans     = dfhack.translation
local dialog    = require('gui.dialogs')

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------

local function get_name(lang_name)
    local ok, str = pcall(trans.translateName, lang_name, true)
    return ok and str or '(unknown)'
end

local function launch_rename(target_name)
    local rename = reqscript('gui/rename')
    rename.RenameScreen{
        target = {name = target_name},
        show_selector = false,
    }:show()
end

----------------------------------------------------------------
-- generic searchable-list widget (simple substring match)
----------------------------------------------------------------

local function make_searchable_list(row_builder)
    local filter = ''
    local list = widgets.List{
        frame = {t=1,l=0,r=0,b=0}, -- row 0 is the search bar
        choices = {},
        on_submit = function(idx, choice)
            if choice and choice.on_submit then
                choice.on_submit()
            end
        end,
    }

    function list:refreshDisplay()
        local rows = row_builder()
        if #filter > 0 then
            local f = filter
            local matched = {}
            for _, row in ipairs(rows) do
                if (row.text or ''):lower():find(f, 1, true) then
                    table.insert(matched, row)
                end
            end
            rows = matched
        end
        local sel = self:getSelected()
        self:setChoices(rows)
        if sel then self:setSelected(sel) end
    end

    list:refreshDisplay()

    local search = widgets.EditField{
        frame={t=0,l=0},
        label_text='Search: ',
        on_change = function(text)
            filter = text:lower()
            list:refreshDisplay()
        end,
    }

    local panel = widgets.Panel{
        frame={t=0,l=0,r=0,b=0},
        subviews={search, list},
    }
    panel.refreshDisplay = function() list:refreshDisplay() end
    return panel
end

----------------------------------------------------------------
-- row builders
----------------------------------------------------------------

local function build_feature_rows(vec, prefix)
    local rows = {}
    for i, obj in ipairs(vec) do
        local name = get_name(obj.name)
        rows[#rows+1] = {
            label = ('%s %d'):format(prefix, i-1),
            text  = name,
            get   = function() return name end,
            set   = function() end,
            on_submit = function() launch_rename(obj.name) end,
        }
    end
    if #rows == 0 then rows[1] = {label='(No data)', text=''} end
    return rows
end

----------------------------------------------------------------
-- page factories (searchable)
----------------------------------------------------------------

local function make_river_page()
    return make_searchable_list(function()
        return build_feature_rows(df.global.world.world_data.rivers, 'River')
    end)
end

local function make_mountain_page()
    return make_searchable_list(function()
        return build_feature_rows(df.global.world.world_data.mountain_peaks, 'Peak')
    end)
end

local function make_entity_page()
    return make_searchable_list(function()
        local rows = {}
        
        -- Entity type lookup table
        local entity_types = {
            [-1] = "NONE",
            [0] = "Civilization",
            [1] = "SiteGovernment", 
            [2] = "VesselCrew",
            [3] = "MigratingGroup",
            [4] = "NomadicGroup",
            [5] = "Religion",
            [6] = "MilitaryUnit",
            [7] = "Outcast",
            [8] = "PerformanceTroupe",
            [9] = "MerchantCompany",
            [10] = "Guild"
        }
        
        for i, ent in ipairs(df.global.world.entities.all) do
            -- Only show entities with translatable names (copying logic from select_civilization)
            local ok, name = pcall(dfhack.translation.translateName, ent.name, true)
            if ok and name and name:match("%S") then
                -- Get race name
                local race_id = ent.race or -1
                local race_str = "(unknown)"
                if race_id >= 0 and df.global.world.raws.creatures.all[race_id] then
                    race_str = df.global.world.raws.creatures.all[race_id].creature_id
                end
                
                -- Get entity type
                local entity_type = entity_types[ent.type] or ("Unknown(" .. ent.type .. ")")
                
                -- Build display text: "Name [Race] (Type)"
                local display_text = string.format("%s [%s] (%s)", name, race_str, entity_type)
                
                rows[#rows+1] = {
                    label = ('Entity %d'):format(i-1),
                    text  = display_text,
                    get   = function() return display_text end,
                    set   = function() end,
                    on_submit = function() launch_rename(ent.name) end,
                    -- Store sorting keys
                    sort_type = ent.type,
                    sort_id = i-1,
                }
            end
        end
        
        -- Sort by type first, then by ID
        table.sort(rows, function(a, b)
            if a.sort_type ~= b.sort_type then
                return a.sort_type < b.sort_type
            end
            return a.sort_id < b.sort_id
        end)
        
        if #rows == 0 then rows[1] = {label='(No named entities)', text=''} end
        return rows
    end)
end

----------------------------------------------------------------
-- Spawn page
----------------------------------------------------------------

local function make_spawn_page()
    local selected_entity = nil
    local selected_race_id = nil

    -- helper to get the display name (from both versions)
    local function get_name(lang_name)
        local ok, str = pcall(dfhack.translation.translateName, lang_name, true)
        return ok and str or '(unknown)'
    end

    -- Refresh the panel layout when status_text changes
    local panel
    local function refresh_display()
        panel:updateLayout()
    end

    -- Prompt the user to pick a civilization (only those with real names)
    local function select_civilization()
        local choices = {}
        for _, ent in ipairs(df.global.world.entities.all) do
            if ent.type == df.historical_entity_type.Civilization then
                -- translate the civ name
                local ok, cname = pcall(dfhack.translation.translateName, ent.name, true)
                if ok and cname and cname:match("%S") then
                    -- look up its race ID
                    local race_id = ent.race or -1
                    local race_str = "(unknown)"
                    if race_id >= 0 and df.global.world.raws.creatures.all[race_id] then
                        race_str = df.global.world.raws.creatures.all[race_id].creature_id
                    end

                    table.insert(choices, {
                        text = string.format("%s [%s]", cname, race_str),
                        data = {entity = ent},
                    })
                end
            end
        end

        if #choices == 0 then
            dialog.showMessage('No civilizations', 'No named civilizations found.', COLOR_RED)
            return
        end

        dialog.showListPrompt(
            'Select Civilization',
            'Choose a civilization to add populations to:',
            COLOR_WHITE,
            choices,
            function(_, choice)
                selected_entity = choice.data.entity
                refresh_display()
            end
        )
    end

    -- Prompt the user to pick a race with searchable list
    local function select_race()
        local RaceSelector = defclass(RaceSelector, gui.ZScreen)
        RaceSelector.ATTRS{focus_path='race_selector'}
        
        function RaceSelector:init()
            local creatures = df.global.world.raws.creatures.all
            local choices = {}
            
            for i, creature in ipairs(creatures) do
                -- Get the creature name (singular form)
                local creature_name = creature.name[0] -- singular form
                if creature_name and creature_name ~= "" then
                    table.insert(choices, {
                        text = string.format("%s [%d]", creature_name, i),
                        race_id = i,
                        on_submit = function()
                            selected_race_id = i
                            refresh_display()
                            self:dismiss()
                        end
                    })
                end
            end
            
            if #choices == 0 then
                dialog.showMessage('No races', 'No races found.', COLOR_RED)
                self:dismiss()
                return
            end
            
            -- Create searchable list using same pattern as rivers/mountains
            local filter = ''
            local list = widgets.List{
                frame = {t=3,l=1,r=1,b=3}, -- leave room for title and search
                choices = choices,
                on_submit = function(idx, choice)
                    if choice and choice.on_submit then
                        choice.on_submit()
                    end
                end,
            }
            
            local function refreshDisplay()
                local rows = choices
                if #filter > 0 then
                    local f = filter
                    local matched = {}
                    for _, row in ipairs(choices) do
                        if (row.text or ''):lower():find(f, 1, true) then
                            table.insert(matched, row)
                        end
                    end
                    rows = matched
                end
                local sel = list:getSelected()
                list:setChoices(rows)
                if sel then list:setSelected(sel) end
            end
            
            local search = widgets.EditField{
                frame={t=1,l=1},
                label_text='Search: ',
                on_change = function(text)
                    filter = text:lower()
                    refreshDisplay()
                end,
            }
            
            self:addviews{
                widgets.Window{
                    frame={w=50,h=30,c=true,m=true},
                    frame_title='Select Race',
                    subviews={
                        search,
                        list,
                        widgets.HotkeyLabel{
                            frame={b=0,l=1},
                            key='LEAVESCREEN',
                            label='Cancel',
                            on_activate=function() self:dismiss() end,
                        },
                    },
                },
            }
            
            refreshDisplay()
        end
        
        RaceSelector{}:show()
    end

    -- The working add_population logic
    local function add_population()
        if not selected_entity then
            dialog.showMessage('Error', 'Please select a civilization first.', COLOR_RED)
            return
        end
        
        if not selected_race_id then
            dialog.showMessage('Error', 'Please select a race first.', COLOR_RED)
            return
        end
        
        dialog.showInputPrompt('Count', 'Enter the population count:', COLOR_WHITE, '',
            function(count_str)
                local count = tonumber(count_str)
                if not count or count <= 0 then
                    dialog.showMessage('Error', 'Invalid count.', COLOR_RED)
                    return
                end
                local sites_modified = 0
                for _, site in ipairs(df.global.world.world_data.sites) do
                    if site.civ_id == selected_entity.id
                       and site.populace
                       and #site.populace.inhabitants > 0
                    then
                        local new_inhabitant = df.world_site_inhabitant:new()
                        new_inhabitant.count = count
                        local pop_spec = new_inhabitant.pop_spec
                        pop_spec.race = selected_race_id
                        pop_spec.breed_id = -1
                        pop_spec.cultural_identity_id = -1
                        pop_spec.epid = -1
                        pop_spec.interaction_effect_index = -1
                        pop_spec.interaction_index = -1
                        pop_spec.special_controlling_enid = -1
                        pop_spec.squad_epp_id = -1
                        pop_spec.squad_id = -1
                        pop_spec.wg_culture_reference_enid = -1
                        site.populace.inhabitants:insert('#', new_inhabitant)
                        sites_modified = sites_modified + 1
                    end
                end
                dialog.showMessage(
                    'Success',
                    ('Added race %d (count: %d) to %d sites.'):format(selected_race_id, count, sites_modified),
                    COLOR_GREEN
                )
            end
        )
    end

    -- Build the panel with status line and hotkeys
    panel = widgets.Panel{
        frame = {t=0, l=0, r=0, b=0},
        subviews = {
            -- status text for civilization
            widgets.Label{
                frame = {t=0, l=1},
                text = {
                    {
                        text = function()
                            return selected_entity
                                and ('Civilization: ' .. get_name(selected_entity.name))
                                or 'No civilization selected'
                        end,
                        pen = COLOR_CYAN
                    }
                },
            },
            -- status text for race
            widgets.Label{
                frame = {t=1, l=1},
                text = {
                    {
                        text = function()
                            if selected_race_id then
                                local creature = df.global.world.raws.creatures.all[selected_race_id]
                                if creature then
                                    return 'Race: ' .. creature.name[0] .. ' [' .. selected_race_id .. ']'
                                end
                            end
                            return 'No race selected'
                        end,
                        pen = COLOR_GREEN
                    }
                },
            },
            -- explanatory text
            widgets.Label{
                frame = {t=3, l=1},
                text = 'Add populations to all sites of selected civilization',
            },
            -- hotkey to select civilization
            widgets.HotkeyLabel{
                frame = {t=5, l=1},
                key = 'CUSTOM_S',
                label = 'Select civilization',
                on_activate = select_civilization,
            },
            -- hotkey to select race
            widgets.HotkeyLabel{
                frame = {t=6, l=1},
                key = 'CUSTOM_R',
                label = 'Select race',
                on_activate = select_race,
            },
            -- hotkey to add (only enabled once both are selected)
            widgets.HotkeyLabel{
                frame = {t=7, l=1},
                key = 'CUSTOM_A',
                label = 'Add population',
                on_activate = add_population,
                enabled = function() return selected_entity ~= nil and selected_race_id ~= nil end,
            },
        },
    }

    return panel
end


----------------------------------------------------------------
-- main window
----------------------------------------------------------------

WorldEditor = defclass(WorldEditor, widgets.Window)
WorldEditor.ATTRS{
    frame_title = 'World Editor',
    frame       = {w=60,h=25,r=2,t=2},
    frame_style = gui.FRAME_WINDOW,
    resizable   = true,
}

function WorldEditor:init()
    local pages = widgets.Pages{
        view_id='pages',
        frame   ={t=2,l=0,r=0,b=0},
        subviews={},
    }
    local function cur_tab() return pages:getSelected() end
    self.page_refs = {}

    local function build_root(idx)
        if     idx == 1 then return make_river_page()
        elseif idx == 2 then return make_mountain_page()
        elseif idx == 3 then return make_entity_page()
        elseif idx == 4 then return make_spawn_page()
        end
    end

    local function ensure_page(idx)
        if not self.page_refs[idx] then
            self.page_refs[idx] = build_root(idx)
            pages.subviews[idx] = self.page_refs[idx]
            if idx == cur_tab() and self.page_refs[idx].refreshDisplay then
                self.page_refs[idx]:refreshDisplay()
            end
        end
    end

    local tab_bar = widgets.TabBar{
        view_id = 'tab_bar',
        frame   = {t=0,l=0},
        labels  = {'Rivers','Mountains','Entities','Spawn'},
        on_select = function(idx)
            ensure_page(idx)
            pages:setSelected(idx)
            self:refreshCurrentPage()
        end,
        get_cur_page = cur_tab,
    }

    self:addviews{tab_bar, pages}

    -- pre-build pages and run the flip-through refresh hack
    for i=1,4 do ensure_page(i) end
    for i=2,4 do tab_bar.on_select(i) end
    tab_bar.on_select(1)
end

function WorldEditor:refreshCurrentPage()
    local pg = self.subviews.pages.subviews[self.subviews.pages:getSelected()]
    if pg and pg.refreshDisplay then pg:refreshDisplay() end
end

----------------------------------------------------------------
-- z-screen wrapper
----------------------------------------------------------------

WorldEditorScreen = defclass(WorldEditorScreen, gui.ZScreen)
WorldEditorScreen.ATTRS{focus_path='world_editor'}
function WorldEditorScreen:init() self:addviews{WorldEditor{}} end
function WorldEditorScreen:onDismiss() view = nil end

-- single global instance
view = view and view:raise() or WorldEditorScreen{}:show()

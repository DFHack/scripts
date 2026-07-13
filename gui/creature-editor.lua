-- gui/creature-editor.lua
local gui     = require('gui')
local widgets = require('gui.widgets')
local utils   = require('utils')
local dialog  = require('gui.dialogs')
local json    = require('json')

-- Directory for storing presets
local PRESET_DIR = 'dfhack-config/creature-presets'

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function niceify(s)
    return s:gsub('_',' '):lower():gsub('^%l', string.upper)
end

local function getStringValue(v)
    return tostring(v)
end

local function ensure_preset_dir()
    local ok, err = pcall(function()
        if not dfhack.filesystem.isdir(PRESET_DIR) then
            dfhack.filesystem.mkdir_recursive(PRESET_DIR)
        end
    end)
    if not ok then
        dialog.showMessage('Error', 'Could not create preset directory: ' .. tostring(err), COLOR_RED)
        return false
    end
    return true
end

local function get_preset_files()
    if not ensure_preset_dir() then return {} end
    local files = {}
    for _, f in ipairs(dfhack.filesystem.listdir(PRESET_DIR) or {}) do
        if f:match('%.json$') then
            table.insert(files, f)
        end
    end
    return files
end

local function make_editable_list(rows, get_tab, flip_tabs, navigate_to, navigate_back)
    local function build()
        local ch = {}
        for _, row in ipairs(rows) do
            local ok, val = pcall(row.get)
            table.insert(ch, {
                label = row.label,
                text = row.label .. ': ' .. (ok and getStringValue(val) or '(error)'),
                get = row.get,
                set = row.set,
                navigable = row.navigable,
                navigate_target = row.navigate_target,
            })
        end
        return ch
    end

    local list = widgets.List{
        frame = {t=0, l=0, r=15, b=0},  -- Changed from r=0 to r=15 to leave space for preset sidebar
        choices = build(),
        on_submit = function(_, choice)
            if choice.navigable and choice.navigate_target then
                navigate_to(choice.navigate_target, choice.label)
                return
            end

            local cur = choice.get() or ''
            dialog.showInputPrompt(
                choice.label, 'Enter new value:', COLOR_WHITE, tostring(cur),
                function(new_val)
                    local num = tonumber(new_val)
                    if num then choice.set(num) end
                    local cur_tab = get_tab()
                    local other = (cur_tab % 4) + 1
                    flip_tabs(other)
                    flip_tabs(cur_tab)
                end
            )
        end
    }

    local orig = list.onInput
    list.onInput = function(self, keys)
        if (keys._MOUSE_R or keys.LEAVESCREEN) and navigate_back then
            navigate_back()
            return true
        end
        return orig(self, keys)
    end

    list.refreshDisplay = function()
        local sel = list:getSelected()
        list:setChoices(build())
        list:setSelected(sel)
    end

    return list
end

----------------------------------------------------------------
-- Preset Functions
----------------------------------------------------------------

local function extract_physical_data(unit)
    local data = {}
    if unit.body.physical_attrs then
        for name, attr in pairs(unit.body.physical_attrs) do
            data[tostring(name)] = {
                value = attr.value,
                max_value = attr.max_value,
                improve_counter = attr.improve_counter,
                demotion_counter = attr.demotion_counter,
                rust_counter = attr.rust_counter,
                soft_demotion = attr.soft_demotion,
                unused_counter = attr.unused_counter
            }
        end
    end
    return data
end

local function extract_mental_data(unit)
    local data = {}
    local soul = unit.status.current_soul
    if soul and soul.mental_attrs then
        for name, attr in pairs(soul.mental_attrs) do
            data[tostring(name)] = {
                value = attr.value,
                max_value = attr.max_value,
                improve_counter = attr.improve_counter,
                demotion_counter = attr.demotion_counter,
                rust_counter = attr.rust_counter,
                soft_demotion = attr.soft_demotion,
                unused_counter = attr.unused_counter
            }
        end
    end
    return data
end

local function extract_personality_data(unit)
    local data = {traits = {}, values = {}}
    local soul = unit.status.current_soul
    if soul and soul.personality then
        -- Extract traits
        if soul.personality.traits then
            for k, v in pairs(soul.personality.traits) do
                data.traits[tostring(k)] = v
            end
        end
        -- Extract values
        if soul.personality.values then
            for i, pv in ipairs(soul.personality.values) do
                table.insert(data.values, {
                    type = pv.type,
                    strength = pv.strength
                })
            end
        end
    end
    return data
end

local function extract_skills_data(unit)
    local data = {}
    local soul = unit.status.current_soul
    if soul and soul.skills then
        for _, sk in ipairs(soul.skills) do
            table.insert(data, {
                id = sk.id,
                rating = sk.rating,
                experience = sk.experience,
                demotion_counter = sk.demotion_counter,
                rust_counter = sk.rust_counter,
                rusty = sk.rusty,
                unused_counter = sk.unused_counter,
                natural_skill_lvl = sk.natural_skill_lvl
            })
        end
    end
    return data
end

local function apply_physical_data(unit, data)
    if not data or not unit.body.physical_attrs then return end
    for name, values in pairs(data) do
        local attr = unit.body.physical_attrs[name]
        if attr then
            for field, value in pairs(values) do
                attr[field] = value
            end
        end
    end
end

local function apply_mental_data(unit, data)
    local soul = unit.status.current_soul
    if not data or not soul or not soul.mental_attrs then return end
    for name, values in pairs(data) do
        local attr = soul.mental_attrs[name]
        if attr then
            for field, value in pairs(values) do
                attr[field] = value
            end
        end
    end
end

local function apply_personality_data(unit, data)
    local soul = unit.status.current_soul
    if not data or not soul or not soul.personality then return end
    
    -- Apply traits
    if data.traits and soul.personality.traits then
        for k, v in pairs(data.traits) do
            soul.personality.traits[k] = v
        end
    end
    
    -- Apply values (this is trickier as we need to match by type)
    if data.values and soul.personality.values then
        for _, saved_pv in ipairs(data.values) do
            for _, pv in ipairs(soul.personality.values) do
                if pv.type == saved_pv.type then
                    pv.strength = saved_pv.strength
                    break
                end
            end
        end
    end
end

local function apply_skills_data(unit, data)
    local soul = unit.status.current_soul
    if not data or not soul then return end
    
    -- Clear existing skills
    soul.skills:resize(0)
    
    -- Add new skills
    for _, skill_data in ipairs(data) do
        local sk = df.unit_skill:new()
        sk.id = skill_data.id
        sk.rating = skill_data.rating
        sk.experience = skill_data.experience
        sk.demotion_counter = skill_data.demotion_counter
        sk.rust_counter = skill_data.rust_counter
        sk.rusty = skill_data.rusty
        sk.unused_counter = skill_data.unused_counter
        sk.natural_skill_lvl = skill_data.natural_skill_lvl
        soul.skills:insert('#', sk)
    end
end

----------------------------------------------------------------
-- Page Builders
----------------------------------------------------------------

local function make_attr_detail(attr, get_tab, flip, back)
    local fields = {
        'value', 'max_value', 'improve_counter', 'demotion_counter',
        'rust_counter', 'soft_demotion', 'unused_counter'
    }
    local rows = {}
    for _, f in ipairs(fields) do
        table.insert(rows, {
            label = f,
            get = function() return attr[f] end,
            set = function(v) attr[f] = v end,
        })
    end
    return make_editable_list(rows, get_tab, flip, nil, back)
end

local function make_attr_page(container, get_tab, flip, nav_to)
    local rows = {}
    if container then
        for name, data in pairs(container) do
            table.insert(rows, {
                label = niceify(name),
                get = function() return data.value end,
                set = function(v) data.value = v end,
                navigable = true,
                navigate_target = {attr_data = data},
            })
        end
    end
    if #rows == 0 then
        table.insert(rows, {label = '(No data)', get = function() return '' end, set = function() end})
    end
    return make_editable_list(rows, get_tab, flip, nav_to, nil)
end

local function make_personality_value_detail_page(pval, get_tab, flip, back)
    local rows = {
        {
            label = 'type',
            get = function()
                local e = df.value_type[pval.type] or ('<%d>'):format(pval.type)
                return ('%s (%d)'):format(e, pval.type)
            end,
            set = function(v) pval.type = v end
        },
        {
            label = 'strength',
            get = function() return pval.strength end,
            set = function(v) pval.strength = v end
        },
    }
    return make_editable_list(rows, get_tab, flip, nil, back)
end

local function make_personality_page(unit, get_tab, flip, nav_to)
    local rows = {}
    local soul = unit.status.current_soul
    local pers = soul and soul.personality

    if pers then
        for k, _ in pairs(pers.traits or {}) do
            local kk = k
            table.insert(rows, {
                label = niceify(kk),
                get = function() return pers.traits[kk] end,
                set = function(v) pers.traits[kk] = v end
            })
        end

        for _, pv in ipairs(pers.values or {}) do
            local en = df.value_type[pv.type] or ('<%d>'):format(pv.type)
            table.insert(rows, {
                label = niceify(en),
                get = function() return pv.strength end,
                set = function(v) pv.strength = v end,
                navigable = true,
                navigate_target = {pval = pv, label = en},
            })
        end
    end

    if #rows == 0 then
        table.insert(rows, {label = '(No personality data)', get = function() return '' end, set = function() end})
    end

    return make_editable_list(rows, get_tab, flip, nav_to, nil)
end

local function make_skill_detail_page(skill, get_tab, flip, back)
    local fields = {
        'rating', 'experience', 'demotion_counter', 'rust_counter',
        'rusty', 'unused_counter', 'natural_skill_lvl'
    }
    local rows = {}
    for _, f in ipairs(fields) do
        table.insert(rows, {
            label = f,
            get = function() return skill[f] end,
            set = function(v) skill[f] = v end
        })
    end
    return make_editable_list(rows, get_tab, flip, nil, back)
end

----------------------------------------------------------------
--  Skills page  (add/remove + robust refresh)
----------------------------------------------------------------
local function make_skills_page(unit, get_tab, flip, nav_to)
    local soul     = unit.status.current_soul
    local skills_v = soul and soul.skills or {}

    ------------------------------------------------------------
    -- rows describing each skill
    ------------------------------------------------------------
    local function build_rows()
        local rows = {}
        for _, sk in ipairs(skills_v) do
            local name = df.job_skill[sk.id] or ('<%d>'):format(sk.id)
            rows[#rows+1] = {
                label     = niceify(name),
                get       = function() return sk.rating end,
                set       = function(v) sk.rating = v end,
                navigable = true,
                navigate_target = {skill = sk, label = name},
            }
        end
        if #rows == 0 then
            rows[1] = {
                label='(No skills)',
                get=function() return '' end,
                set=function() end,
                navigable=false
            }
        end
        return rows
    end

    ------------------------------------------------------------
    -- convert rows → list choices (same logic as make_editable_list)
    ------------------------------------------------------------
    local function rows_to_choices()
        local ch = {}
        for _, row in ipairs(build_rows()) do
            local ok, val = pcall(row.get)
            ch[#ch+1] = {
                label           = row.label,
                text            = row.label .. ': ' ..
                                  (ok and getStringValue(val) or '(error)'),
                get             = row.get,
                set             = row.set,
                navigable       = row.navigable,
                navigate_target = row.navigate_target,
            }
        end
        return ch
    end

    ------------------------------------------------------------
    -- list (leave space for preset sidebar on the right)
    ------------------------------------------------------------
    local list = widgets.List{
        frame   = {t=0,l=0,b=0,r=15},  -- Changed from r=12 to r=15 to avoid preset sidebar
        choices = rows_to_choices(),
        on_submit = function(_, choice)
            if choice.navigable and choice.navigate_target then
                nav_to(choice.navigate_target, choice.label)
                return
            end
            local cur = choice.get() or ''
            dialog.showInputPrompt(
                choice.label, 'Enter new value:', COLOR_WHITE, tostring(cur),
                function(new_val)
                    local num = tonumber(new_val)
                    if num then choice.set(num) end
                    -- force redraw by "tab flip" trick
                    local cur_tab = get_tab()
                    local other   = (cur_tab % 4) + 1
                    flip(other); flip(cur_tab)
                end
            )
        end,
    }

    ------------------------------------------------------------
    -- replace refreshDisplay so it always regenerates choices
    ------------------------------------------------------------
    local function relist(sel)
        sel = sel or list:getSelected() or 1
        local choices = rows_to_choices()
        list:setChoices(choices)
        list:setSelected(math.min(sel, #choices))
    end
    list.refreshDisplay = relist          -- <— key change

    local function refresh()              -- helper for add/remove
        relist()
        dfhack.screen.invalidate()
    end

    ------------------------------------------------------------
    -- ADD
    ------------------------------------------------------------
    local function add_skill()
        local have, choices = {}, {}
        for _, sk in ipairs(skills_v) do have[sk.id] = true end
        for id, name in ipairs(df.job_skill) do
            if id ~= df.job_skill.NONE and not have[id] then
                choices[#choices+1] = {text=niceify(name), data=id}
            end
        end
        if #choices == 0 then return end

        dialog.showListPrompt(
            'Add Skill', 'Select a skill to add:', COLOR_WHITE, choices,
            function(_, ch)
                dialog.showInputPrompt(
                    ch.text, 'Enter rating (0-20):', COLOR_WHITE, '',
                    function(raw)
                        local rating = math.max(0,
                                       math.min(tonumber(raw) or 0, 20))
                        local sk = df.unit_skill:new()
                        sk.id                 = ch.data
                        sk.rating             = rating
                        sk.experience         = 0
                        sk.demotion_counter   = 0
                        sk.rust_counter       = 0
                        sk.rusty              = 0
                        sk.unused_counter     = 0
                        sk.natural_skill_lvl  = 0
                        skills_v:insert('#', sk)
                        refresh()
                    end)
            end, nil, nil, true)
    end

    ------------------------------------------------------------
    -- REMOVE
    ------------------------------------------------------------
    local function remove_skill()
        local idx = list:getSelected()
        if not idx then return end
        local sk   = skills_v[idx - 1]      -- df vectors are 0-based
        local name = niceify(df.job_skill[sk.id] or '<skill>')

        dialog.showYesNoPrompt(
            'Remove Skill',
            ('Delete %s from this creature?'):format(name),
            COLOR_YELLOW,
            function()                        -- YES
                skills_v:erase(idx - 1)
                refresh()
            end)
    end

    ------------------------------------------------------------
    -- sidebar buttons (positioned to not overlap with preset sidebar)
    ------------------------------------------------------------
    local sidebar = widgets.Panel{
        frame={t=10,r=0,w=15,h=5},  -- Moved down to t=10 to appear below preset sidebar
        subviews={
            widgets.Label{
                frame={t=0,l=0},
                text={{text='[Add Skill]', pen=COLOR_LIGHTGREEN}},  -- Changed text
                auto_width=true,
                on_click=add_skill,
            },
            widgets.Label{
                frame={t=2,l=0},
                text={{text='[Remove]', pen=COLOR_LIGHTRED}},
                auto_width=true,
                on_click=remove_skill,
            },
        },
    }

    ------------------------------------------------------------
    -- root panel
    ------------------------------------------------------------
    return widgets.Panel{
        frame     = {t=0,l=0,r=0,b=0},
        subviews  = {list, sidebar},
    }
end

----------------------------------------------------------------
-- Preset UI Components
----------------------------------------------------------------

local function make_preset_sidebar(unit, parent)
    local function save_tab_preset()
        local tab_idx = parent.subviews.pages:getSelected()
        local tab_names = {'physical', 'mental', 'personality', 'skills'}
        local tab_name = tab_names[tab_idx]
        
        dialog.showInputPrompt(
            'Save ' .. tab_name .. ' preset',
            'Enter preset name:',
            COLOR_WHITE,
            '',
            function(name)
                if name == '' then return end
                ensure_preset_dir()
                
                local data = {}
                if tab_idx == 1 then
                    data = extract_physical_data(unit)
                elseif tab_idx == 2 then
                    data = extract_mental_data(unit)
                elseif tab_idx == 3 then
                    data = extract_personality_data(unit)
                elseif tab_idx == 4 then
                    data = extract_skills_data(unit)
                end
                
                local preset = {
                    name = name,
                    type = tab_name,
                    data = data
                }
                
                local filename = PRESET_DIR .. '/' .. name:gsub('[^%w%-_]', '_') .. '_' .. tab_name .. '.json'
                local file = json.open(filename)
                file.data = preset
                file:write()
            end
        )
    end
    
    local function save_all_preset()
        dialog.showInputPrompt(
            'Save complete preset',
            'Enter preset name:',
            COLOR_WHITE,
            '',
            function(name)
                if name == '' then return end
                ensure_preset_dir()
                
                local preset = {
                    name = name,
                    type = 'all',
                    data = {
                        physical = extract_physical_data(unit),
                        mental = extract_mental_data(unit),
                        personality = extract_personality_data(unit),
                        skills = extract_skills_data(unit)
                    }
                }
                
                local filename = PRESET_DIR .. '/' .. name:gsub('[^%w%-_]', '_') .. '_all.json'
                local file = json.open(filename)
                file.data = preset
                file:write()
            end
        )
    end
    
    local function load_tab_preset()
        local tab_idx = parent.subviews.pages:getSelected()
        local tab_names = {'physical', 'mental', 'personality', 'skills'}
        local tab_name = tab_names[tab_idx]
        
        local files = get_preset_files()
        local choices = {}
        
        for _, file in ipairs(files) do
            if file:match('_' .. tab_name .. '%.json$') or file:match('_all%.json$') then
                local display_name = file:gsub('%.json$', '')
                table.insert(choices, {text = display_name, file = file})
            end
        end
        
        if #choices == 0 then
            dialog.showMessage('No presets', 'No presets found for ' .. tab_name, COLOR_YELLOW)
            return
        end
        
        dialog.showListPrompt(
            'Load ' .. tab_name .. ' preset',
            'Select a preset:',
            COLOR_WHITE,
            choices,
            function(_, choice)
                local file = json.open(PRESET_DIR .. '/' .. choice.file)
                local preset = file.data
                
                if preset.type == 'all' and preset.data[tab_name] then
                    if tab_idx == 1 then
                        apply_physical_data(unit, preset.data[tab_name])
                    elseif tab_idx == 2 then
                        apply_mental_data(unit, preset.data[tab_name])
                    elseif tab_idx == 3 then
                        apply_personality_data(unit, preset.data[tab_name])
                    elseif tab_idx == 4 then
                        apply_skills_data(unit, preset.data[tab_name])
                    end
                elseif preset.type == tab_name then
                    if tab_idx == 1 then
                        apply_physical_data(unit, preset.data)
                    elseif tab_idx == 2 then
                        apply_mental_data(unit, preset.data)
                    elseif tab_idx == 3 then
                        apply_personality_data(unit, preset.data)
                    elseif tab_idx == 4 then
                        apply_skills_data(unit, preset.data)
                    end
                else
                    dialog.showMessage('Error', 'Preset type mismatch', COLOR_RED)
                    return
                end
                
                parent:refreshCurrentPage()
            end
        )
    end
    
    local function load_all_preset()
        local files = get_preset_files()
        local choices = {}
        
        for _, file in ipairs(files) do
            if file:match('_all%.json$') then
                table.insert(choices, {text = file, file = file})
            end
        end
        
        if #choices == 0 then
            dialog.showMessage('No presets', 'No complete presets found', COLOR_YELLOW)
            return
        end
        
        dialog.showListPrompt(
            'Load complete preset',
            'Select a preset:',
            COLOR_WHITE,
            choices,
            function(_, choice)
                local file = json.open(PRESET_DIR .. '/' .. choice.file)
                local preset = file.data
                
                if preset.type ~= 'all' then
                    dialog.showMessage('Error', 'Not a complete preset', COLOR_RED)
                    return
                end
                
                apply_physical_data(unit, preset.data.physical)
                apply_mental_data(unit, preset.data.mental)
                apply_personality_data(unit, preset.data.personality)
                apply_skills_data(unit, preset.data.skills)
                
                parent:refreshCurrentPage()
                dialog.showMessage('Success', 'Complete preset loaded!', COLOR_GREEN)
            end
        )
    end
    
    return widgets.Panel{
        frame={t=0, r=0, w=15, h=9},
        frame_style=gui.FRAME_INTERIOR,
        subviews={
            widgets.Label{
                frame={t=0, l=0, r=0},
                text={{text='Presets', pen=COLOR_CYAN}},
                text_pen=COLOR_WHITE,
            },
            widgets.Label{
                frame={t=2, l=1},
                text={{text='[Save Tab]', pen=COLOR_LIGHTGREEN}},
                auto_width=true,
                on_click=save_tab_preset,
            },
            widgets.Label{
                frame={t=3, l=1},
                text={{text='[Load Tab]', pen=COLOR_LIGHTGREEN}},
                auto_width=true,
                on_click=load_tab_preset,
            },
            widgets.Label{
                frame={t=5, l=1},
                text={{text='[Save All]', pen=COLOR_LIGHTCYAN}},
                auto_width=true,
                on_click=save_all_preset,
            },
            widgets.Label{
                frame={t=6, l=1},
                text={{text='[Load All]', pen=COLOR_LIGHTCYAN}},
                auto_width=true,
                on_click=load_all_preset,
            },
        }
    }
end

----------------------------------------------------------------
-- Main Window
----------------------------------------------------------------

CreatureEditor = defclass(CreatureEditor, widgets.Window)
CreatureEditor.ATTRS{
    frame_title = 'Creature Editor',
    frame = {w=75, h=30, r=2, t=2},
    frame_style = gui.FRAME_WINDOW,
    resizable = true,
}

function CreatureEditor:init()
    local unit = dfhack.gui.getSelectedUnit(true)
    
    -- Check if we have a valid unit selected
    if not unit then
        dialog.showMessage('Error', 'No unit selected! Please select a creature first.', COLOR_RED)
        self:dismiss()
        return
    end
    
    self.navigation_stack = {}

    local pages = widgets.Pages{view_id = 'pages', frame = {t=2, l=0, r=0, b=0}}
    local function cur_tab() return pages:getSelected() end
    local function flip(t) pages:setSelected(t); self:refreshCurrentPage() end

    self.page_refs = {}

    function navigate_to(target, label)
        local tab = cur_tab()
        if target.attr_data then
            table.insert(self.navigation_stack, {tab = tab})
            self.page_refs[tab] = make_attr_detail(target.attr_data, cur_tab, flip, function() self:navigateBack() end)
        elseif target.pval then
            table.insert(self.navigation_stack, {tab = 3})
            self.page_refs[3] = make_personality_value_detail_page(target.pval, cur_tab, flip, function() self:navigateBack() end)
        elseif target.skill then
            table.insert(self.navigation_stack, {tab = 4})
            self.page_refs[4] = make_skill_detail_page(target.skill, cur_tab, flip, function() self:navigateBack() end)
        end
        pages.subviews[tab] = self.page_refs[tab]
        self:updateTitle(label)
        self:updateLayout()
        dfhack.screen.invalidate()
        self:refreshCurrentPage()
    end

    local function build_root(idx)
        if idx == 1 then
            return make_attr_page(unit.body.physical_attrs, cur_tab, flip, navigate_to)
        elseif idx == 2 then
            local soul = unit.status.current_soul
            return make_attr_page(soul and soul.mental_attrs, cur_tab, flip, navigate_to)
        elseif idx == 3 then
            return make_personality_page(unit, cur_tab, flip, navigate_to)
        elseif idx == 4 then
            return make_skills_page(unit, cur_tab, flip, navigate_to)
        end
    end

    local function ensure_page(idx)
        if not self.page_refs[idx] then
            self.page_refs[idx] = build_root(idx)
            pages.subviews[idx] = self.page_refs[idx]
        end
    end

    local tab_bar = widgets.TabBar{
        view_id = 'tab_bar',
        frame = {t=0, l=0},
        labels = {'Physical', 'Mental', 'Personality', 'Skills'},
        on_select = function(idx)
            if #self.navigation_stack > 0 then
                self.navigation_stack = {}
                self:updateTitle('Creature Editor')
                self.page_refs = {}
            end
            ensure_page(idx)
            pages:setSelected(idx)
            self:refreshCurrentPage()
        end,
        get_cur_page = function()
            return pages:getSelected()
        end,
    }
    
    -- Add the preset sidebar
    local preset_sidebar = make_preset_sidebar(unit, self)

    self:addviews{tab_bar, pages, preset_sidebar}
    for i = 1, 4 do ensure_page(i) end

    -- Fix initial text rendering bug by rapidly cycling tabs
    for i = 2, 4 do
        tab_bar.on_select(i)
    end
    tab_bar.on_select(1)
end

function CreatureEditor:navigateBack()
    if #self.navigation_stack == 0 then return end
    table.remove(self.navigation_stack)
    if #self.navigation_stack == 0 then
        local idx = self.subviews.pages:getSelected()
        self.page_refs[idx] = nil
        self:updateTitle('Creature Editor')
        self.subviews.tab_bar.on_select(idx)
        self:updateLayout()
        dfhack.screen.invalidate()
    end
end

function CreatureEditor:updateTitle(sub)
    self.frame_title = sub and ('Creature Editor - ' .. sub) or 'Creature Editor'
    self:updateLayout()
end

function CreatureEditor:refreshCurrentPage()
    local pg = self.subviews.pages.subviews[self.subviews.pages:getSelected()]
    if pg and pg.refreshDisplay then pg:refreshDisplay() end
end

----------------------------------------------------------------
-- Z-Screen Wrapper
----------------------------------------------------------------

CreatureEditorScreen = defclass(CreatureEditorScreen, gui.ZScreen)
CreatureEditorScreen.ATTRS{focus_path = 'creature_editor'}
function CreatureEditorScreen:init() self:addviews{CreatureEditor{}} end
function CreatureEditorScreen:onDismiss() view = nil end
view = view and view:raise() or CreatureEditorScreen{}:show()

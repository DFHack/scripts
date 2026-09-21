local gui = require('gui')
local widgets = require('gui.widgets')
local dialogs = require('gui.dialogs')

-- res:  historical_entity.resources field holding the known subtypes
-- defs: world.raws.itemdefs field holding every itemdef of that kind
-- raw:  entity_raw.equipment field holding the civ's native subtypes

local CATEGORIES = {
    {key='armor',      name='Armor & clothing', short='armor',   res='armor_type',            defs='armor',       raw='armor_id'},
    {key='helm',       name='Helms & hats',     short='helm',    res='helm_type',             defs='helms',       raw='helm_id'},
    {key='gloves',     name='Gloves',           short='gloves',  res='gloves_type',           defs='gloves',      raw='gloves_id'},
    {key='shoes',      name='Shoes & boots',    short='shoes',   res='shoes_type',            defs='shoes',       raw='shoes_id'},
    {key='pants',      name='Pants & skirts',   short='pants',   res='pants_type',            defs='pants',       raw='pants_id'},
    {key='shield',     name='Shields',          short='shield',  res='shield_type',           defs='shields',     raw='shield_id'},
    {key='weapon',     name='Weapons',          short='weapon',  res='weapon_type',           defs='weapons',     raw='weapon_id',  cls='weapon'},
    {key='digger',     name='Diggers',          short='digger',  res='digger_type',           defs='weapons',     raw='digger_id',  cls='digger'},
    {key='training',   name='Training wpns',    short='training',res='training_weapon_type',  defs='weapons',                       cls='training'},
    {key='ammo',       name='Ammo',             short='ammo',    res='ammo_type',             defs='ammo',        raw='ammo_id'},
    {key='siegeammo',  name='Siege ammo',       short='siege',   res='siegeammo_type',        defs='siege_ammo',  raw='siegeammo_id'},
    {key='trapcomp',   name='Trap comps',       short='trapcomp',res='trapcomp_type',         defs='trapcomps',   raw='trapcomp_id'},
    {key='tool',       name='Tools',            short='tool',    res='tool_type',             defs='tools',       raw='tool_id'},
    {key='toy',        name='Toys',             short='toy',     res='toy_type',              defs='toys',        raw='toy_id'},
    {key='instrument', name='Instruments',      short='instrmnt',res='instrument_type',       defs='instruments', raw='instrument_id'},
}

local NAME_W = 26
local SHORT_W = 9
-- widest category name is 16, +1 so the count never abuts it. the sidebar must
-- fit CAT_W plus the widest count ("112/275") plus a column for the scrollbar
local CAT_W = 17

--
-- data layer
--

-- some of these fields may not exist in every df version
local function try_field(obj, field)
    if not obj or not field then return nil end
    local ok, val = pcall(function() return obj[field] end)
    if ok then return val end
    return nil
end

local function get_civ()
    local civ_id = df.global.plotinfo.civ_id
    if not civ_id or civ_id < 0 then return nil end
    return df.historical_entity.find(civ_id)
end

-- weapons, diggers, and training weapons all share the weapon itemdef list
local function weapon_class(def)
    local flags = try_field(def, 'flags')
    if flags and try_field(flags, 'TRAINING') then return 'training' end
    if def.skill_melee == df.job_skill.MINING then return 'digger' end
    return 'weapon'
end

local function is_generated(def)
    local base = try_field(def, 'base_flags')
    return base and try_field(base, 'GENERATED') or false
end

-- returns nil if this df version lacks the fields, in which case the category is
-- dropped from the ui
local function build_category(civ, cat)
    local vec = try_field(civ.resources, cat.res)
    local defs = try_field(df.global.world.raws.itemdefs, cat.defs)
    if not vec or not defs then return nil end

    local native
    local eq = try_field(civ.entity_raw, 'equipment')
    local native_vec = try_field(eq, cat.raw)
    if native_vec then
        native = {}
        for _, subtype in ipairs(native_vec) do
            native[subtype] = true
        end
    end

    local items = {}
    for _, def in ipairs(defs) do
        if not cat.cls or weapon_class(def) == cat.cls then
            table.insert(items, {
                subtype = def.subtype,
                name = def.name,
                id = def.id,
                generated = is_generated(def),
                native = native and native[def.subtype] or false,
                -- distinguishes "not native" from "no raw list to check against"
                native_known = native ~= nil,
            })
        end
    end

    local built = {}
    for k, v in pairs(cat) do built[k] = v end
    built.items = items
    return built
end

local function count_in(vec, subtype)
    local n = 0
    for _, v in ipairs(vec) do
        if v == subtype then n = n + 1 end
    end
    return n
end

--
-- CivStyles window
--

CivStyles = defclass(CivStyles, widgets.Window)
CivStyles.ATTRS{
    frame_title='Civilization styles',
    frame={w=80, h=34},
    resizable=true,
    resize_min={w=72, h=20},
}

function CivStyles:init()
    self.civ_id = df.global.plotinfo.civ_id

    local civ = get_civ()
    self.cats = {}
    for _, cat in ipairs(CATEGORIES) do
        local built = build_category(civ, cat)
        if built then table.insert(self.cats, built) end
    end

    self.by_key = {}
    for _, cat in ipairs(self.cats) do self.by_key[cat.key] = cat end

    self.known = {}
    self.counts = {}
    self:refresh_data()

    self:addviews{
        widgets.List{
            view_id='cats',
            frame={t=0, l=0, w=25, b=4},
            scroll_keys={},  -- mouse only; arrow keys belong to the item list
            on_select=self:callback('on_category'),
            choices=self:get_category_choices(),
        },
        widgets.Divider{
            frame={t=0, l=26, w=1, b=4},
            frame_style=gui.FRAME_THIN,
            frame_style_t=false,
            frame_style_b=false,
        },
        widgets.FilteredList{
            view_id='list',
            frame={t=0, l=28, r=0, b=4},
            row_height=2,
            not_found_label='No styles match',
            on_submit=self:callback('on_toggle'),
        },
        widgets.Divider{
            frame={b=3, h=1, l=0, r=0},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.ToggleHotkeyLabel{
            view_id='generated',
            frame={b=2, l=0, w=22},
            key='CUSTOM_CTRL_G',
            label='Generated',
            initial_option=false,
            on_change=function() self:refresh_list(true) end,
        },
        widgets.CycleHotkeyLabel{
            view_id='show',
            frame={b=2, l=24},
            key='CUSTOM_CTRL_S',
            label='Show',
            options={
                {label='all', value='all'},
                {label='known only', value='known', pen=COLOR_LIGHTGREEN},
                {label='missing only', value='missing', pen=COLOR_GRAY},
            },
            on_change=function() self:refresh_list(true) end,
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            key='CUSTOM_CTRL_A',
            label='Add all shown',
            on_activate=self:callback('add_all_shown'),
        },
        widgets.HotkeyLabel{
            frame={b=1, l=24},
            key='CUSTOM_CTRL_X',
            label='Remove all shown',
            on_activate=self:callback('remove_all_shown'),
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key='CUSTOM_CTRL_D',
            label='Remove duplicates',
            on_activate=self:callback('dedupe'),
        },
        widgets.Label{
            frame={b=0, l=28},
            text={
                {text='Enter', pen=COLOR_LIGHTGREEN},
                ' or click toggles a style.',
            },
        },
    }

    self.subviews.cats:setSelected(1)
    self:refresh_list()
end

function CivStyles:get_civ()
    return df.historical_entity.find(self.civ_id)
end

function CivStyles:get_vec(cat)
    local civ = self:get_civ()
    if not civ then return nil end
    return try_field(civ.resources, cat.res)
end

-- run after every edit so nothing has to be recounted per frame
function CivStyles:refresh_data()
    for _, cat in ipairs(self.cats) do
        local counts = {}
        local vec = self:get_vec(cat)
        if vec then
            for _, subtype in ipairs(vec) do
                counts[subtype] = (counts[subtype] or 0) + 1
            end
        end
        self.known[cat.key] = counts

        local n = 0
        for _, item in ipairs(cat.items) do
            if counts[item.subtype] then n = n + 1 end
        end
        self.counts[cat.key] = {known=n, total=#cat.items}
    end
end

function CivStyles:get_category_choices()
    local choices = {{
        text={
            {text='All', width=CAT_W},
            {text=function()
                local known, total = 0, 0
                for _, c in ipairs(self.cats) do
                    known = known + self.counts[c.key].known
                    total = total + self.counts[c.key].total
                end
                return ('%d/%d'):format(known, total)
            end, pen=COLOR_GRAY},
        },
        key_val=nil,
    }}
    for _, cat in ipairs(self.cats) do
        table.insert(choices, {
            text={
                {text=cat.name, width=CAT_W},
                {text=function()
                    local c = self.counts[cat.key]
                    return ('%d/%d'):format(c.known, c.total)
                end, pen=COLOR_GRAY},
            },
            key_val=cat.key,
        })
    end
    return choices
end

function CivStyles:on_category(_, choice)
    if not choice then return end
    if self.cur_cat_key == choice.key_val and self.list_built then return end
    self.cur_cat_key = choice.key_val
    if self.list_built then self:refresh_list() end
end

function CivStyles:selected_cats()
    if not self.cur_cat_key then return self.cats end
    local cat = self.by_key[self.cur_cat_key]
    return cat and {cat} or self.cats
end

function CivStyles:make_row(cat, item)
    -- must go through self: refresh_data() replaces the table rather than
    -- mutating it, so a captured reference would go stale
    local function count()
        return self.known[cat.key][item.subtype]
    end

    -- generated items are never in the raws, so exotic would be redundant
    local tags = {}
    if item.generated then
        table.insert(tags, {text='gen', pen=COLOR_MAGENTA})
    elseif item.native then
        table.insert(tags, {text='native', pen=COLOR_CYAN})
    elseif item.native_known then
        table.insert(tags, {text='exotic', pen=COLOR_BROWN})
    end

    local text = {
        {text=function()
            return count() and '[x]' or '[ ]'
        end, pen=function()
            return count() and COLOR_LIGHTGREEN or COLOR_GRAY
        end, width=3},
        {gap=1, text=item.name, width=NAME_W},
    }
    for _, tag in ipairs(tags) do table.insert(text, tag) end
    table.insert(text, {gap=1, text=function()
        local n = count() or 0
        return n > 1 and ('x%d'):format(n) or ''
    end, pen=COLOR_LIGHTRED})
    table.insert(text, NEWLINE)
    table.insert(text, {gap=4, text=cat.short, width=SHORT_W, pen=COLOR_DARKGRAY})
    table.insert(text, {gap=1, text=item.id, pen=COLOR_GRAY})

    return {
        text=text,
        search_key=('%s %s %s %s'):format(item.name, item.id, cat.short, cat.name),
        cat_key=cat.key,
        subtype=item.subtype,
    }
end

function CivStyles:refresh_list(preserve)
    local list = self.subviews.list
    local filter = preserve and list:getFilter() or ''
    local _, prev = list:getSelected()
    local prev_cat, prev_subtype
    if prev then
        prev_cat, prev_subtype = prev.cat_key, prev.subtype
    end

    local show = self.subviews.show:getOptionValue()
    local show_generated = self.subviews.generated:getOptionValue()

    local choices, reselect = {}, nil
    for _, cat in ipairs(self:selected_cats()) do
        local counts = self.known[cat.key]
        for _, item in ipairs(cat.items) do
            local is_known = counts[item.subtype] ~= nil
            local ok = true
            if item.generated and not show_generated and not is_known then ok = false end
            if show == 'known' and not is_known then ok = false end
            if show == 'missing' and is_known then ok = false end
            if ok then
                table.insert(choices, self:make_row(cat, item))
                if cat.key == prev_cat and item.subtype == prev_subtype then
                    reselect = #choices
                end
            end
        end
    end

    list:setChoices(choices, reselect)
    if filter ~= '' then
        list:setFilter(filter, reselect)
    end
    self.list_built = true
end

--
-- edits
--

function CivStyles:add(cat_key, subtype)
    local cat = self.by_key[cat_key]
    local vec = cat and self:get_vec(cat)
    if not vec then return end
    if count_in(vec, subtype) == 0 then
        vec:insert('#', subtype)
    end
end

function CivStyles:remove(cat_key, subtype)
    local cat = self.by_key[cat_key]
    local vec = cat and self:get_vec(cat)
    if not vec then return end
    for i = #vec - 1, 0, -1 do
        if vec[i] == subtype then vec:erase(i) end
    end
end

function CivStyles:after_edit()
    self:refresh_data()
    -- rows read their state live; only a filtered view needs rebuilding
    if self.subviews.show:getOptionValue() ~= 'all' then
        self:refresh_list(true)
    end
end

function CivStyles:on_toggle(_, choice)
    if not choice then return end
    local counts = self.known[choice.cat_key]
    if counts[choice.subtype] then
        self:remove(choice.cat_key, choice.subtype)
    else
        self:add(choice.cat_key, choice.subtype)
    end
    self:after_edit()
end

function CivStyles:add_all_shown()
    for _, choice in ipairs(self.subviews.list:getVisibleChoices()) do
        self:add(choice.cat_key, choice.subtype)
    end
    self:after_edit()
end

function CivStyles:remove_all_shown()
    local shown = self.subviews.list:getVisibleChoices()
    local n = 0
    for _, choice in ipairs(shown) do
        if self.known[choice.cat_key][choice.subtype] then n = n + 1 end
    end
    if n == 0 then return end
    dialogs.showYesNoPrompt('Remove styles',
        ('Take %d style%s away from your civilization?\n\nAnything already made stays; you just lose the ability to order more.')
            :format(n, n == 1 and '' or 's'),
        COLOR_YELLOW,
        function()
            for _, choice in ipairs(shown) do
                self:remove(choice.cat_key, choice.subtype)
            end
            self:after_edit()
        end)
end

function CivStyles:dedupe()
    local removed = 0
    for _, cat in ipairs(self:selected_cats()) do
        local vec = self:get_vec(cat)
        if vec then
            local seen = {}
            for i = #vec - 1, 0, -1 do
                local subtype = vec[i]
                if seen[subtype] then
                    vec:erase(i)
                    removed = removed + 1
                else
                    seen[subtype] = true
                end
            end
        end
    end
    self:after_edit()
    if removed > 0 then
        dialogs.showMessage('Duplicates removed',
            ('Removed %d duplicate entr%s.'):format(removed, removed == 1 and 'y' or 'ies'),
            COLOR_GREEN)
    else
        dialogs.showMessage('No duplicates', 'Nothing was listed twice.', COLOR_GREEN)
    end
end

--
-- screen
--

CivStylesScreen = defclass(CivStylesScreen, gui.ZScreen)
CivStylesScreen.ATTRS{
    focus_path='civ-styles',
}

function CivStylesScreen:init()
    self:addviews{CivStyles{}}
end

function CivStylesScreen:onDismiss()
    view = nil
end

if not dfhack.isWorldLoaded() then
    qerror('This script requires a world to be loaded')
end

local civ = get_civ()
if not civ then
    qerror('Could not find your civilization -- load a fortress first')
end

view = view and view:raise() or CivStylesScreen{}:show()

-- Find and track historical figures and artifacts
--@module = true

local argparse = require('argparse')
local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')

local world = df.global.world
local transName = dfhack.translation.translateName
local findHF = df.historical_figure.find
local toSearch = dfhack.toSearchNormalized

LType = utils.invert{'None','Local','Site','Wild','Under','Army'} --Location type

filter_text = filter_text --Stored filter between lists; for setting only!
--  Use AdvSelWindow:get_filter_text() instead for getting current filter
cur_tab = cur_tab or 1 -- 1: HF, 2: Artifact
show_dead = show_dead or false --Exclude dead HFs
show_books = show_books or false --Exclude books
sel_hf = sel_hf or -1 --Selected historical_figure.id
sel_art = sel_art or -1 --Selected artifact_record.id
debug_id = false --Show target ID in window title; reopening without -d option resets

---- Fns for target names ----

local function get_race_name(hf) --E.g., 'Plump Helmet Man'
    return dfhack.capitalizeStringWords(dfhack.units.getRaceReadableNameById(hf.race))
end

function get_hf_name(hf) --'Native Name "Translated Name", Race'
    local full_name = transName(hf.name, false)
    if full_name == '' then --Improve searchability
        full_name = 'Unnamed'
    else --Add the translation
        local t_name = transName(hf.name, true)
        if full_name ~= t_name then --Don't repeat
            full_name = full_name..' "'..t_name..'"'
        end
    end
    local race_name = get_race_name(hf)
    if race_name == '' then --Elf deities don't have a race
        full_name = full_name..', Force'
    else --Add the race
        full_name = full_name..', '..race_name
    end
    return full_name
end

function get_art_name(ar) --'Native Name "Translated Name", Item'
    local full_name = transName(ar.name, false)
    if full_name == '' then --Improve searchability
        full_name = 'Unnamed'
    else --Add the translation
        local t_name = transName(ar.name, true)
        if full_name ~= t_name then --Don't repeat
            full_name = full_name..' "'..t_name..'"'
        end
    end
    return full_name..', '..dfhack.items.getDescription(ar.item, 1, true)
end

local function build_hf_list() --Build alphabetized HF list
    local t = {}
    for _,hf in ipairs(world.history.figures) do
        if show_dead or hf.died_year == -1 then --Filter dead
            local name = get_hf_name(hf)
            local str = toSearch(name)

            if hf.died_year ~= -1 then
                name = {{text=name, pen=COLOR_RED}} --Dead
            elseif not hf.info or not hf.info.whereabouts then
                name = {{text=name, pen=COLOR_YELLOW}} --Deity (usually)
            end
            table.insert(t, {text=name, id=hf.id, search_key=str})
        end
    end
    table.sort(t, function(a, b) return a.search_key < b.search_key end)
    return t
end

local function get_id(first, second) --Try to get a numeric id or -1
    return (first >= 0 and first) or (second >= 0 and second) or -1
end

local function dead_holder(ar) --Return true if has holder and they're dead
    local holder = df.historical_figure.find(get_id(ar.holder_hf, ar.owner_hf))
    return holder and holder.died_year ~= -1
end

local function is_book(ar) --Return true if codex/scroll/quire
    local item = ar.item
    return item._type == df.item_bookst or --We'll ignore slabs, despite legends mode behaviour
        (item._type == df.item_toolst and item:hasToolUse(df.tool_uses.CONTAIN_WRITING))
end

local function build_art_list() --Build alphabetized artifact list
    local t = {}
    for _,ar in ipairs(world.artifacts.all) do
        local dead = dead_holder(ar)
        if (show_dead or not dead) and (show_books or not is_book(ar)) then
            local name = get_art_name(ar)
            local str = toSearch(name)

            if dead then
                name = {{text=name, pen=COLOR_RED}}
            end
            table.insert(t, {text=name, id=ar.id, search_key=str})
        end
    end
    table.sort(t, function(a, b) return a.search_key < b.search_key end)
    return t
end

------------------
-- AdvSelWindow --
------------------

AdvSelWindow = defclass(AdvSelWindow, widgets.Window)
AdvSelWindow.ATTRS{
    frame_title = 'Find Target',
    frame = {w=42, h=24, t=22, r=34},
    resizable = true,
    visible = false,
}

function AdvSelWindow:init()
    self:addviews{
        widgets.TabBar{
            frame = {t=0},
            labels = {
                'Historical Figures',
                'Artifacts',
            },
            on_select = self:callback('swap_tab'),
            get_cur_page = function() return cur_tab end,
        },
        widgets.FilteredList{
            view_id = 'sel_hf_list',
            frame = {t=2, b=2},
            not_found_label = 'No results',
            edit_key = 'CUSTOM_ALT_S',
            on_submit = self:callback('select_entry'),
            visible = false, --Handled in sel_list
        },
        widgets.FilteredList{ --setChoices is too slow, don't reuse HF list
            view_id = 'sel_art_list',
            frame = {t=2, b=2},
            not_found_label = 'No results',
            edit_key = 'CUSTOM_ALT_S',
            on_submit = self:callback('select_entry'),
            visible = false,
        },
        widgets.ToggleHotkeyLabel
        {
            view_id = 'dead_toggle',
            frame = {b=0, l=0, w=17, h=1},
            label = 'Show dead:',
            key = 'CUSTOM_SHIFT_D',
            initial_option = show_dead,
            on_change = self:callback('set_show_dead'),
        },
        widgets.ToggleHotkeyLabel
        {
            view_id = 'book_toggle',
            frame = {b=0, r=0, w=18, h=1},
            label = 'Show books:',
            key = 'CUSTOM_SHIFT_B',
            initial_option = show_books,
            on_change = self:callback('set_show_books'),
            visible = function() return cur_tab ~= 1 end,
        },
    }
end

function AdvSelWindow:get_filter_text() --Get current filter from tab
    if cur_tab == 1 then --HF
        return self.subviews.sel_hf_list:getFilter()
    else --Artifact
        return self.subviews.sel_art_list:getFilter()
    end
end

function AdvSelWindow:swap_tab(idx) --Persist filter and swap list
    if cur_tab ~= idx then
        filter_text = self:get_filter_text()
        cur_tab = idx
        self:sel_list()
    end
end

function AdvSelWindow:sel_list() --Set correct list for tab
    local new, old, build_fn
    if cur_tab == 1 then --HF
        new = self.subviews.sel_hf_list
        old = self.subviews.sel_art_list
        build_fn = build_hf_list
    else --Artifact
        new = self.subviews.sel_art_list
        old = self.subviews.sel_hf_list
        build_fn = build_art_list
    end

    old.visible = false
    new.visible = true
    if not next(new:getChoices()) then --Empty, build list
        new:setChoices(build_fn())
    end
    new:setFilter(filter_text) --Restore filter
    new.edit:setFocus(old.edit.focus) --Inherit search focus
    old.edit:setFocus(false)
end

function AdvSelWindow:select_entry(sel, obj) --Set correct target for tab
    local id = obj and obj.id or -1
    if cur_tab == 1 then --HF
        sel_hf, sel_art = id, -1
    else --Artifact
        sel_hf, sel_art = -1, id
    end
end

function AdvSelWindow:set_show_dead(show) --Set filtering of dead HFs, rebuild list
    show = not not show --To bool
    if show == show_dead then
        return --No change
    end
    show_dead = show
    filter_text = self:get_filter_text()
    self.subviews.sel_hf_list:setChoices()
    self.subviews.sel_art_list:setChoices() --Held by HF
    self:sel_list()
end

function AdvSelWindow:set_show_books(show) --Set filtering of books, rebuild list
    show = not not show
    if show == show_books then
        return
    end
    show_books = show
    filter_text = self:get_filter_text()
    self.subviews.sel_art_list:setChoices()
    self:sel_list()
end

function AdvSelWindow:onInput(keys) --Close only this window
    if keys.LEAVESCREEN or keys._MOUSE_R then
        self.visible = false
        filter_text = self:get_filter_text()
        self.subviews.sel_hf_list:setChoices()
        self.subviews.sel_art_list:setChoices()
        return true
    end
    return self.super.onInput(self, keys)
end

---- Fns for getting adventurer data ----

function global_from_local(pos) --Calc global coords (blocks from world origin) from local map pos
    return pos and {x = world.map.region_x*3 + pos.x//16, y = world.map.region_y*3 + pos.y//16} or nil
end

function get_adv_data() --All the coords we can get
    local adv = dfhack.world.getAdventurer()
    if not adv then --Army exists when unit doesn't
        local army = df.army.find(df.global.adventure.player_army_id)
        if army then --Should always exist if unit doesn't
            return {g_pos = army.pos}
        end
        return nil --Error
    end
    return {g_pos = global_from_local(adv.pos), pos = adv.pos}
end

---- Fns for getting target data ----

local function div(n, d) return n//d, n%d end
--We can get the MLT coords of a CZ from its ID (e.g., hf.info.whereabouts.cz_id)
--The g_pos will represent the center of the 3x3 MLT
--In testing, the HF of interest remained in limbo, but it might be of use to someone
function cz_g_pos(cz_id) --Creation zone center in global coords
    if not cz_id or cz_id < 0 then return nil end
    local w, t, rem = world.world_data.world_width, {}, nil
    t.reg_y, rem = div(cz_id, 16*16*w)
    t.mlt_y, rem = div(rem, 16*w)
    t.reg_x, t.mlt_x = div(rem, 16)
    return {x = (t.reg_x*16 + t.mlt_x)*3+1, y = (t.reg_y*16 + t.mlt_y)*3+1}
end

function site_g_pos(site) --Site center in global coords (blocks from world origin)
    local x, y = site.global_min_x, site.global_min_y
    x, y = (x + (site.global_max_x - x)//2)*3+1, (y + (site.global_max_y - y)//2)*3+1
    return {x = x, y = y}
end

local function apply_site_z(site, g_pos) --Improve Z coord using site
    local pos = g_pos or site_g_pos(site) --Fall back on site center
    pos.z = site.min_depth == site.max_depth and site.min_depth or nil --Single layer site
    return pos --Return new table
end

local function death_at_idx(idx) --Return death location data
    if idx then --Dead
        local event = world.history.events_death[idx]
        return {site = event.site, sr = event.subregion, layer = event.feature_layer}
    end
    return {site = -1, sr = -1, layer = -1} --Alive
end

local death_hfid, death_found_idx, death_last_idx --Cache history.events_death data
function get_death_data(hf) --Try to get death location data
    if hf.died_year == -1 then --Alive (or undead)
        return death_at_idx()
    elseif hf.id ~= death_hfid then --Wrong HF, clear cache
        death_hfid, death_found_idx, death_last_idx = hf.id, nil, nil
    end
    local deaths = world.history.events_death
    local deaths_end = #deaths-1

    if death_last_idx and death_last_idx == deaths_end then --No new entries
        return death_at_idx(death_found_idx) --Use cached death
    end
    death_last_idx = death_last_idx or 0 --First time search entire vector

    for i=deaths_end, death_last_idx, -1 do --Iterate new entries backwards
        local event = deaths[i]
        if event._type == df.history_event_hist_figure_diedst then
            if event.victim_hf == hf.id then
                death_found_idx = i --Cache HF's most recent death
                break
            end
        elseif event._type == df.history_event_hist_figure_revivest then
            if event.histfig == hf.id then --Just in case died_year check failed somehow
                death_found_idx = nil --Clear death state
                break
            end
        end
    end
    death_last_idx = deaths_end --Cache latest index
    return death_at_idx(death_found_idx)
end

local function get_whereabouts(hf) --Return state profile data
    local w = hf and hf.info and hf.info.whereabouts
    if w then
        local g_pos = w.abs_smm_x >= 0 and {x = w.abs_smm_x, y = w.abs_smm_y} or nil
        return {site = w.site_id, sr = w.subregion_id, layer = w.feature_layer_id, army = w.army_id, g_pos = g_pos}
    end
    return {site = -1, sr = -1, layer = -1, army = -1}
end

function get_hf_data(hf) --Locational data and coords
    if not hf then --No target
        return nil
    end

    local where = get_whereabouts(hf)
    for _,unit in ipairs(world.units.active) do
        if unit.id == hf.unit_id then --Unit is loaded and active (i.e., player not traveling)
            local pos = xyz2pos(dfhack.units.getPosition(unit))
            pos = pos.x >= 0 and pos or nil --Avoid bad coords
            local g_pos = global_from_local(pos) or where.g_pos
            return {loc_type = LType.Local, g_pos = g_pos, pos = pos}
        end
    end
    local death = get_death_data(hf)

    local site = df.world_site.find(get_id(where.site, death.site))
    if site then --Site
        return {loc_type = LType.Site, site = site, g_pos = apply_site_z(site, where.g_pos)}
    end

    local sr = df.world_region.find(get_id(where.sr, death.sr))
    if sr then --Surface biome
        if where.g_pos then
            where.g_pos.z = 0 --Must be surface
        end
        return {loc_type = LType.Wild, sr = sr, g_pos = where.g_pos}
    end

    local layer = df.world_underground_region.find(get_id(where.layer, death.layer))
    if layer then --Cavern layer
        if where.g_pos then
            where.g_pos.z = layer.layer_depth
        end
        return {loc_type = LType.Under, g_pos = where.g_pos}
    end

    local army = df.army.find(where.army)
    if army then --Traveling
        return {loc_type = LType.Army, g_pos = army.pos}
    end

    if #hf.site_links > 0 then --Try to grab site from links
        local site = df.world_site.find(hf.site_links[#hf.site_links-1].site) --Only try last link
        if site and utils.binsearch(site.populace.nemesis, hf.nemesis_id) then --HF is present
            return {loc_type = LType.Site, site = site, g_pos = apply_site_z(site, where.g_pos)}
        end
    end
    --We'd try cz_g_pos here if it actually helped
    return {loc_type = LType.None, g_pos = where.g_pos} --Probably in limbo
end

function get_art_data(ar) --Locational data and coords
    if not ar then --No target
        return nil
    end
    local holder = findHF(get_id(ar.holder_hf, ar.owner_hf))
    local data = get_hf_data(holder) or {loc_type = LType.None}
    data.holder = holder

    local g_pos = ar.abs_tile_x >= 0 and {x = ar.abs_tile_x//16, y = ar.abs_tile_y//16} or nil

    for _,item in ipairs(world.items.other.ANY_ARTIFACT) do
        if item == ar.item then --Item is nearby if categorized
            local pos = xyz2pos(dfhack.items.getPosition(item))
            pos = pos.x >= 0 and pos or nil --Avoid bad coords
            g_pos = global_from_local(pos) or g_pos
            return {loc_type = LType.Local, holder = holder, g_pos = g_pos, pos = pos}
        end
    end

    local site = df.world_site.find(get_id(ar.site, ar.storage_site))
    if site then --Site
        return {loc_type = LType.Site, site = site, holder = holder, g_pos = apply_site_z(site, g_pos)}
    end

    if data.loc_type ~= LType.None then --Inherit from holder (seems lower priority than site)
        return data
    end

    local sr = df.world_region.find(get_id(ar.subregion, ar.loss_region))
    if sr then --Surface biome
        if g_pos then
            g_pos.z = 0 --Must be surface
        end
        return {loc_type = LType.Wild, holder = holder, sr = sr, g_pos = g_pos}
    end

    local layer = df.world_underground_region.find(get_id(ar.feature_layer, ar.last_layer))
    if layer then --Cavern layer
        if g_pos then
            g_pos.z = layer.layer_depth
        end
        return {loc_type = LType.Under, holder = holder, g_pos = g_pos}
    end

    data.g_pos = data.g_pos or g_pos or nil --Try our own if no holder g_pos
    return data --Probably in limbo
end

---- Fns for adventurer info panel ----

local compass_dir = {
    'E','ENE','NE','NNE',
    'N','NNW','NW','WNW',
    'W','WSW','SW','SSW',
    'S','SSE','SE','ESE',
}
local compass_pointer = { --Same chars as movement indicators
    '>',string.char(191),string.char(191),string.char(191),
    '^',string.char(218),string.char(218),string.char(218),
    '<',string.char(192),string.char(192),string.char(192),
    'v',string.char(217),string.char(217),string.char(217),
}

local idx_div_two_pi = 16/(2*math.pi) --16 indices / 2*Pi radians
function compass(dx, dy) --Handy compass strings
    if dx*dx + dy*dy == 0 then --On target
      return '***', string.char(249) --Char 249 is centered dot
    end
    local angle = math.atan(-dy, dx) --North is -Y
    local index = math.floor(angle*idx_div_two_pi + 16.5)%16 --0.5 helps rounding
    return compass_dir[index + 1], compass_pointer[index + 1]
end

local function insert_text(t, text) --Insert newline before text
    if text and text ~= '' then
        table.insert(t, NEWLINE)
        table.insert(t, text)
    end
end

local function relative_text(t, adv_data, target_data) --Add relative coords and compass
    if not target_data then --No target
        return
    end
    if target_data.pos and adv_data.pos then --Use local
        local dx = target_data.pos.x - adv_data.pos.x
        local dy = target_data.pos.y - adv_data.pos.y
        local dir, point = compass(dx, dy)
        table.insert(t, NEWLINE) --Improve visibility
        insert_text(t, 'Target (local):')
        insert_text(t, point..' '..dir)
        insert_text(t, ('X%+d Y%+d Z%+d'):format(dx, dy, target_data.pos.z - adv_data.pos.z))
    elseif target_data.g_pos and adv_data.g_pos then --Use global
        local dx = target_data.g_pos.x - adv_data.g_pos.x
        local dy = target_data.g_pos.y - adv_data.g_pos.y
        local dir, point = compass(dx, dy)
        table.insert(t, NEWLINE)
        insert_text(t, {text='Target (global):', pen=COLOR_GREY})
        insert_text(t, {text=point..' '..dir, pen=COLOR_GREY})

        local str = ('X%+d Y%+d'):format(dx, dy)
        if target_data.g_pos.z and adv_data.g_pos.z then --Use Z if we have it
            str = str..(' Z%+d'):format(adv_data.g_pos.z - target_data.g_pos.z) --Negate because it's depth
        end
        insert_text(t, {text=str, pen=COLOR_GREY})
    end --else insufficient data
end

local function pos_text(t, g_pos, pos) --Add available coords
    if g_pos then
        local str = g_pos.z and (' Z'..-g_pos.z) or '' --Use Z if we have it, negate because it's depth
        insert_text(t, {text='Global: X'..g_pos.x..' Y'..g_pos.y..str, pen=COLOR_GREY})
    else --Keep compass in consistent spot
        table.insert(t, NEWLINE)
    end
    if pos then
        insert_text(t, ('Local: X%d Y%d Z%d'):format(pos.x, pos.y, pos.z))
    else
        table.insert(t, NEWLINE)
    end
end

local function adv_text(adv_data, target_data) --Text for adv info panel
    if not adv_data then
        return 'Error'
    end
    local t = {'You'} --You, global, local, relative
    pos_text(t, adv_data.g_pos, adv_data.pos)

    relative_text(t, adv_data, target_data)
    return t
end

---- Fns for target info panel ----

local function insert_name_text(t, name) --HF or artifact name; Return true if both lines
    local str = transName(name, false)
    if str == '' then
        table.insert(t, 'Unnamed')
    else --Both native and translation
        table.insert(t, str) --Native
        local t_name = transName(name, true)
        if str ~= t_name then --Don't repeat
            insert_text(t, '"'..t_name..'"')
            return true
        end
    end
end

local function hf_text(hf, target_data) --HF text for target info panel
    if not hf or not target_data then --No target
        return ''
    end
    local t = {} --Native, [translated], race, alive, location, global, local

    local both_lines = insert_name_text(t, hf.name)
    local str = get_race_name(hf)
    insert_text(t, str ~= '' and str or 'Force')
    if not both_lines then --Consistent spacing
        table.insert(t, NEWLINE)
    end

    local eternal --Can't reasonably die
    if hf.died_year ~= -1 then
        insert_text(t, {text='DEAD', pen=COLOR_RED})
    elseif hf.old_year == -1 and target_data.loc_type == LType.None then
        eternal = true --In limbo and can't reasonably die
        insert_text(t, {text='ETERNAL', pen=COLOR_LIGHTBLUE})
    else
        insert_text(t, {text='ALIVE', pen=COLOR_LIGHTGREEN})
    end

    if target_data.loc_type == LType.None then --Everywhere or nowhere
        if eternal then
            insert_text(t, {text='Transcendent', pen=COLOR_YELLOW})
        else
            insert_text(t, {text='Missing', pen=COLOR_MAGENTA})
        end
    else --Physical location
        if target_data.loc_type == LType.Local then
            insert_text(t, 'Nearby')
        elseif target_data.loc_type == LType.Site then
            insert_text(t, {text='At '..transName(target_data.site.name, true), pen=COLOR_LIGHTBLUE})
        elseif target_data.loc_type == LType.Army then
            insert_text(t, {text='Traveling', pen=COLOR_LIGHTBLUE})
        elseif target_data.loc_type == LType.Wild then
            insert_text(t, {text='Wilderness ('..transName(target_data.sr.name, true)..')', pen=COLOR_LIGHTRED})
        elseif target_data.loc_type == LType.Under then
            insert_text(t, {text='Underground', pen=COLOR_LIGHTRED})
        else --Undefined loc_type
            insert_text(t, {text='Error', pen=COLOR_MAGENTA})
        end
    end
    pos_text(t, target_data.g_pos, target_data.pos)
    return t
end

local function art_text(art, target_data) --Artifact text for target info panel
    if not art or not target_data then --No target
        return ''
    end
    local t = {} --Native, [translated], item_type, [held,] location, global, local

    local both_lines = insert_name_text(t, art.name)
    insert_text(t, dfhack.items.getDescription(art.item, 1, true))
    if not both_lines then --Consistent spacing
        table.insert(t, NEWLINE)
    end

    if target_data.holder then
        local str = 'Held by '..transName(target_data.holder.name, false)
        insert_text(t, {text=str, pen=(target_data.holder.died_year == -1 and COLOR_LIGHTGREEN or COLOR_RED)})
    else --Consistent spacing
        table.insert(t, NEWLINE)
    end

    if target_data.loc_type == LType.None then
        insert_text(t, {text='Missing', pen=COLOR_MAGENTA})
    elseif target_data.loc_type == LType.Local then
        insert_text(t, 'Nearby')
    elseif target_data.loc_type == LType.Site then
        insert_text(t, {text='At '..transName(target_data.site.name, true), pen=COLOR_LIGHTBLUE})
    elseif target_data.loc_type == LType.Army then
        insert_text(t, {text='Traveling', pen=COLOR_LIGHTBLUE})
    elseif target_data.loc_type == LType.Wild then
        insert_text(t, {text='Wilderness ('..transName(target_data.sr.name, true)..')', pen=COLOR_LIGHTRED})
    elseif target_data.loc_type == LType.Under then
        insert_text(t, {text='Underground', pen=COLOR_LIGHTRED})
    else --Undefined loc_type
        insert_text(t, {text='Error', pen=COLOR_MAGENTA})
    end
    pos_text(t, target_data.g_pos, target_data.pos)
    return t
end

-------------------
-- AdvFindWindow --
-------------------

AdvFindWindow = defclass(AdvFindWindow, widgets.Window)
AdvFindWindow.ATTRS{
    frame_title = 'Finder',
    frame = {w=30, h=24, t=22, r=2},
    resizable = true,
}

function AdvFindWindow:init()
    self:addviews{
        widgets.Panel{
            view_id = 'adv_panel',
            frame = {t=1, h=9},
            frame_style = gui.FRAME_INTERIOR,
            subviews = {
                widgets.Label{
                    view_id = 'adv_label',
                    text = '',
                    frame = {t=0},
                },
            },
        },
        widgets.Panel{
            view_id = 'target_panel',
            frame = {t=11},
            frame_style = gui.FRAME_INTERIOR,
            subviews = {
                widgets.Label{
                    view_id = 'target_label',
                    text = '',
                    frame = {t=0},
                },
            },
        },
        widgets.ConfigureButton{
            frame = {t=0, r=0},
            on_click = function()
                local sel_window = view.subviews[2] --AdvSelWindow
                sel_window.visible = true
                sel_window:sel_list()
            end,
        }
    }
end

local function set_title(self) --Display target ID in title
    if debug_id then
        local id = get_id(sel_hf, sel_art)
        self.frame_title = 'Finder'..(id ~= -1 and ' (#'..id..')' or '')
    else
        self.frame_title = 'Finder'
    end
end

function AdvFindWindow:onRenderFrame(dc, rect)
    if not dfhack.world.isAdventureMode() then --Could be advfort, etc.
        view:dismiss()
        print('gui/adv-finder: lost adv mode, dismissing view')
    end
    self.super.onRenderFrame(self, dc, rect)

    local adv_panel = self.subviews.adv_panel
    local target_panel = self.subviews.target_panel

    local target_data
    if sel_hf >= 0 then --HF
        local target_hf = findHF(sel_hf)
        target_data = get_hf_data(target_hf)
        target_panel.subviews.target_label:setText(hf_text(target_hf, target_data))
    elseif sel_art >= 0 then --Artifact
        local target_art = df.artifact_record.find(sel_art)
        target_data = get_art_data(target_art)
        target_panel.subviews.target_label:setText(art_text(target_art, target_data))
    else --None
        target_panel.subviews.target_label:setText()
    end
    adv_panel.subviews.adv_label:setText(adv_text(get_adv_data(), target_data))

    adv_panel:updateLayout()
    target_panel:updateLayout()
    set_title(self)
end

-------------------
-- AdvFindScreen --
-------------------

AdvFindScreen = defclass(AdvFindScreen, gui.ZScreen)
AdvFindScreen.ATTRS{
    focus_path = 'advfinder',
}

function AdvFindScreen:init()
    self:addviews{AdvFindWindow{}, AdvSelWindow{}}
end

function AdvFindScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

if not dfhack.world.isAdventureMode() then
    qerror('Adventure mode only!')
end

dfhack.onStateChange['adv-finder'] = function(sc)
    if sc == SC_WORLD_UNLOADED then --Data is world-specific
        sel_hf = -1 --Invalidate IDs
        sel_art = -1
        filter_text = nil --Probably unwanted
        cur_tab = 1 --Reset to first tab, but keep other settings
        print('gui/adv-finder: cleared target')
        dfhack.onStateChange['adv-finder'] = nil --Do once
    end
end

argparse.processArgsGetopt({...}, {
    {'h', 'histfig', handler = function(arg)
        sel_hf = math.tointeger(arg) or -1
        sel_art = -1
    end, hasArg = true},
    {'a', 'artifact', handler = function(arg)
        sel_art = math.tointeger(arg) or -1
        sel_hf = -1
    end, hasArg = true},
    {'d', 'debug', handler = function() debug_id = true end},
})

view = view and view:raise() or AdvFindScreen{}:show()

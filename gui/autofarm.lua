-- A GUI front-end for autofarm
--@ module = true
--[====[
gui/autofarm
============
Graphical interface for the `autofarm` plugin. It allows you to view your farm
plot crop allocation and change target crop thresholds. It also shows you useful
related information, such as the number of seeds and plants of each type you
have on hand and whether the crops that you are trying to plant can be planted
in your map biomes.
]====]

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

-- persist details panel display options between script invocations
show_unavailable = show_unavailable or false
show_unplantable = show_unplantable or false

--------------------------------
-- Plugin API mocks
--------------------------------

-- load the real plugin API if we can and let it override our mocks
local af = {}
dfhack.pcall(function() af = require('plugins.autofarm') end)

local mock_settings = {
        manage_aboveground_crops=true, -- boolean
        manage_underground_crops=true, -- boolean
        exclude_farm_plots={},  -- set<id> (i.e. map of building id to true)
        default_threshold=50,
        thresholds={HELMET_PLUMP=150}, -- map of plant ids to custom thresholds
    }

-- returns currently active settings
af.get_settings = af.get_settings or function() return mock_settings end

-- sets active settings
af.set_settings = af.set_settings or function(settings)
        mock_settings = copyall(settings)
        mock_settings.exclude_farm_plots = copyall(settings.exclude_farm_plots)
        mock_settings.thresholds = copyall(settings.thresholds)
    end

-- returns whether autofarm considers the plot to be aboveground
af.is_plot_aboveground = af.is_plot_aboveground or function(bld)
        return not dfhack.maps.getTileFlags(
                xyz2pos(bld.x1, bld.y1, bld.z)).subterranean
    end

-- returns a list with current metrics for all plant types in the order that the
-- UI should display them. the percent_map_plantable field is the percentage of
-- the map that has a biome that allows the crop to be grown.
af.get_plant_data = af.get_plant_data or function()
        return {
            {name='Plump Helmets', id='HELMET_PLUMP', num_plants=350,
             num_seeds=40, percent_map_plantable=75},
            {name='Pig Tails', id='TAIL_PIG', num_plants=20,
             num_seeds=5, percent_map_plantable=100},
            {name='Rope Weed', id='WEED_ROPE', num_plants=2000,
             num_seeds=5000, percent_map_plantable=0},
            {name='Evil All of Root', id='ROOT_OF_ALL_EVIL', num_plants=0,
             num_seeds=0, percent_map_plantable=0},
        }
    end

-- returns the allocations per crop type that would happen with the given settings
af.dry_run = af.dry_run or function(settings)
        return {
            HELMET_PLUMP={plots=4, tiles=20},
            TAIL_PIG={plots=1, tiles=2},
        }
    end

--------------------------------
-- Details screen
--------------------------------

AutofarmDetails = defclass(AutofarmDetails, gui.FramedScreen)
AutofarmDetails.ATTRS{
    focus_path='autofarm/details',
    frame_style=gui.GREY_LINE_FRAME,
    frame_inset={l=1, r=1, b=1},
    frame_title='Autofarm Crop Threshold Details',
}

local function get_headers()
    return {
        'Plant name', -- e.g. 'Plump Helmet'
        'Plant ID',   -- e.g. 'HELMET_PLUMP'
        'Threshold',  -- custom threshold or nil
        'Plants',     -- plants on hand
        'Seeds',      -- seeds on hand
        'Biome',     -- percent of map with biomes that can grow this crop
        'Plots',      -- farm plots allocated to this plant now / after update
        'Tiles',      -- plot tiles allocated to this plant now / after update
    }
end

local function get_fields(plant_data_elem, threshold, cur_alloc, next_alloc)
    cur_alloc = cur_alloc or {}
    next_alloc = next_alloc or {}

    return {
        plant_data_elem.name,
        plant_data_elem.id,
        tostring(threshold or 'Default'),
        tostring(plant_data_elem.num_plants),
        tostring(plant_data_elem.num_seeds),
        tostring(plant_data_elem.percent_map_plantable) .. '%',
        ('%d -> %d'):format((cur_alloc.plots or 0), (next_alloc.plots or 0)),
        ('%d -> %d'):format((cur_alloc.tiles or 0), (next_alloc.tiles or 0)),
    }
end

local function update_max_widths(max_field_widths, fields)
    for i,f in ipairs(fields) do
        max_field_widths[i] = math.max(max_field_widths[i] or 0, #f)
    end
end

local function get_text_line(widths, fields)
    local text = {}
    for i,w in ipairs(widths) do
        table.insert(text, {text=fields[i], width=w})
        table.insert(text, '  ')
    end
    text[#text] = nil -- remove the last spacer
    return {text=text, plant_id=fields.plant_id}
end

local function digits_only(ch)
    return ch:match('%d')
end

function AutofarmDetails:init(args)
    self.settings = af.get_settings()
    self.plant_data = args.plant_data
    self.cur_allocs = args.cur_allocs

    self:addviews{
        widgets.Label{
            frame={t=0, l=1},
            text='Filters:',
            text_pen=COLOR_GREY},
        widgets.ToggleHotkeyLabel{
            frame={t=0, l=11},
            label='Show unavailable',
            key='CUSTOM_ALT_A',
            initial_option=show_unavailable,
            text_pen=COLOR_GREY,
            on_change=self:callback('update_setting', 'show_unavailable')},
        widgets.ToggleHotkeyLabel{
            frame={t=0, l=41},
            label='Show unplantable',
            key='CUSTOM_ALT_P',
            initial_option=show_unplantable,
            text_pen=COLOR_GREY,
            on_change=self:callback('update_setting', 'show_unplantable')},
        widgets.EditField{
            view_id='default_threshold',
            frame={t=1, l=1},
            key='CUSTOM_D',
            label='Default threshold',
            modal=true,
            text=tostring(self.settings.default_threshold),
            on_char=digits_only,
            on_submit=self:callback('update_default_threshold')},
        widgets.Label{
            view_id='header',
            frame={t=3}},
        widgets.List{
            view_id='list',
            frame={t=5},
            on_submit=self:callback('edit_threshold')},
        widgets.Label{
            frame={b=0, l=1},
            text='Selected threshold:',
            text_pen=COLOR_GREY},
        widgets.HotkeyLabel{
            frame={b=0, l=22},
            label='Edit',
            key='SELECT'},
        widgets.HotkeyLabel{
            frame={b=0, l=35},
            label='Clear',
            key='CUSTOM_R',
            on_activate=self:callback('clear_threshold')},
        widgets.HotkeyLabel{
            frame={b=0, l=45},
            label='Copy',
            key='CUSTOM_C',
            on_activate=self:callback('copy_threshold')},
        widgets.HotkeyLabel{
            frame={b=0, l=54},
            label='Paste',
            key='CUSTOM_P',
            enabled=function() return self.clipboard end,
            on_activate=self:callback('paste_threshold')},
        widgets.Label{
            view_id='clipboard',
            frame={b=0, l=62},
            text={': ', {text=function() return self.clipboard end}},
            visible=false},
        widgets.EditField{
            view_id='threshold',
            frame={}, -- we'll make this appear where we need it to
            visible=false,
            modal=true,
            on_char=digits_only,
            on_submit=self:callback('update_threshold'),
            on_cancel=self:callback('cancel_edit_threshold')},
    }

    self:refresh(true)
end

function AutofarmDetails:getWantedFrameSize()
    local list = self.subviews.list
    return math.max(70, list:getContentWidth()),
            math.max(20, list:getContentHeight())
end

function AutofarmDetails:onDismiss()
    af.set_settings(self.settings)
end

function AutofarmDetails:set_list_choices(max_field_widths)
    local next_allocs = af.dry_run(self.settings)

    local lines = {}
    for _,v in ipairs(self.plant_data) do
        if (not show_unavailable and v.num_seeds == 0) or
                (not show_unplantable and v.percent_map_plantable == 0) then
            goto continue
        end
        local fields = get_fields(v, self.settings.thresholds[v.id],
                                  self.cur_allocs[v.id], next_allocs[v.id])
        update_max_widths(max_field_widths, fields)
        fields.plant_id = v.id
        table.insert(lines, fields)
        ::continue::
    end

    local list = self.subviews.list
    local _, obj = list:getSelected()
    local selected_plant_id = (obj or {}).plant_id
    local list_idx = nil
    local choices = {}
    for i,v in ipairs(lines) do
        table.insert(choices, get_text_line(max_field_widths, v))
        if v.plant_id == selected_plant_id then
            list_idx = i
        end
    end
    self.subviews.list:setChoices(choices, list_idx)
end

function AutofarmDetails:refresh(is_init)
    local headers = get_headers()
    local max_field_widths = {}
    update_max_widths(max_field_widths, headers)

    -- updates max_field_widths
    self:set_list_choices(max_field_widths)

    self.subviews.header:setText(get_text_line(max_field_widths, headers).text)

    -- align the threshold edit box with the on-screen thresholds
    local threshold = self.subviews.threshold
    threshold.frame.l = max_field_widths[1] + 2 + max_field_widths[2] + 2
    threshold.frame.w = max_field_widths[3]

    if not is_init then self:updateLayout() end
end

function AutofarmDetails:update_setting(setting, value)
    _ENV[setting] = value
    self:refresh()
end

function AutofarmDetails:update_default_threshold(val)
    val = tonumber(val)
    if not val then
        val = self.settings.default_threshold
        self.subviews.default_threshold.text = tostring(val)
    end
    self.settings.default_threshold = val
    self:refresh()
end

function AutofarmDetails:edit_threshold(idx, obj)
    self.editing_threshold_id = obj.plant_id

    -- find the location of the threshold text on the screen
    local list = self.subviews.list
    local idx, obj = list:getSelected()
    if not obj then return end
    local y_offset = (idx - list.page_top) * list.row_height

    -- position the edit widget over the threshold text, initialize with the
    -- current threshold, and show
    local edit = self.subviews.threshold
    edit.frame.t = list.frame.t + y_offset
    edit.text = tostring(self.settings.thresholds[obj.plant_id] or '')
    edit.visible = true
    edit:setFocus(true)
    self:updateLayout()
end

function AutofarmDetails:cancel_edit_threshold()
    self.subviews.threshold.visible = false
    self.editing_threshold_id = nil
end

function AutofarmDetails:update_threshold(val)
    val = tonumber(val)
    self.settings.thresholds[self.editing_threshold_id] = val
    self:cancel_edit_threshold()
    self:refresh()
end

function AutofarmDetails:clear_threshold()
    local _, obj = self.subviews.list:getSelected()
    self.settings.thresholds[obj.plant_id] = nil
    self:refresh()
end

function AutofarmDetails:copy_threshold()
    local _, obj = self.subviews.list:getSelected()
    self.clipboard = self.settings.thresholds[obj.plant_id]
    self.subviews.clipboard.visible = self.clipboard
end

function AutofarmDetails:paste_threshold()
    local _, obj = self.subviews.list:getSelected()
    self.settings.thresholds[obj.plant_id] = self.clipboard
    self:refresh()
end

function AutofarmDetails:onInput(keys)
    if self:inputToSubviews(keys) then
        return true
    end

    if keys.LEAVESCREEN then
        self:dismiss()
    end
end

--------------------------------
-- Main UI
--------------------------------

local function is_tile_aboveground(pos)
    local flags = dfhack.maps.getTileFlags(pos)
    return not flags.subterranean
end

local function is_tile_managed(settings, bld, aboveground, pos)
    if aboveground and not settings.manage_aboveground_crops then return false end
    if not aboveground and not settings.manage_underground_crops then return false end
    if aboveground ~= is_tile_aboveground(pos) then return false end
    return not settings.exclude_farm_plots[bld.id]
end

local function is_in_extent(bld, x, y)
    local extents = bld.room.extents
    if not extents then return true end -- farm plot is solid
    local yoff = (y - bld.y1) * (bld.x2 - bld.x1 + 1)
    local xoff = x - bld.x1
    return extents[yoff+xoff] == 1
end

-- scan through buildings and build farm plot metadata for the display
local function get_plot_data(settings)
    local season = df.global.cur_season
    local plots = df.global.world.buildings.other[
            df.buildings_other_id.FARM_PLOT]

    local num_managed_plots, total_plots = 0, 0
    local num_managed_tiles, total_tiles = 0, 0
    local plot_map = {} -- coordinate map for managed/unmanaged plot tiles
    local plant_allocs = {} -- allocation metadata for each plant type

    for _,bld in ipairs(plots) do
        if bld:getBuildStage() ~= bld:getMaxBuildStage() then
            -- ignore unbuilt farms
            goto plot_continue
        end
        local plot_managed = false
        local aboveground = af.is_plot_aboveground(bld)
        local plot_tiles, managed_plot_tiles = 0, 0
        for x=bld.x1,bld.x2 do for y=bld.y1,bld.y2 do
            if not is_in_extent(bld, x, y) then goto tile_continue end
            local zlevel = ensure_key(plot_map, bld.z)
            local bounds = ensure_key(zlevel,'bounds',{x1=x, x2=x, y1=y, y2=y})
            local row = ensure_key(zlevel, y)
            local managed = is_tile_managed(settings, bld, aboveground,
                                            xyz2pos(x, y, bld.z))
            row[x] = {managed=managed, id=bld.id}
            if managed then
                plot_managed = true
                managed_plot_tiles = managed_plot_tiles + 1
            end
            plot_tiles = plot_tiles + 1
            bounds.x1 = math.min(bounds.x1, x)
            bounds.x2 = math.max(bounds.x2, x)
            bounds.y1 = math.min(bounds.y1, y)
            bounds.y2 = math.max(bounds.y2, y)
            ::tile_continue::
        end end
        local plant_alloc = ensure_key(plant_allocs, bld.plant_id[season])
        ensure_key(plant_alloc, 'plots', 0)
        ensure_key(plant_alloc, 'tiles', 0)
        plant_alloc.plots = plant_alloc.plots + 1
        plant_alloc.tiles = plant_alloc.tiles + managed_plot_tiles
        if plot_managed then
            num_managed_tiles = num_managed_tiles + managed_plot_tiles
            num_managed_plots = num_managed_plots + 1
        end
        total_tiles = total_tiles + plot_tiles
        total_plots = total_plots + 1
        ::plot_continue::
    end
    return {
        num_managed_plots=num_managed_plots,
        total_plots=total_plots,
        num_managed_tiles=num_managed_tiles,
        total_tiles=total_tiles,
        plot_map=plot_map,
        plant_allocs=plant_allocs,
    }
end

AutofarmUI = defclass(AutofarmUI, guidm.MenuOverlay)
AutofarmUI.ATTRS{
    frame_inset=1,
    focus_path='autofarm',
    sidebar_mode=df.ui_sidebar_mode.Default,
}

function AutofarmUI:init()
    self:refresh_data()

    local settings = af.get_settings()
    local plant_data = af.get_plant_data()

    local num_seeds, num_plants = 0, 0
    for _,p in ipairs(plant_data) do
        if p.percent_map_plantable > 0 then
            num_seeds = num_seeds + p.num_seeds
            num_plants = num_plants + p.num_plants
        end
    end

    local subviews = {
        widgets.Label{text='Autofarm'},
        widgets.WrappedLabel{
            text_to_wrap=self:callback('get_help_text'),
            text_pen=COLOR_GREY},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.Label{text={'Managed plots: ',
                    {text=function() return self.data.num_managed_plots end},
                    ' of ',
                    {text=function() return self.data.total_plots end}}},
            widgets.Label{text={'Managed tiles: ',
                    {text=function() return self.data.num_managed_tiles end},
                    ' of ',
                    {text=function() return self.data.total_tiles end}}}
            }},
        widgets.ToggleHotkeyLabel{
            key='CUSTOM_SHIFT_A',
            label='Manage aboveground',
            initial_option=settings.manage_aboveground_crops,
            on_change=self:callback('set_setting_flag',
                                    'manage_aboveground_crops')},
        widgets.ToggleHotkeyLabel{
            key='CUSTOM_SHIFT_U',
            label='Manage underground',
            initial_option=settings.manage_underground_crops,
            on_change=self:callback('set_setting_flag',
                                    'manage_underground_crops')},
        widgets.HotkeyLabel{
            key='CUSTOM_X',
            label='Select plots to exclude',
            on_activate=self:callback('start_selection', 'exclude')},
        widgets.HotkeyLabel{
            key='CUSTOM_SHIFT_X',
            label='Select plots to include',
            on_activate=self:callback('start_selection', 'include')},
        widgets.ResizingPanel{autoarrange_subviews=true, subviews={
            widgets.Label{text={'Total plantable seeds: ' .. num_seeds}},
            widgets.Label{text={'Total growable plants: ' .. num_plants}}
            }},
        widgets.HotkeyLabel{
            key='CUSTOM_T',
            label='Crop threshold details',
            on_activate=function()
                    AutofarmDetails{cur_allocs=self.data.plant_allocs,
                                    plant_data=plant_data}:show()
                end},
        widgets.HotkeyLabel{
            key='LEAVESCREEN',
            label=self:callback('get_back_text'),
            on_activate=self:callback('on_back')}
    }

    self:addviews{widgets.Panel{autoarrange_subviews=true,
                                autoarrange_gap=1,
                                subviews=subviews}}
end

function AutofarmUI:refresh_data(settings)
    self.data = get_plot_data(settings or af.get_settings())
end

function AutofarmUI:do_update(settings)
    af.set_settings(settings)
    self:refresh_data(settings)
end

function AutofarmUI:set_setting_flag(flag, val)
    local settings = af.get_settings()
    settings[flag] = val
    self:do_update(settings)
end

function AutofarmUI:get_help_text()
    if not self.mode then
        return 'Managed farm plots are highlighted in green.' ..
                ' Unmanaged farm plots are highlighted in red.'
    end

    local text = 'Select the '
    if self.mark then
        text = text .. 'second corner'
    else
        text = text .. 'first corner'
    end
    return text .. ' with the cursor or mouse.'
end

function AutofarmUI:get_back_text()
    if self.mode then
        return 'Cancel selection'
    end
    return 'Back'
end

function AutofarmUI:on_back()
    if self.mark then
        self.mark = nil
    elseif self.mode then
        self:cancel_selection()
    else
        self:dismiss()
    end
end

function AutofarmUI:get_bounds(cursor)
    local cursor = cursor or guidm.getCursorPos()
    local mark = self.mark

    return {
        x1=math.min(cursor.x, mark.x),
        x2=math.max(cursor.x, mark.x),
        y1=math.min(cursor.y, mark.y),
        y2=math.max(cursor.y, mark.y),
        z1=math.min(cursor.z, mark.z),
        z2=math.max(cursor.z, mark.z)
    }
end

function AutofarmUI:render_selection_overlay()
    local cursor = guidm.getCursorPos()
    if not cursor or not self.mark or not gui.blink_visible(500) then return end


    local function get_selection_overlay_char(pos, is_cursor)
        if is_cursor then return nil end
        return 'X', self.mode == 'include' and COLOR_GREEN or COLOR_RED
    end

    self:renderMapOverlay(get_selection_overlay_char, self:get_bounds(cursor))
end

function AutofarmUI:render_farm_overlay()
    if not gui.blink_visible(1000) then return end

    local zlevel = self.data.plot_map[df.global.window_z]
    if not zlevel then return end

    local function get_farm_overlay_char(pos, is_cursor)
        if is_cursor then return nil end
        local plot_data = safe_index(zlevel, pos.y, pos.x)
        if plot_data == nil then return nil end
        return 'X', plot_data.managed and COLOR_GREEN or COLOR_RED
    end

    self:renderMapOverlay(get_farm_overlay_char, zlevel.bounds)
end

function AutofarmUI:onRenderBody()
    self:render_farm_overlay()
    self:render_selection_overlay()
end

function AutofarmUI:onInput(keys)
    if self:inputToSubviews(keys) then
        return true
    end

    local pos = nil
    if keys._MOUSE_L then
        local x, y = dfhack.screen.getMousePos()
        if gui.is_in_rect(self.df_layout.map, x, y) then
            pos = xyz2pos(df.global.window_x + x - 1,
                          df.global.window_y + y - 1,
                          df.global.window_z)
            guidm.setCursorPos(pos)
        end
    elseif keys.SELECT then
        pos = guidm.getCursorPos()
    end

    if pos then
        if self.mark then
            self:commit_selection(pos)
        else
            self:set_mark(pos)
        end
        return true
    end

    return self:propagateMoveKeys(keys)
end

function AutofarmUI:start_selection(mode)
    self.mode = mode
    self:updateLayout() -- refresh help text

    -- get a cursor on the screen
    self:sendInputToParent('D_LOOK')
end

function AutofarmUI:set_mark(pos)
    self.mark = pos
    self:updateLayout() -- refresh help text
end

function AutofarmUI:cancel_selection()
    self.mode = nil
    self.mark = nil
    self:updateLayout() -- refresh help text

    -- return to the Default (cursorless) viewscreen
    self:sendInputToParent('LEAVESCREEN')
end

function AutofarmUI:commit_selection()
    -- scan for affected plots
    local plot_map, is_exclude = self.data.plot_map, self.mode == 'exclude'
    local bounds = self:get_bounds()
    local settings = af.get_settings()
    local exclude_map = settings.exclude_farm_plots

    for z=bounds.z1,bounds.z2 do
        for y=bounds.y1,bounds.y2 do
            for x=bounds.x1,bounds.x2 do
                local plot_data = safe_index(plot_map, z, y, x)
                if not plot_data then goto continue end
                exclude_map[plot_data.id] = is_exclude or nil
                ::continue::
            end
        end
    end

    self:do_update(settings)
    self:cancel_selection()
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

AutofarmUI():show()

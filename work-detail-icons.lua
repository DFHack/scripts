--@ module = true

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local info = df.global.game.main_interface.info
local creatures = info.creatures
local labor = info.labor
local unit_selector = df.global.game.main_interface.unit_selector

local location_details = df.global.game.main_interface.location_details
local view_sheets = df.global.game.main_interface.view_sheets

local work_details = df.global.plotinfo.labor_info.work_details

--
-- Icon rendering
--

local icondefs = reqscript('internal/work-detail-icons/icon-definitions')
local vanilla = icondefs.vanilla
local builtin = icondefs.builtin

-- not used yet
local function load_user_icon_png(name)
    if dfhack.filesystem.isfile('dfhack-config/work-detail-icons/' .. name .. '.png') then 
        return dfhack.textures.loadTileset('dfhack-config/work-detail-icons/' .. name .. '.png', 8, 12)
    end
end

-- these process the defs from internal/work-detail-icons/icon-definitions
local function make_ascii_icon_spec(icondef, border, border_h)
    local ch1 = icondef.ch1
    local ch2 = icondef.ch2
    
    local fg1 = icondef.fg1
    local fg2 = icondef.fg2
    local bg1 = icondef.bg1
    local bg2 = icondef.bg2
    local pen1 = {fg=fg1, bg=bg1}
    local pen2 = {fg=fg2, bg=bg2}
    
    border = border or COLOR_WHITE
    border_h = border_h or border
    
    return {
        chars={
            {218, 196, 196, 191},
            {179, ch1, ch2, 179},
            {192, 196, 196, 217},
        },
        pens={
            {border, border, border, border},
            {border,  pen1,   pen2,  border},
            {border, border, border, border},
        },
        pens_hover={
            {border_h, border_h, border_h, border_h},
            {border_h,    pen1,   pen2,    border_h},
            {border_h, border_h, border_h, border_h},
        }
    }
end

local function make_graphic_icon_spec(icondef, border, border_h)
    local spec = make_ascii_icon_spec(icondef, border, border_h)
    if icondef.asset then
        spec.asset = icondef.asset
    elseif icondef.tileset then
        spec.tileset = icondef.tileset
        spec.tileset_stride = icondef.tileset_stride
        spec.tileset_offset = icondef.tileset_offset
    end
    return spec
end

function make_icon_text(icondef, force_ascii, border, border_h)
    icondef = icondef or icondefs.IconDef -- lmao. fallback blank icon
    if force_ascii == true then
        return widgets.makeButtonLabelText(make_ascii_icon_spec(icondef, border, border_h))
    else
        return widgets.makeButtonLabelText(make_graphic_icon_spec(icondef, border, border_h))
    end
end

--
-- IconsOverlay
--

local function get_ulist_rows()
    if dfhack.gui.matchFocusString('dwarfmode/Info/LABOR/WORK_DETAILS') then
        return dfhack.gui.getWidget(labor, 'Tabs', 'Work Details', 'Right panel', 0, 3, 'Unit List', 1)
    elseif dfhack.gui.matchFocusString('dwarfmode/Info/CREATURES/CITIZEN') then
        return dfhack.gui.getWidget(creatures, 'Tabs', 'Citizens', 0, 'Unit List', 1)
    elseif dfhack.gui.matchFocusString('dwarfmode/UnitSelector') then
        return dfhack.gui.getWidget(unit_selector, 'Unit selector', 'Unit List', 1)
    end
end

local function get_icon_group(row_number)
    return dfhack.gui.getWidget(get_ulist_rows(), row_number, 'Occupations/Work Details')
end

local function get_first_icon_group()
    local ulist_rows = get_ulist_rows()
    local rows = dfhack.gui.getWidgetChildren(ulist_rows)
    local max_elem = math.min(#rows, ulist_rows.scroll + ulist_rows.num_visible)
    
    for row_idx = ulist_rows.scroll, max_elem do
        local icon_group = get_icon_group(row_idx)
        if icon_group then return icon_group end
    end
end

local function get_row_unit(row_number)
    -- all unit lists with WD icons in them also contain portraits
    -- while not ideal, this shouldn't cause problems
    return dfhack.gui.getWidget(get_ulist_rows(), row_number, 'Portrait').u
end

-- map of work details by unit ids assigned to them
-- like this: {uid1={wd1, wd2...}, uid2=...}
local function get_wds_by_uid()
    if work_details then
        local wds_by_uid = {}
        for i, wd in ipairs(work_details) do
            for _, uid in ipairs(wd.assigned_units) do
                if not wds_by_uid[uid] then wds_by_uid[uid] = {} end
                table.insert(wds_by_uid[uid], wd)
            end
        end
        return wds_by_uid
    end
end

local function get_unit_by_id(id)
    for _, unit in ipairs(df.global.world.units.active) do
        if unit.id == id then
            return unit
        end
    end
end

local function get_unit_wds(unit)
    local unit_wds = {}
    for i, wd in ipairs(work_details) do
        for _, uid in ipairs(wd.assigned_units) do
            if uid == unit.id then
                table.insert(unit_wds, wd)
            end
        end
    end
    return unit_wds
end

local function get_icon_column_num()
    local column_num = 0
    local wds_by_uid = get_wds_by_uid()
    for _, wds in pairs(wds_by_uid) do
        if column_num < #wds then
            column_num = #wds
        end
    end
    return column_num
end

local function get_wdlist_rows()
    -- interestingly, the scroll_rows widget here is not in children but in `rows`
    if dfhack.gui.getWidget(labor, 'Tabs', 'Work Details', 'Details') then
    return dfhack.gui.getWidget(labor, 'Tabs', 'Work Details', 'Details').rows end
end



IconsOverlay = defclass(IconsOverlay, overlay.OverlayWidget)
IconsOverlay.ATTRS{
    desc='Shows customizable work detail icons over regular ones',
    viewscreens={
        'dwarfmode/Info/LABOR/WORK_DETAILS',
        'dwarfmode/Info/CREATURES/CITIZEN',
        'dwarfmode/UnitSelector',
        
        -- apparently these two do not contain widgets
        -- todo: figure out how to get their positions
        -- 'dwarfmode/LocationDetails',
        -- 'dwarfmode/ViewSheets/UNIT/Labor/WorkDetails',
    },
    -- default_enabled=true,
    fullscreen=true, -- since it's supposed to replace vanilla widgets
    default_pos={x=1, y=1}, -- now we can use absolute positions as offsets
    frame={w=1, h=1},
    version=1,
}

function IconsOverlay:init()
    self:addviews{
        widgets.Panel{
            view_id='icon_columns',
        },
        widgets.List{
            view_id='wd_screen_list',
            row_height=3,
            choices={},
        },
        -- todo: handle LABOR/WORK_DETAILS/Details
    }
end

function IconsOverlay:preUpdateLayout(parent_rect)
    -- fun fact: with enough WDs assigned, an icon group may go beyond the bounds of the info window 
    -- (or even beyond the edge of the screen, taking the checkmark button with it)
    -- so we might as well have the frame take up the whole screen
    local win_w, win_h = dfhack.screen.getWindowSize()
    self.frame = {w=win_w, h=win_h}

    -- set icon list pos to first icon group
    -- and width to account for possible overflow
    local ulist_rows = get_ulist_rows()
    if ulist_rows then
        local first_icon_group = get_first_icon_group()
        if first_icon_group then
            self.subviews.icon_columns.frame = {
                l=first_icon_group.rect.x1,
                t=first_icon_group.rect.y1,
                w=win_w-first_icon_group.rect.x1,
                h=ulist_rows.rect.y2-first_icon_group.rect.y1,
            }
        end
        
        -- this matrix, comprised of several lists, will contain our icons.
        -- this is a very backwards way to do this but i couldn't come up with anything better
        -- since neither label nor list allow for several multiline tokens in one row
        while #self.subviews.icon_columns.subviews <= get_icon_column_num() do
            -- there'll be as many columns as the highest amount of wds assigned to one unit
            -- (+1 to account for occupation icons)
            -- they'll stay until the overlay is re-initialized
            local current_col_n = #self.subviews.icon_columns.subviews
            self.subviews.icon_columns:addviews{
                widgets.List{
                    row_height=3,
                    choices={},
                    frame={
                        w=4,
                        l=(current_col_n)*4,
                        t=0,
                    },
                }
            }
        end
    end
    
    -- once we get the viewsheet list working,
    -- it should probably be merged into this one
    -- since they're mutually exclusive
    -- and both show the exact same seq. of icons
    local wdlist_rows = get_wdlist_rows()
    if wdlist_rows then 
        self.subviews.wd_screen_list.frame = {
            l=wdlist_rows.rect.x1,
            t=wdlist_rows.rect.y1,
            w=4,
            h=wdlist_rows.rect.y2-wdlist_rows.rect.y1,
        }
    end
end

function IconsOverlay:onRenderFrame(dc, rect)
    self:updateLayout()
    
    local ulist_rows = get_ulist_rows()
    if ulist_rows and get_first_icon_group() and not dfhack.gui.matchFocusString('dwarfmode/Info/LABOR/WORK_DETAILS/Details') then
        local rows = dfhack.gui.getWidgetChildren(ulist_rows)
        local scroll = ulist_rows.scroll
        local max_elem = math.min(#rows, scroll + ulist_rows.num_visible - 1)
        
        local columns = self.subviews.icon_columns.subviews
        local buffer_columns = {}
        for col_idx = 1, #columns do
            buffer_columns[col_idx] = {}
        end
        
        for row_idx = scroll, max_elem do
            local row_unit = get_row_unit(row_idx)
            local unit_wds = get_unit_wds(row_unit)
            
            local row_icons = {}
            local skip = {text=''}
            -- temp: change this in order to display a different icon
            local custom_icon = {text=make_icon_text(vanilla.WOODCUTTERS)}
            
            -- the occupation (priest, doctor etc.) icon always comes first
            -- if the unit has one, skip it (insert an empty entry)
            for occ_idx = 1, #row_unit.occupations do table.insert(row_icons, skip) end
            -- place icons where needed
            for wd_idx = 1, #unit_wds do
                table.insert(row_icons, custom_icon)
            end
            -- fill the rest with empty entries
            for empty_idx = #row_icons, #columns do table.insert(row_icons, skip) end
            -- commit row to buffer
            for icon_idx = 1, #columns do table.insert(buffer_columns[icon_idx], row_icons[icon_idx]) end
        end
        
        -- commit buffer to panel
        for col_idx, col in ipairs(columns) do
            col:setChoices(buffer_columns[col_idx])
        end
    else
        -- clear icons so they don't linger if there's nothing to draw
        for _, col in ipairs(self.subviews.icon_columns.subviews) do
            col:setChoices{}
        end
    end
    
    local wdlist_rows = get_wdlist_rows()
    if wdlist_rows and dfhack.gui.matchFocusString('dwarfmode/Info/LABOR/WORK_DETAILS') then 
        local rows = dfhack.gui.getWidgetChildren(wdlist_rows)
        local scroll = wdlist_rows.scroll
        local max_elem = math.min(#rows, scroll + wdlist_rows.num_visible - 1)
        
        local icons = {}
        local custom_icon = {text=make_icon_text(builtin.CYAN)}
        
        for row_idx = scroll, max_elem do
            table.insert(icons, custom_icon)
        end
        
        self.subviews.wd_screen_list:setChoices(icons)
    else
        self.subviews.wd_screen_list:setChoices{}
    end
    
    IconsOverlay.super.onRenderFrame(self, dc, rect)
end

--
-- TooltipOverlay
--

local tooltip_w = 26
local tooltip_h = 19

TooltipOverlay = defclass(TooltipOverlay, overlay.OverlayWidget)
TooltipOverlay.ATTRS{
    desc='Shows the name of a work detail when hovering over its icon in unit lists',
    viewscreens={
        'dwarfmode/Info/LABOR/WORK_DETAILS/Default',
        'dwarfmode/Info/CREATURES/CITIZEN',
        'dwarfmode/UnitSelector',
        -- 'dwarfmode/LocationDetails',
    },
    -- default_enabled=true,
    frame={w=tooltip_w-1, h=tooltip_h-1},
    default_pos={x=-1, y=1},
    version=1,
}

function TooltipOverlay:init()    
    self:addviews{
        widgets.Panel{
            -- tooltip box mimicking the vanilla one
            -- (but with a dfhack signature)
            view_id='tooltip',
            visible=false,
            frame_style=gui.FRAME_BOLD,
            frame={
                w=tooltip_w,
                h=tooltip_h,
                r=-1,
                t=-1,
            },
            subviews={
                widgets.Panel{
                    autoarrange_subviews=true,
                    frame_background=gui.CLEAR_PEN,
                    frame={
                        w=tooltip_w-1,
                        h=tooltip_h-1,
                        l=1,
                        b=1,
                    },
                    subviews={
                        widgets.Label{
                            text={
                                'This creature is', NEWLINE,
                                'assigned to the', NEWLINE,
                                'following work', NEWLINE,
                                'detail:', NEWLINE, NEWLINE,
                            },
                        },
                        widgets.WrappedLabel{
                            view_id='wd_name',
                            frame={w=tooltip_w-1},
                            text_to_wrap='',
                        },
                        widgets.Label{
                            view_id='wd_mode',
                            text='',
                        },
                    },
                },
            },    
        }
    }
end

function TooltipOverlay:onRenderFrame(dc, rect)
    self:updateLayout()
    self.subviews.tooltip.visible = false
    
    local ulist_rows = get_ulist_rows()
    if ulist_rows and get_first_icon_group() then
        -- array of tables containing the following:
        -- icon bounding box, work detail name and restriction mode
        local hover_zones = {}
        
        local rows = dfhack.gui.getWidgetChildren(ulist_rows)
        local scroll = ulist_rows.scroll
        local max_elem = math.min(#rows, scroll + ulist_rows.num_visible - 1)
        
        for row_idx = scroll, max_elem do
            local icon_group = get_icon_group(row_idx)
            if icon_group then
                local row_unit = get_row_unit(row_idx)
                local unit_wds = get_unit_wds(row_unit)
                local icons = dfhack.gui.getWidgetChildren(icon_group)
            
                local start_pos = 1
                local wd_num = 1
                for occ_idx = 1, #row_unit.occupations do start_pos = start_pos + 1 end
                
                for icon_idx = start_pos, #icons do
                    zone = {}
                    zone.rect = icons[icon_idx].rect
                    zone.wd_name = unit_wds[wd_num].name
                    zone.wd_mode = unit_wds[wd_num].flags.mode
                    
                    table.insert(hover_zones, zone)
                    wd_num = wd_num + 1
                end
            end
        end
        
        local mouse_x, mouse_y = dfhack.screen.getMousePos()
        if mouse_x and mouse_y then
            for zone_idx, zone in ipairs(hover_zones) do
                -- check if mouse is inside bounding box
                if ((zone.rect.x1 <= mouse_x) and (mouse_x <= zone.rect.x2) and (zone.rect.y1 <= mouse_y) and (mouse_y <= zone.rect.y2)) then
                    self.subviews.wd_name.text_to_wrap = zone.wd_name
                    -- colors like in unit viewsheet
                    if zone.wd_mode == 1 then
                        self.subviews.wd_mode:setText{NEWLINE, {text='(Everybody does this)', pen=COLOR_GREY}}
                    elseif zone.wd_mode == 2 then
                        self.subviews.wd_mode:setText{NEWLINE, {text='(Nobody does this)', pen=COLOR_RED}}
                    elseif zone.wd_mode == 3 then
                        self.subviews.wd_mode:setText{NEWLINE, {text='(Only selected do this)', pen=COLOR_GREEN}}
                    end
                    self.subviews.tooltip.visible = true
                    break
                end
            end
        end
    end
    
    TooltipOverlay.super.onRenderFrame(self, dc, rect)
end

--
-- CheckboxOverlay
--

-- todo: make an overlay that adds a clone of the assign WD checkbox button
-- whenever it's pushed offscreen by too many wd icons

OVERLAY_WIDGETS = {
    display=IconsOverlay,
    tooltip=TooltipOverlay,
}

--
-- CLI
--

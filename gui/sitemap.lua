--@ module = true

local gui = require('gui')
local utils = require('utils')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local toolbar_textures = (dfhack.textures.loadTileset('hack/data/art/sitemap_toolbar.png', 8,12))

function launch_sitemap()
    dfhack.run_script('gui/sitemap')
end

--
-- Sitemap
--

Sitemap = defclass(Sitemap, widgets.Window)
Sitemap.ATTRS {
    frame_title='Sitemap',
    frame={w=57, r=2, t=18, h=25},
    resizable=true,
    resize_min={w=44, h=20},
    frame_inset={l=1, t=1, r=0, b=0},
}

local function to_title_case(str)
    return dfhack.capitalizeStringWords(dfhack.lowerCp437(str:gsub('_', ' ')))
end

-- also called by gui/rename
function get_location_desc(loc)
    if df.abstract_building_hospitalst:is_instance(loc) then
        return 'Hospital', COLOR_WHITE
    elseif df.abstract_building_inn_tavernst:is_instance(loc) then
        return 'Tavern', COLOR_LIGHTRED
    elseif df.abstract_building_libraryst:is_instance(loc) then
        return 'Library', COLOR_BLUE
    elseif df.abstract_building_guildhallst:is_instance(loc) then
        local prof = df.profession[loc.contents.profession]
        if not prof then return 'Guildhall', COLOR_MAGENTA end
        return ('%s guildhall'):format(to_title_case(prof)), COLOR_MAGENTA
    elseif df.abstract_building_templest:is_instance(loc) then
        local is_deity = loc.deity_type == df.religious_practice_type.WORSHIP_HFID
        local id = loc.deity_data[is_deity and 'Deity' or 'Religion']
        local entity = is_deity and df.historical_figure.find(id) or df.historical_entity.find(id)
        local desc = 'Temple'
        if not entity then return desc, COLOR_YELLOW end
        local name = dfhack.translation.translateName(entity.name, true)
        if #name > 0 then
            desc = ('%s to %s'):format(desc, name)
        end
        return desc, COLOR_YELLOW
    end
    local type_name = df.abstract_building_type[loc:getType()] or 'unknown'
    return to_title_case(type_name), COLOR_GREY
end

local function get_location_label(loc, zones)
    local tokens = {}
    table.insert(tokens, dfhack.translation.translateName(loc.name, true))
    local desc, pen = get_location_desc(loc)
    if desc then
        table.insert(tokens, ' (')
        table.insert(tokens, {
            text=desc,
            pen=pen,
        })
        table.insert(tokens, ')')
    end
    if #zones == 0 then
        if loc.flags.DOES_NOT_EXIST then
            table.insert(tokens, ' [retired]')
        else
            table.insert(tokens, ' [no zone]')
        end
    elseif #zones > 1 then
        table.insert(tokens, (' [%d zones]'):format(#zones))
    end
    return tokens
end

local function get_location_choices(site)
    local choices = {}
    if not site then return choices end
    for _,loc in ipairs(site.buildings) do
        local contents = loc:getContents()
        local zones = contents and contents.building_ids or {}
        table.insert(choices, {
            text=get_location_label(loc, zones),
            data={
                -- clone since an adventurer might wander off the site
                -- and the vector gets deallocated
                zones=utils.clone(zones),
                next_idx=1,
            },
        })
    end
    return choices
end

local function zoom_to_next_zone(_, choice)
    local data = choice.data
    if #data.zones == 0 then return end
    if data.next_idx > #data.zones then data.next_idx = 1 end
    local bld = df.building.find(data.zones[data.next_idx])
    if bld then
        dfhack.gui.revealInDwarfmodeMap(
            xyz2pos(bld.centerx, bld.centery, bld.z), true, true)
    end
    data.next_idx = data.next_idx % #data.zones + 1
end

local function get_affiliation(unit)
    local he = df.historical_entity.find(unit.civ_id)
    if not he then return 'Unknown affiliation' end
    local et_name = dfhack.translation.translateName(he.name, true)
    local et_type = df.historical_entity_type[he.type]:gsub('(%l)(%u)', '%1 %2')
    return ('%s%s %s'):format(#et_name > 0 and et_name or 'Unknown', #et_name > 0 and ',' or '', et_type)
end

local function get_unit_disposition_and_pen_and_affiliation(unit)
    local prefix = unit.flags1.caged and 'caged ' or ''
    if dfhack.units.isDanger(unit) then
        if dfhack.units.isInvader(unit) then
            return prefix..'invader', COLOR_RED, get_affiliation(unit)
        end
        return prefix..'hostile', COLOR_LIGHTRED
    elseif dfhack.units.isFortControlled(unit) then
        return prefix..'fort '..(dfhack.units.isAnimal(unit) and 'animal' or 'member'), COLOR_LIGHTBLUE
    elseif dfhack.units.isWildlife(unit) then
        return prefix..'wildlife', COLOR_GREEN
    elseif dfhack.units.isVisitor(unit) or dfhack.units.isDiplomat(unit) then
        return prefix..'visitor', COLOR_MAGENTA, get_affiliation(unit)
    elseif dfhack.units.isMerchant(unit) or dfhack.units.isForest(unit) then
        return prefix..'merchant'..(dfhack.units.isAnimal(unit) and ' animal' or ''), COLOR_BROWN, get_affiliation(unit)
    end
    return prefix..'friendly', COLOR_LIGHTGREEN
end

local function get_unit_choice_text(unit)
    local disposition, disposition_pen, affiliation = get_unit_disposition_and_pen_and_affiliation(unit)
    return {
        dfhack.units.getReadableName(unit),
        ' (',
        {text=disposition, pen=disposition_pen},
        affiliation and ': ' or '',
        {text=affiliation, pen=COLOR_YELLOW},
        ')',
    }
end

local function get_unit_choices()
    local is_fort = dfhack.world.isFortressMode()
    local choices = {}
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isActive(unit) or
            dfhack.units.isHidden(unit) or
            (is_fort and not dfhack.maps.isTileVisible(dfhack.units.getPosition(unit)))
        then
            goto continue
        end
        table.insert(choices, {
            text=get_unit_choice_text(unit),
            data={
                unit_id=unit.id,
            },
        })
        ::continue::
    end
    return choices
end

local function zoom_to_unit(_, choice)
    local data = choice.data
    local unit = df.unit.find(data.unit_id)
    if not unit then return end
    dfhack.gui.revealInDwarfmodeMap(
        xyz2pos(dfhack.units.getPosition(unit)), true, true)
    return unit.id
end

local function follow_unit(idx, choice)
    local unit_id = zoom_to_unit(idx, choice)
    if not unit_id or not dfhack.world.isFortressMode() then return end
    df.global.plotinfo.follow_item = -1
    df.global.plotinfo.follow_unit = unit_id
    pcall(function()
        -- if spectate is available, add the unit to the follow history
        local spectate = require('plugins.spectate')
        spectate.spectate_addToHistory(unit_id)
    end)
end

local function get_artifact_choices()
    local choices = {}
    for _, item in ipairs(df.global.world.items.other.ANY_ARTIFACT) do
        if item.flags.garbage_collect then goto continue end
        table.insert(choices, {
            text=dfhack.items.getReadableDescription(item),
            data={
                item_id=item.id,
            },
        })
        ::continue::
    end
    return choices
end

local function zoom_to_item(_, choice)
    local data = choice.data
    local item = df.item.find(data.item_id)
    if not item then return end
    dfhack.gui.revealInDwarfmodeMap(
        xyz2pos(dfhack.items.getPosition(item)), true, true)
    return item.id
end

local function follow_item(idx, choice)
    local item_id = zoom_to_item(idx, choice)
    if not item_id or not dfhack.world.isFortressMode() then return end
    df.global.plotinfo.follow_item = item_id
    df.global.plotinfo.follow_unit = -1
end

local function get_bottom_text()
    local text = {
        'Click on a name or hit ', {text='Enter', pen=COLOR_LIGHTGREEN}, ' to zoom to', NEWLINE,
        'the selected target.',
    }

    if not dfhack.world.isFortressMode() then
        table.insert(text, NEWLINE)
        table.insert(text, NEWLINE)
        return text
    end

    table.insert(text, ' Shift-click or')
    table.insert(text, NEWLINE)
    table.insert(text, {text='Shift-Enter', pen=COLOR_LIGHTGREEN})
    table.insert(text, ' to zoom and follow unit/item.')
    return text
end

function Sitemap:init()
    local site = dfhack.world.getCurrentSite() or false
    local location_choices = get_location_choices(site)
    local unit_choices = get_unit_choices()
    local artifact_choices = get_artifact_choices()

    self:addviews{
        widgets.TabBar{
            frame={t=0, l=0},
            labels={
                'Creatures',
                'Locations',
                'Artifacts',
            },
            on_select=function(idx)
                self.subviews.pages:setSelected(idx)
                local _, page = self.subviews.pages:getSelected()
                page.subviews.list.edit:setFocus(true)
            end,
            get_cur_page=function() return self.subviews.pages:getSelected() end,
        },
        widgets.Pages{
            view_id='pages',
            frame={t=3, l=0, b=6, r=0},
            subviews={
                widgets.Panel{
                    subviews={
                        widgets.Label{
                            frame={t=0, l=0},
                            text='Nobody around. Spooky!',
                            text_pen=COLOR_LIGHTRED,
                            visible=#unit_choices == 0,
                        },
                        widgets.FilteredList{
                            view_id='list',
                            on_submit=zoom_to_unit,
                            on_submit2=follow_unit,
                            choices=unit_choices,
                            visible=#unit_choices > 0,
                        },
                    },
                },
                widgets.Panel{
                    subviews={
                        widgets.Label{
                            frame={t=0, l=0},
                            text='Please enter a site to see locations.',
                            text_pen=COLOR_LIGHTRED,
                            visible=not site,
                        },
                        widgets.Label{
                            frame={t=0, l=0},
                            text={
                                'No temples, guildhalls, hospitals, taverns,', NEWLINE,
                                'or libraries found at this site.'
                            },
                            text_pen=COLOR_LIGHTRED,
                            visible=site and #location_choices == 0,
                        },
                        widgets.FilteredList{
                            view_id='list',
                            on_submit=zoom_to_next_zone,
                            on_submit2=zoom_to_next_zone,
                            choices=location_choices,
                            visible=#location_choices > 0,
                        },
                    },
                },
                widgets.Panel{
                    subviews={
                        widgets.Label{
                            frame={t=0, l=0},
                            text='No artifacts around here.',
                            text_pen=COLOR_LIGHTRED,
                            visible=#artifact_choices == 0,
                        },
                        widgets.FilteredList{
                            view_id='list',
                            on_submit=zoom_to_item,
                            on_submit2=follow_item,
                            choices=artifact_choices,
                            visible=#artifact_choices > 0,
                        },
                    },
                },
            },
        },
        widgets.Divider{
            frame={b=4, h=1, l=0, r=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Label{
            frame={b=0, l=0},
            text=get_bottom_text(),
        },
    }
end

--
-- SitemapScreen
--

SitemapScreen = defclass(SitemapScreen, gui.ZScreen)
SitemapScreen.ATTRS {
    focus_path='sitemap',
    pass_movement_keys=true,
}

function SitemapScreen:init()
    self:addviews{Sitemap{}}
end

function SitemapScreen:onDismiss()
    view = nil
end


-- --------------------------------
-- SitemapToolbarOverlay
--

SitemapToolbarOverlay = defclass(SitemapToolbarOverlay, overlay.OverlayWidget)
SitemapToolbarOverlay.ATTRS{
    desc='Adds widgets to the erase interface to open the mass removal tool',
    default_pos={x=35, y=-1},
    default_enabled=true,
    viewscreens={
        'dwarfmode'
    },
    frame={w=28, h=9},
}

function SitemapToolbarOverlay:init()
    local button_chars = {
        {218, 196, 196, 191},
        {179, '-', 'O', 179},
        {192, 196, 196, 217},
    }

    self:addviews{
        widgets.Panel{
            frame={t=0, l=0, w=26, h=5},
            frame_style=gui.FRAME_PANEL,
            frame_background=gui.CLEAR_PEN,
            frame_inset={l=1, r=1},
            visible=function() return not not self.subviews.icon:getMousePos() end,
            subviews={
                widgets.Label{
                    text={
                        'Open the sitemap menu.', NEWLINE,
                        NEWLINE,
                        {text='Hotkey: ', pen=COLOR_GRAY}, {key='CUSTOM_CTRL_G'},
                    },
                },
            },
        },
        widgets.Panel{
            view_id='icon',
            frame={b=0, l=0, w=4, h=3},
            subviews={
                widgets.Label{
                    text=widgets.makeButtonLabelText{
                        chars=button_chars,
                        pens=COLOR_GRAY,
                        tileset=toolbar_textures,
                        tileset_offset=1,
                        tileset_stride=8,
                    },
                    on_click=launch_sitemap,
                    visible=function () return not self.subviews.icon:getMousePos() end,
                },
                widgets.Label{
                    text=widgets.makeButtonLabelText{
                        chars=button_chars,
                        pens={
                            {COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE},
                            {COLOR_WHITE, COLOR_GRAY,  COLOR_GRAY,  COLOR_WHITE},
                            {COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE},
                        },
                        tileset=toolbar_textures,
                        tileset_offset=5,
                        tileset_stride=8,
                    },
                    on_click=launch_sitemap,
                    visible=function() return not not self.subviews.icon:getMousePos() end,
                },
            },
        },
    }
end

function SitemapToolbarOverlay:onInput(keys)
    if keys.CUSTOM_CTRL_G then
        launch_sitemap()
        return true
    end
    return SitemapToolbarOverlay.super.onInput(self, keys)
end

OVERLAY_WIDGETS = {sitemaptoolbar=SitemapToolbarOverlay}


if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a map to be loaded')
end

view = view and view:raise() or SitemapScreen{}:show()

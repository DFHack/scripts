local gui = require('gui')
local utils = require('utils')
local widgets = require('gui.widgets')

--
-- Sitemap
--

Sitemap = defclass(Sitemap, widgets.Window)
Sitemap.ATTRS {
    frame_title='Sitemap',
    frame={w=47, r=2, t=18, h=23},
    resizable=true,
}

local function to_title_case(str)
    return dfhack.capitalizeStringWords(dfhack.lowerCp437(str:gsub('_', ' ')))
end

local function get_location_desc(loc)
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
        local name = dfhack.TranslateName(entity.name, true)
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
    table.insert(tokens, dfhack.TranslateName(loc.name, true))
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
            text=dfhack.units.getReadableName(unit),
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
            frame={t=3, l=0, b=5, r=0},
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
                            choices=artifact_choices,
                            visible=#artifact_choices > 0,
                        },
                    },
                },
            },
        },
        widgets.Divider{
            frame={b=3, h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Label{
            frame={b=0, l=0},
            text={
                'Click on a name or hit ', {text='Enter', pen=COLOR_LIGHTGREEN}, NEWLINE,
                'to zoom to the selected target.'
            },
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

if not dfhack.isMapLoaded() then
    qerror('This script requires a map to be loaded')
end

view = view and view:raise() or SitemapScreen{}:show()

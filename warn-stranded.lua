-- Detects and alerts when a citizen is stranded
--@module = true

local gui = require('gui')
local widgets = require('gui.widgets')

local GLOBAL_KEY = 'warn-stranded_v2'

ignoresCache = ignoresCache or {}

local function persist_state()
    -- convert integer keys to strings for storage
    local data = {}
    for k,v in pairs(ignoresCache) do
        data[tostring(k)] = v
    end
    dfhack.persistent.saveSiteData(GLOBAL_KEY, data)
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end
    ignoresCache = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    -- convert the string keys back into integers
    for k,v in pairs(ignoresCache) do
        if type(k) == 'string' then
            ignoresCache[tonumber(k)] = v
            ignoresCache[k] = nil
        end
    end
end

-- ====================================
--              Core logic
-- ====================================

local function getWalkGroup(pos)
    local walkGroup = dfhack.maps.getWalkableGroup(pos)
    return walkGroup ~= 0 and walkGroup or nil
end

local function hasAllowlistedJob(unit)
    local job = unit.job.current_job
    if not job then return false end
    return job.job_type == df.job_type.GatherPlants or
        df.job_type_class[df.job_type.attrs[job.job_type].type] == 'Digging'
end

local function hasAllowlistedPos(pos)
    local bld = dfhack.buildings.findAtTile(pos)
    return bld and bld:getType() == df.building_type.Hatch and
        not bld.door_flags.closed
end

-- used by gui/notify
function getStrandedGroups()
    if not dfhack.isMapLoaded() then
        return {}
    end

    local groupCount = 0
    local unitsByWalkGroup, ignoredUnitsByWalkGroup = {}, {}

    for _, unit in ipairs(dfhack.units.getCitizens(true)) do
        local unitPos = xyz2pos(dfhack.units.getPosition(unit))
        local walkGroup = getWalkGroup(unitPos)

        -- if on an unpathable tile, use the walkGroup of an adjacent tile. this prevents
        -- warnings for units that are walking under falling water, which sometimes makes
        -- a tile unwalkable while the unit is standing on it
        if not walkGroup then
            walkGroup = getWalkGroup(xyz2pos(unitPos.x-1, unitPos.y-1, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x, unitPos.y-1, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x+1, unitPos.y-1, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x-1, unitPos.y, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x+1, unitPos.y, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x-1, unitPos.y+1, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x, unitPos.y+1, unitPos.z))
                or getWalkGroup(xyz2pos(unitPos.x+1, unitPos.y+1, unitPos.z))
                or 0
        end

        -- Skip units who are:
        --   gathering plants (could be on stepladder)
        --   digging (could be digging self out of hole)
        --   standing on an open hatch (which is its own pathability group)
        -- to avoid false positives
        if hasAllowlistedJob(unit) or hasAllowlistedPos(unitPos) then
            goto skip
        end
        if ignoresCache[unit.id] then
            table.insert(ensure_key(ignoredUnitsByWalkGroup, walkGroup), unit)
        else
            if not unitsByWalkGroup[walkGroup] then
                groupCount = groupCount + 1
            end
            table.insert(ensure_key(unitsByWalkGroup, walkGroup), unit)
        end
        ::skip::
    end

    local groupList = {}
    for walkGroup, units in pairs(unitsByWalkGroup) do
        table.insert(groupList, {units=units, walkGroup=walkGroup})
    end
    table.sort(groupList, function(a, b) return #a['units'] < #b['units'] end)

    -- The largest group is not stranded by definition
    local mainGroup
    if #groupList > 0 then
        mainGroup = groupList[#groupList].walkGroup
        table.remove(groupList, #groupList)
    end

    return groupList, ignoredUnitsByWalkGroup, mainGroup
end

-- =============================
--              Gui
-- =============================

local function getSexString(sex)
    local sym = df.pronoun_type.attrs[sex].symbol
    if sym then
        return ('(%s)'):format(tostring(sym))
    end
    return ''
end

local function getUnitDescription(unit)
    return ('[%s] %s %s'):format(
        dfhack.units.getProfessionName(unit),
        dfhack.TranslateName(dfhack.units.getVisibleName(unit)),
        getSexString(unit.sex))
end

-- Use group data, index, and command arguments to generate a group
--   designation string.
local function getGroupDesignation(group, groupIndex, walkGroup)
    local groupDesignation = ''

    if group['mainGroup'] then
        groupDesignation = ' (Main Group)'
    else
        groupDesignation = ' (Group '..groupIndex..')'
    end

    if walkGroup then
        groupDesignation = groupDesignation..' {'..group.walkGroup..'}'
    end

    return groupDesignation
end

local function addId(text, unit)
    return text..'|'..unit.id..'| '
end

local function getIgnoredPrefix(unit)
    return ignoresCache[unit.id] and '[IGNORED] ' or ''
end

-- Returns true if the unit was already ignored, false if it wasn't.
local function toggleUnitIgnore(unit)
    local was_ignored = ignoresCache[unit.id]
    ignoresCache[unit.id] = not was_ignored or nil
    persist_state()
    return was_ignored
end

-- Does the usual GUI pattern when groups can be in a partial state
--   Will ignore everything, unless all units in group are already ignored
--   If all units in the group are ignored, then it will unignore all of them
local function toggleGroup(groups, groupNumber)
    local group = groups[groupNumber]

    if not group then
        print('Group '..groupNumber..' does not exist')
        return false
    end

    if group.mainGroup then
        print('Group '..groupNumber..' is the main group of dwarves. Cannot toggle.')
        return false
    end

    local allIgnored = true
    for _, unit in ipairs(group.units) do
        if not ignoresCache[unit.id] then
            allIgnored = false
            break
        end
    end

    for _, unit in ipairs(group.units) do
        local isIgnored = ignoresCache[unit.id]
        if isIgnored then isIgnored = true else isIgnored = false end
        if allIgnored == isIgnored then
            toggleUnitIgnore(unit)
        end
    end

    return true
end

local function clear()
    ignoresCache = {}
    persist_state()
end

WarningWindow = defclass(WarningWindow, widgets.Window)
WarningWindow.ATTRS{
    frame={w=60, h=25, r=2, t=18},
    resize_min={w=50, h=15},
    frame_title='Stranded citizen warning',
    resizable=true,
    groups=DEFAULT_NIL,
}

function WarningWindow:init()
    self:addviews{
        widgets.List{
            frame={l=0, r=0, t=0, b=6},
            view_id = 'list',
            on_select=self:callback('onZoom'),
            on_double_click=self:callback('onIgnore'),
            on_double_click2=self:callback('onToggleGroup'),
        },
        widgets.WrappedLabel{
            frame={b=3, l=0},
            text_to_wrap='Select to zoom to unit. Double click to toggle unit ignore. Shift double click to toggle a group.',
        },
        widgets.HotkeyLabel{
            frame={b=1, l=0},
            key='SELECT',
            label='Toggle ignore',
            on_activate=self:callback('onIgnore'),
            auto_width=true,
        },
        widgets.HotkeyLabel{
            frame={b=1, l=23},
            key='CUSTOM_G',
            label='Toggle group',
            on_activate = self:callback('onToggleGroup'),
            auto_width=true,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key = 'CUSTOM_SHIFT_I',
            label = 'Ignore all',
            on_activate = self:callback('onIgnoreAll'),
            auto_width=true,

        },
        widgets.HotkeyLabel{
            frame={b=0, l=23},
            key = 'CUSTOM_SHIFT_C',
            label = 'Clear all ignored',
            on_activate = self:callback('onClear'),
            auto_width=true,
        },
    }

    self:initListChoices()
end

function WarningWindow:initListChoices()
    local choices = {}

    for groupIndex, group in ipairs(self.groups) do
        local groupDesignation = getGroupDesignation(group, groupIndex)

        for _, unit in ipairs(group.units) do
            local text = getIgnoredPrefix(unit)
            text = text..getUnitDescription(unit)..groupDesignation
            table.insert(choices, {text=text, data={unit=unit, group=groupIndex}})
        end
    end

    self.subviews.list:setChoices(choices)
end

function WarningWindow:onIgnore(_, choice)
    if not choice then
        _, choice = self.subviews.list:getSelected()
    end
    toggleUnitIgnore(choice.data.unit)
    self:initListChoices()
end

function WarningWindow:onIgnoreAll()
    for _, choice in ipairs(self.subviews.list:getChoices()) do
        -- We don't want to flip ignored units to unignored
        if not ignoresCache[choice.data.unit] then
            toggleUnitIgnore(choice.data.unit)
        end
    end
    self:initListChoices()
end

function WarningWindow:onClear()
    clear()
    self:initListChoices()
end

function WarningWindow:onZoom()
    local _, choice = self.subviews.list:getSelected()
    local unit = choice.data.unit

    local target = xyz2pos(dfhack.units.getPosition(unit))
    dfhack.gui.revealInDwarfmodeMap(target, true, true)
end

function WarningWindow:onToggleGroup()
    local _, choice = self.subviews.list:getSelected()
    local group = choice.data.group

    toggleGroup(self.groups, group)
    self:initListChoices()
end

WarningScreen = defclass(WarningScreen, gui.ZScreen)
WarningScreen.ATTRS{
    focus_path='warn-stranded',
    initial_pause=true,
    groups=DEFAULT_NIL,
}

function WarningScreen:init()
    self:addviews{WarningWindow{groups=self.groups}}
end

function WarningScreen:onDismiss()
    view = nil
end

-- ======================================================================
--                         Core Logic
-- ======================================================================

local function getStrandedGroupsWithIgnored(groupList, ignoredUnitsByWalkGroup, mainGroup)
    if not groupList then
        groupList, ignoredUnitsByWalkGroup, mainGroup = getStrandedGroups()
    end

    -- Merge ignoredGroups with strandedGroups
    for walkGroup, units in pairs(ignoredUnitsByWalkGroup or {}) do
        local groupIndex = nil

        -- Handle ignored units in mainGroup by shifting other groups down
        -- We need to list them so they can be toggled
        if walkGroup == mainGroup then
            table.insert(groupList, 1, {units={}, walkGroup=mainGroup, mainGroup=true})
            groupIndex = 1
        end

        -- Find matching group
        for i, group in ipairs(groupList) do
            if group.walkGroup == walkGroup then
                groupIndex = i
            end
        end

        -- No matching group
        if not groupIndex then
            table.insert(groupList, {units={}, walkGroup=walkGroup})
            groupIndex = #groupList
        end

        -- Put all the units in the appropriate group
        for _, unit in ipairs(units) do
            table.insert(groupList[groupIndex].units, unit)
        end
    end

    -- Key = group number (not pathability group number)
    -- Value = { units = <array of units>, walkGroup = <pathability group>, mainGroup = <is this ignored units from the main group?> }
    return groupList
end

local function findCitizen(unitId)
    for _, citizen in ipairs(dfhack.units.getCitizens(true, true)) do
        if citizen.id == unitId then return citizen end
    end

    return nil
end

local function ignoreGroup(groups, groupNumber)
    local group = groups[groupNumber]

    if not group then
        print('Group '..groupNumber..' does not exist')
        return false
    end

    if group.mainGroup then
        print('Group '..groupNumber..' is the main group of dwarves. Not ignoring.')
        return false
    end

    for _, unit in ipairs(group.units) do
        if ignoresCache[unit.id] then
            print('Unit '..unit.id..' already ignored, doing nothing to them.')
        else
            print('Ignoring unit '..unit.id)
            toggleUnitIgnore(unit)
        end
    end

    return true
end

local function unignoreGroup(groups, groupNumber)
    local group = groups[groupNumber]

    if not group then
        print('Group '..groupNumber..' does not exist')
        return false
    end

    for _, unit in ipairs(group.units) do
        if ignoresCache[unit.id] then
            print('Unignoring unit '..unit.id)
            ignored = toggleUnitIgnore(unit)
        else
            print('Unit '..unit.id..' not already ignored, doing nothing to them.')
        end
    end

    return true
end

local function doCheck()
    local groupList, ignoredUnitsByWalkGroup, mainGroup = getStrandedGroups()

    if #groupList > 0 then
        return WarningScreen{
            groups=getStrandedGroupsWithIgnored(groupList, ignoredUnitsByWalkGroup, mainGroup),
        }:show()
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('warn-stranded requires a map to be loaded')
end

-- =========================================================================
--                       Command Line Interface
-- =========================================================================

local positionals = {...}
local parameter = tonumber(positionals[2])

if positionals[1] == 'clear' then
    print('Clearing unit ignore list.')
    clear()
elseif positionals[1] == 'status' then
    local strandedGroups = getStrandedGroupsWithIgnored()
    if #strandedGroups > 0 then
        for groupIndex, group in ipairs(strandedGroups) do
            local groupDesignation = getGroupDesignation(group, groupIndex, true)

            for _, unit in ipairs(group['units']) do
                local text = getIgnoredPrefix(unit)
                text = addId(text, unit)

                print(text..dfhack.df2console(getUnitDescription(unit))..groupDesignation)
            end
        end
        return true
    end
    print('No citizens are currently stranded.')
    print()
    print('Ignored citizens:')
    for walkGroup, units in pairs(strandedGroups) do
        for _, unit in ipairs(units) do
            local text = ''
            text = addId(text, unit)
            print(text..dfhack.df2console(getUnitDescription(unit))..' {'..walkGroup..'}')
        end
    end
    if #strandedGroups == 0 then
        print('  None')
    end
elseif positionals[1] == 'ignore' then
    if not parameter then
        print('Must provide unit id to the ignore command.')
        return false
    end
    local citizen = findCitizen(parameter)
    if citizen == nil then
        print('No citizen with unit id '..parameter..' found in the fortress')
        return false
    end
    if ignoresCache[citizen.id] then
        print('Unit '..parameter..' is already ignored. You may want to use the unignore command.')
        return false
    end
    print('Ignoring unit '..parameter)
    toggleUnitIgnore(citizen)
elseif positionals[1] == 'ignoregroup' then
    if not parameter then
        print('Must provide group id to the ignoregroup command.')
    end
    print('Ignoring group '..parameter)
    local strandedGroups = getStrandedGroupsWithIgnored()
    ignoreGroup(strandedGroups, parameter)
elseif positionals[1] == 'unignore' then
    if not parameter then
        print('Must provide unit id to unignore command.')
        return false
    end
    local citizen = findCitizen(parameter)
    if citizen == nil then
        print('No citizen with unit id '..parameter..' found in the fortress')
        return false
    end
    if not ignoresCache[citizen.id] then
        print('Unit '..parameter..' is not ignored. You may want to use the ignore command.')
        return false
    end
    print('Unignoring unit '..parameter)
    toggleUnitIgnore(citizen)
elseif positionals[1] == 'unignoregroup' then
    if not parameter then
        print('Must provide group id to unignoregroup command.')
        return false
    end
    print('Unignoring group '..parameter)
    local strandedGroups = getStrandedGroupsWithIgnored()
    unignoreGroup(strandedGroups, parameter)
else
    view = view and view:raise() or doCheck()
end

-- Detects and alerts when a citizen is stranded
-- Logic heavily based off of warn-starving
-- GUI heavily based off of autobutcher
--@module = true

local gui = require 'gui'
local widgets = require 'gui.widgets'
local argparse = require 'argparse'
local args = {...}

local GLOBAL_KEY = 'warn-stranded_v2'

ignoresCache = ignoresCache or {}

-- ===============================================
--              Utility Functions
-- ===============================================

-- Clear the ignore list
local function clear()
    for index, entry in pairs(ignoresCache) do
        entry:delete()
        ignoresCache[index] = nil
    end
end

-- Taken from warn-starving
local function getSexString(sex)
    local sym = df.pronoun_type.attrs[sex].symbol

    if sym then
        return "("..sym..")"
    else
        return ""
    end
end

-- Partially taken from warn-starving
local function getUnitDescription(unit)
    return ('[%s] %s %s'):format(dfhack.units.getProfessionName(unit),
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

-- Add unit.id to text
local function addId(text, unit)
    return text..'|'..unit.id..'| '
end

-- ===============================================
--              Persistence API
-- ===============================================
-- Optional refresh parameter forces us to load from API instead of using cache

-- Uses persistent API. Low-level, gets all entries currently in our persistent table
--   will return an empty array if needed. Clears and adds entries to our cache.
-- Returns the new global ignoresCache value
local function loadIgnoredUnits()
    ignoresCache = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    return ignoresCache
end

-- Uses persistent API. Optional refresh parameter forces us to load from API,
--   instead of using our cache.
-- Returns the persistent entry or nil
local function unitIgnored(unit, refresh)
    if refresh then loadIgnoredUnits() end

    return ignoresCache[unit.id]
end

-- Check for and potentially add [IGNORED] to text.
local function addIgnored(text, unit, refresh)
    if unitIgnored(unit, refresh) then
        return text..'[IGNORED] '
    end

    return text
end

-- Uses persistent API. Toggles a unit's ignored status by deleting the entry from the persistence API
--   and from the ignoresCache table.
-- Returns true if the unit was already ignored, false if it wasn't.
local function toggleUnitIgnore(unit, refresh)
    local was_ignored = unitIgnored(unit, refresh)
    ignoresCache[unit.id] = not was_ignored or nil
    dfhack.persistent.saveSiteData(GLOBAL_KEY, ignoresCache)
    return was_ignored
end

-- Does the usual GUI pattern when groups can be in a partial state
--   Will ignore everything, unless all units in group are already ignored
--   If all units in the group are ignored, then it will unignore all of them
local function toggleGroup(groups, groupNumber)
    if groupNumber > #groups then
        print('Group '..groupNumber..' does not exist')
        return false
    end

    if groups[groupNumber]['mainGroup'] then
        print('Group '..groupNumber..' is the main group of dwarves. Cannot toggle.')
        return false
    end

    local group = groups[groupNumber]

    local allIgnored = true
    for _, unit in ipairs(group['units']) do
        if not unitIgnored(unit) then
            allIgnored = false
            goto process
        end
    end
    ::process::

    for _, unit in ipairs(group['units']) do
        local isIgnored = unitIgnored(unit)
        if isIgnored then isIgnored = true else isIgnored = false end

        if allIgnored == isIgnored then
            toggleUnitIgnore(unit)
        end
    end

    return true
end

-- ===============================================================
--                   Graphical Interface
-- ===============================================================
WarningWindow = defclass(WarningWindow, widgets.Window)
WarningWindow.ATTRS{
    frame={w=60, h=25, r=2, t=18},
    resize_min={w=50, h=15},
    frame_title='Stranded citizen warning',
    resizable=true,
}

function WarningWindow:init(info)
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

    self.groups = info.groups
    self:initListChoices()
end

function WarningWindow:initListChoices()
    local choices = {}

    for groupIndex, group in ipairs(self.groups) do
        local groupDesignation = getGroupDesignation(group, groupIndex)

        for _, unit in ipairs(group['units']) do
            local text = ''

            text = addIgnored(text, unit)
            text = text..getUnitDescription(unit)..groupDesignation

            table.insert(choices, { text = text, data = {unit = unit, group = groupIndex} })
        end
    end

    local list = self.subviews.list
    list:setChoices(choices)
end

function WarningWindow:onIgnore(_, choice)
    if not choice then
        _, choice = self.subviews.list:getSelected()
    end
    local unit = choice.data['unit']

    toggleUnitIgnore(unit)
    self:initListChoices()
end

function WarningWindow:onIgnoreAll()
    local choices = self.subviews.list:getChoices()

    for _, choice in ipairs(choices) do
        -- We don't want to flip ignored units to unignored
        if not unitIgnored(choice.data['unit']) then
            toggleUnitIgnore(choice.data['unit'])
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
    local unit = choice.data['unit']

    local target = xyz2pos(dfhack.units.getPosition(unit))
    dfhack.gui.revealInDwarfmodeMap(target, true, true)
end

function WarningWindow:onToggleGroup()
    local index, choice = self.subviews.list:getSelected()
    local group = choice.data['group']

    toggleGroup(self.groups, group)
    self:initListChoices()
end

WarningScreen = defclass(WarningScreen, gui.ZScreenModal)

function WarningScreen:init(info)
    self:addviews{WarningWindow{groups=info.groups}}
end

function WarningScreen:onDismiss()
    view = nil
end

-- ======================================================================
--                         Core Logic
-- ======================================================================

local function compareGroups(group_one, group_two)
    return #group_one['units'] < #group_two['units']
end

local function getWalkGroup(pos)
    local block = dfhack.maps.getTileBlock(pos)
    if not block then return end
    local walkGroup = dfhack.maps.getWalkableGroup(pos)
    return walkGroup ~= 0 and walkGroup or nil
end

local function getStrandedUnits()
    local groupCount = 0
    local grouped = {}
    local citizens = dfhack.units.getCitizens(true)

    -- Don't use ignored units to determine if there are any stranded units
    -- but keep them to display later
    local ignoredGroup = {}

    -- Pathability group calculation is from gui/pathable
    for _, unit in ipairs(citizens) do
        local unitPos = xyz2pos(dfhack.units.getPosition(unit))
        local walkGroup = getWalkGroup(unitPos) or 0

        -- if on an unpathable tile, use the walkGroup of an adjacent tile. this prevents
        -- warnings for units that are walking under falling water, which sometimes makes
        -- a tile unwalkable while the unit is standing on it
        if walkGroup == 0 then
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

        -- Ignore units who are gathering plants or digging to avoid errors with stepladders and weird digging things
        if unitIgnored(unit) or (unit.job.current_job and
                                    (unit.job.current_job.job_type == df.job_type.GatherPlants or
                                        df.job_type.attrs[unit.job.current_job.job_type].type == 'Digging')) then
            table.insert(ensure_key(ignoredGroup, walkGroup), unit)
        else
            table.insert(ensure_key(grouped, walkGroup), unit)

            -- Count each new group
            if #grouped[walkGroup] == 1 then
                groupCount = groupCount + 1
            end
        end
    end

    -- No one is stranded, so stop here
    if groupCount <= 1 then
        return false, ignoredGroup
    end

    -- We needed the table for easy grouping
    -- Now let us get an array so we can sort easily
    local rawGroups = {}
    for index, units in pairs(grouped) do
        table.insert(rawGroups, { units = units, walkGroup = index })
    end

    -- This data structure is super easy to sort from biggest to smallest
    -- Our group number is just the array index and is sorted for us
    table.sort(rawGroups, compareGroups)

    -- The biggest group is not stranded
    mainGroup = rawGroups[#rawGroups]['walkGroup']
    table.remove(rawGroups, #rawGroups)

    -- Merge ignoredGroup with grouped
    for index, units in pairs(ignoredGroup) do
        local groupIndex = nil

        -- Handle ignored units in mainGroup by shifting other groups down
        -- We need to list them so they can be toggled
        if index == mainGroup then
            table.insert(rawGroups, 1, { units = {}, walkGroup = mainGroup, mainGroup = true })
            groupIndex = 1
        end

        -- Find matching group
        for i, group in ipairs(rawGroups) do
            if group.walkGroup == index then
                groupIndex = i
            end
        end

        -- No matching group
        if groupIndex == nil then
            table.insert(rawGroups, { units = {}, walkGroup = index })
            groupIndex = #rawGroups
        end

        -- Put all the units in the appropriate group
        for _, unit in ipairs(units) do
            table.insert(rawGroups[groupIndex]['units'], unit)
        end
    end

    -- Key = group number (not pathability group number)
    -- Value = { units = <array of units>, walkGroup = <pathability group>, mainGroup = <is this ignored units from the main group?> }
    return true, rawGroups
end

local function findCitizen(unitId)
    local citizens = dfhack.units.getCitizens()

    for _, citizen in ipairs(citizens) do
        if citizen.id == unitId then return citizen end
    end

    return nil
end

local function ignoreGroup(groups, groupNumber)
    if groupNumber > #groups then
        print('Group '..groupNumber..' does not exist')
        return false
    end

    if groups[groupNumber]['mainGroup'] then
        print('Group '..groupNumber..' is the main group of dwarves. Not ignoring.')
        return false
    end

    for _, unit in ipairs(groups[groupNumber]['units']) do
        if unitIgnored(unit) then
            print('Unit '..unit.id..' already ignored, doing nothing to them.')
        else
            print('Ignoring unit '..unit.id)
            toggleUnitIgnore(unit)
        end
    end

    return true
end

local function unignoreGroup(groups, groupNumber)
    if groupNumber > #groups then
        print('Group '..groupNumber..' does not exist')
        return false
    end

    if groups[groupNumber]['mainGroup'] then
        print('Group '..groupNumber..' is the main group of dwarves. Unignoring.')
    end

    for _, unit in ipairs(groups[groupNumber]['units']) do
        if unitIgnored(unit) then
            print('Unignoring unit '..unit.id)
            ignored = toggleUnitIgnore(unit)
        else
            print('Unit '..unit.id..' not already ignored, doing nothing to them.')
        end
    end

    return true
end

function doCheck()
    local result, strandedGroups = getStrandedUnits()

    if result then
        return WarningScreen{groups=strandedGroups}:show()
    end
end

-- Load ignores list on save game load
-- WARNING: This has to be above `dfhack_flags.module` or it will not work as intended on first game load
dfhack.onStateChange[GLOBAL_KEY] = function(state_change)
    if state_change ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    loadIgnoredUnits()
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

local positionals = argparse.processArgsGetopt(args, {})
local parameter = tonumber(positionals[2])

if positionals[1] == 'clear' then
    print('Clearing unit ignore list.')
    clear()

elseif positionals[1] == 'status' then
    local result, strandedGroups = getStrandedUnits()

    if result then
        for groupIndex, group in ipairs(strandedGroups) do
            local groupDesignation = getGroupDesignation(group, groupIndex, true)

            for _, unit in ipairs(group['units']) do
                local text = ''

                text = addIgnored(text, unit)
                text = addId(text, unit)

                print(text..getUnitDescription(unit)..groupDesignation)
            end
        end

        return true
    end


    print('No citizens are currently stranded.')

    -- We have some ignored citizens
    if not (next(strandedGroups) == nil) then
        print('\nIgnored citizens:')

        for walkGroup, units in pairs(strandedGroups) do
            for _, unit in ipairs(units) do
                local text = ''

                text = addId(text, unit)
                text = text..getUnitDescription(unit)..' {'..walkGroup..'}'

                print(text)
            end
        end
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

    if unitIgnored(citizen) then
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
    local _, strandedCitizens = getStrandedUnits()
    ignoreGroup(strandedCitizens, parameter)

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

    if not unitIgnored(citizen) then
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

    local _, strandedCitizens = getStrandedUnits()
    unignoreGroup(strandedCitizens, parameter)
else
    view = view and view:raise() or doCheck()
end

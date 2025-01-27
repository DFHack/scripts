--@ module = true
local dialogs = require('gui.dialogs')
local utils = require('utils')
local argparse = require('argparse')
local makeown = reqscript('makeown')

local function setNewAdvNemFlags(nem)
    nem.flags.ACTIVE_ADVENTURER = true
    nem.flags.ADVENTURER = true
end

local function setOldAdvNemFlags(nem)
    nem.flags.ACTIVE_ADVENTURER = false
end

local function clearNemesisFromLinkedSites(nem)
    -- omitting this step results in duplication of the unit entry in df.global.world.units.active when the site to which the historical figure is linked is reloaded with said figure present as a member of the player party
    -- this can be observed as part of the normal recruitment process when the player adds a site-linked historical figure to their party
    if not nem.figure then
        return
    end
    for _, link in ipairs(nem.figure.site_links) do
        local site = df.world_site.find(link.site)
        utils.erase_sorted(site.populace.nemesis, nem.id)
    end
end

local function createNemesis(unit)
    local nemesis = unit:create_nemesis(1, 1)
    nemesis.figure.flags.never_cull = true
    return nemesis
end

local function isPet(nemesis)
    if nemesis.unit then
        if nemesis.unit.relationship_ids.PetOwner ~= -1 then
            return true
        end
    elseif nemesis.figure then -- in case the unit is offloaded
        for _, link in ipairs(nemesis.figure.histfig_links) do
            if link._type == df.histfig_hf_link_pet_ownerst then
                return true
            end
        end
    end
    return false
end

local function processNemesisParty(nemesis, targetUnitID, alreadyProcessed)
    -- configures the target and any leaders/companions to behave as cohesive adventure mode party members
    local alreadyProcessed = alreadyProcessed or {}
    alreadyProcessed[tostring(nemesis.id)] = true

    local nemUnit = nemesis.unit
    if nemesis.unit_id == targetUnitID then -- the target you're bodyswapping into
        df.global.adventure.interactions.party_core_members:insert('#', nemesis.figure.id)
        nemUnit.relationship_ids.GroupLeader = -1
    elseif isPet(nemesis) then -- pets belonging to the target or to their companions
        df.global.adventure.interactions.party_pets:insert('#', nemesis.figure.id)
    else
        df.global.adventure.interactions.party_extra_members:insert('#', nemesis.figure.id) -- placing all non-pet companions into the extra party list
        if nemUnit then                                                                -- check in case the companion is offloaded
            nemUnit.relationship_ids.GroupLeader = targetUnitID
        end
    end
    -- the hierarchy of nemesis-level leader/companion relationships appears to be left untouched when the player character is changed using the inbuilt "tactical mode" party system

    clearNemesisFromLinkedSites(nemesis)

    if nemesis.group_leader_id ~= -1 and not alreadyProcessed[tostring(nemesis.group_leader_id)] then
        local leader = df.nemesis_record.find(nemesis.group_leader_id)
        if leader then
            processNemesisParty(leader, targetUnitID, alreadyProcessed)
        end
    end
    for _, id in ipairs(nemesis.companions) do
        if not alreadyProcessed[tostring(id)] then
            local companion = df.nemesis_record.find(id)
            if companion then
                processNemesisParty(companion, targetUnitID, alreadyProcessed)
            end
        end
    end
end

local function configureAdvParty(targetNemesis)
    local party = df.global.adventure.interactions
    party.party_core_members:resize(0)
    party.party_pets:resize(0)
    party.party_extra_members:resize(0)
    processNemesisParty(targetNemesis, targetNemesis.unit_id)
end

-- shamelessly copy pasted from flashstep.lua
local function reveal_tile(pos)
    local des = dfhack.maps.getTileFlags(pos)
    des.hidden = false
    des.pile = true  -- reveal the tile on the map
end

local function reveal_around(pos)
    reveal_tile(xyz2pos(pos.x-1, pos.y-1, pos.z))
    reveal_tile(xyz2pos(pos.x,   pos.y-1, pos.z))
    reveal_tile(xyz2pos(pos.x+1, pos.y-1, pos.z))
    reveal_tile(xyz2pos(pos.x-1, pos.y,   pos.z))
    reveal_tile(pos)
    reveal_tile(xyz2pos(pos.x+1, pos.y,   pos.z))
    reveal_tile(xyz2pos(pos.x-1, pos.y+1, pos.z))
    reveal_tile(xyz2pos(pos.x,   pos.y+1, pos.z))
    reveal_tile(xyz2pos(pos.x+1, pos.y+1, pos.z))
end

function swapAdvUnit(newUnit)
    if not newUnit then
        qerror('Target unit not specified!')
    end

    local oldNem = df.nemesis_record.find(df.global.adventure.player_id)
    local oldUnit = oldNem.unit
    if newUnit == oldUnit then
        return
    end

    -- Make sure the unit we're swapping into isn't nameless
    makeown.name_unit(newUnit)

    local newNem = dfhack.units.getNemesis(newUnit) or createNemesis(newUnit)
    if not newNem then
        qerror("Failed to obtain target nemesis!")
    end

    setOldAdvNemFlags(oldNem)
    setNewAdvNemFlags(newNem)
    configureAdvParty(newNem)
    df.global.adventure.player_id = newNem.id
    df.global.world.units.adv_unit = newUnit
    oldUnit.idle_area:assign(oldUnit.pos)
    local pos = xyz2pos(dfhack.units.getPosition(newUnit))
    -- reveal the tiles around the bodyswapped unit
    reveal_around(pos)
    -- Focus on the revealed pos
    dfhack.gui.revealInDwarfmodeMap(pos, true)
end

-- shamelessly copy pasted from gui/sitemap.lua
local function get_unit_choices()
    local choices = {}
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isActive(unit) or
            dfhack.units.isHidden(unit)
        then
            goto continue
        end
        local name = dfhack.units.getReadableName(unit)
        table.insert(choices, {
            text=name,
            unit=unit,
            search_key=dfhack.toSearchNormalized(name),
        })
        ::continue::
    end
    return choices
end

local function swapAdvUnitPrompt()
    local choices = get_unit_choices()
    dialogs.showListPrompt('bodyswap', "Select a unit to bodyswap to:", COLOR_WHITE,
        choices, function(id, choice)
            swapAdvUnit(choice.unit)
        end, nil, nil, true)
end

function getHistoricalSlayer(unit)
    local histFig = unit.hist_figure_id ~= -1 and df.historical_figure.find(unit.hist_figure_id)
    if not histFig then
        return
    end

    local deathEvents = df.global.world.history.events_death
    for i = #deathEvents - 1, 0, -1 do
        local event = deathEvents[i] --as:df.history_event_hist_figure_diedst
        if event.victim_hf == unit.hist_figure_id then
            return df.historical_figure.find(event.slayer_hf)
        end
    end
end

function lingerAdvUnit(unit)
    if not dfhack.units.isKilled(unit) then
        qerror("Target unit hasn't died yet!")
    end

    local slayerHistFig = getHistoricalSlayer(unit)
    local slayer = slayerHistFig and df.unit.find(slayerHistFig.unit_id)
    if not slayer then
        slayer = df.unit.find(unit.relationship_ids.LastAttacker)
    end
    if not slayer then
        qerror("Slayer not found!")
    elseif dfhack.units.isKilled(slayer) then
        local slayerName = ""
        if slayer.name.has_name then
            slayerName = ", " .. dfhack.units.getReadableName(slayer) .. ","
        end
        qerror("The unit's slayer" .. slayerName .. " is dead!")
    end

    swapAdvUnit(slayer)
end

if not dfhack_flags.module then
    if df.global.gamemode ~= df.game_mode.ADVENTURE then
        qerror("This script can only be used in adventure mode!")
    end

    local options = {
        help = false,
        unit = -1,
    }

    local args = { ... }
    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help', handler = function() options.help = true end},
        {'u', 'unit', handler = function(arg) options.unit = argparse.nonnegativeInt(arg, 'unit') end, hasArg = true},
    })

    if positionals[1] == 'help' or options.help then
        print(dfhack.script_help())
        return
    end

    if positionals[1] == 'linger' then
        lingerAdvUnit(dfhack.world.getAdventurer())
        return
    end

    local unit = options.unit == -1 and dfhack.gui.getSelectedUnit(true) or df.unit.find(options.unit)
    if not unit then
        print("Enter the following if you require assistance: help bodyswap")
        if options.unit ~= -1 then
            qerror("Invalid unit id: " .. options.unit)
        else
            swapAdvUnitPrompt()
            return
        end
    end
    swapAdvUnit(unit)
end

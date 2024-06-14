--@ module = true
local dialogs = require 'gui.dialogs'
local utils = require 'utils'
local validArgs = utils.invert({
    'unit',
    'help'
})
local args = utils.processArgs({ ... }, validArgs)

if args.help then
    print(dfhack.script_help())
    return
end

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

-- shamelessly copypasted from makeown.lua
local function get_translation(race_id)
    local race_name = df.global.world.raws.creatures.all[race_id].creature_id
    local backup = nil
    for _,translation in ipairs(df.global.world.raws.language.translations) do
        if translation.name == race_name then
            return translation
        end
        if translation.name == 'GEN_DIVINE' then
            backup = translation
        end
    end
    -- Use a divine name if no normal name is found
    if backup then
        return backup
    end
    -- Use the first language in the list if no divine language is found, this is normally the DWARF language.
    return df.global.world.raws.language.translations[0]
end

local function pick_first_name(race_id)
    local translation = get_translation(race_id)
    return translation.words[math.random(0, #translation.words-1)].value
end

local LANGUAGE_IDX = 0
local word_table = df.global.world.raws.language.word_table[LANGUAGE_IDX][35]

local function name_nemesis(nemesis)
    local figure = nemesis.figure
    if figure.name.has_name then return end

    figure.name.first_name = pick_first_name(figure.race)
    figure.name.words.FrontCompound = word_table.words.FrontCompound[math.random(0, #word_table.words.FrontCompound-1)]
    figure.name.words.RearCompound = word_table.words.RearCompound[math.random(0, #word_table.words.RearCompound-1)]

    figure.name.language = LANGUAGE_IDX
    figure.name.parts_of_speech.FrontCompound = df.part_of_speech.Noun
    figure.name.parts_of_speech.RearCompound = df.part_of_speech.Verb3rdPerson
    figure.name.type = df.language_name_type.Figure
    figure.name.has_name = true
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
    local block = dfhack.maps.getTileBlock(pos)
    local des = block.designation[pos.x%16][pos.y%16]
    des.hidden = false
    des.pile = true  -- reveal the tile on the map
end

local function swapAdvUnit(newUnit)
    if not newUnit then
        qerror('Target unit not specified!')
    end

    local oldNem = df.nemesis_record.find(df.global.adventure.player_id)
    local oldUnit = oldNem.unit
    if newUnit == oldUnit then
        return
    end

    local newNem = dfhack.units.getNemesis(newUnit) or createNemesis(newUnit)
    if not newNem then
        qerror("Failed to obtain target nemesis!")
    end

    name_nemesis(newNem)

    setOldAdvNemFlags(oldNem)
    setNewAdvNemFlags(newNem)
    configureAdvParty(newNem)
    df.global.adventure.player_id = newNem.id
    df.global.world.units.adv_unit = newUnit
    oldUnit.idle_area:assign(oldUnit.pos)
    local pos = xyz2pos(dfhack.units.getPosition(newUnit))

    -- reveal the tiles around the bodyswapped unit
    reveal_tile(xyz2pos(pos.x-1, pos.y-1, pos.z))
    reveal_tile(xyz2pos(pos.x,   pos.y-1, pos.z))
    reveal_tile(xyz2pos(pos.x+1, pos.y-1, pos.z))
    reveal_tile(xyz2pos(pos.x-1, pos.y,   pos.z))
    reveal_tile(pos)
    reveal_tile(xyz2pos(pos.x+1, pos.y,   pos.z))
    reveal_tile(xyz2pos(pos.x-1, pos.y+1, pos.z))
    reveal_tile(xyz2pos(pos.x,   pos.y+1, pos.z))
    reveal_tile(xyz2pos(pos.x+1, pos.y+1, pos.z))

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


if not dfhack_flags.module then
    if df.global.gamemode ~= df.game_mode.ADVENTURE then
        qerror("This script can only be used in adventure mode!")
    end

    local unit = args.unit and df.unit.find(tonumber(args.unit)) or dfhack.gui.getSelectedUnit()
    if not unit then
        print("Enter the following if you require assistance: help bodyswap")
        if args.unit then
            qerror("Invalid unit id: " .. args.unit)
        else
            swapAdvUnitPrompt()
            return
        end
    end
    swapAdvUnit(unit)
end

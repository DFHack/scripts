--@ module=true

local dialogs = require('gui.dialogs')
local utils = require('utils')

local makeown = reqscript('makeown')

local function addToCoreParty(nemesis)
    -- Adds them to the party core members list
    local party = df.global.adventure.interactions
    -- problem: the "brain" icon deciding on manual/automatic control is somewhat broken.
    -- research leads me to believe the data is stored per-unit or unit ID, need to figure out
    -- where that data is stored exactly. Might be one of the unknown variables?
    party.party_core_members:insert('#', nemesis.figure.id)
    local extra_member_idx, _ = utils.linear_index(party.party_extra_members, nemesis.figure.id)
    if extra_member_idx then
        party.party_extra_members:erase(extra_member_idx)
    end
    -- Adds them to unretire list
    nemesis.flags.ADVENTURER = true

    -- Make sure they're no longer nameless
    local unit = df.unit.find(nemesis.figure.unit_id)
    makeown.name_unit(unit)
    if not nemesis.figure.name.has_name then
        local old_name = nemesis.figure.name
        nemesis.figure.name = unit.name:new()
        old_name:delete()
    end
end

local function showExtraPartyPrompt()
    local choices = {}
    for _, histfig_id in ipairs(df.global.adventure.interactions.party_extra_members) do
        local hf = df.historical_figure.find(histfig_id)
        if not hf then goto continue end
        local nemesis, unit = df.nemesis_record.find(hf.nemesis_id), df.unit.find(hf.unit_id)
        if not nemesis or not unit or unit.flags2.killed then goto continue end
        local name = dfhack.units.getReadableName(unit)
        table.insert(choices, {text=name, nemesis=nemesis, search_key=dfhack.toSearchNormalized(name)})
        ::continue::
    end
    dialogs.showListPrompt('party', 'Select someone to add to your "Core Party" (able to assume control, able to unretire):', COLOR_WHITE,
        choices, function(id, choice)
            addToCoreParty(choice.nemesis)
        end, nil, nil, true)
end

function run()
    showExtraPartyPrompt()
end

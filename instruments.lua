-- civilization ID of the player civilization
local civ_id = df.global.plotinfo.civ_id

---@type instrument itemdef_instrumentst
---@return reaction|nil
function getAssemblyReaction(instrument)
    for _, reaction in ipairs(df.global.world.raws.reactions.reactions) do
        if reaction.source_enid == civ_id and
            reaction.category == 'INSTRUMENT' and
            reaction.name:find(instrument.name, 1, true)
        then
            return reaction
        end
    end
    return nil
end

-- patch in thread type
---@type reagent reaction_reagent_itemst
---@return string
function reagentString(reagent)
    if reagent.code == 'thread' then
        local silk = reagent.flags2.silk and "silk " or ""
        local yarn = reagent.flags2.yarn and "yarn " or ""
        local plant = reagent.flags2.plant and "plant " or ""
        return  silk..yarn..plant.."thread"
    else
        return reagent.code
    end
end

---@type reaction reaction
---@return string
function describeReaction(reaction)
    local skill = df.job_skill[reaction.skill]
    local reagents = {}
    for _, reagent in ipairs(reaction.reagents) do
        table.insert(reagents, reagentString(reagent))
    end
    return skill .. ": " .. table.concat(reagents, ", ")
end

-- gather instrument piece reactions and index them by the instrument they are part of
local instruments = {}
for _, reaction in ipairs(df.global.world.raws.reactions.reactions) do
    if reaction.source_enid == civ_id and reaction.category == 'INSTRUMENT_PIECE' then
        local iname = reaction.name:match("[^ ]+ ([^ ]+)")
        table.insert(ensure_key(instruments, iname),
                     reaction.name.." ("..describeReaction(reaction)..")")
    end
end

-- go over instruments
for _,instrument in ipairs(df.global.world.raws.itemdefs.instruments) do
    if not (instrument.source_enid == civ_id) then goto continue end

    local building_tag = instrument.flags.PLACED_AS_BUILDING and " (building, " or " (handheld, "
    local reaction = getAssemblyReaction(instrument)
    dfhack.print(instrument.name..building_tag)
    if #instrument.pieces == 0 then
        print(describeReaction(reaction)..")")
    else
        print(df.job_skill[reaction.skill].."/assemble)")
        for _,str in pairs(instruments[instrument.name]) do
            print("  "..str)
        end
    end
    print()
    ::continue::
end

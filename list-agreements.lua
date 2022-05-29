-- Lists all Guildhall and Temple agreements with Org. Names

--[====[

list-agreements
===============

Lists all Guildhall and Temple agreements in fortress mode.

Additionally:
* Translated names of the associated Orders and Guilds

* Worshiped Deitys and Professions respectively

* Petition age and status satisfied, denied or expired, or blank for outstanding


]====]
local playerfortid = df.global.ui.site_id -- Player fortress id
local templeagreements = {} -- Table of agreements for temples in player fort
local guildhallagreements = {} -- Table of agreements for guildhalls in player fort

function get_location_name(loctier,loctype)
    local locstr
    if loctype == df.abstract_building_type.TEMPLE and loctier == 1 then
        locstr = "Temple"
    elseif loctype == df.abstract_building_type.TEMPLE and loctier == 2 then
        locstr = "Temple Complex"
    elseif loctype == df.abstract_building_type.GUILDHALL and loctier == 1 then
        locstr = "Guildhall"
    elseif loctype == df.abstract_building_type.GUILDHALL and loctier == 2 then
        locstr = "Grand Guildhall"
    end
    return locstr
end

function get_petition_date(agr)
    agr_year = agr.details[0].year
    agr_year_tick = agr.details[0].year_tick
    julian_day = math.floor(agr_year_tick / 1200) + 1
    agr_month = math.floor(julian_day / 28) + 1
    agr_day = julian_day % 28
    return string.format("%03d-%02d-%02d",agr_year, agr_month, agr_day)
end

function get_petition_age(agr)
    agr_year_tick = agr.details[0].year_tick
    agr_year = agr.details[0].year
    cur_year_tick = df.global.cur_year_tick
    cur_year = df.global.cur_year
    --delta, check to prevent off by 1 error, not validated
    if cur_year_tick > agr_year_tick then
        del_year = cur_year - agr_year
        del_year_tick = cur_year_tick - agr_year_tick
    else
        del_year = cur_year - agr_year - 1
        del_year_tick = agr_year_tick - cur_year_tick
    end
    julian_day = math.floor(del_year_tick / 1200) + 1
    del_month = math.floor(julian_day / 28)
    del_day = julian_day % 28
    return {del_year,del_month,del_day}
end

function get_guildhall_profession(agr)
    prof = agr.details[0].data.Location.profession
    profname = string.lower(df.profession[prof])
    -- *VERY* important code follows
    if string.find(profname, "man") then
        profname = string.gsub(profname,"man",string.lower(dfhack.units.getRaceNameById(df.global.ui.race_id)))
    end
    return profname:gsub("_", " ")
end

function get_agr_party_name(agr)
    --assume party 0 is guild/order, 1 is local government as siteid = playerfortid
    party_id = agr.parties[0].entity_ids[0]
    party_name = dfhack.TranslateName(df.global.world.entities.all[party_id].name, true)
    return party_name
end

function get_deity_name(agr)
    religion_id = agr.details[0].data.Location.deity_data.Religion
    for _,deity_id in ipairs(df.global.world.entities.all[religion_id].relations.deities) do
        return dfhack.TranslateName(df.global.world.history.figures[deity_id].name,true)
    end
end

function is_satisfied(agr)
    satisfied = agr.flags.convicted_accepted
    return satisfied
end

function is_denied(agr)
    denied = agr.flags.petition_not_accepted
    return denied
end

function is_expired(agr)
    local expired = false
    agr_age = get_petition_age(agr)
    if agr_age[1] ~= 0 then
        expired = true
    end
    return expired
end

--universal handler
function generate_output(agr,loctype)
    local loc_name = get_location_name(agr.details[0].data.Location.tier,loctype)
    local agr_age = get_petition_age(agr)
    output_str = "Establish a ".. loc_name.." for \""..get_agr_party_name(agr)
    if loctype == df.abstract_building_type.TEMPLE then
        output_str = output_str.."\" worshiping '"..get_deity_name(agr)..",'"
    elseif loctype == df.abstract_building_type.GUILDHALL then
        output_str = output_str.."\", a "..get_guildhall_profession(agr).." guild,"
    else
        print("Agreement with unknown org")
        return
    end
    output_str = output_str.."\n\tas agreed on "..get_petition_date(agr)..". \t"..agr_age[1].."y, "..agr_age[2].."m, "..agr_age[3].."d ago"
    if is_satisfied(agr) then
        print( output_str.." (satisfied)")
    elseif is_denied(agr) then
        print(output_str.." (denied)")
    elseif is_expired(agr) then
        print(output_str.." (expired)")
    else
        print(output_str)
    end
end

---------------------------------------------------------------------------
-- Main Script operation
---------------------------------------------------------------------------

local args = {...}
local cmd = args[1]



for _, agr in pairs(df.agreement.get_vector()) do
    if agr.details[0].data.Location.site == playerfortid then
        if get_location_type(agr) == df.abstract_building_type.TEMPLE then
            table.insert(templeagreements, agr)
        elseif get_location_type(agr) == df.abstract_building_type.GUILDHALL then
            table.insert(guildhallagreements, agr)
        end
    end
end

print "-----------------------"
print "Agreements for Temples:"
print "-----------------------"
if next(templeagreements) == nil then
    print "No agreements"
else
    for _, agr in pairs(templeagreements) do
        generate_output(agr,df.abstract_building_type.TEMPLE)
    end
end

print ""
print "--------------------------"
print "Agreements for Guildhalls:"
print "--------------------------"
if next(guildhallagreements) == nil then
    print "No agreements"
else
    for _, agr in pairs(guildhallagreements) do
        generate_output(agr,df.abstract_building_type.GUILDHALL)
    end
end

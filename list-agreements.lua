-- Lists all guildhall and temple agreements

--[====[

list-agreements
===============

Lists all guildhall and temple agreements in fortress mode.

]====]

local playerfortid = df.global.ui.site_id -- Player fortress id
local templeagreements = {} -- Table of agreements for temples in player fort
local guildhallagreements = {} -- Table of agreements for guildhalls in player fort

function get_location_tier(agr)
    loctier = agr.details[0].data.Location.tier
    return loctier
end

function get_location_type(agr)
    loctype = agr.details[0].data.Location.type
    return loctype
end

function get_location_name(agr)
    if get_location_type(agr) == df.abstract_building_type.TEMPLE and get_location_tier(agr) == 1 then
        return "temple"
    elseif get_location_type(agr) == df.abstract_building_type.TEMPLE and get_location_tier(agr) == 2 then
        return "temple complex"
    elseif get_location_type(agr) == df.abstract_building_type.GUILDHALL and get_location_tier(agr) == 1 then
        return "guildhall"
    elseif get_location_type(agr) == df.abstract_building_type.GUILDHALL and get_location_tier(agr) == 2 then
        return "grand guildhall"
    end
end

function get_petition_date(agr)
    agr_year = agr.details[0].year
    agr_year_tick = agr.details[0].year_tick
    julian_day = math.floor(agr_year_tick / 1200) + 1
    agr_month = math.floor(julian_day / 28) + 1
    agr_day = julian_day % 28
    return agr_year.."-"..agr_month.."-"..agr_day
end

function get_guildhall_profession(agr)
    prof = agr.details[0].data.Location.profession
    profname = string.lower(df.profession[prof])
    return profname:gsub("_", " ")
end

function get_religion_name(agr)
    religion_id = agr.details[0].data.Location.deity_data.Religion
    religion_name = dfhack.TranslateName(df.global.world.entities.all[religion_id].name, true)
    return religion_name
end

function is_satisfied(agr)
    satisfied = agr.flags.convicted_accepted
    return satisfied
end

function is_denied(agr)
    denied = agr.flags.petition_not_accepted
    return denied
end

function generate_output_guild(agr)
    if is_satisfied(agr) == true then
        print("Establish a "..get_location_name(agr).." for the "..get_guildhall_profession(agr).." guild, as agreed on "..get_petition_date(agr).." (satisfied)")
    elseif is_denied(agr) == true then
        print("Establish a "..get_location_name(agr).." for the "..get_guildhall_profession(agr).." guild, as agreed on "..get_petition_date(agr).." (denied)")
    else
        print("Establish a "..get_location_name(agr).." for the "..get_guildhall_profession(agr).." guild, as agreed on "..get_petition_date(agr))
    end
end

function generate_output_temple(agr)
    if is_satisfied(agr) == true then
        print("Establish a "..get_location_name(agr).." for "..get_religion_name(agr)..", as agreed on "..get_petition_date(agr).." (satisfied)")
    elseif is_denied(agr) == true then
        print("Establish a "..get_location_name(agr).." for "..get_religion_name(agr)..", as agreed on "..get_petition_date(agr).." (denied)")
    else
        print("Establish a "..get_location_name(agr).." for "..get_religion_name(agr)..", as agreed on "..get_petition_date(agr))
    end
end

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
print "Agreements for temples:"
print "-----------------------"
if next(templeagreements) == nil then
    print "No agreements"
else
    for _, agr in pairs(templeagreements) do
        generate_output_temple(agr)
    end
end

print ""
print "--------------------------"
print "Agreements for guildhalls:"
print "--------------------------"
if next(guildhallagreements) == nil then
    print "No agreements"
else
    for _, agr in pairs(guildhallagreements) do
        generate_output_guild(agr)
    end
end

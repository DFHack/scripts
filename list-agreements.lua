-- Lists outstanding Guildhall and Temple agreements with Org. Names

--[====[

list-agreements
===============

Lists outstanding Guildhall and Temple agreements in fortress mode.

Additionally:


* Translated names of the associated Orders and Guilds
* Worshiped Deitys and Professions respectively
* Petition age and status satisfied, denied or expired, or blank for outstanding



Arguments
---------------

    all     list all agreements; past and present

    help    script help

]====]
local playerfortid = df.global.ui.site_id -- Player fortress id
local templeagreements = {} -- Table of agreements for temples in player fort
local guildhallagreements = {} -- Table of agreements for guildhalls in player fort

function get_location_name(loctier,loctype)
    local locstr = "Unknown Location"
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

function get_location_type(agr)
    loctype = agr.details[0].data.Location.type
    return loctype
end

function get_petition_date(agr)
    local agr_year = agr.details[0].year
    local agr_year_tick = agr.details[0].year_tick
    local julian_day = math.floor(agr_year_tick / 1200) + 1
    local agr_month = math.floor(julian_day / 28) + 1
    local agr_day = julian_day % 28
    return string.format("%03d-%02d-%02d",agr_year, agr_month, agr_day)
end

function get_petition_age(agr)
    local agr_year_tick = agr.details[0].year_tick
    local agr_year = agr.details[0].year
    local cur_year_tick = df.global.cur_year_tick
    local cur_year = df.global.cur_year
    local del_year, del_year_tick, del_month, del_day
    --delta, check to prevent off by 1 error, not validated
    if cur_year_tick > agr_year_tick then
        del_year = cur_year - agr_year
        del_year_tick = cur_year_tick - agr_year_tick
    else
        del_year = cur_year - agr_year - 1
        del_year_tick = agr_year_tick - cur_year_tick
    end
    local julian_day = math.floor(del_year_tick / 1200) + 1
    del_month = math.floor(julian_day / 28)
    del_day = julian_day % 28
    return {del_year,del_month,del_day}
end

function get_guildhall_profession(agr)
    local prof = agr.details[0].data.Location.profession
    local profname = string.lower(df.profession[prof])
    -- *VERY* important code follows
    if string.find(profname, "man") then
        profname = string.gsub(profname,"man",string.lower(dfhack.units.getRaceNameById(df.global.ui.race_id)))
    end
    return profname:gsub("_", " ")
end

function get_agr_party_name(agr)
    --assume party 0 is guild/order, 1 is local government as siteid = playerfortid
    local party_id = agr.parties[0].entity_ids[0]
    local party_name = dfhack.TranslateName(df.global.world.entities.all[party_id].name, true)
    return party_name
end

function get_deity_name(agr)
    local religion_id = agr.details[0].data.Location.deity_data.Religion
    for _,deity_id in ipairs(df.global.world.entities.all[religion_id].relations.deities) do
        return dfhack.TranslateName(df.global.world.history.figures[deity_id].name,true)
    end
end


--return resolution status
-- 0 no resolution
-- 1 satisfied
-- 2 denied
-- 3 expired
function is_resolved(agr)
    local resolution = 0
    
    if agr.flags.convicted_accepted then    
        resolution = 1
    elseif agr.flags.petition_not_accepted then
        resolution = 2
    elseif get_petition_age(agr)[1] ~= 0 then
        resolution = 3
    end
    return resolution
end

--universal handler
function generate_output(agr,culling,loctype)
    local loc_name = get_location_name(agr.details[0].data.Location.tier,loctype)
    local agr_age = get_petition_age(agr)
    local output_str = 'Establish a '.. loc_name..' for "'..get_agr_party_name(agr)
    
    if loctype == df.abstract_building_type.TEMPLE then
        output_str = output_str..'" worshiping "'..get_deity_name(agr)..',"'
    elseif loctype == df.abstract_building_type.GUILDHALL then
        output_str = output_str..'", a '..get_guildhall_profession(agr)..' guild,'
    else
        print("Agreement with unknown org")
        return
    end
    
    output_str = output_str..'\n\tas agreed on '..get_petition_date(agr)..'. \t'..agr_age[1]..'y, '..agr_age[2]..'m, '..agr_age[3]..'d ago'
    if culling and (is_resolved(agr) ~= 0) then
        return nil
    elseif is_resolved(agr) == 1 then
        print( output_str.." (satisfied)")
    elseif is_resolved(agr) == 2 then
        print(output_str.." (denied)")
    elseif is_resolved(agr) == 3 then
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
local cull_resolved = true

-- args handler
if cmd then
    if cmd == "all" then
        cull_resolved = false
    elseif cmd == "help" then
        print("list-argeements: \n\t Lists outstanding Guildhall and Temple agreements in fortress mode.")
        print("")
        print("Supported arguments:")
        print("\t all \n\t\t shows all agreements, past and present")
        print("\t help \n\t\t shows this help")
        return
    else 
        print("use list-agreements help for supported arguments")
        return
    end
end

for _, agr in pairs(df.agreement.get_vector()) do
    if agr.details[0].data.Location.site == playerfortid then
		if is_resolved(agr) ~= 0 and cull_resolved then
		else
			if get_location_type(agr) == df.abstract_building_type.TEMPLE then
				table.insert(templeagreements, agr)
			elseif get_location_type(agr) == df.abstract_building_type.GUILDHALL then
				table.insert(guildhallagreements, agr)
			end
		end
    end
end

print "-----------------------"
print "Agreements for Temples:"
print "-----------------------"
if next(templeagreements) == nil then
    if cull_resolved then
        print "No outstanding agreements"
    else
        print "No agreements"
    end
else
    for _, agr in pairs(templeagreements) do
        generate_output(agr,cull_resolved,df.abstract_building_type.TEMPLE)
    end
end

print ""
print "--------------------------"
print "Agreements for Guildhalls:"
print "--------------------------"
if next(guildhallagreements) == nil then
    if cull_resolved then
        print "No outstanding agreements"
    else
        print "No agreements"
    end
else
    for _, agr in pairs(guildhallagreements) do
        generate_output(agr,cull_resolved,df.abstract_building_type.GUILDHALL)
    end
end

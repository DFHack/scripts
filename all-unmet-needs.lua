-- Prints the sum of all citizens' needs.
-- show only needs that needs attention now (damaging focus) and garantee it shows on dwarf overview (example need drink)
-- with arg "n" it adds a TAG NDS_ NEEDS_CODE _NDS to citizens prefix names (example: allneeds n)
-- with arg "r" it removes all NDS TAGS citizens prefix names (example: allneeds r)


--SET SCOPE to handle unique elements (needs)
local setid = {}
local function addToSet(set, key)
    set[key] = true
end

local function removeFromSet(set, key)
    set[key] = nil
end

local function setContains(set, key)
    return set[key] ~= nil
end
--SET SCOPE END

--get only user custom nickname OR default
local function getNick(unit)
    local completeName = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
    local unit_name=string.sub(completeName,0,(string.find(completeName,"\' ") or string.len(completeName)))
    unit_name=string.gsub(unit_name,"\'","")
    unit_name=string.gsub(unit_name,"`","")
    return unit_name
end

local function parse_commandline(args)
    local opts = {}

    for i,v in ipairs(args) do
        if v == 'n' or v == 'add-nicknames' then opts.setnick = true return opts end
        if v == 'r' or v == 'remove-nicknames' then opts.removenick = true return opts end
        if v == 'u' or v == 'update-nicknames' then opts.removenick = true opts.setnick = true return opts end
    end

    return opts
end

local opts = parse_commandline({...})

local convertNeeds = {
    ["Socialize"] = "S",
    ["DrinkAlcohol"] = "DA",
    ["PrayOrMeditate"] = "PM",
    ["StayOccupied"] = "SO",
    ["BeCreative"] = "BC",
    ["Excitement"] = "E",
    ["LearnSomething"] = "LS",
    ["BeWithFamily"] = "Fa",
    ["BeWithFriends"] = "Fr",
    ["HearEloquence"] = "H",
    ["UpholdTradition"] = "T",
    ["SelfExamination"] = "SE",
    ["MakeMerry"] ="M",
    ["CraftObject"] = "CO",
    ["MartialTraining"] = "MT",
    ["PracticeSkill"] = "PS",
    ["TakeItEasy"] ="TE",
    ["MakeRomance"] ="MS",
    ["SeeAnimal"] = "SA",
    ["SeeGreatBeast"] = "SGB",
    ["AcquireObject"] = "AO",
    ["EatGoodMeal"] = "EM",
    ["Fight"] = "Fi",
    ["CauseTrouble"] ="CT",
    ["Argue"] = "A",
    ["BeExtravagant"] = "BE",
    ["Wander"]  ="W",
    ["HelpSomebody"] = "HS",
    ["ThinkAbstractly"] = "TA",
    ["AdmireArt"] = "AA",

}

local fort_needs = {}
for _, unit in pairs(df.global.getCitizens()) do

    local mind = unit.status.current_soul.personality.needs
    -- sum need_level and focus_level for each need
    setid = {}
    for _,need in pairs(mind) do
        --Unfocused need.focus_level -1,000 to -9,999 When a need is satisfied, its value is refreshed to maximum (400), regardless of previous value
        if setContains(setid, need.id) == false and need.focus_level < -999 then --with negative focus this need is doing bad, need attention
            addToSet(setid, need.id) --avoid x3 pray need duplicated
            local needs = ensure_key(fort_needs, need.id)
            needs.cumulative_need = (needs.cumulative_need or 0) + need.need_level
            needs.cumulative_focus = (needs.cumulative_focus or 0) + need.focus_level
            needs.citizen_count = (needs.citizen_count or 0) + 1
            if needs.units == nil then needs.units = {} end
            table.insert(needs.units, unit)

        end
    end

    unit_name=getNick(unit)
    if opts.removenick and string.find(unit_name, "NDS_") then
        dfhack.units.setNickname(unit, string.sub(unit_name, string.find(unit_name, "_NDS")+5))
    end

end

local sorted_fort_needs = {}
for id, need in pairs(fort_needs) do
    table.insert(sorted_fort_needs, {
        df.need_type[id],
        need.cumulative_need,
        need.cumulative_focus,
        need.citizen_count,
        need.units,
    })
end

table.sort(sorted_fort_needs, function(a, b)
    return a[2] > b[2]
end)

-- Print sorted output
print(([[%20s %8s %8s %10s]]):format("Need", "Weight", "Focus", "# Dwarves"))
for i, need in pairs(sorted_fort_needs) do
    local names = ""
    --if i < 4 then --CAN limit only the firsts #3 needs
        for _, unit in pairs(need[5]) do
            local modResult = ""
            local nickMod = convertNeeds[need[1]]
            unit_name=getNick(unit)
            if opts.setnick and not string.find(unit_name, nickMod) then
                if string.find(unit_name, "NDS_") then --arready mod
                    local endString = string.find(unit_name, "_NDS")+4
                    local nick = string.sub(unit_name, endString)
                    local prevNeeds = string.sub(unit_name, string.find(unit_name, "NDS_"), endString-5)
                    modResult = prevNeeds .. nickMod .. " _NDS" .. nick
                else
                    modResult = ("NDS_ %s _NDS %s"):format(nickMod, unit_name)
                end
                dfhack.units.setNickname(unit,modResult)
            end
            names = names .. modResult
        end
    --end

    --print(([[%20s %8.f %8.f %10d %20s]]):format(need[1] .. " ".. convertNeeds[need[1]], need[2], need[3], need[4],  names)) --DEBUG show units names
    print(([[%20s %8.f %8.f %10d]]):format(need[1] .. " ".. convertNeeds[need[1]], need[2], need[3], need[4]))
end

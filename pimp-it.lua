local rng = require('plugins.cxxrandom')
local utils = require('utils')
local dorf_tables = dfhack.script_environment('dorf_tables')
dorf_tables.ResetProfessionTable()
local validArgs = utils.invert({
    'applyjob',
    'applyprofession',
    'applytype',
    'selected',
    'cleardwarf',
    'cleardwarves',
    'debug'
})
local args = utils.processArgs({...}, validArgs)

function DisplayTable(t,query,field)
    print('###########################')
    for i,k in pairs(t) do
        if query ~= nil then
            if string.find(i, query) then
                if field ~= nil then
                    print(i,k,k[field])
                else
                    print(i,k)
                end
            end
        else
            if field ~= nil then
                print(i,k,k[field])
            else
                print(i,k)
            end
        end
    end
    print('###########################')
end

function count_this(to_be_counted)
    local count = -1
    local var1 = ""
    while var1 ~= nil do
        count = count + 1
        var1 = (to_be_counted[count])
    end
    count=count-1
    return count
end

function ArrayLength(t)
    local count = 0
    for i,k in pairs(t) do
        if tonumber(i) then
            count = count + 1
        end
    end
    return count
end

function TableLength(table)
    local count = 0
    for i,k in pairs(table) do
        count = count + 1
    end
    return count
end

function FindValueKey(t, value)
    for k,v in pairs(t) do
        if v == value then
            return k
        end
    end
end

function FindKeyValue(t, key)
    for k,v in pairs(t) do
        if k == key then
            return v
        end
    end
end

function GetRandomTableEntry(tName, t)
    -- iterate over whole table to get all keys
    local keyset = {}
    for k in pairs(t) do
        table.insert(keyset, k)
    end
    -- now you can reliably return a random key
    local N = TableLength(t)
    local i = rng.RollIndex(tName, N)
    local key = keyset[i]
    local R = t[key]
    if args.debug and tonumber(args.debug) >= 3 then print(N,i,key,R) end
    return R
end

function GetRandomAttribLevel()
    local N = TableLength(dorf_tables.attrib_levels)
    rng.ResetIndexRolls("attrib levels", N)
    while true do
        local level = GetRandomTableEntry("attrib levels", dorf_tables.attrib_levels)
        if rng.RollBool(level.p) then
            return level
        end
    end
    return nil
end

function isValidProfession(profession, incr)
    local prof = dorf_tables.professions[profession]
    assert(df.profession[profession], "Invalid profession: " .. profession .. " (not a built-in profession, no id found)")
    if prof ~= nil and prof.cur ~= nil and prof.max ~= nil then
        if args.debug and tonumber(args.debug) >= 2 then print("prof.max = " .. prof.max, "prof.cur = " .. prof.cur) end
        if (prof.cur + incr) <= prof.max then
            if prof.ratio ~= nil then
                local limit = (prof.ratio * dwarf_count)
                limit = limit < 1.0 and limit >= 0.5 and math.ceil(limit) or math.floor(limit)
                if args.debug and tonumber(args.debug) >= 3 then print("prof.ratio = " .. prof.ratio, "dwarf_count = " .. dwarf_count, "limit = " .. limit) end
                if (prof.cur + incr) <= limit then
                    return true
                else
                    --surpassed ratio
                    return false
                end
            else
                --no ratio to compare against
                return true
            end
        end
    end
    return false
end

function isValidJob(job) --job is a dorf_jobs.<job> table
    if job ~= nil and job.req ~= nil then
        for i, prof in pairs(job.req) do
            if args.debug and tonumber(args.debug) >= 4 then print("isValidJob() req loop it#" .. i .. " prof:" .. prof) end
            if not isValidProfession(prof, 1) then
                return false
            end
        end
        return true
    end
    return false
end

--Gets the skill table for a skill id from a particular dwarf
function GetSkillTable(dwf, skill)
    local id = df.job_skill[skill]
    assert(id, "Invalid skill - GetSkillTable(" .. skill .. ")")
    for _,skillTable in pairs(dwf.status.current_soul.skills) do
        if skillTable.id == id then
            return skillTable
        end
    end
    if args.debug and tonumber(args.debug) >= 0 then print("Could not find skill: " .. skill) end
    return nil
end

function GenerateStatValue(stat, atr_lvl)
    atr_lvl = atr_lvl == nil and GetRandomAttribLevel() or dorf_tables.attrib_levels[atr_lvl]
    if args.debug and tonumber(args.debug) >= 4 then print(atr_lvl, atr_lvl[1], atr_lvl[2]) end
    local value = math.floor(rng.RollNormal(atr_lvl[1], atr_lvl[2]))
    value = value < 0 and 0 or value
    value = value > 5000 and 5000 or value
    stat.value = stat.value < value and value or stat.value
end

function LoopStatsTable(statsTable, callback)
    local ok,f,t,k = pcall(pairs,statsTable)
    if ok then
        for k,v in f,t,k do
            callback(v)
        end
    end
end

function ApplyType(dwf, dorf_type)
    local type = dorf_tables.dorf_types[dorf_type]
    assert(type, "Invalid dorf type.")
    for attribute, atr_lvl in pairs(type.attribs) do
        if args.debug and tonumber(args.debug) >= 3 then print(attribute, atr_lvl) end
        if 
        attribute == 'STRENGTH' or
        attribute == 'AGILITY' or
        attribute == 'TOUGHNESS' or
        attribute == 'ENDURANCE' or
        attribute == 'RECUPERATION' or
        attribute == 'DISEASE_RESISTANCE'
        then
            GenerateStatValue(dwf.body.physical_attrs[attribute], atr_lvl[1])
        elseif 
        attribute == 'ANALYTICAL_ABILITY' or
        attribute == 'FOCUS' or
        attribute == 'WILLPOWER' or
        attribute == 'CREATIVITY' or
        attribute == 'INTUITION' or
        attribute == 'PATIENCE' or
        attribute == 'MEMORY' or
        attribute == 'LINGUISTIC_ABILITY' or
        attribute == 'SPATIAL_SENSE' or
        attribute == 'MUSICALITY' or
        attribute == 'KINESTHETIC_SENSE' or
        attribute == 'EMPATHY' or
        attribute == 'SOCIAL_AWARENESS'
        then
            GenerateStatValue(dwf.status.current_soul.mental_attrs[attribute], atr_lvl[1])
        else
            error("Invalid stat:" .. attribute)
        end
    end
    if type.skills ~= nil then
        for skill, skillRange in pairs(type.skills) do
            local sTable = GetSkillTable(dwf, skill)
            if sTable == nil then
                utils.insert_or_update(dwf.status.current_soul.skills, { new = true, id = df.job_skill[skill], rating = 0 }, 'id')
                sTable = GetSkillTable(dwf, skill)
            end
            local points = rng.RollInt(skillRange[1], skillRange[2])
            sTable.rating = sTable.rating < points and points or sTable.rating
            sTable.rating = sTable.rating > 20 and 20 or sTable.rating
            if args.debug and tonumber(args.debug) >= 2 then print(skill .. ".rating = " .. sTable.rating) end
        end
    end
end

--Apply only after previously validating
function ApplyProfession(dwf, profession, incr, min, max)
    local prof = dorf_tables.professions[profession]
    prof.cur = prof.cur + incr
    for skill, bonus in pairs(prof.skills) do
        local sTable = GetSkillTable(dwf, skill)
        if sTable == nil then
            utils.insert_or_update(dwf.status.current_soul.skills, { new = true, id = df.job_skill[skill], rating = 0 }, 'id')
            sTable = GetSkillTable(dwf, skill)
        end
        local points = rng.RollInt(min, max)
        sTable.rating = sTable.rating < points and points or sTable.rating
        sTable.rating = sTable.rating + bonus
        sTable.rating = sTable.rating > 20 and 20 or sTable.rating
        if args.debug and tonumber(args.debug) >= 2 then print(skill .. ".rating = " .. sTable.rating) end
    end
end

--Apply only after previously validating
function ApplyJob(dwf, job) --job is a dorf_jobs.<job> table
    local jobName = FindValueKey(dorf_tables.dorf_jobs, job)
    RollStats(dwf, job.types)
    -- set custom profession
    dwf.custom_profession = jobName
    -- Apply required professions
    local bAlreadySetProf2 = false
    for i, prof in pairs(job.req) do
        --> Set Profession(s) (by #)
        if i == 1 then
            dwf.profession = df.profession[prof]
        elseif i == 2 then
            bAlreadySetProf2 = true
            dwf.profession2 = df.profession[prof]
        end
        --These are required professions and were checked before running ApplyJob
        ApplyProfession(dwf, prof, 1.0, 11, 17)
    end
    
    -- Apply priority professions
    if job.prio ~= nil then
        local prioLength = ArrayLength(job.prio)
        local prioCount = 0
        --> max= math.ceil( total / (2 or 3) )
        local prioMax = math.ceil(prioLength / 2)
        rng.ResetIndexRolls(jobName .. ".job.prio", prioLength)
        for i=1,prioLength do
            --> Select random profession
            local prof = GetRandomTableEntry(jobName .. ".job.prio", job.prio)
            -->> Check isValid
            if isValidProfession(prof, 0.7) and (prioCount < prioMax) then
                prioCount = prioCount + 1
                --> Set Profession 2 if not already done (by #)
                if not bAlreadySetProf2 then
                    bAlreadySetProf2 = true
                    dwf.profession2 = df.profession[prof]
                end
                ApplyProfession(dwf, prof, 0.7, 7, 10)
            end
        end
    end
    
    -- Loop tertiary professions
    for prof, p in pairs(job) do
        if tonumber(p) then
            if isValidProfession(prof, 0.3) then
                --> proc probability
                if rng.RollBool(p) then
                    ApplyProfession(dwf, prof, 0.3, 1, 5)
                end
            end
        end
    end
end

function RollStats(dwf, types)
    LoopStatsTable(dwf.body.physical_attrs, GenerateStatValue)
    LoopStatsTable(dwf.status.current_soul.mental_attrs, GenerateStatValue)
    for i, type in pairs(types) do
        if args.debug and tonumber(args.debug) >= 4 then print(i, type) end
        ApplyType(dwf, type)
    end
    for type, table in pairs(dorf_tables.dorf_types) do
        local p = table.p
        if p ~= nil then
            if rng.RollBool(p) then
                ApplyType(dwf, type)
            end
        end
    end
end

function FindJob(dwf)
    if dwf.custom_profession == "" then
        local totalJobs = TableLength(dorf_tables.dorf_jobs)
        rng.ResetIndexRolls("dorf jobs", totalJobs)
        for i=1,totalJobs do
            local job = GetRandomTableEntry("dorf jobs", dorf_tables.dorf_jobs)
            if args.debug and tonumber(args.debug) >= 2 then print("FindJob() iteration #" .. i, FindValueKey(job)) end
            if isValidJob(job) then
                if args.debug and tonumber(args.debug) >= 1 then print("Found a job!") end
                ApplyJob(dwf, job)
                return true
            end
        end
        error("No job found, that is bad?!")
        return false
    end
end

function ZeroDwarf(dwf)
    LoopStatsTable(dwf.body.physical_attrs, function(attribute) attribute.value = 0 end)
    LoopStatsTable(dwf.status.current_soul.mental_attrs, function(attribute) attribute.value = 0 end)
    local count_max = count_this(df.job_skill)
    utils.sort_vector(dwf.status.current_soul.skills, 'id')
    for i=0, count_max do
        utils.erase_sorted_key(dwf.status.current_soul.skills, i, 'id')
    end
    dwf.custom_profession = ""
end

function LoopDwarfCitizens(units, callback)
    local count = 0
    for _, unit in pairs(units) do
        if dfhack.units.isCitizen(unit) then
            count = count + 1
            if callback ~= nil then
                callback(unit)
            end
        end
    end
    return count
end


--[[
    'applyjob',
    'applyprofession',
    'applytype',
    'selected',
    'cleardwarf',
    'cleardwarves',
    'debug'
--]]

local SelectedUnit = nil
local ActiveUnits = df.global.world.units.active
dwarf_count = 0

selection_count = 0
local selection = nil
if args.selected or args.cleardwarf or args.applyjob or args.applyprofession or args.applytype then
    SelectedUnit = dfhack.gui.getSelectedUnit()
    if args.selected or args.cleardwarf then
        selection = {}
        table.insert(selection, SelectedUnit)
    end
else
    selection = ActiveUnits
end

dwarf_count = LoopDwarfCitizens(ActiveUnits)
selection_count = LoopDwarfCitizens(selection)
print(dwarf_count .. " dwarves")
print(selection_count .. " dorf(s) selected")

if not (args.cleardwarves or args.cleardwarf or args.applyjob or args.applyprofession or args.applytype) then
    LoopDwarfCitizens(selection, FindJob)
    print(selection_count .. " dorf(s) have been pimped.")
elseif args.cleardwarves or args.cleardwarf then
    LoopDwarfCitizens(selection, ZeroDwarf)
    print(selection_count .. " dorf(s) have been reset to zero.")
elseif dfhack.units.isCitizen(SelectedUnit) then
    local dwf = SelectedUnit
    if args.applyjob then
        if dorf_tables.dorf_jobs[args.applyjob] then
            ApplyJob(dwf, args.applyjob)
        else
            error("Invalid job: " .. args.applyjob)
        end
    elseif args.applyprofession then
        if dorf_tables.professions[args.applyprofession] then
            ApplyProfession(dwf, args.applyprofession)
        else
            error("Invalid profession: " .. args.applyprofession)
        end
    elseif args.applytype then
        if dorf_tables.dorf_types[args.applytype] then
            ApplyType(dwf, args.applytype)
        else
            error("Invalid type: " .. args.applytype)
        end
    end
end

rng.BlastDistributions()
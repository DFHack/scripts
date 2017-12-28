utils = require('utils')
json = require('json')
local rng = require('plugins.cxxrandom')
print("Loading data tables..")
local dorf_tables = dfhack.script_environment('dorf_tables')
cloned = {} --assurances I'm sure
cloned = {    
	jobs = utils.clone(dorf_tables.dorf_jobs, true),
    professions = utils.clone(dorf_tables.professions, true),
    distributions = utils.clone(dorf_tables.job_distributions, true),
}
print("Done.")
local validArgs = utils.invert({
	'applyjob',
    'applyprofession',
    'applytype',
    'selected',
    'clear', --selected --all --allnamed --allcustom --allpimped --allunpimped --allcustomunpimped --allprotected --allunprotected
	'clearfirst',       --all --allnamed --allcustom --allpimped --allunpimped --allcustomunpimped --allprotected --allunprotected
	'reroll',
    'debug'
})
local args = utils.processArgs({...}, validArgs)
protected_dwarf_signals = {'_', 'c', 'j', 'p'}


function LoadPersistentData()
	local gamePath = dfhack.getDFPath()
	local fortName = dfhack.TranslateName(df.world_site.find(df.global.ui.site_id).name)
	local savePath = dfhack.getSavePath()
	local fileName = fortName .. ".json.dat"
	local cur = json.open(gamePath .. "/data/save/current/" .. fileName)
	local saved = json.open(savePath .. "/" .. fileName)
	print("loading data...")
	if saved.exists == true and cur.exists == false then
		print("Previous session save data found.")
		cur.data = saved.data
	elseif saved.exists == false then
		--saved:write()
	elseif cur.exists == true then
		print("Existing session data found.")
	end
	PimpData = cur.data
end

function SavePersistentData()
	local gamePath = dfhack.getDFPath()
	local fortName = dfhack.TranslateName(df.world_site.find(df.global.ui.site_id).name)
	local fileName = fortName .. ".json.dat"
	local cur = json.open(gamePath .. "/data/save/current/" .. fileName)
	cur.data = PimpData
	cur:write()
end

function safecompare(a,b)
    if a == b then
        return 0
    elseif tonumber(a) and tonumber(b) then
        if a < b then
            return -1
        elseif a > b then
            return 1
        end
    elseif tonumber(a) then
        return 1
    else
        return -1
    end
end

function twofield_compare(t,v1,v2,f1,f2,cmp1,cmp2)
    local a = t[v1]
    local b = t[v2]
    local c1 = cmp1(a[f1],b[f1])
    local c2 = cmp2(a[f2],b[f2])
    if c1 == 0 then
        return c2
    end
    return c1
end

function spairs(t, cmp)
    -- collect the keys
    local keys = {}
    for k,v in pairs(t) do
        table.insert(keys,k)
    end

    utils.sort_vector(keys, nil, cmp)
    
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function GetChar(str,i)
    return string.sub(str,i,i)
end

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

function count_this(to_be_counted, field)
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
    local i = rng.rollIndex(tName, N)
    local key = keyset[i]
    local R = t[key]
    if args.debug and tonumber(args.debug) >= 3 then print(N,i,key,R) end
    return R
end

function GetRandomAttribLevel()
    local N = TableLength(dorf_tables.attrib_levels)
    rng.resetIndexRolls("attrib levels", N)
    while true do
        local level = GetRandomTableEntry("attrib levels", dorf_tables.attrib_levels)
        if rng.rollBool(level.p) then
            return level
        end
    end
    return nil
end

--Returns true if the DWARF has a name (nickname) this dwarf is treated as sacred unless '-clear* allnamed' is specified
function isDwarfNamed(dwf)
    return dwf.status.current_soul.name.nickname ~= ""
end

--Returns true if the DWARF has a custom_profession
function isDwarfCustom(dwf)
    if dwf.custom_profession ~= "" or isDwarfNamed(dwf) then
        return true
    end
    return false
end

--Returns true if the DWARF has a job
function isDwarfPimped(dwf)
    local jobName = dwf.custom_profession
    local job = cloned.jobs[jobName]
    if job then
        return true
    end
    return false
end

--Returns true if the DWARF is a drunk with no job
function isDwarfUnpimped(dwf)
    return (not isDwarfPimped(dwf))
end

--Returns true if the DWARF is custom, but also probably a drunk
function isDwarfCustomUnpimped(dwf)
    if isDwarfCustom(dwf) and isDwarfUnpimped(dwf) then
        return true
    end
    return false
end

--Returns true if the DWARF has a job, or is custom with protection
function isDwarfProtected(dwf)
    if isDwarfNamed(dwf) or isDwarfPimped(dwf) then
        return true
    end
    if dwf.custom_profession ~= "" then
        for _,signal in pairs(protected_dwarf_signals) do
            if GetChar(dwf.custom_profession, 1) == signal then
                return true
            end
        end
    end
    return false
end

--Returns true if the DWARF has no job and or is not custom with protection
function isDwarfUnprotected(dwf)
    return (not isDwarfProtected(dwf))
end

function isValidJob(job) --job is a dorf_jobs.<job> table
    if job ~= nil and job.req ~= nil then
        local jobName = FindValueKey(cloned.jobs, job)
        local jd = cloned.distributions[jobName]
        if not jd then
            error("Job distribution not found. Job: " .. jobName)
        end
        if PimpData[jobName].count < jd.max then
            return true
        end
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
    local value = math.floor(rng.rollNormal(atr_lvl[1], atr_lvl[2]))
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
                --print("ApplyType()", skill, skillRange)
                utils.insert_or_update(dwf.status.current_soul.skills, { new = true, id = df.job_skill[skill], rating = 0 }, 'id')
                sTable = GetSkillTable(dwf, skill)
            end
            local points = rng.rollInt(skillRange[1], skillRange[2])
            sTable.rating = sTable.rating < points and points or sTable.rating
            sTable.rating = sTable.rating > 20 and 20 or sTable.rating
            sTable.rating = sTable.rating < 0 and 0 or sTable.rating
            if args.debug and tonumber(args.debug) >= 2 then print(skill .. ".rating = " .. sTable.rating) end
        end
    end
end

--Apply only after previously validating
function ApplyProfession(dwf, profession, min, max)
    local prof = cloned.professions[profession]
    --todo: implement persistent profession counting
    --prof.cur = prof.cur + 1
    for skill, bonus in pairs(prof.skills) do
        local sTable = GetSkillTable(dwf, skill)
        if sTable == nil then
            utils.insert_or_update(dwf.status.current_soul.skills, { new = true, id = df.job_skill[skill], rating = 0 }, 'id')
            sTable = GetSkillTable(dwf, skill)
        end
        local points = rng.rollInt(min, max)
        sTable.rating = sTable.rating < points and points or sTable.rating
        sTable.rating = sTable.rating + bonus
        sTable.rating = sTable.rating > 20 and 20 or sTable.rating
        sTable.rating = sTable.rating < 0 and 0 or sTable.rating
        if args.debug and tonumber(args.debug) >= 2 then print(skill .. ".rating = " .. sTable.rating) end
    end
end

--Apply only after previously validating
function ApplyJob(dwf, job) --job = dorf_jobs[X]
	local jobName = FindValueKey(cloned.jobs, job)
	local jd = cloned.distributions[jobName]
	PimpData[jobName].count = PimpData[jobName].count + 1
	jd.cur = PimpData[jobName].count
	local id = tostring(dwf.id)
	DwarvesData[id] = {}
	DwarvesData[id]['job'] = jobName
	DwarvesData[id]['professions'] = {}
	if not PimpData[jobName] then
		PimpData[jobName] = {}
	end
	dwf.custom_profession = jobName
    RollStats(dwf, job.types)
    
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
        ApplyProfession(dwf, prof, 12, 17)
    end
        
    -- Loop tertiary professions
	-- Sort loop (asc)
	--[[]]
	local points = 11
	local base_dec = 11 / job.max[1]
	local total = 0
	for prof, t in spairs(PimpData[jobName].profs, 
	function(a,b)
		return twofield_compare(PimpData[jobName].profs, 
		a, b, 'count', 'p',
		function(f1,f2) return safecompare(f1,f2) end, 
		function(f1,f2) return safecompare(f2,f1) end) 
	end) 
	do--]]
		if total < job.max[1] then
			local ratio = job[prof]
			local max = math.ceil(points)
			local min = math.ceil(points - 5)
			min = min < 0 and 0 or min
			--Firsts are special
			if PimpData[jobName].profs[prof].count < (ratio * PimpData[jobName].count) and points > 7.7 then
				ApplyProfession(dwf, prof, min, max)
				table.insert(DwarvesData[id]['professions'], prof)
				PimpData[jobName].profs[prof].count = PimpData[jobName].profs[prof].count + 1
				if args.debug and tonumber(args.debug) >= 1 then print("dwf id:", dwf.id, "count: ", PimpData[jobName].profs[prof].count, jobName, prof) end
				
				if not bAlreadySetProf2 then
					bAlreadySetProf2 = true
					dwf.profession2 = df.profession[prof]
				end
				points = points - base_dec
				total = total + 1
			else
				local p = PimpData[jobName].profs[prof].count > 0 and (1 - (ratio / ((ratio*PimpData[jobName].count) / PimpData[jobName].profs[prof].count))) or ratio
				p = p < 0 and 0 or p
				p = p > 1 and 1 or p
				--p = (p - math.floor(p)) >= 0.5 and math.ceil(p) or math.floor(p)
				--> proc probability and check points
				if points >= 1 and rng.rollBool(p) then
					ApplyProfession(dwf, prof, min, max)
					table.insert(DwarvesData[id]['professions'], prof)
					PimpData[jobName].profs[prof].count = PimpData[jobName].profs[prof].count + 1
					if args.debug and tonumber(args.debug) >= 1 then print("dwf id:", dwf.id, "count: ", PimpData[jobName].profs[prof].count, jobName, prof) end
					
					if not bAlreadySetProf2 then
						bAlreadySetProf2 = true
						dwf.profession2 = df.profession[prof]
					end
					points = points - base_dec
					total = total + 1
				end
			end
		end
	end
    if not bAlreadySetProf2 then
        dwf.profession2 = dwf.profession
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
            if rng.rollBool(p) then
                ApplyType(dwf, type)
            end
        end
    end
end

--Returns true if a job was found and applied, returns false otherwise
function FindJob(dwf, recursive)
    if isDwarfProtected(dwf) then
        return false
    end
    --local totalJobs = TableLength(cloned.jobs)
    --rng.resetIndexRolls("find a job", totalJobs)
    for jobName, jd in spairs(cloned.distributions, 
    function(a,b)
        return twofield_compare(cloned.distributions, 
        a, b, 'cur', 'max',
        function(a,b) return safecompare(a,b) end, 
        function(a,b) return safecompare(b,a) end) 
   end) 
    do
        if args.debug and tonumber(args.debug) >= 4 then print("FindJob() ", jobName) end
        local job = cloned.jobs[jobName]
        if isValidJob(job) then
            if args.debug and tonumber(args.debug) >= 1 then print("Found a job!") end
            ApplyJob(dwf, job)
            pimped_count = pimped_count + 1
            return true
        end
    end
    if not recursive and TrySecondPassExpansion() then
        return FindJob(dwf, true)
    end
    print(":WARNING: No job found, that is bad?!")
    return false
end

function TrySecondPassExpansion() --Tries to expand distribution maximums
    local curTotal = 0
    for k,v in pairs(cloned.distributions) do
        if v.cur ~= nil then
            curTotal = curTotal + v.cur
        end
    end

    if curTotal < work_force then
        local I = 0
        for i, v in pairs(cloned.distributions.Thresholds) do
            if work_force >= v then
                I = i + 1
            end
        end

        local delta = 0
        for jobName, jd in spairs(cloned.distributions, 
        function(a,b)
            return twofield_compare(cloned.distributions, 
            a, b, 'max', 'cur',
            function(a,b) return safecompare(a,b) end, 
            function(a,b) return safecompare(a,b) end) 
        end) 
        do
            if cloned.jobs[jobName] then
                if (curTotal + delta) < work_force then
                    delta = delta + jd[I]
                    jd.max = jd.max + jd[I]
                end
            end
        end
        return true
    end
    return false
end

function ZeroDwarf(dwf)
	zeroed_count = zeroed_count + 1
	
	LoopStatsTable(dwf.body.physical_attrs, function(attribute) attribute.value = 0 end)
    LoopStatsTable(dwf.status.current_soul.mental_attrs, function(attribute) attribute.value = 0 end)

	local count_max = count_this(df.job_skill)
    utils.sort_vector(dwf.status.current_soul.skills, 'id')
    for i=0, count_max do
        utils.erase_sorted_key(dwf.status.current_soul.skills, i, 'id')
    end

	dfhack.units.setNickname(dwf, "")
    dwf.custom_profession = ""
    dwf.profession = df.profession['DRUNK']
	dwf.profession2 = df.profession['DRUNK']

	for id, dwf_data in pairs(DwarvesData) do
		if next(dwf_data) ~= nil and id == tostring(dwf.id) then
			print("Clearing loaded dwf data for dwf id: " .. id)
			local jobName = dwf_data.job
			local job = cloned.jobs[jobName]
			PimpData[jobName].count = PimpData[jobName].count - 1
			for i, prof in pairs(dwf_data.professions) do
				PimpData[jobName].profs[prof].count = PimpData[jobName].profs[prof].count - 1
				if args.debug and tonumber(args.debug) >= 1 then print("dwf id:", dwf.id, "count: ", PimpData[jobName].profs[prof].count, jobName, prof) end
			end
			DwarvesData[tostring(id)] = {}
		elseif next(dwf_data) == nil and id == tostring(dwf.id) then
			print(":WARNING: ZeroDwarf(dwf) - dwf was zeroed, but had never been pimped before")
			--error("this dwf_data shouldn't be nil, I think.. I guess maybe if you were clearing dwarves that weren't pimped")
		end
	end
end

function TryClearDwarf(dwf)
    if args.clear and args.clearfirst then
        error(":ERROR: Please use clearfirst OR clear, not both.")
    end

    local options = args.clear or args.clearfirst
    if options ~= nil then
        if isDwarfNamed(dwf) then
            if args.clear and (options == 'all' or options == 'selected' or options == 'allnamed') then
                ZeroDwarf(dwf)
            elseif args.clearfirst and options == 'allnamed' then
                ZeroDwarf(dwf)
            end
        elseif options == 'all' then
            ZeroDwarf(dwf)
        elseif options == 'allcustom' and isDwarfCustom(dwf) then
            ZeroDwarf(dwf)
        elseif options == 'allpimped' and isDwarfPimped(dwf) then
            ZeroDwarf(dwf)
        elseif options == 'allunpimped' and isDwarfUnpimped(dwf) then
            ZeroDwarf(dwf)
        elseif options == 'allcustomunpimped' and isDwarfCustomUnpimped(dwf) then
            ZeroDwarf(dwf)
        elseif options == 'allprotected' and isDwarfProtected(dwf) then
            ZeroDwarf(dwf)
        elseif options == 'allunprotected' and isDwarfUnprotected(dwf) then
            ZeroDwarf(dwf)
        elseif args.clear and options == 'selected' then
            TryClearDwarf(dwf)
        elseif options ~= 'allnamed' then
            if 
            options ~= 'allcustom' and 
            options ~= 'allpimped' and 
            options ~= 'allunpimped' and 
            options ~= 'allcustomunpimped' and 
            options ~= 'allprotected' and 
            options ~= 'allunprotected'
            then
                error(":ERROR: Please use a valid argument for -clearfirst\n{all, selected, allcustom, allpimped, allunpimped, allcustomunpimped, allprotected, allunprotected")
            end
        end
    else
        if args.clear then
            error(":ERROR: Please use a valid argument\n-clear: {all, selected, allnamed, allcustom, allpimped, allunpimped, allcustomunpimped, allprotected, allunprotected}")
        elseif args.clearfirst then
            error(":ERROR: Please use a valid argument\n-clearfirst: {all, allnamed, allcustom, allpimped, allunpimped, allcustomunpimped, allprotected, allunprotected}")
        end
	end
	if args.reroll and cloned.jobs[args.reroll] then
		if dwf.custom_profession == args.reroll then
			ZeroDwarf(dwf)
		end
	end
end

function LoopUnits(units, check, fn)
    local count = 0
    for _, unit in pairs(units) do
        if check(unit) then
            count = count + 1
            if fn ~= nil then
                fn(unit)
            end
        end
    end
    return count
end

function isDwarfCitizen(dwf)
    return dfhack.units.isCitizen(dwf)
end

function CanWork(dwf)
    return dfhack.units.isCitizen(dwf) and dfhack.units.isAdult(dwf)
end

function Prepare()
	print("Preparing the tables..")
	LoadPersistentData()
	if not PimpData.Dwarves then
		PimpData.Dwarves = {}
	end
	DwarvesData = PimpData.Dwarves

	--Initialize PimpData
	for jobName, job in pairs(cloned.jobs) do
		PrepareDistribution(jobName)
		if not PimpData[jobName] then
			PimpData[jobName] = {}
			PimpData[jobName].count = 0
			PimpData[jobName].profs = {}
		end
		for prof, p in pairs(job) do
			if tonumber(p) then
				if not PimpData[jobName].profs[prof] then
					--print("making " .. prof .. " in " .. jobName .. "'s table: " .. PimpData[jobName])
					PimpData[jobName].profs[prof] = {}
					PimpData[jobName].profs[prof].p = p
					PimpData[jobName].profs[prof].count = 0
				end
			end
		end
	end
	
	--Count Professions from 'DwarvesData'
	--[[for id, dwf_data in pairs(DwarvesData) do
		local jobName = dwf_data.job
		local job = cloned.jobs[jobName]
		local profs = dwf_data.professions
		PimpData[jobName].count = PimpData[jobName].count + 1
		for i, prof in pairs(profs) do
			PimpData[jobName].profs[prof].count = PimpData[jobName].profs[prof].count + 1
		end
	end--]]

	--TryClearDwarf Loop (or maybe not)
	print("Tables are set.")
end

function PrepareDistribution(jobName)
	local jd = cloned.distributions[jobName]
	if not jd then
		error("Job distribution not found. Job: " .. jobName)
	end
	if jd.max == nil then
		local IndexMax = 0
		for i, v in pairs(cloned.distributions.Thresholds) do
			if work_force >= v then
				IndexMax = i
			end
		end
		--print(cloned.distributions.Thresholds[IndexMax])
		local max = 0
		for i=1, IndexMax do
			max = max + jd[i]
		end 
		jd.max = max
	end
end


local SelectedUnit = nil
local ActiveUnits = df.global.world.units.active
dwarf_count = 0
work_force = 0
pimped_count = 0
zeroed_count = 0
selection_count = 0
local selection = nil
if args.selected or (args.clear and args.clear == "selected") or args.applyjob or args.applyprofession or args.applytype then
    SelectedUnit = dfhack.gui.getSelectedUnit()
    assert(SelectedUnit, "Error: you must select a unit")
    if args.selected or args.cleardwarf then
        selection = {}
        table.insert(selection, SelectedUnit)
    end
else
    selection = ActiveUnits
end


dwarf_count = LoopUnits(ActiveUnits, dfhack.units.isCitizen)
work_force = LoopUnits(ActiveUnits, CanWork)
--selection_count = LoopUnits(selection, function() return true end)
print("\nDwarf Population: " .. dwarf_count)
print("Work Force: " .. work_force)
Prepare()

if args.clear then
    LoopUnits(selection, CanWork, TryClearDwarf)
    print(zeroed_count .. " dorf(s) have been reset to zero.")
else
    if not (args.applyjob or args.applyprofession or args.applytype) then
        print("\nPimping Dwarves..")
        LoopUnits(selection, CanWork, TryClearDwarf)
        LoopUnits(selection, CanWork, FindJob)
        print("\n")
        print("cur", "max", "job", "\n  ~~~~~~~~~")
        for k,v in pairs(cloned.distributions) do
            print(v.cur, v.max, k)
        end
        print("Results\n---------")
        print(zeroed_count .. " dorf(s) were reset to zero.")
        print(pimped_count .. " dorf(s) were pimped out.")
    elseif dfhack.units.isCitizen(SelectedUnit) then
        local dwf = SelectedUnit
        TryClearDwarf(dwf)
        if args.applyjob then
            if cloned.jobs[args.applyjob] then
                ApplyJob(dwf, args.applyjob)
            else
                error("Invalid job: " .. args.applyjob)
            end
        elseif args.applyprofession then
            if cloned.professions[args.applyprofession] then
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
    else
        error("You did something wrong. Where's the poop!")
    end
end

SavePersistentData()
print('\n')
function Query(table, query, parent) if not parent then parent = "" end for k,v in pairs(table) do if string.find(tostring(k), query) then print(parent .. "." .. k) end if type(v) == "table" and not string.find(parent, tostring(k)) then if parent then Query(v, query, parent .. "." .. k) else Query(v, query, k) end end end end 
--Query(PimpData, "", "pd")
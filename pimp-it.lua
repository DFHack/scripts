utils ={}
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
    'help',
    'debug',

    'select', --highlighted --all --named --unnamed --employed --pimped --unpimped --protected --unprotected --drunks --jobs
    'clear',
    'reroll',
    'pimpem',

    'applyjobs',
    'applyprofessions',
    'applytypes'
})
local args = utils.processArgs({...}, validArgs)
if args.debug and tonumber(args.debug) >= 0 then print("Debug info [ON]") end
protected_dwarf_signals = {'_', 'c', 'j', 'p'}
if args.select and args.select == 'pimped' then
    if args.pimpem and not args.clear then
        error("Invalid arguments detected. You've selected only pimped dwarves, and are attempting to pimp them without clearing them. This will not work, so I'm warning you about it with this lovely error.")
    end
end

function LoadPersistentData()
	local gamePath = dfhack.getDFPath()
	local fortName = dfhack.TranslateName(df.world_site.find(df.global.ui.site_id).name)
	local savePath = dfhack.getSavePath()
	local fileName = fortName .. ".json.dat"
	local cur = json.open(gamePath .. "/data/save/current/" .. fileName)
	local saved = json.open(savePath .. "/" .. fileName)
	if saved.exists == true and cur.exists == false then
		print("Previous session save data found.")
		cur.data = saved.data
    elseif saved.exists == false then
        print("No session data found. All dwarves will be treated as non-pimped.")
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

function TableToString(t)
    local s = '['
    local n=0
    for k,v in pairs(t) do
        n=n+1
        if n ~= 1 then
            s = s .. ", "
        end
        s = s .. tostring(v)
    end
    s = s .. ']'
    return s
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
    local R = rng.rollNormal(atr_lvl[1], atr_lvl[2])
    local value = math.floor(R)
    value = value < 0 and 0 or value
    value = value > 5000 and 5000 or value
    stat.value = stat.value < value and value or stat.value
    if args.debug and tonumber(args.debug) >= 3 then print(R, stat.value) end
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
        if args.debug and tonumber(args.debug) >= 3 then print(attribute, atr_lvl[1]) end
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
    return true
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
    return true
end

--Apply only after previously validating
function ApplyJob(dwf, jobName) --job = dorf_jobs[X]
    local jd = cloned.distributions[jobName]
    local job = cloned.jobs[jobName]
    if args.debug and tonumber(args.debug) >= 3 then print(dwf,job,jobName, PimpData[jobName]) end
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
    return true
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
    if isDwarfPimped(dwf) then
        return false
    end
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
            ApplyJob(dwf, jobName)
            --pimped_count = pimped_count + 1
            return true
        end
    end
    --not recursive => not recursively called (yet~)
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
			DwarvesData[id] = {}
		elseif next(dwf_data) == nil and id == tostring(dwf.id) then
			print(":WARNING: ZeroDwarf(dwf) - dwf was zeroed, but had never been pimped before")
			--error("this dwf_data shouldn't be nil, I think.. I guess maybe if you were clearing dwarves that weren't pimped")
		end
	end
end

function Reroll(dwf)
    local jobName = dwf.custom_profession
    if cloned.jobs[jobName] then
        if args.reroll ~= 'inclusive' then
            ZeroDwarf(dwf)
        end
        ApplyJob(dwf, jobName)
    end
end

function LoopUnits(units, check, fn, checkoption, profmin, profmax) --cause nothing else will use arg 5 or 6
    local count = 0
    for _, unit in pairs(units) do
        if check ~= nil then
            if check(unit, checkoption, profmin, profmax) then
                if fn ~= nil then
                    if fn(unit) then
                        count = count + 1
                    end
                else
                    count = count + 1
                end
            end
        elseif fn ~= nil then
            if fn(unit) then
                count = count + 1
            end
        end
    end
    if args.debug and tonumber(args.debug) >= 1 then
        print("loop count: ", count)
    end
    return count
end

function LoopTable_Apply_ToUnits(units, apply, applytable, checktable, profmin, profmax) --cause nothing else will use arg 5 or 6
    local count = 0
    local temp = 0
    for _,tvalue in pairs(applytable) do
        if checktable[tvalue] then
            temp = LoopUnits(units, apply, nil, tvalue, profmin, profmax)
            count = count < temp and temp or count
        else
            error("\nInvalid option: " .. tvalue .. "\nLook-up table: " .. checktable)
        end
    end
    return count
end

------------
--CHECKERS--
------------

--Returns true if the DWARF has a user-given name
function isDwarfNamed(dwf)
    return dwf.status.current_soul.name.nickname ~= ""
end

--Returns true if the DWARF has a custom_profession but isn't pimped
function isDwarfEmployed(dwf)
    return dwf.custom_profession ~= "" and (not isDwarfPimped(dwf))
end

--Returns true if the DWARF is in the DwarvesData table
function isDwarfPimped(dwf)
    local id = tostring(dwf.id)
    local pimp = DwarvesData[id]
    return pimp ~= nil
end

--Returns true if the DWARF is a drunk with no job
function isDwarfUnpimped(dwf)
    return (not isDwarfPimped(dwf))
end

--Returns true if the DWARF uses a protection signal in its name or profession
function isDwarfProtected(dwf)
    if dwf.custom_profession ~= "" then
        for _,signal in pairs(protected_dwarf_signals) do
            if GetChar(dwf.custom_profession, 1) == signal then
                return true
            end
        end
    end
    if dwf.status.current_soul.name.nickname ~= "" then
        for _,signal in pairs(protected_dwarf_signals) do
            if GetChar(dwf.status.current_soul.name.nickname, 1) == signal then
                return true
            end
        end
    end
    return false
end

--Returns true if the DWARF doesn't use a protection signal in its name or profession
function isDwarfUnprotected(dwf)
    return (not isDwarfProtected(dwf))
end

function isDwarfCitizen(dwf)
    return dfhack.units.isCitizen(dwf)
end

function CanWork(dwf)
    return dfhack.units.isCitizen(dwf) and dfhack.units.isAdult(dwf)
end

function CheckWorker(dwf, option)
    if CanWork(dwf) then
        --selection options
        if option == 'protected' then
            return isDwarfProtected(dwf)
        elseif isDwarfUnprotected(dwf) then
            if option == 'all' then
                return true
            elseif option == 'highlighted' then
                return dwf == dfhack.gui.getSelectedUnit()
            elseif option == 'named' then
                return isDwarfNamed(dwf)
            elseif option == 'unnamed' then
                return (not isDwarfNamed(dwf))
            elseif option == 'employed' then
                return isDwarfEmployed(dwf)
            elseif option == 'pimped' then
                return isDwarfPimped(dwf)
            elseif option == 'unpimped' then
                return isDwarfUnpimped(dwf)
            elseif option == 'unprotected' then
                return isDwarfUnprotected(dwf)
            elseif option == 'drunks' or option == 'drunk' then
                return dwf.profession == df.profession['DRUNK'] and dwf.profession2 == df.profession['DRUNK']
            elseif type(option) == 'table' then
                if option[1] == 'job' or option[1] == 'jobs' then
                    n=0
                    for _,v in pairs(option) do
                        n=n+1
                        if n > 1 and dwf.custom_profession == v then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

----------------
--END CHECKERS--
----------------

function Prepare()
	print("Loading persistent data..")
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
        if PimpData[jobName].count == nil then
            PimpData[jobName].count = 0
        end
		for prof, p in pairs(job) do
			if tonumber(p) then
				if not PimpData[jobName].profs[prof] then
					--print("making " .. prof .. " in " .. jobName .. "'s table: " .. PimpData[jobName])
					PimpData[jobName].profs[prof] = {}
					PimpData[jobName].profs[prof].p = p
					PimpData[jobName].profs[prof].count = 0
				else
					PimpData[jobName].profs[prof].p = p
				end
			end
		end
    end
    if args.debug and tonumber(args.debug) >= 4 then
        print("PimpData, job counts")
        DisplayTable(PimpData,nil,'count')
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
	print("Data load complete.")
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

function SelectDwarf(dwf)
    table.insert(selection, dwf)
end

function ShowHelp()
    print("\nusage: pimp-it [-help|-select]")
    print("               -select <sel-opt> -<command> <args>")
    ShowHint()
    print("~~~~~~~~~~~~")
    print(" select options:\n  (protected is the only option which will select PROTECTED dwarves)")
    print("    all         - selects all dwarves.")
    print("    highlighted - selects only the in-game highlighted dwarf (from any screen).")
    print("    named       - selects dwarves with user-given names.")
    print("    unnamed     - selects dwarves without user-given names.")
    print("    employed    - selects dwarves with custom professions. Excludes pimped dwarves.")
    print("    pimped      - selects dwarves based on session data. Dwarves who have been pimped, should be listed in this data.")
    print("    unpimped    - selects any dwarves that don't appear in session data.")
    print("    protected   - selects any dwarves which use protection signals in their name or profession. (ie. {'_', 'c', 'j', 'p'})")
    print("    unprotected - selects any dwarves which don't use protection signals in their name or profession.")
    print("    drunks      - selects any dwarves which are currently zeroed, or were originally drunks as their profession.")
    print("    jobs        - selects any dwarves with the listed job types. This will only match with custom professions, or pimped dwarves (for pimped dorfs see: dorf_jobs in dorf_tables.lua).")
    print("                - usage `-select [ jobs job1 job2 etc. ]` eg. `-select [ jobs Miner Trader ]`")
    print("~~~~~~~~~~~~")
    print("Commands will run on the selected dwarves\n available commands:")
    print("    clear              - zeroes selected dwarves. No attributes, no labours. Assigns 'DRUNK' profession.")
    print("    reroll <inclusive> - zeroes selected dwarves, then rerolls that dwarf based on its job. Ignores dwarves with unlisted jobs.")
    print("                       - optional argument: inclusive. Only performs the reroll, will no zero the dwarf first. Benefit: stats can only go higher, not lower.")
    print("    pimpem             - performs a job search for unpimped dwarves. Each dwarf will be found a job according to the job_distribution table in dorf_tables.lua")
    print("    applyjobs          - applies the listed jobs to the selected dwarves. list format: `[ job1 job2 jobn ]` brackets and jobs all separated by spaces.")
    print("                       - see dorf_jobs table in dorf_tables.lua for available jobs.")
    print("    applyprofessions   - applies the listed professions to the selected dwarves. list format: `[ prof1 prof2 profn ]` brackets and professions all separated by spaces.")
    print("                       - see professions table in dorf_tables.lua for available professions.")
    print("    applytypes         - applies the listed types to the selected dwarves. list format: `[ type1 type2 typen ]` brackets and types all separated by spaces.")
    print("                       - see dorf_types table in dorf_tables.lua for available types.")
    print("~~~~~~~~~~~~\n\tOther Arguments:")
    print("\t\thelp - displays this help information.")
    print("\t\tdebug - enables debugging print lines")

    print("No dorfs were harmed in the building of this help screen.")
end

function ShowHint()
    print("\n============\npimp-it script")
    print("~~~~~~~~~~~~")
    print("To use this script, you need to select a subset of your dwarves. Then run commands on those dwarves.")
    print("Examples:")
    print("  [DFHack]# pimp-it -select [ jobs Trader Miner Leader Warden ] -applytype adaptable")
    print("  [DFHack]# pimp-it -select all -clear -pimpem")
    print("  [DFHack]# pimp-it -select pimped -reroll")
    print("  [DFHack]# pimp-it -select named -reroll inclusive -applyprofession RECRUIT")
end

local ActiveUnits = df.global.world.units.active
dwarf_count = LoopUnits(ActiveUnits, isDwarfCitizen)
work_force = LoopUnits(ActiveUnits, CanWork)
Prepare()
print('\nActive Units Population: ' .. ArrayLength(ActiveUnits))
print("Dwarf Population: " .. dwarf_count)
print("Work Force: " .. work_force)
print("Existing Pimps: " .. ArrayLength(PimpData.Dwarves))

function exists(thing)
    if thing then return true else return false end
end
args.b_clear = exists(args.clear) if args.debug and tonumber(args.debug) >= 0 then print(        "args.b_clear:    " .. tostring(args.b_clear)) end
args.b_pimpem = exists(args.pimpem) if args.debug and tonumber(args.debug) >= 0 then print(      "args.b_pimpem:   " .. tostring(args.b_pimpem)) end
args.b_reroll = exists(args.reroll) if args.debug and tonumber(args.debug) >= 0 then print(      "args.b_reroll:   " .. tostring(args.b_reroll)) end
args.b_applyjobs = exists(args.applyjobs) if args.debug and tonumber(args.debug) >= 0 then print("args.b_applyjob: " .. tostring(args.b_applyjobs)) end
if args.help then
    ShowHelp()
elseif args.select and (args.debug or args.clear or args.pimpem or args.reroll or args.applyjobs or args.applyprofessions or args.applytypes) then
    selection = {}
    count = 0
    print("Selected Dwarves: " .. LoopUnits(ActiveUnits, CheckWorker, SelectDwarf, args.select))
    
    if args.b_clear ~= args.b_reroll or not args.b_clear then
        --error("Clear is implied with Reroll. Choose one, not both.")
        if args.b_reroll and args.b_pimpem and args.b_applyjobs then
            error("options: pimpem, reroll, applyjob. Choose one, and only one.")
        elseif args.b_reroll ~= args.b_pimpem ~= args.b_applyjobs or not args.b_reroll then
            --
            --Valid options were entered
            --
            local affected = 0
            local temp = 0
            if args.clear then
                print("\nResetting selected dwarves..")
                temp = LoopUnits(selection, nil, ZeroDwarf)
                affected = affected < temp and temp or affected
            end
            
            if args.pimpem then
                print("\nPimping selected dwarves..")
                temp = LoopUnits(selection, nil, FindJob)
                affected = affected < temp and temp or affected
            elseif args.reroll then
                print("\nRerolling selected dwarves..")
                temp = LoopUnits(selection, nil, Reroll)
                affected = affected < temp and temp or affected
            elseif args.applyjobs then
                if type(args.applyjobs) == 'table' then
                    print("Applying jobs:" .. TableToString(args.applyjobs) .. ", to selected dwarves")
                    temp = LoopTable_Apply_ToUnits(selection, ApplyJob, args.applyjobs, cloned.jobs)
                else
                    print("Applying job:" .. args.applyjobs .. ", to selected dwarves")
                    if cloned.jobs[args.applyjobs] then
                        temp = LoopUnits(selection, ApplyJob, nil, args.applyjobs)
                    else
                        error("Invalid job: " .. args.applyjobs)
                    end
                end
                affected = affected < temp and temp or affected
            end
            
            if args.applyprofessions then
                if type(args.applyprofessions) == 'table' then
                    print("Applying professions:" .. TableToString(args.applyprofessions) .. ", to selected dwarves")
                    temp = LoopTable_Apply_ToUnits(selection, ApplyProfession, args.applyprofessions, cloned.professions,1,5)
                else
                    print("Applying professions:" .. args.applyprofessions .. ", to selected dwarves")
                    if cloned.professions[args.applyprofessions] then
                        temp = LoopUnits(selection, ApplyProfession, nil, args.applyprofessions,1,5)
                    else
                        error("Invalid profession: " .. args.applyprofessions)
                    end
                end
                affected = affected < temp and temp or affected
            elseif args.applytypes then
                if type(args.applytypes) == 'table' then
                    print("Applying types:" .. TableToString(args.applytypes) .. ", to selected dwarves")
                    temp = LoopTable_Apply_ToUnits(selection, ApplyType, args.applytypes, dorf_tables.dorf_types)
                else
                    print("Applying type:" .. args.applytypes .. ", to selected dwarves")
                    if dorf_tables.dorf_types[args.applytypes] then
                        temp = LoopUnits(selection, ApplyType, nil, args.applytypes)
                    else
                        error("Invalid type: " .. args.applytypes)
                    end
                end
                affected = affected < temp and temp or affected
            end    
            print(affected .. " dwarves affected.")

            if args.debug and tonumber(args.debug) >= 1 then
                print("\n")
                print("cur", "max", "job", "\n  ~~~~~~~~~")
                for k,v in pairs(cloned.distributions) do
                    print(v.cur, v.max, k)
                end
            end
            --
            --Valid options code block ending
            --
        else
            error("options: pimpem, reroll, applyjob. Choose one, and only one.")
        end
    else
        error("Clear is implied with Reroll. Choose one, not both.")
    end
else
    ShowHint()
end
SavePersistentData()
print('\n')

function safe_pairs(item, keys_only)
    if keys_only then
        local mt = debug.getmetatable(item)
        if mt and mt._index_table then
            local idx = 0
            return function()
                idx = idx + 1
                if mt._index_table[idx] then
                    return mt._index_table[idx]
                end
            end
        end
    end
    local ret = table.pack(pcall(function() return pairs(item) end))
    local ok = ret[1]
    table.remove(ret, 1)
    if ok then
        return table.unpack(ret)
    else
        return function() end
    end
end

function Query(table, query, parent)
	if not parent then
		parent = ""
	end
	for k,v in safe_pairs(table) do
		if not tonumber(k) and type(k) ~= "table" and not string.find(tostring(k), 'script') then
			if string.find(tostring(k), query) then
				print(parent .. "." .. k)
			end
			--print(parent .. "." .. k)
			if not string.find(parent, tostring(k)) then
				if parent then
					Query(v, query, parent .. "." .. k)
				else
					Query(v, query, k)
				end
			end
		end
	end
end
--Query(dfhack, '','dfhack')
--Query(PimpData, '', 'pd')

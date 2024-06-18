-- gives dwarves unique nicknames

local options = {}

local argparse = require('argparse')
local commands = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() options.help = true end},
    {'q', 'quiet', handler=function() options.quiet = true end},
})

if #commands ~= 1 or commands[1] ~= "all" then
    options.help = true
end

if options.help == true then
    print(dfhack.script_help())
    return
end

local seen = {}
--check current nicknames
for _,unit in ipairs(dfhack.units.getCitizens()) do
    if unit.name.nickname ~= "" then
        seen[unit.name.nickname] = true
    end
end

local names = {}
-- grab list, put in array
local path = dfhack.getDFPath () .. "/dfhack-config/autonick.txt";
for line in io.lines(path) do
    line = line:trim()
    if (line ~= "")
    and (not line:startswith('#'))
    and (not seen[line]) then
        table.insert(names, line)
        seen[line] = true
    end
end

--assign names
local count = 0
for _,unit in ipairs(dfhack.units.getCitizens()) do
    if (#names == 0) then
            if options.quiet ~= true then
                print("not enough unique names in dfhack-config/autonick.txt")
            end
        break
    end
    --if there are any names left
    if unit.name.nickname == "" then
        newnameIndex = math.random (#names)
        dfhack.units.setNickname(unit, names[newnameIndex])
        table.remove(names, newnameIndex)
        count = count + 1
    end
end

if options.quiet ~= true then
    print(("gave nicknames to %s dwarves."):format(count))
end

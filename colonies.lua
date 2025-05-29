-- List, create, or change wild colonies (eg honey bees)
-- By PeridexisErrant and Warmist

local guidm = require('gui.dwarfmode')

function findVermin(target_verm)
    for k,v in ipairs(df.global.world.raws.creatures.all) do
        if v.creature_id == target_verm then
            return k
        end
    end
    qerror("No vermin found with name: "..target_verm)
end

function list_colonies()
    for idx, col in pairs(df.global.world.event.vermin_colonies) do
        local race = df.global.world.raws.creatures.all[col.race].creature_id
        print(race..'    at  '..col.pos.x..', '..col.pos.y..', '..col.pos.z)
    end
end

function convert_vermin_to(target_verm)
    local vermin_id = findVermin(target_verm)
    local changed = 0
    for _, verm in pairs(df.global.world.event.vermin_colonies) do
        verm.race = vermin_id
        verm.caste = -1 -- check for queen bee?
        verm.amount = 18826
        verm.visible = true
        changed = changed + 1
    end
    print('Converted '..changed..' colonies to '..target_verm)
end

function place_vermin(target_verm)
    local pos = guidm.getCursorPos()
    if not pos then
        qerror("Cursor must be pointing somewhere")
    end
    local verm = df.vermin:new()
    verm.race = findVermin(target_verm)
    verm.flags.is_colony = true
    verm.caste = -1 -- check for queen bee?
    verm.amount = 18826
    verm.visible = true
    verm.pos:assign(pos)
    df.global.world.event.vermin_colonies:insert("#", verm)
    df.global.world.event.vermin:insert("#", verm)
end

local args = {...}
local target_verm = args[2] or "HONEY_BEE"

if args[1] == 'help' or args[1] == '?' then
    print(dfhack.script_help())
elseif args[1] == 'convert' then
    convert_vermin_to(target_verm)
elseif args[1] == 'place' then
    place_vermin(target_verm)
else
    if #df.global.world.event.vermin_colonies < 1 then
        dfhack.printerr('There are no colonies on the map.')
    end
    list_colonies()
end

--@ module = true
local repeatUtil = require('repeat-util')

local GLOBAL_KEY = 'source' -- used for state change hooks and persistence

g_sources_list = g_sources_list or {}

local function persist_state(liquidSources)
    dfhack.persistent.saveSiteData(GLOBAL_KEY, liquidSources)
end

local function formatPos(pos)
    return ('[%d, %d, %d]'):format(pos.x, pos.y, pos.z)
end

local function is_flow_passable(pos)
    local tiletype = dfhack.maps.getTileType(pos)
    local titletypeAttrs = df.tiletype.attrs[tiletype]
    local shape = titletypeAttrs.shape
    local tiletypeShapeAttrs = df.tiletype_shape.attrs[shape]
    return tiletypeShapeAttrs.passable_flow
end

local function load_liquid_source()
    repeatUtil.scheduleEvery(GLOBAL_KEY, 12, 'ticks', function()
        if #g_sources_list == 0 then
            repeatUtil.cancel(GLOBAL_KEY)
        else
            for _, v in ipairs(g_sources_list) do
                local block = dfhack.maps.getTileBlock(v.pos)
                if block and is_flow_passable(v.pos) then
                    local isMagma = v.liquid == 'magma'

                    local flags = dfhack.maps.getTileFlags(v.pos)
                    local flow = flags.flow_size

                    if flow ~= v.amount then
                        local target = flow + 1
                        if flow > v.amount then
                            target = flow - 1
                        end

                        flags.liquid_type = isMagma
                        flags.flow_size = target
                        flags.flow_forbid = (isMagma or target >= 4)

                        dfhack.maps.enableBlockUpdates(block, true)
                    end
                end
            end
        end
    end)
end

local function delete_source_at(idx)
    local v = g_sources_list[idx]

    if v then
        local block = dfhack.maps.getTileBlock(v.pos)
        if block and is_flow_passable(v.pos) then
            local flags = dfhack.maps.getTileFlags(v.pos)
            flags.flow_size = 0
            dfhack.maps.enableBlockUpdates(block, true)
        end
        table.remove(g_sources_list, idx)
    end
end

local function add_liquid_source(pos, liquid, amount)
    local new_source = {liquid = liquid, amount = amount, pos = copyall(pos)}
    print(("Adding %d %s to %s"):format(amount, liquid, formatPos(pos)))
    for k, v in ipairs(g_sources_list) do
        if same_xyz(pos, v.pos) then
            delete_source_at(k)
            break
        end
    end

    table.insert(g_sources_list, new_source)

    load_liquid_source()
end

local function delete_liquid_source(pos)
    print(("Deleting Source at %s"):format(formatPos(pos)))
    for k, v in ipairs(g_sources_list) do
        if same_xyz(pos, v.pos) then
            print("Source Found")
            delete_source_at(k)
            break
        end
    end
end

local function clear_liquid_sources()
    while #g_sources_list > 0 do
        delete_source_at(#g_sources_list)
    end
end

local function list_liquid_sources()
    print('Current Liquid Sources:')
    for _,v in ipairs(g_sources_list) do
        print(('%s %s %d'):format(formatPos(v.pos), v.liquid, v.amount))
    end
end

local function find_liquid_source_at_pos(pos)
    print(("Searching for Source at %s"):format(formatPos(pos)))
    for k,v in ipairs(g_sources_list) do
        if same_xyz(v.pos, pos) then
            print("Source Found")
            return k
        end
    end
    return nil
end

function main(args)
    local command = args[1]

    if not command or command == 'list' then
        list_liquid_sources()
        return
    end

    if command == 'clear' then
        clear_liquid_sources()
        print("Cleared sources")
        return
    end

    local targetPos = copyall(df.global.cursor)
    local index = find_liquid_source_at_pos(targetPos)

    if command == 'delete' then
        if targetPos.x < 0 then
            qerror("Please place the cursor where there is a source to delete")
        end
        if index then
            delete_liquid_source(targetPos)
            print(('Deleted source at %s'):format(formatPos(targetPos)))
        else
            qerror(('%s Does not contain a liquid source'):format(formatPos(targetPos)))
        end
        return
    end

    if command == 'add' then
        if targetPos.x < 0 then
            qerror('Please place the cursor where you would like a source')
        end
        local liquidArg = args[2]
        if not liquidArg then
            qerror('You must specify a liquid to add a source for')
        end
        liquidArg = liquidArg:lower()
        if not (liquidArg == 'magma' or liquidArg == 'water') then
            qerror('Liquid must be either "water" or "magma"')
        end
        if not is_flow_passable(targetPos) then
            qerror("Tile not flow passable: I'm afraid I can't let you do that, Dave.")
        end
        local amountArg = tonumber(args[3]) or 7
        add_liquid_source(targetPos, liquidArg, amountArg)
        print(('Added %s %d at %s'):format(liquidArg, amountArg, formatPos(targetPos)))
        return
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_WORLD_UNLOADED then
        g_sources_list = {}
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    g_sources_list = {}

    -- fix up potential errors in previous versions where the list could be non-contiguous
    for _, v in pairs(data) do
        table.insert(g_sources_list, v)
    end

    load_liquid_source()
end

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr('source needs a loaded fortress map to work')
    return
end

main{...}
persist_state(g_sources_list)

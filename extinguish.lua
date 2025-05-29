-- Puts out fires.
--@ module = true

local guidm = require('gui.dwarfmode')
local utils = require('utils')

local validArgs = utils.invert({
    'all',
    'help'
})
local args = utils.processArgs({ ... }, validArgs)

if args.help then
    print(dfhack.script_help())
    return
end

function extinguishTiletype(tiletype)
    if tiletype == df.tiletype['Fire'] or tiletype == df.tiletype['Campfire'] then
        return df.tiletype['Ashes' .. math.random(1, 3)]
    elseif tiletype == df.tiletype['BurningTreeTrunk'] then
        return df.tiletype['TreeDeadTrunkPillar']
    elseif tiletype == df.tiletype['BurningTreeBranches'] then
        return df.tiletype['TreeDeadBranches']
    elseif tiletype == df.tiletype['BurningTreeTwigs'] then
        return df.tiletype['TreeDeadTwigs']
    elseif tiletype == df.tiletype['BurningTreeCapWall'] then
        return df.tiletype['TreeDeadCapPillar']
    elseif tiletype == df.tiletype['BurningTreeCapRamp'] then
        return df.tiletype['TreeDeadCapRamp']
    elseif tiletype == df.tiletype['BurningTreeCapFloor'] then
        return df.tiletype['TreeDeadCapFloor' .. math.random(1, 4)]
    else
        return tiletype
    end
end

function extinguishTile(x, y, z)
    local tileBlock = dfhack.maps.getTileBlock(x, y, z)
    tileBlock.tiletype[x % 16][y % 16] = extinguishTiletype(tileBlock.tiletype[x % 16][y % 16])
    -- chosen as a 'standard' value; it'd be more ideal to calculate it with respect to the region,
    -- season, undergound status, etc (but DF does this for us when updating temperatures)
    tileBlock.temperature_1[x % 16][y % 16] = 10050
    tileBlock.temperature_2[x % 16][y % 16] = 10050
    tileBlock.flags.update_temperature = true
    tileBlock.flags.update_liquid = true
    tileBlock.flags.update_liquid_twice = true
end

function extinguishContaminant(spatter)
    -- reset temperature of any contaminants to prevent them from causing reignition
    -- (just in case anyone decides to play around with molten gold or whatnot)
    spatter.base.temperature.whole = 10050
    spatter.base.temperature.fraction = 0
end

---@param item df.item
function extinguishItem(item)
    if item.flags.on_fire then
        item.flags.on_fire = false
        item.temperature.whole = 10050
        item.temperature.fraction = 0
        item.flags.temps_computed = false
        if item.contaminants then
            for _, spatter in ipairs(item.contaminants) do
                extinguishContaminant(spatter)
            end
        end
    end
end

function extinguishUnit(unit)
    local burning = false
    for _, status in ipairs(unit.body.components.body_part_status) do
        if not burning then
            if status.on_fire then
                burning = true
                status.on_fire = false
            end
        else
            status.on_fire = false
        end
    end
    if burning then
        for i = #unit.status2.body_part_temperature - 1, 0, -1 do
            unit.status2.body_part_temperature:erase(i)
        end
        unit.flags2.calculated_nerves = false
        unit.flags2.calculated_bodyparts = false
        unit.flags2.calculated_insulation = false
        unit.flags3.body_temp_in_range = false
        unit.flags3.compute_health = true
        unit.flags3.dangerous_terrain = false
        for _, spatter in ipairs(unit.body.spatters) do
            extinguishContaminant(spatter)
        end
    end
end

function extinguishAll()
    local fires = df.global.world.event.fires
    for i = #fires - 1, 0, -1 do
        extinguishTile(pos2xyz(fires[i].pos))
        fires:erase(i)
    end
    local campfires = df.global.world.event.campfires
    for i = #campfires - 1, 0, -1 do
        extinguishTile(pos2xyz(campfires[i].pos))
        campfires:erase(i)
    end
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        extinguishItem(item)
    end
    for _, unit in ipairs(df.global.world.units.active) do
        extinguishUnit(unit)
    end
end

function extinguishLocation(x, y, z)
    local pos = xyz2pos(x, y, z)
    local fires = df.global.world.event.fires
    for i = #fires - 1, 0, -1 do
        if same_xyz(pos, fires[i].pos) then
            extinguishTile(x, y, z)
            fires:erase(i)
        end
    end
    local campfires = df.global.world.event.campfires
    for i = #campfires - 1, 0, -1 do
        if same_xyz(pos, campfires[i].pos) then
            extinguishTile(x, y, z)
            campfires:erase(i)
        end
    end
    local units = dfhack.units.getUnitsInBox(x, y, z, x, y, z)
    for _, unit in ipairs(units) do
        extinguishUnit(unit)
    end
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        if same_xyz(pos, xyz2pos(dfhack.items.getPosition(item))) then
            extinguishItem(item)
        end
    end
end

if dfhack_flags.module then
    return
end

if args.all then
    extinguishAll()
else
    local unit = dfhack.gui.getSelectedUnit(true)
    local item = dfhack.gui.getSelectedItem(true)
    local bld = dfhack.gui.getSelectedBuilding(true)
    if unit then
        extinguishLocation(dfhack.units.getPosition(unit))
    elseif item then
        extinguishLocation(dfhack.items.getPosition(item))
    elseif bld then
        for y = bld.y1, bld.y2 do
            for x = bld.x1, bld.x2 do
                extinguishLocation(x, y, bld.z)
            end
        end
    else
        local pos = guidm.getCursorPos()
        if not pos then
            qerror("Select a target, place the keyboard cursor, or specify --all to extinguish everything on the map.")
        end
        extinguishLocation(pos.x, pos.y, pos.z)
    end
end

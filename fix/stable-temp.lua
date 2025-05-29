local args = { ... }

local apply = (args[1] == 'apply')

local count = 0
local types = {} --as:number[]

local function update_temp(item, btemp)
    if item.temperature.whole ~= btemp then
        count = count + 1
        local tid = item:getType()
        types[tid] = (types[tid] or 0) + 1
    end

    if apply then
        item.temperature.whole = btemp
        item.temperature.fraction = 0

        if item.contaminants then
            for _, c in ipairs(item.contaminants) do
                c.base.temperature.whole = btemp
                c.base.temperature.fraction = 0
            end
        end
    end

    for _, sub in ipairs(dfhack.items.getContainedItems(item)) do --as:df.item_actual
        update_temp(sub, btemp)
    end

    if apply then
        item:checkTemperatureDamage()
    end
end

local last_frame = df.global.world.frame_counter - 1

for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
    if not item.flags.on_ground or
        not df.item_actual:is_instance(item) or
        item.temp_updated_frame ~= last_frame
    then
        goto continue
    end
    local pos = item.pos
    local block = dfhack.maps.getTileBlock(pos)
    if block then
        update_temp(item, block.temperature_1[pos.x % 16][pos.y % 16])
    end
    ::continue::
end

if apply then
    print('Items updated: ' .. count)
else
    print("Use 'fix/stable-temp apply' to normalize temperature.")
    print('Items not in equilibrium: ' .. count)
end

local tlist = {}
for k, _ in pairs(types) do tlist[#tlist + 1] = k end
table.sort(tlist, function(a, b) return types[a] > types[b] end)
for _, k in ipairs(tlist) do
    print('    ' .. df.item_type[k] .. ':', types[k])
end

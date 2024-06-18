-- Reset items in your fort to 0 wear
-- original author: Laggy, edited by expwnent

local args = {...}
local count = 0

if not args[1] or args[1] == 'help' or args[1] == '-h' or args[1] == '--help' then
    print(dfhack.script_help())
    return
elseif args[1] == 'all' or args[1] == '-all' then
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        if item:getWear() > 0 then --hint:df.item_actual
            item:setWear(0)
            count = count + 1
        end
    end
else
    for _, arg in ipairs(args) do
        local item_id = tonumber(arg)
        if item_id then
            local item = df.item.find(item_id)
            if item then
                item:setWear(0)
                count = count + 1
            else
                dfhack.printerr('remove-wear: could not find item: ' .. item_id)
            end
        else
            qerror('Invalid item ID: ' .. arg)
        end
    end
end

print('remove-wear: removed wear from '..tostring(count)..' items')

local argparse = require("argparse")

local water_type = dfhack.matinfo.find('WATER').type

local quiet = false
argparse.processArgsGetopt({...}, {
    {'q', 'quiet', handler=function() quiet = true end},
})

local emptied = 0
local in_building = 0
for _,item in ipairs(df.global.world.items.other.BUCKET) do
    if item.flags.in_job then goto continue end
    local well = dfhack.items.getHolderBuilding(item)
    if well and well:getType() == df.building_type.Well and well.well_tag.whole ~= 0 then
        -- bucket is in a well and the well is actively being used
        goto continue
    end
    local emptied_bucket = false
    local freed_in_building = false
    for _,contained_item in ipairs(dfhack.items.getContainedItems(item)) do
        if not contained_item.flags.in_job and
            contained_item:getMaterial() == water_type and
            contained_item:getType() == df.item_type.LIQUID_MISC
        then
            if item.flags.in_building or contained_item.flags.in_building then
                freed_in_building = true
            end
            -- ok to remove item while iterating since we're iterating through copy of the vector
            dfhack.items.remove(contained_item)
            emptied_bucket = true
        end
    end
    if emptied_bucket then
        emptied = emptied + 1
        df.global.plotinfo.flags.recheck_aid_requests = true
    end
    if freed_in_building then
        in_building = in_building + 1
    end
    ::continue::
end

if not quiet then
    print(('Emptied %d buckets.'):format(emptied))
    if in_building > 0 then
        print(('Unclogged %d wells.'):format(in_building))
    end
end

--@module = true

-----------------------------------------------------------
-- helper functions
-----------------------------------------------------------

-- check whether an item is inside a burrow
local function containsItem(burrow,item)
    local res = false
    local x,y,z = dfhack.items.getPosition(item)
    if x then
        res = dfhack.burrows.isAssignedTile(burrow, xyz2pos(x,y,z))
    end
    return res
end

-- fast reachability test for items that requires precomputed walkability groups for
-- all citizens. Returns false for items w/o valid position (e.g., items in inventories).
--- @param item item
--- @param wgroups table<integer,boolean>
--- @return boolean
function fastReachable(item,wgroups)
    local x, y, z = dfhack.items.getPosition(item)
    if x then -- item has a valid position
        local igroup = dfhack.maps.getWalkableGroup(xyz2pos(x, y, z))
        return not not wgroups[igroup]
    else
        return false
    end
end

--- @return table<integer,boolean>
function citizenWalkabilityGroups()
    local cgroups = {}
    for _, unit in pairs(dfhack.units.getCitizens(true)) do
        local wgroup = dfhack.maps.getWalkableGroup(unit.pos)
        cgroups[wgroup] = true
    end
    cgroups[0] = false -- exclude unwalkable tiles
    return cgroups
end


--- @param tab conditions
--- @param pred fun(_:item):boolean
--- @param negate { negate : boolean }|nil
local function addPositiveOrNegative(tab, pred, negate)
    if negate and negate.negate == true then
        table.insert(tab, function (item) return not pred(item) end)
    else
        table.insert(tab, pred)
    end
end


-----------------------------------------------------------------------
-- external API: helpers to assemble filters and `execute` to execute.
-----------------------------------------------------------------------

--- @alias conditions (fun(item:item):boolean)[]

--- @param tab conditions
--- @param burrow burrow
--- @param negate { negate : boolean }|nil
function condition_burrow(tab,burrow, negate)
    local pred = function (item) return containsItem(burrow, item) end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param match number|string
--- @param negate { negate : boolean }|nil
function condition_type(tab, match, negate)
    local pred = nil
    if type(match) == "string" then
        pred = function (item) return df.item_type[item:getType()] == string.upper(match) end
    elseif type(match) == "number" then
        pred = function (item) return item:getType() == type end
    else error("match argument must be string or number")
    end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param negate { negate : boolean }|nil
function condition_reachable(tab, negate)
    local cgroups = citizenWalkabilityGroups()
    local pred = function(item) return fastReachable(item, cgroups) end
    addPositiveOrNegative(tab, pred, negate)
end

-- uses the singular form without stack size (i.e., prickle berry)
--- @param tab conditions
--- @param pattern string # Lua pattern: https://www.lua.org/manual/5.3/manual.html#6.4.1
--- @param negate { negate : boolean }|nil
function condition_description(tab, pattern, negate)
    local pred =
        function(item)
            -- remove trailing stack size for corpse pieces like "wool" (work around DF bug)
            local desc = dfhack.items.getDescription(item, 1):gsub(' %[%d+%]','')
            return not not desc:find(pattern)
        end
     addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param material string
--- @param negate { negate : boolean }|nil
function condition_material(tab, material, negate)
    local pred = function(item) return dfhack.matinfo.decode(item):toString() == material end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param match string
--- @param negate { negate : boolean }|nil
function condition_matcat(tab, match, negate)
    if df.dfhack_material_category[match] ~= nil then
        local pred =
            function (item)
                local matinfo = dfhack.matinfo.decode(item)
                return matinfo:matches{[match]=true}
            end
        addPositiveOrNegative(tab, pred, negate)
    else
        qerror("invalid material category")
    end
end

--- @param tab conditions
--- @param lower number # range: 0 (pristine) to 3 (XX)
--- @param upper number # range: 0 (pristine) to 3 (XX)
--- @param negate { negate : boolean }|nil
function condition_wear(tab, lower, upper, negate)
    local pred = function(item) return lower <= item.wear and item.wear <= upper end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param lower number # range: 0 (standard) to 5 (masterwork)
--- @param upper number # range: 0 (standard) to 5 (masterwork)
--- @param negate { negate : boolean }|nil
function condition_quality(tab, lower, upper, negate)
    local pred = function(item) return lower <= item:getQuality() and item:getQuality() <= upper end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param negate { negate : boolean }|nil
function condition_forbid(tab, negate)
    local pred = function(item) return item.flags.forbid end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param negate { negate : boolean }|nil
function condition_melt(tab, negate)
    local pred = function (item) return item.flags.melt end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param negate { negate : boolean }|nil
function condition_dump(tab, negate)
    local pred = function(item) return item.flags.dump end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
function condition_hidden(tab, negate)
    local pred = function(item) return item.flags.hidden end
    addPositiveOrNegative(tab, pred, negate)
end

function condition_owned(tab, negate)
    local pred = function(item) return item.flags.owned end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param tab conditions
--- @param negate { negate : boolean }|nil
function condition_stockpiled(tab, negate)
    local stocked = {}
    for _, stockpile in ipairs(df.global.world.buildings.other.STOCKPILE) do
        for _, item_container in ipairs(dfhack.buildings.getStockpileContents(stockpile)) do
            stocked[item_container.id] = true
            local contents = dfhack.items.getContainedItems(item_container)
            for _, item_bag in ipairs(contents) do
                stocked[item_bag.id] = true
                local contents2 = dfhack.items.getContainedItems(item_bag)
                for _, item in ipairs(contents2) do
                    stocked[item.id] = true
                end
            end
        end
    end
    local pred = function(item) return stocked[item.id] end
    addPositiveOrNegative(tab, pred, negate)
end

--- @param action "melt"|"unmelt"|"forbid"|"unforbid"|"dump"|"undump"|"count"|"hide"|"unhide"
--- @param conditions conditions
--- @param options { help : boolean, artifact : boolean, dryrun : boolean, bytype : boolean, owned : boolean, nowebs : boolean, verbose : boolean }
--- @param return_items boolean|nil
--- @return number, item[], table<number,number>
function execute(action, conditions, options, return_items)
    local count = 0
    local items = {}
    local types = {}
    local descriptions = {}

    for _, item in pairs(df.global.world.items.other.IN_PLAY) do
        -- never act on items used for constructions/building materials and carried by hostiles
        -- also skip artifacts, unless explicitly told to include them
        if item.flags.construction or
            item.flags.garbage_collect or
            item.flags.in_building or
            item.flags.hostile or
            (item.flags.artifact and not options.artifact) or
            item.flags.on_fire or
            item.flags.trader or
            (item.flags.spider_web and options.nowebs) or
            (item.flags.owned and not options.owned)
        then
            goto skipitem
        end

        -- implicit filters:
        if action == 'melt' and (item.flags.melt or not dfhack.items.canMelt(item)) or
            action == 'unmelt' and not item.flags.melt or
            action == 'forbid' and item.flags.forbid or
            action == 'unforbid' and not item.flags.forbid or
            action == 'dump' and (item.flags.dump or item.flags.artifact) or
            action == 'undump' and not item.flags.dump or
            action == 'hide' and item.flags.hidden or
            action == 'unhide' and not item.flags.hidden
        then
            goto skipitem
        end

        -- check conditions provided via options
        -- note we use pairs instead of ipairs since the caller could have
        -- added conditions with non-list keys
        for _, condition in pairs(conditions) do
            if not condition(item) then goto skipitem end
        end

        -- skip items that are in unrevealed parts of the map
        local x, y, z = dfhack.items.getPosition(item)
        if x and not dfhack.maps.isTileVisible(x, y, z) then
            goto skipitem
        end

        -- item matches the filters
        count = count + 1
        if options.bytype then
            local it = item:getType()
            types[it] = (types[it] or 0) + 1
        end

        -- carry out the action
        if action == 'forbid' and not options.dryrun then
            item.flags.forbid = true
        elseif action == 'unforbid' and not options.dryrun then
            item.flags.forbid = false
        elseif action == 'dump' and not options.dryrun then
            item.flags.dump = true
        elseif action == 'undump' and not options.dryrun then
            item.flags.dump = false
        elseif action == 'melt' and not options.dryrun then
            dfhack.items.markForMelting(item)
        elseif action == 'unmelt' and not options.dryrun then
            dfhack.items.cancelMelting(item)
        elseif action == "hide" and not options.dryrun then
            item.flags.hidden = true
        elseif action == "unhide" and not options.dryrun then
            item.flags.hidden = false
        end

        if options.verbose then
            local desc = dfhack.items.getReadableDescription(item)
            descriptions[desc] = (descriptions[desc] or 0) + 1
        end

        if return_items then table.insert(items, item) end

        :: skipitem ::
    end

    local desc_list = {}
    for desc in pairs(descriptions) do
        table.insert(desc_list, desc)
    end
    table.sort(desc_list)
    for _, desc in ipairs(desc_list) do
        print(('%4d %s'):format(descriptions[desc], desc))
    end

    return count, items, types
end

--- @param action "melt"|"unmelt"|"forbid"|"unforbid"|"dump"|"undump"|"count"|"hide"|"unhide"
--- @param conditions conditions
--- @param options { help : boolean, artifact : boolean, dryrun : boolean, bytype : boolean, owned : boolean, verbose : boolean }
function executeWithPrinting (action, conditions, options)
    local count, _ , types = execute(action, conditions, options)
    if options.verbose and count > 0 then
        print()
    end
    if action == "count" then
        print(count, 'items matched the filter options')
    elseif options.dryrun then
        print(count, 'items would be modified')
    else
        print(count, 'items were modified')
    end
    if options.bytype and count > 0 then
        local sorted = {}
        for tp, ct in pairs(types) do
            table.insert(sorted, { type = tp, count = ct })
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)
        print(("\n%-14s %5s\n"):format("TYPE", "COUNT"))
        for _, t in ipairs(sorted) do
            print(("%-14s %5s"):format(df.item_type[t.type], t.count))
        end
        print()
    end
end

-----------------------------------------------------------------------
-- script action: check for arguments and main action and run act
-----------------------------------------------------------------------

if dfhack_flags.module then
    return
end

local argparse = require('argparse')

local options = {
    help = false,
    artifact = false,
    dryrun = false,
    bytype = false,
    owned = false,
    nowebs = false,
    verbose = false,
}

--- @type (fun(item:item):boolean)[]
local conditions = {}

local function flagsFilter(args, negate)
    local flags = argparse.stringList(args, "flag list")
    for _,flag in ipairs(flags) do
        if     flag == 'forbid' then condition_forbid(conditions, negate)
        elseif flag == 'forbidden' then condition_forbid(conditions, negate) -- be lenient
        elseif flag == 'dump'   then condition_dump(conditions, negate)
        elseif flag == 'hidden' then condition_hidden(conditions, negate)
        elseif flag == 'melt'   then condition_melt(conditions, negate)
        elseif flag == 'owned'  then
            options.owned = true
            condition_owned(conditions, negate)
        else qerror('unkown flag "'..flag..'"')
        end
    end
end

local positionals = argparse.processArgsGetopt({ ... }, {
  { 'h', 'help', handler = function() options.help = true end },
  { 'v', 'verbose', handler = function() options.verbose = true end },
  { 'a', 'include-artifacts', handler = function() options.artifact = true end },
  { nil, 'include-owned', handler = function() options.owned = true end },
  { nil, 'ignore-webs', handler = function() options.nowebs = true end },
  { 'n', 'dry-run', handler = function() options.dryrun = true end },
  { nil, 'by-type', handler = function() options.bytype = true end },
  { 'i', 'inside', hasArg = true,
    handler = function (name)
        local burrow = dfhack.burrows.findByName(name,true)
        if burrow then condition_burrow(conditions, burrow)
        else qerror('burrow '..name..' not found') end
    end
  },
  { 'o', 'outside', hasArg = true,
    handler = function (name)
        local burrow = dfhack.burrows.findByName(name,true)
        if burrow then condition_burrow(conditions, burrow, { negate = true })
        else qerror('burrow '..name..' not found') end
    end
  },
  { 'r', 'reachable',
    handler = function () condition_reachable(conditions) end },
  { 'u', 'unreachable',
    handler = function () condition_reachable(conditions, { negate = true }) end },
  { 't', 'type', hasArg = true,
    handler = function (type) condition_type(conditions,type) end },
  { 'm', 'material', hasArg = true,
    handler = function (material) condition_material(conditions, material) end },
  { 'c', 'mat-category', hasArg = true,
    handler = function (matcat) condition_matcat(conditions, matcat) end },
  { 'w', 'min-wear', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'min-wear')
        condition_wear(conditions, level , 3) end },
  { 'W', 'max-wear', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'max-wear')
        condition_wear(conditions, 0, level) end },
  { 'q', 'min-quality', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'min-quality')
        condition_quality(conditions, level, 5) end },
  { 'Q', 'max-quality', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'max-quality')
        condition_quality(conditions, 0, level) end },
  { nil, 'stockpiled',
    handler = function () condition_stockpiled(conditions) end },
  { nil, 'scattered',
    handler = function () condition_stockpiled(conditions, { negate = true}) end },
  { nil, 'marked', hasArg = true,
    handler = function (args) flagsFilter(args) end },
  { nil, 'not-marked', hasArg = true,
    handler = function (args) flagsFilter(args, { negate = true }) end },
  { nil, 'visible',
    handler = function () condition_hidden(conditions, { negate = true }) end }
})

if options.help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

for i=2,#positionals do
    condition_description(conditions, positionals[i])
end

if     positionals[1] == 'forbid'   then executeWithPrinting('forbid', conditions, options)
elseif positionals[1] == 'unforbid' then executeWithPrinting('unforbid', conditions, options)
elseif positionals[1] == 'dump'     then executeWithPrinting('dump', conditions, options)
elseif positionals[1] == 'undump'   then executeWithPrinting('undump', conditions, options)
elseif positionals[1] == 'melt'     then executeWithPrinting('melt', conditions, options)
elseif positionals[1] == 'unmelt'   then executeWithPrinting('unmelt', conditions, options)
elseif positionals[1] == 'count'    then executeWithPrinting('count', conditions, options)
elseif positionals[1] == 'hide'     then executeWithPrinting('hide', conditions, options)
elseif positionals[1] == 'unhide'   then executeWithPrinting('unhide', conditions, options)
else qerror('main action not recognized')
end

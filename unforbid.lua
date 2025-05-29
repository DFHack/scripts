-- Unforbid all items

local argparse = require('argparse')

local function unforbid_all(include_unreachable, quiet, include_worn)
    local p
    if quiet then p=function(s) return end; else p=function(s) return print(s) end; end
    p('Unforbidding all items...')

    local citizens = dfhack.units.getCitizens(true)
    local count = 0
    for _, item in pairs(df.global.world.items.other.IN_PLAY) do
        if item.flags.forbid then
            if not include_unreachable then
                local reachable = false

                for _, unit in pairs(citizens) do
                    if dfhack.maps.canWalkBetween(xyz2pos(dfhack.items.getPosition(item)), unit.pos) then
                        reachable = true
                    end
                end

                if not reachable then
                    p(('  unreachable: %s (skipping)'):format(item))
                    goto skipitem
                end
            end

            if ((not include_worn) and item.wear >= 2) then
                p(('  worn: %s (skipping)'):format(item))
                goto skipitem
            end

            p(('  unforbid: %s'):format(item))
            item.flags.forbid = false
            count = count + 1

            ::skipitem::
        end
    end

    p(('%d items unforbidden'):format(count))
end

-- let the common --help parameter work, even though it's undocumented
local options, args = {
    help = false,
    quiet = false,
    include_unreachable = false,
    include_worn = false
}, {...}

local positionals = argparse.processArgsGetopt(args, {
    { 'h', 'help', handler = function() options.help = true end },
    { 'q', 'quiet', handler = function() options.quiet = true end },
    { 'X', 'include-worn', handler = function() options.include_worn = true end},
    { 'u', 'include-unreachable', handler = function() options.include_unreachable = true end },
})

if positionals[1] == nil or positionals[1] == 'help' or options.help then
    print(dfhack.script_help())
    return
end

if positionals[1] == 'all' then
    unforbid_all(options.include_unreachable, options.quiet, options.include_worn)
end

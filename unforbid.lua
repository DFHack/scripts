-- Unforbid all items
--[====[

unforbid
========

Unforbids all items.

Usage::

    unforbid all
    unforbid help
]====]

local function unforbid_all()
    print('Unforbidding all items...')
    local count = 0
    for _,item in ipairs(df.global.world.items.all) do
        if item.flags.forbid then
            print(('  unforbid: %s'):format(item))
            item.flags.forbid = false
            count = count + 1
        end
    end
    print(('%d items unforbidden'):format(count))
end

local args = {...}
if args[1] == 'all' then
    unforbid_all()
else
    print(dfhack.script_help())
end

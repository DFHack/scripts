local usage = [====[

find-group
=============
Prints out unit names associated with the searched for group aka Guild, Site, Performance Troupe etc. 

EX: find-group "group name"

]====]

local function find_group(group_name)
    local names = {}

    for _, v in pairs(df.global.world.units.active) do
        if not v then goto continue end -- Try next unit
        local links = df.historical_figure.find(v.hist_figure_id)
        if not links then goto continue end
        links = links.entity_links

        for _, v2 in pairs(links) do
            for k, v3 in pairs(v2) do
                if k == 'entity_id' then
                    local site = df.historical_entity.find(v3)
                    if not site then break end

                    site = string.lower(dfhack.TranslateName(site.name, true))
                    if site == group_name then
                        table.insert(names, dfhack.TranslateName((v.name), true))
                        -- Need to continue because if you dont will get duplicates
                        -- since dwarves can play more than one role at atime in a group
                        goto continue
                    end
                end
            end
        end
        ::continue::
    end

    -- print names
    for _, v in pairs(names) do
        print(v)
    end
end

local function main(...)
    local args = {...}

    if args[1] == 'help' then
        print(usage)
        return
    end

    if args[1] ~= nil then
        find_group(string.lower(args[1]))
        return
    end
end

main(...)
-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2018-10-19
--luacheck:skip-entirely
local utils=require('utils')
local validArgs = utils.invert({
 'unit',
 'table',
 'query',
 'help',
})
local args = utils.processArgs({...}, validArgs)
local help = [====[
devel/query
===========
Query is a script useful for finding and reading values of data structure fields.
Purposes will likely be exclusive to writing lua script code.

This script will recursively search an input for fields matching your query.
Matching fields will be printed along with their values. When a match is a
table the entire table will not be printed, only the reference to it.

When performing table queries, use dot notation to denote sub-tables.
The script has to parse the input string and separate each table.

example: "query -unit -query profession" will print all fields matching
'*profession*' inside the highlighted unit.

The values input to -unit or -table must be global identifiers
(ie. _G[identifier] must exist).

Usage: ``query -unit <global_value> -query <query>``
or ``query -table <global_value> -query <query>``

]====]

--thanks goes mostly to the internet for this function. thanks internet you da real mvp
function safe_pairs(item, keys_only)
    if keys_only then
        local mt = debug.getmetatable(item)
        if mt and mt._index_table then
            local idx = 0
            return function()
                idx = idx + 1
                if mt._index_table[idx] then
                    return mt._index_table[idx]
                end
            end
        end
    end
    local ret = table.pack(pcall(function() return pairs(item) end))
    local ok = ret[1]
    table.remove(ret, 1)
    if ok then
        return table.unpack(ret)
    else
        return function() end
    end
end

function Query(table, query, parent)
    if not parent then
        parent = ""
    end
    for k,v in safe_pairs(table) do
        -- avoid infinite recursion
        if not tonumber(k) and type(k) ~= "table" and not string.find(tostring(k), 'script') then
            if string.find(tostring(k), query) then
                print(parent .. "." .. k .. ":", v)
            end
            --print(parent .. "." .. k)
            if not string.find(parent, tostring(k)) then
                if parent then
                    Query(v, query, parent .. "." .. k)
                else
                    Query(v, query, k)
                end
            end
        end
    end
end

function parseTableString(str)
    tableParts = {}
    for word in string.gmatch(str, '([^.]+)') do --thanks stack overflow
        table.insert(tableParts, word)
    end
    curTable = nil
    for k,v in pairs(tableParts) do
      if curTable == nil then
        if _G[v] ~= nil then
            curTable = _G[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
      else
        if curTable[v] ~= nil then
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
      end
    end
    return curTable
end

local selection = nil
if args.help then
    print(help)
elseif args.unit then
    if _G[args.unit] ~= nil then
        selection = _G[args.unit]
    else
        selection = dfhack.gui.getSelectedUnit()
    end
    if selection == nil then
        qerror("Selected unit is null. Invalid selection.")
    elseif args.query ~= nil then
        Query(selection, args.query, 'selected-unit')
    else
        print("The query is empty, the output is probably gonna be large. Start your engines.")
        Query(selection, '', 'selected-unit')
    end
elseif args.table then
    local t = parseTableString(args.table)
    if args.query ~= nil then
        Query(_G[args.table], args.query, args.table)
    else
        print("The query is empty, the output is probably gonna be large. Start your engines.")
        Query(_G[args.table], '', args.table)
    end
else
    print(help)
end

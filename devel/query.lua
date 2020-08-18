-- Query is a script useful for finding and reading values of data structure fields. Purposes will likely be exclusive to writing lua script code.
-- Written by Josh Cooper(cppcooper) on 2017-12-21, last modified: 2020-03-03
-- Version: 2.x
--luacheck:skip-entirely
local utils=require('utils')
local validArgs = utils.invert({
 'help',

 'unit',
 'item',
 'tile',
 'table',

 'query',
 'querykeys',
 'depth',
 'keydepth',
 'maxtablelength',

 'listall',
 'listfields',
 'listkeys',
 'getfield',
 'setkey',

 'includeitall',

 'safer',
 'dumb',
 'disableprint',
 'debug'
})
local args = utils.processArgs({...}, validArgs)
depth=nil
keydepth=nil
cur_depth = -1
cur_keydepth = -1

newkeyvalue=nil
bprintfields=nil
bprintkeys=nil
space_field="   "
fN=0
--kN=25
local help = [====[

devel/query
===========
Query is a script useful for finding and reading values of data structure fields.
Purposes will likely be exclusive to writing lua script code.

Fields: contents of tables
Keys:   contents below non-table containers

Keys and fields are essentially the same thing. The real difference is what
code checks need to be in place for queries on keys vs fields. This is why
they are differentiated.

This is a recursive script which takes your selected data {table,unit,item,tile}
and then iterates through it, then iterates through anything it finds. It does
this recursively until it has walked over everything it is allowed. Everything
it walks over it checks against any (optional) string/value queries, and if it
finds a match it then prints it to the console.

You can control most aspects of this process, the script is fairly flexible. So
much so that you can easily create an infinitely recursing query and/or potentially
crash Dwarf Fortress and DFHack. In previous iterations memory bloat was even a
concern, where RAM would be used up in mere minutes or seconds; you can probably
get this to happen as well if you are careless with the depth settings and don't
print everything walked over (i.e. have a search term). The `kill-lua` command
may be able to stop this script if it gets out of control.

Before recursing or printing things to the console the script checks several things.
A few important ones:

 - Is the data structure capable of being iterated?
 - Is the data structure pointing to a parent data structure?
 - Is the current level of recursion too high, and do we need to unwind it first?
 - Is the number of entries too high (eg. 70,000 table entries that would be printed)?
 - Is the data going to be usefully readable?
 - Does the field or key match the field or key query or queries?
 - Is printing fields allowed?
 - Is printing keys allowed?

Examples::

  devel/query -table df -query dead
  devel/query -table df.global.ui.main -depth 0
  devel/query -table df.profession -querykeys WAR
  devel/query -unit -query STRENGTH
  devel/query -unit -query physical_attrs -listkeys
  devel/query -unit -getfield id

**Selection options:**

These options are used to specify where the query will run,
or specifically what key to print inside a unit.

``-unit``:              Selects the highlighted unit

``-item``:              Selects the highlighted item.

``-tile``:              Selects the highlighted tile's block and then attempts to find the tile, and perform your queries on it.

``-table <value>``:     Selects the specified table (ie. 'value').

                        Must use dot notation to denote sub-tables.
                        (eg. ``-table df.global.world``)

``-getfield <value>``:  Gets the specified field from the selected unit.

                        Must use dot notation to denote sub-fields.
                        Useful if there would be several matching
                        fields with the input as a substring (eg. 'id', 'gui')

**Query options:**

``-query <value>``:     Searches the selection for fields with substrings matching the specified value.

``-querykeys <value>``: Lists only keys matching the specified value.

``-listall``:           Lists both fields and keys, useful if you aren't running a search.

``-listfields``:        Lists fields. Useful if you aren't running a search.

``-listkeys``:          Lists keys. Useful. Ya, period.

``-depth <value>``:          Limits the field recursion depth (default: 10)

``-keydepth <value>``:       Limits the key recursion depth (default: 4)

``-maxtablelength <value>``: Limits the table sizes that will be walked (default: 257)

``-includeitall``:  Removes blacklist filtering, and disregards readability of output.

``-safer``:         Disables walking struct data.

                    Unlike native Lua types, struct data can sometimes be misaligned,
                    which can cause crashes when accessing it. This option may be useful
                    if you're running an alpha or beta build of DFHack.

``-dumb``:          Disables intelligent checks for things such as reasonable
recursion depth (i.e. depth maximums are increased, not removed) and also checks
for recursive data structures (i.e. to avoid walking a child that goes to a
parent)

**Command options:**

``-debug <value>``: Enables debug log lines equal to or less than the value
provided. Some lines are commented out entirely, and you probably won't even use
this.. but hey, now you know it exists.

``-disableprint``: Disables printing fields and keys. Might be useful if you are
debugging this script. Or to see if a query will crash (faster) but not sure
what else you could use it for.

``-help``: Prints this help information.

]====]

--[[ Test cases:
    These sections just have to do with when I made the tests and what their purpose at that time was.
    [safety] make sure the query doesn't crash itself or dfhack
        1. devel/query -keydepth 3 -listall -table df
        2. devel/query -depth 10 -keydepth 3 -includeitall -dumb -table dfhack -query gui -listall
        3. devel/query -depth 10 -keydepth 3 -includeitall -dumb -table df -listfields
        4. devel/query -depth 10 -keydepth 5 -includeitall -dumb -unit -listall
    [validity] make sure the query output is not malformed, and does what is expected
        1. devel/query -dumb -includeitall -listfields -unit
        2. devel/query -dumb -includeitall -listfields -table dfhack
        3. devel/query -dumb -includeitall -listfields -table df
        4. devel/query -dumb -includeitall -listfields -table df -query job_skill
        5. devel/query -dumb -includeitall -listall -table df -query job_skill
        6. devel/query -dumb -includeitall -listall -table df -getfield job_skill
]]


function init_parameters()
    --Print Options
    bprintfields=(args.listall or args.query or args.listfields) and true or false
    bprintkeys=(args.listall or args.querykeys or args.listkeys) and true or false

    --Dumb Queries
    if args.dumb then
        --[[ Let's make the recursion dumber, but let's not do it infinitely.
        There are many recursive structures which would cause this to happen.
        ]]
        if not args.depth then
            depth = 25
            args.depth = depth
        end
        if not args.keydepth then
            keydepth = 25
            args.keydepth = keydepth
        end
    else
        --Table Length
        if not args.maxtablelength then
            --[[ Table length is inversely proportional to how useful the data is.
            257 was chosen with the intent of capturing all enums. Or hopefully most of them.
            ]]
            args.maxtablelength = 257
        else
            args.maxtablelength = tonumber(args.maxtablelength)
        end
    end

    --Table Recursion
    if args.depth then
        depth = tonumber(args.depth)
        if not depth then
            qerror(string.format("Must provide a number with -depth"))
        end
    else
        depth = 10
        args.depth = depth
    end

    --Key Recursion
    if args.keydepth then
        keydepth = tonumber(args.keydepth)
        if not keydepth then
            qerror(string.format("Must provide a number with -keydepth"))
        end
    else
        keydepth = 4
        args.keydepth = keydepth
    end

    --Set Key [boolean parsing]
    if args.setkey == "true" then
        newkeyvalue=true
    elseif args.setkey == "false" then
        newkeyvalue=false
    end
end

function debugf(level,...)
    if args.debug and level <= tonumber(args.debug) then
        str=string.format(" #  %s",select(1, ...))
        for i = 2, select('#', ...) do
            str=string.format("%s\t%s",str,select(i, ...))
        end
        print(str)
    end
end

--thanks goes to lethosor for this
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

function TableLength(t)
    -- 'and t._kind and' ya, that's right, it can be nil!
    if type(t) == "userdata" and getmetatable(t) and t._kind and not (t._kind == "struct" or t._kind == "primitive") then
        --debugf(11,"TableLength: stage 1",string.format("_kind: %s, value: %s",t._kind,t))
        len=#t
        if len ~= 0 then
            --debugf(11,"TableLength: stage 2")
            return len
        end
    elseif type(t) == "table" then
        --debugf(11,"TableLength: stage 3")
        return #t
    else
        --debugf(11,"TableLength: stage 4")
        return 0
    end
    local count = 0
    --debugf(11,"TableLength: stage 5 (for loop)")
    for i,k in pairs(t) do
        count = count + 1
    end
    return count
end


function parseKeyString(t,str)
    debugf(1,"parsing",t,str)
    curTable = t
    keyParts = {}
    for word in string.gmatch(str, '([^.]+)') do --thanks stack overflow
        table.insert(keyParts, word)
    end
    if not curTable then
        qerror("Looks like we're borked somehow.")
    end
    for k,v in pairs(keyParts) do
        if v and curTable[v] ~= nil then
            --debugf(1,"found something",v,curTable,curTable[v])
            curTable = curTable[v]
        else
            qerror("Table" .. v .. " does not exist.")
        end
    end
    --debugf(1,"returning",curTable)
    return curTable
end

function hasMetadata(value)
    if getmetatable(value) and value._kind then
        return true
    end
    return false
end

function isBlackListed(field)
    if not args.includeitall then
        function match(str,p)
            return string.find(str,p)
        end
        if match(field,"script") then
            return true
        elseif match(field,"saves") then
            return true
        end
    end
    return false
end

function isFieldValueMatch(field,value)
    --debugf(11,"isFieldValueMatch()")
    if not (args.query or args.queryvalues) then
        --debugf(11,"isFieldValueMatch: stage 1")
        return true
    end
    --debugf(11,"isFieldValueMatch: stage 2,0")
    bFieldMatches = not args.query or (args.query and string.find(tostring(field),args.query))
    bValueMatches = not args.queryvalues or (args.queryvalues and string.find(tostring(value),args.queryvalues))
    return bFieldMatches and bValueMatches
end

function isKeyValueMatch(key,value)
    --debugf(11,"isKeyValueMatch()")
    if not (args.querykeys or args.queryvalues) then
        --debugf(11,"isKeyValueMatch: stage 1")
        return true
    end
    --debugf(11,"isKeyValueMatch: stage 2,0")
    bKeyMatches = not args.querykeys or (args.querykeys and string.find(key,args.querykeys))
    bValueMatches = not args.queryvalues or (args.queryvalues and string.find(tostring(value),args.queryvalues))
    return bKeyMatches and bValueMatches
end

function hasPairs(value)
    --debugf(11,"hasPairs()")
    if type(value) == "table" then
        --debugf(11,"hasPairs: stage 1")
        return true
    elseif type(value) == "userdata" then
        --debugf(11,"hasPairs: stage 2")
        if getmetatable(value) then
            --debugf(11,"hasPairs: stage 3")
            if value._kind == "primitive" then
                return false
            elseif value._kind == "container" or value._kind == "bitfield" then
                --debugf(11,"hasPairs: stage 4")
                return true
            elseif value._kind == "struct" and not df.isnull(value) then
                --debugf(11,"hasPairs: stage 5. struct is not null")
                if args.safer then
                    return false
                else
                    return true
                end
            end
            debugf(11,"hasPairs: stage 6")
            debugf(0,string.format("This shouldn't be reached.\n   input-value: %s, type: %s, _kind: %s",value,type(value),value._kind))
            return (TableLength(value) ~= 0)
        end
    else
        --debugf(11,"hasPairs: stage 7")
        for k,v in safe_pairs(value) do
            --debugf(11,"hasPairs: stage 8")
            debugf(0,string.format("Pretty sure this is never going to proc, except on structs.\n   table-length: %d, input-value: %s, type: %s, k: %s, v: %s",TableLength(value),value,type(value),k,v))
            return true
        end
    end
    --debugf(11,"hasPairs: stage 0")
    return false
end

function isFieldHumanReadable(field,value)
    if args.includeitall then
        return true
    end
    --debugf(11,"isFieldHumanReadable()")
    tf=tonumber(field) and "number" or type(field)
    tv=type(value)
    if tf == "string" or hasPairs(value) then
        --debugf(11,"isFieldHumanReadable: stage 1")
        return true
    elseif tf ~= "number" then
        debugf(0,"field type is not a string, or a number. It is: ", tf)
    else
        debugf(1,string.format("field type: %s,  value type: %s",tf,tv))
    end
    --debugf(11,"isFieldHumanReadable: stage 0")
    return false
end

function isKeyHumanReadable(key,value)
    if args.includeitall then
        return true
    end
    --debugf(11,"isKeyHumanReadable()")
    tk=tonumber(key) and "number" or type(key)
    tv=type(value)
    debugf(4,string.format("isKeyHumanReadable: key=%s, value=%s, value-type=%s",key,value,type(value)))
    if tk == "string" or tv == "string" then
        --debugf(11,"isKeyHumanReadable: stage 1")
        return true
    elseif tk == "number" and getmetatable(value) then
        --debugf(11,"isKeyHumanReadable: stage 2")
        return true
    elseif tk ~= "number" then
        debugf(0,"key type is not a string, or a number. It is: ", tk)
    else
        debugf(1,string.format("field type: %s,  value type: %s",tk,tv))
    end
    --debugf(11,"isKeyHumanReadable: stage 0")
    return false
end

function canRecurseField(parent,field,value)
    debugf(10,"canRecurseField()",field,value)
    if type(value) == "table" and hasPairs(value) and (not args.maxtablelength or TableLength(value) <= args.maxtablelength) then
        --debugf(11,"canRecurseField: stage 1")
        --check that we aren't going to walk through a pointer to the parent structure
        if tonumber(field) then
            --debugf(11,"canRecurseField: stage 2")
            --[[if args.dumb or not string.find(parent,"%[[%d]+%]") then
                --debugf(11,"canRecurseField: stage 3")
                return true
            end]]
            return true
        end
        pattern=string.format("%%.%s",field)
        if not string.find(parent,string.format("%s%%.",pattern)) and
           not string.find(parent,pattern,1+parent:len()-pattern:len()) then
            --debugf(11,"canRecurseField: stage 4")
            --todo???if not tonumber(k) and (type(k) ~= "table" or depth) and not string.find(tostring(k), 'script') then
            if not isBlackListed(field) then
                --debugf(11,"canRecurseField: stage 5")
                return true
            end
        end
    end
    --debugf(11,"canRecurseField: stage 0")
    return false
end

function canRecurseKey(parent,key,value)
    --debugf(11,"canRecurseKey()",key,value)
    if hasPairs(value) and (not args.maxtablelength or TableLength(value) <= args.maxtablelength) then
        --debugf(11,"canRecurseKey: stage 1")
        --check that we aren't going to walk through a pointer to the parent structure
        if tonumber(key) then
            --debugf(11,"canRecurseKey: stage 2")
            --[[if args.dumb or not string.find(parent,"%[[%d]+%]") then
                --debugf(11,"canRecurseKey: stage 3")
                return true
            end]]
            return true
        end
        pattern=string.format("%%.%s",key)
        if not string.find(parent,string.format("%s%%.",pattern)) and
           not string.find(parent,pattern,1+parent:len()-pattern:len()) then
            --debugf(11,"canRecurseKey: stage 4")
            --todo???if not tonumber(k) and (type(k) ~= "table" or depth) and not string.find(tostring(k), 'script') then
            if not isBlackListed(key) then
                --debugf(11,"canRecurseKey: stage 5")
                return true
            end
        end
    end
    --debugf(11,"canRecurseKey: stage 0")
    return false
end

function print_tile(key,v)
    if v._kind == "container" and string.find(tostring(v),"[16][]") then
        if isKeyValueMatch(key) then
            debugf(5,"print_keys->print_tile")
            return print_key(string.format("%s[%d][%d]",field,x,y), v[x][y])
        end
    end
    return false
end

function print_keys(parent,field,value,bprintparent)
    --debugf(11,"print_keys()")
    cur_keydepth = cur_keydepth + 1
    if not keydepth or (cur_keydepth <= keydepth) then
        if hasMetadata(value) then
            debugf(5,"print_keys: field value has metadata")
            if value._kind == "enum-type" then
                debugf(4,"print_keys: enum-type")
                for i,v in ipairs(value) do
                    if isKeyHumanReadable(i,value) then
                        bprintparent=print_key(i,v,bprintparent,parent,value)
                        if canRecurseKey(parent,i,v) then
                            debugf(3,"print_keys->print_keys.1")
                            print_keys(string.format("%s[%d]",parent,i),i,v,bprintparent)
                        else
                            debugf(3,"print_keys->norecursion.1")
                        end
                    end
                end
            elseif value._kind == "container" then
                debugf(5,"print_keys: container")
                if not args.tile or not print_tile(field,value) then
                    debugf(4,"print_keys: not a tile exclusive data structure",string.format("_type: %s, length: %s", value._type, #value))
                    for k,v in pairs(value) do
                        if isKeyHumanReadable(k,v) then
                            bprintparent=print_key(k,v,bprintparent,parent,value)
                            if canRecurseKey(parent,k,v) then
                                debugf(3,"print_keys->print_keys.2")
                                print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v,bprintparent)
                            else
                                debugf(3,"print_keys->norecursion.2")
                            end
                        end
                    end
                end
            else
                debugf(5,string.format("print_keys:\n    # parent: %s\n    # field: %s\n    # _kind: %s\n    # type: %s\n    # value: %s",parent,field,value._kind,type(value),value))
                if value._kind == "struct" then
                    --debugf(11,string.format("struct length: %s",TableLength(value)))
                end
                for k,v in safe_pairs(value) do
                    if isKeyHumanReadable(k,v) then
                        bprintparent=print_key(k,v,bprintparent,parent,value)
                        if canRecurseKey(parent,k,v) then
                            debugf(3,"print_keys->print_keys.3")
                            print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v,bprintparent)
                        else
                            debugf(3,"print_keys->norecursion.3")
                        end
                    end
                end
            end
        else
            debugf(5,string.format("print_keys:\n    # parent: %s\n    # field: %s\n    # type: %s\n    # value: %s",parent,field,type(value),value))
            for k,v in pairs(value) do
                if isKeyHumanReadable(k,v) then
                    bprintparent=print_key(k,v,bprintparent,parent,value)
                    if canRecurseKey(parent,k,v) then
                        debugf(3,"print_keys->print_keys.4")
                        print_keys(string.format(tonumber(k) and "%s[%s]" or "%s.%s",parent,k),k,v,bprintparent)
                    else
                        debugf(3,"print_keys->norecursion.4")
                    end
                end
            end
        end
    end
    cur_keydepth = cur_keydepth - 1
    --debugf(11,"print_keys: exit")
end

function print_key(k,v,bprintparent,parent,v0)
    if not args.disableprint and (k or v) and isKeyValueMatch(k,v) then
        if bprintparent then
            debugf(7,"print_key->print_field")
            print_field(parent,v0)
            bprintparent=false
        end
        if args.setkey then
            set_key(v0,k)
            v=v0[k]
        end
        key=string.format("%-4s ",tostring(k)..":")
        indent="   |"
        for i=1,(cur_keydepth) do
            indent=string.format("  %s",indent)
        end
        indent=string.format("%s ",indent)
        print(indent .. string.format("%s",key) .. tostring(v))
    end
    return bprintparent
end

function set_key(v0,k)
    key_type=type(v0[k])
    if key_type == "number" and tonumber(args.setkey) then
        v0[k]=tonumber(args.setkey)
    elseif key_type == "boolean" and newkeyvalue then
        v0[k]=newkeyvalue
    elseif key_type == "string" then
        v0[k]=args.setkey
    end
end

function print_field(field,v)
    if not args.disableprint and (field or v) then
        field=string.format("%s: ",tostring(field))
        cN=string.len(field)
        fN = cN >= fN and cN or fN
        fN = fN >= 90 and 90 or fN
        form="%-"..(fN+5).."s"
        print(space_field .. string.gsub(string.format(form,field),"   "," ~ ") .. "[" .. type(v) .. "] " .. tostring(v))
    end
end

function Query(t,query,parent,field,bprintparent)
    cur_depth = cur_depth + 1
    breturn_printedkeys=false
    if not depth or cur_depth < depth then --We always have at least the default depth limit
        parent = parent and parent or ""
        field = field and field or ""
        debugf(10,"we're inside query")
        if type(t) == "table" then
            --debugf(11,string.format("query: selected table. type: %s, value: %s, length: %s",type(t),t,TableLength(t)))
        elseif type(t) == "userdata" then
            if getmetatable(t) then
                --debugf(11,string.format("query: selected table. type: %s, value: %s, _kind: %s, _type: %s, length: %s",type(t),t,t._kind,t._type,TableLength(t)))
            else
                --debugf(11,string.format("query: selected table. type: %s, value: %s, length: %s",type(t),t,TableLength(t)))
            end
        end
        if bprintkeys and hasMetadata(t) and t._kind == "enum-type" and isFieldValueMatch(field,value) then
            debugf(5,"query is going straight to print_keys")
            print_keys(parent,"",t,bprintparent)
            breturn_printedkeys=true
        else
            for field,value in pairs(t) do
                debugf(10,"we're looping inside query")
                if value then
                    debugf(9,"query loop has a valid value",field,value)
                    debugf(9,string.format("value-type: %s, field: %s, value: %s",type(value),field,value))
                    newParent=""
                    if tonumber(field) then
                        newParent=string.format("%s[%s]",parent,field)
                    else
                        newParent=string.format("%s.%s",parent,field)
                    end
                    debugf(10,"query: stage 1")

                    -- print field
                    bprintparent=true
                    if bprintfields and isFieldValueMatch(field,value) and isFieldHumanReadable(field,value) then
                        debugf(8,"query->print_field")
                        print_field(newParent,value)
                        bprintparent=false
                    end
                    debugf(10,"query: stage 2")

                    -- query recursively
                    bprintedkeys=false
                    if canRecurseField(parent,field,value) then
                        debugf(8,"query->query")
                        bprintedkeys=Query(t[field],query,newParent,field,bprintparent)
                    end
                    debugf(10,"query: stage 3")

                    -- print keys
                    if bprintkeys and not bprintedkeys and isFieldValueMatch(field,value) and canRecurseKey(parent,field,value) then
                        debugf(8,"query->print_keys")
                        print_keys(newParent,field,value,bprintparent)
                        breturn_printedkeys=true
                    end
                    debugf(10,"query: stage 4")
                end
            end
        end
    end
    cur_depth = cur_depth - 1
    return breturn_printedkeys
end

function main()
    init_parameters()
    pos = nil
    x = nil
    y = nil
    block = nil
    info=""
    local selection = nil
    if args.help then
        print(help)
    elseif args.table then
        debugf(0,"table selection")
        selection = utils.df_expr_to_ref(args.table)
        info=args.table
    elseif args.unit then
        debugf(0,"unit selection")
        selection = dfhack.gui.getSelectedUnit()
        info="unit"
    elseif args.item then
        debugf(0,"item selection")
        selection = dfhack.gui.getSelectedItem()
        info="item"
    elseif args.tile then
        debugf(0,"tile selection")
        pos = copyall(df.global.cursor)
        x = pos.x%16
        y = pos.y%16
        selection = dfhack.maps.ensureTileBlock(pos.x,pos.y,pos.z)
        info="block"
    else
        print(help)
    end

    msg=string.format("Selected %s is null. Invalid selection.",info)
    debugf(0,selection,info)

    if selection == nil then
        qerror(msg)
    end

    if args.getfield then
        debugf(0,"getfield..", args.getfield)
        selection=parseKeyString(selection,args.getfield)
        info=string.format("%s.%s",info,args.getfield)
        if canRecurseField("","",selection) then --todo debug, I think this always fails
            debugf(0,"getfield: query")
            Query(selection, args.query, info)
        elseif canRecurseKey("","",selection) then
            debugf(0,"getfield: print_keys")
            print_keys(info,args.getfield,selection,true)
        else
            debugf(0,"getfield: simple print")
            print(string.format("%s: %s",info,selection))
        end
    else
        if args.query then
            debugf(0,"regular query")
            Query(selection, args.query, info)
        else
            debugf(0,"empty query")
            Query(selection, '', info)
        end
    end
end

main()

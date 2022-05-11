-- change number of dwarves on initial embark

--[====[

startdwarf
==========
Use at the embark screen to embark with the specified number of dwarves.

- ``startdwarf 10`` would just allow a few more warm bodies to dig in
- ``startdwarf 500`` would lead to a severe food shortage and FPS issues

The number must be 7 or greater.

]====]

local addr = dfhack.internal.getAddress('start_dwarf_count')
if not addr then
    qerror('start_dwarf_count address not available - cannot patch')
end

local num = tonumber(({...})[1])
if not num then
    qerror('argument must be a number')
elseif num < 7 then
    qerror('argument must be at least 7')
end

dfhack.with_temp_object(df.new('uint32_t'), function(temp)
    temp.value = num
    local temp_size, temp_addr = temp:sizeof()
    dfhack.internal.patchMemory(addr, temp_addr, temp_size)
end)

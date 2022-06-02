-- change number of dwarves on initial embark

--[====[

startdwarf
==========
Use before embarking (e.g. at the site selection screen or any time before) to
change the number of dwarves you embark with from the default of 7.

- ``startdwarf 10`` would just allow a few more warm bodies to dig in
- ``startdwarf 500`` would lead to a severe food shortage and FPS issues

The number must be 7 or greater.

]====]

local addr = dfhack.internal.getAddress('start_dwarf_count')
if not addr then
    qerror('start_dwarf_count address not available - cannot patch')
end

local num = tonumber(({...})[1])
if not num or num < 7 then
    qerror('argument must be a number no less than 7')
end

dfhack.with_temp_object(df.new('uint32_t'), function(temp)
    temp.value = num
    local temp_size, temp_addr = temp:sizeof()
    dfhack.internal.patchMemory(addr, temp_addr, temp_size)
end)

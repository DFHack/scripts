-- Scan and dump likely vtable addresses
local memscan = require('memscan')

local osType = dfhack.getOSType()
if osType ~= 'linux' then
    qerror('unsupported OS: ' .. osType)
end

local function get_ranges()
    local df_ranges, lib_names = {}, {}

    local raw_ranges = dfhack.internal.getMemRanges()

    -- add main binary mem ranges first
    for _, range in ipairs(raw_ranges) do
        if range.read and (
            string.match(range.name, '/dwarfort$') or
            string.match(range.name, 'Dwarf Fortress%.exe')
        )
        then
            table.insert(df_ranges, range)
        end
    end

    for _, range in ipairs(raw_ranges) do
        if range.read and string.match(range.name, '/libg_src_lib.so$') then
            table.insert(df_ranges, range)
            lib_names[range.name] = true
        end
    end

    return df_ranges, lib_names
end

local df_ranges, lib_names = get_ranges()

-- vtables that cross a range boundary can appear twice, a truncated version in the
-- lower memory range and a full version in the higher memory range
-- therefore, sort the memory ranges by start address, descending
-- but keep libraries last
local function sort_ranges(a, b)
    if lib_names[a.name] == lib_names[b.name] then
        return a.start_addr > b.start_addr
    end
    return lib_names[b.name]
end

table.sort(df_ranges, sort_ranges)

function is_df_addr(a)
    for _, range in ipairs(df_ranges) do
        if a >= range.start_addr and a < range.end_addr then
            return true
        end
    end
    return false
end

local function is_vtable_range(range)
    return not range.write and not range.execute
end

function scan_ranges()
    local vtables = {}
    local seen = {} -- only record the first encountered vtable for each name

    for _, range in ipairs(df_ranges) do
        if not is_vtable_range(range) then goto next_range end
        local base = range.name:match('.*/(.*)$')
        local area = memscan.MemoryArea.new(range.start_addr, range.end_addr)
        local is_lib = lib_names[range.name]
        for i = 1, area.uintptr_t.count - 1 do
            -- take every pointer-aligned value in memory mapped to the DF executable, and see if it is a valid vtable
            -- start by following the logic in Process::doReadClassName() and ensure it doesn't crash
            local vtable = area.uintptr_t:idx2addr(i)
            local typeinfo = area.uintptr_t[i - 1]
            if not is_df_addr(typeinfo + 8) then goto next_ptr end
            local typestring = df.reinterpret_cast('uintptr_t', typeinfo + 8)[0]
            if not is_df_addr(typestring) then goto next_ptr end
            -- rule out false positives by checking that the vtable points to a table of valid pointers
            -- TODO: check that the pointers are actually function pointers
            local vlen = 0
            while is_df_addr(vtable + (8*vlen)) and
                is_df_addr(df.reinterpret_cast('uintptr_t', vtable + (8*vlen))[0])
            do
                vlen = vlen + 1
                break -- for now, any vtable with one valid pointer is valid enough
            end
            if vlen <= 0 then goto next_ptr end
            -- some false positives can be ruled out if the string.char() call in read_c_string() throws an error for invalid characters
            local ok, name = pcall(function()
                return memscan.read_c_string(df.reinterpret_cast('char', typestring))
            end)
            if not ok then goto next_ptr end
            -- GCC strips the "_Z" prefix from typeinfo names, so add it back
            local demangled_name = dfhack.internal.cxxDemangle('_Z' .. name)
            if demangled_name and
                not demangled_name:match('[<>]') and
                not demangled_name:match('^std::') and
                not seen[demangled_name] and
                (is_lib or demangled_name ~= 'widgets::widget')  -- the widget in g_src takes precedence
            then
                local base_str = ''
                if is_lib then
                    vtable = vtable - range.base_addr
                    base_str = (" base='%s'"):format(base)
                end
                vtables[demangled_name] = {value=vtable, base_str=base_str}
                seen[demangled_name] = true
            end
            ::next_ptr::
        end
        ::next_range::
    end

    return vtables
end

local vtables = scan_ranges()
for name, data in pairs(vtables) do
    print(("<vtable-address name='%s' value='0x%x'%s/>"):format(name, data.value, data.base_str))
end

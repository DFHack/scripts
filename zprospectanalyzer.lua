-- scripts/zprospectanalyzer.lua

local zprospectanalyzer = {}

--- Scans the world using the `prospect` command and returns a table of materials.
-- @return table data[section][material_key] = { count=number, minElev=number?, maxElev=number? }
function zprospectanalyzer.scanProspect(section)
    local filterSection = section and section:lower():gsub("%s+","_") or "all"
    local showMap = {
        base_materials   = "base",
        liquids          = "liquids",
        layer_materials  = "layers",
        features         = "features",
        ores             = "ores",
        gems             = "gems",
        other_vein_stone = "veins",
        shrubs           = "shrubs",
        wood_in_trees    = "trees",
    }
    local cmd = { "prospect", "all" }
    if filterSection ~= "all" and showMap[filterSection] then
        table.insert(cmd, "--show")
        table.insert(cmd, showMap[filterSection])
    end
    local output, status = dfhack.run_command_silent(table.unpack(cmd))
    if status ~= CR_OK then
        error(("prospect failed (code %d): %s"):format(status, tostring(output)))
    end
    local data = {}
    local current
    -- split output into lines without interpreting escape sequences
    for line in output:gmatch("([^\n]+)") do
        local header = line:match("^%s*([%a%s_]+)%s*:%s*$")
        if header then
            current = header:lower():gsub("%s+","_")
            data[current] = {}
        elseif current then
            local name, count, elev = line:match(
                "^%s*([%u_]+)%s*:%s*(%d+)%s+Elev:?%s*([-%d%.]+)"
            )
            if not name then
                name, count = line:match("^%s*([%u_]+)%s*:%s*(%d+)")
            end
            if name and count then
                local key = name:lower()
                local entry = { count = tonumber(count) }
                if elev then
                    local minE, maxE = elev:match("([-%d]+)%.%.([-%d]+)")
                    entry.minElev = tonumber(minE)
                    entry.maxElev = tonumber(maxE)
                end
                data[current][key] = entry
            end
        end
    end
    return data
end

--- Sorts an array of material entries by min elevation then quantity.
-- @return sorted list
function zprospectanalyzer.sortMaterials(list)
    table.sort(list, function(a, b)
        local am = a.entry.minElev or 0
        local bm = b.entry.minElev or 0
        if am ~= bm then
            return am > bm
        end
        return a.entry.count > b.entry.count
    end)
    return list
end

--- Prints material entries in aligned columns with a header.
function zprospectanalyzer.printMaterials(list)
    -- Header line
    print(string.format("    %-15s %8s %10s %10s", "Material", "Quantity", "Min Elev", "Max Elev"))
    for _, item in ipairs(list) do
        print(string.format(
            "    %-15s %8d %10s %10s",
            item.key:upper(),
            item.entry.count,
            item.entry.minElev or "?",
            item.entry.maxElev or "?"
        ))
    end
end

--- Main entry point for CLI.
-- Supports "blocks" preset or custom section/material arguments.
-- Not-found entries are printed last.
-- blocks preset includes stones that are worth 3 pts.
function zprospectanalyzer.main(...)
    local args = { ... }
    if #args == 0 then args = { "blocks" } end
    local presets = {
        blocks = {
            "Alabaster", "Alunite", "Andesite", "Anhydrite", "Basalt",
            "Bauxite", "Bismuthinite", "Borax", "Brimstone", "Chert",
            "Chromite", "Cinnabar", "Claystone", "Cobaltite", "Conglomerate",
            "Cryolite", "Dacite", "Diorite", "Gabbro", "Gneiss",
            "Granite", "Graphite", "Gypsum", "Hornblende", "Ilmenite",
            "Jet", "Kaolinite", "Kimberlite", "Marcasite", "Mica",
            "Microcline", "Olivine", "Orpiment", "Orthoclase", "Periclase",
            "Petrified_wood", "Phyllite", "Pitchblende", "Puddingstone",
            "Pyrolusite", "Quartzite", "Realgar", "Rhyolite", "Rock_salt",
            "Rutile", "Saltpeter", "Sandstone", "Satinspar", "Schist",
            "Selenite", "Serpentine", "Shale", "Siltstone", "Slate",
            "Stibnite", "Sylvite", "Talc",
        }
    }
    local first = args[1]:lower():gsub("%s+","_")
    local materials = {}
    local section
    if presets[first] then
        materials = presets[first]
    else
        local validSections = {
            base_materials=true, liquids=true, layer_materials=true,
            features=true, ores=true, gems=true,
            other_vein_stone=true, shrubs=true, wood_in_trees=true
        }
        local startIndex = 1
        if validSections[first] then section = first; startIndex = 2 end
        for i = startIndex, #args do materials[#materials+1] = args[i] end
    end
    local data = zprospectanalyzer.scanProspect(section)
    local foundEntries = {}
    local missingEntries = {}
    for _, mat in ipairs(materials) do
        local key = mat:lower():gsub("%s+","_")
        local entryFound = false
        if section then
            local e = (data[section] or {})[key]
            if e then
                foundEntries[#foundEntries+1] = { key = key, entry = e }
                entryFound = true
            end
        else
            for _, items in pairs(data) do
                local e = items[key]
                if e then
                    foundEntries[#foundEntries+1] = { key = key, entry = e }
                    entryFound = true
                end
            end
        end
        if not entryFound then
            missingEntries[#missingEntries+1] = mat
        end
    end
    zprospectanalyzer.printMaterials(zprospectanalyzer.sortMaterials(foundEntries))
    for _, mat in ipairs(missingEntries) do
        print(string.format(
            "    %-15s : %7s   <not found>",
            mat:upper(), "-"
        ))
    end
end

-- Execute main when run as script
zprospectanalyzer.main(...)

return zprospectanalyzer

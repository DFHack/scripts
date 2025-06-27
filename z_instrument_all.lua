-- z_instrument_all.lua
-- Automatically places work orders for all discovered instruments using: 'instruments order <name> <count>'
-- Optionally accepts a numeric argument to specify the number of each instrument to order (default is 1)

local function collect_unique_instrument_names()
    local success, raw_output = pcall(function()
        return dfhack.run_command_silent("instruments")
    end)

    if not success or not raw_output then
        qerror("Failed to run 'instruments': " .. tostring(raw_output))
    end

    local instrument_names = {}
    local seen_names = {}

    for line in raw_output:gmatch("[^\r\n]+") do
        local normalized = dfhack.toSearchNormalized(line)
        if not normalized:match("^%s*make") and not normalized:match("^%s*forge") then
            local raw_name = line:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
            local normalized_name = dfhack.toSearchNormalized(raw_name)
            if raw_name ~= "" and not seen_names[normalized_name] then
                seen_names[normalized_name] = true
                table.insert(instrument_names, { name = raw_name, original_line = line })
            end
        end
    end

    return instrument_names
end

local function place_instrument_work_orders(order_count)
    local instruments = collect_unique_instrument_names()
    local counts = { building = 0, handheld = 0, total = 0 }

    for _, instrument in ipairs(instruments) do
        local name = instrument.name
        local type = "unknown"

        -- Determine type based on line description
        local line_lower = instrument.original_line:lower()
        if line_lower:find("building") then
            type = "building"
        elseif line_lower:find("handheld") then
            type = "handheld"
        end

        print("------------------------------")
        print("Placed order for: " .. name .. " (x" .. order_count .. ") [" .. type .. "]")
        print("------------------------------")

        local success, err = pcall(function()
            dfhack.run_command("instruments", "order", name, tostring(order_count))
        end)

        if not success then
            dfhack.printerr("Failed to place order for '" .. name .. "': " .. tostring(err))
        else
            counts[type] = counts[type] + order_count
            counts.total = counts.total + order_count
        end
    end

    -- Summary
    print("\n==== Instrument Order Summary ====")
    print("Total instruments ordered: " .. counts.total)
    print("  Handheld: " .. counts.handheld)
    print("  Building: " .. counts.building)
    print("==================================\n")
end

-- Main execution
local args = {...}
local quantity = 1

if #args == 1 then
    local parsed = tonumber(args[1])
    if parsed and parsed > 0 then
        quantity = math.floor(parsed)
    else
        qerror("Invalid argument. Usage: z_instrument_all [number_of_orders_per_instrument]")
    end
elseif #args > 1 then
    qerror("Too many arguments. Usage: z_instrument_all [number_of_orders_per_instrument]")
end

local ok, err = pcall(function()
    place_instrument_work_orders(quantity)
end)
if not ok then
    qerror("Script failed: " .. tostring(err))
end

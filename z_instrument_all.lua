-- ztest.lua
-- Automatically places work orders for all discovered instruments using: 'instruments order <name> <count>'
-- Accepts an optional numeric argument to control how many of each to order (default is 1)

-- Retrieves and returns a list of unique instrument names from the DFHack 'instruments' command.
-- Strips parenthetical info and filters out crafting steps like 'make' or 'forge'.
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
        local normalized_line = dfhack.toSearchNormalized(line)

        -- Skip crafting steps
        if not normalized_line:match("^%s*make") and not normalized_line:match("^%s*forge") then
            -- Remove content in parentheses and trim whitespace
            local name = normalized_line:gsub("%s*%b()", ""):gsub("^%s+", ""):gsub("%s+$", "")
            if name ~= "" and not seen_names[name] then
                seen_names[name] = true
                table.insert(instrument_names, name)
            end
        end
    end

    return instrument_names
end

-- Submits DFHack instrument work orders using the list of instrument names and specified count.
local function place_instrument_work_orders(order_count)
    local names = collect_unique_instrument_names()

    for _, instrument in ipairs(names) do
        print("------------------------------\n")

        print("Placed order for: " .. instrument .. " (x" .. order_count .. ")\n")
        local success, err = pcall(function()
            dfhack.run_command("instruments", "order", instrument, tostring(order_count))
        end)

        if not success then
            dfhack.printerr("Failed to place order for '" .. instrument .. "': " .. tostring(err))
        end
        print("------------------------------\n")
    end
end

-- Main entry point: processes optional count argument and triggers order placement.
local args = {...}
local quantity = 1  -- Default number of orders per instrument

if #args == 1 then
    local parsed = tonumber(args[1])
    if parsed and parsed > 0 then
        quantity = math.floor(parsed)
    else
        qerror("Invalid argument. Usage: ztest [number_of_orders_per_instrument]")
    end
elseif #args > 1 then
    qerror("Too many arguments. Usage: ztest [number_of_orders_per_instrument]")
end

local ok, err = pcall(function()
    place_instrument_work_orders(quantity)
end)
if not ok then
    qerror("Script failed: " .. tostring(err))
end

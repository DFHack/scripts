local stockpiles = df.global.world.buildings.other.STOCKPILE
local tool_items = df.global.world.items.other.TOOL

local function get_total_stockpiles()
    local count = 0
    for _ in ipairs(stockpiles) do
        count = count + 1
    end
    return count
end

local function get_total_wheelbarrows()
    local count = 0
    for _, item in ipairs(tool_items) do
        if df.item_toolst:is_instance(item) and item.subtype and item.subtype.id == "ITEM_TOOL_WHEELBARROW" then
            count = count + 1
        end
    end
    return count
end

local function log_summary(total_stockpiles, total_wheelbarrows, needed_wheelbarrows)
    print(string.format("Total stockpiles in fortress: %d", total_stockpiles))
    print(string.format("Total wheelbarrows in fortress: %d", total_wheelbarrows))

    if needed_wheelbarrows > total_wheelbarrows then
        print(string.format("You need to craft %d more wheelbarrows.", needed_wheelbarrows - total_wheelbarrows))
    elseif needed_wheelbarrows < total_wheelbarrows then
        print(string.format("You have %d excess wheelbarrows.", total_wheelbarrows - needed_wheelbarrows))
    else
        print("You have exactly the number of wheelbarrows needed.")
    end
end

local function assign_wheelbarrows_to_stockpiles()
    local total_needed = 0

    print("\n--- Stockpiles Assigned Wheelbarrows ---")
    for _, bld in ipairs(stockpiles) do
        local width = bld.x2 - bld.x1 + 1
        local height = bld.y2 - bld.y1 + 1
        local area = width * height
        local desired_wheelbarrows = math.floor(area / 3)

        local flags = bld.settings and bld.settings.flags
        if flags and (flags.stone or flags.furniture or flags.corpses) then
            bld.storage.max_wheelbarrows = desired_wheelbarrows
            total_needed = total_needed + desired_wheelbarrows
            print(string.format("Stockpile #%d: size %d x %d = %d tiles, needs %d wheelbarrows", bld.id, width, height, area, desired_wheelbarrows))
        end
    end

    local skipped_count = 0
    for _, bld in ipairs(stockpiles) do
        local flags = bld.settings and bld.settings.flags
        if not (flags and (flags.stone or flags.furniture or flags.corpses)) then
            bld.storage.max_wheelbarrows = 0
            skipped_count = skipped_count + 1
        end
    end
    print("\n--- Skipped Stockpiles ---")
    print(string.format("Skipped %d stockpiles (not stone, furniture, or corpses) \n", skipped_count))

    return total_needed
end

local function clear_wheelbarrow_assignments()
    for _, item in ipairs(tool_items) do
        if df.item_toolst:is_instance(item)
            and item.subtype
            and item.subtype.id == "ITEM_TOOL_WHEELBARROW" then

            if #item.specific_refs > 0 or #item.general_refs > 0 then
                print(string.format("Wheelbarrow ID %d in use, skipping", item.id))
            elseif item.stockpile then
                item.stockpile.id = -1
                item.stockpile.x = -30000
                item.stockpile.y = -30000
            end
        end
    end
end

local total_stockpiles = get_total_stockpiles()
local total_wheelbarrows = get_total_wheelbarrows()
local needed_wheelbarrows = assign_wheelbarrows_to_stockpiles()

log_summary(total_stockpiles, total_wheelbarrows, needed_wheelbarrows)

print("\n> zAutowheelbarrow\n")

clear_wheelbarrow_assignments()
-- handles automatic fishing jobs to limit the number of fish the fortress keeps on hand
-- autofish [enable | disable] <max> [min] [--include-raw | -r]

--@ enable=true
--@ module=true

local json = require("json")
local persist = require("persist-table")
local argparse = require("argparse")

local GLOBAL_KEY = "autofish"

-- set default enabled state
enabled = enabled or false
set_maxFish = set_maxFish or 100
set_minFish = set_minFish or 50
set_useRaw = set_useRaw or true
isFishing = isFishing or true

function isEnabled()
    return enabled
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({enabled=enabled,
        set_maxFish=set_maxFish, set_minFish=set_minFish, set_useRaw=set_useRaw,
        isFishing=isFishing
    })
end

local function load_state()
    -- load persistent data
    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or "")
    enabled = (persisted_data or {enabled=false})["enabled"]
    set_maxFish = (persisted_data or {set_maxFish=100})["set_maxFish"]
    set_minFish = (persisted_data or {set_minFish=50})["set_minFish"]
    set_useRaw = (persisted_data or {set_useRaw=true})["set_useRaw"]
    isFishing = (persisted_data or {isFishing=true})["isFishing"]
end


-- toggle the fishing labour on all dwarves/work detail if enabled
function toggle_fishing_labour(state)
    -- pass true to state to turn on, otherwise disable
    -- find all work details that have fishing enabled:
    local work_details = df.global.plotinfo.hauling.work_details
    for _,v in pairs(work_details) do
        if v.allowed_labors.FISH then
            -- set limited to true just in case a custom work detail is being
            -- changed, to prevent *all* dwarves from fishing.
            v.work_detail_flags.limited = true
            v.work_detail_flags.enabled = state

            -- workaround to actually enable labours
            for _,v2 in ipairs(v.assigned_units) do
                -- find unit by ID and toggle fishing
                local unit = df.unit.find(v2)
                unit.status.labors.FISH = state
            end
        end
    end
    isFishing = state -- save current state

    -- let the user know we've got enough, or run out of fish
    if isFishing then
        print("autofish: Re-enabling fishing, fallen below minimum.")
    else
        print("autofish: Disabling fishing, reached desired quota.")
    end
end

-- check if an item isn't forbidden/rotten/on fire/etc..
function isValidItem(item)
    local flags = item.flags
    if flags.rotten or flags.trader or flags.hostile or flags.forbid
        or flags.dump or flags.on_fire or flags.garbage_collect or flags.owned
        or flags.removed or flags.encased or flags.spider_web then
        return false
    end
    return true
end

function event_loop()
    --print(enabled, set_minFish, set_maxFish, set_useRaw, isFishing)
    if not enabled then return end
    local world = df.global.world

    -- count the number of valid fish we have. (not rotten, forbidden, on fire, dumping...)
    local prepared, raw = 0, 0
    for k,v in pairs(world.items.other[df.items_other_id.IN_PLAY]) do
        if v:getType() == df.item_type.FISH and isValidItem(v) then
            prepared = prepared + v:getStackSize()
        end
        if (v:getType() == df.item_type.RAW_FISH and isValidItem(v)) and set_useRaw then
            raw = raw + v:getStackSize()
        end
    end

    -- hande pausing/resuming labour
    local numFish = set_useRaw and (prepared + raw) or prepared
    --print(numFish)
    if numFish >= set_maxFish and isFishing then
        toggle_fishing_labour(false)
    elseif numFish < set_minFish and not isFishing then
        toggle_fishing_labour(true)
    end
    -- don't need to check *that* often
    dfhack.timeout(1, "days", event_loop)
end



local function print_status()
    load_state()
    --print(string.format("%s max, %s min, %s useraw", settings.maxFish, settings.minFish, tostring(settings.useRawFish)))
    print(string.format("autofish is currently %s.\n", (enabled and "enabled" or "disabled")))
    if enabled then

        local rfs
        rfs = set_useRaw and "raw & prepared" or "prepared"

        print(string.format("Stopping at %s %s fish.", set_maxFish, rfs))
        print(string.format("Restarting at %s %s fish.", set_minFish, rfs))
        if isFishing then
            print("\nCurrently allowing fishing.")
        else
            print("\nCurrently not allowing fishing.")
        end
    end
end

-- handle loading
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    -- unload with game
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    load_state()

    -- run the main code
    event_loop()
end


-- sanity checks?
if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr("autofish needs a loaded fortress to work")
end

-- argument handling
local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and "enable" or "disable"}
end

-- find flags in args:
local positionals = argparse.processArgsGetopt(args,
    {{"r", "toggle-raw",
    handler=function() set_useRaw = not set_useRaw end}
})

if positionals[1] == "enable" then
    enabled = true
    --print_status()
elseif positionals[1] == "disable" then
    enabled = false
elseif positionals[1] == "status" then
    print_status()
    return
elseif positionals ~= nil then
    -- positionals is a number?
    if positionals[1] and tonumber(positionals[1]) then
        -- assume we're changing setting:
        set_maxFish = tonumber(positionals[1])
    else
        -- invalid or no argument
        return
    end
    if positionals[2] and tonumber(positionals[2]) then
        set_minFish = tonumber(positionals[2])
    end
    -- a setting probably changed, save & show the updated settings.
    persist_state()
    print_status()
    return
end

--load_state()
event_loop()
persist_state()

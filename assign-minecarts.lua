-- assigns minecarts to hauling routes
--@ module = true
--[====[

assign-minecarts
================
This script allows you to assign minecarts to hauling routes without having to
use the in-game interface.

Usage::

    assign-minecarts list|all|<route id> [-q|--quiet]

:list: will show you information about your hauling routes, including whether
       they have minecarts assigned to them.
:all: will automatically assign a free minecart to all hauling routes that don't
      have a minecart assigned to them.

If you specifiy a route id, only that route will get a minecart assigned to it
(if it doesn't already have one and there is a free minecart available).

Add ``-q`` or ``--quiet`` to suppress informational output.

Note that a hauling route must have at least one stop defined before a minecart
can be assigned to it.
]====]

local argparse = require('argparse')
local quickfort = reqscript('quickfort')

-- ensures the list of available minecarts has been calculated by the game
local function refresh_ui_hauling_vehicles()
    local qfdata
    if #df.global.ui.hauling.routes > 0 then
        -- if there is an existing route, move to the vehicle screen and back
        -- out to force the game to scan for assignable minecarts
        qfdata = 'hv^^'
    else
        -- if no current routes, create a route, move to the vehicle screen,
        -- back out, and remove the route. The extra "px" is in the string in
        -- case the user has the confirm plugin enabled. "p" pauses the plugin
        -- and "x" retries the route deletion.
        qfdata = 'hrv^xpx^'
    end
    quickfort.apply_blueprint{mode='config', data=qfdata}
end

function get_free_vehicles()
    refresh_ui_hauling_vehicles()
    local free_vehicles = {}
    for _,minecart in ipairs(df.global.ui.hauling.vehicles) do
        if minecart and minecart.route_id == -1 then
            table.insert(free_vehicles, minecart)
        end
    end
    return free_vehicles
end

local function has_minecart(route)
    return #route.vehicle_ids > 0
end

local function has_stops(route)
    return #route.stops > 0
end

local function get_name(route)
    return route.name and #route.name > 0 and route.name or ('Route '..route.id)
end

local function get_id_and_name(route)
    return ('%d (%s)'):format(route.id, get_name(route))
end

local function assign_minecart_to_route(route, quiet, minecart)
    if has_minecart(route) then
        return true
    end
    if not has_stops(route) then
        if not quiet then
            dfhack.printerr(
                ('Route %s has no stops defined. Cannot assign minecart.')
                :format(get_id_and_name(route)))
        end
        return false
    end
    if not minecart then
        minecart = get_free_vehicles()[1]
        if not minecart then
            if not quiet then
                dfhack.printerr('No minecarts available! Please build some.')
            end
            return false
        end
    end
    route.vehicle_ids:insert('#', minecart.id)
    route.vehicle_stops:insert('#', 0)
    minecart.route_id = route.id
    if not quiet then
        print(('Assigned a minecart to route %s.')
              :format(get_id_and_name(route)))
    end
    return true
end

-- assign first free minecart to the most recently-created route
-- returns whether route now has a minecart assigned
function assign_minecart_to_last_route(quiet)
    local routes = df.global.ui.hauling.routes
    local route_idx = #routes - 1
    if route_idx < 0 then
        return false
    end
    local route = routes[route_idx]
    return assign_minecart_to_route(route, quiet)
end

local function get_route_by_id(route_id)
    for _,route in ipairs(df.global.ui.hauling.routes) do
        if route.id == route_id then
            return route
        end
    end
end

local function list()
    local routes = df.global.ui.hauling.routes
    if 0 == #routes then
        print('No hauling routes defined.')
    else
        print(('Found %d route%s:\n')
              :format(#routes, #routes == 1 and '' or 's'))
        print('route id  minecart?  has stops?  route name')
        print('--------  ---------  ----------  ----------')
        for _,route in ipairs(routes) do
            print(('%-8d  %-9s  %-9s  %s')
                  :format(route.id,
                          has_minecart(route) and 'yes' or 'NO',
                          has_stops(route) and 'yes' or 'NO',
                          get_name(route)))
        end
    end
    local minecarts = get_free_vehicles()
    print(('\nYou have %d unassigned minecart%s.')
          :format(#minecarts, #minecarts == 1 and '' or 's'))
end

local function all(quiet)
    local minecarts, idx = get_free_vehicles(), 1
    local routes = df.global.ui.hauling.routes
    for _,route in ipairs(routes) do
        if has_minecart(route) then
            goto continue
        end
        if not assign_minecart_to_route(route, quiet, minecarts[idx]) then
            return
        end
        idx = idx + 1
        ::continue::
    end
end

local function do_help()
    print(dfhack.script_help())
end

local command_switch = {
    list=list,
    all=all,
}

local function main(args)
    local help, quiet = false, false
    local command = argparse.processArgsGetopt(args, {
            {'h', 'help', handler=function() help = true end},
            {'q', 'quiet', handler=function() quiet = true end}})[1]

    if help then
        command = nil
    end

    local requested_route_id = tonumber(command)
    if requested_route_id then
        local route = get_route_by_id(requested_route_id)
        if not route then
            dfhack.printerr('route id not found: '..requested_route_id)
        elseif has_minecart(route) then
            if not quiet then
                print(('Route %s already has a minecart assigned.')
                    :format(get_id_and_name(route)))
            end
        else
            assign_minecart_to_route(route, quiet)
        end
        return
    end

    (command_switch[command] or do_help)(quiet)
end

if not dfhack_flags.module then
    main({...})
end

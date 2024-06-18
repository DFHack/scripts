local am = reqscript('assign-minecarts')

local quickfort = reqscript('quickfort')

local mock_routes, mock_vehicles
local mock_apply_blueprint, mock_print, mock_script_help

config.wrapper = function(test_fn)
    mock_routes, mock_vehicles = {}, {}

    local mock_df = {}
    mock_df.global = {}
    mock_df.global.plotinfo = {}
    mock_df.global.plotinfo.hauling = {}
    mock_df.global.plotinfo.hauling.routes = mock_routes
    mock_df.global.plotinfo.hauling.vehicles = mock_vehicles

    mock_apply_blueprint, mock_print = mock.func(), mock.func()
    mock_script_help = mock.func()

    mock.patch({{am, 'df', mock_df},
                {quickfort, 'apply_blueprint', mock_apply_blueprint},
                {am.dfhack, 'script_help', mock_script_help},
                {am, 'print', mock_print}},
               test_fn)
end

function test.get_free_vehicles_no_routes()
    am.get_free_vehicles()
    expect.str_find('x', mock_apply_blueprint.call_args[1][1].data,
                    'should attempt to remove a route')
end

function test.get_free_vehicles_existing_routes()
    mock_routes[1] = {}
    am.get_free_vehicles()
    expect.str_find('v^^', mock_apply_blueprint.call_args[1][1].data,
                    'should not attempt to remove a route')
end

function test.get_free_vehicles_no_vehicles()
    expect.eq(0, #am.get_free_vehicles())
end

function test.get_free_vehicles_no_free_vehicles()
    mock_vehicles[1] = {route_id=10}
    mock_vehicles[2] = {route_id=11}
    expect.eq(0, #am.get_free_vehicles())
end

function test.get_free_vehicles_has_free_vehicles()
    mock_vehicles[1] = {route_id=10}
    mock_vehicles[2] = {route_id=-1}
    mock_vehicles[3] = {route_id=11}
    local free_vehicles = am.get_free_vehicles()
    expect.eq(1, #free_vehicles)
    expect.eq(mock_vehicles[2], free_vehicles[1])
end

function test.assign_minecart_to_last_route_no_routes()
    expect.false_(am.assign_minecart_to_last_route(true))
    expect.eq(0, mock_print.call_count)
end

function test.assign_minecart_to_last_route_already_has_minecart()
    mock_routes[1] = {stops={[1]={}}, vehicle_ids={10}}
    mock_routes[0] = mock_routes[1] -- simulate 0-based index
    expect.true_(am.assign_minecart_to_last_route(true))
    expect.eq(0, mock_print.call_count)
end

function test.assign_minecart_to_last_route_no_stops()
    mock_routes[1] = {stops={}, vehicle_ids={}}
    mock_routes[0] = mock_routes[1] -- simulate 0-based index
    expect.false_(am.assign_minecart_to_last_route(true))
    expect.eq(0, mock_print.call_count)
end

function test.assign_minecart_to_last_route_no_stops_output()
    mock_routes[1] = {id=10, stops={}, vehicle_ids={}}
    mock_routes[0] = mock_routes[1] -- simulate 0-based index
    expect.printerr_match('no stops defined',
        function() expect.false_(am.assign_minecart_to_last_route(false)) end)
end

function test.assign_minecart_to_last_route_no_minecarts_quiet()
    mock_routes[1] = {stops={[1]={}}, vehicle_ids={}}
    mock_routes[0] = mock_routes[1] -- simulate 0-based index
    expect.false_(am.assign_minecart_to_last_route(true))
    expect.eq(0, mock_print.call_count)
end

function test.assign_minecart_to_last_route_no_minecarts()
    mock_routes[1] = {id=10, stops={[1]={}}, vehicle_ids={}}
    mock_routes[0] = mock_routes[1] -- simulate 0-based index
    expect.printerr_match('No minecarts available',
        function() expect.false_(am.assign_minecart_to_last_route(false)) end)
end

local function fake_insert(self, pos, value)
    expect.eq('#', pos)
    table.insert(self, value)
end

function test.assign_minecart_to_last_route_happy()
    mock_vehicles[1] = {id=100, route_id=-1}
    mock_routes[1] = {id=5, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}}
    mock_routes[0] = mock_routes[1] -- simulate 0-based index
    expect.true_(am.assign_minecart_to_last_route(true))
    expect.eq(1, #mock_routes[1].vehicle_ids)
    expect.eq(100, mock_routes[1].vehicle_ids[1])
    expect.eq(1, #mock_routes[1].vehicle_stops)
    expect.eq(0, mock_routes[1].vehicle_stops[1])
    expect.eq(5, mock_vehicles[1].route_id)
    expect.eq(0, mock_print.call_count)
end

function test.main_all_more_routes_than_vehicles()
    mock_vehicles[1] = {id=100, route_id=-1}
    mock_vehicles[2] = {id=200, route_id=-1}
    mock_routes[1] = {id=10, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}}
    mock_routes[2] = {id=20, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}}
    mock_routes[3] = {id=30, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}}

    dfhack.run_script('assign-minecarts', 'all', '-q')

    expect.eq(100, mock_routes[1].vehicle_ids[1])
    expect.eq(10, mock_vehicles[1].route_id)
    expect.eq(200, mock_routes[2].vehicle_ids[1])
    expect.eq(20, mock_vehicles[2].route_id)
    expect.eq(0, #mock_routes[3].vehicle_ids)

    expect.eq(0, mock_print.call_count)
end

function test.main_all_more_vehicles_than_routes()
    mock_vehicles[1] = {id=100, route_id=-1}
    mock_vehicles[2] = {id=200, route_id=-1}
    mock_vehicles[3] = {id=300, route_id=-1}
    mock_routes[1] = {id=10, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}}
    mock_routes[2] = {id=20, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}}

    dfhack.run_script('assign-minecarts', 'all', '-q')

    expect.eq(100, mock_routes[1].vehicle_ids[1])
    expect.eq(10, mock_vehicles[1].route_id)
    expect.eq(200, mock_routes[2].vehicle_ids[1])
    expect.eq(20, mock_vehicles[2].route_id)
    expect.eq(-1, mock_vehicles[3].route_id)

    expect.eq(0, mock_print.call_count)
end

function test.main_list_no_routes_no_minecarts()
    dfhack.run_script('assign-minecarts', 'list')

    expect.eq(2, mock_print.call_count)
    expect.str_find('No hauling routes', mock_print.call_args[1][1])
    expect.str_find('0 unassigned minecarts', mock_print.call_args[2][1])
end

function test.main_list_happy()
    mock_vehicles[1] = {id=100, route_id=-1}
    mock_vehicles[2] = {id=200, route_id=20}
    mock_routes[1] = {id=10, stops={[1]={}}, vehicle_ids={},
                      vehicle_stops={}, name='goober'}
    mock_routes[2] = {id=20, stops={[1]={}}, vehicle_ids={20},
                      vehicle_stops={0}}

    dfhack.run_script('assign-minecarts', 'list')

    expect.eq(6, mock_print.call_count)
    expect.str_find('Found 2 routes', mock_print.call_args[1][1])
    expect.str_find('10%s+NO%s+yes%s+goober', mock_print.call_args[4][1])
    expect.str_find('20%s+yes%s+yes%s+Route 20', mock_print.call_args[5][1])
    expect.str_find('1 unassigned minecart', mock_print.call_args[6][1])
end

function test.main_route_id_not_exist()
    expect.printerr_match('route id not found',
            function() dfhack.run_script('assign-minecarts', '1000') end)
end

function test.main_route_id_already_has_minecart()
    mock_vehicles[1] = {id=100, route_id=-1}
    mock_routes[1] = {id=10, stops={[1]={}}, vehicle_ids={100},
                      vehicle_stops={0}}

    dfhack.run_script('assign-minecarts', '10')

    expect.eq(1, mock_print.call_count)
    expect.str_find('already has a minecart', mock_print.call_args[1][1])
end

function test.main_route_id_happy()
    mock_vehicles[1] = {id=100, route_id=-1}
    mock_routes[1] = {id=10, stops={[1]={}}, vehicle_ids={insert=fake_insert},
                      vehicle_stops={insert=fake_insert}, name='dumper'}

    dfhack.run_script('assign-minecarts', '10')

    expect.eq(100, mock_routes[1].vehicle_ids[1])
    expect.eq(10, mock_vehicles[1].route_id)
    expect.eq(1, mock_print.call_count)
    expect.str_find('Assigned a minecart', mock_print.call_args[1][1])
end

function test.main_help_no_args()
    dfhack.run_script('assign-minecarts')
    expect.eq(1, mock_script_help.call_count)
end

function test.main_help_help()
    dfhack.run_script('assign-minecarts', 'help')
    expect.eq(1, mock_script_help.call_count)
end

function test.main_help_help_opt()
    dfhack.run_script('assign-minecarts', '--help')
    expect.eq(1, mock_script_help.call_count)
end

function test.main_help_command_with_help_opt()
    dfhack.run_script('assign-minecarts', 'list', '--help')
    expect.eq(1, mock_script_help.call_count)
end

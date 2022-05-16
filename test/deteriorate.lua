local d = reqscript('deteriorate')

local mock_timeout_ids
local mock_clothes_not_valid_worn, mock_clothes_valid_not_worn, mock_clothes_valid_worn
local mock_corpse_not_valid_worn, mock_corpse_valid_not_worn, mock_corpse_valid_newly_worn, mock_corpse_valid_worn
local mock_remains_not_valid_worn, mock_remains_valid_not_worn, mock_remains_valid_newly_worn, mock_remains_valid_worn
local mock_food_valid_not_worn, mock_food_valid_newly_worn, mock_food_valid_worn
local mock_df, mock_script_help, mock_print, mock_timeout, mock_timeout_active

config.wrapper = function(test_fn)
    mock_timeout_ids = {clothes={}, corpses={}, food={}}

    mock_clothes_not_valid_worn = {subtype={armorlevel=1}, flags={on_ground=true}, wear=3, wear_timer=100}
    mock_clothes_valid_not_worn = {subtype={armorlevel=0}, flags={on_ground=true}, wear=1, wear_timer=100}
    mock_clothes_valid_worn = {subtype={armorlevel=0}, flags={on_ground=true}, wear=3, wear_timer=0}

    mock_corpse_not_valid_worn = {flags={dead_dwarf=true}, wear=3, wear_timer=100}
    mock_corpse_valid_not_worn = {flags={}, wear=1, wear_timer=100}
    mock_corpse_valid_newly_worn = {flags={}, wear=3, wear_timer=100}
    mock_corpse_valid_worn = {flags={}, wear=4, wear_timer=0}

    mock_remains_not_valid_worn = {flags={dead_dwarf=true}, wear=3, wear_timer=100}
    mock_remains_valid_not_worn = {flags={}, wear=1, wear_timer=100}
    mock_remains_valid_newly_worn = {flags={}, wear=3, wear_timer=100}
    mock_remains_valid_worn = {flags={}, wear=4, wear_timer=0}

    mock_food_valid_not_worn = {flags={}, wear=1, wear_timer=100}
    mock_food_valid_newly_worn = {flags={}, wear=3, wear_timer=100}
    mock_food_valid_worn = {flags={}, wear=4, wear_timer=0}

    mock_df = {}
    mock_df.global = {}
    mock_df.global.world = {}
    mock_df.global.world.items = {}
    mock_df.global.world.items.other = {}
    mock_df.global.world.items.other.GLOVES = {mock_clothes_not_valid_worn, mock_clothes_valid_not_worn, mock_clothes_valid_worn}
    mock_df.global.world.items.other.ARMOR = {}
    mock_df.global.world.items.other.SHOES = {}
    mock_df.global.world.items.other.PANTS = {}
    mock_df.global.world.items.other.HELM = {}
    mock_df.global.world.items.other.ANY_CORPSE = {mock_corpse_not_valid_worn, mock_corpse_valid_not_worn, mock_corpse_valid_newly_worn, mock_corpse_valid_worn}
    mock_df.global.world.items.other.REMAINS = {mock_remains_not_valid_worn, mock_remains_valid_not_worn, mock_remains_valid_newly_worn, mock_remains_valid_worn}
    mock_df.global.world.items.other.FISH = {mock_food_valid_not_worn, mock_food_valid_newly_worn, mock_food_valid_worn}
    mock_df.global.world.items.other.FISH_RAW = {}
    mock_df.global.world.items.other.EGG = {}
    mock_df.global.world.items.other.CHEESE = {}

    mock_script_help, mock_print = mock.func(''), mock.func()
    mock_timeout, mock_timeout_active = mock.func(1), mock.func()

    mock.patch({{d, 'timeout_ids', mock_timeout_ids},
                {d, 'df', mock_df},
                {d.dfhack, 'script_help', mock_script_help},
                {d.dfhack, 'isMapLoaded', mock.func(true)},
                {d.dfhack, 'timeout', mock_timeout},
                {d.dfhack, 'timeout_active', mock_timeout_active},
                {d, 'print', mock_print}},
               function()
                   test_fn()
                   -- cancel any leftover timeout callbacks
                   dfhack.run_script('deteriorate', 'stop', '-qtclothes,corpses,food')
               end)
end

function test.help()
    dfhack.run_script('deteriorate')
    expect.eq(1, mock_script_help.call_count)
    dfhack.run_script('deteriorate', '-h')
    expect.eq(2, mock_script_help.call_count)
    dfhack.run_script('deteriorate', '--help')
    expect.eq(3, mock_script_help.call_count)
    dfhack.run_script('deteriorate', 'help')
    expect.eq(4, mock_script_help.call_count)
    dfhack.run_script('deteriorate', 'goober')
    expect.eq(5, mock_script_help.call_count)
end

function test.no_map_loaded()
    mock.patch(d.dfhack, 'isMapLoaded', mock.func(false), function()
        expect.error_match('needs a fortress map', function()
            dfhack.run_script('deteriorate', 'status')
        end)
    end)
end

function test.missing_types()
    expect.error_match('no item types',
            function() dfhack.run_script('deteriorate', 'start') end)
end

function test.bad_type()
    expect.error_match('unrecognized type',
            function() dfhack.run_script('deteriorate', '--types=food,bad') end)
end

function test.bad_time()
    expect.error_match('number parameter',
            function() dfhack.run_script('deteriorate', '--freq=') end)
    expect.error_match('number parameter',
            function() dfhack.run_script('deteriorate', '--freq=notnumber') end)
    expect.error_match('number parameter',
            function() dfhack.run_script('deteriorate', '--freq=-5') end)
end

function test.bad_mode()
    expect.error_match('invalid time unit',
            function() dfhack.run_script('deteriorate', '--freq=1,') end)
    expect.error_match('invalid time unit',
            function() dfhack.run_script('deteriorate', '--freq=1,dayss') end)
    expect.error_match('invalid time unit',
            function() dfhack.run_script('deteriorate', '--freq=1,goober') end)
end

function test.status_all_stopped()
    dfhack.run_script('deteriorate', 'status')
    expect.eq(3, mock_print.call_count)
    for i=1,3 do
        expect.str_find('Stopped', mock_print.call_args[i][1])
    end
end

function test.status_show_freq()
    dfhack.run_script('deteriorate', 'start', '-qtclothes', '-f10,month')
    dfhack.run_script('deteriorate', 'start', '-qtcorpses', '-f1,years')
    dfhack.run_script('deteriorate', 'start', '-qtfood', '-f0.5')
    dfhack.run_script('deteriorate', 'status')
    expect.eq(3, mock_print.call_count)
    for i=1,3 do
        local text = mock_print.call_args[i][1]
        expect.str_find('Running', text)
        if text:find('clothes') then expect.str_find('10 months', text)
        elseif text:find('corpses') then expect.str_find('1 year', text)
        elseif text:find('food') then expect.str_find('0.5 days', text)
        else expect.fail('did not match print text: ' .. text) end
    end
end

function test.start_stop()
    dfhack.run_script('deteriorate', 'start', '-tcorpses', '-f1,years')
    expect.ne(nil, mock_timeout_ids.corpses.id)
    expect.eq(1, mock_print.call_count)
    expect.str_find('corpses commencing', mock_print.call_args[1][1])
    dfhack.run_script('deteriorate', 'stop', '-tcorpses')
    expect.nil_(mock_timeout_ids.corpses.id)
    expect.eq(2, mock_print.call_count)
    expect.str_find('Stopped deteriorating corpses', mock_print.call_args[2][1])
end

function test.stop_on_map_unload()
    dfhack.run_script('deteriorate', 'start', '-qtcorpses,clothes')
    expect.ne(nil, mock_timeout_ids.corpses.id)
    expect.ne(nil, mock_timeout_ids.clothes.id)
    mock.patch(d.dfhack, 'timeout', mock.func(), function()
        -- invoke one of the callbacks, both should then be canceled
        mock_timeout.call_args[1][3]()
        expect.nil_(mock_timeout_ids.corpses.id)
        expect.nil_(mock_timeout_ids.clothes.id)
    end)
end

function test.change_freq()
    dfhack.run_script('deteriorate', 'start', '-qtcorpses', '-f1,years')
    expect.eq(1, mock_timeout_ids.corpses.time)
    expect.eq('years', mock_timeout_ids.corpses.mode)
    dfhack.run_script('deteriorate', 'start', '-qtcorpses', '-f5')
    expect.eq(5, mock_timeout_ids.corpses.time)
    expect.eq('days', mock_timeout_ids.corpses.mode)
end

function test.reregister_on_cb()
    dfhack.run_script('deteriorate', 'start', '-qtcorpses')
    expect.eq(1, mock_timeout.call_count)
    -- manually call the callbacks
    mock_timeout.call_args[1][3]()
    expect.eq(2, mock_timeout.call_count)
end

function test.wear_clothes()
    dfhack.run_script('deteriorate', 'start', '-qtclothes')
    -- call the callback
    mock_timeout.call_args[1][3]()
    -- ensure clothes are deteriorated and corpses and food items are not
    expect.nil_(mock_clothes_not_valid_worn.flags.garbage_collect,
                'clothes with armor level > 0 incorrectly deteriorated')
    expect.eq(150, mock_clothes_valid_not_worn.wear_timer,
              'wear_timer expected to be incremented but was not')
    expect.nil_(mock_clothes_valid_not_worn.flags.garbage_collect,
                'clothes with wear level < 3 incorrectly garbage collected')
    expect.true_(mock_clothes_valid_worn.flags.garbage_collect,
                 'clothes with wear >= 3 not garbage collected')

    expect.nil_(mock_corpse_valid_worn.flags.garbage_collect,
                'corpses should not be deteriorated')
    expect.nil_(mock_food_valid_worn.flags.garbage_collect,
                'food should not be deteriorated')
end

function test.wear_corpses()
    dfhack.run_script('deteriorate', 'start', '-qtcorpses')
    -- call the callback
    mock_timeout.call_args[1][3]()
    -- ensure corpse and remains are deteriorated
    expect.nil_(mock_corpse_not_valid_worn.flags.garbage_collect,
                'dwarf corpse incorrectly deteriorated')
    expect.eq(2, mock_corpse_valid_not_worn.wear,
              'wear expected to be incremented but was not')
    expect.true_(mock_corpse_valid_newly_worn.flags.garbage_collect,
                'newly worn corpse should be garbage collected')
    expect.true_(mock_corpse_valid_worn.flags.garbage_collect,
                 'corpse with wear >= 3 not garbage collected')

    expect.nil_(mock_remains_not_valid_worn.flags.garbage_collect,
                'dwarf remains incorrectly deteriorated')
    expect.eq(2, mock_remains_valid_not_worn.wear,
              'wear expected to be incremented but was not')
    expect.true_(mock_remains_valid_newly_worn.flags.garbage_collect,
                'newly worn remains should be garbage collected')
    expect.true_(mock_remains_valid_worn.flags.garbage_collect,
                 'remains with wear >= 3 not garbage collected')
end

function test.wear_food()
    dfhack.run_script('deteriorate', 'start', '-qtfood')
    -- call the callback
    mock_timeout.call_args[1][3]()
    -- ensure food is deteriorated
    expect.eq(2, mock_food_valid_not_worn.wear,
              'wear expected to be incremented but was not')
    expect.true_(mock_food_valid_newly_worn.flags.garbage_collect,
                'food with wear >= 3 not garbage collected')
    expect.true_(mock_food_valid_worn.flags.garbage_collect,
                 'food with wear >= 3 not garbage collected')
end

function test.wear_food_now()
    dfhack.run_script('deteriorate', 'now', '-tfood')
    expect.eq(1, mock_print.call_count)
    expect.str_find('Immediately deteriorating', mock_print.call_args[1][1])
    expect.true_(mock_food_valid_not_worn.flags.garbage_collect)
    expect.true_(mock_food_valid_newly_worn.flags.garbage_collect)
    expect.true_(mock_food_valid_worn.flags.garbage_collect)
end

function test.wear_all_now()
    dfhack.run_script('deteriorate', 'now', '-qtfood,corpses,clothes')
    expect.nil_(mock_clothes_not_valid_worn.flags.garbage_collect)
    expect.true_(mock_clothes_valid_not_worn.flags.garbage_collect)
    expect.true_(mock_clothes_valid_worn.flags.garbage_collect)

    expect.nil_(mock_corpse_not_valid_worn.flags.garbage_collect)
    expect.true_(mock_corpse_valid_not_worn.flags.garbage_collect)
    expect.true_(mock_corpse_valid_newly_worn.flags.garbage_collect)
    expect.true_(mock_corpse_valid_worn.flags.garbage_collect)

    expect.nil_(mock_remains_not_valid_worn.flags.garbage_collect)
    expect.true_(mock_remains_valid_not_worn.flags.garbage_collect)
    expect.true_(mock_remains_valid_newly_worn.flags.garbage_collect)
    expect.true_(mock_remains_valid_worn.flags.garbage_collect)

    expect.true_(mock_food_valid_not_worn.flags.garbage_collect)
    expect.true_(mock_food_valid_newly_worn.flags.garbage_collect)
    expect.true_(mock_food_valid_worn.flags.garbage_collect)
end

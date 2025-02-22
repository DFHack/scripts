-- Report cursor and mouse position, along with other info.
--@ module = true

local argparse = require('argparse')
local guidm = require('gui.dwarfmode')

local function parse_args(args)
    local opts = {}
    local positionals = argparse.processArgsGetopt(args,
    {
        {'c', 'copy', handler=function() opts.copy = true end},
    })

    if #positionals > 0 then
        qerror('Too many positionals!')
    end

    return opts
end

local months =
{
    'Granite, in early Spring.',
    'Slate, in mid Spring.',
    'Felsite, in late Spring.',
    'Hematite, in early Summer.',
    'Malachite, in mid Summer.',
    'Galena, in late Summer.',
    'Limestone, in early Autumn.',
    'Sandstone, in mid Autumn.',
    'Timber, in late Autumn.',
    'Moonstone, in early Winter.',
    'Opal, in mid Winter.',
    'Obsidian, in late Winter.',
}

function print_time_info()
    --Fortress mode counts 1200 ticks per day and 403200 per year
    --Adventurer mode counts 86400 ticks to a day and 29030400 ticks per year
    --Twelve months per year, 28 days to every month, 336 days per year
    local julian_day = df.global.cur_year_tick // 1200 + 1
    local month = julian_day // 28 + 1 --days and months are 1-indexed
    local day = julian_day % 28

    local time_of_day = df.global.cur_year_tick_advmode // 336
    local second = time_of_day % 60
    local minute = time_of_day // 60 % 60
    local hour = time_of_day // 3600 % 24

    print('Time:')
    print(('    The time is %02d:%02d:%02d'):format(hour, minute, second))
    print(('    The date is %03d-%02d-%02d'):format(df.global.cur_year, month, day))
    print('    It is the month of '..months[month])

    local eras = df.global.world.history.eras
    if #eras > 0 then
        print('    It is the '..eras[#eras-1].title.name..'.')
    end
end

function get_adv_region_pos() --Regional coords
    if not dfhack.world.getAdventurer() then --Army exists when unit doesn't
        local army = df.army.find(df.global.adventure.player_army_id)
        if army then
            return army.pos.x//48, army.pos.y//48
        end
    end
    local wd = df.global.world.world_data
    return wd.midmap_data.adv_region_x, wd.midmap_data.adv_region_y
end

local function print_world_info()
    local wd = df.global.world.world_data
    local site = dfhack.world.getCurrentSite()
    if site then
        print(('    The current site is at x=%d, y=%d on the %dx%d world map.'):
            format(site.pos.x, site.pos.y, wd.world_width, wd.world_height))
    end

    if dfhack.world.isAdventureMode() then
        local x, y = get_adv_region_pos()
        print(('    The adventurer is at x=%d, y=%d on the %dx%d world map.'):
            format(x, y, wd.world_width, wd.world_height))
    end
end

function print_place_info(cursor)
    print('Place:')
    print('    The z-level is z='..df.global.window_z)

    if cursor then
        local x, y = cursor.x, cursor.y
        print(('    The keyboard cursor is at x=%d, y=%d (%d+%d, %d+%d)'):
            format(x, y, x//16*16, x%16, y//16*16, y%16))
    else
        print('    The keyboard cursor is inactive.')
    end

    local x, y = dfhack.screen.getWindowSize()
    print('    The window is '..x..' tiles wide and '..y..' tiles high.')

    x, y = dfhack.screen.getMousePos()
    if x then
        print('    The mouse is at x='..x..', y='..y..' within the window.')
        local pos = dfhack.gui.getMousePos()
        if pos then
            print('    The mouse is over map tile x='..pos.x..', y='..pos.y)
        end
    else
        print('    The mouse is not in the DF window.')
    end

    print_world_info()
end

if dfhack_flags.module then
    return
end

function main(opts)
    local cursor = guidm.getCursorPos()

    if opts.copy then --Copy keyboard cursor to clipboard
        if not cursor then
            qerror('No keyboard cursor!')
        end
        dfhack.internal.setClipboardTextCp437(('%d,%d,%d'):format(cursor.x, cursor.y, cursor.z))
        return --Don't print anything
    end

    print_time_info()
    print_place_info(cursor)
end

main(parse_args({...}))

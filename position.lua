
local cursor = df.global.cursor
local args = {...}
if #args > 0 then --Copy keyboard cursor to clipboard
    if #args > 1 then
        qerror('Too many arguments!')
    elseif args[1] ~= '-c' and args[1] ~= '--copy' then
        qerror('Invalid argument "'..args[1]..'"!')
    elseif cursor.x < 0 then
        qerror('No keyboard cursor!')
    end

    dfhack.internal.setClipboardTextCp437(('%d,%d,%d'):format(cursor.x, cursor.y, cursor.z))
    return
end

local months = {
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

print('Place:')
print('    The z-level is z='..df.global.window_z)

if cursor.x < 0 then
    print('    The keyboard cursor is inactive.')
else
    print('    The keyboard cursor is at x='..cursor.x..', y='..cursor.y)
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

local wd = df.global.world.world_data
local site = dfhack.world.getCurrentSite()
if site then
    print(('    The current site is at x=%d, y=%d on the %dx%d world map.'):
        format(site.pos.x, site.pos.y, wd.world_width, wd.world_height))
elseif dfhack.world.isAdventureMode() then
    x, y = -1, -1
    for _,army in ipairs(df.global.world.armies.all) do
        if army.flags.player then
            x, y = army.pos.x // 48, army.pos.y // 48
            break
        end
    end
    if x < 0 then
        x, y = wd.midmap_data.adv_region_x, wd.midmap_data.adv_region_y
    end
    print(('    The adventurer is at x=%d, y=%d on the %dx%d world map.'):
        format(x, y, wd.world_width, wd.world_height))
end

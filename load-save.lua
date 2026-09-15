-- load a save non-interactively - intended to be run on startup

local gui = require 'gui'
local script = require('gui.script')

local folder_name = ({...})[1] or qerror("No folder name given")

-- the current title screen manages the whole continue-game flow: mode 0 is
-- the main menu, mode 2 the active world list, and mode 3 the save list.
-- getViewscreenByType finds it even when a child screen sits on top.
local function title_screen()
    return dfhack.gui.getViewscreenByType(df.viewscreen_titlest, 0)
end

local function load_screen()
    return dfhack.gui.getViewscreenByType(df.viewscreen_loadgamest, 0)
end

local function click_row(scr, y)
    local sw, _ = dfhack.screen.getWindowSize()
    df.global.gps.mouse_x = sw // 2
    df.global.gps.mouse_y = y
    df.global.gps.precise_mouse_x = df.global.gps.mouse_x * df.global.gps.tile_pixel_x
    df.global.gps.precise_mouse_y = df.global.gps.mouse_y * df.global.gps.tile_pixel_y
    gui.simulateInput(scr, '_MOUSE_L')
end

-- wait for the title screen to react to a click, polling every frame; mode
-- transitions play a fade animation and `mode` only flips once it
-- completes. the timeout is wall-clock because the title screen can
-- render far faster than 60 fps, making frame counts unreliable
local function wait_for_change(prev_mode, timeout_ms)
    local deadline = dfhack.getTickCount() + (timeout_ms or 2000)
    repeat
        script.sleep(1, 'frames')
        if load_screen() then return 'loading' end
        local scr = title_screen()
        if not scr then return 'other' end
        if scr.mode ~= prev_mode then return 'mode' end
    until dfhack.getTickCount() >= deadline
    return 'timeout'
end

-- List rows sit a few tiles below the screen center and are a couple of
-- tiles tall each; the pitch is not exact, so probe a small y band around
-- the estimate until the screen reacts.
local function click_list_entry(scr, index)
    local prev_mode = scr.mode
    local _, sh = dfhack.screen.getWindowSize()
    local base_y = sh < 60 and 25 or (sh // 2) + 3
    local est_y = base_y + math.floor(index * 8 / 3 + 0.5)
    for _, y in ipairs({est_y, est_y - 1, est_y + 1, est_y - 2, est_y + 2}) do
        click_row(scr, y)
        local result = wait_for_change(prev_mode)
        if result ~= 'timeout' then
            return result
        end
    end
    return 'timeout'
end

local function find_save_index(scr)
    for idx = 0, #scr.savegame_header_game - 1 do
        if scr.savegame_header_game[idx].filename_noext == folder_name then
            return idx
        end
    end
    return nil
end

local function main()
    local load = load_screen()
    if load then
        local name = load.cur_save and load.cur_save.filename_noext
        if name == folder_name then
            return  -- already loading the requested save
        end
        -- the header may not be populated yet, so the name can be empty
        qerror('A save is already loading' ..
            (name and name ~= '' and (': ' .. name) or ''))
    end

    local scr = title_screen()
    if not scr then
        qerror("Can't find title or load game screen")
    end

    -- mode 0: main menu. "Continue" is the top entry when a resumable game
    -- exists; clicking it lands on the world list (mode 2).
    if scr.mode == df.title_mode_type.MAIN_MENU then
        if scr.menu_line_id[0] ~= df.main_choice_type.Continue then
            qerror("Can't find 'Continue Playing' option")
        end
        local _, sh = dfhack.screen.getWindowSize()
        -- capture the mode before clicking: the transition applies
        -- synchronously inside the input feed, so reading it after
        -- the click would observe the new mode and never detect a change
        local prev_mode = scr.mode
        click_row(scr, sh < 60 and 25 or (sh // 2) + 3)
        if wait_for_change(prev_mode) ~= 'mode' then
            qerror('Failed to enter the world list')
        end
    end

    -- if a save list (mode 3) is already open, back out to the world list
    -- first so the search below can check every world
    if scr.mode == df.title_mode_type.CONTINUE_ACTIVE then
        local prev_mode = scr.mode
        scr:feed_key(df.interface_key.LEAVESCREEN)
        wait_for_change(prev_mode)
    end

    -- mode 2: world list. Enter each world in turn and search its save list
    -- (mode 3), backing out to the world list between misses.
    if scr.mode ~= df.title_mode_type.CONTINUE_ACTIVE_WORLD then
        qerror(('Unexpected screen state: title screen mode %s'):format(
            tostring(scr.mode)))
    end
    for world_idx = 0, #scr.savegame_header_world - 1 do
        if click_list_entry(scr, world_idx) ~= 'mode' then
            qerror('Failed to select a world')
        end
        local save_idx = find_save_index(scr)
        if save_idx then
            if click_list_entry(scr, save_idx) == 'loading' then
                local loading = load_screen()
                if loading.cur_save.filename_noext == folder_name then
                    print(('Loading save "%s"'):format(folder_name))
                    return
                end
                qerror(('Started loading "%s" instead of "%s"'):format(
                    tostring(loading.cur_save.filename_noext), folder_name))
            end
            qerror('Failed to start loading the save')
        end
        -- wrong world; back out to the world list and try the next one
        local prev_mode = scr.mode
        scr:feed_key(df.interface_key.LEAVESCREEN)
        wait_for_change(prev_mode)
        if not title_screen()
            or scr.mode ~= df.title_mode_type.CONTINUE_ACTIVE_WORLD then
            qerror('Failed to return to the world list')
        end
    end
    qerror("Can't find save: " .. folder_name)
end

-- frame-level waiting needs a script coroutine
script.start(main)

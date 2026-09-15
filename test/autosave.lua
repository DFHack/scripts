config = {
    mode = 'fortress',
    target = 'autosave',
}

local autosave = reqscript('autosave')

-- saving can take a while for large forts
local SAVE_TIMEOUT_FRAMES = 6000

local function wait_for_save()
    -- the unsaved time counter resets when a save completes, so it decreasing
    -- below the value captured before triggering the save means it finished
    local before = dfhack.persistent.getUnsavedSeconds()
    return function()
        return dfhack.persistent.getUnsavedSeconds() < before
    end
end

config.wrapper = function(test_fn)
    -- dfhack.run_script is patched during tests to use a test-local script
    -- env, but enable/disable go through dfhack.enable_script and act on the
    -- real env, so drive the real env directly with run_script_with_env
    local orig_interval = autosave.config.data.interval_minutes
    dfhack.enable_script('autosave', false)
    local ok, err = pcall(test_fn)
    dfhack.enable_script('autosave', false)
    dfhack.run_script_with_env(nil, 'autosave', {}, 'set', tostring(orig_interval or 30))
    if not ok then error(err) end
end

function test.now_saves_game()
    -- wait a few seconds so that the unsaved time is distinguishably positive
    delay_until(function()
        return dfhack.persistent.getUnsavedSeconds() >= 3
    end, 1000)
    dfhack.run_script('autosave', 'now')
    delay_until(wait_for_save(), SAVE_TIMEOUT_FRAMES)
end

function test.save_fires_when_enabled()
    -- wait a few seconds so that the unsaved time is distinguishably positive
    -- and its reset on save is observable
    delay_until(function()
        return dfhack.persistent.getUnsavedSeconds() >= 3
    end, 1000)
    dfhack.run_script_with_env(nil, 'autosave', {}, 'set', '0.001')
    dfhack.enable_script('autosave', true)
    delay_until(wait_for_save(), SAVE_TIMEOUT_FRAMES)
end

function test.no_save_when_disabled()
    local before = dfhack.persistent.getUnsavedSeconds()
    -- poll interval is 100 frames; wait well past it
    delay(500)
    expect.true_(dfhack.persistent.getUnsavedSeconds() >= before)
end

-- autopath_up_down_with_option1.lua
-- Usage: autopath_up_down_with_option1
-- Presents an "Up/Down/Cancel" menu, then auto-paths one level at a time by simulating OPTION1 for each step,
-- shows a popup at start and a separate popup on success or failure using showPopupAnnouncement.

local script      = require('gui.script')
local gui         = require('gui')
local dfgui       = dfhack.gui
local world       = df.global.world
local map         = world.map
local you         = world.units.adv_unit
local delayFrames = 10  -- frames to wait for each simulated step

script.start(function()
    if not you then
        qerror("Error: No adventurer unit found.")
    end

    local view = dfhack.gui.getCurViewscreen()
    if not view then
        qerror("Error: No current viewscreen to send input to.")
    end

    local x, y, current_z = you.pos.x, you.pos.y, you.pos.z

    -- Show Up/Down/Cancel menu
    local choices = { "Up", "Down", "Cancel" }
    local ok, idx = script.showListPrompt(
        "AutoPath",
        string.format("Current z = %d. Which direction? (Cancel to exit)", current_z),
        COLOR_WHITE,
        choices,
        nil,
        true
    )
    if not ok or idx == 3 then
        return  -- cancelled by user
    end

    local goUp = (idx == 1)
    local direction = goUp and "up" or "down"

    -- Determine scan range: Up scans from top down; Down scans from bottom up
    local start_z, step, bound
    if goUp then
        start_z = map.z_count - 1
        step    = -1
        bound   = current_z
    else
        start_z = 0
        step    = 1
        bound   = current_z
    end

    -- Popup to notify user not to press keys while running
    dfgui.showPopupAnnouncement(
        "Auto-path in progress... Please do not press any keys.",
        COLOR_YELLOW
    )

    -- Recursive scan function
    local function tryZ(z)
        -- Bounds check: if passed bound without finding, fail
        if (goUp and z < bound) or (not goUp and z > bound) then
            dfgui.showPopupAnnouncement(
                string.format("No available auto-path %s from your position.", direction),
                COLOR_RED
            )
            return
        end

        -- Request path to (x, y, z)
        you.path.dest.x = x
        you.path.dest.y = y
        you.path.dest.z = z
        you.path.goal   = 215

        -- Simulate the OPTION1 input (one-step move)
        gui.simulateInput(view, 'OPTION1')

        -- Wait for the step to be processed
        dfhack.timeout(delayFrames, 'frames', function()
            local pd    = you.path.path and you.path.path.x
            local valid = pd and (#pd > 0)
            if valid then
                -- Commit to this step
                you.path.dest.z = z
                you.path.goal   = 215
                local levels = math.abs(z - current_z)
                dfgui.showPopupAnnouncement(
                    string.format("Auto-path %s %d levels.", direction, levels),
                    COLOR_GREEN
                )
            else
                tryZ(z + step)
            end
        end)
    end

    -- Start scanning
    tryZ(start_z)
end)

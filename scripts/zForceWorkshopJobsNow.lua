--@ module=true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local gui = require('gui')

local ForceJobs = {}

function ForceJobs.prioritize_all_jobs()
    local count, changed = 0, 0
    for _, bld in ipairs(df.global.world.buildings.other.IN_PLAY) do
        local t = bld:getType()
        if t == df.building_type.Workshop or t == df.building_type.Furnace then
            count = count + 1
            for _, job in ipairs(bld.jobs or {}) do
                if job and not job.flags.do_now then
                    job.flags.do_now = true
                    changed = changed + 1
                end
            end
        end
    end
    dfhack.println(('ForceJobsNow: Buildings scanned: %d | Jobs changed: %d'):format(count, changed))
end

function ForceJobs.disable_all_jobs()
    local count, changed = 0, 0
    for _, bld in ipairs(df.global.world.buildings.other.IN_PLAY) do
        local t = bld:getType()
        if t == df.building_type.Workshop or t == df.building_type.Furnace then
            count = count + 1
            for _, job in ipairs(bld.jobs or {}) do
                if job and job.flags.do_now then
                    job.flags.do_now = false
                    changed = changed + 1
                end
            end
        end
    end
    dfhack.println(('ForceJobsNow: Buildings scanned: %d | Jobs disabled: %d'):format(count, changed))
end

local ForceJobsOverlay = defclass(ForceJobsOverlay, overlay.OverlayWidget)
ForceJobsOverlay.ATTRS {
    desc = 'Force-start jobs in workshops/furnaces.',
    viewscreens = {

        'dwarfmode/ViewSheets/BUILDING/Workshop/Masons/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Masons/Items',
        'dwarfmode/ViewSheets/BUILDING/Furnace/Smelter/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Furnace/Smelter/Items',
        'dwarfmode/ViewSheets/BUILDING/Furnace/WoodFurnace/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Furnace/WoodFurnace/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Bowyers/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Bowyers/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Craftsdwarfs/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Craftsdwarfs/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Mechanics/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Mechanics/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Jewelers/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Jewelers/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Ashery/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Ashery/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Custom/SOAP_MAKER/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Custom/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Siege/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Siege/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Loom/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Loom/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Clothiers/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Clothiers/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Dyers/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Dyers/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Leatherworks/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Leatherworks/Items',
        'dwarfmode/ViewSheets/BUILDING/Furnace/Kiln/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Furnace/Kiln/Items',
        'dwarfmode/ViewSheets/BUILDING/Furnace/GlassFurnace/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Furnace/GlassFurnace/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Carpenters/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Carpenters/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/MetalsmithsForge/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/MetalsmithsForge/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Still/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Still/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Farmers/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Farmers/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Butchers/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Butchers/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Kitchen/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Kitchen/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Fishery/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Fishery/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Tanners/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Tanners/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Custom/SCREW_PRESS/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Custom/Items',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Quern/Tasks',
        'dwarfmode/ViewSheets/BUILDING/Workshop/Quern/Items',
    },
    default_enabled = true,
    default_pos = {x = -41, y = 9},
    frame = {w = 18, h = 3, transparent = true},
}

function ForceJobsOverlay:init()
    self.toggle_state = true  -- default to ON

    self:addviews{
        widgets.Panel{
            frame = {b = 0, r = 0, w = 40, h = 5},
            frame_background = gui.CLEAR_PEN,
            subviews = {
                widgets.Label{
                    frame = {l = 1, t = 0},
                    text = 'Prioritize All:',
                },
                widgets.HotkeyLabel{
                    frame = {l = 1, t = 2},
                    label = 'ON',
                    key = 'CUSTOM_O',
                    auto_width = true,
                    on_activate = function()
                        self.toggle_state = true
                        ForceJobs.prioritize_all_jobs()
                    end,
                },
                widgets.HotkeyLabel{
                    frame = {l = 9, t = 2},
                    label = 'OFF',
                    key = 'CUSTOM_F',
                    auto_width = true,
                    on_activate = function()
                        self.toggle_state = false
                        ForceJobs.disable_all_jobs()
                    end,
                },
            },
        },
    }
end

OVERLAY_WIDGETS = {
    force_jobs_overlay = ForceJobsOverlay,
}

-- Run manually from DFHack console
if not dfhack_flags.module then
    local cmd = ...
    if cmd == nil or cmd:upper() == 'ON' then
        ForceJobs.prioritize_all_jobs()
    elseif cmd:upper() == 'OFF' then
        ForceJobs.disable_all_jobs()
    else
        qerror("Usage: zForceWorkshopJobsNow [ON|OFF]")
    end
end

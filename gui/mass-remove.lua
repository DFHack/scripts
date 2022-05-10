-- building/construction mass removal/suspension tool

--[====[

gui/mass-remove
===============
Allows removal of buildings/constructions and suspend/unsuspend using
a box selection.

The following marking modes are available.

- Suspend: suspends the construction of a planned building/construction
- Unsuspend: resumes the construction of a planned building/construction
- Remove Construction: designates a construction (wall, floor, etc) for removal. Similar to the native Designate->Remove Construction menu in DF
- Unremove Construction: cancels removal of a construction (wall, floor, etc)
- Remove Building: designates a building (door, workshop, etc) for removal. Similar to the native Set Building Tasks/Prefs->Remove Building menu in DF
- Unremove Building: cancels removal of a building (door, workshop, etc)
- Remove All: designates both constructions and buildings for removal, and deletes planned buildings/constructions
- Unremove All: cancels removal designations for both constructions and buildings
]====]

local gui = require "gui"
local guidm = require "gui.dwarfmode"
local persistTable = require 'persist-table'
local utils = require 'utils'
local buildingplan = require('plugins.buildingplan')

MassRemoveUI = defclass(MassRemoveUI, guidm.MenuOverlay)

-- used to iterate through actions with + and -
local actions = {
    "suspend",
    "unsuspend",
    "remove_construction",
    "unremove_construction",
    "remove_building",
    "unremove_building",
    "remove_all",
    "unremove_all",
}
local action_indexes = utils.invert(actions)

MassRemoveUI.ATTRS {
    action="remove_all",
    marking=false,
    mark=nil,
    sidebar_mode=df.ui_sidebar_mode.LookAround,
}

-- Helper functions.

-- Helper to match a job of a particular type at tile (x,y,z) and run the callback function on the job.
local function iterateJobs(jobType, x, y, z, callback)
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == jobType and job.pos.x == x and job.pos.y == y and job.pos.z == z then
            callback(job)
        end
    end
end

-- Sorts and returns the given arguments.
local function minToMax(...)
    local args={...}
    table.sort(args,function(a,b) return a < b end)
    return table.unpack(args)
end

local function paintMapTile(dc, vp, cursor, pos, ...)
    if not same_xyz(cursor, pos) then
        local stile = vp:tileToScreen(pos)
        if stile.z == 0 then
            dc:map(true):seek(stile.x,stile.y):char(...):map(false)
        end
    end
end

local function ableToSuspend(job)
    local buildingHolder = dfhack.job.getGeneralRef(job, df.general_ref_type.BUILDING_HOLDER)
    local ret = not buildingHolder or not buildingplan.isPlannedBuilding(buildingHolder:getBuilding())
    return ret
end

function MassRemoveUI:onDestroy()
    persistTable.GlobalTable.massRemoveAction=self.action
end

function MassRemoveUI:changeSuspendState(x, y, z, new_state)
    iterateJobs(
        df.job_type.ConstructBuilding,
        x,
        y,
        z,
        function(job)
            if ableToSuspend(job) then
                job.flags.suspend = new_state
            end
        end
    )
end

function MassRemoveUI:suspend(x, y, z)
    self:changeSuspendState(x, y, z, true)
end

function MassRemoveUI:unsuspend(x, y, z)
    self:changeSuspendState(x, y, z, false)
end

function MassRemoveUI:removeConstruction(x, y, z)
    dfhack.constructions.designateRemove(x, y, z)
end

-- Construction removals can either be marked as dig on the tile itself, or picked up as jobs. This function checks both.
function MassRemoveUI:unremoveConstruction(x, y, z)
    local tileFlags, occupancy = dfhack.maps.getTileFlags(x,y,z)
    tileFlags.dig = df.tile_dig_designation.No
    dfhack.maps.getTileBlock(x,y,z).flags.designated = true
end

function MassRemoveUI:removeBuilding(x, y, z)
    local building = dfhack.buildings.findAtTile(x, y, z)
    if building then
        dfhack.buildings.deconstruct(building)
    end
end

function MassRemoveUI:unremoveBuilding(x, y, z)
    local building = dfhack.buildings.findAtTile(x, y, z)
    if building then
        for _, job in ipairs(building.jobs) do
            if job.job_type == df.job_type.DestroyBuilding then
                dfhack.job.removeJob(job)
                break
            end
        end
    end
end

function MassRemoveUI:changeDesignation(x, y, z)
    if self.action == "suspend" then
        self:suspend(x, y, z)
    elseif self.action == "unsuspend" then
        self:unsuspend(x, y, z)
    elseif self.action == "remove_building" then
        self:removeBuilding(x, y, z)
    elseif self.action == "unremove_building" then
        self:unremoveBuilding(x, y, z)
    elseif self.action == "remove_construction" then
        self:removeConstruction(x, y, z)
    elseif self.action == "unremove_construction" then
        self:unremoveConstruction(x, y, z)
    elseif self.action == "remove_all" then
        self:removeBuilding(x, y, z)
        self:removeConstruction(x, y, z)
    elseif self.action == "unremove_all" then
        self:unremoveBuilding(x, y, z)
        self:unremoveConstruction(x, y, z)
    end
end

function MassRemoveUI:changeDesignations(x1, y1, z1, x2, y2, z2)
    local x_start, x_end = minToMax(x1, x2)
    local y_start, y_end = minToMax(y1, y2)
    local z_start, z_end = minToMax(z1, z2)
    for x=x_start, x_end do
        for y=y_start, y_end do
            for z=z_start, z_end do
                self:changeDesignation(x, y, z)
            end
        end
    end
end

function MassRemoveUI:getColor(action)
    if action == self.action then
        return COLOR_WHITE
    else
        return COLOR_GREY
    end
end

-- show buildings/constructions marked for removal and planned
-- buildings/constructions that are suspended
function get_building_overlay()
    local grid, z = {}, guidm.getCursorPos().z

    local joblist = df.global.world.jobs.list.next
    while joblist do
        local job = joblist.item
        joblist = joblist.next
        if job.pos.z ~= z then
            goto continue
        end

        if job.job_type == df.job_type.ConstructBuilding
                and job.flags.suspend and ableToSuspend(job) then
            ensure_key(grid, job.pos.y)[job.pos.x] = 's'
        elseif job.job_type == df.job_type.RemoveConstruction then
            ensure_key(grid, job.pos.y)[job.pos.x] = 'n'
        end
        ::continue::
    end

    return function(pos, is_cursor)
        if is_cursor then return end
        local building = dfhack.buildings.findAtTile(pos.x, pos.y, pos.z)
        if building and dfhack.buildings.markedForRemoval(building) then
            return 'x', COLOR_LIGHTRED
        end
        return safe_index(grid, pos.y, pos.x), COLOR_LIGHTRED
    end
end

-- shows the selection range
function get_selection_overlay(pos, is_cursor)
    if is_cursor then return end
    return 'X', COLOR_GREEN
end

function MassRemoveUI:onRenderBody(dc)
    local blink_state = gui.blink_visible(500)

    if blink_state then
        self:renderMapOverlay(get_building_overlay())
    end

    if not blink_state and self.marking then
        local cursor = guidm.getCursorPos()
        self:renderMapOverlay(get_selection_overlay, {
                                  x1 = math.min(self.mark.x, cursor.x),
                                  x2 = math.max(self.mark.x, cursor.x),
                                  y1 = math.min(self.mark.y, cursor.y),
                                  y2 = math.max(self.mark.y, cursor.y)})
    end

    dc:clear():seek(1,1):pen(COLOR_WHITE):string("Mass Remove")
    dc:seek(1,3)

    dc:pen(COLOR_GREY)
    dc:string("Designate multiple buildings"):newline(1)
      :string("and constructions (built or"):newline(1)
      :string("planned) for mass removal."):newline(1)

    dc:seek(1,7)
    dc:pen(COLOR_WHITE)
    if self.marking then
        dc:string("Select the second corner.")
    else
        dc:string("Select the first corner.")
    end

    dc:seek(1,9)
    dc:pen(self:getColor("suspend")):key_string("CUSTOM_S", "Suspend"):newline(1)
    dc:pen(self:getColor("unsuspend")):key_string("CUSTOM_SHIFT_S", "Unsuspend"):newline():newline(1)
    dc:pen(self:getColor("remove_construction")):key_string("CUSTOM_N", "Remove Construction"):newline(1)
    dc:pen(self:getColor("unremove_construction")):key_string("CUSTOM_SHIFT_N", "Unremove Construction"):newline():newline(1)
    dc:pen(self:getColor("remove_building")):key_string("CUSTOM_X", "Remove Building"):newline(1)
    dc:pen(self:getColor("unremove_building")):key_string("CUSTOM_SHIFT_X", "Unremove Building"):newline():newline(1)
    dc:pen(self:getColor("remove_all")):key_string("CUSTOM_A", "Remove All"):newline(1)
    dc:pen(self:getColor("unremove_all")):key_string("CUSTOM_SHIFT_A", "Unremove All"):newline(1)

    dc:pen(COLOR_WHITE)
    if self.marking then
        dc:newline(1):key_string("LEAVESCREEN", "Cancel selection")
    else
        dc:newline(1):key_string("LEAVESCREEN", "Back")
    end
end

function MassRemoveUI:onInput(keys)
    if keys.CUSTOM_S then
        self.action = "suspend"
        return
    elseif keys.CUSTOM_SHIFT_S then
        self.action = "unsuspend"
        return
    elseif keys.CUSTOM_N then
        self.action = "remove_construction"
        return
    elseif keys.CUSTOM_SHIFT_N then
        self.action = "unremove_construction"
        return
    elseif keys.CUSTOM_X then
        self.action = "remove_building"
        return
    elseif keys.CUSTOM_SHIFT_X then
        self.action = "unremove_building"
        return
    elseif keys.CUSTOM_A then
        self.action = "remove_all"
        return
    elseif keys.CUSTOM_SHIFT_A then
        self.action = "unremove_all"
        return
    elseif keys.SECONDSCROLL_UP then
        self.action = actions[((action_indexes[self.action]-2) % #actions)+1]
        return
    elseif keys.SECONDSCROLL_DOWN then
        self.action = actions[(action_indexes[self.action] % #actions)+1]
        return
    end

    if keys.SELECT then
        if self.marking then
            self.marking = false
            self:changeDesignations(self.mark.x, self.mark.y, self.mark.z, df.global.cursor.x, df.global.cursor.y, df.global.cursor.z)
        else
            self.marking = true
            self.mark = copyall(df.global.cursor)
        end
    elseif keys.LEAVESCREEN and self.marking then
        self.marking = false
        return
    end

    if keys.LEAVESCREEN then
        self:dismiss()
    elseif self:propagateMoveKeys(keys) then
        return
    end
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

MassRemoveUI{action=persistTable.GlobalTable.massRemoveAction, marking=false}:show()

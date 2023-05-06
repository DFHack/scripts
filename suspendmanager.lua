-- Avoid suspended jobs and creating unreachable jobs
--@module = true
--@enable = true

local json = require('json')
local persist = require('persist-table')
local argparse = require('argparse')
local eventful = require('plugins.eventful')
local utils = require('utils')
local repeatUtil = require('repeat-util')
local ok, buildingplan = pcall(require, 'plugins.buildingplan')
if not ok then
    buildingplan = nil
end

local GLOBAL_KEY = 'suspendmanager' -- used for state change hooks and persistence

enabled = enabled or false
preventblocking = preventblocking == nil and true or preventblocking

eventful.enableEvent(eventful.eventType.JOB_INITIATED, 10)
eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 10)

SuspendManager = defclass(SuspendManager)
SuspendManager.ATTRS {
    --- List of jobs that are blocking others
    blockingJobs = {},
    --- List of already computed jobs
    visited = {},
    --- Time of the last update, used to avoid recomputing the same
    --- thing when the many job events are fired on the same tick
    lastTick = -1,
}

function SuspendManager.new()
    return SuspendManager {}
end

-- SuspendManager instance kept between frames
Instance = SuspendManager.new()

function isEnabled()
    return enabled
end

function preventBlockingEnabled()
    return preventblocking
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({
        enabled=enabled,
        prevent_blocking=preventblocking,
    })
end

---@param setting string
---@param value string|boolean
function update_setting(setting, value)
    if setting == "preventblocking" then
        if (value == "true" or value == true) then
            preventblocking = true
        elseif (value == "false" or value == false) then
            preventblocking = false
        else
            qerror(tostring(value) .. " is not a valid value for preventblocking, it must be true or false")
        end
    else
        qerror(setting .. " is not a valid setting.")
    end
    persist_state()
end


--- Suspend a job
---@param job job
function suspend(job)
    job.flags.suspend = true
    job.flags.working = false
    dfhack.job.removeWorker(job, 0)
end

--- Unsuspend a job
---@param job job
function unsuspend(job)
    job.flags.suspend = false
end

--- Loop over all the construction jobs
---@param fn function A function taking a job as argument
function foreach_construction_job(fn)
    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.ConstructBuilding then
            fn(job)
        end
    end
end

local CONSTRUCTION_IMPASSABLE = {
    [df.construction_type.Wall]=true,
    [df.construction_type.Fortification]=true,
}

local BUILDING_IMPASSABLE = {
    [df.building_type.Floodgate]=true,
    [df.building_type.Statue]=true,
    [df.building_type.WindowGlass]=true,
    [df.building_type.WindowGem]=true,
    [df.building_type.GrateWall]=true,
    [df.building_type.BarsVertical]=true,
}

--- Check if a building is blocking once constructed
---@param building building_constructionst|building
---@return boolean
local function isImpassable(building)
    local type = building:getType()
    if type == df.building_type.Construction then
        return CONSTRUCTION_IMPASSABLE[building.type]
    else
        return BUILDING_IMPASSABLE[type]
    end
end

--- Return the job at a given position if it will be impassable
---@param pos coord
---@return job?
local function getPlansToConstructImpassableAt(pos)
    --- @type building_constructionst|building
    local building = dfhack.buildings.findAtTile(pos)
    if not building then return nil end
    if building.flags.exists then
        -- The building is already created
        return nil
    end
    if not isImpassable(building) then
        return nil
    end

    return building.jobs[0]
end

--- Check if the tile can be walked on
---@param pos coord
local function walkable(pos)
    local tt = dfhack.maps.getTileType(pos)
    if not tt then
        return false
    end
    local attrs = df.tiletype.attrs[tt]
    local shape_attrs = df.tiletype_shape.attrs[attrs.shape]
    return shape_attrs.walkable
end

--- List neighbour coordinates of a position
---@param pos coord
---@return table<number, coord>
local function neighbours(pos)
    return {
        {x=pos.x-1, y=pos.y, z=pos.z},
        {x=pos.x+1, y=pos.y, z=pos.z},
        {x=pos.x, y=pos.y-1, z=pos.z},
        {x=pos.x, y=pos.y+1, z=pos.z},
    }
end

--- Reset the list of visited and blocking jobs if its outdated
function SuspendManager:resetIfNewTick()
    local tick = dfhack.getTickCount()
    if self.lastTick ~= tick then
        self.visited = {}
        self.blockingJobs = {}
        self.lastTick = tick
    end
end

--- Read the neighbourhood status of a position
--- Return the list of neighbours, number of passables neighbours and number of impassables neighbours
--- @param pos coord Position to analyze
--- @param exclude table<integer, boolean> Set of jobs to to consider as blocked
local function readNeighbourhood(pos, exclude)
    local impassables = 0
    local passables = 0
    local connectedJobs = {}
    for _,neighbourPos in pairs(neighbours(pos)) do
        local neighbourJob = getPlansToConstructImpassableAt(neighbourPos)
        if not walkable(neighbourPos) then
            impassables = impassables + 1
        elseif neighbourJob ~= nil then
            if exclude[neighbourJob.id] then
                impassables = impassables + 1
            else
                table.insert(connectedJobs, table.pack(neighbourJob.id, neighbourPos))
            end
        else
            passables = passables + 1
        end
    end
    return passables, impassables, connectedJobs
end

--- Explore a job and all the connected jobs to it
--- All the jobs considered as potentially blocking are stored in self.blockingJobs
--- All the visited jobs are stored in self.visited, which can be used to prevent analyzing
--- twice the same cluster
---@param job job A job from the cluster to analyze
function SuspendManager:computeClusterBlockingJobs(job)
    -- Not a construction job, no risk
    if job.job_type ~= df.job_type.ConstructBuilding then return end
    local building = dfhack.job.getHolder(job)

    --- Not building a blocking construction, no risk
    if not building or not isImpassable(building) then return end

    --- job.pos is sometimes off by one, get the building pos
    local jobPos = {x=building.centerx,y=building.centery,z=building.z}

    -- list of jobs leading to a walkable area, assumed to be an exit
    local clusterExits = {}

    -- list of jobs part of a dead end corridor
    -- When exploring other dead end corridors, these are excluded
    local leadsToDeadend = {}

    -- remainder (job,position) to visit for this cluster of jobs
    -- It is populated as the cluster is visited
    local toVisit = {table.pack(job.id, jobPos)}

    local clusterSize = 0

    repeat
        clusterSize = clusterSize + 1
        local jobId, pos = table.unpack(table.remove(toVisit))
        if not self.visited[jobId] then
            self.visited[jobId] = true

            local passables, impassables, connectedJobs = readNeighbourhood(pos, {})
            for _, connectedJob in ipairs(connectedJobs) do
                -- store the connected jobs for a future loop
                table.insert(toVisit, connectedJob)
            end

            -- One walkable neighbour without any plan,
            -- Register as an exit of the cluster
            if passables > 0 then
                table.insert(clusterExits, table.pack(jobId, pos))
            end

            -- If there is a single connected job and 3 impassable neighbours, we are at a dead-end
            -- protect it by marking as blocking the corridor leading to it
            while #connectedJobs == 1 and impassables == 3 do
                local next, nextPos = table.unpack(connectedJobs[1])
                -- Mark the next block in the corridor to be suspended
                self.blockingJobs[next] = true
                -- Mark the currently analyzed job as a dead-end, not to be explored
                -- when looking for escapes in corridors
                leadsToDeadend[jobId] = true
                -- Explore the next job in the corridor
                _, impassables, connectedJobs = readNeighbourhood(nextPos, leadsToDeadend)
                jobId = next
                pos = nextPos
            end
        end
    until #toVisit == 0

    -- Once the cluster has been fully visited, if there is a single exit to this cluster
    -- protect it too from being closed
    if #clusterExits == 1 and clusterSize > 1 then
        local jobId, pos = table.unpack(clusterExits[1])
        self.blockingJobs[jobId] = true
        local _, _, connectedJobs = readNeighbourhood(pos, leadsToDeadend)
        while #connectedJobs == 1 do
            -- There is a single escape, mark it and continue the exploration
            local next, nextPos = table.unpack(connectedJobs[1])
            -- Mark the escape to be suspended
            self.blockingJobs[next] = true
            -- Mark the currently analyzed job as a dead-end, not to be explored
            -- when looking for escapes
            leadsToDeadend[jobId] = true
            -- Explore the escape
            _, _, connectedJobs = readNeighbourhood(nextPos, leadsToDeadend)
            jobId = next
            pos = nextPos
        end
    end
end

--- Compute all the blocking jobs
function SuspendManager:computeBlockingJobs()
    foreach_construction_job(function (job)
        if not self.visited[job.id] then
            self:computeClusterBlockingJobs(job)
        end
    end)
end

--- Return true with a reason if a job should be suspended.
--- It optionally takes in account the risk of creating stuck
--- construction buildings
--- @param job job
function SuspendManager:shouldBeSuspended(job)
    if self.visited[job.id] and self.blockingJobs[job.id] then
        return true, 'blocking'
    end
    return false, nil
end

--- Return true with a reason if a job should not be unsuspended.
function SuspendManager:shouldStaySuspended(job)
    -- External reasons to be suspended

    if dfhack.maps.getTileFlags(job.pos).flow_size > 1 then
        return true, 'underwater'
    end

    local bld = dfhack.job.getHolder(job)
    if bld and buildingplan and buildingplan.isPlannedBuilding(bld) then
        return true, 'buildingplan'
    end

    -- Internal reasons to be suspended, determined by suspendmanager
    return self:shouldBeSuspended(job)
end

local function run_now()
    Instance:resetIfNewTick()
    if preventblocking then
        Instance:computeBlockingJobs()
    else
        Instance.blockingJobs = {}
    end
    foreach_construction_job(function(job)
        if job.flags.suspend then
            if not Instance:shouldStaySuspended(job) then
                unsuspend(job)
            end
        else
            if Instance:shouldBeSuspended(job) then
                suspend(job)
            end
        end
    end)
end

--- @param job job
local function on_job_change(job)
    if preventblocking then
        -- Note: This method could be made incremental by taking in account the
        -- changed job
        run_now()
    end
end

local function update_triggers()
    if enabled then
        eventful.onJobInitiated[GLOBAL_KEY] = on_job_change
        eventful.onJobCompleted[GLOBAL_KEY] = on_job_change
        repeatUtil.scheduleEvery(GLOBAL_KEY, 1, "days", run_now)
    else
        eventful.onJobInitiated[GLOBAL_KEY] = nil
        eventful.onJobCompleted[GLOBAL_KEY] = nil
        repeatUtil.cancel(GLOBAL_KEY)
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
    enabled = (persisted_data or {enabled=false})['enabled']
    preventblocking = (persisted_data or {prevent_blocking=true})['prevent_blocking']
    update_triggers()
end

local function main(args)
    if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
        dfhack.printerr('suspendmanager needs a loaded fortress map to work')
        return
    end

    if dfhack_flags and dfhack_flags.enable then
        args = {dfhack_flags.enable_state and 'enable' or 'disable'}
    end

    local help = false
    local positionals = argparse.processArgsGetopt(args, {
        {"h", "help", handler=function() help = true end},
    })
    local command = positionals[1]

    if help or command == "help" then
        print(dfhack.script_help())
        return
    elseif command == "enable" then
        enabled = true
    elseif command == "disable" then
        enabled = false
    elseif command == "set" then
        update_setting(positionals[2], positionals[3])
    elseif command == "deadend" then
        local manager = SuspendManager.new()
        local job = dfhack.gui.getSelectedJob(true)
        if job ~= nil then
            manager:analyzeCorridor(job)
            foreach_construction_job(function(job)
                if manager.blockingJobs[job.id] then
                    suspend(job)
                else
                    unsuspend(job)
                end
            end)
        end
        return
    elseif command == nil then
        print(string.format("suspendmanager is currently %s", (enabled and "enabled" or "disabled")))
        if preventblocking then
            print("It is configured to prevent construction jobs from blocking each others")
        else
            print("It is configured to unsuspend all jobs")
        end
    else
        qerror("Unknown command " .. command)
        return
    end

    persist_state()
    update_triggers()
end

if not dfhack_flags.module then
    main({...})
end

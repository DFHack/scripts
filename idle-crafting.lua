--@module = true
--@enable = true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local repeatutil = require("repeat-util")

---create a new linked job
---@return df.job
function make_job()
    local job = df.job:new()
    dfhack.job.linkIntoWorld(job, true)
    return job
end

---3D city metric
---@param p1 df.coord
---@param p2 df.coord
---@return number
function distance(p1, p2)
    return math.abs(p1.x - p2.x) + math.abs(p1.y - p2.y) + math.abs(p1.z - p2.z)
end

local function passesScreen(item)
    return not item.flags.in_job and not item.flags.forbid
end

---find closest item in an item vector
---@generic T : df.item
---@param pos df.coord
---@param item_vector T[]
---@param is_good? fun(item: T): boolean
---@return T?
local function findClosest(pos, item_vector, is_good)
    local closest = nil
    local dclosest = -1
    for _, item in ipairs(item_vector) do
        if passesScreen(item) and (not is_good or is_good(item)) then
            local x, y, z = dfhack.items.getPosition(item)
            local ditem = distance(pos, xyz2pos(x, y, z))
            if not closest or ditem < dclosest then
                closest = item
                dclosest = ditem
            end
        end
    end
    return closest
end

---find item inside workshop or linked stockpile
---@generic T : df.item
---@param workshop df.building_workshopst
---@param is_good fun(item: T): boolean
---@return T?
function findLinked(workshop, is_good)
    local res = nil
    -- look inside the workshop first
    for _, contained_item in ipairs(workshop.contained_items) do
        if contained_item.use_mode == 0 and passesScreen(contained_item.item) and is_good(contained_item.item) then
            res = contained_item.item
            -- print('attaching item from inside the workshop')
            goto done
        end
    end
    -- then look through the linked stockpiles
    for _, stockpile in ipairs(workshop.profile.links.take_from_pile) do
        for _, item in ipairs(dfhack.buildings.getStockpileContents(stockpile)) do
            if passesScreen(item) and is_good(item) then
                res = item
                -- print('attaching item from linked stockpile')
                goto done
            end
        end
    end
    ::done::
    return res
end

---make bone crafts at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
local function makeBoneCraft(unit, workshop)
    local workshop_position = xyz2pos(workshop.centerx, workshop.centery, workshop.z)
    local function is_bone(item)
        if df.item_corpsepiecest:is_instance(item) then
            return item.corpse_flags.bone and not item.flags.dead_dwarf
        else
            return false
        end
    end
    local bone = nil
    if #workshop.profile.links.take_from_pile > 0 then
        bone = findLinked(workshop, is_bone)
    else
        bone = findClosest(workshop_position, df.global.world.items.other.ANY_REFUSE, is_bone)
    end

    if not bone then
        return false
    end
    local job = make_job()
    job.job_type = df.job_type.MakeCrafts
    job.mat_type = -1
    job.material_category.bone = true
    job.pos = workshop_position

    local jitem = df.job_item:new()
    jitem.item_type = df.item_type.NONE
    jitem.mat_type = -1
    jitem.mat_index = -1
    jitem.quantity = 1
    jitem.vector_id = df.job_item_vector_id.ANY_REFUSE
    jitem.flags1.unrotten = true
    jitem.flags2.bone = true
    jitem.flags2.body_part = true
    job.job_items.elements:insert('#', jitem)

    dfhack.job.addGeneralRef(job, df.general_ref_type.BUILDING_HOLDER, workshop.id)
    if not dfhack.job.attachJobItem(job, bone, df.job_item_ref.T_role.Reagent, 0, -1) then
        dfhack.printerr('could not attach bones')
        return false
    end
    workshop.jobs:insert("#", job)
    job.flags.fetching = true
    job.items[0].flags.is_fetching = true
    return dfhack.job.addWorker(job, unit)
end

---make rock crafts at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean ""
local function makeRockCraft(unit, workshop)
    local workshop_position = xyz2pos(workshop.centerx, workshop.centery, workshop.z)


    local boulder = findClosest(workshop_position, df.global.world.items.other.BOULDER)
    if not boulder then
        return false
    end
    local job = make_job()
    job.job_type = df.job_type.MakeCrafts
    job.mat_type = 0
    job.pos = workshop_position

    local jitem = df.job_item:new()
    jitem.item_type = df.item_type.BOULDER
    jitem.mat_type = 0
    jitem.mat_index = -1
    jitem.quantity = 1
    jitem.vector_id = df.job_item_vector_id.BOULDER
    jitem.flags2.non_economic = true
    jitem.flags3.hard = true
    job.job_items.elements:insert('#', jitem)

    dfhack.job.addGeneralRef(job, df.general_ref_type.BUILDING_HOLDER, workshop.id)
    if not dfhack.job.attachJobItem(job, boulder, df.job_item_ref.T_role.Reagent, 0, -1) then
        dfhack.printerr('could not attach boulder')
        return false
    end
    workshop.jobs:insert("#", job)
    job.flags.fetching = true
    job.items[0].flags.is_fetching = true
    return dfhack.job.addWorker(job, unit)
end

-- script logic

local GLOBAL_KEY = 'idle-crafting'

enabled = enabled or false
function isEnabled()
    return enabled
end

---IDs of workshops where idle crafting is permitted
---@type table<integer,boolean>
allowed = allowed or {}

---IDs of workshops that have encountered failures (e.g. missing materials)
---@type table<integer,boolean>
failing = failing or {}

---IDs of watched units in need of crafting items
---@type table<integer,boolean>[]
watched = watched or {}

---priority thresholds for crafting needs
---@type integer[]
thresholds = thresholds or { 10000, 1000, 500 }

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled = enabled,
        allowed = allowed,
        thresholds = thresholds
    })
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = persisted_data.enabled or false
    allowed = persisted_data.allowed or {}
    thresholds = persisted_data.thresholds or { 10000, 1000, 500 }
end

CraftObject = df.need_type['CraftObject']

---negative crafting focus penalty
---@param unit df.unit
---@return number
local function getCraftingNeed(unit)
    local needs = unit.status.current_soul.personality.needs
    for _, need in ipairs(needs) do
        if need.id == CraftObject then
            return -need.focus_level
        end
    end
    return 0
end

local function stop()
    enabled = false
    repeatutil.cancel(GLOBAL_KEY .. 'main')
    repeatutil.cancel(GLOBAL_KEY .. 'unit')
end

local function checkForWorkshop()
    if not next(allowed) then
        print('no available workshops, disabling')
        stop()
    end
end

---retrieve workshop by id
---@param id integer
---@return df.building_workshopst|nil
local function locateWorkshop(id)
    local workshop = df.building.find(id)
    if df.building_workshopst:is_instance(workshop) and workshop.type == 3 then
        return workshop
    else
        return nil
    end
end

---checks that unit can path to workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
function canAccessWorkshop(unit, workshop)
    local workshop_position = xyz2pos(workshop.centerx, workshop.centery, workshop.z)
    return dfhack.maps.canWalkBetween(unit.pos, workshop_position)
end

---unit is ready to take jobs
---@param unit df.unit
---@return boolean
local function unitIsAvailable(unit)
    if unit.job.current_job then
        return false
    elseif #unit.social_activities > 0 then
        return false
    elseif #unit.individual_drills > 0 then
        return false
    elseif unit.military.squad_id ~= -1 then
        local squad = df.squad.find(unit.military.squad_id)
        -- this lookup should never fail
        ---@diagnostic disable-next-line: need-check-nil
        return #squad.orders == 0 and squad.activity == -1
    end
    return true
end

---check if unit is ready and try to create a crafting job for it
---@param workshop df.building_workshopst
---@param idx integer
---@param unit_id integer
---@return boolean "proceed to next workshop"
function processUnit(workshop, idx, unit_id)
    local unit = df.unit.find(unit_id)
    -- check that unit is still there
    if not unit then
        watched[idx][unit_id] = nil
        return false
    elseif not canAccessWorkshop(unit, workshop) then
        dfhack.print('-')
        return false
    elseif not unitIsAvailable(unit) then
        dfhack.print('.')
        return false
    end
    -- We have an available unit
    local success = false
    if workshop.profile.blocked_labors[df.unit_labor['BONE_CARVE']] == false then
        success = makeBoneCraft(unit, workshop)
    end
    if not success and workshop.profile.blocked_labors[df.unit_labor['STONE_CRAFT']] == false then
        success = makeRockCraft(unit, workshop)
    end
    local name = (dfhack.TranslateName(dfhack.units.getVisibleName(unit)))
    if success then
        -- Why is the encoding still wrong, even when using df2console?
        print(' assigned ' .. dfhack.df2console(name))
        watched[idx][unit_id] = nil
    else
        print(' failed to assign ' .. dfhack.df2console(name))
        print('  disabling failing workshop until the next run of the main loop')
        failing[workshop.id] = true
    end
    return true
end

local function unit_loop()
    for workshop_id, _ in pairs(allowed) do
        -- skip workshops where job creation failed (e.g. due to missing materials)
        if failing[workshop_id] then
            goto next_workshop
        end
        local workshop = locateWorkshop(workshop_id)
        -- workshop may have been destroyed or assigned a master
        if not workshop or #workshop.profile.permitted_workers > 0 then
            allowed[workshop_id] = nil --clearing during iteration is permitted
            goto next_workshop
        end
        -- only consider workshop if not currently in use
        if #workshop.jobs > 0 then
            goto next_workshop
        end
        dfhack.print(('idle-crafting: locating crafter for %s (%d)'):format(dfhack.buildings.getName(workshop),
            workshop_id))
        -- workshop is free to use, try to find a unit
        for idx, _ in ipairs(thresholds) do
            for unit_id, _ in pairs(watched[idx]) do
                if processUnit(workshop, idx, unit_id) then
                    goto next_workshop
                end
            end
            dfhack.print('/')
        end

        print('no unit found')
        ::next_workshop::
    end
    -- disable loop if there are no more units
    if not next(watched) then
        repeatutil.cancel(GLOBAL_KEY .. 'unit')
    end
    -- disable tool if there are no more workshops
    checkForWorkshop()
    persist_state()
end

local function main_loop()
    print('idle crafting: running main loop')
    checkForWorkshop()
    if not enabled then
        return
    end
    -- put failing workshops back into the loop
    failing = {}

    local num_watched = {}
    local watching = false

    ---@type table<integer,boolean>[]
    watched = {}
    for idx, _ in ipairs(thresholds) do
        watched[idx] = {}
        num_watched[idx] = 0
    end

    for _, unit in ipairs(dfhack.units.getCitizens(true, false)) do
        for idx, threshold in ipairs(thresholds) do
            if getCraftingNeed(unit) > threshold then
                watched[idx][unit.id] = true
                num_watched[idx] = num_watched[idx] + 1
                watching = true
                goto continue
            end
        end
        ::continue::
    end
    print(('watching %s dwarfs with crafting needs'):format(
        table.concat(num_watched, '/')
    ))

    if watching then
        repeatutil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY .. 'unit', 53, 'ticks', unit_loop)
    end
end

---enable main loop
---@param enable boolean|nil
local function start(enable)
    enabled = enable or enabled
    if enabled then
        repeatutil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY .. 'main', 8419, 'ticks', main_loop)
    end
end

--- Handles automatic loading
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    load_state()
    start()
end

--
-- Overlay to select workshops
--


IdleCraftingOverlay = defclass(IdleCraftingOverlay, overlay.OverlayWidget)
IdleCraftingOverlay.ATTRS {
    desc = 'Adds a UI to the Workers tab too enable idle crafting.',
    default_pos = { x = -42, y = 41 },
    default_enabled = true,
    viewscreens = {
        'dwarfmode/ViewSheets/BUILDING/Workshop/Craftsdwarfs/Tasks',
    },
    frame = { w = 55, h = 1 },
    visible = function ()
        return #df.global.game.main_interface.building.button == 0
    end
}

function IdleCraftingOverlay:init()
    self:addviews {
        widgets.CycleHotkeyLabel {
            view_id = 'leisure_toggle',
            frame = { l = 0, t = 0 },
            label = 'Allow idle dwarfs to satisfy crafting needs:',
            key = 'CUSTOM_L',
            options = {
                { label = 'yes', value = true, pen = COLOR_GREEN },
                { label = 'no',  value = false },
            },
            initial_option = 'no',
            on_change = self:callback('onClick'),
        }
    }
end

function IdleCraftingOverlay:onClick(new, _)
    local workshop = dfhack.gui.getSelectedBuilding(true)
    allowed[workshop.id] = new or nil
    if new and not enabled then
        start(true)
    end
    if not next(allowed) then
        stop()
    end
    persist_state()
end

function IdleCraftingOverlay:onRenderBody(painter)
    local workshop = dfhack.gui.getSelectedBuilding(true)
    if not workshop then
        return
    end
    self.subviews.leisure_toggle:setOption(allowed[workshop.id] or false)
end

OVERLAY_WIDGETS = {
    idlecrafting = IdleCraftingOverlay
}

--
-- commandline interface
--

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF then
    print('this tool requires a loaded fort')
    return
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        print('This tool is enabled by permitting idle crafting at a Craftsdarf\'s workshop')
        return
    else
        allowed = {}
        stop()
        persist_state()
        return
    end
end

local fulfillment_level =
{ 'unfettered', 'level-headed', 'untroubled', 'not distracted', 'unfocused', 'distracted', 'badly distracted' }
local fulfillment_threshold =
{ 300, 200, 100, -999, -9999, -99999, -500000 }

local argparse = require('argparse')

load_state()
local positionals = argparse.processArgsGetopt({ ... }, {
    {
        't', 'thresholds', hasArg = true,
        handler = function(optarg)
            thresholds = argparse.numberList(optarg, 'thresholds')
        end
    }
})

if positionals[1] == 'status' then
    ---@type integer[]
    stats = {}
    for _, unit in ipairs(dfhack.units.getCitizens(true, false)) do
        local fulfillment = -getCraftingNeed(unit)
        for i = 1, 7 do
            if fulfillment >= fulfillment_threshold[i] then
                stats[i] = stats[i] and stats[i] + 1 or 1
                goto continue
            end
        end
        ::continue::
    end
    print('Fulfillment levels for "craft item" needs')
    for k, v in pairs(stats) do
        print(('%4d %s'):format(v, fulfillment_level[k]))
    end
    local num_workshops = 0
    for _, _ in pairs(allowed) do
        num_workshops = num_workshops + 1
    end
    print(('Script is %s with %d workshops configured for idle crafting'):
        format(enabled and 'enabled' or 'disabled', num_workshops))
    print(('The thresholds for "craft item" needs are %s'):
        format(table.concat(thresholds, '/')))
elseif positionals[1] == 'disable' then
        allowed = {}
        stop()
end
persist_state()

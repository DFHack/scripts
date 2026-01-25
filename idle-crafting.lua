--@module = true
--@enable = true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local repeatutil = require("repeat-util")
local orders = require('plugins.orders')

---iterate over input materials of workshop with stockpile links
---@param workshop df.building_workshopst
---@param action fun(item:df.item):any
local function for_inputs(workshop, action)
    if #workshop.profile.links.take_from_pile == 0 then
        dfhack.error('workshop has no links')
    else
        for _, stockpile in ipairs(workshop.profile.links.take_from_pile) do
            for _, item in ipairs(dfhack.buildings.getStockpileContents(stockpile)) do
                if item:isAssignedToThisStockpile(stockpile.id) then
                    for _, contained_item in ipairs(dfhack.items.getContainedItems(item)) do
                       action(contained_item)
                    end
                else
                    action(item)
                end
            end
        end
        for _, contained_item in ipairs(workshop.contained_items) do
            if contained_item.use_mode == df.building_item_role_type.TEMP then
                action(contained_item.item)
            end
        end
    end
end

---choose random value based on positive integer weights
---@generic T
---@param choices table<T,integer>
---@return T
function weightedChoice(choices)
    local sum = 0
    for _, weight in pairs(choices) do
        sum = sum + weight
    end
    if sum <= 0 then
        return nil
    end
    local random = math.random(sum)
    for choice, weight in pairs(choices) do
        if random > weight then
            random = random - weight
        else
            return choice
        end
    end
    return nil --never reached on well-formed input
end

---make totem at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
function makeTotem(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MakeTotem
    job.mat_type = -1

    local jitem = df.job_item:new()
    jitem.item_type = df.item_type.NONE --the game seems to leave this uninitialized
    jitem.mat_type = -1
    jitem.mat_index = -1
    jitem.quantity = 1
    jitem.vector_id = df.job_item_vector_id.ANY_REFUSE
    jitem.flags1.unrotten = true
    jitem.flags2.totemable = true
    jitem.flags2.body_part = true
    job.job_items.elements:insert('#', jitem)

    dfhack.job.assignToWorkshop(job, workshop)
    return dfhack.job.addWorker(job, unit)
end

---make totem at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
function makeHornCrafts(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MakeCrafts
    job.mat_type = -1
    job.material_category.horn = true

    local jitem = df.job_item:new()
    jitem.item_type = df.item_type.NONE --the game seems to leave this uninitialized
    jitem.mat_type = -1
    jitem.mat_index = -1
    jitem.quantity = 1
    jitem.vector_id = df.job_item_vector_id.ANY_REFUSE
    jitem.flags1.unrotten = true
    jitem.flags2.horn = true
    jitem.flags2.body_part = true
    job.job_items.elements:insert('#', jitem)

    dfhack.job.assignToWorkshop(job, workshop)
    return dfhack.job.addWorker(job, unit)
end

---make bone crafts at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
function makeBoneCraft(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MakeCrafts
    job.mat_type = -1
    job.material_category.bone = true

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

    dfhack.job.assignToWorkshop(job, workshop)
    return dfhack.job.addWorker(job, unit)
end

---make shell crafts at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
function makeShellCraft(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MakeCrafts
    job.mat_type = -1
    job.material_category.shell = true

    local jitem = df.job_item:new()
    jitem.item_type = df.item_type.NONE
    jitem.mat_type = -1
    jitem.mat_index = -1
    jitem.quantity = 1
    jitem.vector_id = df.job_item_vector_id.ANY_REFUSE
    jitem.flags1.unrotten = true
    jitem.flags2.shell = true
    jitem.flags2.body_part = true
    job.job_items.elements:insert('#', jitem)

    dfhack.job.assignToWorkshop(job, workshop)
    return dfhack.job.addWorker(job, unit)
end

---make rock crafts at specified workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean ""
function makeRockCraft(unit, workshop)
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MakeCrafts
    job.mat_type = 0

    local jitem = df.job_item:new()
    jitem.item_type = df.item_type.BOULDER
    jitem.mat_type = 0
    jitem.mat_index = -1
    jitem.quantity = 1
    jitem.vector_id = df.job_item_vector_id.BOULDER
    jitem.flags2.non_economic = true
    jitem.flags3.hard = true
    job.job_items.elements:insert('#', jitem)

    dfhack.job.assignToWorkshop(job, workshop)
    return dfhack.job.addWorker(job, unit)
end

---categorize and count crafting materials (for Craftsdwarf's workshop)
---@param tab table<string,integer>
---@param item df.item
local function categorize_craft(tab,item)
    if df.item_corpsepiecest:is_instance(item) then
        if item.corpse_flags.bone then
            tab['bone'] = (tab['bone'] or 0) + item.material_amount.Bone
        elseif item.corpse_flags.skull then
            tab['skull'] = (tab['skull'] or 0) + 1
        elseif item.corpse_flags.horn then
            tab['horn'] = (tab['horn'] or 0) + item.material_amount.Horn
        elseif item.corpse_flags.shell then
            tab['shell'] = (tab['shell'] or 0) + 1
        end
    elseif df.item_boulderst:is_instance(item) then
        tab['boulder'] = (tab['boulder'] or 0) + 1
    end
end

-- script logic

local GLOBAL_KEY = 'idle-crafting'

enabled = enabled or false
function isEnabled()
    return enabled
end

---IDs of workshops where idle crafting is permitted
---@type table<integer,integer>
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

---@type boolean
ignore_happy = ignore_happy == nil and true or ignore_happy

-- persisting a table with numeric keys results in a json array with a huge number of null entries
-- therefore, we convert the keys to strings for persistence
-- also, we clear the frame counter values since the frame counter gets reset on load
local function to_persist_allowed()
    local persistable_allowed = {}
    for workshop_id in pairs(allowed) do
        persistable_allowed[tostring(workshop_id)] = -1
    end
    return persistable_allowed
end

-- loads both from the older array format and the new string table format
local function from_persist_allowed(persisted_allowed)
    if not persisted_allowed then
        return
    end
    local usable_allowed = {}
    for workshop_id in pairs(persisted_allowed) do
        usable_allowed[tonumber(workshop_id)] = -1
    end
    return usable_allowed
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=enabled,
        allowed=to_persist_allowed(),
        thresholds=thresholds,
        ignore_happy=ignore_happy
    })
end

--- Load the saved state of the script
local function load_state()
    -- load persistent data
    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = persisted_data.enabled or false
    allowed = from_persist_allowed(persisted_data.allowed) or {}
    thresholds = persisted_data.thresholds or { 10000, 1000, 500 }
    ignore_happy = persisted_data.ignore_happy == nil and true or ignore_happy
end

--frequently accessed values
local CraftObject = df.need_type['CraftObject']
local BONE_CARVE = df.unit_labor['BONE_CARVE']
local STONE_CRAFT = df.unit_labor['STONE_CRAFT']

---negative crafting focus penalty
---@generic T
---@param unit df.unit
---@param value_if_absent T
---@return number|T
function getCraftingNeed(unit, value_if_absent)
    local focus_penalty = dfhack.units.getFocusPenalty(unit, CraftObject)
    return focus_penalty > 1000 and value_if_absent or -focus_penalty
end

local function stop()
    enabled = false
    repeatutil.cancel(GLOBAL_KEY .. 'main')
    repeatutil.cancel(GLOBAL_KEY .. 'unit')
end

local function checkForWorkshop()
    if not next(allowed) then
        -- print('no available workshops, disabling')
        stop()
    end
end

---retrieve workshop by id
---@param id integer
---@return df.building_workshopst|nil
local function locateWorkshop(id)
    local workshop = df.building.find(id)
    if df.building_workshopst:is_instance(workshop) and workshop.type == df.workshop_type.Craftsdwarfs then
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

---select crafting job based on available resources
---@param workshop df.building_workshopst
---@return (fun(unit:df.unit, workshop:df.building_workshopst):boolean)?
function select_crafting_job(workshop)
    local tab = {}
    for_inputs(workshop, curry(categorize_craft,tab))
    local blocked_labors = workshop.profile.blocked_labors
    if blocked_labors[STONE_CRAFT] then
        tab['boulder'] = nil
    end
    if blocked_labors[BONE_CARVE] then
        tab['bone'] = nil
        tab['skull'] = nil
        tab['horn'] = nil
        tab['shell'] = nil
    end
    local material = weightedChoice(tab)
    if material == 'bone' then return makeBoneCraft
    elseif material == 'skull' then return makeTotem
    elseif material == 'horn' then return makeHornCrafts
    elseif material == 'shell' then return makeShellCraft
    elseif material == 'boulder' then return makeRockCraft
    else
        return nil
    end
end


---check if unit is ready and try to create a crafting job for it
---@param workshop df.building_workshopst
---@param idx integer "index of the unit's group"
---@param unit_id integer
---@return boolean "proceed to next workshop"
local function processUnit(workshop, idx, unit_id)
    local unit = df.unit.find(unit_id)
    -- check that unit is still there, not caged or chained, and still has crafting needs
    if not unit or unit.flags1.caged or unit.flags1.chained or getCraftingNeed(unit, -1) < 0 then
        watched[idx][unit_id] = nil
        return false
    elseif not canAccessWorkshop(unit, workshop) then
        -- dfhack.print('-')
        return false
    elseif not dfhack.units.isJobAvailable(unit) then
        -- dfhack.print('.')
        return false
    end
    -- We have an available unit
    local success = false
    if #workshop.profile.links.take_from_pile == 0 then
        -- can we do something smarter here?
        if workshop.profile.blocked_labors[STONE_CRAFT] == false then
            success = makeRockCraft(unit, workshop)
        end
        if not success and workshop.profile.blocked_labors[BONE_CARVE] == false then
            success = makeBoneCraft(unit, workshop)
        end
        if not success then
            dfhack.printerr('idle-crafting: profile allows neither bone carving nor stonecrafting')
        end
    else
        local craftItem = select_crafting_job(workshop)
        if craftItem then
            success = craftItem(unit, workshop)
        else
            print('idle-crafting: workshop has no usable materials in linked stockpiles')
            failing[workshop.id] = true
        end
    end
    if success then
        print('idle-crafting: assigned crafting job to ' .. dfhack.df2console(dfhack.units.getReadableName(unit)))
        watched[idx][unit_id] = nil
        allowed[workshop.id] = df.global.world.frame_counter
    end
    return true
end


---@param workshop df.building_workshopst
---@return boolean
local function invalidProfile(workshop)
    local profile = workshop.profile
    return (#profile.permitted_workers > 0) or
        (profile.blocked_labors[BONE_CARVE] and profile.blocked_labors[STONE_CRAFT])
end

-- try to catch units that currently don't have a job and send them to satisfy
-- their crafting needs.
local function unit_loop()
    local current_frame = df.global.world.frame_counter
    for workshop_id, last_job_frame in pairs(allowed) do
        -- skip workshops where jobs appear to have been cancelled (e.g. to missing materials)
        if failing[workshop_id] then
            goto next_workshop
        end

        local workshop = locateWorkshop(workshop_id)
        -- workshop may have been destroyed, assigned a master, or does not allow crafting
        if not workshop or invalidProfile(workshop) then
            -- print('workshop destroyed or has invalid profile')
            allowed[workshop_id] = nil --clearing during iteration is permitted
            goto next_workshop
        end

        -- only consider workshop if not currently in use
        if #workshop.jobs > 0 then
            goto next_workshop
        end

        -- check that we didn't schedule a job on the last iteration
        if (last_job_frame >= 0) and (current_frame < last_job_frame + 60) then
            -- print(('idle-crafting: disabling failing workshop (%d) until the next run of main loop'):
            --     format(workshop_id))
            failing[workshop_id] = true
            goto next_workshop
        end

        -- dfhack.print(('idle-crafting: locating crafter for %s (%d)'):
        --     format(dfhack.buildings.getName(workshop), workshop_id))

        -- workshop is free to use, try to find a unit
        for idx, _ in ipairs(thresholds) do
            for unit_id, _ in pairs(watched[idx]) do
                if processUnit(workshop, idx, unit_id) then
                    goto next_workshop
                end
            end
            -- dfhack.print('/')
        end

        -- print('no unit found')
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
    -- print('idle crafting: running main loop')
    checkForWorkshop()
    if not enabled then
        return
    end
    -- put failing workshops back into the loop
    failing = {}
    for workshop_id, _ in pairs(allowed) do
        allowed[workshop_id] = -1
    end

    local num_watched = {}
    local watching = false

    ---@type table<integer,boolean>[]
    watched = {}
    for idx, _ in ipairs(thresholds) do
        watched[idx] = {}
        num_watched[idx] = 0
    end

    local max_threshold = thresholds[1]
    for _, unit in ipairs(dfhack.units.getCitizens(true, false)) do

        local crafting_need = getCraftingNeed(unit, nil)

        if not crafting_need then
            goto next_unit
        end

        local is_happy = unit.status.current_soul.personality.stress < -25000 and
                         unit.status.current_soul.personality.longterm_stress < 0

        for idx, threshold in ipairs(thresholds) do
            if ignore_happy and is_happy and threshold < max_threshold then
                -- ignore happy and ecstatic units for any threshold but the highest
                -- print(dfhack.df2console(("idle-crafting: skipping happy unit %s"):format(dfhack.units.getReadableName(unit))))
                goto next_unit
            end

            if crafting_need > threshold then
                watched[idx][unit.id] = true
                num_watched[idx] = num_watched[idx] + 1
                watching = true
                goto next_unit
            end
        end
        ::next_unit::
    end
    -- print(('watching %s dwarfs with crafting needs'):format(
    --     table.concat(num_watched, '/')
    -- ))

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
    desc = "Adds a toggle for recreational crafting to Craftdwarf's workshops.",
    default_pos = { x = -39, y = 41 },
    version = 2,
    default_enabled = true,
    viewscreens = {
        'dwarfmode/ViewSheets/BUILDING/Workshop/Craftsdwarfs/Workers',
    },
    frame = { w = 58, h = 1 },
    visible = orders.can_set_labors
}

function IdleCraftingOverlay:init()
    self:addviews {
        widgets.BannerPanel{
            frame={l=0, w=54},
            subviews={
                widgets.CycleHotkeyLabel {
                    view_id = 'leisure_toggle',
                    frame = { t=0, l = 1, r = 1 },
                    label = 'Allow idle dwarves to satisfy crafting needs:',
                    key = 'CUSTOM_I',
                    options = {
                        { label = 'yes', value = true, pen = COLOR_GREEN },
                        { label = 'no',  value = false },
                    },
                    initial_option = 'no',
                    on_change = self:callback('onClick'),
                    enabled = function()
                        local bld = dfhack.gui.getSelectedBuilding(true)
                        if not bld then return end
                        return not invalidProfile(bld)
                    end,
                }
            },
        },
        widgets.HelpButton{
            frame={r=0},
            command='idle-crafting',
        },
    }
end

function IdleCraftingOverlay:onClick(new, _)
    local workshop = dfhack.gui.getSelectedBuilding(true)
    allowed[workshop.id] = new and -1 or nil
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
    qerror('this tool requires a loaded fort')
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        qerror('This tool is enabled by permitting idle crafting at a Craftsdarf\'s workshop')
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
local positionals = argparse.processArgsGetopt({ ... }, {})

if not positionals[1] or positionals[1] == 'status' then
    ---@type integer[]
    stats = {}
    for _, unit in ipairs(dfhack.units.getCitizens(true, false)) do
        local crafting_need = getCraftingNeed(unit, nil)
        if not crafting_need then
            goto continue
        end
        for i = 1, 7 do
            if -crafting_need >= fulfillment_threshold[i] then
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
        format(table.concat(thresholds, ',')))
    if ignore_happy then
        print('Will only assign crafting jobs to happy dwarves with strong needs')
    else
        print('Will treat happy units like all other units')
    end

elseif positionals[1] == 'thresholds' then
    thresholds = argparse.numberList(positionals[2], 'thresholds')
    table.sort(thresholds, function (a, b) return a > b end)
    print(('Thresholds for "craft item" needs set to %s'):
        format(table.concat(thresholds, ',')))
elseif positionals[1] == 'happy' then
    ignore_happy = not argparse.boolean(positionals[2], 'happy')
elseif positionals[1] == 'disable' then
        allowed = {}
        stop()
end
persist_state()

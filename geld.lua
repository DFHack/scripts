local utils = require('utils')

local validArgs = utils.invert({
    'unit',
    'toggle',
    'ungeld',
    'help',
})
local args = utils.processArgs({...}, validArgs)

local unit = nil

if args.help then
    print(dfhack.script_help())
    return
end

if args.unit then
    id=tonumber(args.unit)
    if id then
        unit = df.unit.find(id)
    else
        qerror("Invalid unit ID provided.")
    end
else
    unit = dfhack.gui.getSelectedUnit()
end

if not unit then
    qerror("Invalid unit selection.")
end

if unit.sex == df.pronoun_type.she then
    qerror("Cannot geld female animals.")
end

-- Find the geldable body part id, returns -1 on failure
local function FindBodyPartId(unit)
    for i,part in ipairs(unit.body.body_plan.body_parts) do
        if part.flags.GELDABLE then
            return i
        end
    end
    return -1
end

-- Sets the gelded status of a unit, returns false on failure
local function SetGelded(unit, state)
    -- Gelded status is set in a number of places:
    -- unit.flags3
    -- unit.body.wounds
    -- unit.body.components.body_part_status

    local part_id = FindBodyPartId(unit)
    if part_id == -1 then
        print("Could not find a geldable body part.")
        return false
    end

    unit.flags3.gelded = state

    if state then
        -- Create new wound
        local _,wound,_ = utils.insert_or_update(unit.body.wounds, { new = true, id = unit.body.wound_next_id }, 'id')
        unit.body.wound_next_id = unit.body.wound_next_id + 1
        local _,part,_ = utils.insert_or_update(wound.parts, { new = true, body_part_id = part_id}, 'body_part_id')
        part.flags2.gelded = true
    else
        -- Remove gelding from any existing wounds
        for _,wound in ipairs(unit.body.wounds) do
            for _,part in ipairs(wound.parts) do
                part.flags2.gelded = false
            end
        end
    end

    if state then
        -- Set part status to gelded
        unit.body.components.body_part_status[part_id].gelded = true
    else
        -- Remove gelded status from all parts
        for _,part in ipairs(unit.body.components.body_part_status) do
            part.gelded = false
        end
    end
    return true
end

local function Geld(unit)
    if SetGelded(unit, true) then
        print(string.format("Unit %s gelded.", unit.id))
    else
        print(string.format("Failed to geld unit %s.", unit.id))
    end
end

local function Ungeld(unit)
    if SetGelded(unit, false) then
        print(string.format("Unit %s ungelded.", unit.id))
    else
        print(string.format("Failed to ungeld unit %s.", unit.id))
    end
end

local oldstate = dfhack.units.isGelded(unit)
local newstate

if args.ungeld then
    newstate = false
elseif args.toggle then
    newstate = not oldstate
else
    newstate = true
end

if newstate ~= oldstate then
    if newstate then
        Geld(unit)
    else
        Ungeld(unit)
    end
else
    qerror(string.format("Unit %s is already %s.", unit.id, oldstate and "gelded" or "ungelded"))
end

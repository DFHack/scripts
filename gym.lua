-- Code for dwarves to hit the gym when they yearn for the gains.
--[====[
Gym
===

Tags: Fort| Needs | BugFix | Units

Assigns Dwarves to a military squad until they have fulfilled their need for Martial Training. Also passively builds military skills and physical stats.

CRITICAL SETUP:

- Minimum 1 squad with the name "Gym"
- An assigned squadleader in "Gym"
- An assigned Barracks for the squad "Gym"
- Active Training orders for the squad "Gym"

This should be a new non-military-use squad. The uniform should be set to "No Uniform" and the squad should be set to "Constant Training" in the military screen.
Set the squad's schedule to full time training with at least 8 or 9 training.
The squad doesn't need months off. The members leave the squad once they have gotten their gains.

NOTE: Dwarfs with the labor "Fish Dissection" enabled are ignored. Make a Dwarven labour with only the Fish Dissection enabled, set to "Only selected do this" and assign it to a dwarf to ignore them.

Usage
-----

    gym [<options>]

Examples
--------

gym
    Current status of script

enable gym
    Checks to see if you have fullfilled the creation of a training gym.
    Searches your fort for dwarves with a need to go to the gym, and begins assigning them to said gym.
    Once they have fulfilled their need they will be removed from the gym squad to be replaced by the next dwarf in the list.

disable gym
    Dwarves currently in the Gym squad, with the exception of the squad leader, will be unassigned and no new dwarves will be added to the squad.

Options
-------

    -t
        Use integer values. (Default 3000)
        The negative need threshhold to trigger for each citizen
        The greater the number the longer before a dwarf is added to the waiting list.
]====]
--@ enable = true
--@ module = true

enabled = enabled or false
function isEnabled()
    return enabled
end

local repeatUtil = require 'repeat-util'
local utils=require('utils')

validArgs = utils.invert({
    't'
})

local args = utils.processArgs({...}, validArgs)
local scriptname = "Gym"
local ignore_flag = 43 -- Fish Dissection labor id
local ignore_count = 0
local need_id = 14
local squadname ="Gym"


--######
--Functions
--######
function getAllCititzen()
    local citizen = {}
    local my_civ = df.global.world.world_data.active_site[0].entity_links[0].entity_id
    for n, unit in ipairs(df.global.world.units.all) do
        if unit.civ_id == my_civ and dfhack.units.isCitizen(unit) then
            if unit.profession ~= df.profession.BABY and unit.profession ~= df.profession.CHILD then
                if ( not unit.status.labors[ignore_flag] ) then
                    table.insert(citizen, unit)
                else
                    ignore_count = ignore_count +1
                end
            end
        end
    end
    return citizen
end

local citizen = getAllCititzen()

function findNeed(unit,need_id)
    local needs =  unit.status.current_soul.personality.needs
    local need_index = -1
    for k = #needs-1,0,-1 do
        if needs[k].id == need_id then
            need_index = k
            break
        end
    end    if (need_index ~= -1 ) then
        return needs[need_index]
    end
    return nil
end

--######
--Main
--######

function getByID(id)
    for n, unit in ipairs(citizen) do
        if (unit.hist_figure_id == id) then
            return unit
        end
    end

    return nil
end

-- Find all training squads
-- Abort if no squads found
function checkSquads()
    local squads = {}
    local count = 0
    for n, mil in ipairs(df.global.world.squads.all) do
        if (mil.alias == squadname) then
            local leader = mil.positions[0].occupant
            if ( leader ~= -1) then
                table.insert(squads,mil)
                count = count +1
            end
        end
    end

    if (count == 0) then
        dfhack.print(scriptname.." | ")
        dfhack.printerr('ERROR: You need a squad with the name ' .. squadname)
        dfhack.print(scriptname.." | ")
        dfhack.printerr('That has an active Squad Leader')
        dfhack.color(-1)
        return nil
    end

    return squads
end

function addTraining(squads,unit)
    for n, squad in ipairs(squads) do
        for i=1,9,1   do
            if (unit.hist_figure_id == squad.positions[i].occupant) then
                return true
            end

            if (unit.military.squad_id ~= -1) then
                return false
            end

            if ( squad.positions[i].occupant  == -1 ) then
                squad.positions[i].occupant = unit.hist_figure_id
                return true
            end
        end
    end

    return false
end

function removeTraining(squads,unit)
    for n, squad in ipairs(squads) do
        for i=1,9,1   do
            if ( unit.hist_figure_id  == squad.positions[i].occupant ) then
                unit.military.squad_id = -1
                unit.military.squad_position = -1
                squad.positions[i].occupant = -1
                return true
            end
        end
    end
    return false
end

function removeAll(squads)
    if ( squads == nil) then return end
    for n, squad in ipairs(squads) do
        for i=1,9,1 do
            local dwarf = getByID(squad.positions[i].occupant)
            if (dwarf ~= nil) then
                dwarf.military.squad_id = -1
                dwarf.military.squad_position = -1
                squad.positions[i].occupant = -1
            end
        end
    end
end


function check()
    local squads = checkSquads()
    local intraining_count = 0
    local inque_count = 0
    if ( squads == nil)then return end
    for n, unit in ipairs(citizen) do
        local need = findNeed(unit,need_id)
        if ( need  ~= nil ) then
            if ( need.focus_level  < threshold ) then
                local bol = addTraining(squads,unit)
                if ( bol ) then
                    intraining_count = intraining_count +1
                else
                    inque_count = inque_count +1
                end
            else
                removeTraining(squads,unit)
            end
        end
    end

    dfhack.println(scriptname .. " | IGN: " .. ignore_count .. " TRAIN: " .. intraining_count .. " QUE: " ..inque_count )
end

function start()
    threshold = -5000
    dfhack.println(scriptname ..  " | START")

    if (args.t) then
        threshold = 0-tonumber(args.t)
    end

    running = true
    repeatUtil.scheduleEvery(scriptname,1000,'ticks',check)
end

function stop()
    repeatUtil.cancel(scriptname)
    local squads = checkSquads()
    removeAll(squads)
    running = false
    dfhack.println(scriptname .. " | STOP")
end

if dfhack_flags.enable then
    if dfhack_flags.enable_state then
        start()
        enabled = true
    else
        stop()
        enabled = false
    end
end

if dfhack_flags.module then
    return
end

if ( running ) then
    dfhack.println(scriptname .."    | Enabled")
else
    dfhack.println(scriptname .."    | Disabled")
end

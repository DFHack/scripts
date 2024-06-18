local argparse = require('argparse')

local units = df.global.world.units.active
local MONTH = 1200 * 28
local YEAR = MONTH * 12

local count = 0

local function scrub_active()
    for i=#units-1,0,-1 do
        local unit = units[i]
        if not dfhack.units.isDead(unit) or dfhack.units.isOwnRace(unit) then
            goto continue
        end
        local remove = false
        if dfhack.units.isMarkedForSlaughter(unit) then
            remove = true
        elseif unit.hist_figure_id == -1 then
            remove = true
        elseif not dfhack.units.isOwnCiv(unit) and
            not (dfhack.units.isMerchant(unit) or dfhack.units.isDiplomat(unit)) then
            remove = true
        end
        if remove and unit.counters.death_id ~= -1 then
            --  Keep recent deaths around for a month before culling them. It's
            --  annoying to have that rampaging FB just be gone from both the
            --  other and dead lists, and you may want to keep killed wildlife
            --  around for a while too. We don't have a time of death for
            --  slaughtered units, so they go the first time.
            local incident = df.incident.find(unit.counters.death_id)
            if incident then
                local incident_time = incident.event_year * YEAR + incident.event_time
                local now = df.global.cur_year * YEAR + df.global.cur_year_tick
                if now - incident_time < MONTH then
                    remove = false  --  Wait a while before culling it.
                end
            end
        end
        if remove then
            count = count + 1
            units:erase(i)
        end
        ::continue::
    end
end

local function scrub_burrows()
    for _, burrow in ipairs(df.global.plotinfo.burrows.list) do
        for _, unit_id in ipairs(burrow.units) do
            local unit = df.unit.find(unit_id)
            if unit and dfhack.units.isDead(unit) then
                count = count + 1
                dfhack.burrows.setAssignedUnit(burrow, unit, false)
            end
        end
    end
end

local args = {...}
if not args[1] then args[1] = '--active' end

local quiet = false

argparse.processArgsGetopt(args, {
    {nil, 'active', handler=scrub_active},
    {nil, 'burrow', handler=scrub_burrows},
    {nil, 'burrows', handler=scrub_burrows},
    {'q', 'quiet', handler=function() quiet = true end},
})

if count > 0 or not quiet then
    print('Dead units scrubbed: ' .. count)
end

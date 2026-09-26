--@module = true

local argparse = require('argparse')

local verbose, quiet = false, false
argparse.processArgsGetopt({...}, {
    {'v', 'verbose', handler=function() verbose = true end},
    {'q', 'quiet', handler=function() quiet = true end},
})

local function for_pray_need(needs, fn)
    for idx, need in ipairs(needs) do
        if need.id == df.need_type.PrayOrMeditate then
            fn(idx, need)
        end
    end
end

---Rearrange prayer needs
---@param needs _unit_personality_needs
---@param prayer_targets table<integer, boolean> analysis suggests that there is exactly one prayer target
---@return boolean?
local function shuffle_prayer_needs(needs, prayer_targets)
    local idx_of_prayer_target, max_focus_level
    local idx_of_min_focus_level, min_focus_level

    -- determine most satisfied need inside the prayer group and most
    -- unsatisfied need outside the prayer group
    for_pray_need(needs, function(idx, need)
        if prayer_targets[need.deity_id] and need.focus_level > -1000 and
            (not max_focus_level or need.focus_level > max_focus_level)
        then
            idx_of_prayer_target = idx
            max_focus_level = need.focus_level

        -- find a need that hasn't been met outside of the current prayer targets
        elseif not prayer_targets[need.deity_id] and
            need.focus_level <= -1000 and
            (not min_focus_level or need.focus_level < min_focus_level)
        then
            idx_of_min_focus_level = idx
            min_focus_level = need.focus_level
        end
    end)

    -- if a need inside the prayer group is met and a need outside of the
    -- prayer group is not met, swap the respective focus levels
    if idx_of_prayer_target and idx_of_min_focus_level then
        needs[idx_of_min_focus_level].focus_level = needs[idx_of_prayer_target].focus_level
        needs[idx_of_prayer_target].focus_level = min_focus_level
        return true
    end

    if not idx_of_prayer_target then return end

    -- If there is a satisfied prayer need inside the prayer group, set the
    -- focus level of all unsatisfied prayer needs inside the group to the
    -- maximum focus level found earlier (dead code if prayer groups are
    -- singletons)
    local modified = false
    for_pray_need(needs, function(_, need)
        if prayer_targets[need.deity_id] and need.focus_level <= -1000 then
            need.focus_level = needs[idx_of_prayer_target].focus_level
            modified = true
        end
    end)
    return modified
end

---get current prayer target(s) of a unit (as set of histfig_id)
---@param unit df.unit
---@return table<integer, boolean>?
function get_prayer_targets(unit)
    local deity_set = {}
    local return_set = false

    for _, sa in ipairs(unit.social_activities) do
        local ae = df.activity_entry.find(sa)
        if not ae or ae.type ~= df.activity_entry_type.Prayer then
            goto next_activity
        end
        for _, ev in ipairs(ae.events) do
            if df.activity_event_prayerst:is_instance(ev) then
                for _, participant_id in ipairs(ev.participants.units) do
                    if participant_id == unit.id then
                        deity_set[ev.histfig_id] = true
                        --I want to know whether units can actually have multiple prayer targets or not
                        if return_set then
                            dfhack.color(COLOR_YELLOW)
                            print(("%s has multiple prayer targets, please report"):format(
                                dfhack.translation.translateName(unit.name)
                            ))
                            dfhack.color(nil)
                        end
                        return_set = true
                    end
                end

            end
        end
        ::next_activity::
    end
    return return_set and deity_set or nil
end

if dfhack_flags.module then return end

local count = 0
for _,unit in ipairs(dfhack.units.getCitizens(false, true)) do
    local prayer_targets = get_prayer_targets(unit)
    if not unit.status.current_soul or not prayer_targets then
        goto next_unit
    end
    local needs = unit.status.current_soul.personality.needs
    if shuffle_prayer_needs(needs, prayer_targets) then
        count = count + 1
        if verbose then
            print('Shuffled prayer target for '..dfhack.df2console(dfhack.units.getReadableName(unit)))
        end
    end
    ::next_unit::
end

if not quiet or count > 0 then
    print(('Rebalanced prayer needs for %d units.'):format(count))
end

local function for_pray_need(needs, fn)
    for idx, need in ipairs(needs) do
        if need.id == df.need_type.PrayOrMeditate then
            fn(idx, need)
        end
    end
end

local function shuffle_prayer_needs(needs, prayer_targets)
    local idx_of_prayer_target, max_focus_level
    local idx_of_min_focus_level, min_focus_level
    for_pray_need(needs, function(idx, need)
        -- only shuffle if the need for one of the current prayer targets
        -- is already met
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
    -- prayer group is not met, transfer the credit outside of the prayer group
    if idx_of_prayer_target and idx_of_min_focus_level then
        needs[idx_of_min_focus_level].focus_level = needs[idx_of_prayer_target].focus_level
        needs[idx_of_prayer_target].focus_level = min_focus_level
        return true
    end

    if not idx_of_prayer_target then return end

    -- otherwise, if the only unmet needs are inside the prayer group,
    -- set the credit inside the prayer group to the level of the met need
    -- we found earlier
    local modified = false
    for_pray_need(needs, function(_, need)
        if prayer_targets[need.deity_id] and need.focus_level <= -1000 then
            need.focus_level = needs[idx_of_prayer_target].focus_level
            modified = true
        end
    end)
    return modified
end

local function get_prayer_targets(unit)
    for _, sa in ipairs(unit.social_activities) do
        local ae = df.activity_entry.find(sa)
        if not ae or ae.type ~= df.activity_entry_type.Prayer then
            goto next_activity
        end
        for _, ev in ipairs(ae.events) do
            if not df.activity_event_worshipst:is_instance(ev) then
                goto next_event
            end
            for _, hfid in ipairs(ev.participants.histfigs) do
                local hf = df.historical_figure.find(hfid)
                if not hf then goto next_hf end
                local deity_set = {}
                for _, hf_link in ipairs(hf.histfig_links) do
                    if df.histfig_hf_link_deityst:is_instance(hf_link) then
                        deity_set[hf_link.target_hf] = true
                    end
                end
                if next(deity_set) then return deity_set end
                ::next_hf::
            end
            ::next_event::
        end
        ::next_activity::
    end
end

for _,unit in ipairs(dfhack.units.getCitizens(false, true)) do
    local prayer_targets = get_prayer_targets(unit)
    if not unit.status.current_soul or not prayer_targets then
        goto next_unit
    end
    local needs = unit.status.current_soul.personality.needs
    if shuffle_prayer_needs(needs, prayer_targets) then
        print('rebalanced prayer needs for ' ..
            dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unit))))
    end
    ::next_unit::
end

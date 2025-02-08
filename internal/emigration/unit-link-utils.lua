--@module true

---@param histFig   df.historical_figure
---@param oldEntity df.historical_entity
function removeHistFigFromEntity(histFig, oldEntity)
    if not histFig or not oldEntity then return end

    local histFigId = histFig.id

    -- erase the unit from the fortress entity
    for k,v in ipairs(oldEntity.histfig_ids) do
        if v == histFigId then
            df.global.plotinfo.main.fortress_entity.histfig_ids:erase(k)
            break
        end
    end
    for k,v in ipairs(oldEntity.hist_figures) do
        if v.id == histFigId then
            df.global.plotinfo.main.fortress_entity.hist_figures:erase(k)
            break
        end
    end
    for k,v in ipairs(oldEntity.nemesis) do
        if v.figure.id == histFigId then
            df.global.plotinfo.main.fortress_entity.nemesis:erase(k)
            df.global.plotinfo.main.fortress_entity.nemesis_ids:erase(k)
            break
        end
    end

    -- remove the old entity link and create new one to indicate former membership
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_former_memberst, entity_id = oldEntity.id, link_strength = 100})
    for k,v in ipairs(histFig.entity_links) do
        if v._type == df.histfig_entity_link_memberst and v.entity_id == oldEntity.id then
            histFig.entity_links:erase(k)
            break
        end
    end
end

---@param histFig   df.historical_figure
---@param entity    df.historical_entity
function addNewHistFigEntityLink(histFig, entity)
end

---Creates events indicating a histfig's move to a new site and joining its entity.
---@param histFig df.historical_figure
---@param siteId  number Set to -1 if unneeded
---@param siteGov df.historical_entity
function addHistFigToSite(histFig, siteId, siteGov)
    if not histFig or not siteGov then return nil end

    local histFigId = histFig.id

    -- add new site gov to histfig links
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_memberst, entity_id = siteGov.id, link_strength = 100})

    -- add histfig to new site gov
    siteGov.histfig_ids:insert('#', histFigId)
    siteGov.hist_figures:insert('#', histFig)
    local hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_add_hf_entity_linkst, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, civ = siteGov.id, histfig = histFigId, link_type = 0})

    if siteId <= -1 then return end -- skip site join event

    -- create event indicating histfig moved to site
    hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_change_hf_statest, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, hfid = histFigId, state = 1, reason = -1, site = siteId})
end

---@param unit df.unit
function removeUnitAssociations(unit)
    -- free owned rooms
    for i = #unit.owned_buildings-1, 0, -1 do
        local tmp = df.building.find(unit.owned_buildings[i].id)
        dfhack.buildings.setOwner(tmp, nil)
    end

    -- remove from workshop profiles
    for _, bld in ipairs(df.global.world.buildings.other.WORKSHOP_ANY) do
        for k, v in ipairs(bld.profile.permitted_workers) do
            if v == unit.id then
                bld.profile.permitted_workers:erase(k)
                break
            end
        end
    end
    for _, bld in ipairs(df.global.world.buildings.other.FURNACE_ANY) do
        for k, v in ipairs(bld.profile.permitted_workers) do
            if v == unit.id then
                bld.profile.permitted_workers:erase(k)
                break
            end
        end
    end

    -- disassociate from work details
    for _, detail in ipairs(df.global.plotinfo.labor_info.work_details) do
        for k, v in ipairs(detail.assigned_units) do
            if v == unit.id then
                detail.assigned_units:erase(k)
                break
            end
        end
    end

    -- unburrow
    for _, burrow in ipairs(df.global.plotinfo.burrows.list) do
        dfhack.burrows.setAssignedUnit(burrow, unit, false)
    end
end

---@param unit      df.unit
---@param civId     number
---@param leaveNow  boolean Decides if unit leaves immediately or with merchants
function markUnitForEmigration(unit, civId, leaveNow)
    unit.following = nil
    unit.civ_id = civId

    if leaveNow then
        unit.flags1.forest = true
        unit.flags2.visitor = true
        unit.animal.leave_countdown = 2
    else
        unit.flags1.merchant = true
    end
end

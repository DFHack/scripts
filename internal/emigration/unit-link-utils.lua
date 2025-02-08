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
---@param newEntity df.historical_entity
function addHistFigToEntity(histFig, newEntity)
    if not histFig or not newEntity then return end

    local histFigId = histFig.id
    local newEntId = newEntity.id

    -- have unit join site government
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_memberst, entity_id = newEntId, link_strength = 100})

    -- create event indicating new membership
    newEntity.histfig_ids:insert('#', histFigId)
    newEntity.hist_figures:insert('#', histFig)
    local hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_add_hf_entity_linkst, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, civ = newEntId, histfig = histFigId, link_type = 0})
end

---@param histFig df.historical_figure
---@param newSite df.historical_entity
function createHistFigJoinSiteEvent(histFig, newSite)
    if not histFig or not newSite then return end

    -- create event indicating histfig moved to site
    local histFigId = histFig.id
    local siteId = newSite.id
    hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_change_hf_statest, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, hfid = histFigId, state = 1, reason = -1, site = siteId})
end

---@param histFig   df.historical_figure
---@param entity    df.historical_entity
function insertNewHistFigEntityLink(histFig, entity)
    if not histFig or not entity then return end

    local entityId = entity.id
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_memberst, entity_id = entityId, link_strength = 100})
end

---@param histFig df.historical_figure
---@param newSite df.world_site
---@return df.historical_entity|nil siteGov New site entity histfig is associated with
function addHistFigToSite(histFig, newSite)
    if not histFig or not newSite then return nil end

    -- have unit join site government
    local siteGovId = newSite.cur_owner_id
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_memberst, entity_id = siteGovId, link_strength = 100})
    local histFigId = histFig.id

    -- have unit join new site
    local siteId = newSite.id
    local siteGov = df.historical_entity.find(siteGovId)
    if not siteGov then qerror("could not find site!") end

    siteGov.histfig_ids:insert('#', histFigId)
    siteGov.hist_figures:insert('#', histFig)
    local hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_add_hf_entity_linkst, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, civ = siteGovId, histfig = histFigId, link_type = 0})

    hfEventId = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#", {new = df.history_event_change_hf_statest, year = df.global.cur_year, seconds = df.global.cur_year_tick, id = hfEventId, hfid = histFigId, state = 1, reason = -1, site = siteId})

    return siteGov
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

--@module = true

---@param histFig df.historical_figure
---@param oldEntity df.historical_entity
local function unassignMayor(histFig, oldEntity)
    local assignmentId = -1
    local nps = dfhack.units.getNoblePositions(histFig) or {}
    for _,pos in ipairs(nps) do
        if pos.entity.id == oldEntity.id and pos.position.flags.ELECTED then
            pos.assignment.histfig = -1
            pos.assignment.histfig2 = -1
            assignmentId = pos.assignment.id
        end
    end
    if assignmentId == -1 then qerror("could not find mayor assignment!") end

    local startYear = -1 -- remove mayor assignment
    for k,v in ipairs(histFig.entity_links) do
        if v.entity_id == oldEntity.id
            and df.histfig_entity_link_positionst:is_instance(v)
            and v.assignment_id == assignmentId
        then
            startYear = v.start_year
            histFig.entity_links:erase(k)
            v:delete()
            break
        end
    end
    if startYear == -1 then qerror("could not find entity link!") end

    histFig.entity_links:insert('#', {new = df.histfig_entity_link_former_positionst, assignment_id = assignmentId, start_year = startYear, entity_id = oldEntity.id, end_year = df.global.cur_year, link_strength = 100 })
end

---@param histFig df.historical_figure
---@param oldEntity df.historical_entity
---@param removeMayor boolean
function removeHistFigFromEntity(histFig, oldEntity, removeMayor)
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

    -- remove mayor assignment if exists
    if removeMayor then unassignMayor(histFig, oldEntity) end

    -- remove the old entity link and create new one to indicate former membership
    histFig.entity_links:insert("#", {new = df.histfig_entity_link_former_memberst, entity_id = oldEntity.id, link_strength = 100})
    for k,v in ipairs(histFig.entity_links) do
        if v._type == df.histfig_entity_link_memberst and v.entity_id == oldEntity.id then
            histFig.entity_links:erase(k)
            break
        end
    end
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

---@param item df.item
local function getPos(item)
    local x, y, z = dfhack.items.getPosition(item)
    if not x or not y or not z then
        return nil
    end

    if dfhack.maps.isTileVisible(x, y, z) then
        return xyz2pos(x, y, z)
    end
end

---@param assignmentId number
---@param entity df.historical_entity
---@param site df.world_site
function unassignSymbols(assignmentId, entity, site)
    local claims = entity.artifact_claims
    local artifacts = df.global.world.artifacts.all

    for i=#claims-1,0,-1 do
        local claim = claims[i]
        if claim.claim_type ~= df.artifact_claim_type.Symbol then goto continue end
        if claim.symbol_claim_id ~= assignmentId then goto continue end

        local artifact = artifacts[claim.artifact_id]
        local item = artifact.item
        local artifactName = dfhack.translation.translateName(artifact.name)

        -- we can probably keep artifact.entity_claims since we still hold it
        local itemPos = getPos(item)
        local success = false
        if not itemPos then
            if artifact.site == site.id then
                print(" ! "..artifactName.." cannot be found!")
                goto removeClaim
            else
                print(" ! "..artifactName.." is not in this site!")
                goto continue
            end
        end

        success = dfhack.items.moveToGround(item, itemPos)
        if success then print(" + dropped "..artifactName)
        else print(" ! could not drop "..artifactName)
        end

        -- they do not seem to "own" their artifacts, no additional cleaning seems necessary

        ::removeClaim::
        claims:erase(i)
        claim:delete()
        ::continue::
    end
end

-- Unstick noble symbols that cannot be re-designated.

local utils = require('utils')

local function GetArtifact(item)
    local artifact
    for _, generalRef in ipairs(item.general_refs) do
        if df.general_ref_is_artifactst:is_instance(generalRef) then
            artifact = df.artifact_record.find(generalRef.artifact_id)
            break
        end
    end
    local civ_id = df.global.plotinfo.civ_id
    -- Check if selected item is claimed by current site's civ.
    local entClaim_idx = artifact and utils.linear_index(artifact.entity_claims, civ_id)
    if artifact and entClaim_idx then
        return artifact, entClaim_idx
    end
    return nil
end

local function UnstickSymbol(artifact, entClaim_idx)
    local civEntity = df.historical_entity.find(df.global.plotinfo.civ_id)
    local idx = utils.linear_index(civEntity.artifact_claims, artifact.id, 'artifact_id')
    -- Check if selected item is a symbol.
    if idx and civEntity.artifact_claims[idx].claim_type == df.artifact_claim_type.Symbol then
        local position_idx = civEntity.artifact_claims[idx].symbol_claim_id
        -- Check if symbol's position has been vacated.
        if civEntity.positions.assignments[position_idx].histfig == -1 then
            -- Erase claim from the entity and its reference in the artifact's record.
            -- Note: it's also possible to re-assign symbol by changing symbol_claim_id
            -- to point to the appropriate idx in civEntity.positions.assignments
            civEntity.artifact_claims:erase(idx)
            artifact.entity_claims:erase(entClaim_idx)
            return true
        end
    end
    return false
end

local function Main(args)
    if args[1] == 'help' then
        print(dfhack.script_help())
        return
    end
    local item = dfhack.gui.getSelectedItem(true)
    if not item then
        qerror('No item selected.')
    end
    local artifact, entClaim_idx = GetArtifact(item)
    if artifact then
        if UnstickSymbol(artifact, entClaim_idx) then
            print('Symbol designation removed from selected item.')
            local strItemName = item and dfhack.items.getReadableDescription(item)
            print(('%s can now be re-designated as a symbol of nobility.'):format(strItemName))
        else
            qerror('Selected item is not a defunct symbol of the current site\'s civilization.')
        end
    else
        qerror('Selected item is not an artifact claimed by the current site\'s civilization.')
    end
end

if not dfhack.isSiteLoaded() and not dfhack.world.isFortressMode() then
    qerror('This script requires the game to be in fortress mode.')
end

Main({...})

--@ module = true

--TODO: map other claim types
claimType = {
    accuses = 0,
    confessed = 5,
    implicates = 6
}

function convictUnit (crime, unit)
    if crime.flags.sentenced then
        return false
    end

    crime.convicted_hf = unit.hist_figure_id
    crime.convicted_hf_2 = unit.hist_figure_id
    --crime.convicted_hf_3 = unit.hist_figure_id -- this value is not set by the game

    -- TODO: Not sure why the game fill this vector. Need to investigate if the convict and victim is always equal and if it has only one entry
    if #crime.convict_data.unk_v47_vector_1 > 0 then
        local convict = crime.convict_data.unk_v47_vector_1[0]
        crime.victim_data.unk_v47_vector_2:insert(#crime.victim_data.unk_v47_vector_2, convict)
    end

    crime.convict_data.convicted = unit.id
    crime.flags.sentenced = false

    return true
end

function scheduleInterview (crime, unit)
    if isScheduled(crime, unit.hist_figure_id) or not canInterview(unit) then
        return false
    end

    local report = df.crime.T_reports:new()
    report.accused_id = unit.hist_figure_id
    report.accused_id_2 = unit.hist_figure_id

    crime.reports:insert(#crime.reports, report)

    return true
end

function scheduleduleInterviewUnits (crime, units)
    for i, unit in ipairs (units) do
        scheduleInterview(crime, unit)
    end
end

function skipConviction (unit)
    --TODO: Not sure how to check long term resident or others that asked to join
    if dfhack.units.isCitizen(unit, true) then
        return true -- Always skip citizen crimes
    end

    return false
end

function isScheduled (crime, hist_figure_id)
    for i, report in ipairs (crime.reports) do
        if report.accused_id == hist_figure_id then
            return true
        end
    end
    return false
end

function didInterview (crime, hist_figure_id)
    for i, report in ipairs (crime.counterintelligence) do
        if report.identified_hf == hist_figure_id then
            return true
        end
    end
    return false
end

function canInterview(unit)
    return dfhack.units.isActive(unit) and
        unit.status.current_soul and
        not dfhack.units.isAnimal(unit)
end

function isOpenCrime (crime, siteId)
    return crime.site == siteId and
        crime.flags.discovered and
        not crime.flags.sentenced
end


function isUndiscoveredCrime (crime, siteId)
    return crime.site == siteId and
        not crime.flags.discovered
end

function getOpenCrimes (crimes, siteId)
    local r = {}

    for i, crime in ipairs (crimes) do
        if isOpenCrime(crime, siteId) then
            table.insert(r, crime)
        end
    end

    return r
end

function getConfessedUnit (crime)
    for i, witness in ipairs (crime.witnesses) do
        if witness.witness_claim == claimType.confessed then
            return df.unit.find(witness.witness_id)
        end
    end
    return nil
end

function getAccusedUnit (crime)
    for i, witness in ipairs (crime.witnesses) do
        if witness.witness_claim == claimType.accuses or
            witness.witness_claim == claimType.implicates then
            return df.unit.find(witness.accused_id)
        end
    end
    return nil
end

function hasConfessed (crime, unit)
    local confessed = getConfessedUnit(crime)
    return confessed ~= nil and confessed.hist_figure_id == unit.hist_figure_id
end

function isAccused (crime, unit)
    local accused = getAccusedUnit(crime)
    return accused ~= nil and accused.hist_figure_id == unit.hist_figure_id
end

function findRelatedCrimes (crimes, unit)
    local r = {}

    for i, crime in ipairs (crimes) do
        if didInterview(crime, unit.hist_figure_id) then
            table.insert(r, crime)
        end
    end

    return r
end

function tryConvictUnit (crime, unit)
    if crime.flags.sentenced or unit == nil then
        return false
    end

    if skipConviction(unit) then
        return true
    end

    return convictUnit(crime, unit)
end

function trySolveCrime (crime)
    if crime.flags.sentenced or #crime.witnesses == 0 then
        return false
    end

    local unit = getConfessedUnit(crime)
    if (unit == nil) then
        return false
    end

    if skipConviction(unit) then
        return true
    end

    return convictUnit(crime, unit)
end
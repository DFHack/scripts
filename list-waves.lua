-- displays migration wave information for citizens

local argparse = require('argparse')
local utils = require('utils')

local TICKS_PER_DAY = 1200
local TICKS_PER_MONTH = 28 * TICKS_PER_DAY
local TICKS_PER_SEASON = 3 * TICKS_PER_MONTH

local function get_season(year_ticks)
    local seasons = {
        'spring',
        'summer',
        'autumn',
        'winter',
    }

    return tostring(seasons[year_ticks // TICKS_PER_SEASON + 1])
end

local granularities = {
    days={
        to_wave_fn=function(elink) return elink.year * 28 * 12 + elink.seconds // TICKS_PER_DAY end,
        to_string_fn=function(elink) return ('year %d, month %d (%s), day %d'):format(
            elink.year, elink.seconds // TICKS_PER_MONTH + 1, get_season(elink.seconds), elink.seconds // TICKS_PER_DAY + 1) end,
    },
    months={
        to_wave_fn=function(elink) return elink.year * 12 + elink.seconds // TICKS_PER_MONTH end,
        to_string_fn=function(elink) return ('year %d, month %d (%s)'):format(
            elink.year, elink.seconds // TICKS_PER_MONTH + 1, get_season(elink.seconds)) end,
    },
    seasons={
        to_wave_fn=function(elink) return elink.year * 4 + elink.seconds // TICKS_PER_SEASON end,
        to_string_fn=function(elink) return ('the %s of year %d'):format(get_season(elink.seconds), elink.year) end,
    },
    years={
        to_wave_fn=function(elink) return elink.year end,
        to_string_fn=function(elink) return ('year %d'):format(elink.year) end,
    },
}

local plotinfo = df.global.plotinfo

local function match_unit_id(unit_id, hf)
    if not unit_id or hf.unit_id < 0 then return false end
    return hf.unit_id == unit_id
end

local function add_hfdata(opts, hfs, ev, hfid)
    local hf = df.historical_figure.find(hfid)
    if not hf or
        dfhack.units.casteFlagSet(hf.race, hf.caste, df.caste_raw_flags.PET) or
        dfhack.units.casteFlagSet(hf.race, hf.caste, df.caste_raw_flags.PET_EXOTIC)
    then
        return
    end
    hfs[hfid] = hfs[hfid] or {
        hf=hf,
        year=ev.year,
        seconds=ev.seconds,
        dead=false,
        petitioned=false,
        highlight=match_unit_id(opts.unit_id, hf),
    }
end

local function record_histfig_residency(opts, hfs, ev, enid, hfid)
    if enid == plotinfo.group_id then
        add_hfdata(opts, hfs, ev, hfid)
        hfs[hfid].petitioned = true
    end
end

local function record_residency_agreement(opts, hfs, ev)
    local agreement = df.agreement.find(ev.agreement_id)
    if not agreement then return end
    local found = false
    for _,details in ipairs(agreement.details) do
        if details.type == df.agreement_details_type.Residency and details.data.Residency.site == plotinfo.site_id then
            found = true
            break
        end
    end
    if not found then return end
    if #agreement.parties ~= 2 or #agreement.parties[1].entity_ids ~= 1 then return end
    local enid = agreement.parties[1].entity_ids[0]
    if #agreement.parties[0].histfig_ids == 1 then
        local hfid = agreement.parties[0].histfig_ids[0]
        record_histfig_residency(opts, hfs, ev, enid, hfid)
    elseif #agreement.parties[0].entity_ids == 1 then
        local troupe = df.historical_entity.find(agreement.parties[0].entity_ids[0])
        if troupe and troupe.type == df.historical_entity_type.PerformanceTroupe then
            for _,hfid in ipairs(troupe.histfig_ids) do
                record_histfig_residency(opts, hfs, ev, enid, hfid)
            end
        end
    end
end

-- returns map of histfig id to {hf=df.historical_figure, year=int, seconds=int, dead=bool, petitioned=bool, highlight=bool}
local function get_histfigs(opts)
    local hfs = {}
    for _,ev in ipairs(df.global.world.history.events) do
        local evtype = ev:getType()
        if evtype == df.history_event_type.CHANGE_HF_STATE then
            if ev.site == plotinfo.site_id and ev.state == df.whereabouts_type.settler then
                add_hfdata(opts, hfs, ev, ev.hfid)
            end
        elseif evtype == df.history_event_type.AGREEMENT_FORMED then
            record_residency_agreement(opts, hfs, ev)
        elseif evtype == df.history_event_type.HIST_FIGURE_DIED then
            if hfs[ev.victim_hf] then
                hfs[ev.victim_hf].dead = true
            end
        elseif evtype == df.history_event_type.HIST_FIGURE_REVIVED then
            if hfs[ev.histfig] then
                hfs[ev.histfig].dead = false
            end
        end
    end
    return hfs
end

local function cull_histfigs(opts, hfs)
    for hfid,hfdata in pairs(hfs) do
        if not opts.petitioners and hfdata.petitioned or
            not opts.dead and hfdata.dead
        then
            hfs[hfid] = nil
        end
    end
    return hfs
end

local function get_waves(opts)
    local waves = {}
    for _,hfdata in pairs(cull_histfigs(opts, get_histfigs(opts))) do
        local waveid = granularities[opts.granularity].to_wave_fn(hfdata)
        if not waveid then goto continue end
        table.insert(ensure_keys(waves, waveid, hfdata.petitioned and 'petitioners' or 'migrants'), hfdata)
        if not waves[waveid].desc then
            waves[waveid].desc = granularities[opts.granularity].to_string_fn(hfdata)
        end
        waves[waveid].highlight = waves[waveid].highlight or hfdata.highlight
        waves[waveid].size = (waves[waveid].size or 0) + 1
        ::continue::
    end
    return waves
end

local function spairs(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    utils.sort_vector(keys)
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k then
            return k, t[k]
        end
    end
end

local function print_units(header, hfs)
    print()
    print(('  %s:'):format(header))
    for _,hfdata in ipairs(hfs) do
        local deceased = hfdata.dead and ' (deceased)' or ''
        local highlight = hfdata.highlight and ' (selected unit)' or ''
        local unit = df.unit.find(hfdata.hf.unit_id)
        local name = unit and dfhack.units.getReadableName(unit) or dfhack.units.getReadableName(hfdata.hf)
        print(('    %s%s%s'):format(dfhack.df2console(name), deceased, highlight))
    end
end

local function print_waves(opts, waves)
    local wave_num = 0
    for _,wave in spairs(waves) do
        wave_num = wave_num + 1
        if opts.wave_filter and not opts.wave_filter[wave_num-1] then goto continue end
        local highlight = wave.highlight and ' (includes selected unit)' or ''
        print(('Wave %2d consisted of %2d unit(s) and arrived in %s%s'):format(wave_num-1, wave.size, wave.desc, highlight))
        if opts.names then
            if wave.migrants and #wave.migrants > 0 then
                print_units('Migrants', wave.migrants)
            end
            if wave.petitioners and #wave.petitioners > 0 then
                print_units('Units who joined via petition', wave.petitioners)
            end
            print()
        end
        ::continue::
    end
end

local opts = {
    granularity='seasons',
    dead=true,
    names=true,
    petitioners=true,
    unit_id=nil,
    wave_filter=nil,
}
local help = false
local positionals = argparse.processArgsGetopt({...}, {
        {'d', 'no-dead', handler=function() opts.dead = false end},
        {'g', 'granularity', hasArg=true, handler=function(arg) opts.granularity = arg end},
        {'h', 'help', handler=function() help = true end},
        {'n', 'no-names', handler=function() opts.names = false end},
        {'p', 'no-petitioners', handler=function() opts.petitioners = false end},
        {'u', 'unit', hasArg=true, handler=function(arg) opts.unit_id = tonumber(arg) end},
    })

if positionals[1] == 'help' or help == true then
    print(dfhack.script_help())
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('please load a fortress')
end

if not granularities[opts.granularity] then
    qerror(('Invalid granularity value: "%s". Omit the option if you want "seasons".'):format(opts.granularity))
end

for _,wavenum in ipairs(positionals) do
    local wavenumnum = tonumber(wavenum)
    if wavenumnum then
        opts.wave_filter = opts.wave_filter or {}
        opts.wave_filter[wavenumnum] = true
    end
end

if not opts.unit_id then
    local selected_unit = dfhack.gui.getSelectedUnit(true)
    opts.unit_id = selected_unit and selected_unit.id
end

print_waves(opts, get_waves(opts))

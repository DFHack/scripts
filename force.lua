local wildlife = reqscript('fix/wildlife')

local function findCiv(civ)
    if civ == 'player' then return df.historical_entity.find(df.global.plotinfo.civ_id) end
    if tonumber(civ) then return df.historical_entity.find(tonumber(civ)) end
    civ = string.lower(tostring(civ))
    for _,entity in ipairs(df.global.world.entities.all) do
        if string.lower(entity.entity_raw.code) == civ then return entity end
    end
end

local args = { ... }
if #args < 1 then qerror('missing event type') end
if args[1]:find('help') then
    print(dfhack.script_help())
    return
end

local eventType = args[1]:upper()

-- handle synthetic events
if eventType == 'WILDLIFE' then
    wildlife.free_all_wildlife(args[2] == 'all')
    return
end

-- handle native events
for _, type in ipairs(df.timed_event_type) do
    if type:lower() == args[1]:lower() then
        eventType = type
    end
end
if not df.timed_event_type[eventType] then
    qerror('unknown event type: ' .. args[1])
end
if eventType == 'FeatureAttack' then
    qerror('Event type: FeatureAttack is not currently supported')
end

local civ

if eventType == 'Caravan' or eventType == 'Diplomat' then
    civ = findCiv(args[2] or 'player')
    if not civ then
        qerror('unable to find civilization: '..tostring(civ))
    end
elseif eventType == 'Migrants' then
    civ = findCiv('player')
end

df.global.timed_events:insert('#', {
    new=true,
    type=df.timed_event_type[eventType],
    season=df.global.cur_season,
    season_ticks=df.global.cur_season_tick,
    entity=civ,
    feature_ind=-1,
})

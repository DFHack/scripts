function getEntityName(u)
    local civ = df.historical_entity.find(u.civ_id)
    if not civ then return 'unknown civ' end
    return dfhack.translation.translateName(civ.name)
end

function getEntityRace(u)
    local civ = df.historical_entity.find(u.civ_id)
    if civ then
        local craw = df.creature_raw.find(civ.race)
        if craw then
            return craw.name[0]
        end
    end
    return 'unknown race'
end

function dismissMerchants(args)
    local dry_run = false
    for _, arg in pairs(args) do
        if args[1]:match('-h') or args[1]:match('help') then
            print(dfhack.script_help())
            return
        elseif args[1]:match('-n') or args[1]:match('dry') then
            dry_run = true
        end
    end
    for _,u in pairs(df.global.world.units.active) do
        if u.flags1.merchant and not dfhack.units.isActive (u) then
            print(('%s unit %d: %s (%s), civ %d (%s, %s)'):format(
                dry_run and 'Would remove' or 'Removing',
                u.id,
                dfhack.df2console(dfhack.units.getReadableName(u)),
                df.creature_raw.find(u.race).name[0],
                u.civ_id,
                dfhack.df2console(getEntityName(u)),
                getEntityRace(u)
            ))
            if not dry_run then
                u.flags1.left = true
            end
        end
    end
end

dismissMerchants{...}

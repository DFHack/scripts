if dfhack.isWorldLoaded() then
    df.global.world.worldgen.worldgen_parms.embark_points = tonumber(...)
    local scr = dfhack.gui.getDFViewscreen()
    if df.viewscreen_setupdwarfgamest:is_instance(scr) then
        scr.points_remaining = tonumber(...)
    end
else
    qerror('no world loaded - cannot modify embark points')
end

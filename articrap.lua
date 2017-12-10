--Like artifake but maybe with a little less of the shiny fancy stuff, might fall off truck once or six time, is good!
--[====[
articrap
=====
Changes the selected item or inventory full of items into artifact quality items which don't accumulate wear.
]====]
local scrn=dfhack.gui.getCurViewscreen()
local articrap
    if df.viewscreen_itemst:is_instance(scrn) then
            articrap=scrn.item
            articrap.flags.artifact_mood=true
            articrap.flags.artifact=true
            articrap.quality=6
            articrap.wear=0
            articrap.wear_timer=0
--[[play with these                articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=41,mat_index=3,quality=6,skill_rating=15})
      if you want bling            articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=420,mat_index=230,quality=6,skill_rating=15})]]
                articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=0,mat_index=9,quality=6,skill_rating=15})
            if (df.item_weaponst:is_instance(articrap) or df.item_toolst:is_instance(articrap)) then articrap.sharpness=100000 end
    elseif df.viewscreen_dungeon_monsterstatusst:is_instance(scrn) then
            articrap=scrn.inventory
        for k,v in ipairs(articrap) do
            articrap[k].item.flags.artifact=true
            articrap[k].item.flags.artifact_mood=true
            articrap[k].item.quality=6
            articrap[k].item.wear=0
            articrap[k].item.wear_timer=0
--[[play with these                articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=41,mat_index=3,quality=6,skill_rating=15})
      if you want bling            articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=420,mat_index=230,quality=6,skill_rating=15})]]
                articrap[k].item.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=0,mat_index=9,quality=6,skill_rating=15})
            if (df.item_weaponst:is_instance(articrap[k].item) or df.item_toolst:is_instance(articrap[k].item)) then articrap[k].item.sharpness=100000 end
        end
    elseif df.global.ui_advmode.menu==5 then
        articrap=df.global.world.units.active[0].inventory
        for k,v in ipairs(articrap) do
            articrap[k].item.flags.artifact=true
            articrap[k].item.flags.artifact_mood=true
            articrap[k].item.quality=6
            articrap[k].item.wear=0
            articrap[k].item.wear_timer=0
--[[play with these                articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=41,mat_index=3,quality=6,skill_rating=15})
      if you want bling            articrap.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=420,mat_index=230,quality=6,skill_rating=15})]]
                articrap[k].item.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=0,mat_index=9,quality=6,skill_rating=15})
            if (df.item_weaponst:is_instance(articrap[k].item) or df.item_toolst:is_instance(articrap[k].item)) then articrap[k].item.sharpness=100000 end
        end
end

--Use while viewing an item, unit inventory, or tile to start fires.
local tinder
if dfhack.gui.getCurFocus() == 'item' then
    tinder=dfhack.gui.getCurViewscreen().item
    tinder.flags.on_fire=true
elseif dfhack.gui.getSelectedUnit(true) then
    tinder=dfhack.gui.getSelectedUnit(true).inventory
        for k,v in ipairs(tinder) do
            tinder[k].item.flags.on_fire=true
        end
elseif df.global.ui_advmode.menu==1 then
local curpos=df.global.cursor
    df.global.world.fires:insert('#',{new=df.fire})
local hot = df.global.world.fires
    for _,k in ipairs(hot) do
        if k.temperature==0 then
        local spot = k
            k.pos.x=curpos.x
            k.pos.y=curpos.y
            k.pos.z=curpos.z
            k.timer=1000
            k.temperature=60000
        end
    end
end

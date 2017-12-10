--Assume Direct Control of the unit you're viewing. This Can Hurt You.
local utils = require 'gui'
local dialog = require 'gui.dialogs'

function assumeControl(new,old)
local actold
for i,j in ipairs(df.global.world.units.all) do
    if j.id==df.global.world.units.active[0].id then
        actold=j.id
        break
    end
end
local active=df.global.world.units.active
local old
old=df.unit.find(actold)
local new
new=dfhack.gui.getSelectedUnit(true)
if new==nil then
    qerror("Unable to Assume Control!")
end
local actnew
for k,v in pairs(active) do
    if v==new then
        actnew=k
        break
    end
end
if actnew==nil then
    qerror("Attempt to Assume Control has failed?")
end
if dfhack.gui.getSelectedUnit(true)==active[0] then
    local choices={}
    for k,v in pairs(active) do
        if dfhack.units.getNemesis(active[k]).flags.RETIRED_ADVENTURER==true then
            local nems=active[k]
            table.insert(choices,{text=nems.name.first_name,nems=k})
        end
        dialog.showListPrompt("Unit choice", "Choose unit to return to:", COLOR_WHITE,choices,
            function (idx,choice)
              dfhack.units.getNemesis(choice).flags.ACTIVE_ADVENTURER=true
              dfhack.units.getNemesis(choice).flags.ADVENTURER=true
              dfhack.units.getNemesis(choice).flags.RETIRED_ADVENTURER=false
              choice.status.current_soul.personality.flags[1]=true
              dfhack.units.getNemesis(old).flags.ACTIVE_ADVENTURER=false
              dfhack.units.getNemesis(old).flags.RETIRED_ADVENTURER=true
              old.status.current_soul.personality.flags[1]=false
              return
            end)
    end
end
active[actnew]=active[0]
active[0]=new
local target = dfhack.units.getNemesis(new)
    if target then
    local nwnem=dfhack.units.getNemesis(new)
    local olnem=dfhack.units.getNemesis(old)
    if olnem then
        olnem.flags.ACTIVE_ADVENTURER=false
        olnem.flags.RETIRED_ADVENTURER=true
        olnem.unit.status.current_soul.personality.flags[1]=false
        olnem.unit.idle_area.x=olnem.unit.pos.x
        olnem.unit.idle_area.y=olnem.unit.pos.y
        olnem.unit.idle_area.z=olnem.unit.pos.z
    end
    if nwnem then
        nwnem.flags.ACTIVE_ADVENTURER=true
        nwnem.flags.RETIRED_ADVENTURER=false
        nwnem.flags.ADVENTURER=true
        nwnem.unit.status.current_soul.personality.flags[1]=true
        for k,v in pairs(df.global.world.nemesis.all) do
            if v.id==nwnem.id then
                df.global.ui_advmode.player_id=k
                end
            end
        end
    else
        qerror("Assuming Direct Control! Current target may not last long!")
    end
end
assumeControl(new,old)

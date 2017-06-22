local utils = require 'gui'

function assumeControl(new,old)
local actold
for i,j in ipairs(df.global.world.units.all) do
	if j.id==df.global.world.units.active[0].id then
		actold=j.id
		break
	end
end
local old
old=df.unit.find(actold)
local new
new=dfhack.gui.getSelectedUnit(true)
if new==nil then
	qerror("Unable to Assume Control!")
end
local active=df.global.world.units.active
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
	end
	if nwem then
		nwem.flags.ACTIVE_ADVENTURER=true
		nwem.flags.RETIRED_ADVENTURER=false
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
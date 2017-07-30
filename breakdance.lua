--Breaks up a stuck dance activity.
--[====[

breakdance
=====
Breaks up broken or otherwise hung dances that occur when a unit can't find a partner.

]====]
local unit = df.global.world.units.active[0]
local act = unit.social_activities[0]
if df.activity_entry.find(act).type==8 then
    df.activity_entry.find(act).events[0].flags.dismissed = true
end

--Breaks up a stuck dance activity.
local unit = df.global.world.units.active[0]
local act = unit.social_activities[0]
if df.activity_entry.find(act).type==8 then
    df.activity_entry.find(act).events[0].flags.dismissed = true
end

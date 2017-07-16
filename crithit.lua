--Turns the previously readied attack into a super powerful critical hit.
local unit = df.global.world.units.active[0]
local attks = unit.actions
for k,v in ipairs(attks) do
    if attks[k].type==1 then
        attks[k].data.attack.attack_accuracy=1000
        attks[k].data.attack.attack_velocity=9999999
    end
    for i = 0,3 do
        unit.body.body_plan.attacks[i].velocity_modifier=2700000
        unit.body.body_plan.attacks[i].contact_perc=100000
        unit.body.body_plan.attacks[i].penetration_perc=100000
        unit.body.body_plan.attacks[i].flags.edge=true
    end
end

--Turns the previously readied attack into a super powerful critical hit.
local unit = df.global.world.units.active[0]
local attks = unit.actions
for k,v in ipairs(attks) do
	if attks[k].type==1 then
		unit.body.body_plan.attacks[0].velocity_modifier=2700000
		unit.body.body_plan.attacks[0].contact_perc=100000
		unit.body.body_plan.attacks[0].penetration_perc=100000
		unit.body.body_plan.attacks[0].flags.edge=true
		unit.body.body_plan.attacks[1].velocity_modifier=2700000
		unit.body.body_plan.attacks[1].contact_perc=100000
		unit.body.body_plan.attacks[1].penetration_perc=100000
		unit.body.body_plan.attacks[1].flags.edge=true
		unit.body.body_plan.attacks[2].velocity_modifier=2700000
		unit.body.body_plan.attacks[2].contact_perc=100000
		unit.body.body_plan.attacks[2].penetration_perc=100000
		unit.body.body_plan.attacks[2].flags.edge=true
		unit.body.body_plan.attacks[3].velocity_modifier=2700000
		unit.body.body_plan.attacks[3].contact_perc=100000
		unit.body.body_plan.attacks[3].penetration_perc=100000
		unit.body.body_plan.attacks[3].flags.edge=true
		attks[k].data.attack.attack_accuracy=1000
		attks[k].data.attack.attack_velocity=9999999
	end
end
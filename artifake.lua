local utils = require 'utils'

validArgs = validArgs or utils.invert({
 'help',
 'material',
 'item',
 'name',
 'r',
 'l' 
})

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(
[[artifake.lua
arguments:
	-help
	print this help message
	-material matstring
	specify the material of the item to be created
	examples:
			INORGANIC:IRON
			CREATURE_MAT:DWARF:BRAIN
			PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
-item itemstring
		specify the itemdef of the item to be created
		examples:
		WEAPON:ITEM_WEAPON_PICK
-name namestring
	specify a first name if desired
-r
	for right handed gloves
-l
	for left handed gloves
]])
 return
end

if dfhack.gui.getSelectedUnit(true) then
 args.creator = dfhack.gui.getSelectedUnit()
 else args.creator = df.global.world.units.active[0]
end
if not args.item then
 error 'Invalid item.'
end
local itemType = dfhack.items.findType(args.item)
if itemType == -1 then
 error 'Invalid item.'
end
local itemSubtype = dfhack.items.findSubtype(args.item)

args.material = dfhack.matinfo.find(args.material)
if not args.material then
 error 'Invalid material.'
end


local item = dfhack.items.createItem(itemType, itemSubtype, args.material['type'], args.material.index, args.creator)

local base=df.item.find(df.global.item_next_id-1)
df.global.world.artifacts.all:new()
df.global.world.artifacts.all:insert('#',{new=df.artifact_record})
local facts = df.global.world.artifacts.all
	for _,k in ipairs(facts) do
		if k.item==nil then
	local fake=k
	fake.id=df.global.artifact_next_id
	fake.item = {new=base}
		fake.item.flags.artifact = false
		fake.item.flags.artifact_mood = true
		fake.item.id = base.id
		fake.item.general_refs:insert('#',{new =df.general_ref_is_artifactst})
		fake.item.general_refs[0].artifact_id = fake.id
		fake.item.spec_heat = base.spec_heat
		fake.item.ignite_point = base.ignite_point
		fake.item.heatdam_point = base.heatdam_point
		fake.item.colddam_point = base.colddam_point 
		fake.item.boiling_point = base.boiling_point
		fake.item.fixed_temp = base.fixed_temp
		fake.item.weight = base.weight
		fake.item.weight_fraction = base.weight_fraction
		fake.item.improvements:insert('#',{new = df.itemimprovement_spikesst,mat_type=41,mat_index=3,quality=6,skill_rating=15})
		fake.item.improvements:insert('#',{new = df.itemimprovement_spikesst,mat_type=40,mat_index=3,quality=6,skill_rating=15})
		fake.item.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=43,mat_index=3,quality=6,skill_rating=15})
		fake.item.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=420,mat_index=230,quality=6,skill_rating=15})
		fake.item.improvements:insert('#',{new = df.itemimprovement_art_imagest,mat_type=0,mat_index=9,quality=6,skill_rating=15})
	fake.flags:new()
		for i = 0,7 do
	if #fake.flags < 8 then
		fake.flags[i] = true
	elseif #fake.flags==8 then
		 fake.flags[0] = false
		 fake.flags[i] = false
		 end
	 end
	 fake.anon_1 = -1000000
	 fake.anon_2 = -1000000
	 fake.anon_3 = -1000000
	 base.flags.artifact = false
	 base.flags.artifact_mood = true
	 base.general_refs = fake.item.general_refs
	 base.improvements = fake.item.improvements
	 fake.item:setQuality(6)
	 base:setQuality(6)
	 if (df.item_weaponst:is_instance(fake.item) or df.item_toolst:is_instance(fake.item)) then fake.item.sharpness=100000 end
	 if (df.item_weaponst:is_instance(base) or df.item_toolst:is_instance(base)) then base.sharpness=100000 end
	 df.global.artifact_next_id=df.global.artifact_next_id+1
	 df.global.world.history.events:new()
	 df.global.world.history.events:insert('#',{new=df.history_event_artifact_createdst,
		year = df.global.cur_year,
		seconds = df.global.cur_year_tick_advmode,
		id = df.global.hist_event_next_id,
		artifact_id = fake.id,
		unit_id = args.creator.id,
		hfid = args.creator.hist_figure_id,
		}
		)
 df.global.hist_event_next_id = df.global.hist_event_next_id+1 
if args.r then
	base.handedness[0] = true
	fake.item.handedness[0] = true
end
if args.l then
	base.handedness[1] = true
	fake.item.handedness[1] = true
end
 if args.name then do
fake.name.first_name = args.name
fake.name.language = 0
fake.name.has_name = true 
			end
		end
	 end
end
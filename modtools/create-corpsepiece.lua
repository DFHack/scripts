-- creates any corpsepiece or (single-layered) body part from a selected unit
--author expwnent
local usage = [====[

modtools/create-corpsepiece
====================

Arguments::

    -creator id
        specify the id of the unit who will create the bone,
        or \\LAST to indicate the unit with id df.global.unit_next_id-1
        this uses the currently selected unit if no creator is specified
        examples:
            0
            2
            \\LAST
    -bodypart
        specify the id of body part of the unit to spawn a cloned bone from
        examples:
            1
            10
            30
    -layer
        select a tissue layer from the selected body part
        examples:
            0 (outermost)
            1
            3 (usually bone on a dwarf)
    -list
        list the body parts (names and ids) of the selected unit, but don't do anything

]====]
local utils = require 'utils'
local gui = require('gui')

local validArgs = utils.invert({
 'help',
 'creator',
 'bodypart',
 'layer',
-- 'amount',
-- 'creature',
-- 'caste',
 'list'
})

function createItem(creatorID, bodypart, partlayer)

 local creator = nil

 if creatorID ~= nil then
    creator = df.unit.find(creatorID)
 else
    creator = dfhack.gui.getSelectedUnit(true)
 end

 if creator == nil then
    qerror("Please select a unit to spawn from in the game UI")
 end

 -- print(creator)

 local bodpart = tonumber(bodypart)
 local patlayer = tonumber(partlayer)
 
 if bodpart == nil then
  error 'Invalid bodypart.'
 end

 if amnt == nil then
  amnt = 1
 end

 if patlayer == nil then
  error 'Invalid bodypart layer.'
 end
 -- store the tissue id of the specific layer we selected
 local parlayer = tonumber(creator.body.body_plan.body_parts[bodpart].layers[patlayer].tissue_id)
 
 -- some materials have layers that are just not in the mat_layers field, so ???????
 if parlayer > #(creator.body.body_plan.materials.mat_type) - 1 then
	parlayer = #(creator.body.body_plan.materials.mat_type) - 1
 end

 -- default is MEAT, so if anything else fails to change it to something else, we know that the body layer is a meat item
 local itemm = "MEAT"
 -- get race name and layer name, both for finding the item material, and the latter for determining the corpsepiece flags to set
 local raceName = string.upper(df.creature_raw.find(creator.race).creature_id)
 local layerName = creator.body.body_plan.body_parts[bodpart].layers[patlayer].layer_name
 
 -- print(raceName)
 -- print(layerName)
 
 -- copy of the tissue_id that isn't affected by the following hair material check, so later lines don't go weird, i guess? i forgor :skull:
 local farlayer = parlayer
 
 -- print(farlayer)

 -- every key is a valid non-hair corpsepiece, so if we try to index a key that's not on the table, we don't have a non-hair corpsepiece
 local corpseTable = {BONE = "BONE", SKIN = "SKIN", CARTILAGE = "CARTILAGE", TOOTH = "TOOTH", NERVE = "NERVE", NAIL = "NAIL", HORN = "HORN", HOOF = "HOOF"}
 -- we do the same as above but with hair
 local hairTable = {HAIR = "HAIR", EYEBROW = "EYEBROW", EYELASH = "EYELASH", MOUSTACHE = "MOUSTACHE", CHIN_WHISKERS = "CHIN_WHISKERS", SIDEBURNS = "SIDEBURNS"}
 -- if the layer is fat, spawn a glob of fat and DON'T check for other layer types
 if layerName == "FAT" then
  itemm = "GLOB"
 elseif corpseTable[layerName] then
  itemm = "CORPSEPIECE"
 elseif hairTable[layerName] then -- check if hair
  farlayer = 5
  layerName = "HAIR" -- we then simplify every hair-tissue into just "HAIR"
  itemm = "CORPSEPIECE"
 end
 
 local itemType = dfhack.items.findType(itemm..":NONE")
 if itemType == -1 then
  error 'Invalid item.'
 end
 local itemSubtype = dfhack.items.findSubtype(itemm..":NONE")
 
 -- print(creator.body.body_plan.materials.mat_type[farlayer])
 
 local material = "CREATURE_MAT:"..raceName..":"..layerName
 
 if not material then
  error 'Invalid material.'
 end
 local materialInfo = dfhack.matinfo.find(material)
 if not materialInfo then
  error 'Invalid material.'
 end
 
 local item1 = dfhack.items.createItem(itemType, itemSubtype, materialInfo['type'], materialInfo.index, creator)
 local item = df.item.find(item1)
 
 -- if the item type is a corpsepiece, we know we have one, and then go on to set the appropriate flags
 if itemm == "CORPSEPIECE" then
	 if layerName == "BONE" then -- check if bones
		item.corpse_flags.bone = true
		item.material_amount.Bone = 1
	 elseif layerName == "SKIN" then -- check if skin/leather
		item.corpse_flags.leather = true
		item.material_amount.Leather = 1
	 -- elseif layerName == "CARTILAGE" then -- check if cartilage (NO SPECIAL FLAGS)
	 elseif layerName == "HAIR" then -- check if hair (simplified from before)
		-- print("aaaaaahhhhh")
		-- print(materialInfo.material.flags.YARN)
		item.corpse_flags.hair_wool = true
		item.material_amount.HairWool = 1
		if materialInfo.material.flags.YARN then
			item.corpse_flags.yarn = true
			item.material_amount.Yarn = 1
		end
	 elseif layerName == "TOOTH" then -- check if tooth
		item.corpse_flags.tooth = true
		item.material_amount.Tooth = 1
	 elseif layerName == "NERVE" then -- check if nervous tissue
		item.corpse_flags.skull1 = true -- ?????????
		item.corpse_flags.separated_part = true
	 -- elseif layerName == "NAIL" then -- check if nail (NO SPECIAL FLAGS)
	 elseif layerName == "HORN" or layerName == "HOOF" then -- check if nail
		item.corpse_flags.horn = true
		item.material_amount.Horn = 1
		isCorpsePiece = true
	 end
	 -- checking for skull
	 if creator.body.body_plan.body_parts[bodpart].token == "SKULL" then
	  item.corpse_flags.skull2 = true
	 end
 end
 
 if itemm == "CORPSEPIECE" then
	 --referencing the source unit for, material, relation purposes???
	 item.race = creator.race
	 item.normal_race = creator.race
	 item.normal_caste = creator.caste
	 item.sex = creator.sex
	 item.unit_id = creator.id
	 -- on a dwarf tissue index 3 (bone) is 22, but this is not always the case for all creatures, so we get the mat_type of index 3 instead
	 -- here we also set the actual referenced creature material of the corpsepiece
	 item.bone1.mat_type = creator.body.body_plan.materials.mat_type[farlayer]
	 item.bone1.mat_index = creator.race
	 item.bone2.mat_type = creator.body.body_plan.materials.mat_type[farlayer]
	 item.bone2.mat_index = creator.race
	 
	 -- copy creator's body parts to item
	 item.body.components:assign(creator.body.components)
	 item.body.components.numbered_masks:assign(creator.body.components.numbered_masks)
	 
	 -- skin (and presumably other parts) use body part modifiers for size or amount
	 for i,n in pairs(creator.appearance.bp_modifiers) do
		-- inserts
		item.body.bp_modifiers:insert('#',n)
	 end
	 
	 -- copy creator's body relsizes to the bone's body relsizes thing
	 for i in pairs(creator.body.body_plan.body_parts) do
		-- inserts
		item.body.body_part_relsize:insert('#',creator.body.body_plan.body_parts[i].relsize)
	 end

	 -- iterates through every stored body part and marks them as missing
	 for i in pairs(item.body.components.body_part_status) do
		for n,w in pairs(item.body.components.body_part_status[i]) do
			item.body.components.body_part_status[i].missing = true
		end
	 end

	 
	 --iterates through every tissue layer and marks them as gone
	 for i in pairs(item.body.components.layer_status) do
		for n,w in pairs(item.body.components.layer_status[i]) do
			item.body.components.layer_status[i].gone = true
		end
	 end
	 
	 -- keeps the body part that the user selected to spawn the bone from
	 item.body.components.body_part_status[bodpart].missing = false
	 
	 -- restores the actual bone layer of the selected body part
	 item.body.components.layer_status[creator.body.body_plan.body_parts[bodpart].layers[patlayer].layer_id].gone = false
	 
	 -- DO THIS LAST or else the game crashes for some reason
	 item.caste = creator.caste
 end
 print("Spawned "..raceName.." "..layerName.." "..itemm..".")
end

if moduleMode then
 return
end

local args = utils.processArgs({...}, validArgs)

if args.help then
 print(usage)
 return
end


if args.creator == '\\LAST' then
  args.creator = tostring(df.global.unit_next_id-1)
end

if args.list then
 local creator = nil

 if creatorID ~= nil then
    creator = df.unit.find(creatorID)
 else
    creator = dfhack.gui.getSelectedUnit(true)
 end

 if creator == nil then
    qerror("Please select a unit to spawn from in the game UI")
 end
 
 for i in pairs(creator.body.body_plan.body_parts) do
    print(i..": "..creator.body.body_plan.body_parts[i].name_singular[0][0])
 end
 
 
 return
end

createItem(tonumber(args.creator), args.bodypart, args.layer)

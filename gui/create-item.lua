-- A gui-based item creation script.
-- author Putnam
-- edited by expwnent
--@module = true

local utils = require 'utils'

function getGenderString(gender)
  local sym = df.pronoun_type.attrs[gender].symbol
  if not sym then
    return ""
  end
  return "("..sym..")"
end

function getCreatureList()
 local crList={}
 for k,cr in ipairs(df.global.world.raws.creatures.alphabetic) do
  for kk,ca in ipairs(cr.caste) do
   local str=ca.caste_name[0]
   str=str..' '..getGenderString(ca.sex)
   table.insert(crList,{str,nil,ca})
  end
 end
 return crList
end

function getCreaturePartList(creatureID, casteID)
 local crpList={{"generic"}}
 for k,crp in ipairs(df.global.world.raws.creatures.all[creatureID].caste[casteID].body_info.body_parts) do
  local str = crp.name_singular[0][0]
  table.insert(crpList,{str})
 end
 return crpList
end

function getCreaturePartLayerList(creatureID, casteID, partID)
 local crplList={}
 for k,crpl in ipairs(df.global.world.raws.creatures.all[creatureID].caste[casteID].body_info.body_parts[partID].layers) do
  local str = crpl.layer_name
  table.insert(crplList,{str})
 end
 return crplList
end

function getCreatureMaterialList(creatureID, casteID)
 local crmList={}
 for k,crm in ipairs(df.global.world.raws.creatures.all[creatureID].material) do
  local str = crm.id
  table.insert(crmList,{str})
 end
 return crmList
end

function getRestrictiveMatFilter(itemType)
 if args.unrestricted then return nil end
 local itemTypes={
   WEAPON=function(mat,parent,typ,idx)
    return (mat.flags.ITEMS_WEAPON or mat.flags.ITEMS_WEAPON_RANGED)
   end,
   AMMO=function(mat,parent,typ,idx)
    return (mat.flags.ITEMS_AMMO)
   end,
   ARMOR=function(mat,parent,typ,idx)
    return (mat.flags.ITEMS_ARMOR)
   end,
   INSTRUMENT=function(mat,parent,typ,idx)
    return (mat.flags.ITEMS_HARD)
   end,
   AMULET=function(mat,parent,typ,idx)
    return (mat.flags.ITEMS_SOFT or mat.flags.ITEMS_HARD)
   end,
   ROCK=function(mat,parent,typ,idx)
    return (mat.flags.IS_STONE)
   end,
   BOULDER=ROCK,
   BAR=function(mat,parent,typ,idx)
    return (mat.flags.IS_METAL or mat.flags.SOAP or mat.id==COAL)
   end

  }
 for k,v in ipairs({'GOBLET','FLASK','TOY','RING','CROWN','SCEPTER','FIGURINE','TOOL'}) do
  itemTypes[v]=itemTypes.INSTRUMENT
 end
 for k,v in ipairs({'SHOES','SHIELD','HELM','GLOVES'}) do
    itemTypes[v]=itemTypes.ARMOR
 end
 for k,v in ipairs({'EARRING','BRACELET'}) do
    itemTypes[v]=itemTypes.AMULET
 end
 itemTypes.BOULDER=itemTypes.ROCK
 return itemTypes[df.item_type[itemType]]
end

function getMatFilter(itemtype)
  local itemTypes={
   SEEDS=function(mat,parent,typ,idx)
    return mat.flags.SEED_MAT
   end,
   PLANT=function(mat,parent,typ,idx)
    return mat.flags.STRUCTURAL_PLANT_MAT
   end,
   LEAVES=function(mat,parent,typ,idx)
    return mat.flags.LEAF_MAT
   end,
   MEAT=function(mat,parent,typ,idx)
    return mat.flags.MEAT
   end,
   CHEESE=function(mat,parent,typ,idx)
    return (mat.flags.CHEESE_PLANT or mat.flags.CHEESE_CREATURE)
   end,
   LIQUID_MISC=function(mat,parent,typ,idx)
    return (mat.flags.LIQUID_MISC_PLANT or mat.flags.LIQUID_MISC_CREATURE or mat.flags.LIQUID_MISC_OTHER)
   end,
   POWDER_MISC=function(mat,parent,typ,idx)
    return (mat.flags.POWDER_MISC_PLANT or mat.flags.POWDER_MISC_CREATURE)
   end,
   DRINK=function(mat,parent,typ,idx)
    return (mat.flags.ALCOHOL_PLANT or mat.flags.ALCOHOL_CREATURE)
   end,
   GLOB=function(mat,parent,typ,idx)
    return (mat.flags.STOCKPILE_GLOB)
   end,
   WOOD=function(mat,parent,typ,idx)
    return (mat.flags.WOOD)
   end,
   THREAD=function(mat,parent,typ,idx)
    return (mat.flags.THREAD_PLANT)
   end,
   LEATHER=function(mat,parent,typ,idx)
    return (mat.flags.LEATHER)
   end
  }
  return itemTypes[df.item_type[itemtype]] or getRestrictiveMatFilter(itemtype)
end

function createItem(mat,itemType,quality,creator,description,amount)
 local item=df.item.find(dfhack.items.createItem(itemType[1], itemType[2], mat[1], mat[2], creator))
 local item2=nil
 assert(item, 'failed to create item')
 quality = math.max(0, math.min(5, quality - 1))
 item:setQuality(quality)
 if df.item_type[itemType[1]]=='SLAB' then
  item.description=description
 end
 if df.item_type[itemType[1]]=='GLOVES' then
  --create matching gloves
  item:setGloveHandedness(1)
  item2=df.item.find(dfhack.items.createItem(itemType[1], itemType[2], mat[1], mat[2], creator))
  assert(item2, 'failed to create item')
  item2:setQuality(quality)
  item2:setGloveHandedness(2)
 end
 if df.item_type[itemType[1]]=='SHOES' then
  --create matching shoes
  item2=df.item.find(dfhack.items.createItem(itemType[1], itemType[2], mat[1], mat[2], creator))
  assert(item2, 'failed to create item')
  item2:setQuality(quality)
 end
 if tonumber(amount) > 1 then
  item:setStackSize(amount)
  if item2 then item2:setStackSize(amount) end
 end
end

function qualityTable()
 return {{'None'},
 {'-Well-crafted-'},
 {'+Finely-crafted+'},
 {'*Superior*'},
 {string.char(240)..'Exceptional'..string.char(240)},
 {string.char(15)..'Masterwork'..string.char(15)}
 }
end

local script=require('gui.script')

function showItemPrompt(text,item_filter,hide_none)
 require('gui.materials').ItemTypeDialog{
  prompt=text,
  item_filter=item_filter,
  hide_none=hide_none,
  on_select=script.mkresume(true),
  on_cancel=script.mkresume(false),
  on_close=script.qresume(nil)
 }:show()

 return script.wait()
end

function showMaterialPrompt(title, prompt, filter, inorganic, creature, plant) --the one included with DFHack doesn't have a filter or the inorganic, creature, plant things available
 require('gui.materials').MaterialDialog{
  frame_title = title,
  prompt = prompt,
  mat_filter = filter,
  use_inorganic = inorganic,
  use_creature = creature,
  use_plant = plant,
  on_select = script.mkresume(true),
  on_cancel = script.mkresume(false),
  on_close = script.qresume(nil)
 }:show()

 return script.wait()
end

function usesCreature(itemtype)
 typesThatUseCreatures={REMAINS=true,FISH=true,FISH_RAW=true,VERMIN=true,PET=true,EGG=true,CORPSE=true,CORPSEPIECE=true}
 return typesThatUseCreatures[df.item_type[itemtype]]
end

local function getCreatureRaceAndCaste(caste)
 return df.global.world.raws.creatures.list_creature[caste.index],df.global.world.raws.creatures.list_caste[caste.index]
end

local CORPSE_PIECES = utils.invert{'BONE', 'SKIN', 'CARTILAGE', 'TOOTH', 'NERVE', 'NAIL', 'HORN', 'HOOF' }
local HAIR_PIECES = utils.invert{'HAIR', 'EYEBROW', 'EYELASH', 'MOUSTACHE', 'CHIN_WHISKERS', 'SIDEBURNS' }

function createCorpsePiece(creator, bodypart, partlayer, creatureID, casteID, generic, quality) -- this part was written by four rabbits in a trenchcoat (ppaawwll)
 -- (partlayer is also used to determine the material if we're spawning a "generic" body part (i'm just lazy lol))
 quality = math.max(0, math.min(5, quality - 1))
 creatureID = tonumber(creatureID)
 -- get the actual raws of the target creature
 local creatorRaceRaw = df.creature_raw.find(creatureID)
 casteID = tonumber(casteID)
 bodypart = tonumber(bodypart)
 partlayer = tonumber(partlayer)
 -- get body info for easy reference
 local creatorBody = creatorRaceRaw.caste[casteID].body_info
 local layerName
 local layerMat
 local tissueID
 if not generic then -- if we have a specified body part and layer, figure all the stuff out about that
 -- store the tissue id of the specific layer we selected
  tissueID = tonumber(creatorBody.body_parts[bodypart].layers[partlayer].tissue_id)
  layerMat = {}
  -- get the material name from the material itself
  for i in string.gmatch(dfhack.matinfo.getToken(creatorRaceRaw.tissue[tissueID].mat_type,creatureID), "([^:]+)") do
   table.insert(layerMat,i)
  end
  layerMat = layerMat[3]
  layerName = creatorBody.body_parts[bodypart].layers[partlayer].layer_name
 else -- otherwise, figure out the mat name from the dual-use partlayer argument
  layerMat = creatorRaceRaw.material[partlayer].id
  layerName = layerMat
 end
 -- default is MEAT, so if anything else fails to change it to something else, we know that the body layer is a meat item
 local item_type = "MEAT"
 -- get race name and layer name, both for finding the item material, and the latter for determining the corpsepiece flags to set
 local raceName = string.upper(creatorRaceRaw.creature_id)
 -- every key is a valid non-hair corpsepiece, so if we try to index a key that's not on the table, we don't have a non-hair corpsepiece
 -- we do the same as above but with hair
 -- if the layer is fat, spawn a glob of fat and DON'T check for other layer types
 if layerName == "FAT" then
  item_type = "GLOB"
 elseif CORPSE_PIECES[layerName] or HAIR_PIECES[layerName] then -- check if hair
  item_type = "CORPSEPIECE"
 end
 local itemType = dfhack.items.findType(item_type..":NONE")
 local itemSubtype = dfhack.items.findSubtype(item_type..":NONE")
 local material = "CREATURE_MAT:"..raceName..":"..layerMat
 local materialInfo = dfhack.matinfo.find(material)
 local item_id = dfhack.items.createItem(itemType, itemSubtype, materialInfo['type'], materialInfo.index, creator)
 local item = df.item.find(item_id)
 item:setQuality(quality)
 local isCorpsePiece = false
 -- if the item type is a corpsepiece, we know we have one, and then go on to set the appropriate flags
 if item_type == "CORPSEPIECE" then
  if layerName == "BONE" then -- check if bones
   item.corpse_flags.bone = true
   item.material_amount.Bone = 1
  elseif layerName == "SKIN" then -- check if skin/leather
   item.corpse_flags.leather = true
   item.material_amount.Leather = 1
   -- elseif layerName == "CARTILAGE" then -- check if cartilage (NO SPECIAL FLAGS)
  elseif layerName == "HAIR" then -- check if hair (simplified from before)
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
   item.corpse_flags.skull1 = true -- apparently "skull1" is supposed to be named "rots/can_rot"
   item.corpse_flags.separated_part = true
   -- elseif layerName == "NAIL" then -- check if nail (NO SPECIAL FLAGS)
  elseif layerName == "HORN" or layerName == "HOOF" then -- check if nail
   item.corpse_flags.horn = true
   item.material_amount.Horn = 1
   isCorpsePiece = true
  end
  -- checking for skull
  if not generic and creatorBody.body_parts[bodypart].token == "SKULL" then
   item.corpse_flags.skull2 = true
  end
 end
 local matType
 -- figure out which material type the material is (probably a better way of doing this but whatever)
 for i in pairs(creatorRaceRaw.tissue) do
  if creatorRaceRaw.tissue[i].tissue_material_str[1] == layerMat then
   matType = creatorRaceRaw.tissue[i].mat_type
  end
 end
 if item_type == "CORPSEPIECE" then
  --referencing the source unit for, material, relation purposes???
  item.race = creatureID
  item.normal_race = creatureID
  item.normal_caste = casteID
  if casteID < 2 and #(creatorRaceRaw.caste) > 1 then -- usually the first two castes are for the creature's sex, so we set the item's sex to the caste if both the creature has one and it's a valid sex id (0 or 1)
   item.sex = casteID
  else
   item.sex = -1 -- it
  end
  -- on a dwarf tissue index 3 (bone) is 22, but this is not always the case for all creatures, so we get the mat_type of index 3 instead
  -- here we also set the actual referenced creature material of the corpsepiece
  item.bone1.mat_type = matType
  item.bone1.mat_index = creatureID
  item.bone2.mat_type = matType
  item.bone2.mat_index = creatureID
  -- skin (and presumably other parts) use body part modifiers for size or amount
  for i=0,200 do -- fuck it this works
   -- inserts
   item.body.bp_modifiers:insert('#',1) --jus,t, set a lot of it to one who cares
  end
  -- copy target creature's relsizes to the item's's body relsizes thing
  for i,n in pairs(creatorBody.body_parts) do
   -- inserts
   item.body.body_part_relsize:insert('#',n.relsize)
   item.body.components.body_part_status:insert(i,creator.body.components.body_part_status[0]) --copy the status of the creator's first part to every body_part_status of the desired creature
   item.body.components.body_part_status[i].missing = true
  end
  for i in pairs(creatorBody.layer_part) do
   -- inserts
   item.body.components.layer_status:insert(i,creator.body.components.layer_status[0]) --copy the layer status of the creator's first layer to every layer_status of the desired creature
   item.body.components.layer_status[i].gone = true
  end
  if not generic then
   -- keeps the body part that the user selected to spawn the item from
   item.body.components.body_part_status[bodypart].missing = false
   -- restores the selected layer of the selected body part
   item.body.components.layer_status[creatorBody.body_parts[bodypart].layers[partlayer].layer_id].gone = false
  elseif generic then
   for i in pairs(creatorBody.body_parts) do
     for n in pairs(creatorBody.body_parts[i].layers) do
      -- search through the target creature's body parts and bring back every one which has the desired material
      if creatorRaceRaw.tissue[creatorBody.body_parts[i].layers[n].tissue_id].tissue_material_str[1] == layerMat and creatorBody.body_parts[i].token ~= "SKULL" and not creatorBody.body_parts[i].flags.SMALL then
       item.body.components.body_part_status[i].missing = false
       item.body.components.body_part_status[i].grime = 2
       item.body.components.layer_status[creatorBody.body_parts[i].layers[n].layer_id].gone = false
       -- save the index of the bone layer to a variable
      end
     end
    end
  end
  -- DO THIS LAST or else the game crashes for some reason
  item.caste = casteID
 end
end

function hackWish(unit)
 script.start(function()
  local amountok, amount
  local matok,mattype,matindex,matFilter
  local itemok,itemtype,itemsubtype=showItemPrompt('What item do you want?',function(itype) return df.item_type[itype]~='CORPSE' and df.item_type[itype]~='FOOD' end ,true)
  local corpsepieceGeneric
  local bodypart
  if not itemok then return end
  if not args.notRestrictive then
   matFilter=getMatFilter(itemtype)
  end
  if not usesCreature(itemtype) then
   matok,mattype,matindex=showMaterialPrompt('Wish','And what material should it be made of?',matFilter)
   if not matok then return end
  else
   local creatureok,useless,creatureTable=script.showListPrompt('Wish','What creature should it be?',COLOR_LIGHTGREEN,getCreatureList())
   if not creatureok then return end
   mattype,matindex=getCreatureRaceAndCaste(creatureTable[3])
  end
  if df.item_type[itemtype]=='CORPSEPIECE' then
    local bodpartok,bodypartLocal=script.showListPrompt('Wish','What body part should it be?',COLOR_LIGHTGREEN,getCreaturePartList(mattype,matindex))
    -- createCorpsePiece() references the bodypart variable so it can't be local to here
    bodypart = bodypartLocal
    if bodypart == 1 then
     corpsepieceGeneric = true
    end
   if not bodpartok then return end
   if not corpsepieceGeneric then -- probably a better way of doing this tbh
    partlayerok,partlayerID=script.showListPrompt('Wish','What tissue layer should it be?',COLOR_LIGHTGREEN,getCreaturePartLayerList(mattype,matindex,bodypart-2))
   else
    partlayerok,partlayerID=script.showListPrompt('Wish','What creature material should it be?',COLOR_LIGHTGREEN,getCreatureMaterialList(mattype,matindex))
   end
    if not partlayerok then return end
  end
  local qualityok,quality=script.showListPrompt('Wish','What quality should it be?',COLOR_LIGHTGREEN,qualityTable())
  if not qualityok then return end
  local description
  if df.item_type[itemtype]=='SLAB' then
   local descriptionok
   descriptionok,description=script.showInputPrompt('Slab','What should the slab say?',COLOR_WHITE)
   if not descriptionok then return end
  end
  if args.multi then
   repeat amountok,amount=script.showInputPrompt('Wish','How many do you want? (numbers only!)',COLOR_LIGHTGREEN) until tonumber(amount) or not amountok
   if not amountok then return end
   if mattype and itemtype then
    if df.item_type.attrs[itemtype].is_stackable then
     createItem({mattype,matindex},{itemtype,itemsubtype},quality,unit,description,amount)
    else
     local isCorpsePiece = itemtype == df.item_type.CORPSEPIECE
     for i=1,amount do
      if not isCorpsePiece then
       createItem({mattype,matindex},{itemtype,itemsubtype},quality,unit,description,1)
      else
       createCorpsePiece(unit,bodypart-2,partlayerID-1,mattype,matindex,corpsepieceGeneric,quality)
      end
     end
    end
    return true
   end
   return false
  else
   if mattype and itemtype then
      if itemtype ~= df.item_type.CORPSEPIECE then
       createItem({mattype,matindex},{itemtype,itemsubtype},quality,unit,description,1)
      else
       createCorpsePiece(unit,bodypart-2,partlayerID-1,mattype,matindex,corpsepieceGeneric,quality)
      end
    return true
   end
   return false
  end
 end)
end

scriptArgs={...}

utils=require('utils')

validArgs = utils.invert({
 'startup',
 'unrestricted',
 'unit',
 'multi'
})

if moduleMode then
  return
end

args = utils.processArgs({...}, validArgs)

eventful=require('plugins.eventful')

if not args.startup then
 local unit=tonumber(args.unit) and df.unit.find(tonumber(args.unit)) or dfhack.gui.getSelectedUnit(true)
 if unit then
  hackWish(unit)
 else
  qerror('A unit needs to be selected to use gui/create-item.')
 end
else
 eventful.onReactionComplete.hackWishP=function(reaction,unit,input_items,input_reagents,output_items,call_native)
  if not reaction.code:find('DFHACK_WISH') then return nil end
  hackWish(unit)
 end
end

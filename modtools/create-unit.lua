-- Creates a unit.  Beta; use at own risk.

-- Originally created by warmist
-- Significant contributions over time by Boltgun, Dirst, Expwnent, lethosor, mifki, Putnam and Atomic Chicken.

--[[
  TODO
    confirm body size is computed appropriately for different ages / life stages
    incarnate pre-existing historical figures
    some sort of invasion helper script
      set invasion_id, etc
    announcement for fake natural birth if appropriate
    option to attach to an existing wild animal population
    option to attach to a map feature
]]

--@ module = true

local usage = [====[

modtools/create-unit
====================
Creates a unit.  Usage::

    -race raceName
        (obligatory)
        specify the race of the unit to be created
        examples:
            DWARF
            HUMAN

    -caste casteName
        specify the caste of the unit to be created
        if omitted, the caste is randomly selected
        examples:
            MALE
            FEMALE
            DEFAULT

    -domesticate
        tames the unit if it lacks the CAN_LEARN and CAN_SPEAK tokens

    -civId id
        Make the created unit a member of the specified civ
        (or none if id = -1).  If id is \\LOCAL, make it a member of the
        civ associated with the fort; otherwise id must be an integer

    -groupId id
        Make the created unit a member of the specified group
        (or none if id = -1).  If id is \\LOCAL, make it a member of the
        group associated with the fort; otherwise id must be an integer

    -setUnitToFort
        Sets the groupId and civId to the local fort
        Can be used instead of -civId \\LOCAL and -groupId \\LOCAL

    -name entityRawName
        Set the unit's name to be a random name appropriate for the
        given entity. \\LOCAL can be specified instead to automatically
        use the fort group entity in fortress mode only
        examples:
            MOUNTAIN
            EVIL

    -nick nickname
        set the unit's nickname directly

    -age howOld
        set the birth date of the unit by current age
        chosen randomly if this argument is omitted

    -duration ticks
        if this is included, the unit will vanish in a puff of smoke
        once the specified number of ticks has elapsed
        "ticks" must be an integer greater than 0

    -quantity howMany
        replace "howMany" with the number of creatures you want to create
        defaults to 1 if this argument is omitted

    -location [ x y z ]
        (obligatory)
        specify the coordinates where you want the unit to appear

    -locationRange [ x_offset y_offset z_offset ]
        if included, the unit will be spawned at a random location
        centred around the position specified in the -location argument
        z_offset defaults to 0 if omitted
        the location is randomised each time when creating multiple units
        example:
            -locationRange [ 4 3 1 ]
                attempts to place the unit anywhere within
                -4 to +4 tiles on the x-axis
                -3 to +3 tiles on the y-axis
                -1 to +1 tiles on the z-axis
                from the specified -location coordinates

    -locationType type
        may be used with -locationRange
        to specify what counts as a valid tile for unit spawning
        unit creation will not occur if no valid tiles are available
        replace "type" with one of the following:
            Walkable
                units will only be placed on walkable ground tiles
                this is the default used if -locationType is omitted
            Open
                open spaces are also valid spawn points
                this is intended for flying units
            Any
                all tiles, including solid walls, are valid
                this is only recommended for ghosts not carrying items

    -flagSet [ flag1 flag2 ... ]
        set the specified unit flags in the new unit to true
        flags may be selected from df.unit_flags1, df.unit_flags2,
        or df.unit_flags3

    -flagClear [ flag1 flag2 ... ]
        set the specified unit flags in the new unit to false
        flags may be selected from df.unit_flags1, df.unit_flags2,
        or df.unit_flags3

]====]

local utils = require 'utils'

function createUnit(raceStr, casteStr, pos, locationRange, locationType, age, domesticate, civ_id, group_id, entityRawName, nickname, vanishDelay, quantity, flagSet, flagClear)
--  creates the desired unit(s) at the specified location
--  returns a table containing the created unit(s)
  if not pos then
    qerror("Location not specified!") -- check repeated for module usage
  end
  if not dfhack.maps.isValidTilePos(pos) then
    qerror("Invalid location!")
  end
  if locationType and locationType ~= 'Walkable' and locationType ~= 'Open' and locationType ~= 'Any' then
    qerror('Invalid location type: ' .. locationType)
  end
  local locationChoices
  if locationRange then
    locationType = locationType or 'Walkable'
    locationChoices = getLocationChoices(pos, locationRange.offset_x, locationRange.offset_y, locationRange.offset_z)
  end

  if age then
    if not tonumber(age) or age < 0 then
      qerror('Invalid age: ' .. age)
    end
  end
  if vanishDelay then
    if not tonumber(vanishDelay) or tonumber(vanishDelay) < 1 then
      qerror('Invalid duration: ' .. vanishDelay)
    end
  end
  local spawnNumber = 1
  if quantity then
    spawnNumber = tonumber(quantity)
    if not spawnNumber or spawnNumber < 1 then
      qerror('Invalid spawn quantity: ' .. quantity)
    end
  end
  local race_id, caste_id, caste_id_choices = getRaceCasteIDs(raceStr, casteStr)
  return createUnitBase(race_id, caste_id, caste_id_choices, pos, locationChoices, locationType, age, domesticate, civ_id, group_id, entityRawName, nickname, vanishDelay, flagSet, flagClear, spawnNumber)
end

function createUnitBase(...)
  local old_gametype = df.global.gametype
  local old_mode = df.global.ui.main.mode
  local old_popups = {} --as:df.popup_message[]
  for _, popup in pairs(df.global.world.status.popups) do
    table.insert(old_popups, popup)
  end
  df.global.world.status.popups:resize(0) -- popups would prevent us from opening the creature creation menu, so remove them temporarily

  local ok, ret = dfhack.pcall(createUnitInner, ...)

  df.global.gametype = old_gametype
  df.global.ui.main.mode = old_mode
  for _, popup in pairs(old_popups) do
    df.global.world.status.popups:insert('#', popup)
  end

  if not ok then
    error(ret)
  end

  return ret
end

function createUnitInner(race_id, caste_id, caste_id_choices, pos, locationChoices, locationType, age, domesticate, civ_id, group_id, entityRawName, nickname, vanishDelay, flagSet, flagClear, spawnNumber)
  local gui = require 'gui'

  local view_x = df.global.window_x
  local view_y = df.global.window_y
  local view_z = df.global.window_z
  local cursor = copyall(df.global.cursor)

  local isArena = dfhack.world.isArena()
  local arenaSpawn = df.global.world.arena_spawn

  local oldSpawnType
  local oldSpawnFilter
  oldSpawnType = arenaSpawn.type
  arenaSpawn.type = 0 -- selects the creature at index 0 when the arena spawn screen is produced
  oldSpawnFilter = arenaSpawn.filter
  arenaSpawn.filter = "" -- clear filter to prevent it from messing with the selection

-- Clear arena spawn data to avoid interference:

  local oldInteractionEffect
  oldInteractionEffect = arenaSpawn.interaction
  arenaSpawn.interaction = -1
  local oldSpawnTame
  oldSpawnTame = arenaSpawn.tame
  arenaSpawn.tame = df.world.T_arena_spawn.T_tame.NotTame -- prevent interference by the tame/mountable setting (which isn't particularly useful as it only appears to set unit.flags1.tame)

  local equipment = arenaSpawn.equipment

  local old_item_types = {} --as:df.item_type[]
  for _, item_type in pairs(equipment.item_types) do
    table.insert(old_item_types, item_type)
  end
  equipment.item_types:resize(0)

  local old_item_subtypes = {} --as:number[]
  for _, item_subtype in pairs(equipment.item_subtypes) do
    table.insert(old_item_subtypes, item_subtype)
  end
  equipment.item_subtypes:resize(0)

  local old_item_mat_types = {} --as:number[]
  for _, item_mat_type in pairs(equipment.item_materials.mat_type) do
    table.insert(old_item_mat_types, item_mat_type)
  end
  equipment.item_materials.mat_type:resize(0)

  local old_item_mat_indexes = {} --as:number[]
  for _, item_mat_index in pairs(equipment.item_materials.mat_index) do
    table.insert(old_item_mat_indexes, item_mat_index)
  end
  equipment.item_materials.mat_index:resize(0)

  local old_item_counts = {} --as:number[]
  for _, item_count in pairs(equipment.item_counts) do
    table.insert(old_item_counts, item_count)
  end
  equipment.item_counts:resize(0)

  local old_skill_levels = {} --as:number[]
  for k, skill_level in ipairs(equipment.skill_levels) do
    table.insert(old_skill_levels, skill_level)
    equipment.skill_levels[k] = 0
  end

-- Spawn the creature:

  arenaSpawn.race:insert(0, race_id) -- place at index 0 to allow for straightforward selection as described above. The rest of the list need not be cleared.
  if caste_id then
    arenaSpawn.caste:insert(0, caste_id) -- if not specificied, caste_id is randomly selected and inserted during the spawn loop below, as otherwise creating multiple creatures simultaneously would result in them all being of the same caste.
  end
  arenaSpawn.creature_cnt:insert('#', 0)

  local curViewscreen = dfhack.gui.getCurViewscreen()
  local dwarfmodeScreen = df.viewscreen_dwarfmodest:new() -- the viewscreen present in arena "overseer" mode
  curViewscreen.child = dwarfmodeScreen
  dwarfmodeScreen.parent = curViewscreen
  df.global.ui.main.mode = df.ui_sidebar_mode.LookAround -- produce the cursor

  df.global.gametype = df.game_type.DWARF_ARENA

  if not locationChoices then -- otherwise randomise the cursor location for every unit spawned in the loop below
--  move cursor to location instead of moving unit later, corrects issue of missing mapdata when moving the created unit.
    df.global.cursor.x = tonumber(pos.x)
    df.global.cursor.y = tonumber(pos.y)
    df.global.cursor.z = tonumber(pos.z)
  end

  local createdUnits = {}
  for n = 1, spawnNumber do -- loop here to avoid having to handle spawn data each time when creating multiple units
    if not caste_id then -- choose a random caste ID each time
      arenaSpawn.caste:insert(0, caste_id_choices[math.random(1, #caste_id_choices)])
    end

    if locationChoices then
--    select a random spawn position within the specified location range, if available
      local randomPos
      for n = 1, #locationChoices do
        local i = math.random(1, #locationChoices)
        if locationType == 'Any' or isValidSpawnLocation(locationChoices[i], locationType) then
          randomPos = locationChoices[i]
          break
        else
          table.remove(locationChoices, i) -- remove invalid positions from the list to optimise subsequent spawning sequences
        end
      end
      if randomPos then
        df.global.cursor.x = tonumber(randomPos.x)
        df.global.cursor.y = tonumber(randomPos.y)
        df.global.cursor.z = tonumber(randomPos.z)
      else
        break -- no valid tiles available; terminate the spawn loop without creating any units
      end
    end

    gui.simulateInput(dwarfmodeScreen, 'D_LOOK_ARENA_CREATURE') -- open the arena spawning menu
    local spawnScreen = dfhack.gui.getCurViewscreen() -- df.viewscreen_layer_arena_creaturest
    gui.simulateInput(spawnScreen, 'SELECT') -- create the selected creature

    if not caste_id then
      arenaSpawn.caste:erase(0)
    end

--  Process the created unit:
    local unit = df.unit.find(df.global.unit_next_id-1)
    table.insert(createdUnits, unit)
    processNewUnit(unit, age, domesticate, civ_id, group_id, entityRawName, nickname, vanishDelay, flagSet, flagClear, isArena)
  end

  dfhack.screen.dismiss(dwarfmodeScreen)
  df.global.window_x = view_x -- view moves whilst spawning units, so restore it here
  df.global.window_y = view_y
  df.global.window_z = view_z
  df.global.cursor:assign(cursor) -- cursor sometimes persists in adventure mode, so ensure that it's reset

-- Restore arena spawn data:

  arenaSpawn.race:erase(0)
  if caste_id then
    arenaSpawn.caste:erase(0)
  end
  arenaSpawn.creature_cnt:erase(0)

  arenaSpawn.filter = oldSpawnFilter
  arenaSpawn.type = oldSpawnType
  arenaSpawn.interaction = oldInteractionEffect
  arenaSpawn.tame = oldSpawnTame

  for _,i in pairs(old_item_types) do
    equipment.item_types:insert('#',i)
  end
  for _,i in pairs(old_item_subtypes) do
    equipment.item_subtypes:insert('#',i)
  end
  for _,i in pairs(old_item_mat_types) do
    equipment.item_materials.mat_type:insert('#',i)
  end
  for _,i in pairs(old_item_mat_indexes) do
    equipment.item_materials.mat_index:insert('#',i)
  end
  for _,i in pairs(old_item_counts) do
    equipment.item_counts:insert('#',i)
  end
  for k,i in ipairs(old_skill_levels) do
    equipment.skill_levels[k-1] = i
  end

  return createdUnits -- table containing the created unit(s) (intended for module usage)
end

function getLocationChoices(pos, offset_x, offset_y, offset_z)
  local spawnCoords = {}
  local min_x = pos.x - offset_x
  local max_x = pos.x + offset_x
  local min_y = pos.y - offset_y
  local max_y = pos.y + offset_y
  local min_z = pos.z - offset_z
  local max_z = pos.z + offset_z
  local map = df.global.world.map
  local map_x = map.x_count-1 -- maximum local coordinates on the loaded map
  local map_y = map.y_count-1
  local map_z = map.z_count-1

  for x = min_x >= 0 and min_x or 0, max_x <= map_x and max_x or map_x do
    for y = min_y >= 0 and min_y or 0, max_y <= map_y and max_y or map_y do
      for z = min_z >= 0 and min_z or 0, max_z <= map_z and max_z or map_z do
        table.insert(spawnCoords,{x = x, y = y, z = z})
      end
    end
  end
  return spawnCoords
end

function isValidSpawnLocation(pos, locationType)
  if not dfhack.maps.isValidTilePos(pos) then
    return false
  end
  local tiletype = dfhack.maps.getTileBlock(pos.x, pos.y, pos.z).tiletype[pos.x%16][pos.y%16]
  local tileShapeAttrs = df.tiletype_shape.attrs[df.tiletype.attrs[tiletype].shape]
  if locationType == 'Open' then
    if tileShapeAttrs.basic_shape == df.tiletype_shape_basic.Open then
      return true
    end
    return false
  elseif locationType == 'Walkable' then
    if tileShapeAttrs.walkable and tileShapeAttrs.basic_shape ~= df.tiletype_shape_basic.Open then
      return true
    end
    return false
  end
end

function getRaceCasteIDs(raceStr, casteStr)
--  Takes a race name and a caste name and returns the appropriate race and caste IDs.
--  Returns a table of valid caste IDs if casteStr is omitted.
  if not raceStr then
    qerror("Race not specified!")
  end
  local race
  local raceIndex
  for i,c in ipairs(df.global.world.raws.creatures.all) do
    if c.creature_id == raceStr then
      race = c
      raceIndex = i
      break
    end
  end
  if not race then
    qerror('Invalid race: ' .. raceStr)
  end

  local casteIndex
  local caste_id_choices = {} --as:number[]
  if casteStr then
    for i,c in ipairs(race.caste) do
      if c.caste_id == casteStr then
        casteIndex = i
        break
      end
    end
    if not casteIndex then
      qerror('Invalid caste: ' .. casteStr)
    end
  else
    for i,c in ipairs(race.caste) do
      table.insert(caste_id_choices, i)
    end
  end

  return raceIndex, casteIndex, caste_id_choices
end

local function allocateNewChunk(hist_entity)
  hist_entity.save_file_id = df.global.unit_chunk_next_id
  df.global.unit_chunk_next_id = df.global.unit_chunk_next_id+1
  hist_entity.next_member_idx = 0
  print("allocating chunk:",hist_entity.save_file_id)
end

local function allocateIds(nemesis_record,hist_entity)
  if hist_entity.next_member_idx == 100 then
    allocateNewChunk(hist_entity)
  end
  nemesis_record.save_file_id = hist_entity.save_file_id
  nemesis_record.member_idx = hist_entity.next_member_idx
  hist_entity.next_member_idx = hist_entity.next_member_idx+1
end

function createFigure(unit,he,he_group)
  local hf = df.historical_figure:new()
  hf.id = df.global.hist_figure_next_id
  df.global.hist_figure_next_id = df.global.hist_figure_next_id+1

  hf.unit_id = unit.id
  hf.unit_id2 = -1
  hf.race = unit.race
  hf.caste = unit.caste
  hf.profession = unit.profession
  hf.sex = unit.sex
  hf.name:assign(unit.name)

  hf.appeared_year = df.global.cur_year
  hf.born_year = unit.birth_year
  hf.born_seconds = unit.birth_time
  hf.curse_year = unit.curse_year
  hf.curse_seconds = unit.curse_time
  hf.birth_year_bias = unit.birth_year_bias
  hf.birth_time_bias = unit.birth_time_bias
  hf.old_year = unit.old_year
  hf.old_seconds = unit.old_time
  hf.died_year = -1
  hf.died_seconds = -1

  hf.civ_id = unit.civ_id
  hf.population_id = unit.population_id
  hf.breed_id = -1
  hf.cultural_identity = unit.cultural_identity
  hf.family_head_id = -1

  df.global.world.history.figures:insert("#", hf)

  hf.info = df.historical_figure_info:new()
  hf.info.unk_14 = df.historical_figure_info.T_unk_14:new() -- hf state?
  --unk_14.region_id = -1; unk_14.beast_id = -1; unk_14.unk_14 = 0
  hf.info.unk_14.unk_18 = -1; hf.info.unk_14.unk_1c = -1
  -- set values that seem related to state and do event
  --change_state(hf, dfg.ui.site_id, region_pos)


  --let's skip skills for now
  --local skills = df.historical_figure_info.T_skills:new() -- skills snap shot
  -- ...
  -- note that innate skills are automaticaly set by DF
  hf.info.skills = {new=true}

  if he then
    he.histfig_ids:insert('#', hf.id)
    he.hist_figures:insert('#', hf)
    hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=unit.civ_id,link_strength=100})

    --add entity event
    local hf_event_id = df.global.hist_event_next_id
    df.global.hist_event_next_id = df.global.hist_event_next_id+1
    df.global.world.history.events:insert("#",{new=df.history_event_add_hf_entity_linkst,year=unit.birth_year,
    seconds=unit.birth_time,id=hf_event_id,civ=hf.civ_id,histfig=hf.id,link_type=0})
  end

  if he_group and he_group ~= he then
    he_group.histfig_ids:insert('#', hf.id)
    he_group.hist_figures:insert('#', hf)
    hf.entity_links:insert("#",{new=df.histfig_entity_link_memberst,entity_id=he_group.id,link_strength=100})
  end

  local soul = unit.status.current_soul
  if soul then
    hf.orientation_flags:assign(soul.orientation_flags)
  end

  unit.flags1.important_historical_figure = true
  unit.flags2.important_historical_figure = true
  unit.hist_figure_id = hf.id
  unit.hist_figure_id2 = hf.id

  return hf
end

function createNemesis(unit,civ_id,group_id)
  local id = df.global.nemesis_next_id
  local nem = df.nemesis_record:new()

  nem.id = id
  nem.unit_id = unit.id
  nem.unit = unit
  nem.flags:resize(31)
  nem.unk10 = -1
  nem.unk11 = -1
  nem.unk12 = -1
  df.global.world.nemesis.all:insert("#",nem)
  df.global.nemesis_next_id = id+1
  unit.general_refs:insert("#",{new = df.general_ref_is_nemesisst, nemesis_id = id})

  nem.save_file_id = -1

  local he
  if civ_id and civ_id ~= -1 then
    he = df.historical_entity.find(civ_id)
    he.nemesis_ids:insert("#",id)
    he.nemesis:insert("#",nem)
    allocateIds(nem,he)
  end
  local he_group
  if group_id and group_id ~= -1 then
    he_group = df.historical_entity.find(group_id)
  end
  if he_group then
    he_group.nemesis_ids:insert("#",id)
    he_group.nemesis:insert("#",nem)
  end
  nem.figure = unit.hist_figure_id ~= -1 and df.historical_figure.find(unit.hist_figure_id) or createFigure(unit,he,he_group) -- the histfig check is there just in case this function is called by another script to create nemesis data for a historical figure which somehow lacks it
  nem.figure.unit_id2 = id
  return nem
end

function nameUnit(unit, entityRawName)
  --pick a random appropriate name
  --choose three random words in the appropriate things
  local entity_raw
  if entityRawName then
    for k,v in ipairs(df.global.world.raws.entities) do
      if v.code == entityRawName then
        entity_raw = v
        break
      end
    end
  end

  if not entity_raw then
    qerror('Invalid entity raw name: ' .. entityRawName)
  end

  local translation = entity_raw.translation
  local translationIndex
  for k,v in ipairs(df.global.world.raws.language.translations) do
    if v.name == translation then
      translationIndex = k
      break
    end
  end

  local language_word_table = entity_raw.symbols.symbols1[0] --educated guess
  function randomWord()
    local index = math.random(0, #language_word_table.words[0] - 1)
    return index
  end
  local firstName = randomWord()
  local lastName1 = randomWord()
  local lastName2 = randomWord()
  local name = unit.name
  name.words[0] = language_word_table.words[0][lastName1]
  name.parts_of_speech[0] = language_word_table.parts[0][lastName1]
  name.words[1] = language_word_table.words[0][lastName2]
  name.parts_of_speech[1] = language_word_table.parts[0][lastName2]
  local language = nil
  for _, lang in pairs(df.global.world.raws.language.translations) do
    if lang.name == entity_raw.translation then
      language = lang
    end
  end
  if language then
    name.first_name = language.words[firstName].value
  else
    name.first_name = df.language_word.find(language_word_table.words[0][firstName]).forms[language_word_table.parts[0][firstName]]
  end
  name.has_name = true
  name.language = translationIndex
  if unit.status.current_soul then
    unit.status.current_soul.name:assign(name)
  end
  local hf = df.historical_figure.find(unit.hist_figure_id)
  if hf then
    hf.name:assign(name)
  end
end

function processNewUnit(unit, age, domesticate, civ_id, group_id, entityRawName, nickname, vanishDelay, flagSet, flagClear, isArena) -- isArena boolean is used for determining whether or not the arena name should be cleared
  if entityRawName and type(entityRawName) == 'string' then
    nameUnit(unit, entityRawName)
  elseif not isArena then -- arena mode ONLY displays the first_name of units; removing it would result in a blank space where you'd otherwise expect the caste name to show up
    unit.name.first_name = '' -- removes the string of numbers produced by the arena spawning process
    unit.name.has_name = false
    if unit.status.current_soul then
      unit.status.current_soul.name.has_name = false
    end
  end

  if nickname and type(nickname) == 'string' then
    dfhack.units.setNickname(unit, nickname)
  end

  if tonumber(civ_id) then
    unit.civ_id = civ_id
  end
  createNemesis(unit, tonumber(civ_id), tonumber(group_id))

  setAge(unit, age) -- run regardless of whether or not age has been specified so as to set baby/child status
  induceBodyComputations(unit)

  if domesticate then
    domesticateUnit(unit)
  elseif not civ_id then
    wildUnit(unit)
  end
  if vanishDelay then
    setVanishCountdown(unit, vanishDelay)
  end
  enableDefaultLabors(unit)
  handleUnitFlags(unit,flagSet,flagClear)
end

function setAge(unit, age)
--  Shifts the unit's birth and death dates to match the specified age.
--  Also checks for [BABY] and [CHILD] tokens and turns the unit into a baby/child if age-appropriate.

  local hf = df.historical_figure.find(unit.hist_figure_id)

  if age then
    if not tonumber(age) or age < 0 then -- this check is repeated for the sake of module usage
      qerror("Invalid age: " .. age)
    end

--  Change birth and death dates:
    if age == 0 then
      unit.birth_time = df.global.cur_year_tick
    end
    local oldYearDelta = unit.old_year - unit.birth_year -- the unit's natural lifespan
    unit.birth_year = df.global.cur_year - age
    if unit.old_year ~= -1 then
      unit.old_year = unit.birth_year + oldYearDelta
    end
    if hf then
      hf.born_year = unit.birth_year
      hf.born_seconds = unit.birth_time
      hf.old_year = unit.old_year
      hf.old_seconds = unit.old_time
    end
  end

-- Turn into a child or baby if appropriate:
  local getAge = age or dfhack.units.getAge(unit,true)
  local cr = df.creature_raw.find(unit.race).caste[unit.caste]
  if cr.flags.HAS_BABYSTATE and (getAge < cr.misc.baby_age) then
    unit.profession = df.profession.BABY
    --unit.profession2 = df.profession.BABY
    unit.mood = df.mood_type.Baby
  elseif cr.flags.HAS_CHILDSTATE and (getAge < cr.misc.child_age) then
    unit.profession = df.profession.CHILD
    --unit.profession2 = df.profession.CHILD
  end
  if hf then
    hf.profession = unit.profession
  end
end

function induceBodyComputations(unit)
--these flags are an educated guess of how to get the game to compute sizes correctly: use -flagSet and -flagClear arguments to override or supplement
  unit.flags2.calculated_nerves = false
  unit.flags2.calculated_bodyparts = false
  unit.flags3.body_part_relsize_computed = false
  unit.flags3.size_modifier_computed = false
  unit.flags3.weight_computed = false
end

function domesticateUnit(unit)
  -- If a friendly animal, make it domesticated.  From Boltgun & Dirst
  local casteFlags = unit.enemy.caste_flags
  if not(casteFlags.CAN_SPEAK and casteFlags.CAN_LEARN) then
    -- Fix friendly animals (from Boltgun)
    unit.flags2.resident = false
    unit.population_id = -1
    unit.animal.population.region_x = -1
    unit.animal.population.region_y = -1
    unit.animal.population.unk_28 = -1
    unit.animal.population.population_idx = -1
    unit.animal.population.depth = -1

    -- And make them tame (from Dirst)
    unit.flags1.tame = true
    unit.training_level = df.animal_training_level.Domesticated
  end
end

function wildUnit(unit)
  local casteFlags = unit.enemy.caste_flags
  -- x = df.global.world.world_data.active_site[0].pos.x
  -- y = df.global.world.world_data.active_site[0].pos.y
  -- region = df.global.map.map_blocks[df.global.map.x_count_block*x+y]
  if not(casteFlags.CAN_SPEAK and casteFlags.CAN_LEARN) then
    if #df.global.world.world_data.active_site > 0 then -- empty in adventure mode
      unit.animal.population.region_x = df.global.world.world_data.active_site[0].pos.x
      unit.animal.population.region_y = df.global.world.world_data.active_site[0].pos.y
    end
    unit.animal.population.unk_28 = -1
    unit.animal.population.population_idx = -1  -- Eventually want to make a real population
    unit.animal.population.depth = -1  -- Eventually this should be a parameter
    unit.animal.leave_countdown = 99999  -- Eventually this should be a parameter
    unit.flags2.roaming_wilderness_population_source = true
    unit.flags2.roaming_wilderness_population_source_not_a_map_feature = true
    -- region = df.global.world.map.map_blocks[df.global.world.map.x_count_block*x+y]
  end
end

function enableDefaultLabors(unit)
  if unit.profession == df.profession.BABY or unit.profession == df.profession.CHILD then
    return
  end
  if unit.enemy.caste_flags.CAN_LEARN then
    local labors = unit.status.labors
    labors.HAUL_STONE = true
    labors.HAUL_WOOD = true
    labors.HAUL_BODY = true
    labors.HAUL_FOOD = true
    labors.HAUL_REFUSE = true
    labors.HAUL_ITEM = true
    labors.HAUL_FURNITURE = true
    labors.HAUL_ANIMALS = true
    labors.CLEAN = true
    labors.FEED_WATER_CIVILIANS = true
    labors.RECOVER_WOUNDED = true
    labors.HANDLE_VEHICLES = true
    labors.HAUL_TRADE = true
    labors.PULL_LEVER = true
    labors.REMOVE_CONSTRUCTION = true
    labors.HAUL_WATER = true
    labors.BUILD_ROAD = true
    labors.BUILD_CONSTRUCTION = true
  end
end

function setVanishCountdown(unit, ticks)
  if not tonumber(ticks) or tonumber(ticks) < 1 then
    qerror('Invalid vanish delay: ' .. ticks)
  end
  unit.animal.vanish_countdown = ticks
end

function handleUnitFlags(unit,flagSet,flagClear)
  if flagSet or flagClear then
    local flagsToSet = {}
    local flagsToClear = {}
    for _,v in ipairs(flagSet or {}) do
      flagsToSet[v] = true
    end
    for _,v in ipairs(flagClear or {}) do
      flagsToClear[v] = true
    end
    for _,k in ipairs(df.unit_flags1) do
      if flagsToSet[k] then
        unit.flags1[k] = true
      elseif flagsToClear[k] then
        unit.flags1[k] = false
      end
    end
    for _,k in ipairs(df.unit_flags2) do
      if flagsToSet[k] then
        unit.flags2[k] = true
      elseif flagsToClear[k] then
        unit.flags2[k] = false
      end
    end
    for _,k in ipairs(df.unit_flags3) do
      if flagsToSet[k] then
        unit.flags3[k] = true
      elseif flagsToClear[k] then
        unit.flags3[k] = false
      end
    end
  end
end

validArgs = utils.invert({
  'help',
  'race',
  'caste',
  'domesticate',
  'civId',
  'groupId',
  'flagSet',
  'flagClear',
  'name',
  'nick',
  'location',
  'age',
  'setUnitToFort', -- added by amostubal to get past an issue with \\LOCAL
  'quantity',
  'duration',
  'locationRange',
  'locationType'
})

if moduleMode then
  return
end

local args = utils.processArgs({...}, validArgs)

if args.help then
  print(usage)
  return
end

if not args.race then
  qerror('Specify a race for the new unit.')
end

if not args.location then
  qerror('Location not specified!')
end
local pos = {x = tonumber(args.location[1]), y = tonumber(args.location[2]), z = tonumber(args.location[3])}

if args.locationType and not args.locationRange then
  qerror("-locationType cannot be used without -locationRange!")
end

local locationRange
if args.locationRange then
  locationRange = {offset_x = math.abs(tonumber(args.locationRange[1])), offset_y = math.abs(tonumber(args.locationRange[2])), offset_z = args.locationRange[3] and math.abs(tonumber(args.locationRange[3])) or 0} -- allow offset_z to be omitted
end

local isFortressMode = dfhack.world.isFortressMode()

local civ_id
if args.setUnitToFort or args.civId == '\\LOCAL' then
  if not isFortressMode then
    qerror("The LOCAL civ cannot be specified outside of Fortress mode!")
  end
  civ_id = df.global.ui.civ_id
elseif args.civId and tonumber(args.civId) then
  civ_id = tonumber(args.civId)
end

local group_id
if args.setUnitToFort or args.groupId == '\\LOCAL' then
  if not isFortressMode then
    qerror("The LOCAL group cannot be specified outside of Fortress mode!")
  end
  group_id = df.global.ui.group_id
elseif args.groupId and tonumber(args.groupId) then
  group_id = tonumber(args.groupId)
end

local entityRawName
if args.name then
  entityRawName = tostring(args.name)
  if entityRawName == '\\LOCAL' then
    if not isFortressMode then
      qerror("The LOCAL entityRawName cannot be specified outside of Fortress mode!")
    else
      entityRawName = df.historical_entity.find(df.global.ui.group_id).entity_raw.code
    end
  end
end

createUnit(args.race, args.caste, pos, locationRange, args.locationType, tonumber(args.age), args.domesticate, tonumber(civ_id), tonumber(group_id), entityRawName, args.nick, tonumber(args.duration), tonumber(args.quantity), args.flagSet, args.flagClear)

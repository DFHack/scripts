-- Tool to allow dynamically enabling / disabling adventure mode reactions based on circumstances
--@ module = true

--[[ HOW IT WORKS:
Commands / scripts register a set of conditional checks associated with a reaction (the set of conditions is referred to a "condition blob").
When the player opens up the actions menu in game (the menu where they can perform reactions), the script checks if they satisfy one of the condition blobs associated with that reaction (that is, they satisfy every condition in any of the registered blobs for that reaction).
If they don't satisfy all the conditions for any of the condition blobs, the reaction is removed from their list of reactions.
]]

--[[ TODO / WISHLIST:
- Time: Available within certain hourly bounds, allowing for day/night requirements.
- Season. Available during a particular season.
- Weather. Available during certain weathers.
]]

local help = [====[

modtools/dynamic-adv-reactions
==============================
Tool to allow dynamically enabling / disabling adventure mode reactions based on certain conditions.
When a reaction is registered with this script, its usage by adventurers will be disabled by default. Each usage of this command creates its own set of conditions to check, and the reaction will be enabled for the player if they satisfy all the criteria of one of those sets of conditions.
Registered reactions are cleared when the world is unloaded, and so it is best to include any commands for this within an ``onLoad*.init`` file.
Checks with multiple instances of the same type of condition are possible if registered via code rather than with commands.

* ``-reaction reactionCode``
  (Required)
  Specify the reaction the conditions will allow.
  Examples::

    MAKE_SHARP_ROCK
    "ASSEMBLE STONE AXE"

Conditions:
Most conditions can optionally be a table of conditions, rather than a single argument. That condition is satisfied if any of them are met.

* ``-creature token``
  Require the adventurer to be the specified creature.
  Can optionally be a table of arguments.
  Example: DWARF

* ``-caste token``
  Require the adventurer to be the specified caste.
  Can optionally be a table of arguments.
  Examples::

    FEMALE
    DRONE

* ``-creatureCaste tokens``
  Require the adventurer to be the specified creature + caste combination.
  Can optionally be a table of arguments.
  Example: DWARF:MALE

* ``-creatureClass class``
  Require the adventurer to be a creature with the specified creature class.
  Can optionally be a table of arguments.
  Examples::

    GENERAL_POISON
    MAMMAL

* ``-sphere sphere``
  Require the adventurer to be a creature with the specified sphere.
  Can optionally be a table of arguments.
  Examples::

    METALS
    MUCK

* ``-syndrome name``
  Require the adventurer to be under the effects of the specified syndrome.
  Can optionally be a table of arguments.
  Examples::

    "giant cave spider bite"
    "night sickness"

* ``-syndromeClass class``
  Require the adventurer to be under the effects of a syndrome with the specified SYN_CLASS.
  Can optionally be a table of arguments.
  Example: RAISED_UNDEAD

* ``-syndromeIdentifier identifier``
  Require the adventurer to be under the effects of a syndrome with the specified SYN_IDENTIFIER.
  Can optionally be a table of arguments.
  Example: INEBRIATION

* ``-secret id``
  Require the adventurer to know the specified secret.
  Can optionally be a table of arguments.
  Since game-generated secrets have unique names, this is more likely for use with mod-made secrets, which keep the same ids between worlds.

* ``-item token``
  Require the adventurer to be holding the specified item in their hands.
  Can optionally be a table of arguments.
  Examples::

    WEAPON:ITEM_WEAPON_PICK
    BUCKET:NONE

* ``-itemType token``
  Require the adventurer to be holding the an item of the specified item type in their hands.
  Can optionally be a table of arguments.
  Examples::

    WEAPON
    COIN
    BOX

* ``-moon [ startPhase endPhase ]``
  Require the moon to be within a set bound of phases.
  See the wiki entry for what numbers correspond to which phases: https://dwarffortresswiki.org/index.php/DF2014:Syndrome#MOON_PHASE

Example Usage:

* Restrict stone axe making to only drunken elves::

    modtools/dynamic-adv-reactions -reaction "ASSEMBLE STONE AXE" -creature ELF -syndromeIdentifier INEBRIATION

* Only allow beings related to an appropriate sphere to sharpen rocks::

    modtools/dynamic-adv-reactions -reaction MAKE_SHARP_ROCK -sphere [ EARTH MINERALS METALS ]

]====]

local utils = require "utils"
local gui = require("gui")

local validArgs = utils.invert({
  "help",
  "reaction",
  "creature",
  "caste",
  "creatureCaste",
  "creatureClass",
  "sphere",
  "syndrome",
  "syndromeClass",
  "syndromeIdentifier",
  "secret",
  "item",
  "itemType",
  "moon",
})
---------------------------------------------------------------------
registered_reactions = registered_reactions or {} -- Table containing each reaction that's been registered with this script. The reaction codes are used as keys, storing an indexed table of each condition blob that's been added for that reaction.
hack_insert = hack_insert or 0
---------------------------------------------------------------------
-- REGISTRATION AND CONDITION CREATION
-- If the condition includes a key of `unit`, the current adventurer will be passed to the check function.
-- You can technically add your own condition checks to your registered reactions, so long as you follow the formatting.

-- Use to register an adventurer reaction to be handled by this script
-- For scripts using this: The function returns the newly added condition blob. Use `make_condition_*`  and the `add_condition` functions to add conditions to it.
function register_reaction(reaction_token)
  if registered_reactions[reaction_token] == nil then
    registered_reactions[reaction_token] = {}
  end

  local condition_blob = {}
  table.insert(registered_reactions[reaction_token], condition_blob)

  return condition_blob
end

-- Adds a condition to the given registered entry
function add_condition(condition_blob, condition)
  table.insert(condition_blob, condition)
end

-- For checking if the current adventurer is any of the given races (e.g. DWARF)
function make_condition_creature(creature_tokens)
  return {
    id = "creature",
    check_function = check_creature,
    unit = true,
    creature_tokens = creature_tokens,
  }
end

-- For checking if the current adventurer is any of the given castes (e.g. FEMALE, DRONE)
function make_condition_caste(caste_tokens)
  return {
    id = "caste",
    check_function = check_caste,
    unit = true,
    caste_tokens = caste_tokens,
  }
end

-- For checking if the current adventurer is any of the given race + caste combinations (e.g. HUMAN:MALE)
function make_condition_creature_caste(creature_castes)
  return {
    id = "creature_caste",
    check_function = check_creature_caste,
    unit = true,
    creature_castes = creature_castes,
  }
end

-- For checking if the current adventurer is any of the given creature classes (e.g. GENERAL_POISON)
function make_condition_creature_class(creature_classes)
  return {
    id = "creature_class",
    check_function = check_creature_class,
    unit = true,
    creature_classes = creature_classes,
  }
end

-- For checking if the current adventurer's race is associated with any spheres (e.g. MUCK)
function make_condition_sphere(spheres)
  return {
    id = "sphere",
    check_function = check_sphere,
    unit = true,
    spheres = spheres,
  }
end

-- For checking if the current adventurer is affected by any syndromes with the provided syndrome names (e.g. night sickness, giant cave spider bite)
function make_condition_syndrome_name(syndrome_names)
  return {
    id = "syndrome_name",
    check_function = check_syndrome_name,
    unit = true,
    syndrome_names = syndrome_names,
  }
end

-- For checking if the current adventurer is affected by any syndromes with the provided syndrome classes (e.g. RAISED_UNDEAD)
function make_condition_syndrome_class(syndrome_classes)
  return {
    id = "syndrome_class",
    check_function = check_syndrome_class,
    unit = true,
    syndrome_classes = syndrome_classes,
  }
end

-- For checking if the current adventurer is affected by any syndromes with the provided syndrome identifiers (e.g. INEBRIATION)
function make_condition_syndrome_identifier(syndrome_identifiers)
  return {
    id = "syndrome_identifier",
    check_function = check_syndrome_identifier,
    unit = true,
    syndrome_identifiers = syndrome_identifiers,
  }
end


-- For checking if the current adventurer knows any of the given secrets. Because the ids of game-generated secrets vary, you'd likely use this for mod-created secrets, or after looking up the ids of a world's generated secrets.
function make_condition_secret(secrets)
  return {
    id = "secret",
    check_function = check_secret,
    unit = true,
    secrets = secrets,
  }
end

-- For checking if the current adventurer is holding any of the provided items in their hands (e.g. WEAPON:ITEM_WEAPON_PICK, TOY:ITEM_TOY_AXE, BUCKET:NONE)
function make_condition_item(item_tokens)
  return {
    id = "holding_item",
    check_function = check_holding_item,
    unit = true,
    item_tokens = item_tokens,
  }
end

-- For checking if the current adventurer is holding any items of the provided item type in their hands (e.g. WEAPON, TOY, BOX)
function make_condition_item_type(item_types)
  return {
    id = "holding_item_type",
    check_function = check_holding_item_type,
    unit = true,
    item_types = item_types,
  }
end

-- For checking if the world is in the given range of moon phases. The values should be numerical - a list of which can be found here https://dwarffortresswiki.org/index.php/DF2014:Syndrome#MOON_PHASE
function make_condition_moon_phase(start_value, end_value)
  return {
    id = "moon_phase",
    check_function = check_moon_phase,
    start_value = start_value,
    end_value = end_value,
  }
end

---------------------------------------------------------------------
-- CONDTION CHECKING

-- Runs the given condition's check, feeding in the instance's given arguments to the checking function
-- Use this function to check a condition from a condition blob
function check_condition(condition_instance)
  local result

  if condition_instance.unit == true then
    -- If the condition requires a unit, automatically feed the current adventurer unit in as the first arg
    result = condition_instance.check_function(get_adventurer_unit(), condition_instance)
  else
    result = condition_instance.check_function(condition_instance)
  end

  return result
end

-- Run the checks for all conditions in a condition blob
-- If all of the checks are passed, returns true.
function check_condition_blob(condition_blob)
  for _, condition_instance in pairs(condition_blob) do
    if check_condition(condition_instance) == false then
      return false
    end
  end

  -- If we got here, all the checks passed!
  return true
end

function check_creature(unit, args)
  return unit_is_race(unit, args.creature_tokens)
end

function check_caste(unit, args)
  return unit_is_caste(unit, args.caste_tokens)
end

function check_creature_caste(unit, args)
  return unit_is_creature_caste(unit, args.creature_castes)
end

function check_creature_class(unit, args)
  return unit_is_creature_class(unit, args.creature_classes)
end

function check_secret(unit, args)
  return unit_knows_secret(unit, args.secrets)
end

function check_moon_phase(args)
  return is_moon_phase(args.start_value, args.end_value)
end

function check_sphere(unit, args)
  return unit_has_sphere(unit, args.spheres)
end

function check_syndrome_class(unit, args)
  return unit_has_syndrome_class(unit, args.syndrome_classes)
end

function check_syndrome_identifier(unit, args)
  return unit_has_syndrome_identifier(unit, args.syndrome_identifiers)
end

function check_syndrome_name(unit, args)
  return unit_has_syndrome_name(unit, args.syndrome_names)
end

function check_holding_item(unit, args)
  return unit_is_holding_item(unit, args.item_tokens)
end

function check_holding_item_type(unit, args)
  return unit_is_holding_item_type(unit, args.item_types)
end

---------------------------------------------------------------------
-- CHECK HELPER FUNCTIONS
-- Returns the currently active adventurer
function get_adventurer_unit()
  local nemesis = df.nemesis_record.find(df.global.ui_advmode.player_id)
  local unit = df.unit.find(nemesis.unit_id)

  return unit
end

-- Technically there's already a record for what an adventurer is holding in the action menu data (`held_items`), but testing this way means I can re-use this function in slightly more situations :p
-- Returns true if the unit is holding a particular given item (e.g. "WEAPON:ITEM_WEAPON_SWORD_SHORT", "BED:NONE", "TOY:ITEM_TOY_AXE")
-- Optionally, item_token can be an indexed table of item tokens to check. Returns true if any match.
function unit_is_holding_item(unit, item_token)
  local tokens_table

  if type(item_token) == "table" then
    tokens_table = item_token
  else
    tokens_table = {}
    table.insert(tokens_table, item_token)
  end

  for _, inventory_entry in pairs(unit.inventory) do
    -- Adventure mode crafting only cares about held items (equip type Weapon), not hauled items
    if inventory_entry.mode == df.unit_inventory_item.T_mode.Weapon then
      local item = (inventory_entry.item)
      -- Get the subtype of the item for checks later
      local item_subtype_token

      if item:getSubtype() == -1 then
        -- This sort of item doesn't have a subtype
        item_subtype_token = "NONE"
      else
        -- Lookup the item's subtype definition to get its text token
        local subtype_def = dfhack.items.getSubtypeDef(item:getType() ,item:getSubtype())
        item_subtype_token = subtype_def.id
      end

      for _, token_to_check in pairs(tokens_table) do
        local desired_type_token, desired_subtype_token = string.match(token_to_check, "([^:]+):([^:]+)")

        -- Check that the current inventory item's item type matches the current desired item's one
        -- Then also checking if it matches the current desired item's subtype (but skip the check if the item doesn't have a subtype)
        if get_item_type_token(item) == desired_type_token and (item_subtype_token == "NONE" or item_subtype_token == desired_subtype_token) then
          return true
        end
      end
    end
  end

  return false
end

-- Returns true if the unit is holding an item of the given item type (e.g. "BOX", "BED", "WEAPON")
-- Optionally, item_type_token can be an indexed table of item type tokens to check. Returns true if any match.
function unit_is_holding_item_type(unit, item_type_token)
  local tokens_table

  if type(item_type_token) == "table" then
    tokens_table = item_type_token
  else
    tokens_table = {}
    table.insert(tokens_table, item_type_token)
  end

  for _, inventory_entry in pairs(unit.inventory) do
    -- Adventure mode crafting only cares about held items (equip type Weapon), not hauled items
    if inventory_entry.mode == df.unit_inventory_item.T_mode.Weapon then
      for _, item_type_token in pairs(tokens_table) do
        if item_type_token == get_item_type_token(inventory_entry.item) then
          return true
        end
      end
    end
  end

  return false
end

-- Returns a string of the item's type (e.g. "BOX", "BED", "WEAPON")
function get_item_type_token(item)
  return df.item_type[item:getType()]
end

-- Returns true if a unit knows the given secret
-- Optionally, secret can be an indexed table of secrets to check. Returns true if any match.
function unit_knows_secret(unit, secret_token)
  if unit.hist_figure_id == -1 then
    return false
  end

  local histfig = df.historical_figure.find(unit.hist_figure_id)

  if histfig.info.known_info.known_secrets == nil then
    return false
  end

  local secrets_table

  if type(secret_token) == "table" then
    secrets_table = secret_token
  else
    secrets_table = {}
    table.insert(secrets_table, secret_token)
  end

  for _, interaction in pairs(histfig.info.known_info.known_secrets) do
    for _, secret_token in pairs(secrets_table) do
      if interaction.name == secret_token then
        return true
      end
    end
  end

  return false
end

-- Returns true if the unit has the given sphere
-- Optionally, creature_class can be an indexed table of creature classes to check. Returns true if any match.
function creature_has_sphere(creature, sphere)
  local sphere_table

  if type(sphere) == "table" then
    sphere_table = sphere
  else
    sphere_table = {}
    table.insert(sphere_table, sphere)
  end

  for index, sphere_id in pairs(creature.sphere) do

    local current_sphere = df.sphere_type[sphere_id]

    for _, desired_sphere in pairs(sphere_table) do
      if desired_sphere == current_sphere then
        return true
      end
    end
  end

  return false
end

-- Wrapper for creature_has_sphere to use on units
function unit_has_sphere(unit, sphere)
  local sphere_table

  if type(sphere) == "table" then
    sphere_table = sphere
  else
    sphere_table = {}
    table.insert(sphere_table, sphere)
  end

  local creature_raw = df.creature_raw.find(unit.race)
  return creature_has_sphere(creature_raw, sphere_table)
end

-- Returns true if the unit is the given race
-- Optionally, creature_token can be an indexed table of creature tokens to check. Returns true if any match.
function unit_is_race(unit, creature_token)
  local token_table

  if type(creature_token) == "table" then
    token_table = creature_token
  else
    token_table = {}
    table.insert(token_table, creature_token)
  end

  local creature_raw = df.creature_raw.find(unit.race)

  for _, token in pairs(token_table) do
    if creature_raw.creature_id == token then
      return true
    end
  end

  -- If we get here, we didn't find it
  return false
end

-- Returns true if the unit has the given caste token (e.g. "FEMALE", "DRONE")
-- Optionally, caste_token can be an indexed table of caste tokens to check. Returns true if any match.
function unit_is_caste(unit, caste_token)
  local token_table

  if type(caste_token) == "table" then
    token_table = caste_token
  else
    token_table = {}
    table.insert(token_table, caste_token)
  end

  local creature_raw = df.creature_raw.find(unit.race)
  local caste_raw = creature_raw.caste[unit.caste]

  for _, token in pairs(token_table) do
    if caste_raw.caste_id == token then
      return true
    end
  end

  -- If we get here, we didn't find it
  return false
end

-- Returns true if the unit is the given creature + class combination (e.g. "DWARF:FEMALE")
-- Optionally, token can be an indexed table of tokens to check. Returns true if any match.
function unit_is_creature_caste(unit, token)
  local token_table

  if type(token) == "table" then
    token_table = token
  else
    token_table = {}
    table.insert(token_table, token)
  end

  local creature_raw = df.creature_raw.find(unit.race)

  local unit_race_token = creature_raw.creature_id
  local unit_caste_token = creature_raw.caste[unit.caste].caste_id

  for _, token in pairs(token_table) do
    local current_race_token, current_caste_token = string.match(token, "([^:]+):([^:]+)")

    if current_race_token == unit_race_token and current_caste_token == unit_caste_token then
      return true
    end
  end

  return false
end

-- Returns true if the unit has the given creature class
-- Optionally, creature_class can be an indexed table of creature classes to check. Returns true if any match.
function unit_is_creature_class(unit, creature_class)
  local class_table

  if type(creature_class) == "table" then
    class_table = creature_class
  else
    class_table = {}
    table.insert(class_table, creature_class)
  end

  local caste_raw = df.creature_raw.find(unit.race).caste[unit.caste]

  for index, entry in pairs(caste_raw.creature_class) do
    for index, class in pairs(class_table) do
      if entry.value == class then
        return true
      end
    end
  end

  return false
end

-- Returns true if the unit has a syndrome with the given name
-- Optionally, name can be an indexed table of syndrome names to check. Returns true if any match.
function unit_has_syndrome_name(unit, name)
  local name_table

  if type(name) == "table" then
    name_table = name
  else
    name_table = {}
    table.insert(name_table, name)
  end

  for _, active_syndrome in pairs(unit.syndromes.active) do

    local syndrome = df.syndrome.find(active_syndrome.type)

    for _, name in pairs(name_table) do
      if syndrome.syn_name == name then
        return true
      end
    end
  end

  return false
end

-- Returns true if the unit has a syndrome with the given class
-- Optionally, class may be an indexed table of syndrome classes to check. Returns true if any match.
function unit_has_syndrome_class(unit, syndrome_class)
  local classes_to_check

  if type(syndrome_class) == "table" then
    classes_to_check = syndrome_class
  else
    classes_to_check = {}
    table.insert(classes_to_check, syndrome_class)
  end

  for _, active_syndrome in pairs(unit.syndromes.active) do
    -- Get the actual syndrome info
    local syndrome = df.syndrome.find(active_syndrome.type)

    -- Loop through each syn_class entry for the syndrome
    for _, entry in pairs(syndrome.syn_class) do -- < Crashes before returning to this loop after going through once
      local current_class = entry.value

      -- Check if the current class is one of the ones we were given to look for
      for _, check_class in pairs(classes_to_check) do
        if check_class == current_class then
          return true
        end
      end
    end
  end

  return false
end

-- Returns true if the unit has a syndrome with the given identifier
-- Optionally, identifier may be an indexed table of syndrome identifiers to check. Returns true if any match.
function unit_has_syndrome_identifier(unit, identifier)
  local indentifier_table

  if type(identifier) == "table" then
    indentifier_table = identifier
  else
    indentifier_table = {}
    table.insert(indentifier_table, identifier)
  end

  for _, active_syndrome in pairs(unit.syndromes.active) do
    local syndrome = df.syndrome.find(active_syndrome.type)

    for _, identifier in pairs(indentifier_table) do
      if syndrome.syn_identifier == identifier then
        return true
      end
    end
  end

  return false
end

-- Returns true if the world's current moon phase is at or between the two given values (or alternatively if only `start_value` is provided, returns true if the current moon phase is exactly the given value)
-- Supports looping around to the next cycle (in the case that `start_value` is higher than `end_value`)
-- See https://dwarffortresswiki.org/index.php/DF2014:Syndrome#MOON_PHASE for a list of the values
function is_moon_phase(start_value, end_value)
  -- If only min is provided, only check if the moon phase is exactly equal to the current one
  local moon_phase = df.global.world.world_data.moon_phase
  if end_value == nil then
    return (moon_phase == start_value)
  end

  if start_value <= end_value then
    return (moon_phase >= start_value and moon_phase <= end_value)
  else -- The start_value value is greater than end_value, meaning the range is supposed to loop around
    return (moon_phase >= start_value or moon_phase <= end_value)
  end
end

---------------------------------------------------------------------
-- MISC

-- Blocks all adventure mode reactions that have been registered with this script from being used. They can then be selectively enabled if the player character satisfies a condition blob for that reaction
function disable_registered_reactions()
  for index, reaction in pairs(df.global.world.raws.reactions.reactions) do
    -- Check if it's a reaction with have registered condition blobs for
    if registered_reactions[reaction.code] ~= nil then
      reaction.flags.ADVENTURE_MODE_ENABLED = false
    end
  end
end

-- Runs through each reaction that has been registered with this script, testing if the should be available for the current adventurer. If they are, they are re-enabled (after them having been disabled in `disable_registered_reactions()`)
function update_available_reactions()
  for _, reaction in pairs(df.global.world.raws.reactions.reactions) do
    -- Only bother doing things for registered reactions
    if registered_reactions[reaction.code] ~= nil then
      local can_use = false
      -- Go through each condition blob and check each condition
      for _, condition_blob in pairs(registered_reactions[reaction.code]) do
        if check_condition_blob(condition_blob) == true then
          -- The adventurer passed all the checks in the condition blob, so they should be given access to the reaction
          can_use = true
          break
        end
      end

      -- Re-enable the reaction if they passed
      if can_use == true then
        reaction.flags.ADVENTURE_MODE_ENABLED = true
      end
    end
  end
end

function find_creature_by_token(token)
  local out = nil
  for index, creature in pairs(df.global.world.raws.creatures.all) do
    if creature.creature_id == token then
      out = creature
      break
    end
  end

  return out
end

-- Removes all registered reactions + resets everything else
function reset()
  -- Clear previous information
  registered_reactions = {}
  hack_insert = 0
end

dfhack.onStateChange.dynamic_adv_reactions = function(event)
  if event == SC_VIEWSCREEN_CHANGED then
    -- This slightly hacky method is how we update the list of available reactions for the player
    -- It detects when the player opens the actions menu, immediately closes the menu, updates the available reactions, then reopens the menu
    -- (The memory mapping currently isn't up to snuff for just adding the reactions straight to the menu's list of options, so we have to do this. It works out fine, though)
    if df.viewscreen_dungeonmodest:is_instance(df.global.gview.view.child) and df.viewscreen_layer_unit_actionst:is_instance(df.global.gview.view.child.child) then
      local adventure_view = df.global.gview.view.child
      local action_view = adventure_view.child
      if hack_insert == 0 and not dfhack.screen.isDismissed(action_view) then -- Even if hack_insert is 0, don't execute if the view is being dismissed (otherwise this will trigger again after the player manually closes the view, since the view itself persists for a bit after closing)!

        -- RUN CODE HERE
        disable_registered_reactions()
        update_available_reactions()

        hack_insert = 1 -- We use this flag to tell the code not to trigger again when the screen is re-opened by this script

        -- Close and re-open to refresh
        gui.simulateInput(action_view,"LEAVESCREEN")
        gui.simulateInput(adventure_view, "A_ACTION")
      elseif hack_insert ~= 0 then
        -- Reset the flag
        hack_insert = 0
      end
    end
  elseif event == SC_WORLD_UNLOADED then
    -- Cleanup this world's registered reactions
    reset()
  end
end

function main(...)
  local args = utils.processArgs({...}, validArgs)

  if args.help then
    print(help)
    return
  end

  if not args.reaction then
    qerror("Please provide a reaction with the -reaction argument")
  end

  -- Create the new condition blob for this reaction.
  local condition_blob = register_reaction(args.reaction)

  if args.creature then
    add_condition(condition_blob, make_condition_creature(args.creature))
  end

  if args.caste then
    add_condition(condition_blob, make_condition_caste(args.caste))
  end

  if args.creatureCaste then
    add_condition(condition_blob, make_condition_creature_caste(args.creatureCaste))
  end

  if args.creatureClass then
    add_condition(condition_blob, make_condition_creature_class(args.creatureClass))
  end

  if args.sphere then
    add_condition(condition_blob, make_condition_sphere(args.sphere))
  end

  if args.syndrome then
    add_condition(condition_blob, make_condition_syndrome_name(args.syndrome))
  end

  if args.syndromeClass then
    add_condition(condition_blob, make_condition_syndrome_class(args.syndromeClass))
  end

  if args.syndromeIdentifier then
    add_condition(condition_blob, make_condition_syndrome_identifier(args.syndromeIdentifier))
  end

  if args.secret then
    add_condition(condition_blob, make_condition_secret(args.secret))
  end

  if args.item then
    add_condition(condition_blob, make_condition_item(args.item))
  end

  if args.itemType then
    add_condition(condition_blob, make_condition_item_type(args.itemType))
  end

  -- Cleanup
  if args.moon then
    -- Cleanup into numbers first, then add the conditions
    if type(args.moon) == "table" then
      args.moon[1] = tonumber(args.moon[1])
      args.moon[2] = tonumber(args.moon[2])

      add_condition(condition_blob, make_condition_moon_phase(args.moon[1], args.moon[2]))
    else
      args.moon = tonumber(args.moon)
      add_condition(condition_blob, make_condition_moon_phase(args.moon))
    end
  end
end

if not dfhack_flags.module then
    main(...)
end

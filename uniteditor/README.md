# Dwarf Fortress unit editor

A collection of scripts to modify or reset the characteristics of a unit. You can alter attributes, skills,
preferences, beliefs, goals and facets one at a time, or you can define a profile and apply it as a whole to the unit.

This collection exists for two reasons:
1. to group all the scripts with similar scopes in a single place, simplifying use and maintainability;
2. to increase the user-friendliness of the existing scripts by rewriting, reorganising and expanding their
   functionality.

##### HOW TO USE THIS COLLECTION:
 
To use this collection, copy the "*uniteditor*" folder inside the "*/hack/scripts/*"
folder under the DF root directory: the scripts will be automatically recognised.

###### DISCLAIMER:
A lot of guesswork (and very little testing) was involved in the making of the modules of this
collection. Also, almost no check is performed on the values provided in the profile json (just a bit
more than a simple spell-check). This means that this can potentially corrupt your save. Please backup.

Another thing: although they are written to be applied to a dwarf, I think they could work on other creatures, but here
we are in the realm of pure gambling. Anyway, feel free to create a carpenter cat (a caTpenter?) or a carpenter carp.

## Scripts documentation

### assign-profile
A script to change the characteristics of a unit according to a profile loaded from a json file.

A profile can describe which attributes, skills, preferences, beliefs, goals and facets a
unit must have. The script relies on the presence of the other `assign-...` modules in this
collection: please refer to the other modules documentation for more specific information.

For information about the json schema, please see the [Profile JSON format guide](JSON_FORMAT.md) 
and the "*/hack/scripts/uniteditor/dwarf_profiles.json*" file for other examples.

##### Usage:
* `-help`: print the help page.

* `-unit <UNIT_ID>`: the target unit ID. If not present, the target will be the currently selected unit.

* `-file <filename>`: the json file containing the profile to apply. It's a relative
  path, starting from the DF root directory and ending at the json file. It must
  begin with a slash. Default value: "*/hack/scripts/uniteditor/dwarf_profiles.json*".

* `-profile <profile>`: the profile to apply. It's the name of the profile as stated in the json file.

* `-reset <list of characteristics>`: the characteristics to be reset/cleared. If not present, it will not clear or
  reset any characteristic. If it's a valid list of characteristic, those characteristics will be reset, and then, if
  present in the profile, the new values will be applied. If set to `PROFILE`, it will reset only the characteristics
  changed in the profile (and then the new values will be applied). If set to `ALL`, it will reset EVERY characteristic.
  Possible values: `ALL`, `PROFILE`, `ATTRIBUTES`, `SKILLS`, `PREFERENCES`, `BELIEFS`, `GOALS`, `FACETS`.
 
##### Examples
`uniteditor/assign-profile -reset ALL`

Resets/clears all the characteristics of the unit, leaving behind a very bland character.

`uniteditor/assign-profile -profile CARPENTER -reset PROFILE`

Loads and applies the profile called "CARPENTER" in the default json file, resetting/clearing
all the characteristics listed in the profile, and then applying the new values.

`uniteditor/assign-profile -file /hack/military_profiles.json -profile ARCHER -reset ATTRIBUTES`

Loads and applies the profile called "ARCHER" in the provided json file, keeping all the old characteristics but the
attributes, which will be reset (and then, if the profile provides some attributes values, those value will be applied).

### assign-attributes
A script to change the physical and mental attributes of a unit.

Attributes are divided into tiers from -4 to 4. Tier 0 is the standard level and represents the
average values for that attribute, tier 4 is the maximum level, and tier -4 is the minimum level.

An example of the attribute "Strength":

Tier | Description
:---:| ----------
  4  | unbelievably strong
  3  | mighty
  2  | very strong
  1  | strong
  0  | (no description)
 -1  | weak
 -2  | very weak
 -3  | unquestionably weak
 -4  | unfathomably weak
 
For more information: [DF2014:Attribute](https://dwarffortresswiki.org/index.php/DF2014:Attribute).

##### Usage: 
* `-help`: print the help page.

* `-unit <UNIT_ID>`: the target unit ID. If not present, the currently selected unit will be the target.

* `-attributes <ATTRIBUTE TIER [ATTRIBUTE TIER] [...]>`: the list of the attributes to modify and their tiers.
  The valid attribute names can be found [in the wiki](https://dwarffortresswiki.org/index.php/DF2014:Attribute)
  (substitute any space with underscores); tiers range from -4 to 4.
                           
* `-reset`: reset all attributes to the average level (tier 0). If both this option and a list of attributes/tiers
  are present, the unit attributes will be reset and then the listed attributes will be modified.

##### Example: 
`uniteditor/assign-attributes -reset -attributes STRENGTH 2 AGILITY -1 SPATIAL_SENSE -1`
 
This will reset all attributes to a neutral value and will set the following values (if the currently
selected unit is a dwarf): Strength: a random value between 1750 and 1999 (tier 2); Agility: a random
value between 401 and 650 (tier -1); Spatial sense: a random value between 1043 and 1292 (tier -1).

The final result will be:

> `She is strong, but she is very clumsy. She has a questionable spatial sense.`

### assign-skills
A script to change the skills of a unit.

Skills are defined by their token and their rank. Skills tokens can be found here:
[DF2014:Skill token](https://dwarffortresswiki.org/index.php/DF2014:Skill_token).

Below you can find a list of the first 16 ranks.:

Rank | Skill name
:---:| ----------
  0  | Dabbling
  1  | Novice
  2  | Adequate
  3  | Competent
  4  | Skilled
  5  | Proficient
  6  | Talented
  7  | Adept
  8  | Expert
  9  | Professional
 10  | Accomplished
 11  | Great
 12  | Master
 13  | High Master
 14  | Grand Master
 15+ | Legendary

For more information: [DF2014:Skill](https://dwarffortresswiki.org/index.php/DF2014:Skill#Skill_level_names).

##### Usage:
* `-help`: print the help page.

* `-unit <UNIT_ID>`: the target unit ID. If not present, the currently selected unit will be the target.

* `-skills <SKILL RANK [SKILL RANK] [...]>`: The list of the skills to modify and
* their ranks. Rank values range from -1 (the skill is not learned) to normally 20
* (legendary + 5). It is actually possible to go beyond 20, no check is performed.

* `-reset`: clear all skills. If the script is called with both this option and a list of
* skills/ranks, first all the unit skills will be cleared and then the listed skills will be added.

##### Example:
`uniteditor/assign-skills -skills WOODCUTTING 3 AXE 2 -reset`

Clears all the unit skills, then adds the Wood cutter skill (competent evel) and the Axeman skill (adequate level).

### assign-preferences
A script to change the preferences of a unit.

Preferences are classified into 12 types. The first 9 are: like material; like creature;
like food; hate creature; like item; like plant; like tree; like colour; like shape.

These can be changed using this script.

The remaining three are not currently managed by this script,
and are: like poetic form, like musical form, like dance form.

To produce the correct description in the "thoughts and preferences" page, you must specify the
particular type of preference. For each type, a description is provided in the section below.
 
You will need to know the token of the object you want your dwarf to like. Unless told otherwise, the
best way to get those tokens is to activate the plugin `stonesense`, load a world and let the plugin
generate a file named "MatList.csv" in the root DF folder. Browse this file (import it as a .csv
file with Excel or similar program) to get the desired token (in the "id" column). Otherwise, in the
folder "/raw/objects/" under the main DF directory you will find all the raws defined in the game.

For more information: [DF2014:Preferences](https://dwarffortresswiki.org/index.php/DF2014:Preferences).

##### Usage:
* `-help`: print the help page.

* `-unit <UNIT_ID>`: set the target unit ID. If not present, the currently selected unit will be the target.

* `-likematerial <TOKEN [TOKEN] [...]>`: usually a type of stone, a type of metal and a type of gem, plus it can
  also be a type of wood, a type of glass, a type of leather, a type of horn, a type of pearl, a type of ivory, a
  decoration material - coral or amber, a type of bone, a type of shell, a type of silk, a type of yarn, or a type of
  plant cloth. Write the tokens as found in the "id" column of the file ""MatList.csv", generated as explained above.
                           
* `-likecreature <TOKEN [TOKEN] [...]>`: one or more creatures liked by the unit. You can just list the
  species: if you are using the file "MatList.csv" as explained above, the creature token will be something
  similar to `CREATURE:SPARROW:SKIN`, so the name of the species will be `SPARROW`. Nothing will stop
  you to write the full token, if you want: the script will just ignore the first and the last parts.

* `-likefood <TOKEN [TOKEN] [...]>`: usually a type of alcohol, plus it can be a type of
  meat, a type of fish, a type of cheese, a type of edible plant, a cookable plant/creature
  extract, a cookable mill powder, a cookable plant seed or a cookable plant leaf. Write the
  tokens as found in the "id" column of the file "MatList.csv", generated as explained above.

* `-hatecreature <TOKEN [TOKEN] [...]>`: works the same way as `-likecreature`, but this time it's one or
  more creatures that the unit detests. They should be a type of `HATEABLE` vermin which isn't already
  explicitly liked, but no check is performed about this. Like before, you can just list the creature species.

* `-likeitem <TOKEN [TOKEN] [...]>`: a kind of weapon, a kind of ammo, a kind of piece of armor, a piece of
  clothing (including backpacks or quivers), a type of furniture (doors, floodgates, beds, chairs, windows,
  cages, barrels, tables, coffins, statues, boxes, armor stands, weapon racks, cabinets, bins, hatch covers,
  grates, querns, millstones, traction benches, or slabs), a kind of craft (figurines, amulets, scepters,
  crowns, rings, earrings, bracelets, or large gems), or a kind of miscellaneous item (catapult parts, ballista
  parts, a type of siege ammo, a trap component, coins, anvils, totems, chains, flasks, goblets, buckets, animal
  traps, an instrument, a toy, splints, crutches, or a tool). The item tokens can be found here: [DF2014:Item
  token](https://dwarffortresswiki.org/index.php/DF2014:Item_token). If you want to specify an item subtype,
  look into the files listed under the column `Subtype` of the wiki page (they are in the "*/raw/ojects/*"
  folder), then specify the items using the full tokens found in those files (see the examples below).

* `-likeplant <TOKEN [TOKEN] [...]`: works in a similar way as `-likecreature`, this time with plants.
  You can just List the plant species (the middle part of the token as listed in "*MatList.csv*").

* `-liketree <TOKEN [TOKEN] [...]`: works exactly as `-likeplant`. I think this preference type is here for
  backward compatibility (?). You can still use it, however. As before, you can just list the tree (plant) species.

* `-likecolor <TOKEN [TOKEN] [...]`: you can find the color tokens here:
  [DF2014:Color](https://dwarffortresswiki.org/index.php/DF2014:Color#Color_tokens),
  or inside the "*descriptor_color_standard.txt*" file (in the "*/raw/ojects/*"
  folder). You can use the full token or just the color name.

* `-likeshape <TOKEN [TOKEN] [...]`: I couldn't find a list of shape tokens in the
  wiki, but you can find them inside the "*descriptor_shape_standard.txt*" file (in
  the "*/raw/ojects/*" folder). You can use the full token or just the shape name.

* `-reset`: clear all preferences. If the script is called with both this option and one or more
  preferences, first all the unit preferences will be cleared and then the listed preferences will be added.

##### Examples:
`uniteditor/assign-preferences -reset -likematerial INORGANIC:OBSIDAN PLANT:WILLOW:WOOD`
> "likes alabaster and willow wood"

`uniteditor/assign-preferences -reset -likecreature SPARROW`
> "likes sparrows for their ..."

`uniteditor/assign-preferences -reset -likefood PLANT:MUSHROOM_HELMET_PLUMP:DRINK PLANT:OLIVE:FRUIT`
> "prefers to consume dwarven wine and olives"
 
`uniteditor/assign-preferences -reset -hatecreature SPIDER_JUMPING`
> "absolutely detests jumping spiders
        
`uniteditor/assign-preferences -reset -likeitem WOOD ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE`
> "likes logs and battle axes"
        
`uniteditor/assign-preferences -reset -likeplant BERRIES_STRAW`
> "likes straberry plants for their ..."
       
`uniteditor/assign-preferences -reset -liketree OAK`
> "likes oaks for their ..."
        
`uniteditor/assign-preferences -reset -likecolor AQUA`
> "likes the color aqua"
        
`uniteditor/assign-preferences -reset -likeshape STAR`
> "likes stars"

### assign-beliefs
A script to change the beliefs (values) of a unit.

Beliefs are defined with the belief token and a number from -3 to 3, which describes
the different levels of belief strength, as explained here: [DF2014:Personality
traits](https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Beliefs).

Strength | Effect
:------: | ------ 
   3     | Highest
   2     | Very High
   1     | High
   0     | Neutral
  -1     | Low
  -2     | Very Low 
  -3     | Lowest

Resetting a belief means setting it to a level that does not trigger a report in the "Thoughts and preferences" screen.

##### Usage:
* `-help`: print the help page.

* `-unit <UNIT_ID>`: set the target unit ID. If not present, the currently selected unit will be the target.

* `-beliefs <BELIEF LEVEL [BELIEF LEVEL] [...]>`: the beliefs to modify and their levels. The
  valid belief tokens can be found in the wiki page linked above; level values range from -3 to 3.

* `-reset`: reset all beliefs to a neutral level. If the script is called with
  both this option and a list of beliefs/levels, first all the unit beliefs will
  be reset and then those beliefs listed after ``-beliefs`` will be modified.

##### Example:
`uniteditor/assign-beliefs -reset -beliefs TRADITION 2 CRAFTSMANSHIP 3 POWER 0 CUNNING -1`

Resets all the unit beliefs, then sets the listed beliefs to the following values: Tradition: a random
value between 26 and 40 (level 2); Craftsmanship: a random value between 41 and 50 (level 3); Power:
a random value between -10 and 10 (level 0); Cunning: a random value between -25 and -11 (level -1).
  
The final result (for a dwarf) will be:
> `She personally is a firm believer in the value of tradition and
sees guile and cunning as indirect and somewhat > > worthless.`

Note that the beliefs aligned with the cultural values of the unit have not triggered a report.

### assign-goals 
A script to change the goals (dreams) of a unit.

Goals are defined with the goal token and a true/false value that describes whether
or not the goal has been accomplished. Be advised that this last feature has not been
properly tested and might be potentially destructive. I suggest leaving it at false.

For a list of possible goals: [DF2014:Personality
trait](https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Goals).

Bear in mind that nothing will stop you from assigning zero or
more than one goal, but it's not clear how it will affect the game.

##### Usage:
* `-help`: print the help page.

* `-unit <UNIT_ID>`: set the target unit ID. If not present, the currently selected unit will be the target.

* `-goals <GOAL REALIZED_FLAG [GOAL REALIZED_FLAG] [...]>`: the goals to modify/add and whether
  they have been realized or not. The valid goal tokens can be found in the wiki page linked above.

* `-reset`: clear all goals. If the script is called with both this option and a list of goals,
  first all the unit goals will be erased and then those goals listed after `-goals` will be added.

##### Example:
`uniteditor/assign-goals -reset -goals MASTER_A_SKILL false`

Clears all the unit goals, then sets the "master a skill"
goal. The final result will be:
> `dreams of mastering a skill.`

### assign-facets
A script to change the facets (traits) of a unit.

Facets are defined with a token and a number from -3 to 3, which describes the different levels of facets strength, as
explained here: [DF2014:Personality trait](https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Facets)

Strength | Effect
:------: | ------
   3     | Highest
   2     | Very High
   1     | High
   0     | Neutral 
  -1     | Low
  -2     | Very Low
  -3     | Lowest

Resetting a facet means setting it to a level that does not trigger a report in the "Thoughts and preferences" screen.

##### Usage:
* `-help`: print the help page.

* `-unit <UNIT_ID>`: set the target unit ID. If not present, the currently selected unit will be the target.

* `-beliefs <FACET LEVEL [FACET LEVEL] [...]>`: the facets to modify and their levels. The valid
  facet tokens can be found in the wiki page linked above; level values range from -3 to 3.

* `-reset`: reset all facets to a neutral level. If the script is called with
  both this option and a list of facets/levels, first all the unit facets will
  be reset and then those facets listed after ``-facets`` will be modified.

##### Example:
`uniteditor/assign-facets -reset -facets HATE_PROPENSITY -2 CHEER_PROPENSITY -1`

Resets all the unit facets, then sets the listed facets to the following values: Hate propensity:
a value between 10 and 24 (level -2); Cheer propensity: a value between 25 and 39 (level -1).
  
The final result (for a dwarf) will be:
> `She very rarely develops negative feelings toward things. She is rarely
happy or enthusiastic, and she is conflicted by this as she values parties and merrymaking in the abstract.`

Note that the facets are compared to the beliefs, and if conflicts arise they will be reported.
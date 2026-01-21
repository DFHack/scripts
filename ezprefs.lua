--Easily assign large and broken preference profiles to dwarves.

local utils = require("utils")
local argparse = require("argparse")
local opts = {}

local help = [====[

ezprefs
=======
Easily assign large and broken preference profiles to dwarves.

This script assigns a whole bunch of useful preferences to a dwarf, plus some
specialized preferences based on profiles you specify. The script relies on
the wonderful assign-preferences.lua to do the actual assigning. (It also
steals liberally from its code.) Note that this means that it cannot assign
preferences for music, poetry, or dance. Try pref-adjust.lua for those.

For example, "ezprefs --jobs glassmaker" gives the dwarf a bunch of preferences
that are useful for everyone to like (the "everyone" profile), and then adds
the different types of glass, as well as pearlash. The "everyone" list includes
all kinds of layer stone (which makes a dwarf's perception of the value of
their room skyrocket), green and clear glass, most of the more useful metals,
most of the furniture items they are likely to encounter, all the dye colors,
and all the foods that can be grown underground, plus a few choice delicacies
that can be found easily in the caverns.

WARNING: This script may result in unreasonably happy dwarves, as well as
the occasional masterwork made by a dabbler.

Usage
=====

ezprefs [--help|--syntax|--list|--tips|--nicknames] | [--unit <UNIT_ID>|--all] [--reset] [--preview|--jobs|--addjobs <job1>,<job2>,<...>]

 -h, --help                 Print this help page.

 -x, --syntax               Print an abbreviated syntax reference.

 -l, --list                 Print the list of valid profiles that can be
                            assigned with this script (by default).
                            Recommended reading.

 -t, --tips                 Print tips on customizing the script to your own
                            preferences, as well as usage suggestions.

 -n, --nicknames            Print the list of shortcuts you can use to enter
                            job names, such as "ws" for weaponsmith.

 -u, --unit <UNIT_ID>       Optional. Set the target unit ID. If not present,
                            the currently selected unit will be the target.
                            Usable with --jobs and -addjobs.

 -p, --preview <job1>,<job2>,<...>
                            Print the list of preferences that will be added
                            with the selected profiles. Does not include
                            "everyone" by default. The list of profiles must be
                            separated by commas, with no spaces.

 -j --jobs <job1>,<job2>,<...>
                            Replaces all of a unit's preferences with a list
                            based on what profiles are selected. These are
                            added to a list of preferences that are useful to
                            every dwarf (the "everyone" profile).

 -a, --addjobs <job1>,<job2>,<...>
                            Adds preferences for the jobs listed, without
                            removing the existing preferences. Does not include
                            the "everyone" job unless you include it in the
                            list. This can be used with --reset to start from
                            scratch without adding 'everyone'.

 -r, --reset                Removes all preferences. Can be used alone or with
                            --addjobs.

 --all                      Apply the changes to every citizen. Note that there
                            is no undo function, so consider saving beforehand.

 -s, --silent               Suppress all dialog besides errors.

Examples
========

    ezprefs --jobs metalcrafter
    ezprefs -j mc
                            Replaces the selected unit's existing preferences
                            with the "everyone" list, as well as all the
                            metals, bars, crafts, toys, and goblets.

    ezprefs --addjobs cook,carpenter
    ezprefs -a co,ca
                            Adds preferences for biscuits, stew, roasts, tower-
                            cap, willow, oak, and logs in general to the
                            selected unit's existing preferences.

    ezprefs --reset -a cook,carpenter
    ezprefs -ra co,ca
                            Adds cook and carpenter preferences as above, but
                            removes the unit's existing preferences first.

    ezprefs --unit 24601 --jobs noble
    ezprefs -u 24601 -j no
                            Prepares unit 24601 to become the mayor by removing
                            all preferences and replacing them with a list that
                            cannot generate mandates.

    ezprefs --reset --add mood-hammer
    ezprefs -ra m-ha
                            Clears all preferences and adds a preference for
                            warhammers. Good if your moody weaponsmith just
                            picked up a bar of lead.

    ezprefs --preview everyone,child,armorsmith
    ezprefs -p e,ch,ar
                            Displays the list of preferences that will be added
                            by default with the -jobs command, in addition to
                            toys (from child) and metal bars (from armorsmith).

    ezprefs --all --reset --silent --addjobs mood-crossbow
    ezprefs --all -rsa m-c
                            Makes every dwarf like nothing but crossbows, and
                            does it quietly. Probably not ideal.

]====]

local shorthelp = [====[
Usage reference (-h for full)
=============================
ezprefs [--help|--syntax|--list|--tips|--nicknames] | [--unit <UNIT_ID>|--all] [--reset] [--preview|--jobs|--addjobs <job1>,<job2>,<...>]

 -h, --help                 Print the full help page.
 -x, --syntax               Print this brief syntax reference.
 -l, --list                 Print the list of valid preference profiles.
 -t, --tips                 Print tips for using this script to break the game.
 -n, --nicknames            Print the list of profile shortcuts.
 -u, --unit <UNIT_ID>       Optional. Set the target unit ID. If not present,
                            the currently selected unit will be the target.
 --all                      Targets all citizens instead of just one.
 -r, --reset                Clears all unit preferences. Can be used with -a.
 -p, --preview <job1>,<job2>,<...>
                            Print the list of preferences that will be added
                            with the selected jobs arguments.
 -j, --jobs <job1>,<job2>,<...>
                            Replaces all preferences with a predefined list
                            based on what jobs are selected plus the "everyone"
                            job.
 -a, --addjobs <job1>,<job2>,<...>
                            Adds preferences for the jobs listed to the existing
                            preferences. Does not include the "everyone" job
                            unless you include it in the list.
 -s, --silent               Suppress non-error messages.
]====]

local tips = [====[
Tips
====

    This is not a subtle script. If you want to tweak individual preferences a
    little, I recommend using assign-preferences.lua. If you want to break the
    game and like ALL the things!, then this is what you want.

Duplicate preferences

    ezprefs checks for duplicates in the preferences that it adds to the unit.
    You could run ezprefs --reset --addjobs everyone,everyone,everyone and it
    would only add each preference once.

    That said, it does not check for duplicates with preferences that the unit
    already has. So if you run ezprefs -j miner and then ezprefs -a miner, they
    would end up liking picks and boulders twice. The game doesn't seem to
    notice this much.

Custom Profiles

    It should be relatively easy to change the preference lists or add new job
    profiles. Some instructions are provided inside the script if you wish to
    do so. Start by searching for "-- DATA --".

    Don't use it to make your animal trainers like their animals. They get
    really tetchy when you eat them.

Moods

    When a dwarf enters a mood, the types of items they can build is determined
    by their highest moodable skill; within that list, however, the item is not
    decided until the dwarf actually completes the mood. If they have a
    preference for a type of item that can be made with their highest moodable
    skill, they will make that item. So a dwarf whose highest skill is weapon-
    smithing will make a weapon or a trap component, but if they like short
    swords then they will make a short sword.

    That means that, since you can change their preferences, you can change
    what kind of artifact they will produce. Say a moody weaponsmith likes
    swords, but using "showmood" tells you that they are going to grab a bar of
    platinum. Use "ezprefs -ra mood-hammer" to give them the sole preference of
    warhammers, and they'll make an artifact worth using. Likewise, a carpenter
    in a mood is much better spent on a door than on a barrel or wheelbarrow.
    Furniture that is built cannot be destroyed or stolen, and makes great bait
    for building destroyers.

    Just don't forget to give them some preferences again after the mood is
    over.

Contact
    You can contact the author, doublestrafe, on the Bay12 forums.
]====]

local list = [====[
Labors:
    armorsmith  blacksmith      metalcrafter    weaponsmith     furnaceoperator
    farmer      cook            brewer          papermaker      miller
    miner       mason           engraver        mechanic        stonecrafter
    clothier    leatherworker   weaver          dyer            doctor
    bowyer      carpenter       woodburner      woodcutter      bonecarver
    glassmaker  potter          woodcrafter     soldier         scholar
    thresher    jeweler

Moods:
    Each of these profiles contains one type of item: a good item to have a
    preference for during a strange mood. This will be either a weapon, a piece
    of armor, or a piece of furniture that can be built. See 'Tips' for more.

    mood-armorstand     mood-axe        mood-bed        mood-box
    mood-breastplate    mood-cabinet    mood-chain      mood-crossbow
    mood-door           mood-gear       mood-hammer     mood-instrument
    mood-mace           mood-shield     mood-spear      mood-statue
    mood-sword          mood-table      mood-throne     mood-weaponrack

Special cases:

    everyone    Automatically included with --jobs. "everyone" is the only job
                that includes colors and foods.

    noble       Does not like any items. Only likes the most common materials.
                This eliminates all mandates, and makes most demands a fair
                bit more reasonable. This job cannot be used with any others.
                If you want additional jobs added, use ezprefs -jobs noble, and
                then use ezprefs -addjobs <whatever>. It may be beneficial to
                edit these preferences to match what's on your map.

    greedy      Experimental job that adds figurines, amulets, scepters,
                crowns, rings, earrings, bracelets, and large gems. Use it
                with --addjobs to maybe get them to fill the "acquire something"
                need. Maybe.

    child        Likes toys. Because I don't know how to make them like magma.

Each of the labors has a few aliases, such as "ws" for weaponsmith. Use
ezprefs --nicknames (-n) to view them.
]====]


-- ------------------------------------------------------ DATA ------------------------------------------------------- --

    --[[    Here we have the data that the script runs on. Feel free to muck
            with it if you don't like my taste in liking stuff.

            Adding custom professions:
            ==========================
            Should be pretty easy, honestly. A profile consists of one or more
            tables of preferences, an entry in the table big_jobs_list, and an
            entry in the job_alias table.

            For example, let's make a profile called "fred". Here's what fred
            likes:

            trees['fred'] = {'PALM'}
            shapes['fred'] = {'SUN','WAVE'}
            colors['fred'] = {'PINK','PURPLE','TEAL','ORANGE','BLACK'}

            Clearly Fred is into synthwave. Next he'll need to go into the
            big_jobs_list table:

            local big_job_list={'armorsmith', [...] ,'mood-weaponrack','fred'}

            Finally he'll need a job_alias entry:

            job_alias['fred'] = {'fred','f','freddy'}

            Notice that 'f' is not used by any other profiles as an alias. If
            it were, it would cause problems, so watch out for that.

            The first entry in the job_alias table should be the same as the
            index name.

            With that, ezprefs -j fred should work. Have fun!
    --]]


local materials = {}
local items = {}
local plants = {}
local creatures = {}
local foods = {}
local trees = {}
local colors = {}
local shapes = {}
local hates = {}

     --[[   This is the meat of this beast, and the easiest part to reconfigure
            to your taste. Add or remove tokens to your heart's desire.

            The empty tables are here because I thought they might be needed,
            but when I found out they were not, I left them in for the sake of
            future editing's convenience. They don't seem to hurt anything. --]]

materials['armorsmith'] = {'COPPER','BRONZE','BISMUTH_BRONZE','IRON','STEEL','SILVER','ADAMANTINE'}
materials['blacksmith'] = {'BILLON','BISMUTH','BLACK_BRONZE','BRASS','ELECTRUM','LEAD','NICKEL','NICKEL_SILVER','PEWTER_FINE','PEWTER_LAY','PEWTER_TRIFLE','STERLING_SILVER','TIN','ZINC'}
materials['bowyer'] = {'PLANT_MAT:TOWER_CAP:WOOD','PLANT_MAT:WILLOW:WOOD','PLANT_MAT:OAK:WOOD','PLANT_MAT:FEATHER:WOOD'}
materials['carpenter'] = {'PLANT_MAT:TOWER_CAP:WOOD','PLANT_MAT:WILLOW:WOOD','PLANT_MAT:OAK:WOOD','PLANT_MAT:FEATHER:WOOD'}
materials['child'] = {}
materials['clothier'] = {'PLANT_MAT:REED_ROPE:THREAD','PLANT_MAT:GRASS_TAIL_PIG:THREAD','CREATURE_MAT:SPIDER_CAVE:SILK','CREATURE_MAT:SPIDER_CAVE_GIANT:SILK','CREATURE_MAT:SHEEP:HAIR','CREATURE_MAT:ALPACA:HAIR','CREATURE_MAT:LLAMA:HAIR'}
materials['cook'] = {}
materials['doctor'] = {'PLANT_MAT:REED_ROPE:THREAD','PLANT_MAT:GRASS_TAIL_PIG:THREAD','CREATURE_MAT:SPIDER_CAVE:SILK','CREATURE_MAT:SHEEP:HAIR','CREATURE_MAT:ALPACA:HAIR','CREATURE_MAT:LLAMA:HAIR','PLASTER'}
materials['dyer'] = {'PLANT_MAT:REED_ROPE:THREAD','PLANT_MAT:GRASS_TAIL_PIG:THREAD','CREATURE_MAT:SPIDER_CAVE:SILK','CREATURE_MAT:SPIDER_CAVE_GIANT:SILK','CREATURE_MAT:SHEEP:HAIR','CREATURE_MAT:ALPACA:HAIR','CREATURE_MAT:LLAMA:HAIR'}
materials['engraver'] = {}
materials['everyone'] = {'ORTHOCLASE','MICROCLINE','BAUXITE','MARBLE','LIMESTONE','OBSIDIAN','QUARTZITE','GABBRO','GRANITE','DIORITE','DOLOMITE','GNEISS','CHALK','GLASS_GREEN','GLASS_CLEAR','ADAMANTINE','BISMUTH_BRONZE','BRONZE','COPPER','GOLD','IRON','PLATINUM','SILVER','STEEL','ALUMINUM','ROSE_GOLD','CREATURE_MAT:SPIDER_CAVE_GIANT:SILK'}
materials['farmer'] = {}
materials['furnaceoperator'] = {'MAGNETITE','HEMATITE','NATIVE_ALUMINUM','BISMUTHINITE','CASSITERITE','NATIVE_COPPER','GALENA','GARNIERITE','NATIVE_GOLD','HORN_SILVER','LIMONITE','MALACHITE','NATIVE_PLATINUM','NATIVE_SILVER','SPHALERITE','TETRAHEDRITE','COAL','PIG_IRON','COAL_BITUMINOUS','LIGNITE','PLASTER','PEARLASH'}
materials['glassmaker'] = {'PEARLASH','GLASS_CRYSTAL'}
materials['jeweler'] = {'DIAMOND_BLACK','DIAMOND_BLUE','DIAMOND_CLEAR','DIAMOND_GREEN','DIAMOND_RED','DIAMOND_YELLOW','DIAMOND_FY','SAPPHIRE_STAR','SAPPHIRE','RUBY','RUBY_STAR','EMERALD','GLASS_GREEN','GLASS_CLEAR','GLASS_CRYSTAL'}
materials['leatherworker'] = {'CREATURE_MAT:RUTHERER:LEATHER','CREATURE_MAT:ELK_BIRD:LEATHER','CREATURE_MAT:BIRD_TURKEY:LEATHER','CREATURE_MAT:BIRD_GOOSE:LEATHER','CREATURE_MAT:DRALTHA:LEATHER','CREATURE_MAT:JABBERER:LEATHER','CREATURE_MAT:VORACIOUS_CAVE_CRAWLER:LEATHER','CREATURE_MAT:BAT_GIANT:LEATHER'}
materials['mason'] = {'ORTHOCLASE','MICROCLINE','BAUXITE','MARBLE','LIMESTONE','OBSIDIAN','QUARTZITE','GABBRO','GRANITE','DIORITE','DOLOMITE','GNEISS','CHALK'}
materials['mechanic'] = {'ORTHOCLASE','MICROCLINE','BAUXITE','MARBLE','LIMESTONE','OBSIDIAN','QUARTZITE','GABBRO','GRANITE','DIORITE','DOLOMITE','GNEISS','CHALK','COPPER','BRONZE','BISMUTH_BRONZE','IRON','STEEL','SILVER'}
materials['metalcrafter'] = {'BILLON','BISMUTH','BLACK_BRONZE','BRASS','ELECTRUM','LEAD','NICKEL','NICKEL_SILVER','PEWTER_FINE','PEWTER_LAY','PEWTER_TRIFLE','STERLING_SILVER','TIN','ZINC'}
materials['noble'] = {'IRON','OBSIDIAN','CREATURE_MAT:SPIDER_CAVE:SILK','GLASS_GREEN','PLANT_MAT:TOWER_CAP:WOOD','PLANT_MAT:TUNNEL_TUBE:WOOD'}
materials['potter'] = {'CERAMIC_EARTHENWARE','CERAMIC_STONEWARE','CERAMIC_PORCELAIN','CLAY','SANDY_CLAY','SILTY_CLAY','CLAY_LOAM','FIRE_CLAY','KAOLINITE','CASSITERITE'}
materials['miner'] = {'COPPER','BRONZE','BISMUTH_BRONZE','IRON','STEEL','SILVER','ADAMANTINE'}
materials['papermaker'] = {'PLANT_MAT:REED_ROPE:THREAD','PLANT_MAT:GRASS_TAIL_PIG:THREAD'}
materials['scholar'] = {}
materials['soldier'] = {'STEEL','BRONZE','BISMUTH_BRONZE','ADAMANTINE','COPPER','SILVER','PLATINUM'}
materials['thresher'] = {}
materials['weaponsmith'] = {'COPPER','BRONZE','BISMUTH_BRONZE','IRON','STEEL','SILVER','ADAMANTINE'}
materials['weaver'] = {'PLANT_MAT:REED_ROPE:THREAD','PLANT_MAT:GRASS_TAIL_PIG:THREAD','CREATURE_MAT:SPIDER_CAVE:SILK','CREATURE_MAT:SPIDER_CAVE_GIANT:SILK','CREATURE_MAT:SHEEP:HAIR','CREATURE_MAT:ALPACA:HAIR','CREATURE_MAT:LLAMA:HAIR'}
materials['woodburner'] = {'COAL','ASH'}
materials['woodcutter'] = {'COPPER','BRONZE','BISMUTH_BRONZE','IRON','STEEL','SILVER','ADAMANTINE'}
items['armorsmith'] = {'BAR','ANVIL'}
items['blacksmith'] = {'BAR','ANVIL','ARMORSTAND','BLOCKS','BOX','BUCKET','CABINET','CAGE','CHAIN','CHAIR','COFFIN','DOOR','HATCH_COVER','STATUE','TABLE','TOOL','WEAPONRACK'}
items['bonecarver'] = {'CORPSEPIECE','ITEM_AMMO:ITEM_AMMO_BOLTS','TOTEM','FIGURINE','AMULET','SCEPTER','CROWN','RING','EARRING','BRACELET'}
items['bowyer'] = {'WOOD','CORPSEPIECE','ITEM_WEAPON:ITEM_WEAPON_CROSSBOW'}
items['carpenter'] = {'WOOD','ARMORSTAND','BED','BLOCKS','BOX','BUCKET','CABINET','CAGE','CHAIR','COFFIN','DOOR','HATCH_COVER','STATUE','TABLE','TOOL','WEAPONRACK'}
items['child'] = {'PLANT','SEEDS','TOY'}
items['clothier'] = {'CLOTH','THREAD','POWDER_MISC'}
items['cook'] = {'ITEM_FOOD:ITEM_FOOD_BISCUITS','ITEM_FOOD:ITEM_FOOD_STEW','ITEM_FOOD:ITEM_FOOD_ROAST'}
items['doctor'] = {'CLOTH','THREAD','POWDER_MISC','BED','BOX','TABLE','TRACTION_BENCH','SPLINT','CRUTCH'}
items['dyer'] = {'CLOTH','THREAD','POWDER_MISC'}
items['engraver'] = {'INSTRUMENT'}
items['everyone'] = {'ANVIL','ARMORSTAND','BARREL','BED','BLOCKS','BOX','BUCKET','CABINET','CAGE','CHAIN','CHAIR','COFFIN','DOOR','HATCH_COVER','MILLSTONE','SLAB','STATUE','TABLE','TOOL','TRAPPARTS','WEAPONRACK','WINDOW','HELM','ARMOR','PANTS','SHOES','GLOVES','ITEM_TRAPCOMP:ITEM_TRAPCOMP_ENORMOUSCORKSCREW','ITEM_TRAPCOMP:ITEM_TRAPCOMP_MENACINGSPIKE','ITEM_TRAPCOMP:ITEM_TRAPCOMP_SPIKEDBALL','ITEM_TRAPCOMP:ITEM_TRAPCOMP_LARGESERRATEDDISC'}
items['farmer'] = {'PLANT','SEEDS'}
items['furnaceoperator'] = {'BAR','BOULDER'}
items['glassmaker'] = {'GOBLET','PIPE_SECTION','ITEM_TRAPCOMP:ITEM_TRAPCOMP_ENORMOUSCORKSCREW','ITEM_TRAPCOMP:ITEM_TRAPCOMP_LARGESERRATEDDISC','ARMORSTAND','BLOCKS','BOX','BUCKET','CABINET','CAGE','CHAIN','CHAIR','COFFIN','DOOR','HATCH_COVER','STATUE','TABLE','TOOL','WEAPONRACK'}
items['greedy'] = {'FIGURINE','AMULET','SCEPTER','CROWN','RING','EARRING','BRACELET','GEM'}
items['jeweler'] = {'ROUGH','SMALLGEM','GEM'}
items['leatherworker'] = {'SKIN_TANNED'}
items['mason'] = {'BOULDER','BLOCKS','BOX','CABINET','CHAIR','COFFIN','DOOR','HATCH_COVER','MILLSTONE','SLAB','STATUE','TABLE','TOOL','WEAPONRACK','ARMORSTAND'}
items['mechanic'] = {'TRACTION_BENCH','ITEM_TRAPCOMP:ITEM_TRAPCOMP_LARGESERRATEDDISC','ITEM_TRAPCOMP:ITEM_TRAPCOMP_ENORMOUSCORKSCREW','ITEM_TRAPCOMP:ITEM_TRAPCOMP_MENACINGSPIKE','ITEM_TRAPCOMP:ITEM_TRAPCOMP_SPIKEDBALL'}
items['metalcrafter'] = {'BAR','ANVIL','GOBLET','FIGURINE','AMULET','SCEPTER','CROWN','RING','EARRING','BRACELET','TOY'}
items['miller'] = {'POWDER_MISC','GLOB','PLANT','SEEDS'}
items['miner'] = {'BOULDER','ITEM_WEAPON:ITEM_WEAPON_PICK'}
items['papermaker'] = {'BOOK','SHEET'}
items['potter'] = {'ITEM_TOOL:ITEM_TOOL_LARGE_POT','ITEM_TOOL:ITEM_TOOL_JUG','BAR','BOULDER','FIGURINE','AMULET','SCEPTER','CROWN','RING','EARRING','BRACELET','TOY'}
items['scholar'] = {'BOOK','SHEET','TABLE','CHAIR','ITEM_TOOL:ITEM_TOOL_BOOKCASE'}
items['soldier'] = {'ITEM_WEAPON:ITEM_WEAPON_HAMMER_WAR','ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE','ITEM_WEAPON:ITEM_WEAPON_SPEAR','ITEM_WEAPON:ITEM_WEAPON_MACE','ITEM_WEAPON:ITEM_WEAPON_CROSSBOW','ITEM_WEAPON:ITEM_WEAPON_SWORD_SHORT','ITEM_AMMO:ITEM_AMMO_BOLTS','ITEM_SHIELD:ITEM_SHIELD_SHIELD','QUIVER','FLASK','BACKPACK'}
items['stonecrafter'] = {'ITEM_TOOL:ITEM_TOOL_NEST_BOX','ITEM_TOOL:ITEM_TOOL_JUG','ITEM_TOOL:ITEM_TOOL_HIVE','ITEM_TOOL:ITEM_TOOL_LARGE_POT','INSTRUMENT','GOBLET','FIGURINE','AMULET','SCEPTER','CROWN','RING','EARRING','BRACELET','TOY'}
items['thresher'] = {'PLANT','SEEDS','THREAD','BOX','BARREL','ITEM_TOOL:ITEM_TOOL_JUG'}
items['weaponsmith'] = {'ITEM_WEAPON:ITEM_WEAPON_PICK','ITEM_WEAPON:ITEM_WEAPON_HAMMER_WAR','ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE','ITEM_WEAPON:ITEM_WEAPON_SPEAR','ITEM_WEAPON:ITEM_WEAPON_MACE','ITEM_WEAPON:ITEM_WEAPON_CROSSBOW','ITEM_WEAPON:ITEM_WEAPON_SWORD_SHORT','ITEM_AMMO:ITEM_AMMO_BOLTS','BAR','ANVIL'}
items['weaver'] = {'CLOTH','THREAD','POWDER_MISC'}
items['woodburner'] = {'BAR','WOOD'}
items['woodcrafter'] = {'GOBLET','FIGURINE','AMULET','SCEPTER','CROWN','RING','EARRING','BRACELET','TOY'}
items['woodcutter'] = {'ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE','WOOD'}
items['mood-armorstand'] = {'ARMORSTAND'}
items['mood-axe'] = {'ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE'}
items['mood-bed'] = {'BED'}
items['mood-box'] = {'BOX'}
items['mood-breastplate'] = {'ITEM_ARMOR:ITEM_ARMOR_BREASTPLATE'}
items['mood-cabinet'] = {'CABINET'}
items['mood-chain'] = {'CHAIN'}
items['mood-crossbow'] = {'ITEM_WEAPON:ITEM_WEAPON_CROSSBOW'}
items['mood-door'] = {'DOOR'}
items['mood-gear'] = {'TRAPPARTS'}
items['mood-hammer'] = {'ITEM_WEAPON:ITEM_WEAPON_HAMMER_WAR'}
items['mood-instrument'] = {'INSTRUMENT'}
items['mood-mace'] = {'ITEM_WEAPON:ITEM_WEAPON_MACE'}
items['mood-shield'] = {'ITEM_SHIELD:ITEM_SHIELD_SHIELD'}
items['mood-spear'] = {'ITEM_WEAPON:ITEM_WEAPON_SPEAR'}
items['mood-statue'] = {'STATUE'}
items['mood-sword'] = {'ITEM_WEAPON:ITEM_WEAPON_SWORD_SHORT'}
items['mood-table'] = {'TABLE'}
items['mood-throne'] = {'CHAIR'}
items['mood-weaponrack'] = {'WEAPONRACK'}
plants['farmer'] = {'MUSHROOM_HELMET_PLUMP','GRASS_TAIL_PIG','GRASS_WHEAT_CAVE','POD_SWEET','BUSH_QUARRY','MUSHROOM_CUP_DIMPLE','BERRY_SUN','VINE_WHIP','REED_ROPE','HEMP'}
plants['papermaker'] = {'GRASS_TAIL_PIG','REED_ROPE','HEMP','KENAF','JUTE','PAPYRUS_SEDGE','COTTON','RAMIE','FLAX'}
plants['brewer'] = {'MUSHROOM_HELMET_PLUMP','BERRY_SUN','VINE_WHIP','REED_ROPE','POD_SWEET','GRASS_WHEAT_CAVE','GRASS_TAIL_PIG'}
plants['miller'] = {'VINE_WHIP','POD_SWEET','GRASS_WHEAT_CAVE','GRASS_TAIL_PIG','MUSHROOM_CUP_DIMPLE','HEMP'}
plants['thresher'] = {'GRASS_TAIL_PIG','POD_SWEET','BUSH_QUARRY','REED_ROPE','HEMP','KENAF','JUTE','COTTON','RAMIE','FLAX','HERB_VALLEY'}
colors['everyone'] = {'MIDNIGHT_BLUE','EMERALD','RED','BLACK'}
colors['noble'] = {'MIDNIGHT_BLUE'}
foods['everyone'] = {'CREATURE:CRUNDLE:MUSCLE','CREATURE:CROCODILE_CAVE:MUSCLE','CREATURE:SHEEP:CHEESE','PLANT:REED_ROPE:DRINK','PLANT:BERRIES_STRAW:DRINK','PLANT:BERRY_SUN:DRINK','PLANT:GRASS_LONGLAND:DRINK','PLANT:GRASS_LONGLAND:MILL','PLANT:VINE_WHIP:DRINK','PLANT:VINE_WHIP:MILL','CREATURE:HONEY_BEE:MEAD','PLANT:MUSHROOM_HELMET_PLUMP','PLANT:MUSHROOM_HELMET_PLUMP:DRINK','PLANT:BUSH_QUARRY:LEAF','PLANT:BUSH_QUARRY:SEED','PLANT:POD_SWEET:MILL','PLANT:POD_SWEET:EXTRACT','PLANT:GRASS_WHEAT_CAVE:MILL','PLANT:GRASS_WHEAT_CAVE:DRINK','PLANT:GRASS_TAIL_PIG:DRINK'}
foods['noble'] = {'CREATURE:CRUNDLE:MUSCLE','CREATURE:CROCODILE_CAVE:MUSCLE','CREATURE:SHEEP:CHEESE','PLANT:REED_ROPE:DRINK','PLANT:BERRIES_STRAW:DRINK','PLANT:BERRY_SUN:DRINK','PLANT:GRASS_LONGLAND:DRINK','PLANT:GRASS_LONGLAND:MILL','PLANT:VINE_WHIP:DRINK','PLANT:VINE_WHIP:MILL','CREATURE:HONEY_BEE:MEAD','PLANT:MUSHROOM_HELMET_PLUMP','PLANT:MUSHROOM_HELMET_PLUMP:DRINK','PLANT:BUSH_QUARRY:LEAF','PLANT:BUSH_QUARRY:SEED','PLANT:POD_SWEET:MILL','PLANT:POD_SWEET:EXTRACT','PLANT:GRASS_WHEAT_CAVE:MILL','PLANT:GRASS_WHEAT_CAVE:DRINK','PLANT:GRASS_TAIL_PIG:DRINK'}
creatures['everyone'] = {'BIRD_TURKEY','BIRD_GOOSE','FLY','FLY_ACORN','SHEEP'}
creatures['noble'] = {'DOG','CAT','PIG','BIRD_TURKEY','BIRD_GOOSE','FLY','FLY_ACORN','SHEEP','CRUNDLE','CROCODILE_CAVE'}
hates['child'] = {'NIGHT_CREATURE_20'}

        --I could probably rewrite this to eliminate the big_job_list now that
        --I have job_alias, but I can only rewrite this thing so many times.

local big_job_list={'armorsmith','blacksmith','bonecarver','bowyer','brewer','carpenter',
                    'child','clothier','cook','doctor','dyer','engraver','everyone','farmer',
                    'furnaceoperator','glassmaker','greedy','jeweler','leatherworker','mason',
                    'mechanic','metalcrafter','noble','miller','miner','papermaker','potter',
                    'scholar','soldier','stonecrafter','thresher','weaponsmith','weaver',
                    'woodburner','woodcrafter','woodcutter','mood-armorstand','mood-axe',
                    'mood-bed','mood-box','mood-breastplate','mood-cabinet','mood-chain',
                    'mood-crossbow','mood-door','mood-gear','mood-hammer','mood-instrument',
                    'mood-mace','mood-shield','mood-spear','mood-statue','mood-sword','mood-table',
                    'mood-throne','mood-weaponrack'}

local pref_types = {}
pref_types['names'] = {'material','color','shape','item','food','plant','tree','creature','hate'}
pref_types['data'] = {materials,colors,shapes,items,foods,plants,trees,creatures,hates}
pref_types['output_args'] = {'likematerial','likecolor','likeshape','likeitem','likefood','likeplant','liketree','likecreature','hatecreature'}
pref_types['output_prefs'] = {{},{},{},{},{},{},{},{},{}}

      --[[  job_alias:
            This is just for abbreviations for the job names, but an entry here
            does need to exist for any custom profiles you may create.
      --]]

local job_alias = {}
job_alias['armorsmith'] = {'armorsmith','as','armorer','armoring','armor','ar'}
job_alias['blacksmith'] = {'blacksmith','bs','ms','metalsmith','blacksmithing','metalsmithing'}
job_alias['bonecarver'] = {'bonecarver','bc','bon','boner','bonecarving','bone'}
job_alias['bowyer'] = {'bowyer','bo','bow'}
job_alias['brewer'] = {'brewer','br','brew'}
job_alias['carpenter'] = {'carpenter','ca','carpentry'}
job_alias['child'] = {'child','ch','children','baby','kid','brat','foulspawnofthedarkpits'}
job_alias['clothier'] = {'clothier','cl','clothesmaker','clothesmaking'}
job_alias['cook'] = {'cook','co','chef'}
job_alias['doctor'] = {'doctor','do','doc'}
job_alias['dyer'] = {'dyer','dy','dye','dyeing','dying'}
job_alias['engraver'] = {'engraver','en','engraving'}
job_alias['everyone'] = {'everyone','e', 'ev','everybody'}
job_alias['farmer'] = {'farmer','fa','farming','planter','planting','farm'}
job_alias['furnaceoperator'] = {'furnaceoperator','fu','furnace'}
job_alias['glassmaker'] = {'glassmaker','gl','glassmaking','glazier','glass'}
job_alias['greedy'] = {'greedy','gr','acquire','greed'}
job_alias['jeweler'] = {'jeweler','je','gc','gs','gemcutter','gemsetter'}
job_alias['leatherworker'] = {'leatherworker','le','leather','leatherworking'}
job_alias['mason'] = {'mason','ma','masonry','stonecutting','worldruler'}
job_alias['mechanic'] = {'mechanic','me','mech','mechanics'}
job_alias['metalcrafter'] = {'metalcrafter','mc','metalcrafting'}
job_alias['miller'] = {'miller','mill','milling'}
job_alias['miner'] = {'miner','min','mining','digger','diggydiggyhole'}
job_alias['noble'] = {'noble','no','nob'}
job_alias['papermaker'] = {'papermaker','pa','papermaking','paper'}
job_alias['potter'] = {'potter','po','pot','glazer'}
job_alias['scholar'] = {'scholar','sc','scribe','monk'}
job_alias['soldier'] = {'soldier','so','mil','military','fighter','draftee','meatshield'}
job_alias['stonecrafter'] = {'stonecrafter','sc','stonecrafting','scraft'}
job_alias['thresher'] = {'thresher','th','plantprocessor'}
job_alias['weaponsmith'] = {'weaponsmith','ws','weaponsmithing','wep'}
job_alias['weaver'] = {'weaver','we','weaving','loom','glitterglue'}
job_alias['woodburner'] = {'woodburner','wb','woodburning'}
job_alias['woodcrafter'] = {'woodcrafter','wcraft','woodcrafting'}
job_alias['woodcutter'] = {'woodcutter','wc','woodcutting'}
job_alias['mood-armorstand'] = {'mood-armorstand','m-as'}
job_alias['mood-axe'] = {'mood-axe','m-a'}
job_alias['mood-bed'] = {'mood-bed','m-bed'}
job_alias['mood-box'] = {'mood-box','m-h'}
job_alias['mood-breastplate'] = {'mood-breastplate','m-b'}
job_alias['mood-cabinet'] = {'mood-cabinet','m-f'}
job_alias['mood-chain'] = {'mood-chain','m-v'}
job_alias['mood-crossbow'] = {'mood-crossbow','m-c'}
job_alias['mood-door'] = {'mood-door','m-d'}
job_alias['mood-gear'] = {'mood-gear','m-g'}
job_alias['mood-hammer'] = {'mood-hammer','m-ha'}
job_alias['mood-instrument'] = {'mood-instrument','m-i'} --for engravers
job_alias['mood-mace'] = {'mood-mace','m-ma'}
job_alias['mood-shield'] = {'mood-shield','m-sh'}
job_alias['mood-spear'] = {'mood-spear','m-sp'}
job_alias['mood-statue'] = {'mood-statue','m-s'}
job_alias['mood-sword'] = {'mood-sword','m-sw'}
job_alias['mood-table'] = {'mood-table','m-t'}
job_alias['mood-throne'] = {'mood-throne','m-r'}
job_alias['mood-weaponrack'] = {'mood-weaponrack','m-w'}

-- ------------------------------------------------------ UTILITY ------------------------------------------------------- --

-- --------------------------------------------------- REMOVE_DUPES ----------------------------------------------------- --
local function remove_dupes(sometable)  --Thank you, Stack Overflow.

    local hash = {}
    local res = {}

    for _,v in ipairs(sometable) do
       if (not hash[v]) then
           res[#res+1] = v
           hash[v] = true
       end

    end
    return res
end

-- --------------------------------------------------- PRINT_YELLOW ----------------------------------------------------- --
local function print_yellow(text)       --Lifted directly from assign-preferences.lua
    dfhack.color(COLOR_YELLOW)
    print(text)
    dfhack.color(-1)
end



----------------------- PROCESS_UNIT -------------------------------
local function process_unit(unit)
    local unitnum

    if unit then
        unitnum = tonumber(unit)

        if (not unitnum) and opts.unit then
            print_yellow("'" .. unit .. "' is not a valid unit ID.")
            opts.action = "die"
            return
        end
    else
        local tempunit = dfhack.gui.getSelectedUnit(true)

        if not tempunit then
            print_yellow("No unit specified or selected with [v]iew in Dwarf Fortress. Aborting.")
            opts.action = "die"
            return
        else
            unit = tempunit.id
        end

        unitnum = tonumber(unit)
    end

    local unitobj = df.unit.find(unitnum)

    if not unitobj then
        print_yellow("Cannot find unit " .. unit .. ".")
        opts.action = "die"
        return
    end

    opts.unitname = dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unitobj)))
    if not opts.silent then
        print("Identified target " .. opts.unitname .. ".")
    end
    return unit
end

----- ------------------------------------------------- PRINT_ALIASES -------------------------------------------------- --
local function print_aliases()
    local aliases_formatted = {}

    print("\nProfile names   Aliases")
    print("=============   ====================================================================")

    for _,v in ipairs(big_job_list) do
        for j,w in pairs(job_alias[v]) do
            if #w > 9 then
                aliases_formatted[j] = w
            else
                aliases_formatted[j] = w .. string.rep(" ",9-#w)
            end
        end
        print(table.concat(aliases_formatted,"\t"))
        for k, _ in pairs(aliases_formatted) do
            aliases_formatted[k]= nil
        end
    end
    return
end

----------------------- GET_ALL_UNITS -------------------------------
local function get_all_units()
    local ret = {}
    for _, thisunit in ipairs(df.global.world.units.all) do
        if dfhack.units.isCitizen(thisunit) then
            table.insert(ret,tostring(thisunit.id))
        end
    end
    return ret
end

----------------------- VALIDATE_UNIT_OPTS -------------------------------
local function validate_unit_opts()
    if opts.unit then
        if opts.all then
            print_yellow("Option \'--unit\' conflicts with option \'--all\'.")
            opts.action = "die"
            return
        elseif opts.preview then
            print_yellow("Preview is hypothetical. Ignoring option \'--unit\'.")
            opts.unit = false
            return
        else
            process_unit(opts.unit)
        end
    elseif not opts.all then
        if not opts.preview then
            opts.unit = process_unit() -- looking for a selected unit
            unit=opts.unit
        end
    elseif opts.all then
        if opts.preview then
            print_yellow("Preview is hypothetical. Ignoring option \'--all\'.")
            opts.all = false
        else
            unit = "all"
            opts.allunits = {}
            opts.allunits = get_all_units()
        end
    end
    return unit
end

----------------------- VALIDATE_RESET -------------------------------
local function validate_reset()
    if opts.jobs then
        print_yellow("Option \'--reset\' comes free with \'--jobs\'. Ignoring.")
    elseif opts.preview then
        print_yellow("Option \'--reset\' doesn't do anything with \'--preview\'. Ignoring.")
    elseif opts.addjobs then
    else
        opts.action = "reset"
    end
    return
end
----------------------- VALIDATE_ACTION_OPTS -------------------------------
local function validate_action_opts()
    if opts.jobs then
        if opts.addjobs or opts.preview then
            print_yellow("Can't use options \'--jobs\' with  \'--addjobs\' or  \'--preview\'.")
            opts.action = "die"
        else
            opts.action = "jobs"
            opts.needprefs = true
        end
    elseif opts.preview then
        if opts.addjobs then
            print_yellow("Can't use options \'--addjobs\' and  \'--preview\' together.")
            opts.action = "die"
        else
            opts.action = "preview"
            opts.needprefs = true
        end
    elseif opts.addjobs then
        opts.action = "addjobs"
        opts.needprefs = true
    end
    return
end


-------------------------- PROCESS_ARGS -------------------------------

local function process_args(args)

    if args[1] == "help" then
        opts.help = true
        opts.action = "die"
        return
    end

    local positionals = utils.processArgsGetopt(args,{
        {'j','jobs',hasArg=true, handler=function(optargs) opts.jobs = optargs end },
        {'a','addjobs',hasArg=true, handler=function(optargs) opts.addjobs = optargs end },
        {'p','preview',hasArg=true, handler=function(optargs) opts.preview = optargs end },
        {'u','unit',hasArg=true, handler=function(optargs) opts.unit = optargs end },
        {'','all', handler=function() opts.all = true end },
        {'r','reset', handler=function() opts.reset = true end },
        {'h','help',handler=function() opts.help = true end },
        {'x','syntax',handler=function() opts.syntax = true end },
        {'t','tips',handler=function() opts.tips = true end },
        {'l','list',handler=function() opts.list = true end },
        {'n','nicknames',handler=function() opts.aliases = true end },
        {'s','silent',handler=function() opts.silent = true end }
        })

    if opts.help or opts.tips or opts.list or opts.aliases or opts.syntax then
        return
    end

    return positionals
end

-- ------------------------------------------------------ DO_RESET ------------------------------------------------------ --
local function do_reset(str_unit)

    if str_unit == "all" then
        print("This will remove all preferences for all units.")
        for _,v in ipairs(opts.allunits) do
            local unitthing = df.unit.find(tonumber(v))
            local unitname = dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unitthing)))
            if not opts.silent then
                print("All existing preferences will be removed from " .. unitname .. ".")
            end

            dfhack.run_script("assign-preferences","-unit",tostring(v),"-reset")
        end
    else

        local unitthing = df.unit.find(tonumber(unit))
        local unitname = dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unitthing)))
        if not opts.silent then
            print("All existing preferences will be removed from " .. unitname .. ".")
        end

        dfhack.run_script("assign-preferences","-unit",tostring(unit),"-reset")

    end
    return
end

-- ------------------------------------------------------ GET_JOB_LIST ------------------------------------------------------ --
local function get_job_list(optargs)
    local ret = argparse.stringList(optargs)
    return ret
end

-- ------------------------------------------------------ GET_PREFERENCES ------------------------------------------------------ --
local function get_preferences(jobs_list,everyone)

    for i,v in ipairs(jobs_list) do                             --Replace all aliases with the real names.
        for _,w in ipairs(big_job_list) do
            for _,alias in pairs(job_alias[w]) do
                if v == alias then
                    jobs_list[i] = job_alias[w][1]
                end
            end
        end
    end

    for _,v in pairs(jobs_list) do                           --noble check
       if v=='noble' then
            everyone = false
            for _,w in ipairs(big_job_list) do
                for _,x in pairs(jobs_list) do               --it's lonely at the top
                    if (w == x) and not (x == 'noble') then
                        print_yellow("The \'noble\' profile cannot be combined with other profiles.")
                        return
                    end
                end
            end
        end
    end

    local ret = {}

    if everyone then                                                            --for --jobs, which implies "everyone" without including it as an arg
        for _,v in ipairs(jobs_list) do
            if v == "everyone" then
                everyone = false
            end
        end
        if everyone then
            table.insert(jobs_list,"everyone")
        end
    end

    for _,v in pairs(jobs_list) do                                              --loop through jobs supplied in args, let's try with 'carpenter'
        if not job_alias[v] then                                                --job_alias['carpenter'] exists, so we're ok
            print_yellow("\""..v.."\"".." doesn\'t seem to be a valid job.")
            ret = nil
            return
        end

        if not opts.silent then
            print("Compiling preferences for \'" .. v .. "\' profile.")
        end
        for index,datatable in ipairs(pref_types['data']) do                     --starts with 1,materials
            local counter = 1

            if datatable[v] then                                                --materials['carpenter'] exists, it's some woods
                for _, w in pairs(datatable[v]) do                              --1,'PLANT_MAT:TOWER_CAP:WOOD'
                    table.insert(pref_types['output_prefs'][index],counter,w)          --pref_types['prefs'][1] == material_prefs; material_prefs[1] == 'PLANT_MAT:TOWER_CAP:WOOD'
                    counter=counter+1                                           --2
                    ret[pref_types['names'][index]] = pref_types['output_prefs'][index]
                end

            end                                                                 --go on to items
        end
    end

    return ret
end

-- ------------------------------------------------------ DO_PREVIEW ------------------------------------------------------ --
local function do_preview(jobs_list,everyone)

    local preferences=get_preferences(jobs_list,everyone)

    if not preferences then
        return
    end

    local clean_prefs = {}
    for _,prefname in ipairs(pref_types['names']) do
        if preferences[prefname] then
            clean_prefs[prefname] = remove_dupes(preferences[prefname])
            print("\n" .. prefname:gsub("^%l", string.upper).."s: \n"..string.rep("=",#prefname+2).."\n\t\t"..table.concat(clean_prefs[prefname],'\n\t\t'))
        end
    end

    return
end

-- ---------------------------------------------------- DO_PREFS ---------------------------------------------------- --
local function do_prefs(jobs_list,unit,reset,everyone)
    local assign_cmd = {}
    local prefcounter = 0
    local reset_pending = reset

    local getpreferences=get_preferences(jobs_list,everyone)   --get those prefs

    if not getpreferences then              --in case we need to die.
        return
    end

    local preferences = {}


    for i,prefname in ipairs(pref_types['names']) do                --looking through the preference categories again
        local cmd_counter = 1

        if getpreferences[prefname] then
            preferences[prefname] = remove_dupes(getpreferences[prefname])  --dedupe

            assign_cmd[prefname] = {}
            assign_cmd[prefname][cmd_counter] = "assign-preferences"    --assign_cmd['material'][1] == "assign-preferences"
            cmd_counter = cmd_counter + 1

            if reset and reset_pending then                             --put this in the first time only, or we'll end up
                assign_cmd[prefname][cmd_counter] = "-reset"            --with nothing
                cmd_counter = cmd_counter + 1
                if not opts.silent then
                    print("Clearing existing preferences.")
                end
                reset_pending = false
            end

            assign_cmd[prefname][cmd_counter] = "-unit"
            cmd_counter = cmd_counter + 1
            assign_cmd[prefname][cmd_counter] = tostring(unit)
            cmd_counter = cmd_counter + 1

            assign_cmd[prefname][cmd_counter] = "-" .. pref_types['output_args'][i]     --assign_cmd['material'][2-5,depending] = "-likematerial"
            cmd_counter = cmd_counter + 1
            assign_cmd[prefname][cmd_counter] = "["
            cmd_counter = cmd_counter + 1
            for _,v in ipairs(preferences[prefname]) do
                table.insert(assign_cmd[prefname],cmd_counter,v)                        --adding the preferences
                cmd_counter = cmd_counter + 1
                prefcounter = prefcounter + 1
            end
            assign_cmd[prefname][cmd_counter] = "]"
            cmd_counter = cmd_counter + 1

            dfhack.run_script(table.unpack(assign_cmd[prefname]))
        end
    end
    local unitthing = df.unit.find(unit)
    local unitname = dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unitthing)))
    if not opts.silent then
        print("Added " .. prefcounter .. " preferences to " .. unitname .. ".")
    end
    return
end
-------------------------- DO_ACTIONS -----------------------------
local function do_actions(job_list)
    if opts.all then
        --opts.silent = true
        if opts.action == "jobs" then
            for _,v in ipairs(opts.allunits) do
                do_prefs(job_list,v,true,true)
            end
        elseif opts.action == "addjobs" then
            for _,v in ipairs(opts.allunits) do
                do_prefs(job_list,v,opts.reset,false)
            end
        else
            print_yellow("You should not have gotten here.")
        end
    else
        if opts.action == "jobs" then
            do_prefs(job_list,opts.unit,true,true)
        elseif opts.action == "addjobs" then
            do_prefs(job_list,opts.unit,opts.reset,false)
        elseif opts.action == "preview" then
            do_preview(job_list)
        else
            print_yellow("You should not have gotten here.")
        end
    end
end
-------------------------- MAIN -------------------------------

local function main(...)
    local positionals = process_args({...})

    if positionals ~= nil and #positionals > 0 then
        print(shorthelp)
        return
    end

    if opts.help then
        print(help)
        return
    elseif opts.tips then
        print(tips)
        return
    elseif opts.list then
        print(list)
        return
    elseif opts.aliases then
        print_aliases()
        return
    elseif opts.syntax then
        print(shorthelp)
        return
    else
        opts.unit = validate_unit_opts()
        if opts.action == "die" then
            return
        end
        if opts.reset then
            validate_reset()
        end
        if opts.jobs or opts.addjobs or opts.preview then
            validate_action_opts()
        elseif opts.reset then
        else
            print(shorthelp)
            return
        end
    end

    if opts.action == "die" then
        return
    end

    if opts.action == "reset" then
        do_reset(opts.unit)
        return
    end

    local job_list = get_job_list(opts.jobs or opts.addjobs or opts.preview)

    if not opts.action then
        print_yellow("Give me something to do!")
        return
    elseif opts.needprefs then
        do_actions(job_list)
    else
        print_yellow("This should not have happened.")
    end
    return
end
-----------------------------------------------------------------------
if not dfhack_flags.module then
    main(...)
end

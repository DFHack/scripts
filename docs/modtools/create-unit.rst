modtools/create-unit
====================

.. dfhack-tool::
    :summary: Create arbitrary units.
    :tags: unavailable

Creates a unit.

Usage
-----

::

    -race raceName
        (obligatory)
        Specify the race of the unit to be created.
        examples:
            DWARF
            HUMAN

    -caste casteName
        Specify the caste of the unit to be created.
        If omitted, the caste is randomly selected.
        examples:
            MALE
            FEMALE
            DEFAULT

    -domesticate
        Tames the unit if it lacks the CAN_LEARN and CAN_SPEAK tokens.

    -civId id
        Make the created unit a member of the specified civilisation
        (or none if id = -1).  If id is \\LOCAL, make it a member of the
        civ associated with the fort; otherwise id must be an integer

    -groupId id
        Make the created unit a member of the specified group
        (or none if id = -1).  If id is \\LOCAL, make it a member of the
        group associated with the fort; otherwise id must be an integer

    -setUnitToFort
        Sets the groupId and civId to those of the player in Fortress mode.
        Equivalent to -civId \\LOCAL and -groupId \\LOCAL.

    -name entityRawName
        Set the unit's name to be a random name appropriate for the
        given entity. \\LOCAL can be specified instead to automatically
        use the fort group entity in fortress mode only. Can be passed
        empty to generate a wild name (random language, any words), i.e.
        the type of name that animal people historical figures have.
        examples:
            MOUNTAIN
            EVIL

    -nick nickname
        This can be included to nickname the unit.
        Replace "nickname" with the desired name.

    -age howOld
        This can be included to specify the unit's age.
        Replace "howOld" with a (non-negative) number.
        The unit's age is set randomly if this is omitted.

    -equip [ ITEM:MATERIAL:QUANTITY ... ]
        This can be included to create items and equip them onto
            the created unit.
        This is carried out via the same logic used in arena mode,
            so equipment will always be sized correctly and placed
            on what the game deems to be appropriate bodyparts.
            Clothing is also layered in the appropriate order.
        Note that this currently comes with some limitations,
            such as an inability to specify item quality
            and objects not being placed in containers
            (for example, arrows are not placed in quivers).
        Item quantity defaults to 1 if omitted.
        When spaces are included in the item or material name,
            the entire item description should be enclosed in
            quotation marks. This can also be done to increase
            legibility when specifying multiple items.
        examples:
            -equip [ RING:CREATURE:DWARF:BONE:3 ]
                3 dwarf bone rings
            -equip [ ITEM_WEAPON_PICK:INORGANIC:IRON ]
                1 iron pick
            -equip [ "ITEM_SHIELD_BUCKLER:PLANT:OAK:WOOD" "AMULET:AMBER" ]
                1 oaken buckler and 1 amber amulet

    -skills [ SKILL:LEVEL ... ]
        This can be included to add skills to the created unit.
        Specify a skill token followed by a skill level value.
        Look up "Skill Token" and "Skill" on the DF Wiki for a list
            of valid tokens and levels respectively.
        Note that the skill level provided must be a number greater than 0.
        If the unit possesses a matching natural skill, this is added to it.
        Quotation marks can be added for legibility as explained above.
        example:
            -skill [ SNEAK:1 EXTRACT_STRAND:15 ]
                novice ambusher, legendary strand extractor

    -profession token
        This can be included to set the unit's profession.
        Replace "token" with a Unit Type Token (check the DF Wiki for a list).
        For skill-based professions, it is recommended to give the unit
            the appropriate skill set via -skills.
        This can also be used to make animals trained for war/hunting.
        Note that this will be overridden if the unit has been given the age
            of a baby or child, as these have a special "profession" set.
        Using this for setting baby/child status is not recommended;
            this should be done via -age instead.
        examples:
            STRAND_EXTRACTOR
            MASTER_SWORDSMAN
            TRAINED_WAR

    -customProfession name
        This can be included to give the unit a custom profession name.
        Enclose the name in quotation marks if it includes spaces.
        example:
            -customProfession "Destroyer of Worlds"

    -duration ticks
        If this is included, the unit will vanish in a puff of smoke
            once the specified number of ticks has elapsed.
        Replace "ticks" with an integer greater than 0.
        Note that the unit's equipment will not vanish.

    -quantity howMany
        This can be included to create multiple creatures simultaneously.
        Replace "howMany" with the desired number of creatures.
        Quantity defaults to 1 if this is omitted.

    -location [ x y z ]
        (obligatory)
        Specify the coordinates where you want the unit to appear.

    -locationRange [ x_offset y_offset z_offset ]
        If included, the unit will be spawned at a random location
            within the specified range relative to the target -location.
        z_offset defaults to 0 if omitted.
        When creating multiple units, the location is randomised each time.
        example:
            -locationRange [ 4 3 1 ]
                attempts to place the unit anywhere within
                -4 to +4 tiles on the x-axis
                -3 to +3 tiles on the y-axis
                -1 to +1 tiles on the z-axis
                from the specified -location coordinates

    -locationType type
        May be used with -locationRange
            to specify what counts as a valid tile for unit spawning.
        Unit creation will not occur if no valid tiles are available.
        Replace "type" with one of the following:
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
        This can be used to set the specified unit flags to true.
        Flags may be selected from:
            df.unit_flags1
            df.unit_flags2
            df.unit_flags3
            df.unit_flags4
        example:
            flagSet [ announce_titan ]
                causes an announcement describing the unit to appear
                when it is discovered ("[Unit] has come! ...")

    -flagClear [ flag1 flag2 ... ]
        As above, but sets the specified unit flags to false.

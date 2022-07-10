
assign-preferences
==================
A script to change the preferences of a unit.

Preferences are classified into 12 types. The first 9 are:

* like material;
* like creature;
* like food;
* hate creature;
* like item;
* like plant;
* like tree;
* like colour;
* like shape.

These can be changed using this script.

The remaining three are not currently managed by this script,
and are: like poetic form, like musical form, like dance form.

To produce the correct description in the "thoughts and preferences"
page, you must specify the particular type of preference. For
each type, a description is provided in the section below.

You will need to know the token of the object you want your dwarf to like.
You can find them in the wiki, otherwise in the folder "/raw/objects/" under
the main DF directory you will find all the raws defined in the game.

For more information:
https://dwarffortresswiki.org/index.php/DF2014:Preferences

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

``-likematerial [ <TOKEN> <TOKEN> <...> ]``:
                    usually a type of stone, a type of metal and a type
                    of gem, plus it can also be a type of wood, a type of
                    glass, a type of leather, a type of horn, a type of
                    pearl, a type of ivory, a decoration material - coral
                    or amber, a type of bone, a type of shell, a type
                    of silk, a type of yarn, or a type of plant cloth.
                    Write the full tokens.
                    There must be a space before and after each square
                    bracket.

``-likecreature [ <TOKEN> <TOKEN> <...> ]``:
                    one or more creatures liked by the unit. You can
                    just list the species: the creature token will be
                    something similar to ``CREATURE:SPARROW:SKIN``,
                    so the name of the species will be ``SPARROW``. Nothing
                    will stop you to write the full token, if you want: the
                    script will just ignore the first and the last parts.
                    There must be a space before and after each square
                    bracket.

``-likefood [ <TOKEN> <TOKEN> <...> ]``:
                    usually a type of alcohol, plus it can be a type of
                    meat, a type of fish, a type of cheese, a type of edible
                    plant, a cookable plant/creature extract, a cookable
                    mill powder, a cookable plant seed or a cookable plant
                    leaf. Write the full tokens.
                    There must be a space before and after each square
                    bracket.

``-hatecreature [ <TOKEN> <TOKEN> <...> ]``:
                    works the same way as ``-likecreature``, but this time
                    it's one or more creatures that the unit detests. They
                    should be a type of ``HATEABLE`` vermin which isn't already
                    explicitly liked, but no check is performed about this.
                    Like before, you can just list the creature species.
                    There must be a space before and after each square
                    bracket.

``-likeitem [ <TOKEN> <TOKEN> <...> ]``:
                    a kind of weapon, a kind of ammo, a kind of piece of
                    armor, a piece of clothing (including backpacks or
                    quivers), a type of furniture (doors, floodgates, beds,
                    chairs, windows, cages, barrels, tables, coffins,
                    statues, boxes, armor stands, weapon racks, cabinets,
                    bins, hatch covers, grates, querns, millstones, traction
                    benches, or slabs), a kind of craft (figurines, amulets,
                    scepters, crowns, rings, earrings, bracelets, or large
                    gems), or a kind of miscellaneous item (catapult parts,
                    ballista parts, a type of siege ammo, a trap component,
                    coins, anvils, totems, chains, flasks, goblets,
                    buckets, animal traps, an instrument, a toy, splints,
                    crutches, or a tool). The item tokens can be found here:
                    https://dwarffortresswiki.org/index.php/DF2014:Item_token
                    If you want to specify an item subtype, look into the files
                    listed under the column "Subtype" of the wiki page (they are
                    in the "/raw/ojects/" folder), then specify the items using
                    the full tokens found in those files (see examples below).
                    There must be a space before and after each square
                    bracket.

``-likeplant [ <TOKEN> <TOKEN> <...> ]``:
                    works in a similar way as ``-likecreature``, this time
                    with plants. You can just List the plant species (the
                    middle part of the token).
                    There must be a space before and after each square
                    bracket.

``-liketree [ <TOKEN> <TOKEN> <...> ]``:
                    works exactly as ``-likeplant``. I think this
                    preference type is here for backward compatibility (?).
                    You can still use it, however. As before,
                    you can just list the tree (plant) species.
                    There must be a space before and after each square
                    bracket.

``-likecolor [ <TOKEN> <TOKEN> <...> ]``:
                    you can find the color tokens here:
                    https://dwarffortresswiki.org/index.php/DF2014:Color#Color_tokens
                    or inside the "descriptor_color_standard.txt" file
                    (in the "/raw/ojects/" folder). You can use the full token or
                    just the color name.
                    There must be a space before and after each square
                    bracket.

``-likeshape [ <TOKEN> <TOKEN> <...> ]``:
                    I couldn't find a list of shape tokens in the wiki, but you
                    can find them inside the "descriptor_shape_standard.txt"
                    file (in the "/raw/ojects/" folder). You can
                    use the full token or just the shape name.
                    There must be a space before and after each square
                    bracket.

``-reset``:
                    clear all preferences. If the script is called
                    with both this option and one or more preferences,
                    first all the unit preferences will be cleared
                    and then the listed preferences will be added.

Examples:

* "likes alabaster and willow wood"::

    assign-preferences -reset -likematerial [ INORGANIC:ALABASTER PLANT:WILLOW:WOOD ]

* "likes sparrows for their ..."::

    assign-preferences -reset -likecreature SPARROW

* "prefers to consume dwarven wine and olives"::

    assign-preferences -reset -likefood [ PLANT:MUSHROOM_HELMET_PLUMP:DRINK PLANT:OLIVE:FRUIT ]

* "absolutely detests jumping spiders::

    assign-preferences -reset -hatecreature SPIDER_JUMPING

* "likes logs and battle axes"::

    assign-preferences -reset -likeitem [ WOOD ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE ]

* "likes straberry plants for their ..."::

    assign-preferences -reset -likeplant BERRIES_STRAW

* "likes oaks for their ..."::

    assign-preferences -reset -liketree OAK

* "likes the color aqua"::

    assign-preferences -reset -likecolor AQUA

* "likes stars"::

    assign-preferences -reset -likeshape STAR

assign-preferences
==================

.. dfhack-tool::
    :summary: Adjust a unit's preferences.
    :tags: fort armok units

You will need to know the token of the object you want your dwarf to like.
You can find them in the wiki, otherwise in the folder "/raw/objects/" under
the main DF directory you will find all the raws defined in the game.

For more information, please see the :wiki:`wiki <Preferences>`.

Note the last three types of preferences ("like poetic form", "like musical
form", and "like dance form") are not supported by this script.

Usage
-----

::

    assign-goals [--unit <id>] <options>

Examples
--------

* "likes alabaster and willow wood"::

    assign-preferences --reset --likematerial [ INORGANIC:ALABASTER PLANT:WILLOW:WOOD ]

* "likes sparrows for their ..."::

    assign-preferences --reset --likecreature SPARROW

* "prefers to consume dwarven wine, olives and yak"::

    assign-preferences --reset --likefood [ PLANT:MUSHROOM_HELMET_PLUMP:DRINK PLANT:OLIVE:FRUIT CREATURE_MAT:YAK:MUSCLE ]

* "absolutely detests jumping spiders::

    assign-preferences --reset --hatecreature SPIDER_JUMPING

* "likes logs and battle axes"::

    assign-preferences --reset --likeitem [ WOOD ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE ]

* "likes strawberry plants for their ..."::

    assign-preferences --reset --likeplant BERRIES_STRAW

* "likes oaks for their ..."::

    assign-preferences --reset --liketree OAK

* "likes the color aqua"::

    assign-preferences --reset --likecolor AQUA

* "likes stars"::

    assign-preferences --reset --likeshape STAR

Options
-------

For each of the parameters that take lists of tokens, if there is a space in the
token name, please replace it with an underscore. Also, there must be a space
before and after each square bracket. If only one value is provided, the square
brackets can be omitted.

``--unit <id>``
    The target unit ID. If not present, the currently selected unit will be the
    target.
``--likematerial [ <token> [<token> ...] ]``
    This is usually set to three tokens: a type of stone, a type of metal, and a
    type of gem. It can also be a type of wood, glass, leather, horn, pearl,
    ivory, a decoration material - coral or amber, bone, shell, silk, yarn, or
    cloth. Please include the full tokens, not just a part.
``--likecreature [ <token> [<token> ...] ]``
    For this preference, you can just list the species as the token. For
    example, a creature token can be something like ``CREATURE:SPARROW:SKIN``.
    Here, you can just say ``SPARROW``.
``--likefood [ <token> [<token> ...] ]``
    This usually contains at least a type of alcohol. It can also be a type of
    meat, fish, cheese, edible plant, cookable plant/creature extract, cookable
    mill powder, cookable plant seed, or cookable plant leaf. Please write the
    full tokens.
``--hatecreature [ <token> [<token> ...] ]``
    As in ``--likecreature`` above, you can just list the species in the token.
    The creature should be a type of ``HATEABLE`` vermin which isn't already
    explicitly liked, but no check is performed to enforce this.
``--likeitem [ <token> [<token> ...] ]``
    This can be a kind of weapon, a kind of ammo, a piece of armor, a piece of
    clothing (including backpacks or quivers), a type of furniture (doors,
    floodgates, beds, chairs, windows, cages, barrels, tables, coffins, statues,
    boxes, armor stands, weapon racks, cabinets, bins, hatch covers, grates,
    querns, millstones, traction benches, or slabs), a kind of craft (figurines,
    amulets, scepters, crowns, rings, earrings, bracelets, or large gems), or a
    kind of miscellaneous item (catapult parts, ballista parts, a type of siege
    ammo, a trap component, coins, anvils, totems, chains, flasks, goblets,
    buckets, animal traps, an instrument, a toy, splints, crutches, or a tool).
    The item tokens can be found here:
    https://dwarffortresswiki.org/index.php/DF2014:Item_token
    If you want to specify an item subtype, look into the files listed under the
    column "Subtype" of the wiki page (they are in the "/raw/objects/" folder),
    then specify the items using the full tokens found in those files (see
    examples in this help).
``--likeplant [ <token> [<token> ...] ]``
    As in ``--likecreature`` above, you can just list the tree or plant species
    in the token.
``--likecolor [ <token> [<token> ...] ]``
    You can find the color tokens here:
    https://dwarffortresswiki.org/index.php/DF2014:Color#Color_tokens
    or inside the "descriptor_color_standard.txt" file (in the "/raw/objects/"
    folder). You can use the full token or just the color name.
``--likeshape [ <token> [<token> ...] ]``
    I couldn't find a list of shape tokens in the wiki, but you can find them
    inside the "descriptor_shape_standard.txt" file (in the "/raw/objects/"
    folder). You can use the full token or just the shape name.
``--reset``
    Clear all preferences. If the script is called with both this option and one
    or more preferences, first all the unit preferences will be cleared and then
    the listed preferences will be added.

combine
=======

.. dfhack-tool::
    :summary: Combine items that can be stacked together.
    :tags: fort productivity items plants stockpiles

This handy tool "defragments" your items without giving your fort an undue
advantage of unreasonably large stacks. Within stockpiles and built containers,
similar items will be combined into fewer, larger stacks for more compact and
easier-to-manage storage. Cloth and thread that has been partially used by
hospitals will be rebalanced so that the used parts are associated with the
fewest number of cloth/thread items possible. Finally, partial bars that
accumulate in smelters when you melt metal items are gathered together so
complete, usable bars can be created.

Items inside of stockpiles or built containers will not be combined with items
outside of those stockpiles or containers. Cloth and thread, however, can be
dropped anywhere after being partially used, so cloth and thread is combined
across the entire fort. If a full bar is collected from your smelters, it will
appear at one of the smelters that contributed to that metal type.

Usage
-----

::

    combine (all|here) [<options>]

Examples
--------
``combine all --dry-run``
    Preview what will be combined for all types in all
    stockpiles/containers/smelters.
``combine all``
    Merge all items in all stockpiles/containers/smelters.
``combine all --types=meat,plant``
    Merge ``meat`` and ``plant`` type stacks in all stockpiles and containers.
``combine here``
    Merge stacks in the currently selected stockpile or container, or collect
    all accumulated metal bars to the currently selected smelter.

Commands
--------
``all``
    Combine things in all stockpiles, built containers, and smelters.
``here``
    Combine items in the currently selected stockpile or container, or collect
    partial bars from all smelters into the selected smelter.

Options
-------
``-d``, ``--dry-run``
    Display what would be combined instead of actually combining items.
``-t``, ``--types <comma separated list of types>``
    Specify which item types should be combined. Default is ``all``. Valid
    types are:
    :all: all of the types listed here
    :ammo: stacks of ammunition
    :bars: partial bars left over in smelters
    :cloth: cloth
    :drink: stacks of drinks in barrels/pots
    :fat: cheese, fat, tallow, and other globs
    :fish: raw and prepared fish. this category also includes all types of eggs
    :food: prepared food
    :meat: meat
    :parts: corpse pieces
    :plant: plants and plant growths
    :powders: dye and other non-sand, non-plaster powders
    :seed: non-plantable seeds (plantable seeds cannot stack)
    :thread: thread
``-q``, ``--quiet``
    Don't print the final item distribution summary.
``-v``, ``--verbose n``
    Print verbose output for debugging purposes, n from 1 to 4.

Notes
-----

The following conditions prevent an item from being combined:

1. An item is not in a stockpile.
2. An item is sand or plaster.
3. An item is rotten, forbidden/hidden, marked for dumping/melting, on
    fire, encased, owned by a trader/hostile/dwarf or is in a spider web.
4. An item is part of a corpse and has not been butchered.

Moreover, if a stack is in a container associated with a stockpile, the stack
will not be able to grow past the volume limit of the container.

An item can be combined with others if it:

1. has an associated race/caste and is of the same item type, race, and caste
2. has the same type, material, and quality. If it is a masterwork, it is also
   grouped by who created it.

Since the player cannot easily choose what kind of cloth and thread the
hospital uses to dress and suture wounds, `combine` will refill more expensive
cloth/thread first and deduct accordingly from cheaper cloth/thread. Existing
wound dressings and sutures that used the more expensive materials will be
modified to use the cheaper materials.

When partial bars are collected in smelters, collected whole bars are spawned
at one of the smelters that had a partial amount of that bar. Any remaining
partial amounts of spawned bar materials will be associated with that smelter.

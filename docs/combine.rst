combine
=======

.. dfhack-tool::
    :summary: Combine items that can be stacked together.
    :tags: fort productivity items plants stockpiles

This handy tool "defragments" your items without giving your fort the undue
advantage of unreasonably large stacks. Within each stockpile, similar items
will be combined into fewer, larger stacks for more compact and
easier-to-manage storage. Items outside of stockpiles will not be combined, and
items in separate stockpiles will not be combined together.

Usage
-----

::

    combine (all|here) [<options>]

Examples
--------

``combine``
    Displays help
``combine all --dry-run``
    Preview what will be combined for all types in all stockpiles.
``combine all``
    Merge stacks in all stockpile for all types
``combine all --types=meat,plant``
    Merge ``meat`` and ``plant`` type stacks in all stockpiles.
``combine here``
    Merge stacks in the selected stockpile.

Commands
--------

``all``
    Search all stockpiles.
``here``
    Search the currently selected stockpile.

Options
-------

``-d``, ``--dry-run``
    Display what would be combined instead of actually combining items.

``-t``, ``--types <comma separated list of types>``
    Specify which item types should be combined. Default is ``all``. Valid
    types are:

    :all:     all of the types listed here.
    :ammo:    stacks of ammunition. Qty max 25.
    :drink:   stacks of drinks in barrels/pots. Qty max 25.
    :fat:     cheese, fat, tallow, and other globs. Qty max 5.
    :fish:    raw and prepared fish. this category also includes all types of
              eggs. Qty max 5.
    :food:    prepared food. Qty max 20.
    :meat:    meat. Qty max 5.
    :parts:   corpse pieces. Material max 30.
    :plant:   plant and plant growths. Qty max 5.
    :powders: dye and other non-sand, non-plaster powders. Qty max 10.

``-q``, ``--quiet``
    Don't print the final item distribution summary.

``-v``, ``--verbose n``
    Print verbose output for debugging purposes, n from 1 to 4.

Notes
-----

The following conditions prevent an item from being combined:

1. it is not in a stockpile.
2. it is sand or plaster.
3. it is rotten, forbidden, marked for dumping/melting, on fire, encased, owned
   by a trader/hostile/dwarf or is in a spider web.
4. it is part of a corpse and has not been butchered.

Moreover, if a stack is in a container associated with a stockpile, the stack
will not be able to grow past the volume limit of the container.

An item can be combined with other similar items if it:

1. has an associated race/caste and is of the same item type, race, and caste
2. has the same type, material, and quality. If it is a masterwork, it is also
   grouped by who created it.

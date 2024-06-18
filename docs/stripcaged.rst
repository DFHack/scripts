stripcaged
==========

.. dfhack-tool::
    :summary: Remove items from caged prisoners.
    :tags: fort productivity items

This tool helps with the tedious task of going through all your cages and
marking the items inside for dumping. This lets you get leftover seeds out of
cages after you tamed the animals inside. The most popular use, though, is to
strip the weapons and armor from caged prisoners. After you run ``stripcaged``,
your dwarves will come and take the items to the garbage dump, leaving your
cages clean and your prisoners stripped bare.

If you don't want to wait for your dwarves to dump all the items, you can use
`autodump` to speed the process along.

Usage
-----

::

    stripcaged list
    stripcaged items|weapons|armor|all [here|<cage id> ...] [<options>]

Examples
--------

``stripcaged list``
    Display a list of all cages and their item contents.
``stripcaged all``
    Dump all items in all cages, equipped by a creature or not.
``stripcaged items``
    Dump loose items in all cages, such as seeds left over from animal training.
``stripcaged weapons``
    Dump weapons equipped by caged creatures.
``stripcaged armor here --skip-forbidden``
    Dumps unforbidden armor equipped by the caged creature in the selected cage.
``stripcaged all 25321 34228``
    Dumps all items out of the specified cages.
``stripcaged items here --include-pets --include-vermin``
    Dumps loose items in the selected cage, including any tamed/untamed vermin.

Options
-------

``--include-pets``, ``--include-vermin``
    Live tame (pets) and untamed vermin are considered items by the game. They
    are normally excluded from dumping since that risks them escaping or dying
    from your cats. Use these options to dump them anyway.

``-f``, ``--skip-forbidden``
    Items to be marked for dumping are unforbidden by default. Use this option
    to instead only act on unforbidden items, and leave forbidden items
    forbidden. This allows you to, for example, manually unforbid high-value
    items from the stocks menu (like steel) and then have ``stripcaged`` just
    act on the unforbidden items.

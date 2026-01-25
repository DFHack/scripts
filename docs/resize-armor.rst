resize-armor
============

.. dfhack-tool::
    :summary: Resize armor and clothing.
    :tags: adventure fort armok gameplay items

Resize any armor or clothing item to suit any creature size.

Usage
-----

``resize-armor [<option>]``

Select an armor or clothing item while in either adventure or fortress mode and
run this tool to resize the item. A stockpile can be selected while in fortress
mode to perform the resize operation on armor or clothing items contained in
the stockpile. If race ID is not specified, the items will be resized to suit
the race of the current adventurer while in adventure mode, or to suit the race
of the current site's civilization while in fortress mode.

Options
-------

``-r``, ``--race <id>``
    Specify the race ID of the target race to resize the item to.

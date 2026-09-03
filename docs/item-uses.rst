item-uses
=========

.. dfhack-tool::
    :summary: Lists all workshops and tasks where a specific item can be used.
    :tags: fort inspection

This script analyzes the selected item and determines exactly which workshops
can accept it as a reagent, and what reactions or tasks can be performed with it.
It automatically distinguishes between raw materials (like ores or logs) and finished
goods, as well as checking for applicable tasks like encrusting, melting, and milling.

Usage
-----

::

    item-uses

Select an item in the game UI (e.g. using the ``k`` cursor, or viewing an item
in a stockpile or inventory) and run the command. The script will output a
categorized list of all compatible workshops and their relevant tasks.

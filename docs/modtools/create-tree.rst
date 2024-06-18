modtools/create-tree
====================

.. dfhack-tool::
    :summary: Spawn trees.
    :tags: unavailable

Spawns a tree.

Usage
-----

::

    -tree treeName
        specify the tree to be created
        examples:
            OAK
            NETHER_CAP

    -age howOld
        set the age of the tree in years (integers only)
        defaults to 1 if omitted

    -location [ x y z ]
        create the tree at the specified coordinates

    example:
        modtools/create-tree -tree OAK -age 100 -location [ 33 145 137 ]

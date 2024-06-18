modtools/change-build-menu
==========================

.. dfhack-tool::
    :summary: Add or remove items from the build sidebar menus.
    :tags: unavailable

Change the build sidebar menus.

This script provides a flexible and comprehensive system for adding and removing
items from the build sidebar menus. You can add or remove workshops/furnaces by
text ID, or you can add/remove ANY building via a numeric building ID triplet.

Changes made with this script do not survive a save/load. You will need to redo
your changes each time the world loads.

Just to be clear: You CANNOT use this script AT ALL if there is no world
loaded!

Usage
-----

``enable modtools/change-build-menu``:

    Start the ticker. This needs to be done before any changes will take
    effect. Note that you can make changes before or after starting the
    ticker.

``disable modtools/change-build-menu``:

    Stop the ticker. Does not clear stored changes. The ticker will
    automatically stop when the current world is unloaded.

``modtools/change-build-menu add <ID> <CATEGORY> [<KEY>]``:

    Add the workshop or furnace with the ID ``<ID>`` to ``<CATEGORY>``.
    ``<KEY>`` is an optional DF hotkey ID.

    ``<CATEGORY>`` may be one of:
        - MAIN_PAGE
        - SIEGE_ENGINES
        - TRAPS
        - WORKSHOPS
        - FURNACES
        - CONSTRUCTIONS
        - MACHINES
        - CONSTRUCTIONS_TRACK

    Valid ``<ID>`` values for hardcoded buildings are as follows:
        - CARPENTERS
        - FARMERS
        - MASONS
        - CRAFTSDWARFS
        - JEWELERS
        - METALSMITHSFORGE
        - MAGMAFORGE
        - BOWYERS
        - MECHANICS
        - SIEGE
        - BUTCHERS
        - LEATHERWORKS
        - TANNERS
        - CLOTHIERS
        - FISHERY
        - STILL
        - LOOM
        - QUERN
        - KENNELS
        - ASHERY
        - KITCHEN
        - DYERS
        - TOOL
        - MILLSTONE
        - WOOD_FURNACE
        - SMELTER
        - GLASS_FURNACE
        - MAGMA_SMELTER
        - MAGMA_GLASS_FURNACE
        - MAGMA_KILN
        - KILN

``modtools/change-build-menu remove <ID> <CATEGORY>``:

    Remove the workshop or furnace with the ID ``<ID>`` from ``<CATEGORY>``.

    ``<CATEGORY>`` and ``<ID>`` may have the same values as for the "add"
    option.

``modtools/change-build-menu revert <ID> <CATEGORY>``:

    Revert an earlier remove or add operation. It is NOT safe to "remove"
    an "add"ed building or vice versa, use this option to reverse any
    changes you no longer want/need.


Module Usage
------------

To use this script as a module put the following somewhere in your own script:

.. code-block:: lua

    local buildmenu = reqscript "change-build-menu"

Then you can call the functions documented here like so:

    - Example: Remove the carpenters workshop:

    .. code-block:: lua

        buildmenu.ChangeBuilding("CARPENTERS", "WORKSHOPS", false)

    - Example: Make it impossible to build walls (not recommended!):

    .. code-block:: lua

        local typ, styp = df.building_type.Construction, df.construction_type.Wall
        buildmenu.ChangeBuildingAdv(typ, styp, -1, "CONSTRUCTIONS", false)

Note that to allow any of your changes to take effect you need to start the
ticker. See the "Command Usage" section.


**Global Functions:**

``GetWShopID(btype, bsubtype, bcustom)``:
    GetWShopID returns a workshop's or furnace's string ID based on its
    numeric ID triplet. This string ID *should* match what is expected
    by eventful for hardcoded buildings.

``GetWShopType(id)``:
    GetWShopIDs returns a workshop or furnace's ID numbers as a table.
    The passed in ID should be the building's string identifier, it makes
    no difference if it is a custom building or a hardcoded one.
    The return table is structured like so: ``{type, subtype, custom}``

``IsEntityPermitted(id)``:
    IsEntityPermitted returns true if DF would normally allow you to build
    a workshop or furnace. Use this if you want to change a building, but
    only if it is permitted in the current entity. You do not need to
    specify an entity, the current fortress race is used.

``ChangeBuilding(id, category, [add, [key]])``:

``ChangeBuildingAdv(typ, subtyp, custom, category, [add, [key]]):``
    These two functions apply changes to the build sidebar menus. If "add"
    is true then the building is added to the specified category, else it
    is removed. When adding you may specify "key", a string DF hotkey ID.

    The first version of this function takes a workshop or furnace ID as a
    string, the second takes a numeric ID triplet (which can specify any
    building, not just workshops or furnaces).

``RevertBuildingChanges(id, category)``:

``RevertBuildingChangesAdv(typ, subtyp, custom, category)``:
    These two functions revert changes made by "ChangeBuilding" and
    "ChangeBuildingAdv". Like those two functions there are two versions,
    a simple one that takes a string ID and one that takes a numeric ID
    triplet.

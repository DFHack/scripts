multihaul
=========

.. dfhack-tool::
    :summary: Haulers gather multiple nearby items when using wheelbarrows.
    :tags: fort gameplay items stockpile

This tool allows dwarves to collect several adjacent non-forbidden items at once when
performing hauling jobs with a wheelbarrow. When enabled, new
``StoreItemInStockpile`` jobs with wheelbarrows will automatically attach nearby items so
they can be hauled in a single trip. Jobs without wheelbarrows would try to attach one if autowheelbarrows option is on.
Items claimed by another jobs or already stored in stockpiles would be ignored.
By default, up to ten additional items within 10 tiles of the original item are collected.
Warning: Destination stockpile filters are currently ignored by the job (because of DF logic). Which items qualify can be controlled
with the ``--mode`` option.
Basic usage of wheelbarrows remains the same: dwarfs would use them only if hauling item is heavier than 75

Usage
-----

::

    multihaul enable [<options>]
    multihaul disable
    multihaul status
    multihaul config [<options>]
    multihaul finish

The script can also be enabled persistently with ``enable multihaul``.

``multihaul finish`` cancels any ``StoreItemInStockpile`` jobs that have lost
their wheelbarrows, freeing attached items.

Options
-------

``--radius <tiles>``
    Search this many tiles around the target item for additional items. Default
    is ``10``.
``--max-items <count>``
    Attach at most this many additional items to each hauling job. Default is
    ``10``.
``--mode <any|sametype|samesubtype|identical>``
    Control which nearby items are attached. ``any`` collects any items nearby, even if they are not related to an original job item,
    ``sametype`` only matches the item type (like STONE or WOOD), ``samesubtype`` requires type and
    subtype to match, and ``identical`` additionally matches material. The
    default is ``sametype``.
``--autowheelbarrows <on|off|enable|disable>``
    Automatically assign wheelbarrows to jobs that lack them.
``--debug <on|off|enable|disable>``
    Show debug messages via ``dfhack.gui.showAnnouncement`` when items are
    attached.

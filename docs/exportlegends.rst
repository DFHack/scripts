exportlegends
=============

.. dfhack-tool::
    :summary: Exports extended legends data for external viewing.
    :tags: legends inspection

When run from the legends mode screen, this tool will export detailed data
about your world so that it can be browsed with external programs like
:forums:`Legends Browser <179848>`. The data is more detailed than what you can
get with vanilla export functionality, and many external tools depend on this
extra information.

By default, ``exportlegends`` hooks into the standard vanilla ``Export XML``
button and runs in the background when you click it, allowing both the vanilla
export and the extended data export to execute simultaneously. You can continue
to browse legends mode via the vanilla UI while the export is running.

To use:

- Enter legends by "Starting a new game" in an existing world and selecting
  Legends mode
- Ensure the toggle for "Also export extended legends data" is on (which is the
  default)
- Click the "Export XML" button to generate both the standard export and the
  extended data export

You can also generate just the extended data export by manually running the
``exportlegends`` command while legends mode is open.

In addition to ``legends_plus.xml``, ``exportlegends`` recreates the companion
files that Classic Dwarf Fortress produced with its "Export Map/Gen
Information" action:

- ``world_sites_and_pops.txt`` contains civilized, site, outdoor animal, and
  underground animal population totals.
- ``world_history.txt`` contains civilizations, worship relationships, and
  current position holders.
- ``world_map.csv`` is a compact per-world-tile companion containing biome,
  alignment, savagery, elevation, volcanism, mountain-peak metadata, and
  lake/river/road flags and exact cardinal river connections. Compatible
  viewers can combine it with the Premium world-map graphics installed with
  the game; no proprietary graphics are copied into the export. Road
  connections can be inferred between adjacent road tiles, but the available
  data does not identify paving, so compatible viewers render them as dirt.

The text files use the Classic names and structure expected by external legends
viewers. The CSV companion is a DFHack extension.

Usage
-----

::

    exportlegends

Overlay
-------

This script also provides several overlays that are managed by the `overlay`
framework.

**exportlegends.export**

When the overlay is enabled, a toggle for exporting extended legends data will
appear below the vanilla "Export XML" button. If the toggle is enabled when the
"Export XML" button is clicked, then ``exportlegends`` will run alongside the
vanilla data export.

While the extended data is being exported, a status line will appear in place
of the toggle, reporting the current export target and the overall percent
complete.

**exportlegends.mask**

This overlay masks out the "Done" button while the extended export is running.
This prevents the player from accidentally exiting legends mode before the
export is complete.

**exportlegends.histfigfilter**

This overlay adds a filter widget to the Historical Figures legends page.
Clicking the widget allows you to filter the list of historical figures by race.

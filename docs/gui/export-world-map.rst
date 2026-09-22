gui/export-world-map
====================

.. dfhack-tool::
    :summary: Export world map data for GIS and other external tools.
    :tags: inspection embark map

This tool provides a GUI for the `export-world-map` plugin and a number of
additional exports written in Lua. Moreover, this tool automates the process of
scrolling around the embark map to generate the region tiles used for the
exports.

The additional exports provided are:

* Roads and tunnels (GeoJSON)
* Geological layers and the veins included in them (semicolon-delimited pure data layer)
* Animal and plant populations of regions (semicolon-delimited pure data layer)

The data layers are in "long" format (e.g. ``BIRD_KEA`` is a field in the
``raw_id`` column instead of a column header). Since these layers do not have
any geometry information, they need to be joined with the ``region`` layer of
`export-world-map`. The first column of each file (e.g. ``geo_index`` for
geological layers) match as the corresponding column from the region export.

Usage
-----

::

    gui/export-world-map

gui/sitemap
===========

.. dfhack-tool::
    :summary: List and zoom to people, locations, or artifacts.
    :tags: adventure fort inspection

This simple UI gives you searchable lists of people, locations (temples,
guildhalls, hospitals, taverns, and libraries), and artifacts in the local area.
Clicking on a list item will zoom the map to the target. In fort mode,
shift-clicking will zoom to the unit or artifact and lock the camera to the
target with follow mode. If you are zooming to a location and the location has
multiple zones attached to it, clicking again will zoom to each component zone
in turn.

Locations are attached to a site, so if you're in adventure mode, you must
enter a site before searching for locations. For worldgen sites, many locations
are not attached to a zone, so it does not have a specific map location and
click to zoom will have no effect.

Usage
-----

::

    gui/sitemap


Overlay
-------

This tool also provides one overlay that is managed by the `overlay`
framework.

sitemaptoolbar
~~~~~~~~~~~~~~~~~

The sitemap.sitemaptoolbar overlay adds a button to the toolbar at the bottom left corner of the
screen with the other menu buttons. It allows you to conveniently open the ``gui/sitemap``
interface.

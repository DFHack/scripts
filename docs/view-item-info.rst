view-item-info
==============

.. dfhack-tool::
    :summary: Extend item and unit descriptions with more information.
    :tags: unavailable

This tool extends the item or unit description viewscreen with additional
information, including a custom description of each item (when available), and
properties such as material statistics, weapon attacks, armor effectiveness, and
more.

Usage
-----

::

    enable view-item-info

Info for modded items
---------------------

The associated :file:`scripts/internal/view-item-info/item-descriptions` script
supplies custom descriptions of items. Mods can extend or override the
descriptions in that file by supplying a similarly formatted file named
:file:`raw/scripts/more-item-descriptions.lua`.  Both work as sparse lists,
so missing items simply go undescribed if not defined in the fallback.

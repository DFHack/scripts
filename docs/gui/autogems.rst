
gui/autogems
============

.. dfhack-tool::
    :summary: Automatically cut rough gems.
    :tags: unavailable

This is a frontend for the `autogems` plugin that allows interactively
configuring the gem types that you want to be cut.

The following controls apply to the gems currently listed:

- ``s``: Searches for matching gems
- ``Shift+Enter``: Toggles the status of all listed gems

The following controls apply to the gems currently listed, as well as gems
listed *before* the current search with ``s``, if applicable:

- ``r``: Displays only "rock crystal" gems
- ``c``: Displays only gems whose color matches the selected gem
- ``m``: Displays only gems where at least one rough (uncut) gem is available
    somewhere on the map

This behavior is intended to allow for things like a search for "lazuli"
followed by pressing ``c`` to select all gems with the same color as lapis
lazuli (5 blue gems in vanilla DF), rather than further restricting that to gems
with "lazuli" in their name (only 1).

``x`` clears all filters, which is currently the only way to undo filters
(besides searching), and is useful to verify the gems selected.

Usage
-----

::

    gui/autogems

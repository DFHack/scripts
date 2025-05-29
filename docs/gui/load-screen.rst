gui/load-screen
===============

.. dfhack-tool::
    :summary: Replace DF's continue game screen with a searchable list.
    :tags: unavailable

If you tend to have many ongoing games, this tool can make it much easier to
load the one you're looking for. It replaces DF's "continue game" screen with
a dialog that has search and filter options.

The primary view is a list of saved games, much like the default list provided
by DF. Several filter options are available:

- :kbd:`s`: search for folder names containing specific text
- :kbd:`t`: filter by active game type (e.g. fortress, adventurer)
- :kbd:`b`: toggle display of backup folders, as created by DF's ``AUTOBACKUP``
  option (see :file:`data/init/init.txt` for a detailed explanation). This
  defaults to hiding backup folders, since they can take up significant space in
  the list.

When selecting a game with :kbd:`Enter`, a dialog will give options to load the
selected game (:kbd:`Enter` again), cancel (:kbd:`Esc`), or rename the game's
folder (:kbd:`r`).

Also see the ``title-start-rename`` `tweak` to rename folders in the
"start playing" menu.

Usage
-----

::

    enable gui/load-screen

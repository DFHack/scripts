
gui/load-screen
===============
A replacement for the "continue game" screen.

Usage: ``gui/load-screen enable|disable``

The primary view is a list of saved games, much like the default list provided
by DF. Several filter options are available:

- :kbd:`s`: search for folder names containing specific text
- :kbd:`t`: filter by active game type (e.g. fortress, adventurer)
- :kbd:`b`: toggle display of backup folders, as created by DF's ``AUTOBACKUP``
  option (see data/init/init.txt for a detailed explanation). This defaults to
  hiding backup folders, since they can take up significant space in the list.

When selecting a game with :kbd:`Enter`, a dialog will give options to load the
selected game (:kbd:`Enter` again), cancel (:kbd:`Esc`), or rename the game's
folder (:kbd:`r`). See the ``title-start-rename`` `tweak` to rename folders in
the "start playing" menu.



gui/rename
==========
Backed by `rename`, this script allows entering the desired name
via a simple dialog in the game ui.

* ``gui/rename [building]`` in :kbd:`q` mode changes the name of a building.

  .. image:: /docs/images/rename-bld.png

  The selected building must be one of stockpile, workshop, furnace, trap, or siege engine.
  It is also possible to rename zones from the :kbd:`i` menu.

* ``gui/rename [unit]`` with a unit selected changes the nickname.

  Unlike the built-in interface, this works even on enemies and animals.

* ``gui/rename unit-profession`` changes the selected unit's custom profession name.

  .. image:: /docs/images/rename-prof.png

  Likewise, this can be applied to any unit, and when used on animals it overrides
  their species string.

The ``building`` or ``unit`` options are automatically assumed when in relevant UI state.

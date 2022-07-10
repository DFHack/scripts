
devel/spawn-unit-helper
=======================
Setup stuff to allow arena creature spawn after a mode change.

With Arena spawn data initialized:

- enter the :kbd:`k` menu and change mode using
  ``rb_eval df.gametype = :DWARF_ARENA``

- spawn creatures (:kbd:`c` ingame)

- revert to game mode using ``rb_eval df.gametype = #{df.gametype.inspect}``

- To convert spawned creatures to livestock, select each one with
  the :kbd:`v` menu, and enter ``rb_eval df.unit_find.civ_id = df.ui.civ_id``


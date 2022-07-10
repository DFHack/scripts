
gui/gm-editor
=============
This editor allows to change and modify almost anything in df. Press :kbd:`?` for
in-game help. There are multiple ways to open this editor:

* Calling ``gui/gm-editor``  from a command or keybinding opens the editor
  on whatever is selected or viewed (e.g. unit/item description screen)

* using ``gui/gm-editor <lua command>`` - executes lua command and opens editor on
  its results (e.g. ``gui/gm-editor "df.global.world.items.all"`` shows all items)

* using ``gui/gm-editor dialog`` - shows an in game dialog to input lua command. Works
  the same as version above.

* using ``gui/gm-editor toggle`` - will hide (if shown) and show (if hidden) editor at
  the same position you left it

.. image:: /docs/images/gm-editor.png

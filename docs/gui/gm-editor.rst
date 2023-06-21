gui/gm-editor
=============

.. dfhack-tool::
    :summary: Inspect and edit DF game data.
    :tags: dfhack armok inspection animals buildings items jobs map plants stockpiles units workorders

This editor allows you to inspect or modify almost anything in DF. Press
:kbd:`?` for in-game help.

If you just want to browse without fear of accidentally changing anything, hit
:kbd:`Ctrl`:kbd:`D` to toggle read-only mode.

Usage
-----

``gui/gm-editor [-f]``
    Open the editor on whatever is selected or viewed (e.g. unit/item
    description screen)
``gui/gm-editor [-f] <lua expression>``
    Evaluate a lua expression and opens the editor on its results. Field
    prefixes of ``df.global`` can be omitted.
``gui/gm-editor [-f] dialog``
    Show an in-game dialog to input the lua expression to evaluate. Works the
    same as the version above.

Examples
--------

``gui/gm-editor``
    Opens the editor on the selected unit/item/job/workorder/stockpile etc.
``gui/gm-editor world.items.all``
    Opens the editor on the items list.
``gui/gm-editor --freeze scr``
    Opens the editor on the current DF viewscreen data (bypassing any DFHack
    layers) and prevents the underlying viewscreen from getting updates while
    you have the editor open.

Options
-------

``-f``, ``--freeze``
    Freeze the underlying viewscreen so that it does not receive any updates.
    This allows you to be sure that whatever you are inspecting or modifying
    will not be read or changed by the game until you are done with it. Note
    that this will also prevent any rendering refreshes, so the background is
    replaced with a blank screen. You can open multiple instances of
    `gui/gm-editor` as usual when the game is frozen. The black background will
    disappear when the last `gui/gm-editor` window that was opened with the
    ``--freeze`` option is dismissed.

Screenshot
----------

.. image:: /docs/images/gm-editor.png

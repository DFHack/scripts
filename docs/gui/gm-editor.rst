gui/gm-editor
=============

.. dfhack-tool::
    :summary: Inspect and edit DF game data.
    :tags: dfhack armok inspection animals buildings items jobs map plants stockpiles units workorders

This editor allows you to inspect or modify almost anything in DF. Press
:kbd:`?` for in-game help.

Select a field and hit :kbd:`Enter` or double click to edit, or, for structured
fields, hit :kbd:`Enter` or single click to inspect their contents. Right click
or hit :kbd:`Esc` to go back to the previous structure you were inspecting.
Right clicking when viewing the structure you started with will exit the tool.
Hold down :kbd:`Shift` and right click to exit, even if you are inspecting a
substructure, no matter how deep.

If you just want to browse without fear of accidentally changing anything, hit
:kbd:`Ctrl`:kbd:`D` to toggle read-only mode.

If you want `gui/gm-editor` to automatically pick up changes to game data in
realtime, hit :kbd:`Alt`:kbd:`A` to switch to auto update mode.

.. warning::

    Note that data structures can be created and deleted while the game is
    running. If you happen to be inspecting a dynamically allocated data
    structure when it is deleted by the game, the game may crash. Please save
    your game before poking around in `gui/gm-editor`, especially if you are
    examining data while the game is unpaused.

.. warning::

    Union data structures contain fields that occupy the same memory space.
    When you see the ``[union structure]`` badge at the top of the screen, be
    aware that only one of the fields in the structure is likely to make sense.
    The "correct" field is usually indicated by some context in the parent
    structure. If there are any pointers to substructures in the union,
    inspecting the pointer when it is not the "correct" field may crash the
    game.

Usage
-----

::

    gui/gm-editor [<options>] [<lua expression>]
    gui/gm-editor [<options>] dialog

When specifying a lua expression, field prefixes of ``df.global`` can be
omitted.

Examples
--------

``gui/gm-editor``
    Opens the editor on the selected unit/item/job/workorder/stockpile etc.
``gui/gm-editor world.items.all``
    Opens the editor on the items list.
``gui/gm-editor df.unit.find(12345)``
    Opens the editor on the unit with id 12345.
``gui/gm-editor reqscript('gui/quickfort').view``
    Opens the editor on a running instance of `gui/quickfort`. Useful for
    debugging GUI tool state during development.
``gui/gm-editor --freeze scr``
    Opens the editor on the current DF viewscreen data (bypassing any DFHack
    tools that may be open) and prevents the underlying viewscreen from getting
    updates while you are inspecting the data.
``gui/gm-editor dialog``
    Show an in-game dialog to input the lua expression to evaluate.

Options
-------

``-f``, ``--freeze``, ``--safe-mode``
    Freeze the underlying viewscreen so that it does not receive any updates.
    This allows you to be sure that whatever you are inspecting or modifying
    will not be read or changed by the game until you are done with it. Note
    that this will also prevent any rendering refreshes, so the background is
    replaced with a blank screen. You can open multiple instances of
    `gui/gm-editor` as usual when the game is frozen. The black background will
    disappear when the last `gui/gm-editor` window that was opened with the
    ``--freeze`` option is dismissed.
``--no-stringification``
    Don't attempt to provide helpful string representations of potentially
    unsafe fields like language_name when browsing the data structures. Specify
    this option when you know you will be browsing garbage data that could lead
    to crashes if accessed for stringification. Note that fields in union data
    structures are never stringified.

Screenshot
----------

.. image:: /docs/images/gm-editor.png

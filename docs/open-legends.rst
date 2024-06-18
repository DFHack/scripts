open-legends
============

.. dfhack-tool::
    :summary: Open a legends screen from fort or adventure mode.
    :tags: legends inspection

You can use this tool to open legends mode from a world loaded in fortress or
adventure mode. You can browse around as normal, and even export legends data
while you're on the legends screen.

However, entering and leaving legends mode from a fort or adventure mode game
will leave Dwarf Fortress in an inconsistent state. Therefore, entering legends
mode via this tool is a **ONE WAY TRIP**. If you care about your savegame, you
*MUST* save your game before entering legends mode. `open-legends` will pop up
a dialog to remind you of this and (in fort mode) will give you a link that you
can use to trigger an Autosave. You can also close the dialog, do a manual save
with a name of your choice, and run `open-legends` again to continue to legends
mode.

Usage
-----

::

    open-legends
    open-legends --no-autoquit

Options
-------

The ``--no-autoquit`` option is provided for bypassing the auto-quit in case
you are doing testing where you want to switch into legends mode, switch back,
make a few changes, and then hop back into legends mode. However, please note
that while the game appears playable once you are back in the original mode,
your world data **is corrupted** in subtle ways that are not easy to detect
from the UI. Once you are done with your legends browsing, you *must* quit to
desktop and restart the game to be sure to avoid save corruption issues.

If you are returning to fort mode, autosaves will be disabled to avoid
accidental overwriting of good savegames.

If the ``--no-autoquit`` option has previously been passed and the savegame is
already "tainted" by previous trips into legends mode, the warning dialog
prompting you to save your game will be skipped.

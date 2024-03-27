open-legends
============

.. dfhack-tool::
    :summary: Open a legends screen from fort or adventure mode.
    :tags: legends inspection

You can use this tool to open legends mode from a world loaded in fortress or
adventure mode. You can browse around, or even export legends data while you're
on the legends screen.

However, entering and leaving legends mode from a fort or adventure mode game
will leave Dwarf Fortress in an inconsistent state. Therefore, entering legends
mode is a **ONE WAY TRIP**. If you care about your savegame, you *MUST* save
your game before entering legends mode. `open-legends` will pop up a dialog to
remind you of this and will give you a link that you can use to trigger an
Autosave. You can also close the dialog, do a manual save with a name of your
choice, and run `open-legends` again to continue to legends mode.

Usage
-----

::

    open-legends

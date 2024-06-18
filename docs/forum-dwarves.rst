forum-dwarves
=============

.. dfhack-tool::
    :summary: Exports the text you see on the screen for posting to the forums.
    :tags: unavailable

This tool saves a copy of a text screen, formatted in BBcode for posting to the
Bay12 Forums. Text color and layout is preserved. See `markdown` if you want to
export for posting to Reddit or other places.

This script will attempt to read the current screen, and if it is a text
viewscreen (such as the dwarf 'thoughts' screen or an item 'description') then
append a marked-up version of this text to the ``forumdwarves.txt`` file.
Previous entries in the file are not overwritten, so you may use the
``forum-dwarves`` command multiple times to create a single document containing
the text from multiple screens, like thoughts from several dwarves or
descriptions from multiple artifacts.

The screens which have been tested and known to function properly with this
script are:

1. dwarf/unit 'thoughts' screen
2. item/art 'description' screen
3. individual 'historical item/figure' screens

There may be other screens to which the script applies. It should be safe to
attempt running the script with any screen active. An error message will inform
you when the selected screen is not appropriate for this script.

.. note::
    The text will be encoded in CP437, which is likely to be incompatible
    with the system default.  This causes incorrect display of special
    characters (e.g. :guilabel:`é õ ç` = ``é õ ç``).  You can fix this by
    opening the file in an editor such as Notepad++ and selecting the
    correct encoding before copying the text.

Usage
-----

::

    forum-dwarves

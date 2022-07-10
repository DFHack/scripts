
forum-dwarves
=============
Saves a copy of a text screen, formatted in bbcode for posting to the
Bay12 Forums.  See `markdown` to export for Reddit etc.

This script will attempt to read the current df-screen, and if it is a
text-viewscreen (such as the dwarf 'thoughts' screen or an item
'description') then append a marked-up version of this text to the
target file. Previous entries in the file are not overwritten, so you
may use the 'forumdwarves' command multiple times to create a single
document containing the text from multiple screens (eg: text screens
from several dwarves, or text screens from multiple artifacts/items,
or some combination).

The screens which have been tested and known to function properly with
this script are:

1. dwarf/unit 'thoughts' screen
2. item/art 'description' screen
3. individual 'historical item/figure' screens

There may be other screens to which the script applies.  It should be
safe to attempt running the script with any screen active, with an
error message to inform you when the selected screen is not appropriate
for this script.

The target file's name is 'forumdwarves.txt'.  A reminder to this effect
will be displayed if the script is successful.

.. note::
    The text will be encoded in CP437, which is likely to be incompatible
    with the system default.  This causes incorrect display of special
    characters (eg. :guilabel:`é õ ç` = ``é õ ç``).  You can fix this by
    opening the file in an editor such as Notepad++ and selecting the
    correct encoding before using the text.

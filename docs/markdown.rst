
markdown
========
Save a copy of a text screen in markdown (useful for Reddit, among other sites).
See `forum-dwarves` for BBCode export (for e.g. the Bay12 Forums).

This script will attempt to read the current df-screen, and if it is a
text-viewscreen (such as the dwarf 'thoughts' screen or an item / creature
'description') or an announcement list screen (such as announcements and
combat reports) then append a marked-down version of this text to the
target file (for easy pasting on reddit for example).
Previous entries in the file are not overwritten, so you
may use the``markdown`` command multiple times to create a single
document containing the text from multiple screens (eg: text screens
from several dwarves, or text screens from multiple artifacts/items,
or some combination).

Usage::

    markdown [-n] [filename]

:-n:    overwrites contents of output file
:filename:
        if provided, save to :file:`md_{filename}.md` instead
        of the default :file:`md_export.md`

The screens which have been tested and known to function properly with
this script are:

#. dwarf/unit 'thoughts' screen
#. item/art 'description' screen
#. individual 'historical item/figure' screens
#. manual
#. announements screen
#. combat reports screen
#. latest news (when meeting with liaison)

There may be other screens to which the script applies.  It should be
safe to attempt running the script with any screen active, with an
error message to inform you when the selected screen is not appropriate
for this script.


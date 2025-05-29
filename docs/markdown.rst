markdown
========

.. dfhack-tool::
    :summary: Export displayed text to a Markdown file.
    :tags: adventure fort items units

Saves the description of a selected unit or item to a Markdown file encoded in
UTF-8.

By default, data is stored in the ``markdown_{YourWorldName}.md`` file in the
root of the game directory.

For units, the script exports:

#. Name, race, age, profession
#. Description from the unit's Health -> Description screen
#. Traits from the unit's Personality -> Traits screen

For items, it exports:

#. Decorated name (e.g., "☼«☼Chalk Statue of Dakas☼»☼")
#. Full description from the item's view sheet

The script works for most items with in-game descriptions and names, including
those in storage, on the ground, installed as a building, or worn/carried by
units.

By default, entries are appended, not overwritten, allowing the ``markdown``
command to compile descriptions of multiple items & units in a single document.
You can quickly export text for the currently selected unit or item by tapping
the Ctrl-t keybinding or selecting `markdown` from the DFHack logo menu.

Usage
-----

::

    markdown [<name>] [<options>]

Specifying a name will append to ``markdown_{name}.md``, which can be useful
for organizing data by category or topic. If ``name`` includes whitespace,
quote it in double quotes.

If no ``name`` is given, the name of the loaded world is used by default.

Examples
--------

- ``markdown``

Example output for a selected chalk statue in the world "Orid Tamun", appended
to the default ``markdown_Orid_Tamun.md`` file::

    [...previous entries...]

    ### ☼Chalk Statue of Bìlalo Bandbeach☼

    #### Description:
    This is a well-crafted chalk statue of Bìlalo Bandbeach. The item is an
    image of Bìlalo Bandbeach the elf and Lani Lyricmonks the Learned the ettin
    in chalk by Domas Uthmiklikot. Lani Lyricmonks the Learned is striking down
    Bìlalo Bandbeach.
    The artwork relates to the killing of the elf Bìlalo Bandbeach by the
    ettin Lani Lyricmonks the Learned with Hailbite in The Forest of
    Indignation in 147.

    ---

- ``markdown -o descriptions``

Example output for a selected unit Lokum Alnisendok, written to the newly
overwritten ``markdown_descriptions.md`` file::

    ### Lokum Alnisendok, dwarf, 27 years old Presser.

    #### Description:
    A short, sturdy creature fond of drink and industry.

    He is very quick to tire.

    His very long beard is neatly combed.  His very long sideburns are braided.
    His very long moustache is neatly combed.  His hair is clean-shaven.  He is
    average in size. His nose is sharply hooked.  His nose bridge is convex.
    His gold eyes are slightly wide-set.  His somewhat tall ears are somewhat
    narrow.  His hair is copper.  His skin is copper.

    #### Personality:
    He has an amazing memory, but he has a questionable spatial sense and poor
    focus.

    He doesn't generally think before acting.  He feels a strong need to
    reciprocate any favor done for him.  He enjoys the company of others.  He
    does not easily hate or develop negative feelings.  He generally finds
    himself quite hopeful about the future.  He tends to be swayed by the
    emotions of others.  He finds obligations confining, though he is
    conflicted by this for more than one reason.  He doesn't tend to hold on to
    grievances.  He has an active imagination.

    He needs alcohol to get through the working day.

    ---

Options
-------

``-o``, ``--overwrite``
    Overwrite the output file, deleting previous entries.

Setting up custom keybindings
-----------------------------

If you want to use custom filenames, you can create your own keybinding so
you don't have to type out the full command each time. You can run a command
like this in `gui/launcher` to make it active for the current session, or add
it to ``dfhack-config/init/dfhack.init`` to register it at startup for future
game sessions::

    keybinding add Ctrl-Shift-S@dwarfmode/ViewSheets/UNIT|dwarfmode/ViewSheets/ITEM "markdown descriptions"

You can use a different key combination and output name, of course. See the
`keybinding` docs for more details.

Alternately, you can register commandlines with the `gui/quickcmd` tool and run
them from the popup menu.

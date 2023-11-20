markdown
========

.. dfhack-tool::
    :summary: Save descriptions of selected units/items in markdown format (e.g., for Reddit).
    :tags: fort | inspection | units

Saves descriptions of selected units or items to a markdown file.


For units, the script retrieves:
- Name, race, age, profession
- Description from the Unit/Health/Description screen
- Traits from the Unit/Personality/Traits screen
It works for all units with text in the Description &/or Personality/Traits tabs, 
such as dwarves, dogs, elves, goblins, and beasts.

For items, it retrieves:
- Decorated name (e.g., "☼«☼Chalk Statue of Dakas☼»☼")
- Full description from the item's view sheet
It works for most items with in-game descriptions and names, including those in storage,
on the ground, installed as a building, or worn/carried by units.

The script appends a markdown-formatted version of the text to a target file 
for easy sharing, e.g., on Reddit.

By default, entries are appended, not overwritten, allowing the ``markdown`` command 
to compile descriptions of multiple items & units in a single document.

By default, data is stored in markdown_{YourWorldName}_export.md.

See `forum-dwarves` for BBCode export (e.g., for the Bay12 Forums).


Usage
-----

::

    markdown [-o] [<filename>]

Appends the description of the selected unit/item 
to ``markdown_{world_name}_export.md`` file by default. 
Specifying a filename will append to ``markdown_{filename}.md`` instead,
which is useful for organizing data by category or topic.
The [-o] argument tells the script to overwrite the output file.

Options
-------

``-o``
    Overwrite the output file, deleting previous entries.
``help`` 
    Show help.

Examples
--------

::

    markdown

#### Example output for a selected chalk statue in the world "Orid Tamun", 
appended to the default ``markdown_Orid_Tamun_export.md`` file:

    [...previous entries...]

    ### ☼Chalk Statue of Bìlalo Bandbeach☼

    #### Description: 
    This is a well-crafted chalk statue of Bìlalo Bandbeach. The item is an image of 
    Bìlalo Bandbeach the elf and Lani Lyricmonks the Learned the ettin in chalk by 
    Domas Uthmiklikot. Lani Lyricmonks the Learned is striking down Bìlalo Bandbeach. 
    The artwork relates to the killing of the elf Bìlalo Bandbeach by the 
    ettin Lani Lyricmonks the Learned with Hailbite in The Forest of Indignation in 147.  

    ---
::

    ``markdown -o descriptions``
    
#### Example output for a selected unit Lokum Alnisendok, appended to the ``markdown_descriptions.md`` file
::

    ### Lokum Alnisendok, dwarf, 27 years old Presser.

    #### Description: 
    A short, sturdy creature fond of drink and industry.

    He is very quick to tire.  

    His very long beard is neatly combed.  His very long sideburns are braided.  His very long moustache is neatly combed.  His hair is clean-shaven.  He is average in size.  His nose is sharply hooked.  His nose bridge is convex.  His gold eyes are slightly wide-set.  His somewhat tall ears are somewhat narrow.  His hair is copper.  His skin is copper.  

    #### Personality: 
    He has an amazing memory, but he has a questionable spatial sense and poor focus.  

    He doesn't generally think before acting.  He feels a strong need to reciprocate any favor done for him.  He enjoys the company of others.  He does not easily hate or develop negative feelings.  He generally finds himself quite hopeful about the future.  He tends to be swayed by the emotions of others.  He finds obligations confining, though he is conflicted by this for more than one reason.  He doesn't tend to hold on to grievances.  He has an active imagination.  

    He needs alcohol to get through the working day.  

    ---
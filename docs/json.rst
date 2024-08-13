json
====

.. dfhack-tool::
    :summary: Export unit or item data to a JSON file.
    :tags: fort items units

Saves the description of a selected unit or item to a JSON file encoded in UTF-8 in the root of the game directory.

For units, the script exports:

#. General information like name, race, age, profession, and various status flags.
#. Detailed health status, including wounds, treatments, and history from the unit's Health screen.
#. Personality traits, values, preferences, needs, and thoughts from the unit's Personality screen.
#. Thoughts and memories.

For items, it exports:

#. Item ID.
#. Decorated name (e.g., "☼«☼Chalk Statue of Dakas☼»☼").
#. Full description from the item's view sheet.

The script works for most items with in-game descriptions and names and for units in various states and roles.

Usage
-----

::

   json

The script generates filenames based on the selected item or unit ID. For example, "unit_12345.json" for a unit with ID 12345.

Examples
--------

- ``json``

Example output for a selected chalk statue with ID 6789:

   {
     "item": 6789,
     "name": "☼Chalk Statue of Bìlalo Bandbeach☼",
     "description": "This is a well-crafted chalk statue of Bìlalo Bandbeach. The item is an image of Bìlalo Bandbeach the elf and Lani Lyricmonks the Learned the ettin in chalk by Domas Uthmiklikot. Lani Lyricmonks the Learned is striking down Bìlalo Bandbeach. The artwork relates to the killing of the elf Bìlalo Bandbeach by the ettin Lani Lyricmonks the Learned with Hailbite in The Forest of Indignation in 147."
   }

- ``json``

Example output for a selected unit Lokum Alnisendok with ID 12345:

   {
     "id": 12345,
     "name": "Lokum Alnisendok",
     "age": 27,
     "sex": "male",
     "profession": "Presser",
     "skills": {
       "MASONRY": {"rating": 7, "rating_name": "Adept"}
     },
     "race": "dwarf",
     "isCitizen": true,
     "isAlive": true,
     "description": "A short, sturdy creature fond of drink and industry. ...",
     "thoughts": "Various thoughts ...",
     "memories": "Various memories ..."
     ...
   }


Setting up custom keybindings
-----------------------------

You can create custom keybindings to run the script faster without typing the full command each time.
You can run a command like this in gui/launcher to make it active for the current session, or add it to "dfhack-config/init/dfhack.init" to register it at startup for future game sessions:

   keybinding add Ctrl-Shift-J@dwarfmode/ViewSheets/UNIT|dwarfmode/ViewSheets/ITEM "json"

Alternatively, you can register commandlines with the `gui/quickcmd` tool and run them from the popup menu.

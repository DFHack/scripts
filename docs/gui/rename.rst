gui/rename
==========

.. dfhack-tool::
    :summary: Edit in-game language-based names.
    :tags: adventure fort productivity animals items units

Once you select a target (by clicking on something on the game map, by passing
a commandline parameter, or by using the selection dialog) this tool allows you
change the language of the name, generate a new random name, or replace
components of the name with your preferred words.

`gui/rename` provides an interface similar to the in-game naming panel that you
can use to customize your fortress name at embark. That is, it allows you to
choose words from an in-game language to assemble a name, just like the default
names that the game generates. You will be able to assign units new given and
last names, or even rename the world itself.

You can run `gui/rename` while on the "prepare carefully" embark screen to
rename your starting dwarves.

Start typing to search for a word. You can search in English, in the selected
native language, or by the part of speech. Click on a word to assign it to the
selected name component slot. You can also clear or randomize each individual
name component slot.

When giving a name to a unit that didn't previously have a name, you must
assign a word to the First Name slot. Otherwise, the game will not display the
name for the unit.

When you change the language of a unit's name, the unit's existing first name
will be translated into the new language.

Usage
-----

::

    gui/rename [<options>]

The selection dialog will appear if no options are provided. You can
interactively choose one of the following to rename:

- An artifact on the current map
- A location (e.g. tavern, hospital, guildhall, temple) on the current map
- The current fortress (or adventurer site)
- A squad belonging to the current fortress
- The civilization of the current fortress
- The government of the current fortress
- A unit on the current map
- The world

Some of the options above will not show up if there is nothing of the given
type to rename (e.g. you won't get the option to rename a squad if there are no
squads, and you won't get an option to rename the government of the fortress if
you aren't in fortress mode).

Examples
--------

``gui/rename``
    Load the selected artifact, location, or unit for renaming. If nothing is
    selected, you can select a target from a list.
``gui/rename -u 123 --no-target-selector``
    Load the unit with id ``123`` for renaming and remove the widget that
    allows selecting a different target.
``gui/rename --location 2 --site 456``
    Load the location with "abstract building" ID ``2`` attached to the site
    with id ``456`` for renaming.

Options
-------

Targets specified via these options do not need to be on the local map.

``-a``, ``--artifact <id>``
    Rename the artifact with the given item ID.
``-e``, ``--entity <id>``
    Rename the historical entity (e.g. site government, world religion, etc)
    with the given ID.
``-f``, ``--histfig <id>``
    Rename the historical figure with the given ID.
``-l``, ``--location <id>``
    Rename the location (e.g. tavern, hospital, guildhall, temple) with the
    given ID. If this option is used, ``--site`` can be specified to indicate
    locations attached to a specific site. If ``--site`` is not specified, the
    location will be loaded from the current site.
``-q``, ``--squad <id>``
    Rename the squad with the given ID.
``-s``, ``--site <id>``
    Rename the site with the given ID.
``-u``, ``--unit <id>``
    Rename the unit with the given ID. Renaming a unit also renames the
    associated historical figure.
``-w``, ``--world``
    Rename the current world.
``--no-target-selector``
    Do not allow the player to switch naming targets. An option that sets the
    initial target is required when using this option.

Overlays
--------

This tool supports the following overlays:

``gui/rename.world``
    Adds a widget to the world generation screen for renaming the world.
``gui/rename.unit_embark``
    Transparently fixes DF :bug:`12060` on the "Prepare carefully" embark screen
    where the player is unable to give units nicknames or custom professions.

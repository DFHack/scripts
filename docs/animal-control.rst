animal-control
==============

.. dfhack-tool::
    :summary: Quickly view, butcher, or geld groups of animals.
    :tags: fort productivity animals

Animal control is useful for browsing through your animals and deciding which
to butcher or geld based on their stats.

Usage
-----

::

    animal-control [<selection options>] [<command options>]

Examples
--------

``animal-control --all``
    View all your animals and whether they are marked for gelding or butchering.
``animal-control --race DOG --showstats``
    View extended info on your dogs.
``animal-control --markfor gelding --id 1988``
    Mark the specified unit for gelding.
``animal-control --gelded --markfor slaughter``
    Mark all gelded animals for slaughter.
``animal-control --gelded --markedfor slaughter --unmarkfor slaughter``
    Unmark all gelded animals for slaughter.

Selection options
-----------------

These options are used to specify what animals you want to select. If an option
calls for an ``<action>``, valid actions are ``slaughter`` and ``gelding``.

``--all``
    Selects all units. This is the default if no selection options are
    specified.
``--id <value>``
    Selects the unit with the specified id.
``--race <value>``
    Selects units which match the specified race. This can be the string name or
    the numeric race id. Run ``animal-control --all`` to see which races you
    have right now.
``--markedfor <action>``
    Selects units which have been marked for the given action.
``--notmarkedfor <action>``
    Selects units which have not been marked for the given action.
``--gelded``
    Selects units which have already been gelded.
``--notgelded``
    Selects units which have not been gelded.
``--male``
    Selects male units.
``--female``
    Selects female units.

Command options
---------------

If no command option is specified, the default is to just list the matched
animals with some basic information.

``--showstats``
    Displays physical attributes of the selected animals.
``--markfor <action>``
    Marks selected animals for the given action.
``--unmarkfor <action>``
    Unmarks selected animals for the given action.

Column abbreviations
--------------------

Due to space constraints, the names of some output columns are abbreviated
as follows:

- ``str``: strength
- ``agi``: agility
- ``tgh``: toughness
- ``endur``: endurance
- ``recup``: recuperation
- ``disres``: disease resistance

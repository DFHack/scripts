
animal-control
==============
Animal control is a script useful for deciding what animals to butcher and geld.

While not as powerful as Dwarf Therapist in managing animals - in so far as
DT allows you to sort by various stats and flags - this script does provide
many options for filtering animals. Additionally you can mark animals for
slaughter or gelding, you can even do so enmasse if you so choose.

Examples::

  animal-control -race DOG
  animal-control -race DOG -male -notgelded -showstats
  animal-control -markfor gelding -id 1988
  animal-control -markfor slaughter -id 1988
  animal-control -gelded -markedfor slaughter -unmarkfor slaughter

**Selection options:**

These options are used to specify what animals you want or do not want to select.

``-all``:                   Selects all units.
                            Note: cannot be used in conjunction with other
                            selection options.

``-id <value>``:            Selects the unit with the specified id value provided.

``-race <value>``:          Selects units which match the race value provided.

``-markedfor <action>``:    Selects units which have been marked for the action provided.
                            Valid actions: ``slaughter``, ``gelding``

``-notmarkedfor <action>``: Selects units which have not been marked for the action provided.
                            Valid actions: ``slaughter``, ``gelding``

``-gelded``:                Selects units which have already been gelded.

``-notgelded``:             Selects units which have not been gelded.

``-male``:                  Selects units which are male.

``-female``:                Selects units which are female.

**Command options:**

- ``-showstats``:           Displays physical attributes of the selected animals.

- ``-markfor <action>``:    Marks selected animals for the action provided.
                            Valid actions: ``slaughter``, ``gelding``

- ``-unmarkfor <action>``:  Unmarks selected animals for the action provided.
                            Valid actions: ``slaughter``, ``gelding``

**Other options:**

- ``-help``: Displays this information

**Column abbreviations**

Due to space constraints, the names of some output columns are abbreviated
as follows:

- ``str``: strength
- ``agi``: agility
- ``tgh``: toughness
- ``endur``: endurance
- ``recup``: recuperation
- ``disres``: disease resistance


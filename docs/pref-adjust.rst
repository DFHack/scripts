
pref-adjust
===========
``pref-adjust all`` removes/changes preferences from all dwarves, and
``pref-adjust one`` which works for a single currently selected dwarf.
For either, the script inserts an 'ideal' set which is easy to satisfy:

    ... likes iron, steel, weapons, armor, shields/bucklers and plump helmets
    for their rounded tops.  When possible, she prefers to consume dwarven
    wine, plump helmets, and prepared meals (quarry bush). She absolutely
    detests trolls, buzzards, vultures and crundles.

Additionally, ``pref-adjust goth`` will insert a less than ideal set, which
is quite challenging, for a single dwarf:

    ... likes dwarf skin, corpses, body parts, remains, coffins, the color
    black, crosses, glumprongs for their living shadows and snow demons for
    their horrifying features.  When possible, she prefers to consume sewer
    brew, gutter cruor and bloated tubers.  She absolutely detests elves,
    humans and dwarves.

To see what values can be used with each type of preference, use
``pref-adjust list``.  Optionally, a single dwarf or all dwarves can have
their preferences cleared manually with the use of ``pref-adjust clear``
and ``pref-adjust clear_all``, respectively. Existing preferences are
automatically cleared, normally.

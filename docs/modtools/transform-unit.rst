
modtools/transform-unit
=======================
Transforms a unit into another unit type, possibly permanently.
Warning: this will crash arena mode if you view the unit on the
same tick that it transforms.  If you wait until later, it will be fine.

Arguments::

    -clear
        clear records of normal races
    -unit id
        set the target unit
    -duration ticks
        how long it should last, or "forever"
    -setPrevRace
        make a record of the previous race so that you can
        change it back with -untransform
    -keepInventory
        move items back into inventory after transformation
    -race raceName
    -caste casteName
    -suppressAnnouncement
        don't show the Unit has transformed into a Blah! event
    -untransform
        turn the unit back into what it was before

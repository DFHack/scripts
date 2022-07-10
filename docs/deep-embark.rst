
deep-embark
===========
Moves the starting units and equipment to
a specific underground region upon embarking.

This script can be run directly from the console
at any point whilst setting up an embark.

Alternatively, create a file called "onLoad.init"
in the DF raw folder (if one does not exist already)
and enter the script command within it. Doing so will
cause the script to run automatically and should hence
be especially useful for modders who want their mod
to include underground embarks by default.

Example::

    deep-embark -depth CAVERN_2

Usage::

    -depth X
        (obligatory)
        replace "X" with one of the following:
            CAVERN_1
            CAVERN_2
            CAVERN_3
            UNDERWORLD

    -blockDemons
        including this arg will prevent demon surges
        in the context of breached underworld spires
        (intended mainly for UNDERWORLD embarks)
        ("wildlife" demon spawning will be unaffected)

    -atReclaim
        if the script is being run from onLoad.init,
        including this arg will enable deep embarks
        when reclaiming sites too
        (there's no need to specify this if running
        the script directly from the console)

    -clear
        re-enable normal surface embarks


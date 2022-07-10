
multicmd
========
Run multiple dfhack commands. The argument is split around the character ";",
and all parts are run sequentially as independent dfhack commands. Useful for
hotkeys.

Example::

    multicmd locate-ore IRON; digv; digcircle 16

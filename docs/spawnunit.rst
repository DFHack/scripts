
spawnunit
=========
Provides a simpler interface to `modtools/create-unit`, for creating units.

Usage:  ``spawnunit [-command] RACE CASTE [NAME] [x y z] [...]``

The ``-command`` flag prints the generated `modtools/create-unit` command
instead of running it.  ``RACE`` and ``CASTE`` specify the race and caste
of the unit to be created.  The name and coordinates of the unit are optional.
Any further arguments are simply passed on to `modtools/create-unit`.

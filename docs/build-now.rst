
build-now
=========

Instantly completes unsuspended building construction jobs. By default, all
buildings on the map are completed, but the area of effect is configurable.

Note that no units will get architecture experience for any buildings that
require that skill to construct.

Usage::

    build-now [<pos> [<pos>]] [<options>]

Where the optional ``<pos>`` pair can be used to specify the coordinate bounds
within which ``build-now`` will operate. If they are not specified,
``build-now`` will scan the entire map. If only one ``<pos>`` is specified, only
the building at that coordinate is built.

The ``<pos>`` parameters can either be an ``<x>,<y>,<z>`` triple (e.g.
``35,12,150``) or the string ``here``, which means the position of the active
game cursor.

Examples:

``build-now``
    Completes all unsuspended construction jobs on the map.

``build-now here``
    Builds the unsuspended, unconstructed building under the cursor.

Options:

:``-h``, ``--help``:
    Show help text.
:``-q``, ``--quiet``:
    Suppress informational output (error messages are still printed).

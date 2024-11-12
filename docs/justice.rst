justice
=======

.. dfhack-tool::
    :summary: Commands related to the justice system.
    :tags: fort armok units

This tool allows control over aspects of the justice system, such as the
ability to pardon criminals.

Usage
-----

::
    justice pardon [--unit <id>]

Pardon the selected unit or the one specified by unit id (if provided).
Currently only applies to prison time and doesn't cancel beatings or
hammerings.


Options
-------

``-u``, ``--unit <id>``
    Specifies the unit id of the target of the command.

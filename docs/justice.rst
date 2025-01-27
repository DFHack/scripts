justice
=======

.. dfhack-tool::
    :summary: Mess with the justice system.
    :tags: fort armok units

This tool allows control over aspects of the justice system, such as the
ability to pardon criminals.

Usage
-----

::
    justice [list]
    justice pardon [--unit <id>]

Pardon the selected unit or the one specified by unit id (if provided).
Currently only applies to prison time and doesn't cancel beatings or
hammerings.

Examples
--------

``justice``
    List the convicts currently serving sentences.
``justice pardon``
    Commutes the sentence of the currently selected convict.

Options
-------

``-u``, ``--unit <id>``
    Specifies a specific unit instead of using a selected unit.

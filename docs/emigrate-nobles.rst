emigrate-nobles
==========

.. dfhack-tool::
    :summary: Allow inherited nobles to emigrate from fort to their site of governance.
    :tags: fort units

Tired of inherited nobility freeloading off your fortress making inane demands? Use this tool
to have them (willingly) emigrate to their rightful lands.

The unit must not be assigned to a squad.

Warning! Nobles will not surrender any assigned items, be sure to unassign your artefacts before
using this tool.

Usage
-----

``emigrate-nobles --list``
    List all nobles that do not rule your fortress
``emigrate-nobles --all``
    Emigrate all nobles that do not rule your fortress
``emigrate-nobles --unit <id>``
    Emigrate a noble matching the specified unit ID that does not rule your fortress

Options
-------

``-h``, ``--help``
    View help
``-l``, ``--list``
    List all nobles that do not rule your fortress
``-a``, ``--all``
    Emigrate all nobles do not rule your fortress
``-u <id>``, ``--unit <id>``
    Emigrate noble matching specified unit ID that does not rule your fortress

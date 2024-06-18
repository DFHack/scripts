diplomacy
=========

.. dfhack-tool::
    :summary: View or alter diplomatic relationships.
    :tags: fort armok inspection military

This tool can report on or modify the diplomatic relationships (i.e. war vs.
peace) you have with other contacted civilizations. Note that a civilization
is only at peace if **both** you are at peace with them **and** they are at
peace with you.

Usage
-----

::

    diplomacy
    diplomacy all <RELATIONSHIP>
    diplomacy <CIV_ID> <RELATIONSHIP>

Examples
--------

``diplomacy``
    See current diplomatic relationships between you and all other contacted
    civs.
``diplomacy 224 peace``
    Changes both your stance towards civilization 224 and their stance towards
    you to peace.
``diplomacy all war``
    Induce the entire world to declare war on your civilization.

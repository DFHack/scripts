devel/visualize-structure
=========================

.. dfhack-tool::
    :summary: Display raw memory of a DF data structure.
    :tags: dev

Displays the raw memory of a structure, field by field. Useful for checking if
structures are aligned.

Usage
-----

::

    devel/visualize-structure <lua expression>

Example
-------

::

    devel/visualize-structure df.global.cursor

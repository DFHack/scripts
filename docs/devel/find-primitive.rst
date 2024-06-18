devel/find-primitive
====================

.. dfhack-tool::
    :summary: Discover memory offsets for new variables.
    :tags: dev

This tool helps find a primitive variable in DF's data section, relying on the
user to change its value and then scanning for memory that has changed to that
new value. This is similar to `devel/find-offsets`, but useful for new variables
whose locations are unknown (i.e. they could be part of an existing global).

Usage
-----

::

    devel/find-primitive <data type> val1 val2 [val3...]

where ``data type`` is a primitive type (int32_t, uint8_t, long, etc.) and each
``val`` is a valid value for that type.

Run ``devel/find-primitive help`` for a list of valid data types.

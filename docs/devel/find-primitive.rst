
devel/find-primitive
====================

Finds a primitive variable in DF's data section, relying on the user to change
its value. This is similar to `devel/find-offsets`, but useful for new variables
whose locations are unknown (i.e. they could be part of an existing global).

Usage::

    devel/find-primitive data-type val1 val2 [val3...]

where ``data-type`` is a primitive type (int32_t, uint8_t, long, etc.) and each
``val`` is a valid value for that type.

Use ``devel/find-primitive help`` for a list of valid data types.

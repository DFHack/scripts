workorder
=========

.. dfhack-tool::
    :summary: Create manager workorders.
    :tags: fort productivity workorders

This tool can enqueue work orders as if you were using the ``j-m-q`` interface.
It also has some convenience functions, such as automatically counting how many
creatures can be milked or sheared for ``MilkCreature`` or ``ShearCreature``
jobs. It can also take existing orders into account to ensure that the quantity
produced by *all* enqueued workorders for a specified job type totals to a
specified amount.

Usage
-----

``workorder -l <filter>``, ``workorder --listtypes <filter>``
    Print all values for relevant DF types (``job_type``, ``item_type`` etc.)
    that will be useful for assembling the workorder json. You can pass a filter
    to only print types that match a pattern.
``workorder <jobtype> [<amount>]``
    The job type is the number or name from ``df.job_type`` and the amount is
    the quantity for the generated workorder. The amount can be omitted for
    ``MilkCreature`` and ``ShearCreature`` jobs, and ``workorder`` will scan
    your pets for milkable or shearable creatures and fill the correct number
    in. Note that this syntax cannot specify the material of the item produced
    by the job. If you need more specificity, you can describe the job in JSON
    format (see the next two command forms).
``workorder <json>``
    Create a workorder whose properties are specified in the given JSON. See
    below for examples and the complete format specification.
``workorder --file <filename>``
    Loads the json representation of a workorder from the specified file in
    ``dfhack-config/workorder/``.

Examples
--------

``workorder MakeCharcoal 100``
    Enqueue a workorder to make 100 bars of charcoal.
``workorder MakeTable 10``
    Enqueue a workorder to make 10 tables of unspecified material. The material
    will be determined by which workshop ends up picking up the job.
``repeat --name autoShearCreature --time 14 --timeUnits days --command [ workorder ShearCreature ]``
    Automatically shear any pets that are ready to be sheared.
``repeat --name autoMilkCreature --time 14 --timeUnits days --command [ workorder "{\"job\":\"MilkCreature\",\"item_conditions\":[{\"condition\":\"AtLeast\",\"value\":5,\"flags\":[\"empty\"],\"item_type\":\"BUCKET\"}]}" ]``
    Automatically milk any pets that are ready to be milked (but only if there
    are at least 5 empty buckets available to receive the milk).
``workorder "{\"job\":\"EncrustWithGems\",\"item_category\":[\"finished_goods\"],\"amount_total\":5}"``
    Add an order to ``EncrustWithGems`` five ``finished_goods`` using any
    material (since a material is not specified).

JSON string specification
-------------------------

The JSON representation of a workorder must be a valid Lua string literal (note
usage of :kbd:`\\` in the JSON examples above). You can export existing manager
orders with the `orders` command and look at the created ``.json`` file in
``dfhack-config/orders`` to see how a particular order can be represented.

Note that, unlike `orders`, ``workorder`` is meant for dynamically creating new
orders, so even if fields like ``amount_left``, ``is_active`` or
``is_validated`` are specified in the JSON, they will be ignored in the
generated orders.

Also:

- You only need to fill in ``id`` if it is used for order conditions
- If ``frequency`` is unspecified, it defaults to ``OneTime``
- The ``amount_total`` field can be missing (only valid for ``MilkCreature`` or
  ``ShearCreature`` jobs) or it can be raw Lua code called as
  ``load(code)(order, orders)`` that must return an integer.

A custom field ``__reduce_amount`` can be set if existing open orders should be
taken into account. The first matching existing order will be modified to have
the desired quantity remaining. If the desired quantity is negative, the
existing order will be removed. An empty ``amount_total`` implies
``"__reduce_amount": true``.
